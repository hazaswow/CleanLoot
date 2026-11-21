-- Loot session window (/cll session): the items of the master looter's bags that can be handed
-- out, oldest first, each with a box to leave it out of the session (all are offered by
-- default) and the time left to trade it. The master looter's session itself (the timed
-- rolls, one item after the other) comes on top of this list.

local _, CL = ...

local Session = {}
CL.Session = Session

local WIN_W, ROW_H, ROWS = 420, 26, 12
local HEAD_H = 62
local FOOT_H = 40
local FLAT = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
    bgFile = FLAT, edgeFile = FLAT, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local GREY = "|cffb3b3b3"
local GOLD = "|cffffd100"

local win

local function Quality(quality)
    return CL.QualityColor(quality)
end

local function IconOf(entry)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(instant) == "function" and entry.link then
        local ok, _, _, _, _, icon = pcall(instant, entry.link)
        if ok and icon ~= nil then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Refresh()
    if not win or not win:IsShown() then return end
    local list = CL.LootPool.List()
    local maxOffset = math.max(0, #list - ROWS)
    if win.offset > maxOffset then win.offset = maxOffset end

    local offered = 0
    for _, e in ipairs(list) do if not e.excluded then offered = offered + 1 end end

    for i, row in ipairs(win.rows) do
        local e = list[i + win.offset]
        if e then
            row.entry = e
            row.check:SetChecked(not e.excluded)
            row.icon:SetTexture(IconOf(e))
            row.name:SetText(e.name)
            local r, g, b = Quality(e.quality)
            row.name:SetTextColor(r, g, b)
            if e.remaining then
                local low = e.remaining < 1200   -- under 20 minutes
                row.time:SetText((low and "|cffff5555" or GREY) .. CL.LootPool.FormatTime(e.remaining) .. "|r")
            else
                row.time:SetText(GREY .. "no limit|r")
            end
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end

    if #list == 0 then
        local ML = CL.MasterLoot
        win.sub:SetText(GREY .. ((ML.IsMasterLooter() and ML.Enabled())
            and "Nothing to hand out: no tradable item in your bags."
            or "Only the master looter's bags are followed.") .. "|r")
    else
        win.sub:SetText(("%s%d of %d item%s offered. Untick one to leave it out.|r"):format(GREY, offered, #list,
            #list == 1 and "" or "s"))
    end
    win:SetHeight(HEAD_H + math.min(#list, ROWS) * ROW_H + FOOT_H)
end
Session.Refresh = Refresh

local function Create()
    local f = CreateFrame("Frame", "CleanLootSession", UIParent, "BackdropTemplate")
    f:SetSize(WIN_W, HEAD_H + FOOT_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
    f:SetBackdropBorderColor(0.4, 0.33, 0.12, 1)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if point then CL.db.sessionPoint = { point, relPoint, x, y } end
    end)
    f:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, self.offset - delta)
        Refresh()
    end)
    f.offset = 0
    local p = CL.db.sessionPoint
    if type(p) == "table" and p[1] then
        f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    f.title:SetText("Loot session")
    f.sub = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -38)
    f.sub:SetJustifyH("LEFT")

    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    local x = close:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    x:SetPoint("CENTER")
    x:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close

    f.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(WIN_W - 20, ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(HEAD_H + (i - 1) * ROW_H))
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(24, 24)
        row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.check:SetScript("OnClick", function(self)
            if row.entry then CL.LootPool.SetExcluded(row.entry.guid, not self:GetChecked()) end
        end)
        row.iconButton = CreateFrame("Button", nil, row)
        row.iconButton:SetSize(20, 20)
        row.iconButton:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
        row.icon = row.iconButton:CreateTexture(nil, "ARTWORK")
        row.icon:SetAllPoints()
        row.iconButton:SetScript("OnEnter", function(self)
            if not row.entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = row.entry.link and pcall(GameTooltip.SetHyperlink, GameTooltip, row.entry.link)
            if not ok then GameTooltip:SetText(row.entry.name or "?") end
            GameTooltip:Show()
        end)
        row.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.iconButton, "RIGHT", 8, 0)
        row.name:SetWidth(WIN_W - 190)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.time = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.time:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.time:SetJustifyH("RIGHT")
        f.rows[i] = row
    end

    local refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refresh:SetSize(90, 22)
    refresh:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        CL.LootPool.Scan()
        Refresh()
    end)
    f.refresh = refresh
    f:Hide()
    return f
end

function Session.Window() return win end

function Session.Open()
    win = win or Create()
    win:Show()
    -- the list is kept while you are the master looter; a look now covers the rest
    if CL.LootPool.Active() then CL.LootPool.Scan() end
    Refresh()
end

function Session.Toggle()
    if win and win:IsShown() then win:Hide() else Session.Open() end
end
