-- The result popup: when a roll ends, a small card says who won the item and with
-- what roll, and what you rolled yourself. With the per-roll lines kept out of the
-- chat (ChatFilter.lua) this is where the numbers go. Hover a card for every roll
-- of that drop; right-click closes it.
--
-- The data comes from CL.API.GetResult (the loot history, or the simulator).

local _, CL = ...

local Results = {}
CL.Results = Results

local CARD_W = 252
local CARD_H, CARD_H_ME = 46, 57   -- a third line when you did not win
local SPACING = 4
local MAX_CARDS = 8   -- as many as the roll frames: a big drop ends all at once
local SHOW_FOR, FADE_FOR = 10, 0.6  -- seconds on screen, then fading out
local RETRY_DELAYS = { 0.3, 1, 2.5 }  -- the winner reaches the history a moment after "complete"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
    bgFile = FLAT, edgeFile = FLAT, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local GOLD = "|cffffd100"

local WAIT_H = 26    -- the "waiting on rolls" card
local free = {}      -- cards not in use
local active = {}    -- cards on screen, oldest first
local anchor
local waitCard       -- "waiting on rolls": first in the stack, only while somebody has not rolled
local open = {}      -- lootListKey -> time first known: rolls followed until the game names a winner
local shown = {}     -- lootListKey -> true: result already announced

-------------------------------------------------
-- Position: its own anchor, same lock rule as the roll frames
-------------------------------------------------
local function GetAnchor()
    if anchor then return anchor end
    anchor = CreateFrame("Frame", "CleanLootResultsAnchor", UIParent)
    anchor:SetSize(1, 1)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    local p = CL.db and CL.db.resultsPoint
    if p then
        anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        -- left of the roll frames, which are centred
        anchor:SetPoint("TOPLEFT", UIParent, "CENTER", -430, 150)
    end
    return anchor
end

local function SavePosition()
    local point, _, relPoint, x, y = anchor:GetPoint()
    if CL.db then CL.db.resultsPoint = { point, relPoint, x, y } end
end

-- Movable when the roll frames are, or while a simulated result is on screen.
function Results.CanMove()
    if CL.RollFrames.CanMove() then return true end
    for _, c in ipairs(active) do
        if c.simulated then return true end
    end
    return false
end

function Results.ResetPosition()
    if CL.db then CL.db.resultsPoint = nil end
    local a = GetAnchor()
    a:ClearAllPoints()
    a:SetPoint("TOPLEFT", UIParent, "CENTER", -430, 150)
    Results.Layout()
end

-------------------------------------------------
-- Text helpers
-------------------------------------------------
local function ShortName(name)
    if type(name) ~= "string" then return "?" end
    return name:match("^([^%-]+)") or name
end

local function Hex(r, g, b)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- The class colour of a name: the game's own table first, its colour API second,
-- grey when the class is not known (an unreadable value, a missing entry).
local function ClassColor(class)
    if type(class) == "string" then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if type(c) ~= "table" and C_ClassColor and C_ClassColor.GetClassColor then
            local ok, color = pcall(C_ClassColor.GetClassColor, class)
            if ok then c = color end
        end
        if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
            return c.r, c.g, c.b
        end
    end
    return 0.8, 0.8, 0.8
end

-- The roll type as the game's own button picture: dice for Need, coin for Greed.
local ICONS = {
    [CL.ROLL.NEED] = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    [CL.ROLL.GREED] = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
}

-- "<dice> 57", the picture alone when the game gave no number, the plain word for a
-- type without a picture, or nil when it gave neither.
local function RollText(rollType, value)
    local icon = rollType and ICONS[rollType]
    local label = icon and ("|T%s:16:16:0:-2|t"):format(icon) or (rollType and CL.ROLL_NAME[rollType])
    if label and value then return ("%s %s"):format(label, tostring(value)) end
    return label
end

local function WinnerLine(w)
    local roll = RollText(w.type, w.value)
    local who = w.isSelf and (GOLD .. "You|r") or (Hex(ClassColor(w.class)) .. ShortName(w.name) .. "|r")
    if roll then return ("%s won with %s"):format(who, roll) end
    return ("%s won"):format(who)
end

