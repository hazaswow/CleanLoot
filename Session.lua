-- The loot session window (/cll session). Two views of the same window:
--
--   * the list: the items of the master looter's bags that can be handed out, oldest first,
--     each with a box to leave it out of the session (all are offered by default) and the time
--     left to trade it, with the buttons that start a session;
--   * the session: the item in play, the timer, the rolls as they come in (best first), and the
--     controls (pause, +10 s, skip, cancel, re-roll after a tie). When the master looter picks
--     the winner, a click on a name asks for confirmation at the mouse.
--
-- The session itself is in SessionRun.lua.

local _, CL = ...

local Session = {}
CL.Session = Session

local WIN_W, ROW_H, ROWS = 420, 26, 12
local HEAD_H = 62
local FOOT_H = 40
local RUN_ROWS, RUN_ROW_H = 10, 22
local RUN_HEAD_H = 84
local RUN_FOOT_H = 48
local FLAT = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
    bgFile = FLAT, edgeFile = FLAT, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local GREY = "|cffb3b3b3"
local GOLD = "|cffffd100"
local GREEN = "|cff40ff40"

local win

local function IconOf(entry)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(instant) == "function" and entry.link then
        local ok, _, _, _, _, icon = pcall(instant, entry.link)
        if ok and icon ~= nil then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Run() return CL.SessionRun end

