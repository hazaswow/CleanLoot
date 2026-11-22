-- The timed loot session: the master looter offers the items of the loot pool one after the
-- other. For each one the group is told in the chat how to roll, the rolls are read from the
-- game's own "X rolls N (1-100)" messages, and the winner is picked and announced.
--
--   1-100 = MS   1-99 = OS   1-90 = Other      (MS beats OS beats Other, whatever the numbers)
--
-- Rules for the rolls of one player on one item: the first roll counts; a later roll in a LOWER
-- category (MS then OS, OS then Other) replaces it, never the other way round; passing cancels
-- the roll. Because the game's /roll messages are shown to the whole group, everybody reading
-- them sees the same rolls, with or without CleanLoot.
--
-- The state machine of one item: rolling (timer, reminders, countdown) -> decide (rolls closed:
-- the winner is picked, or the master looter picks) -> between (a short pause) -> next item.
-- Alone, nothing is sent: the messages are printed to you (that is how to try it by yourself).

local _, CL = ...

local Run = {}
CL.SessionRun = Run

local ML = CL.MasterLoot
local Book = CL.RollBook

local PAUSE_BETWEEN = 3     -- seconds between an item's result and the next item
local REVIEW_WAIT = 30      -- after the last item: time to change an assignment before the session ends
local EXTEND = 10           -- seconds a click on +10 s adds
local WHISPER_GAP = 0.4     -- between two whispers

local LABEL = { "MS", "OS", "Other" }
local RANGE = { 100, 99, 90 }
local CAT_OF = { [100] = 1, [99] = 2, [90] = 3 }
function Run.Label(cat) return LABEL[cat] end
-- One colour per kind of roll, so MS, OS and Other are told apart at a glance.
local COLOR = { "|cffff9933", "|cff33ccff", "|cffcc99ff" }
function Run.CatColor(cat) return COLOR[cat] or "" end

local state   -- nil while no session runs
function Run.State() return state end
function Run.Active() return state ~= nil end
Run.last = nil   -- the session that ended last: its awards

local function Changed()
    if CL.Session and CL.Session.Refresh then CL.Session.Refresh() end
end

-- The seconds each item is open: the option, kept between 10 and 60.
function Run.Duration()
    local t = CL.db and CL.db.sessionTime
    if type(t) ~= "number" then t = 15 end
    return math.max(10, math.min(60, math.floor(t)))
end

