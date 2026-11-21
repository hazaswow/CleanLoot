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

local PAUSE_BETWEEN = 3     -- seconds between an item's result and the next item
local EXTEND = 10           -- seconds a click on +10 s adds
local WHISPER_GAP = 0.4     -- between two whispers

local LABEL = { "MS", "OS", "Other" }
local RANGE = { 100, 99, 90 }
local CAT_OF = { [100] = 1, [99] = 2, [90] = 3 }
function Run.Label(cat) return LABEL[cat] end

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

-- One roll seen in the chat. Returns true when it counts.
function Run.HandleRoll(name, value, low, high)
    if not (state and state.phase == "rolling") then return false end
    if type(name) ~= "string" or type(value) ~= "number" or low ~= 1 then return false end
    local cat = CAT_OF[high]
    if not cat then return false end   -- not one of the three ranges: not a roll for this
    if state.restrict then
        if not state.restrict.names[name] or cat ~= state.restrict.cat then return false end
    end
    local old = state.rolls[name]
    if old and cat <= old.cat then return false end   -- the same category again, or an upgrade
    state.rolls[name] = { cat = cat, value = value }
    state.passed[name] = nil
    Changed()
    return true
end

-- Somebody passes: their roll is cancelled (CleanLoot players pass with a button).
function Run.Pass(name)
    if not (state and state.phase == "rolling") then return false end
    state.rolls[name] = nil
    state.passed[name] = true
    Changed()
    return true
end

