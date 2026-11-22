-- The disenchanter: the master looter asks the group who can disenchant ("Who can disenchant?
-- Type de in the chat"), the enchanters answer with a short keyword (optionally with their
-- skill: "de 300"), and the master looter picks the one who will do it. Items nobody wants (and
-- any item the master looter chooses) are then given to him: he comes to trade the master looter
-- for them, disenchants, and either keeps the materials or trades them back to be shared out.
--
-- The designated name is saved (CleanLootDB.deName) so it stays from one evening to the next.

local _, CL = ...

local DE = {}
CL.Disenchant = DE

local ML = CL.MasterLoot

local ASK_FOR = 180          -- seconds the master looter keeps listening after asking
local MAX_CANDIDATES = 12

DE.candidates = {}           -- { { name, skill, at }, ... } in the order they answered
DE.askedAt = nil             -- GetTime() of the question while it is open

local function Changed()
    if DE.window and DE.window:IsShown() and DE.Refresh then DE.Refresh() end
end

local function ShortName(name)
    return type(name) == "string" and (name:match("^([^%-]+)") or name) or "?"
end

-------------------------------------------------
-- The keyword and the designated player
-------------------------------------------------
-- The short word enchanters answer with: lower case, no spaces (default "de").
function DE.Keyword()
    local k = CL.db and CL.db.deKeyword
    if type(k) ~= "string" then return "de" end
    k = k:gsub("%s", ""):lower()
    return k ~= "" and k or "de"
end

function DE.Name()
    local n = CL.db and CL.db.deName
    return type(n) == "string" and n ~= "" and n or nil
end

-- Does the designated one keep the materials (true) or trade them back (false)?
function DE.Keeps()
    return CL.db and CL.db.deKeep == true
end

-- What the designated player is told in a whisper for an item he is to disenchant.
function DE.WhisperText(link)
    if DE.Keeps() then
        return ("[CleanLoot] You are the disenchanter: come trade me for %s, disenchant it, the materials are yours."):format(link)
    end
    return ("[CleanLoot] You are the disenchanter: come trade me for %s, disenchant it, then trade me the materials."):format(link)
end

-- Make `name` the disenchanter and tell the group.
function DE.Designate(name)
    if type(name) ~= "string" then return false end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false end
    CL.db.deName = name
    DE.askedAt = nil
    ML.Say(("[CleanLoot] %s is the designated disenchanter."):format(ShortName(name)))
    Changed()
    if CL.Session and CL.Session.Refresh then CL.Session.Refresh() end
    return true
end

function DE.Clear()
    if not DE.Name() then return false end
    CL.db.deName = nil
    Changed()
    if CL.Session and CL.Session.Refresh then CL.Session.Refresh() end
    return true
end

-------------------------------------------------
-- Asking, and hearing the answers
-------------------------------------------------
function DE.IsAsking()
    if DE.askedAt and GetTime() - DE.askedAt > ASK_FOR then DE.askedAt = nil end
    return DE.askedAt ~= nil
end

-- Ask the group (/ra, or /p, with the /rw option): the master looter, or you alone to try it.
function DE.Ask()
    if not ML.Enabled() then
        CL.Print("the master loot features are off (Options > Master loot).")
        return false
    end
    local inGroup = type(IsInGroup) == "function" and IsInGroup() == true
    if inGroup and not ML.IsMasterLooter() then
        CL.Print("only the master looter can ask who can disenchant.")
        return false
    end
    local kw = DE.Keyword()
    DE.candidates = {}
    DE.askedAt = GetTime()
    ML.Say(("[CleanLoot] Who can disenchant? Type \"%s\" in the chat if you have Enchanting (\"%s 300\" with your skill if you like)."):format(kw, kw))
    Changed()
    return true
end

function DE.StopAsking()
    if not DE.askedAt then return false end
    DE.askedAt = nil
    Changed()
    return true
end

-- Is this chat line an answer? (the keyword alone, or followed by a number: the skill)
local function ReadAnswer(text)
    if type(text) ~= "string" then return false end
    text = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local kw = DE.Keyword()
    if text == kw then return true, nil end
    local skill = text:match("^" .. kw:gsub("%W", "%%%0") .. "%s+(%d+)$")
    if skill then return true, tonumber(skill) end
    return false
end

-- A line of the group's chat (or a whisper). Only while the question is open.
function DE.Hear(text, sender)
    if not DE.IsAsking() then return false end
    if type(sender) ~= "string" or sender == "" then return false end
    local ok, skill = ReadAnswer(text)
    if not ok then return false end
    for _, c in ipairs(DE.candidates) do
        if ML.SameName(c.name, sender) then
            c.skill = skill or c.skill
            Changed()
            return true
        end
    end
    if #DE.candidates >= MAX_CANDIDATES then return false end
    DE.candidates[#DE.candidates + 1] = { name = sender, skill = skill, at = GetTime() }
    Changed()
    return true
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, _, text, sender)
    if not (CL.db and DE.askedAt) then return end
    DE.Hear(CL.Plain(text), CL.Plain(sender))