-- When to speak while an item is open (seconds left). A countdown 3, 2, 1 always ends it; before
-- it one or two reminders, none of them on the same second as another:
--   more than 15 s: 15 and 5  |  11 to 15 s: 10  |  10 s: 5
function Run.Marks(duration)
    local marks
    if duration > 15 then marks = { 15, 5 }
    elseif duration > 10 then marks = { 10 }
    else marks = { 5 } end
    marks[#marks + 1] = 3
    marks[#marks + 1] = 2
    marks[#marks + 1] = 1
    return marks
end

local function MarkText(mark)
    if mark >= 4 then return ("%d sec left"):format(mark) end
    return tostring(mark)   -- the countdown: 3, 2, 1
end

-------------------------------------------------
-- Talking
-------------------------------------------------
-- A test session never reaches the group.
local function Say(message)
    if state and state.test then
        print(message)
    else
        ML.Say(message)
    end
end

local function LinkOf(item)
    return ML.ChatLink(item.link, item.name, item.quality)
end

-- Tell the other players' CleanLoot what happens (Comm.lua). Never from a test session, and
-- nothing goes out alone.
local function Broadcast(kind, ...)
    if state and not state.test and CL.Comm then CL.Comm.Send(kind, ...) end
end

local function LotIndex(lot)
    for i, l in ipairs(state and state.queue or {}) do
        if l == lot then return i end
    end
    return 0
end

local function ShortName(name)
    return type(name) == "string" and (name:match("^([^%-]+)") or name) or "?"
end

local whisperQueue, whispering = {}, false
local function NextWhisper()
    local w = table.remove(whisperQueue, 1)
    if not w then
        whispering = false
        return
    end
    local ok, err = pcall(SendChatMessage, w.message, "WHISPER", nil, w.name)
    if not ok then CL.Print("could not whisper " .. w.name .. ": " .. tostring(err)) end
    C_Timer.After(WHISPER_GAP, NextWhisper)
end
local function Whisper(name, message)
    whisperQueue[#whisperQueue + 1] = { name = name, message = message }
    if not whispering then
        whispering = true
        NextWhisper()
    end
end

local function MyName()
    local name = type(UnitName) == "function" and UnitName("player")
    return type(name) == "string" and name or nil
end

-------------------------------------------------
-- The rolls of the item in play
-------------------------------------------------
-- The roll messages, from the game's own format ("%s rolls %d (%d-%d)").
local rollPattern
local function RollPattern()
    if rollPattern ~= nil then return rollPattern end
    local text = rawget(_G, "RANDOM_ROLL_RESULT")
    if type(text) ~= "string" then
        rollPattern = false
        return false
    end
    local p = text:gsub("[%(%)%.%-%+%[%]%?%*%^%$]", "%%%0"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    rollPattern = "^" .. p .. "$"
    return rollPattern
end

-- "X rolls N (1-100)" -> name, value, low, high (nil when the text is something else).
function Run.ParseRoll(text)
    local pattern = RollPattern()
    if not pattern or type(text) ~= "string" then return nil end
    local name, value, low, high = text:match(pattern)
    if not name then return nil end
    return name, tonumber(value), tonumber(low), tonumber(high)
end

-- One roll seen in the chat. Returns true when it counts (the rules are in RollBook.lua).
function Run.HandleRoll(name, value, low, high)
    if not (state and state.phase == "rolling") then return false end
    if not Book.Add(state, name, value, low, high) then return false end
    Changed()
    return true
end

-- Somebody passes: their roll is cancelled (CleanLoot players pass with a button).
function Run.Pass(name)
    if not (state and state.phase == "rolling") then return false end
    Book.Pass(state, name)
    Changed()
    return true
end

-- The rolls, best first: { { name, cat, value, tied }, ... }, and how many share the best.
function Run.Ranking()
    if not state then return {}, 0 end
    return Book.Ranking(state)
end

local function RangeText(cat)
    return ("1-%d=%s"):format(RANGE[cat], LABEL[cat])
end

-- Identical items (100%: the same item, enchants, gems and bonuses) are offered together: one
-- roll for all the copies, and as many winners as there are copies, best rolls first. The one
-- field that differs from one copy to the next, the unique id of the link, is ignored.
function Run.ItemKey(link)
    local itemString = type(link) == "string" and link:match("|H(item:[^|]+)|h")
    if not itemString then return nil end
    local fields = {}
    for field in (itemString .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = field end
    -- item:itemID:enchant:gem1:gem2:gem3:gem4:suffix:uniqueID:...  (the 9th field is the unique id)
    if #fields >= 9 then fields[9] = "" end
    return table.concat(fields, ":")
end

-- The items of the list grouped by identity, oldest first:
--   { { link, name, quality, guid, items = { entry, ... }, count }, ... }
local function MakeLots(entries)
    local lots, byKey = {}, {}
    for _, e in ipairs(entries) do
        local key = Run.ItemKey(e.link) or ("one:" .. tostring(e.guid or e.name))
        local lot = byKey[key]
        if not lot then
            lot = { link = e.link, name = e.name, quality = e.quality, guid = e.guid, items = {}, count = 0 }
            byKey[key] = lot
            lots[#lots + 1] = lot
        end
        lot.items[#lot.items + 1] = e
        lot.count = lot.count + 1
    end
    return lots
end
Run.MakeLots = MakeLots

-- Who wins with `slots` copies to give, from the rolls (best first): the players above the line,
-- and, when equal rolls straddle the last copy, that group and how many of them still win.
--   winners, contested (or nil), need
local function Plan(ranking, slots)
    local winners, contested, need = {}, nil, 0
    local i = 1
    while i <= #ranking and slots > 0 do
        local first = ranking[i]
        local group, j = {}, i
        while j <= #ranking and ranking[j].cat == first.cat and ranking[j].value == first.value do
            group[#group + 1] = ranking[j]
            j = j + 1
        end
        if #group <= slots then
            for _, e in ipairs(group) do winners[#winners + 1] = e end
            slots = slots - #group
        else
            contested, need = group, slots
            break
        end
        i = j
    end
    return winners, contested, need
end

-------------------------------------------------
-- The flow
-------------------------------------------------
local runner = CreateFrame("Frame")
runner:Hide()

local function Between(seconds)
    -- the item is done: remember it, the master looter can come back to it
    if state.item and state.recorded ~= state.index then
        state.recorded = state.index
        state.history[#state.history + 1] = { lot = state.item, ranking = state.ranking or {} }
    end
    state.phase = "between"
    state.wait = seconds or PAUSE_BETWEEN
    Changed()
end

local BeginItem, End

local function Next()
    state.index = state.index + 1
    if state.index > #state.queue then
        -- every item is done: a moment to change an assignment before the whispers go out
        state.phase = "review"
        state.reviewLeft = REVIEW_WAIT
        state.item = nil
        Changed()
    else
        BeginItem()
    end
end

-- Test sessions: made-up players roll at random moments, so a session can be tried alone.
local FAKE_NAMES = { "Aludra Fen", "Baric Holt", "Cyndra Vale", "Dorun Ash", "Eluned Rook" }
local function MakeFake(duration)
    local fake = {}
    for i, name in ipairs(FAKE_NAMES) do
        local cat = (i <= 3) and 1 or ((i == 4) and 2 or 3)
        fake[#fake + 1] = { name = name, cat = cat, at = 1 + math.random() * math.max(1, duration - 4),
            value = math.random(1, RANGE[cat]) }
    end
    return fake
end

function BeginItem()
    local item = state.queue[state.index]
    state.item = item
    state.rolls, state.passed = {}, {}
    state.restrict, state.ranking, state.tie = nil, nil, false
    state.slots, state.contested, state.need, state.pendingClear = item.count or 1, nil, 0, 0
    state.lotAwarded = {}
    state.remaining = state.duration
    state.marks = Run.Marks(state.duration)
    state.fired = {}
    state.phase = "rolling"
    state.fake = state.test and MakeFake(state.duration) or nil
    if (item.count or 1) > 1 then
        Say(("Roll for %s x%d (%d/%d): the %d best rolls win. 1-100=MS 1-99=OS 1-90=Other. %d sec left"):format(
            LinkOf(item), item.count, state.index, #state.queue, item.count, state.duration))
    else
        Say(("Roll for %s (%d/%d): 1-100=MS 1-99=OS 1-90=Other. %d sec left"):format(
            LinkOf(item), state.index, #state.queue, state.duration))
    end
    Broadcast("I", state.sid, state.index, #state.queue, item.count or 1, item.link or "", state.duration)
    runner:Show()
    Changed()
end

-- Who wins now among the rolls not yet given a copy, and which equal rolls are contested.
local function Settle()
    local open = {}
    for _, e in ipairs(state.ranking or {}) do
        e.tied = false
        if not e.assigned then open[#open + 1] = e end
    end
    local winners, contested, need = Plan(open, state.slots)
    state.contested, state.need = contested, need
    state.tie = contested ~= nil
    state.pendingClear = #winners
    if contested then
        for _, e in ipairs(contested) do e.tied = true end
    end
    return winners
end

local function Unassigned()
    local n = 0
    for _, e in ipairs(state and state.ranking or {}) do
        if not e.assigned then n = n + 1 end
    end
    return n
end

-- The rolls are closed: the best rolls win the copies (by themselves, or the master looter
-- picks); equal rolls on the last copy are announced and re-rolled or decided by the master looter.
local function CloseItem()
    state.phase = "decide"
    local ranking = Run.Ranking()
    state.ranking = ranking
    local link = LinkOf(state.item)
    Broadcast("C", state.sid, state.index)
    if #ranking == 0 then
        Say(("[CleanLoot] No roll for %s."):format(link))
        state.awardedText = "Nobody rolled."
        Between()
        return
    end
    Say(("[CleanLoot] Rolls closed for %s."):format(link))
    local winners = Settle()
    local contested, need = state.contested, state.need
    local tieMessage
    if contested then
        local names = {}
        for _, e in ipairs(contested) do names[#names + 1] = ShortName(e.name) end
        local roll = ("%s %d"):format(LABEL[contested[1].cat], contested[1].value)
        if need > 1 then
            tieMessage = ("[CleanLoot] Tie for the last %d copies of %s between %s (%s). The master looter decides."):format(
                need, link, table.concat(names, ", "), roll)
        else
            tieMessage = ("[CleanLoot] Tie for %s between %s (%s). The master looter decides."):format(
                link, table.concat(names, ", "), roll)
        end
    end
    if CL.db.sessionAuto then
        for _, e in ipairs(winners) do Run.Award(e.name) end
    end
    if tieMessage and state.phase == "decide" then Say(tieMessage) end
    Changed()
end

-- Give the next copy of the item in play to `name` (one of the rolls). Automatic, or the master
-- looter's choice.
function Run.Award(name)
    if not (state and state.phase == "decide") or state.slots <= 0 then return false end
    local entry
    for _, e in ipairs(state.ranking or {}) do
        if e.name == name and not e.assigned then entry = e break end
    end
    if not entry then return false end
    local item = state.item
    local copy = (item.items and item.items[(item.count or 1) - state.slots + 1]) or item
    entry.assigned = true
    state.slots = state.slots - 1
    state.awards[#state.awards + 1] = { item = item, copy = copy, winner = name, cat = entry.cat, value = entry.value,
        entry = entry }
    state.lotAwarded[#state.lotAwarded + 1] = ShortName(name)
    if not state.test and copy.guid then
        CL.LootPool.SetAwarded(copy.guid, name, LABEL[entry.cat] .. " " .. entry.value)
    end
    Say(("[CleanLoot] %s assigned to %s for roll %s %d."):format(LinkOf(item), ShortName(name),
        LABEL[entry.cat], entry.value))
    Broadcast("W", state.sid, state.index, name, entry.cat, entry.value)
    if state.slots == 0 or Unassigned() == 0 then
        if #state.lotAwarded == 1 then
            state.awardedText = ("Assigned to %s (%s %d)."):format(ShortName(name), LABEL[entry.cat], entry.value)
        else
            state.awardedText = "Assigned to " .. table.concat(state.lotAwarded, ", ") .. "."
        end
        if state.slots > 0 then
            state.awardedText = state.awardedText .. (" %d cop%s not given."):format(state.slots,
                state.slots == 1 and "y" or "ies")
        end
        Between()
    else
        Settle()
        Changed()
    end
    return true
end

function End(cancelled)
    Broadcast(cancelled and "K" or "E", state.sid)
    local awards = state.awards
    if not cancelled then
        if #awards == 0 then
            Say("[CleanLoot] Session over: nothing was assigned.")
        else
            Say(("[CleanLoot] Session over: %d item%s assigned."):format(#awards, #awards == 1 and "" or "s"))
        end
    end
    -- each winner is invited to come and trade the master looter, one whisper per item
    if CL.db.sessionWhisper and not state.test then
        local me = MyName()
        for _, a in ipairs(awards) do
            if not (me and ML.SameName(a.winner, me)) then
                local roll = a.cat and (" (%s %d)"):format(LABEL[a.cat], a.value) or ""
                Whisper(a.winner, ("[CleanLoot] You won %s%s. Come trade me for it."):format(LinkOf(a.item), roll))
            end
        end
    end
    Run.last = state
    state = nil
    runner:Hide()
    Changed()
end

runner:SetScript("OnUpdate", function(_, elapsed)
    if not state then return end
    elapsed = elapsed or 0
    if state.phase == "rolling" then
        state.remaining = state.remaining - elapsed
        if state.fake then
            local spent = state.duration - state.remaining
            for _, f in ipairs(state.fake) do
                if not f.done and spent >= f.at then
                    f.done = true
                    Run.HandleRoll(f.name, f.value, 1, RANGE[f.cat])
                end
            end
        end
        for _, mark in ipairs(state.marks) do
            if not state.fired[mark] and state.remaining <= mark then
                state.fired[mark] = true
                if state.remaining > 0 then Say(MarkText(mark)) end
            end
        end
        if state.remaining <= 0 then
            state.remaining = 0
            CloseItem()
        end
    elseif state.phase == "between" then
        state.wait = state.wait - elapsed
        if state.wait <= 0 then Next() end
    elseif state.phase == "review" then
        state.reviewLeft = state.reviewLeft - elapsed
        if state.reviewLeft <= 0 then End(false) end
    end
    if not state then return end
    state.tick = (state.tick or 0) + elapsed
    if state.tick >= 0.25 then
        state.tick = 0
        Changed()
    end
end)

-------------------------------------------------
-- Starting
-------------------------------------------------
-- Can a session start now? (true) or (false, why).
function Run.CanStart()
    if state then return false, "a session is already running." end
    if not ML.Enabled() then return false, "the master loot features are off (Options > Master loot)." end
    local inGroup = type(IsInGroup) == "function" and IsInGroup() == true
    if inGroup and not ML.IsMasterLooter() then return false, "only the master looter can start a session." end
    if #CL.LootPool.Offered() == 0 then
        return false, "no item to offer: the list is empty, or every item is left out (/cll session)."
    end
    return true
end

local function Begin(items, test)
    local lots = MakeLots(items)
    state = { queue = lots, index = 0, test = test, awards = {}, history = {}, duration = Run.Duration(),
        phase = "starting", sid = ("%d%03d"):format(math.floor(GetTime()), math.random(0, 999)) }
    local different = #lots ~= #items and (" (%d different)"):format(#lots) or ""
    Say(("[CleanLoot] Loot session: %d item%s%s, %d sec each. 1-100=MS 1-99=OS 1-90=Other"):format(
        #items, #items == 1 and "" or "s", different, state.duration))
    Broadcast("S", CL.Comm and CL.Comm.VERSION or 1, state.sid, #lots, state.duration)
    Next()
    return true
end

function Run.Start()
    local ok, why = Run.CanStart()
    if not ok then
        CL.Print(why)
        return false
    end
    return Begin(CL.LootPool.Offered(), false)
end

-- A session with made-up players that never speaks to the group: to see it work alone.
function Run.StartTest()
    if state then
        CL.Print("a session is already running.")
        return false
    end
    local items = {}
    for _, e in ipairs(CL.LootPool.Offered()) do
        if #items < 3 then items[#items + 1] = e end
    end
    local fakes = { { name = "Sim Test Blade", id = 9999, quality = 4 }, { name = "Sim Test Ring", id = 9998, quality = 3 } }
    for _, f in ipairs(fakes) do
        if #items < 2 then
            items[#items + 1] = { name = f.name, quality = f.quality,
                link = ("|cff0070dd|Hitem:%d::::::::60:::::|h[%s]|h|r"):format(f.id, f.name) }
        end
    end
    return Begin(items, true)
end

-------------------------------------------------
-- The master looter's controls (each one tells the group)
-------------------------------------------------
local function Rolling() return state and (state.phase == "rolling" or state.phase == "paused") end

function Run.Pause()
    if not (state and state.phase == "rolling") then return false end
    state.phase = "paused"
    Say("[CleanLoot] Session paused.")
    Broadcast("P", state.sid, state.index, 1, math.ceil(state.remaining))
    Changed()
    return true
end

function Run.Resume()
    if not (state and state.phase == "paused") then return false end
    state.phase = "rolling"
    Say(("[CleanLoot] Session resumed: %d sec left for %s."):format(math.ceil(state.remaining), LinkOf(state.item)))
    Broadcast("P", state.sid, state.index, 0, math.ceil(state.remaining))
    Changed()
    return true
end

function Run.Extend()
    if not Rolling() then return false end
    state.remaining = state.remaining + EXTEND
    for mark in pairs(state.fired) do
        if mark < state.remaining then state.fired[mark] = nil end   -- the reminders below come again
    end
    Say(("[CleanLoot] +%d sec for %s: %d sec left."):format(EXTEND, LinkOf(state.item), math.ceil(state.remaining)))
    Broadcast("P", state.sid, state.index, state.phase == "paused" and 1 or 0, math.ceil(state.remaining))
    Changed()
    return true
end

-- Leave the item unassigned and go on.
function Run.Skip()
    if not (state and (Rolling() or state.phase == "decide")) then return false end
    Say(("[CleanLoot] %s skipped."):format(LinkOf(state.item)))
    state.ranking = state.ranking or Run.Ranking()
    Broadcast("Z", state.sid, state.index)
    state.awardedText = "Skipped."
    Between()
    return true
end

function Run.Cancel()
    if not state then return false end
    Say("[CleanLoot] Session cancelled.")
    End(true)
    return true
end

-- After a tie: only the tied players roll again, in the range of their category.
function Run.Reroll()
    if not (state and state.phase == "decide" and state.tie and state.pendingClear == 0) then return false end
    local names, list, full, cat = {}, {}, {}, state.contested[1].cat
    for _, e in ipairs(state.contested) do
        names[e.name] = true
        list[#list + 1] = ShortName(e.name)
        full[#full + 1] = e.name
    end
    state.restrict = { names = names, cat = cat }
    state.rolls, state.passed, state.ranking, state.tie, state.contested = {}, {}, nil, false, nil
    state.remaining = state.duration
    state.fired = {}
    state.phase = "rolling"
    local copies = state.slots > 1 and (" (%d copies to give)"):format(state.slots) or ""
    Say(("[CleanLoot] Re-roll for %s between %s: %s%s. %d sec left"):format(LinkOf(state.item),
        table.concat(list, ", "), RangeText(cat), copies, state.duration))
    Broadcast("R", state.sid, state.index, table.concat(full, ","), cat, state.duration)
    Changed()
    return true
end

-- The master looter rolls too: his buttons make the game's own /roll, which the session reads
-- like everybody's (a test session has no real roll, so it makes one up).
local function MyRollName()
    local me = MyName()
    if me and state then
        for name in pairs(state.rolls) do
            if ML.SameName(name, me) then return name end
        end
    end
    return me or "You"
end

function Run.RollAs(cat)
    if not (state and state.phase == "rolling") or not RANGE[cat] then return false end
    local high = RANGE[cat]
    if state.test then
        Run.HandleRoll(MyName() or "You", math.random(1, high), 1, high)
    else
        local ok, err = pcall(RandomRoll, 1, high)
        if not ok then
            CL.Print("could not roll: " .. tostring(err))
            return false
        end
    end
    return true
end

function Run.PassMe()
    if not (state and state.phase == "rolling") then return false end
    return Run.Pass(MyRollName())
end

-- After the last item the session waits a little so assignments can be changed; this ends it now.
function Run.Finish()
    if not (state and state.phase == "review") then return false end
    End(false)
    return true
end

-- The items done so far: { { lot, ranking }, ... }.
function Run.History() return state and state.history or {} end

function Run.AwardsFor(lot)
    local list = {}
    for _, a in ipairs(state and state.awards or {}) do
        if a.item == lot then list[#list + 1] = a end
    end
    return list
end

function Run.FreeCopies(lot)
    return (lot.count or 1) - #Run.AwardsFor(lot)
end

-- An item can be changed once it is done, never while it is being rolled for.
function Run.CanEdit(lot)
    if not (state and lot) then return false end
    if state.item == lot and (state.phase == "rolling" or state.phase == "paused" or state.phase == "decide") then
        return false
    end
    return true
end

local function Touched()
    if state and state.phase == "review" then state.reviewLeft = REVIEW_WAIT end   -- the master looter is still on it
    Changed()
end

-- Take an assignment back: the copy is free again.
function Run.Unassign(award)
    if not state then return false end
    for i, a in ipairs(state.awards) do
        if a == award then
            if not Run.CanEdit(award.item) then return false end
            table.remove(state.awards, i)
            if award.entry then award.entry.assigned = false end
            if not state.test and award.copy and award.copy.guid then CL.LootPool.ClearAwarded(award.copy.guid) end
            Say(("[CleanLoot] %s is no longer assigned to %s."):format(LinkOf(award.item), ShortName(award.winner)))
            Broadcast("X", state.sid, LotIndex(award.item), award.winner)
            Touched()
            return true
        end
    end
    return false
end

-- Give a free copy of a finished item to `name` by hand: one of its rolls (`entry`) or anybody.
function Run.AssignManual(lot, name, entry)
    if not (state and lot and Run.CanEdit(lot)) then return false end
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return false end
    local used = {}
    for _, a in ipairs(Run.AwardsFor(lot)) do used[a.copy] = true end
    local copy
    for _, c in ipairs(lot.items or { lot }) do
        if not used[c] then copy = c break end
    end
    if not copy then return false end
    state.awards[#state.awards + 1] = { item = lot, copy = copy, winner = name, cat = entry and entry.cat or nil,
        value = entry and entry.value or nil, entry = entry }
    if entry then entry.assigned = true end
    if not state.test and copy.guid then
        CL.LootPool.SetAwarded(copy.guid, name, entry and (LABEL[entry.cat] .. " " .. entry.value) or "by hand")
    end
    if entry then
        Say(("[CleanLoot] %s assigned to %s for roll %s %d."):format(LinkOf(lot), ShortName(name), LABEL[entry.cat], entry.value))
    else
        Say(("[CleanLoot] %s assigned to %s."):format(LinkOf(lot), ShortName(name)))
    end
    Broadcast("W", state.sid, LotIndex(lot), name, entry and entry.cat or "", entry and entry.value or "")
    Touched()
    return true
end

-- What the window may offer now.
function Run.Can(action)
    if not state then return false end
    if action == "cancel" then return true end
    if action == "roll" or action == "pass" then return state.phase == "rolling" end
    if action == "finish" then return state.phase == "review" end
    if action == "pause" then return state.phase == "rolling" end
    if action == "resume" then return state.phase == "paused" end
    if action == "extend" then return Rolling() and true or false end
    if action == "skip" then return (Rolling() or state.phase == "decide") and true or false end
    if action == "reroll" then return state.phase == "decide" and state.tie and state.pendingClear == 0 end
    if action == "choose" then return state.phase == "decide" and state.slots > 0 and Unassigned() > 0 end
    return false
end

-------------------------------------------------
-- The game's roll messages
-------------------------------------------------
-- A player of the group passes with his CleanLoot window.
if CL.Comm then
    CL.Comm.On("Q", function(fields, sender)
        if not (state and state.phase == "rolling" and fields[1] == state.sid and tonumber(fields[2]) == state.index) then
            return
        end
        local who = sender
        for name in pairs(state.rolls) do
            if ML.SameName(name, sender) then who = name break end
        end
        Run.Pass(who)
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:SetScript("OnEvent", function(_, _, text)
    if not (state and state.phase == "rolling") or state.test then return end
    local name, value, low, high = Run.ParseRoll(CL.Plain(text))
    if name then Run.HandleRoll(name, value, low, high) end
end)
