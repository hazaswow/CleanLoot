-- Master loot: the roll result window and the hand-out.
--
-- With a master looter the game runs the rolls (a "roll request") but names no winner:
-- the master looter hands the item out. So when the rolls are over everybody in the
-- group gets a window for the item with every roll and the name of who made it, best
-- first. The master looter can click a name to give that player the item: a small
-- confirmation opens at the mouse, then the item is handed out and the group is told
-- ("[CleanLoot] [item] given to X for roll Greed 44", in /p, or /ra in a raid).
--
-- The rolls come from the loot history (CL.API.GetResult); the hand-out is the game's
-- own GiveMasterLoot, used on the slot of the boss's open loot window (the same calls
-- the master-loot addons make).

local _, CL = ...

local ML = {}
CL.MasterLoot = ML

local WIN_W, ROW_H, ROWS = 280, 20, 12
local HEAD_H = 54          -- the item, then a line of help, before the rows
local FOOT_H = 24
local GAP = 8              -- between two windows
local MAX_WINDOWS = 4
local GIVE_WAIT = 2        -- seconds the game has to confirm a hand-out
local FLAT = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
    bgFile = FLAT, edgeFile = FLAT, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local GOLD = "|cffffd100"
local GREY = "|cffb3b3b3"
local GREEN = "|cff40ff40"

local METHODS = { [0] = "freeforall", [1] = "roundrobin", [2] = "master", [3] = "group",
    [4] = "needbeforegreed", [5] = "personalloot" }

-------------------------------------------------
-- Who is the master looter
-------------------------------------------------
-- "master", "group"... and, for a master looter, his party (0 = you) or raid index.
function ML.LootMethod()
    local method, party, raid
    local get = rawget(_G, "GetLootMethod")
    local ok
    if type(get) == "function" then
        ok, method, party, raid = pcall(get)
    elseif C_PartyInfo and type(C_PartyInfo.GetLootMethod) == "function" then
        ok, method, party, raid = pcall(C_PartyInfo.GetLootMethod)
    end
    if not ok then return nil end
    if type(method) == "number" then method = METHODS[method] end
    if type(method) ~= "string" then return nil end
    return method:lower(), party, raid
end

function ML.IsMasterLoot()
    return ML.LootMethod() == "master"
end

function ML.IsMasterLooter()
    local method, party, raid = ML.LootMethod()
    if method ~= "master" then return false end
    if party == 0 then return true end
    if type(raid) == "number" and raid > 0 and type(UnitIsUnit) == "function" then
        local ok, same = pcall(UnitIsUnit, "raid" .. raid, "player")
        return ok and same == true
    end
    return false
end

-------------------------------------------------
-- Names and links
-------------------------------------------------
local function Norm(name)
    return (tostring(name):lower():gsub("%-.*$", ""))
end