-- Your own roll, when you are not the winner: always shown, passed or not.
local function MeLine(me)
    if not me then return nil end
    if me.type == CL.ROLL.PASS then return "|cffb3b3b3You passed|r" end
    local roll = RollText(me.type, me.value)
    if not roll then return "|cffb3b3b3You did not roll|r" end
    if me.value then return ("You rolled %s"):format(roll) end
    return ("You chose %s"):format(roll)
end

-------------------------------------------------
-- Cards
-------------------------------------------------
local function ShowTooltip(card)
    local res = card.result
    if not res then return end
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    local r, g, b = CL.QualityColor(res.quality)
    GameTooltip:AddLine(res.name or "?", r, g, b)
    for _, e in ipairs(res.rolls) do
        local nr, ng, nb = ClassColor(e.class)
        local who = ShortName(e.name)
        if e.isSelf then nr, ng, nb, who = 1, 0.82, 0, "You" end
        local roll = RollText(e.type, e.value) or "?"
        if e.isWinner then roll = GOLD .. roll .. "|r" end
        GameTooltip:AddDoubleLine(who, roll, nr, ng, nb, 1, 1, 1)
    end
    if res.passes > 0 then
        GameTooltip:AddLine(("%d passed"):format(res.passes), 0.6, 0.6, 0.6)
    end
    if card.sample then
        GameTooltip:AddLine("Drag to move. Right-click when done.", 1, 1, 1)
    end
    GameTooltip:Show()
end

local function CreateCard()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(CARD_W, CARD_H)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.04, 0.04, 0.04, 0.9)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(32, 32)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local function Line(font, y)
        local fs = f:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 6, y)
        fs:SetSize(CARD_W - 58, 13)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    f.name = Line("GameFontNormal", -1)
    f.winner = Line("GameFontHighlightSmall", -17)
    f.me = Line("GameFontHighlightSmall", -30)

    f:SetScript("OnEnter", function(self)
        self.hover = true
        if self.age > SHOW_FOR then self.age = SHOW_FOR - 2 end  -- caught while fading
        self:SetAlpha(1)
        ShowTooltip(self)
    end)
    f:SetScript("OnLeave", function(self)
        self.hover = nil
        GameTooltip:Hide()
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then Results.Remove(self) end
    end)
    f:SetScript("OnDragStart", function(self)
        if not Results.CanMove() then return end
        self.dragging = true
        GetAnchor():StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = nil
        GetAnchor():StopMovingOrSizing()
        SavePosition()
    end)
    f:SetScript("OnUpdate", function(self, elapsed)
        if self.hover or self.dragging or self.sample then return end
        self.age = self.age + (elapsed or 0)
        if self.age <= SHOW_FOR then return end
        local alpha = 1 - (self.age - SHOW_FOR) / FADE_FOR
        if alpha <= 0 then
            Results.Remove(self)
        else
            self:SetAlpha(alpha)
        end
    end)
    return f
end

-------------------------------------------------
-- "Waiting on rolls": a small card while some roll still waits for somebody; hover it
-- for the items, how many players have not rolled on each, and who
-------------------------------------------------
local MAX_WAIT_NAMES = 30
local waitEntries = {}   -- what the tooltip lists now
local waitQueued         -- a refresh is already scheduled
local waitTicking        -- the periodic look at the card is running
-- A roll cannot be waited on for longer than it lasts (three minutes at most, plus
-- a margin). A drop still undecided after that never got its winner -- you left
-- the zone before answering, say -- and must not keep the card up for ever.
local WAIT_MAX = 240