-- The rolls, best first: { { name, cat, value, tied }, ... }, and how many share the best.
function Run.Ranking()
    local list = {}
    if not state then return list, 0 end
    for name, r in pairs(state.rolls) do
        list[#list + 1] = { name = name, cat = r.cat, value = r.value }
    end
    table.sort(list, function(a, b)
        if a.cat ~= b.cat then return a.cat < b.cat end
        if a.value ~= b.value then return a.value > b.value end
        return a.name < b.name
    end)
    local top, tied = list[1], 0
    for _, e in ipairs(list) do
        if top and e.cat == top.cat and e.value == top.value then tied = tied + 1 end
    end
    for _, e in ipairs(list) do
        e.tied = tied > 1 and top and e.cat == top.cat and e.value == top.value or false
    end
    return list, tied
end

local function RangeText(cat)
    return ("1-%d=%s"):format(RANGE[cat], LABEL[cat])
end

-------------------------------------------------
-- The flow
-------------------------------------------------
local runner = CreateFrame("Frame")
runner:Hide()

local function Between(seconds)
    state.phase = "between"
    state.wait = seconds or PAUSE_BETWEEN
    Changed()
end

local BeginItem, End

local function Next()
    state.index = state.index + 1
    if state.index > #state.queue then
        End(false)
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
    state.remaining = state.duration
    state.marks = Run.Marks(state.duration)
    state.fired = {}
    state.phase = "rolling"
    state.fake = state.test and MakeFake(state.duration) or nil
    Say(("Roll for %s (%d/%d): 1-100=MS 1-99=OS 1-90=Other. %d sec left"):format(
        LinkOf(item), state.index, #state.queue, state.duration))
    runner:Show()
    Changed()
end

-- The rolls are closed: pick the winner, or leave it to the master looter.
local function CloseItem()
    state.phase = "decide"
    local ranking, tied = Run.Ranking()
    state.ranking = ranking
    local link = LinkOf(state.item)
    if #ranking == 0 then
        Say(("[CleanLoot] No roll for %s."):format(link))
        state.awardedText = "Nobody rolled."
        Between()
        return
    end
    Say(("[CleanLoot] Rolls closed for %s."):format(link))
    if tied > 1 then
        local names = {}
        for _, e in ipairs(ranking) do
            if e.tied then names[#names + 1] = ShortName(e.name) end
        end
        state.tie = true
        Say(("[CleanLoot] Tie for %s between %s (%s %d). The master looter decides."):format(link,
            table.concat(names, ", "), LABEL[ranking[1].cat], ranking[1].value))
    elseif CL.db.sessionAuto then
        Run.Award(ranking[1].name)
        return
    end
    Changed()
end

-- Give the item in play to `name` (one of the rolls). Automatic, or the master looter's choice.
function Run.Award(name)
    if not (state and state.phase == "decide") then return false end
    local entry
    for _, e in ipairs(state.ranking or {}) do
        if e.name == name then entry = e break end
    end
    if not entry then return false end
    state.awards[#state.awards + 1] = { item = state.item, winner = name, cat = entry.cat, value = entry.value }
    if not state.test and state.item.guid then
        CL.LootPool.SetAwarded(state.item.guid, name, LABEL[entry.cat] .. " " .. entry.value)
    end
    Say(("[CleanLoot] %s assigned to %s for roll %s %d."):format(LinkOf(state.item), ShortName(name),
        LABEL[entry.cat], entry.value))
    state.awardedText = ("Assigned to %s (%s %d)."):format(ShortName(name), LABEL[entry.cat], entry.value)
    Between()
    return true
end

function End(cancelled)
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
                Whisper(a.winner, ("[CleanLoot] You won %s (%s %d). Come trade me for it."):format(
                    LinkOf(a.item), LABEL[a.cat], a.value))
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
    state = { queue = items, index = 0, test = test, awards = {}, duration = Run.Duration(), phase = "starting" }
    Say(("[CleanLoot] Loot session: %d item%s, %d sec each. 1-100=MS 1-99=OS 1-90=Other"):format(
        #items, #items == 1 and "" or "s", state.duration))
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
    Changed()
    return true
end

function Run.Resume()
    if not (state and state.phase == "paused") then return false end
    state.phase = "rolling"
    Say(("[CleanLoot] Session resumed: %d sec left for %s."):format(math.ceil(state.remaining), LinkOf(state.item)))
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
    Changed()
    return true
end

-- Leave the item unassigned and go on.
function Run.Skip()
    if not (state and (Rolling() or state.phase == "decide")) then return false end
    Say(("[CleanLoot] %s skipped."):format(LinkOf(state.item)))
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
    if not (state and state.phase == "decide" and state.tie) then return false end
    local names, cat = {}, state.ranking[1].cat
    local list = {}
    for _, e in ipairs(state.ranking) do
        if e.tied then
            names[e.name] = true
            list[#list + 1] = ShortName(e.name)
        end
    end
    state.restrict = { names = names, cat = cat }
    state.rolls, state.passed, state.ranking, state.tie = {}, {}, nil, false
    state.remaining = state.duration
    state.fired = {}
    state.phase = "rolling"
    Say(("[CleanLoot] Re-roll for %s between %s: %s. %d sec left"):format(LinkOf(state.item),
        table.concat(list, ", "), RangeText(cat), state.duration))
    Changed()
    return true
end

-- What the window may offer now.
function Run.Can(action)
    if not state then return false end
    if action == "cancel" then return true end
    if action == "pause" then return state.phase == "rolling" end
    if action == "resume" then return state.phase == "paused" end
    if action == "extend" then return Rolling() and true or false end
    if action == "skip" then return (Rolling() or state.phase == "decide") and true or false end
    if action == "reroll" then return state.phase == "decide" and state.tie end
    if action == "choose" then return state.phase == "decide" and #(state.ranking or {}) > 0 end
    return false
end

-------------------------------------------------
-- The game's roll messages
-------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:SetScript("OnEvent", function(_, _, text)
    if not (state and state.phase == "rolling") or state.test then return end
    local pattern = RollPattern()
    text = CL.Plain(text)
    if not pattern or type(text) ~= "string" then return end
    local name, value, low, high = text:match(pattern)
    if name then Run.HandleRoll(name, tonumber(value), tonumber(low), tonumber(high)) end
end)