-------------------------------------------------
-- The list view
-------------------------------------------------
local function RefreshList()
    local list = CL.LootPool.List()
    local maxOffset = math.max(0, #list - ROWS)
    if win.offset > maxOffset then win.offset = maxOffset end

    local offered = 0
    for _, e in ipairs(list) do if not e.excluded and not e.awardedTo then offered = offered + 1 end end

    for i, row in ipairs(win.rows) do
        local e = list[i + win.offset]
        if e then
            row.entry = e
            row.check:SetChecked(not e.excluded)
            row.icon:SetTexture(IconOf(e))
            row.name:SetText(e.name)
            local r, g, b = CL.QualityColor(e.quality)
            row.name:SetTextColor(r, g, b)
            if e.awardedTo then
                row.time:SetText(GREEN .. "to " .. (e.awardedTo:match("^([^%-]+)") or e.awardedTo) .. "|r")
            elseif e.remaining then
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
            or "Only the master looter's bags are followed (Refresh looks now).") .. "|r")
    else
        win.sub:SetText(("%s%d of %d item%s offered. Untick one to leave it out.|r"):format(GREY, offered, #list,
            #list == 1 and "" or "s"))
    end
    local ok = Run().CanStart()
    if ok then win.start:Enable() else win.start:Disable() end
    win:SetHeight(HEAD_H + math.min(#list, ROWS) * ROW_H + FOOT_H)
end

-------------------------------------------------
-- The session view
-------------------------------------------------
local function IsMe(name)
    local me = type(UnitName) == "function" and UnitName("player")
    return type(me) == "string" and CL.MasterLoot.SameName(name, me)
end

local function RefreshRun()
    local state = Run().State()
    local item = state.item
    if item then
        win.runIcon:SetTexture(IconOf(item))
        win.runName:SetText(item.name or "?")
        local r, g, b = CL.QualityColor(item.quality)
        win.runName:SetTextColor(r, g, b)
    end
    win.runCount:SetText(("%sItem %d of %d|r"):format(GREY, state.index, #state.queue))

    local phase = state.phase
    if phase == "rolling" then
        win.runTime:SetText(("%d s"):format(math.ceil(state.remaining)))
        win.runStatus:SetText(GREY .. "Players roll 1-100 MS, 1-99 OS, 1-90 Other.|r")
    elseif phase == "paused" then
        win.runTime:SetText(GREY .. "paused|r")
        win.runStatus:SetText(GREY .. "Paused: the timer is stopped.|r")
    elseif phase == "decide" then
        win.runTime:SetText("")
        if #(state.ranking or {}) == 0 then
            win.runStatus:SetText(GREY .. "Nobody rolled.|r")
        elseif state.tie then
            win.runStatus:SetText(GOLD .. "Tie: click a name to pick, or re-roll between the tied.|r")
        else
            win.runStatus:SetText(GOLD .. "Rolls closed: click a name to assign the item.|r")
        end
    else
        win.runTime:SetText("")
        win.runStatus:SetText(GREEN .. (state.awardedText or "") .. "|r " .. GREY ..
            ("Next in %d s.|r"):format(math.ceil(state.wait or 0)))
    end
    if state.test then win.runStatus:SetText(win.runStatus:GetText() .. " " .. GREY .. "(test: nothing is sent)|r") end

    local ranking = (phase == "decide" and state.ranking) or select(1, Run().Ranking())
    local canChoose = Run().Can("choose")
    for i, row in ipairs(win.runRows) do
        local e = ranking[i]
        if e then
            row.entry = e
            row.who:SetText(IsMe(e.name) and "You" or e.name)
            row.who:SetTextColor(IsMe(e.name) and 1 or 0.9, IsMe(e.name) and 0.82 or 0.9, IsMe(e.name) and 0 or 0.9)
            local roll = ("%s %d"):format(Run().Label(e.cat), e.value)
            local top = ranking[1]
            local best = top and e.cat == top.cat and e.value == top.value
            row.roll:SetText((best and GOLD or "") .. roll .. (best and "|r" or "") .. (e.tied and (GREY .. "  tie|r") or ""))
            row:Show()
            row:EnableMouse(canChoose and true or false)
        else
            row.entry = nil
            row:Hide()
        end
    end

    for action, button in pairs(win.controls) do
        if Run().Can(action) then button:Enable() else button:Disable() end
    end
    -- Pause and Resume share a place
    if Run().Can("resume") then
        win.controls.pause:Hide()
        win.controls.resume:Show()
    else
        win.controls.resume:Hide()
        win.controls.pause:Show()
    end
end

-------------------------------------------------
-- Showing the right view
-------------------------------------------------
local function SetView(running)
    for _, region in ipairs(win.listParts) do
        if running then region:Hide() end
    end
    for _, region in ipairs(win.runParts) do
        if running then region:Show() else region:Hide() end
    end
    win.title:SetText(running and "Loot session: running" or "Loot session")
end

local function Refresh()
    if not win or not win:IsShown() then return end
    if Run().Active() then
        SetView(true)
        win:SetHeight(RUN_HEAD_H + RUN_ROWS * RUN_ROW_H + RUN_FOOT_H)
        RefreshRun()
    else
        SetView(false)
        for _, row in ipairs(win.rows) do row:Hide() end
        win.sub:Show()
        win.refresh:Show()
        win.start:Show()
        win.test:Show()
        RefreshList()
    end
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
        if Run().Active() then return end
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

    ---------------- the list view
    f.rows = {}
    f.listParts = {}
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

    f.refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.refresh:SetSize(90, 22)
    f.refresh:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    f.refresh:SetText("Refresh")
    f.refresh:SetScript("OnClick", function()
        CL.LootPool.Scan()
        Refresh()
    end)
    f.start = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.start:SetSize(120, 22)
    f.start:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    f.start:SetText("Start session")
    f.start:SetScript("OnClick", function() Run().Start() Refresh() end)
    f.start:SetScript("OnEnter", function(self)
        local ok, why = Run().CanStart()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if ok then
            GameTooltip:AddLine("Offer the items one after the other, " .. Run().Duration() .. " seconds each.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("Cannot start: " .. tostring(why), 1, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    f.start:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.test = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.test:SetSize(90, 22)
    f.test:SetPoint("RIGHT", f.start, "LEFT", -6, 0)
    f.test:SetText("Test it")
    f.test:SetScript("OnClick", function() Run().StartTest() Refresh() end)
    f.test:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("A session with made-up players. Nothing is sent to the group.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.test:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ---------------- the session view
    f.runParts = {}
    local function Part(region)
        f.runParts[#f.runParts + 1] = region
        region:Hide()
        return region
    end
    local iconButton = Part(CreateFrame("Button", nil, f))
    iconButton:SetSize(36, 36)
    iconButton:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    f.runIcon = iconButton:CreateTexture(nil, "ARTWORK")
    f.runIcon:SetAllPoints()
    iconButton:SetScript("OnEnter", function(self)
        local state = Run().State()
        if not (state and state.item) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok = state.item.link and pcall(GameTooltip.SetHyperlink, GameTooltip, state.item.link)
        if not ok then GameTooltip:SetText(state.item.name or "?") end
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.runName = Part(f:CreateFontString(nil, "ARTWORK", "GameFontNormal"))
    f.runName:SetPoint("TOPLEFT", f, "TOPLEFT", 58, -40)
    f.runName:SetWidth(WIN_W - 170)
    f.runName:SetJustifyH("LEFT")
    f.runName:SetWordWrap(false)
    f.runCount = Part(f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"))
    f.runCount:SetPoint("TOPLEFT", f, "TOPLEFT", 58, -58)
    f.runTime = Part(f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"))
    f.runTime:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -40)
    f.runTime:SetJustifyH("RIGHT")
    f.runStatus = Part(f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"))
    f.runStatus:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -80)
    f.runStatus:SetWidth(WIN_W - 28)
    f.runStatus:SetJustifyH("LEFT")

    f.runRows = {}
    for i = 1, RUN_ROWS do
        local row = Part(CreateFrame("Button", nil, f))
        row:SetSize(WIN_W - 20, RUN_ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(RUN_HEAD_H + 14 + (i - 1) * RUN_ROW_H))
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.1)
        row.hl:Hide()
        row.who = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.who:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.who:SetWidth(200)
        row.who:SetJustifyH("LEFT")
        row.who:SetWordWrap(false)
        row.roll = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.roll:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.roll:SetJustifyH("RIGHT")
        row:SetScript("OnEnter", function(self) if self.entry and Run().Can("choose") then self.hl:Show() end end)
        row:SetScript("OnLeave", function(self) self.hl:Hide() end)
        row:SetScript("OnClick", function(self)
            local e = self.entry
            if not (e and Run().Can("choose")) then return end
            local state = Run().State()
            CL.MasterLoot.Confirmation(
                ("Assign %s to %s?"):format(state.item.name or "?", e.name),
                ("Roll: %s %d"):format(Run().Label(e.cat), e.value),
                function() Run().Award(e.name) end, "Assign")
        end)
        f.runRows[i] = row
    end

    f.controls = {}
    local function Control(action, label, width, x, onClick, tip)
        local b = Part(CreateFrame("Button", nil, f, "UIPanelButtonTemplate"))
        b:SetSize(width, 22)
        b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 12)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.controls[action] = b
        return b
    end
    Control("pause", "Pause", 72, 12, function() Run().Pause() end, "Stop the timer. The group is told.")
    Control("resume", "Resume", 72, 12, function() Run().Resume() end, "Start the timer again. The group is told.")
    Control("extend", "+10 s", 60, 90, function() Run().Extend() end, "Add ten seconds. The group is told.")
    Control("skip", "Skip", 60, 156, function() Run().Skip() end, "Leave this item unassigned and go on.")
    Control("reroll", "Re-roll", 72, 222, function() Run().Reroll() end, "Only the tied players roll again.")
    Control("cancel", "Cancel", 72, WIN_W - 84, function() Run().Cancel() end, "End the session now. The group is told.")
    f.controls.resume:Hide()

    -- what the list view owns, hidden while a session runs
    f.listParts = { f.sub, f.refresh, f.start, f.test }
    for _, row in ipairs(f.rows) do f.listParts[#f.listParts + 1] = row end
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

-- /cll session [start | test | stop]
function Session.Command(arg)
    arg = (arg or ""):lower()
    if arg == "start" then
        Session.Open()
        Run().Start()
        Refresh()
    elseif arg == "test" then
        Session.Open()
        Run().StartTest()
        Refresh()
    elseif arg == "stop" or arg == "cancel" then
        if not Run().Cancel() then CL.Print("no session is running.") end
    else
        Session.Toggle()
    end
end
