-- The window of a player while the master looter runs a loot session: the item in play, the
-- time left, everybody's rolls as they come in, and the buttons to roll yourself (MS 1-100,
-- OS 1-99, Other 1-90, or pass). It is driven by the messages of the master looter's CleanLoot
-- (Comm.lua) and reads the rolls from the game's own /roll messages, with the same rules as the
-- master looter (RollBook.lua), so the list is the one he sees.
--
-- Nothing here is needed to take part: a player without CleanLoot just types /roll 100, 99 or 90
-- as the chat says.

local _, CL = ...

local PW = {}
CL.PlayerWindow = PW

local Book = CL.RollBook
local Comm = CL.Comm

local WIN_W, ROWS, ROW_H = 340, 8, 20
local FLAT = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
    bgFile = FLAT, edgeFile = FLAT, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local GREY = "|cffb3b3b3"
local GOLD = "|cffffd100"
local GREEN = "|cff40ff40"
local HIDE_AFTER = 8        -- seconds the window stays once the session is over
local LATE = 3              -- seconds past zero without a "closed" message before it is shown closed anyway

local S      -- the session as a player sees it, nil when none
local win

function PW.State() return S end
function PW.Window() return win end

-- Forget the session and close the window (master loot switched off, a new start).
function PW.Reset()
    S = nil
    if win then win:Hide() end
end

local function Enabled()
    return CL.db and CL.db.sessionJoin ~= false and CL.MasterLoot.Enabled()
end

local function ShortName(name)
    return type(name) == "string" and (name:match("^([^%-]+)") or name) or "?"
end

local function MyName()
    local name = type(UnitName) == "function" and UnitName("player")
    return type(name) == "string" and name or nil
end

local function IsMe(name)
    local me = MyName()
    return me ~= nil and CL.MasterLoot.SameName(name, me)
end

-- Quality of an item link, from its colour.
local COLOR_QUALITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }
local function QualityOf(link)
    if type(link) ~= "string" then return 1 end
    local n = link:match("|cnIQ(%d)")
    if n then return tonumber(n) end
    local hex = link:match("|cff(%x%x%x%x%x%x)")
    return hex and COLOR_QUALITY[hex:lower()] or 3
end

local function IconOf(link)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(instant) == "function" and link then
        local ok, _, _, _, _, icon = pcall(instant, link)
        if ok and icon ~= nil then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-------------------------------------------------
-- The window
-------------------------------------------------
local function Refresh()
    if not win or not S then return end
    local lot = S.lot
    if lot then
        win.icon:SetTexture(IconOf(lot.link))
        win.name:SetText((lot.name or "?") .. ((lot.copies or 1) > 1 and (" x" .. lot.copies) or ""))
        local r, g, b = CL.QualityColor(lot.quality)
        win.name:SetTextColor(r, g, b)
        win.count:SetText(GREY .. ("Item %d of %d"):format(S.index or 0, S.total or 0) .. "|r")
    else
        win.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        win.name:SetText("Loot session")
        win.name:SetTextColor(1, 0.82, 0)
        win.count:SetText(GREY .. ("%d item%s"):format(S.count or 0, (S.count or 0) == 1 and "" or "s") .. "|r")
    end
    win.title:SetText("Loot session: " .. ShortName(S.sender))

    local phase = S.phase
    local status, timeText = "", ""
    if phase == "rolling" then
        timeText = S.paused and (GREY .. "paused|r") or ("%d s"):format(math.max(0, math.ceil(S.remaining)))
        if S.book.restrict then
            status = GOLD .. ("Re-roll: only the tied players roll (%s).|r"):format(Book.LABEL[S.book.restrict.cat])
        else
            status = GREY .. "Roll 1-100 MS, 1-99 OS or 1-90 Other, or pass.|r"
        end
    elseif phase == "closed" then
        status = GOLD .. "Rolls closed. The master looter decides.|r"
    elseif phase == "skipped" then
        status = GREY .. "Skipped.|r"
    elseif phase == "over" then
        status = GREEN .. "The session is over.|r"
    elseif phase == "cancelled" then
        status = GREY .. "The session was cancelled.|r"
    else
        status = GREY .. "Waiting for the first item.|r"
    end
    if S.won then status = GREEN .. "You won it! Come and trade the master looter.|r" end
    win.time:SetText(timeText)
    win.status:SetText(status)

    -- the rolls, best first, with who has a copy
    local ranking = Book.Ranking(S.book)
    for i, row in ipairs(win.rows) do
        local e = ranking[i]
        if e then
            local me = IsMe(e.name)
            row.who:SetText(me and "You" or ShortName(e.name))
            row.who:SetTextColor(me and 1 or 0.9, me and 0.82 or 0.9, me and 0 or 0.9)
            local won
            for _, a in ipairs(S.awards) do
                if CL.MasterLoot.SameName(a.name, e.name) then won = true end
            end
            row.roll:SetText((won and (GREEN .. "won|r  ") or "")
                .. CL.SessionRun.CatColor(e.cat) .. ("%s %d"):format(Book.LABEL[e.cat], e.value) .. "|r"
                .. (e.tied and (GREY .. "  tie|r") or ""))
            row:Show()
        else
            row:Hide()
        end
    end

    -- the buttons
    local canRoll = phase == "rolling" and not S.paused
    for cat = 1, 3 do
        local button = win.buttons[cat]
        local allowed = canRoll and (not S.book.restrict or S.book.restrict.cat == cat)
        if allowed then button:Enable() else button:Disable() end
    end
    if canRoll then win.buttons.pass:Enable() else win.buttons.pass:Disable() end