end)

-------------------------------------------------
-- The window
-------------------------------------------------
local WIN_W, ROW_H, ROWS = 340, 24, 8
local FLAT = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
    bgFile = FLAT, edgeFile = FLAT, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local GREY = "|cffb3b3b3"
local GOLD = "|cffffd100"
local GREEN = "|cff40ff40"

function DE.Refresh()
    local win = DE.window
    if not win or not win:IsShown() then return end
    local name = DE.Name()
    if name then
        win.current:SetText(("Disenchanter: %s%s|r"):format(GREEN, ShortName(name)))
        win.clear:Enable()
    else
        win.current:SetText("Disenchanter: " .. GREY .. "nobody yet|r")
        win.clear:Disable()
    end
    if DE.IsAsking() then
        win.sub:SetText(GOLD .. ("Listening: players answer \"%s\" in the chat."):format(DE.Keyword()) .. "|r")
        win.stop:Enable()
    else
        win.sub:SetText(GREY .. "Ask the group, then click a name to designate it." .. "|r")
        win.stop:Disable()
    end
    for i, row in ipairs(win.rows) do
        local c = DE.candidates[i]
        if c then
            row.candidate = c
            row.who:SetText(ShortName(c.name))
            row.skill:SetText(c.skill and (GREY .. "skill " .. c.skill .. "|r") or "")
            row:Show()
        else
            row.candidate = nil
            row:Hide()
        end
    end
end

local function CreateWindow()
    local f = CreateFrame("Frame", "CleanLootDisenchant", UIParent, "BackdropTemplate")
    f:SetSize(WIN_W, 130 + ROWS * ROW_H + 40)
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
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetPoint("CENTER", UIParent, "CENTER", 260, 40)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    title:SetText("Disenchanter")
    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    local x = close:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    x:SetPoint("CENTER")
    x:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)

    f.current = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.current:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    f.sub = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -60)
    f.sub:SetWidth(WIN_W - 28)
    f.sub:SetJustifyH("LEFT")

    f.ask = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.ask:SetSize(150, 22)
    f.ask:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -82)
    f.ask:SetText("Ask who can disenchant")
    f.ask:SetScript("OnClick", function() DE.Ask() end)
    f.stop = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.stop:SetSize(70, 22)
    f.stop:SetPoint("LEFT", f.ask, "RIGHT", 6, 0)
    f.stop:SetText("Stop")
    f.stop:SetScript("OnClick", function() DE.StopAsking() end)
    f.clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.clear:SetSize(80, 22)
    f.clear:SetPoint("LEFT", f.stop, "RIGHT", 6, 0)
    f.clear:SetText("No one")
    f.clear:SetScript("OnClick", function() DE.Clear() end)

    f.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetSize(WIN_W - 20, ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(112 + (i - 1) * ROW_H))
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.1)
        row.hl:Hide()
        row.who = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.who:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.skill = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.skill:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row:SetScript("OnEnter", function(self) self.hl:Show() end)
        row:SetScript("OnLeave", function(self) self.hl:Hide() end)
        row:SetScript("OnClick", function(self)
            local c = self.candidate
            if not c then return end
            ML.Confirmation(("Make %s the disenchanter?"):format(ShortName(c.name)), "The group is told.",
                function() DE.Designate(c.name) end, "Designate")
        end)
        f.rows[i] = row
    end

    local label = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    label:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 16)
    label:SetText("Or by name:")
    f.box = CreateFrame("EditBox", nil, f)
    f.box:SetSize(150, 22)
    f.box:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 84, 10)
    f.box:SetFontObject("ChatFontNormal")
    f.box:SetAutoFocus(false)
    f.box:SetTextInsets(4, 4, 0, 0)
    local bg = f.box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    local function ByName()
        local text = f.box:GetText()
        if text == nil or text:match("^%s*$") then return end
        if DE.Designate(text) then f.box:SetText("") f.box:ClearFocus() end
    end
    f.box:SetScript("OnEnterPressed", ByName)
    f.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.byName = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.byName:SetSize(80, 22)
    f.byName:SetPoint("LEFT", f.box, "RIGHT", 6, 0)
    f.byName:SetText("Designate")
    f.byName:SetScript("OnClick", ByName)
    f:Hide()
    return f
end

function DE.Open()
    DE.window = DE.window or CreateWindow()
    DE.window:Show()
    DE.Refresh()
end

function DE.Toggle()
    if DE.window and DE.window:IsShown() then DE.window:Hide() else DE.Open() end
end

-- /cll de [ask | stop | clear | <name>]
function DE.Command(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local key = arg:lower()
    if key == "" then
        DE.Toggle()
    elseif key == "ask" then
        DE.Open()
        DE.Ask()
    elseif key == "stop" then
        if not DE.StopAsking() then CL.Print("not asking.") end
    elseif key == "clear" or key == "none" then
        if DE.Clear() then CL.Print("no disenchanter designated any more.") else CL.Print("nobody was designated.") end
    else
        DE.Designate(arg)
    end
end