-- The rolls still waiting for somebody, oldest first:
--   { { key, name, quality, pending = { { name, class, isSelf }, ... } }, ... }
-- Real drops come from the loot history through the rolls being followed (so a roll
-- you have already answered still counts, you included while you have not answered),
-- simulated ones from the simulator.
local function WaitingEntries()
    local keys = {}
    local now = GetTime()
    for key, since in pairs(open) do
        if not shown[key] and now - since <= WAIT_MAX then keys[#keys + 1] = { key = key, since = since } end
    end
    table.sort(keys, function(a, b)
        if a.since ~= b.since then return a.since < b.since end
        return tostring(a.key) < tostring(b.key)
    end)
    local list = {}
    for _, k in ipairs(keys) do
        local e = CL.API.GetWaiting(k.key)
        if e and #e.pending > 0 then list[#list + 1] = e end
    end
    if CL.Sim and CL.Sim.Waiting then
        for _, e in ipairs(CL.Sim.Waiting()) do
            if #e.pending > 0 then list[#list + 1] = e end
        end
    end
    return list
end

-- "Aludra, Baric, You": class colours, you in gold, the very long lists cut short.
local function WaitNames(pending)
    local parts = {}
    for i, p in ipairs(pending) do
        if i > MAX_WAIT_NAMES then
            parts[#parts + 1] = ("|cffb3b3b3+%d more|r"):format(#pending - MAX_WAIT_NAMES)
            break
        end
        if p.isSelf then
            parts[#parts + 1] = GOLD .. "You|r"
        else
            parts[#parts + 1] = Hex(ClassColor(p.class)) .. ShortName(p.name) .. "|r"
        end
    end
    return table.concat(parts, ", ")
end

-- One block per item: its name (quality colour) and how many players wait, then who.
local function ShowWaitingTooltip(card)
    if #waitEntries == 0 then return end
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Waiting on rolls", 1, 1, 1)
    for _, e in ipairs(waitEntries) do
        local r, g, b = CL.QualityColor(e.quality)
        local n = #e.pending
        GameTooltip:AddDoubleLine(e.name or "?", n == 1 and "1 player" or ("%d players"):format(n),
            r, g, b, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(WaitNames(e.pending), 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function CreateWaitCard()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(CARD_W, WAIT_H)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.04, 0.04, 0.04, 0.9)
    f:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:Hide()

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(16, 16)
    f.icon:SetPoint("LEFT", f, "LEFT", 8, 0)
    f.icon:SetTexture("Interface\\ICONS\\INV_Misc_PocketWatch_02")  -- the clock of the roll frames
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetText("Waiting on rolls")

    f:SetScript("OnEnter", function(self) ShowWaitingTooltip(self) end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnDragStart", function(self)
        if not Results.CanMove() then return end
        self.dragging = true
        GetAnchor():StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = nil
        GetAnchor():StopMovingOrSizing()
        SavePosition()
    end)
    return f
end

local function RefreshWaitingNow()
    local entries = {}
    if CL.db and CL.db.showWaiting then entries = WaitingEntries() end
    waitEntries = entries
    if #entries == 0 then
        if waitCard and waitCard:IsShown() then
            if GameTooltip:IsShown() and GameTooltip:IsOwned(waitCard) then GameTooltip:Hide() end
            waitCard:Hide()
            Results.Layout()
        end
        return
    end
    waitCard = waitCard or CreateWaitCard()
    local wasShown = waitCard:IsShown()
    waitCard:Show()
    if not wasShown then Results.Layout() end
    -- keep a tooltip that is open in step with the votes
    if GameTooltip:IsShown() and GameTooltip:IsOwned(waitCard) then ShowWaitingTooltip(waitCard) end
    -- no event ends a roll that was abandoned: look again from time to time
    if not waitTicking then
        waitTicking = true
        C_Timer.After(15, function()
            waitTicking = nil
            RefreshWaitingNow()
        end)
    end
end

-- Show the card while some roll still waits for somebody, hide it otherwise (or when
-- the option is off). Votes come in bursts: refreshes are merged into one a moment
-- later, unless `now`.
function Results.RefreshWaiting(now)
    if now then
        waitQueued = nil
        RefreshWaitingNow()
        return
    end
    if waitQueued then return end
    waitQueued = true
    C_Timer.After(0.1, function()
        waitQueued = nil
        RefreshWaitingNow()
    end)
end

function Results.WaitingShown()
    return waitCard ~= nil and waitCard:IsShown()
end

function Results.WaitCard()
    return waitCard
end

-- What the tooltip lists now (see WaitingEntries).
function Results.Waiting()
    return waitEntries
end

-- After a loading screen (a teleport, an instance exit): the rolls that are no longer
-- running for you and have no winner will not get one in this zone -- stop waiting
-- for them. `isLive(key)` says whether a roll we still show belongs to that drop.
function Results.ForgetAbandoned(isLive)
    local dropped = false
    for key in pairs(open) do
        if not isLive(key) then open[key] = nil dropped = true end
    end
    if dropped then Results.RefreshWaiting(true) end
end

-- Stop following every roll (a clean slate; the tests use it between scenarios).
function Results.ForgetRolls()
    for key in pairs(open) do open[key] = nil end
    for key in pairs(shown) do shown[key] = nil end
    Results.RefreshWaiting(true)
end

-- The popup stacks its own way: its own setting, else the roll frames' direction.
function Results.Direction()
    local db = CL.db
    return (db and (db.resultsDirection or db.growDirection)) or "DOWN"
end

function Results.SetDirection(direction)
    CL.db.resultsDirection = direction
    Results.Layout()
end

function Results.Layout()
    local grow = Results.Direction()
    local scale = (CL.db and CL.db.frameScale) or CL.DEFAULT_SCALE
    local base = GetAnchor()
    local prev
    -- the "waiting on rolls" card opens the stack
    if waitCard and waitCard:IsShown() then
        local corner = grow == "UP" and "BOTTOMLEFT" or "TOPLEFT"
        waitCard:SetScale(scale)
        waitCard:ClearAllPoints()
        waitCard:SetPoint(corner, base, corner, 0, 0)
        prev = waitCard
    end
    for _, f in ipairs(active) do
        f:SetScale(scale)
        f:ClearAllPoints()
        if not prev then
            f:SetPoint(grow == "UP" and "BOTTOMLEFT" or "TOPLEFT", base, grow == "UP" and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
        elseif grow == "UP" then
            f:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, SPACING)
        else
            f:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -SPACING)
        end
        prev = f
    end
end

function Results.Remove(card)
    for i, c in ipairs(active) do
        if c == card then table.remove(active, i) break end
    end
    card.result, card.hover, card.dragging, card.sample = nil, nil, nil, nil
    if GameTooltip:IsShown() and GameTooltip:IsOwned(card) then GameTooltip:Hide() end
    card:Hide()
    free[#free + 1] = card
    Results.Layout()
end

function Results.Clear()
    for i = #active, 1, -1 do Results.Remove(active[i]) end
end

function Results.ActiveCount()
    return #active
end

function Results.GetCard(index)
    return active[index]
end

-- Put a result on screen (also what the simulator calls). Returns the card, or
-- nil when the popup is off or there is nothing to say.
function Results.Show(res, simulated, sample)
    if not (sample or (CL.db and CL.db.showResults)) then return nil end
    if type(res) ~= "table" or not res.winner then return nil end

    while #active >= MAX_CARDS do Results.Remove(active[1]) end
    local card = table.remove(free) or CreateCard()
    active[#active + 1] = card

    card.result, card.age, card.simulated = res, 0, simulated and true or nil
    card.sample = sample and true or nil
    card.hover, card.dragging = nil, nil
    card:SetAlpha(1)

    local r, g, b = CL.QualityColor(res.quality)
    card.icon:SetTexture(res.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    card.name:SetText(res.name or "?")
    card.name:SetTextColor(r, g, b)
    card.winner:SetText(WinnerLine(res.winner))
    if not res.winner.class and not sample then
        CL.Debug("result %s: no class for %s (unreadable?), its name stays grey", tostring(res.key), tostring(res.winner.name))
    end

    local me = (not res.winner.isSelf) and MeLine(res.me) or nil
    card.me:SetText(me or "")
    card:SetHeight(me and CARD_H_ME or CARD_H)

    if res.winner.isSelf then
        card:SetBackdropBorderColor(1, 0.82, 0, 1)  -- you won it
    else
        card:SetBackdropBorderColor(r, g, b, 1)
    end

    card:Show()
    Results.Layout()
    return card
end

-- Items the popup speaks about: from the start of their roll until a while after
-- the result. Blizzard's "You won" toast for such an item is redundant (Toasts.lua
-- can hide exactly those). Keyed by the item's plain lower-case name.
local covered = {}   -- name -> time until which it counts as covered

local function PlainName(name)
    name = CL.Plain(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|H.-|h", ""):gsub("|h", ""):gsub("|r", "")
    name = name:gsub("[%[%]]", ""):match("^%s*(.-)%s*$")
    return name ~= "" and name:lower() or nil
end

function Results.Cover(name, seconds)
    local n = PlainName(name)
    if not n then return end
    local untilTime = GetTime() + (seconds or 30)
    if (covered[n] or 0) < untilTime then covered[n] = untilTime end
end

function Results.Covers(name)
    if not (CL.db and CL.db.showResults) then return false end
    local n = PlainName(name)
    local untilTime = n and covered[n]
    return untilTime ~= nil and GetTime() < untilTime
end

-- A card to place the popup with: it stays until right-clicked and moves whatever
-- the lock says. Its text is made up.
function Results.ToggleSample()
    for _, c in ipairs(active) do
        if c.sample then
            Results.Remove(c)
            return false
        end
    end
    Results.Show({
        name = "Drag to place the popup", quality = 4, rolls = {}, passes = 0,
        texture = "Interface\\Icons\\INV_Misc_QuestionMark",
        winner = { name = "Example", class = "MAGE", type = CL.ROLL.GREED, value = 57 },
        me = { type = CL.ROLL.GREED, value = 6 },
    }, true, true)
    return true
end

-------------------------------------------------
-- From the game's events
-------------------------------------------------
-- A roll is followed from the moment we know of it until the game names a winner.
-- Several signals feed that, none of them trusted alone: START_LOOT_ROLL (the roll
-- is ours), a history update that still shows no winner, and LOOT_ROLLS_COMPLETE.
-- The complete event's key can be unreadable (a secret value), so a sweep over all
-- the rolls being followed does the looking, not that one key.
-- (open: lootListKey -> time first known, the rolls waiting for their winner; shown:
-- lootListKey -> true once announced -- both declared at the top, the waiting card reads them)
local OPEN_FOR = 900  -- seconds; a roll lasts three minutes at most

local function Announce(key, res)
    open[key] = nil
    shown[key] = true
    Results.Cover(res.name, 30)   -- the winner's toast comes with the result
    Results.RefreshWaiting()      -- decided: no longer waited for
    local card = Results.Show(res)
    CL.Debug("result %s: %s won %s -> %s", tostring(key), tostring(res.winner.name), tostring(res.name),
        card and "card shown" or "popup is off")
end

-- Look at one roll. `mayOpen`: a roll seen undecided is now one to follow.
local function Consider(key, mayOpen)
    if shown[key] then return end
    local res = CL.API.GetResult(key)
    if not res then
        CL.Debug("result %s: the loot history does not know this drop", tostring(key))
        return
    end
    if res.winner then
        if open[key] then Announce(key, res) end
    elseif res.allPassed then
        open[key] = nil   -- the chat already says everyone passed
    elseif mayOpen and not open[key] then
        open[key] = GetTime()
    end
end

local function Sweep()
    local now = GetTime()
    for key, since in pairs(open) do
        if now - since > OPEN_FOR then
            open[key] = nil
        else
            Consider(key, false)
        end
    end
end

-- START_LOOT_ROLL gave us the roll's key.
function Results.Watch(key)
    key = CL.Plain(key)
    if key ~= nil and not shown[key] then open[key] = open[key] or GetTime() end
    Results.RefreshWaiting()
end

-- LOOT_ROLLS_COMPLETE: the roll is over. The winner reaches the history a moment
-- later, so look again shortly (the history's own update also looks).
function Results.OnComplete(key)
    key = CL.Plain(key)
    CL.Debug("result: rolls complete, key %s%s", key ~= nil and tostring(key) or "unreadable",
        (InCombatLockdown and InCombatLockdown()) and " (in combat)" or "")
    if key ~= nil and not shown[key] then open[key] = open[key] or GetTime() end
    Sweep()
    for _, delay in ipairs(RETRY_DELAYS) do C_Timer.After(delay, Sweep) end
    Results.RefreshWaiting()
end

-- LOOT_HISTORY_UPDATE_DROP: somebody's choice or the result changed.
function Results.OnDropUpdate(key)
    key = CL.Plain(key)
    if key == nil then
        Sweep()
    else
        Consider(key, true)
    end
    -- every choice somebody makes lands here: the waiting card follows it, also for a
    -- roll you have already answered (it has no frame any more)
    Results.RefreshWaiting()
end