end

local function Create()
    local f = CreateFrame("Frame", "CleanLootPlayerSession", UIParent, "BackdropTemplate")
    f:SetSize(WIN_W, 100 + ROWS * ROW_H + 40)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
    f:SetBackdropBorderColor(0.4, 0.33, 0.12, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if point then CL.db.playerSessionPoint = { point, relPoint, x, y } end
    end)
    local p = CL.db.playerSessionPoint
    if type(p) == "table" and p[1] then
        f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", -260, 60)
    end

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    local x = close:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    x:SetPoint("CENTER")
    x:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)

    local iconButton = CreateFrame("Button", nil, f)
    iconButton:SetSize(36, 36)
    iconButton:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
    f.icon = iconButton:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    iconButton:SetScript("OnEnter", function(self)
        if not (S and S.lot) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok = S.lot.link and pcall(GameTooltip.SetHyperlink, GameTooltip, S.lot.link)
        if not ok then GameTooltip:SetText(S.lot.name or "?") end
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.name = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 56, -32)
    f.name:SetWidth(WIN_W - 150)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.count = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.count:SetPoint("TOPLEFT", f, "TOPLEFT", 56, -50)
    f.time = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.time:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -32)
    f.time:SetJustifyH("RIGHT")
    f.status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.status:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -74)
    f.status:SetWidth(WIN_W - 24)
    f.status:SetJustifyH("LEFT")

    f.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(WIN_W - 20, ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(94 + (i - 1) * ROW_H))
        row.who = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.who:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.who:SetWidth(150)
        row.who:SetJustifyH("LEFT")
        row.who:SetWordWrap(false)
        row.roll = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.roll:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.roll:SetJustifyH("RIGHT")
        f.rows[i] = row
    end

    f.buttons = {}
    local function Button(key, label, width, x0, onClick, tip)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x0, 12)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.buttons[key] = b
    end
    local names = { "Main spec", "Off spec", "Other" }
    for cat = 1, 3 do
        Button(cat, ("%s%s 1-%d|r"):format(CL.SessionRun.CatColor(cat), Book.LABEL[cat], Book.RANGE[cat]), 90,
            12 + (cat - 1) * 96, function() PW.Roll(cat) end,
            names[cat] .. ": rolls 1-" .. Book.RANGE[cat] .. ", like typing /roll " .. Book.RANGE[cat] .. ".")
    end
    Button("pass", "Pass", 44, 12 + 3 * 96, function() PW.Pass() end, "Take your roll back: you are out for this item.")

    f:SetScript("OnUpdate", function(_, elapsed)
        if not S then return end
        if S.phase == "rolling" and not S.paused then
            S.remaining = S.remaining - elapsed
            -- the master looter's "closed" never came: show it closed anyway
            if S.remaining < -LATE then
                S.phase = "closed"
            end
        elseif S.hideIn then
            S.hideIn = S.hideIn - elapsed
            if S.hideIn <= 0 then
                f:Hide()
                S = nil
                return
            end
        end
        S.tick = (S.tick or 0) + elapsed
        if S.tick >= 0.25 then
            S.tick = 0
            Refresh()
        end
    end)
    f:Hide()
    return f
end

local function Show()
    win = win or Create()
    win:Show()
    Refresh()
end

-------------------------------------------------
-- What the player does
-------------------------------------------------
function PW.Roll(cat)
    if not (S and S.phase == "rolling" and not S.paused) then return false end
    local high = Book.RANGE[cat]
    if not high or (S.book.restrict and S.book.restrict.cat ~= cat) then return false end
    local ok, err = pcall(RandomRoll, 1, high)
    if not ok then
        CL.Print("could not roll: " .. tostring(err))
        return false
    end
    return true