-- "Cline" and "Cline Gloomhaunt" are the same player on Forever: a first name matches the full one.
local function SameName(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    a, b = Norm(a), Norm(b)
    return a == b or a:find(b .. " ", 1, true) == 1 or b:find(a .. " ", 1, true) == 1
end

-- The item as the chat takes it: the classic coloured link, built from the item string.
local function ChatLink(res)
    local link = res.link
    local itemString = type(link) == "string" and link:match("|H(item:[^|]+)|h")
    local name = type(link) == "string" and link:match("|h%[(.-)%]|h") or res.name
    if not (itemString and name) then return res.name or "?" end
    local r, g, b = CL.QualityColor(res.quality)
    return ("|cff%02x%02x%02x|H%s|h[%s]|h|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5), itemString, name)
end

local function RollWord(entry)
    local word = CL.ROLL_NAME[entry.type] or "roll"
    if entry.value then return ("%s %s"):format(word, tostring(entry.value)) end
    return word
end

-------------------------------------------------
-- Handing the item out
-------------------------------------------------
local function FindSlot(link)
    local want = CL.AutoRoll.ItemID(link)
    if not want then return nil end
    local count = type(GetNumLootItems) == "function" and GetNumLootItems()
    if type(count) ~= "number" then return nil end
    for slot = 1, count do
        local slotLink = GetLootSlotLink(slot)
        if type(slotLink) == "string" and CL.AutoRoll.ItemID(slotLink) == want then return slot end
    end
    return nil
end

local function FindCandidate(slot, name)
    for index = 1, 40 do
        local candidate = GetMasterLootCandidate(slot, index)
        if type(candidate) == "string" and SameName(candidate, name) then return index end
    end
    return nil
end

local function Channel()
    if type(IsInRaid) == "function" and IsInRaid() == true then return "RAID" end
    if type(IsInGroup) == "function" and IsInGroup() == true then return "PARTY" end
    return nil
end

local pending   -- the hand-out the game has not confirmed yet: { win, entry, slot, token }

-- The hand-out went through: say so on the window and to the group.
local function Done(win, entry)
    win.given = entry.name
    win.givenTo = entry
    ML.Refresh(win)
    local short = entry.name:match("^([^%-]+)") or entry.name
    local message = ("[CleanLoot] %s given to %s for roll %s"):format(ChatLink(win.res), short, RollWord(entry))
    local channel = (not win.simulated) and CL.db.masterAnnounce and Channel() or nil
    if channel then
        local ok, err = pcall(SendChatMessage, message, channel)
        if not ok then CL.Print("could not announce it: " .. tostring(err)) end
    else
        print(message)
    end
    CL.Debug("master loot: %s given to %s (%s)", tostring(win.res.name), tostring(entry.name), RollWord(entry))
    C_Timer.After(20, function() if win.given == entry.name then ML.Close(win) end end)
end

local function Failed(why)
    if not pending then return end
    pending = nil
    CL.Print("the item was not handed out: " .. why)
end

-- Give the item of `win` to `entry` (one row of its rolls).
function ML.Give(win, entry)
    if win.given then return end
    if win.simulated then
        Done(win, entry)
        return
    end
    if pending then
        CL.Print("another hand-out is still in progress, try again in a moment.")
        return
    end
    local slot = FindSlot(win.res.link)
    if not slot then
        CL.Print("the item is not in an open loot window: open the boss's loot, then click the name again.")
        return
    end
    local index = FindCandidate(slot, entry.name)
    if not index then
        CL.Print(("%s is not on the loot window's list of players who can receive it."):format(entry.name))
        return
    end
    local token = {}
    pending = { win = win, entry = entry, slot = slot, token = token }
    local ok, err = pcall(GiveMasterLoot, slot, index)
    if not ok then
        Failed("GiveMasterLoot failed: " .. tostring(err))
        return
    end
    -- success is the slot clearing (or the "receives loot" line); silence is a refusal
    -- (full bags, too far away, the loot window closed...)
    C_Timer.After(GIVE_WAIT, function()
        if pending and pending.token == token then
            Failed("the game did not confirm it (full bags? too far away? the loot window closed?).")
        end
    end)
end

local function Confirmed()
    if not pending then return end
    local win, entry = pending.win, pending.entry
    pending = nil
    Done(win, entry)
end

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_SLOT_CLEARED")
events:RegisterEvent("CHAT_MSG_LOOT")
events:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PARTY_LOOT_METHOD_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        -- Gargul is loaded after us and sets up late: look a few seconds after
        C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 6 or 1.5, function()
            if CL.db and ML.MaybeAskGargul then ML.MaybeAskGargul() end
        end)
        return
    end
    if not pending then return end
    if event == "LOOT_SLOT_CLEARED" then
        if arg1 == pending.slot then Confirmed() end
    else
        local line = CL.Plain(arg1)
        if type(line) ~= "string" then return end
        local who = pending.entry
        if who.isSelf and line:find("^You receive loot") then
            Confirmed()
        elseif line:find("receives loot", 1, true) and line:find(who.name:match("^([^%-]+)") or who.name, 1, true) then
            Confirmed()
        end
    end
end)

-------------------------------------------------
-- The confirmation, at the mouse
-------------------------------------------------
local confirm

local function CreateConfirm()
    local f = CreateFrame("Frame", "CleanLootGiveConfirm", UIParent, "BackdropTemplate")
    f:SetSize(270, 86)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    f:SetBackdropBorderColor(0.9, 0.75, 0.2, 1)

    f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.text:SetPoint("TOP", f, "TOP", 0, -12)
    f.text:SetWidth(250)
    f.text:SetJustifyH("CENTER")
    f.detail = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.detail:SetPoint("TOP", f, "TOP", 0, -32)

    f.give = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.give:SetSize(100, 24)
    f.give:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 12)
    f.give:SetText("Give")
    f.give:SetScript("OnClick", function()
        local win, entry = f.win, f.entry
        f:Hide()
        if win and entry then ML.Give(win, entry) end
    end)
    f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancel:SetSize(100, 24)
    f.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 12)
    f.cancel:SetText("Cancel")
    f.cancel:SetScript("OnClick", function() f:Hide() end)

    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "CleanLootGiveConfirm") end
    f:Hide()
    return f
end

local function PlaceAtCursor(f)
    f:ClearAllPoints()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if type(x) == "number" and type(y) == "number" and type(scale) == "number" and scale > 0 then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function ML.Confirm() return confirm end

local function CanGive(win)
    return not win.given and (win.simulated or ML.IsMasterLooter())
end

-- A click on a name: ask before giving.
function ML.Ask(win, entry)
    if not (win and entry and CanGive(win)) then return end
    confirm = confirm or CreateConfirm()
    confirm.win, confirm.entry = win, entry
    local rr, gg, bb = CL.QualityColor(win.res.quality)
    local who = CL.Results.Hex(CL.Results.ClassColor(entry.class)) .. (entry.name:match("^([^%-]+)") or entry.name) .. "|r"
    confirm.text:SetText(("Give %s%s|r to %s?"):format(CL.Results.Hex(rr, gg, bb), win.res.name or "?", who))
    confirm.detail:SetText("Roll: " .. (CL.Results.RollText(entry.type, entry.value) or "?"))
    PlaceAtCursor(confirm)
    confirm:Show()
end

-------------------------------------------------
-- The window
-------------------------------------------------
local free, active = {}, {}

local function Layout()
    for i, w in ipairs(active) do
        w:ClearAllPoints()
        if i == 1 then
            local p = CL.db.masterPoint
            if type(p) == "table" and p[1] then
                w:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
            else
                w:SetPoint("CENTER", UIParent, "CENTER", -310, 40)
            end
        else
            w:SetPoint("TOPLEFT", active[i - 1], "TOPRIGHT", GAP, 0)
        end
    end
end