end

function PW.Pass()
    if not (S and S.phase == "rolling") then return false end
    local me = MyName()
    if me then
        for name in pairs(S.book.rolls) do
            if CL.MasterLoot.SameName(name, me) then Book.Pass(S.book, name) end
        end
    end
    Comm.Send("Q", S.sid, S.index or 0)
    Refresh()
    return true
end

-------------------------------------------------
-- What the master looter says
-------------------------------------------------
-- Only the master looter is believed, and only when this part is on.
local function Accept(sender)
    if not Enabled() then return false end
    if CL.SessionRun.Active() then return false end   -- you run your own session
    return Comm.FromMasterLooter(sender)
end

local function Fresh(sid, sender)
    S = { sid = sid, sender = sender, book = Book.New(), awards = {}, phase = "waiting", remaining = 0 }
end

local function Mine(fields, sender)
    return S and S.sid == fields[1] and CL.MasterLoot.SameName(sender, S.sender)
end

Comm.On("S", function(f, sender)
    -- version, sid, count, seconds
    if tonumber(f[1]) ~= Comm.VERSION or not Accept(sender) then return end
    Fresh(f[2], sender)
    S.count, S.duration = tonumber(f[3]), tonumber(f[4])
    Refresh()
end)

Comm.On("I", function(f, sender)
    -- sid, index, total, copies, link, seconds
    if not Accept(sender) then return end
    if not (S and S.sid == f[1]) then Fresh(f[1], sender) end   -- joined after the start
    local link = f[5]
    S.index, S.total = tonumber(f[2]), tonumber(f[3])
    S.lot = { link = link, name = type(link) == "string" and link:match("|h%[(.-)%]|h") or "?",
        copies = tonumber(f[4]) or 1, quality = QualityOf(link) }
    S.book = Book.New()
    S.awards = {}
    S.won, S.hideIn = nil, nil
    S.phase, S.paused = "rolling", false
    S.remaining = tonumber(f[6]) or S.duration or 15
    Show()
end)

Comm.On("P", function(f, sender)
    -- sid, index, paused, seconds
    if not Mine(f, sender) then return end
    S.paused = f[3] == "1"
    S.remaining = tonumber(f[4]) or S.remaining
    Refresh()
end)

Comm.On("R", function(f, sender)
    -- sid, index, names, cat, seconds
    if not Mine(f, sender) then return end
    local names = {}
    for name in (f[3] or ""):gmatch("([^,]+)") do names[name] = true end
    S.book = Book.New()
    S.book.restrict = { names = names, cat = tonumber(f[4]) or 1 }
    S.phase, S.paused = "rolling", false
    S.remaining = tonumber(f[5]) or S.duration or 15
    S.won = nil
    Refresh()
end)

Comm.On("C", function(f, sender)
    if not Mine(f, sender) then return end
    S.phase, S.remaining = "closed", 0
    Refresh()
end)

Comm.On("W", function(f, sender)
    -- sid, index, name, cat, value
    if not Mine(f, sender) then return end
    S.awards[#S.awards + 1] = { name = f[3], cat = tonumber(f[4]), value = tonumber(f[5]) }
    if IsMe(f[3]) then S.won = true end
    Refresh()
end)

Comm.On("X", function(f, sender)
    -- sid, index, name
    if not Mine(f, sender) then return end
    for i = #S.awards, 1, -1 do
        if CL.MasterLoot.SameName(S.awards[i].name, f[3]) then
            table.remove(S.awards, i)
            break
        end
    end
    if IsMe(f[3]) then S.won = nil end
    Refresh()
end)

Comm.On("Z", function(f, sender)
    if not Mine(f, sender) then return end
    S.phase = "skipped"
    Refresh()
end)

local function Over(phase)
    return function(f, sender)
        if not Mine(f, sender) then return end
        S.phase, S.hideIn = phase, HIDE_AFTER
        Refresh()
    end
end
Comm.On("E", Over("over"))
Comm.On("K", Over("cancelled"))

-- The rolls come from the game's /roll messages, like for the master looter.
local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:SetScript("OnEvent", function(_, _, text)
    if not (S and S.phase == "rolling" and not S.paused) then return end
    local name, value, low, high = CL.SessionRun.ParseRoll(CL.Plain(text))
    if name and Book.Add(S.book, name, value, low, high) then Refresh() end
end)