function ML.Close(win)
    if not win then return end
    win:Hide()
    for i, w in ipairs(active) do
        if w == win then table.remove(active, i) break end
    end
    free[#free + 1] = win
    if confirm and confirm.win == win then confirm:Hide() end
    Layout()
end

function ML.CloseAll()
    while #active > 0 do ML.Close(active[#active]) end
    if confirm then confirm:Hide() end
end

function ML.Windows() return active end

-- Names and rolls into the rows, and the window's height to fit them.
function ML.Refresh(win)
    local res = win.res
    local rolls = res.rolls
    local top = rolls[1]
    -- the best roll, and anybody who tied with it
    local tiedWithTop = 0
    for _, e in ipairs(rolls) do
        if top and e.type == top.type and e.value == top.value then tiedWithTop = tiedWithTop + 1 end
    end
    local maxOffset = math.max(0, #rolls - ROWS)
    if win.offset > maxOffset then win.offset = maxOffset end

    local canGive = CanGive(win)
    for i, row in ipairs(win.rows) do
        local e = rolls[i + win.offset]
        if e then
            row.entry = e
            local nr, ng, nb = CL.Results.ClassColor(e.class)
            local who = e.isSelf and "You" or CL.Results.ShortName(e.name)
            row.who:SetTextColor(e.isSelf and 1 or nr, e.isSelf and 0.82 or ng, e.isSelf and 0 or nb)
            local best = top and tiedWithTop > 0 and e.type == top.type and e.value == top.value
            row.who:SetText(who .. ((best and tiedWithTop > 1) and (GREY .. "  tie|r") or ""))
            local roll = CL.Results.RollText(e.type, e.value) or "?"
            row.roll:SetText(best and (GOLD .. roll .. "|r") or roll)
            if win.givenTo == e then row.given:Show() else row.given:Hide() end
            row:Show()
            row:EnableMouse(canGive)
        else
            row.entry = nil
            row:Hide()
        end
    end

    local shownRows = math.min(#rolls, ROWS)
    local note = {}
    if (res.passes or 0) > 0 then note[#note + 1] = ("%d passed"):format(res.passes) end
    if (res.noRoll or 0) > 0 then note[#note + 1] = ("%d did not roll"):format(res.noRoll) end
    if #rolls > ROWS then note[#note + 1] = "scroll for more" end
    win.foot:SetText(GREY .. table.concat(note, ", ") .. "|r")
    win.foot:ClearAllPoints()
    win.foot:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -(HEAD_H + shownRows * ROW_H + 6))
    win:SetHeight(HEAD_H + shownRows * ROW_H + FOOT_H)

    if win.given then
        win.sub:SetText(GREEN .. "Given to " .. (win.given:match("^([^%-]+)") or win.given) .. "|r")
    elseif #rolls == 0 then
        win.sub:SetText(GREY .. "Nobody rolled on it.|r")
    elseif canGive then
        win.sub:SetText(GREY .. "Click a name to give the item.|r")
    else
        win.sub:SetText(GREY .. "The master looter gives the item.|r")
    end
end

local function CreateWindow()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(WIN_W, HEAD_H + FOOT_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if active[1] == self then
            local point, _, relPoint, x, y = self:GetPoint()
            if point then CL.db.masterPoint = { point, relPoint, x, y } end
        end
    end)
    f:SetScript("OnMouseWheel", function(self, delta)
        if not self.res then return end
        self.offset = math.max(0, self.offset - delta)
        ML.Refresh(self)
    end)

    local iconButton = CreateFrame("Button", nil, f)
    iconButton:SetSize(32, 32)
    iconButton:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    f.icon = iconButton:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    iconButton:SetScript("OnEnter", function(self)
        local res = f.res
        if not res then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local ok = res.link and pcall(GameTooltip.SetHyperlink, GameTooltip, res.link)
        if not ok then
            local r, g, b = CL.QualityColor(res.quality)
            GameTooltip:SetText(res.name or "?", r, g, b)
        end
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.name = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -12)
    f.name:SetSize(WIN_W - 50 - 30, 14)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.sub = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -30)
    f.sub:SetJustifyH("LEFT")

    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    local x = close:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    x:SetPoint("CENTER")
    x:SetText("X")
    close:SetScript("OnClick", function() ML.Close(f) end)
    f.close = close

    f.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetSize(WIN_W - 16, ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(HEAD_H + (i - 1) * ROW_H))
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.1)
        row.hl:Hide()
        row.who = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.who:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.who:SetWidth(150)
        row.who:SetJustifyH("LEFT")
        row.who:SetWordWrap(false)
        row.roll = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.roll:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.roll:SetJustifyH("RIGHT")
        row.given = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.given:SetPoint("RIGHT", row.roll, "LEFT", -8, 0)
        row.given:SetText(GREEN .. "given|r")
        row.given:Hide()
        row:SetScript("OnEnter", function(self) if self.entry and CanGive(f) then self.hl:Show() end end)
        row:SetScript("OnLeave", function(self) self.hl:Hide() end)
        row:SetScript("OnClick", function(self)
            if self.entry then ML.Ask(f, self.entry) end
        end)
        f.rows[i] = row
    end
    f.foot = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.foot:SetJustifyH("LEFT")
    f:Hide()
    return f
end

-- Open the window for a result: { key, link, name, quality, texture, rolls, passes, noRoll }.
function ML.Show(res, simulated)
    if type(res) ~= "table" then return nil end
    while #active >= MAX_WINDOWS do ML.Close(active[1]) end
    local win = table.remove(free) or CreateWindow()
    active[#active + 1] = win

    win.res, win.simulated = res, simulated and true or nil
    win.given, win.givenTo, win.offset = nil, nil, 0
    local r, g, b = CL.QualityColor(res.quality)
    win.icon:SetTexture(res.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    win.name:SetText(res.name or "?")
    win.name:SetTextColor(r, g, b)
    win:SetBackdropBorderColor(r, g, b, 1)
    ML.Refresh(win)
    Layout()
    win:Show()
    return win
end

-------------------------------------------------
-- Gargul announces hand-outs too
-------------------------------------------------
-- Gargul (the master-loot addon) posts "item awarded to X" in /ra or /p as well. With both
-- on, every hand-out is announced twice, so once, as master looter, CleanLoot asks which
-- one should keep doing it. Gargul's setting is read and set through the Gargul object it
-- opens to other addons (Gargul.Settings:get / :set).
local GARGUL_SETTING = "AwardingLoot.awardMessagesEnabled"

local function GargulObject()
    local g = rawget(_G, "Gargul")
    if type(g) == "table" and type(g.Settings) == "table" and type(g.Settings.get) == "function" then return g end
    return nil
end

-- nil: Gargul is not installed. Otherwise whether its award messages are on.
function ML.GargulAnnounces()
    local g = GargulObject()
    if not g then return nil end
    local ok, value = pcall(g.Settings.get, g.Settings, GARGUL_SETTING)
    if not ok then return true end   -- installed but unreadable: its default is on
    return value ~= false
end

-- Both would announce the same hand-out.
function ML.GargulConflict()
    return CL.db.masterAnnounce == true and ML.GargulAnnounces() == true
end

local gargulBox

local function CreateGargulBox()
    local f = CreateFrame("Frame", "CleanLootGargulChoice", UIParent, "BackdropTemplate")
    f:SetSize(380, 214)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    f:SetBackdropBorderColor(0.9, 0.75, 0.2, 1)

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -12)
    f.title:SetText("CleanLoot and Gargul")
    f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.text:SetPoint("TOP", f, "TOP", 0, -38)
    f.text:SetWidth(340)
    f.text:SetJustifyH("CENTER")
    f.text:SetText("Gargul is installed and announces the items you hand out in the chat, as CleanLoot does: "
        .. "each hand-out would be announced twice. What do you prefer?")

    local function Choice(label, y, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(320, 24)
        b:SetPoint("TOP", f, "TOP", 0, y)
        b:SetText(label)
        b:SetScript("OnClick", function()
            CL.db.gargulAsked = true
            f:Hide()
            onClick()
            if CL.Options and CL.Options.Refresh then CL.Options.Refresh() end
        end)
        return b
    end
    f.both = Choice("Keep both", -98, function()
        CL.Print("both keep announcing the hand-outs.")
    end)
    f.mine = Choice("Turn off CleanLoot's announcements", -128, function()
        CL.db.masterAnnounce = false
        CL.Print("CleanLoot no longer announces hand-outs (Gargul does).")
    end)
    f.theirs = Choice("Turn off Gargul's award messages", -158, function()
        local g = GargulObject()
        local ok = g and type(g.Settings.set) == "function" and pcall(g.Settings.set, g.Settings, GARGUL_SETTING, false)
        if ok then
            CL.Print("Gargul's award messages are off (CleanLoot announces the hand-outs).")
        else
            CL.Print("could not change Gargul's setting: turn off its Award messages in its settings (Awarding loot).")
        end
    end)
    f.note = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.note:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    f.note:SetText("Ask again later with /cll gargul.")

    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "CleanLootGargulChoice") end
    f:Hide()
    return f
end

function ML.GargulBox() return gargulBox end

-- `force` (/cll gargul, the options button): ask even when it was answered before.
function ML.AskGargul(force)
    if ML.GargulAnnounces() == nil then
        if force then CL.Print("Gargul is not installed (or not loaded).") end
        return false
    end
    if not ML.GargulConflict() then
        if force then
            CL.Print(("Gargul's award messages are %s, CleanLoot's announcements are %s: nothing is announced twice."):format(
                ML.GargulAnnounces() and "on" or "off", CL.db.masterAnnounce and "on" or "off"))
        end
        return false
    end
    if not force and CL.db.gargulAsked then return false end
    gargulBox = gargulBox or CreateGargulBox()
    gargulBox:Show()
    return true
end

-- Asked once, to the master looter, and not in the middle of a fight.
function ML.MaybeAskGargul()
    if CL.db.gargulAsked or not ML.IsMasterLooter() then return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown() == true then return false end
    return ML.AskGargul(false)
end

-------------------------------------------------
-- When the rolls are over
-------------------------------------------------
local handled = {}   -- lootListKey -> true: its window was opened (or there was nothing to show)

-- LOOT_ROLLS_COMPLETE. In master loot the game decides nobody: show the rolls.
-- The history is brought up to date a moment after the event, so look then.
function ML.OnComplete(key)
    key = CL.Plain(key)
    if key == nil or handled[key] then return end
    C_Timer.After(0.6, function()
        if handled[key] or not ML.IsMasterLoot() then return end
        local res = CL.API.GetResult(key)
        if not res or res.winner or res.allPassed then return end   -- the game named one: Results shows it
        handled[key] = #res.rolls > 0 and true or "empty"   -- "empty": nobody had rolled yet, a later update may bring rolls
        CL.Results.Close(key)   -- nobody is waited for any more
        if not CL.db.masterWindow then return end
        CL.Debug("master loot: rolls over for %s, %d roll(s)", tostring(res.name), #res.rolls)
        if #res.rolls > 0 then ML.Show(res) end
        ML.MaybeAskGargul()
    end)
end

-- LOOT_HISTORY_UPDATE_DROP: a roll that landed after the window opened (or after "complete")
-- joins the window; one that had no rolls yet gets its window now.
function ML.OnDropUpdate(key)
    key = CL.Plain(key)
    if key == nil or not handled[key] then return end
    local res = CL.API.GetResult(key)
    if not res or res.winner then return end
    for _, win in ipairs(active) do
        if win.res.key == key and not win.simulated then
            if not win.given then
                win.res = res
                ML.Refresh(win)
            end
            return
        end
    end
    if handled[key] == "empty" and #res.rolls > 0 and CL.db.masterWindow and ML.IsMasterLoot() then
        handled[key] = true
        ML.Show(res)
    end
end

-- /cll sim master: a result window with a made-up group, to see it and try the click.
function ML.Simulate()
    local players = {
        { "Aludra", "MAGE" }, { "Baric", "WARRIOR" }, { "Cyndra", "PRIEST" }, { "Dorun", "HUNTER" },
        { "Eluned", "DRUID" }, { "Farrow", "ROGUE" },
    }
    local rolls = {}
    for i, p in ipairs(players) do
        rolls[#rolls + 1] = { name = p[1], class = p[2], type = i <= 2 and CL.ROLL.NEED or CL.ROLL.GREED,
            value = math.random(1, 100), isSelf = false, isWinner = false }
    end
    rolls[#rolls + 1] = { name = "You", class = "SHAMAN", type = CL.ROLL.GREED, value = math.random(1, 100),
        isSelf = true, isWinner = false }
    table.sort(rolls, function(a, b)
        if a.type ~= b.type then return a.type < b.type end
        return a.value > b.value
    end)
    return ML.Show({ key = "sim", name = "Sim Rare Blade", quality = 3, rolls = rolls, passes = 2, noRoll = 1,
        texture = "Interface\\Icons\\INV_Sword_04" }, true)
end
