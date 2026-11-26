-- The loot session window (/cll session). One window, three views:
--
--   * the list: the items of the master looter's bags that can be handed out, oldest first,
--     each with a box to leave it out of the session (all are offered by default) and the time
--     left to trade it, with the buttons that start a session;
--   * the session: the item in play, the timer, the rolls as they come in (best first, one
--     colour per kind of roll), the master looter's own roll buttons and the controls (pause,
--     +10 s, skip, cancel, re-roll after a tie);
--   * the changes: a small icon at the side for every item already done; a click goes back to
--     it to take an assignment back, give a copy to one of the rolls, or to anybody by name.
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
local RUN_FOOT_H = 84
local STRIP_MAX, STRIP_ICON = 10, 30
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
    if type(instant) == "function" and entry and entry.link then
        local ok, _, _, _, _, icon = pcall(instant, entry.link)
        if ok and icon ~= nil then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Run() return CL.SessionRun end

local function ShortName(name)
    return type(name) == "string" and (name:match("^([^%-]+)") or name) or "?"
end

local function IsMe(name)
    local me = type(UnitName) == "function" and UnitName("player")
    return type(me) == "string" and CL.MasterLoot.SameName(name, me)
end

local function ItemTooltip(owner, entry)
    if not entry then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = entry.link and pcall(GameTooltip.SetHyperlink, GameTooltip, entry.link)
    if not ok then GameTooltip:SetText(entry.name or "?") end
end

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
                row.time:SetText(GREEN .. "to " .. ShortName(e.awardedTo) .. "|r")
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
-- The rows of rolls (the session and the changes)
-------------------------------------------------
local function RollText(e)
    if not e.cat then return GREY .. "by hand|r" end
    return ("%s%s %d|r"):format(Run().CatColor(e.cat), Run().Label(e.cat), e.value)
end

local function HideRows()
    for _, row in ipairs(win.runRows) do
        row.entry, row.award = nil, nil
        row:Hide()
        row.cancel:Hide()
    end
end

-- The rolls of the item in play.
local function FillLiveRows(state)
    HideRows()
    local phase = state.phase
    local ranking = (phase == "decide" and state.ranking) or select(1, Run().Ranking())
    local canChoose = Run().Can("choose")
    for i, row in ipairs(win.runRows) do
        local e = ranking[i]
        if e then
            row.entry = e
            local me = IsMe(e.name)
            row.who:SetText(me and "You" or e.name)
            row.who:SetTextColor(me and 1 or 0.9, me and 0.82 or 0.9, me and 0 or 0.9)
            row.roll:SetText((e.assigned and (GREEN .. "won|r  ") or "") .. RollText(e)
                .. (e.tied and (GREY .. "  tie|r") or ""))
            row:Show()
            row:EnableMouse((canChoose and not e.assigned) and true or false)
        end
    end
end

-- The rolls of an item already done, and the names given a copy by hand.
local function FillEditRows(hist)
    HideRows()
    local lot = hist.lot
    local canEdit = Run().CanEdit(lot)
    local free = Run().FreeCopies(lot)
    local display = {}
    for _, e in ipairs(hist.ranking or {}) do display[#display + 1] = { entry = e } end
    for _, a in ipairs(Run().AwardsFor(lot)) do
        if not a.entry then display[#display + 1] = { award = a } end   -- given by hand to somebody who did not roll
    end
    for i, row in ipairs(win.runRows) do
        local d = display[i]
        if d then
            local e = d.entry or { name = d.award.winner, assigned = true }
            row.entry, row.award = d.entry, d.award
            if d.entry then
                for _, a in ipairs(Run().AwardsFor(lot)) do
                    if a.entry == d.entry then row.award = a end
                end
            end
            local me = IsMe(e.name)
            row.who:SetText(me and "You" or e.name)
            row.who:SetTextColor(me and 1 or 0.9, me and 0.82 or 0.9, me and 0 or 0.9)
            local assigned = row.award ~= nil
            row.roll:SetText((assigned and (GREEN .. "won|r  ") or "") .. RollText(d.entry or d.award))
            row:Show()
            row:EnableMouse((not assigned and canEdit and free > 0) and true or false)
            if assigned and canEdit then row.cancel:Show() end
        end
    end
end

-------------------------------------------------
-- The session view
-------------------------------------------------
local function Header(item, countText, timeText, statusText)
    if item then
        win.runIcon:SetTexture(IconOf(item))
        win.runName:SetText((item.name or "?") .. ((item.count or 1) > 1 and (" x" .. item.count) or ""))
        local r, g, b = CL.QualityColor(item.quality)
        win.runName:SetTextColor(r, g, b)
    else
        win.runIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        win.runName:SetText("All items done")
        win.runName:SetTextColor(1, 0.82, 0)
    end
    win.runCount:SetText(GREY .. countText .. "|r")
    win.runTime:SetText(timeText or "")
    win.runStatus:SetText(statusText or "")
end

local function RefreshRun()
    local state = Run().State()
    local phase = state.phase
    local count = state.item and ("Item %d of %d"):format(state.index, #state.queue) or ("%d items"):format(#state.queue)
    local status, timeText
    if phase == "rolling" then
        timeText = ("%d s"):format(math.ceil(state.remaining))
        status = GREY .. "Players roll 1-100 MS, 1-99 OS, 1-90 Other. Roll with the buttons below.|r"
    elseif phase == "paused" then
        timeText = GREY .. "paused|r"
        status = GREY .. "Paused: the timer is stopped.|r"
    elseif phase == "decide" then
        timeText = ""
        if #(state.ranking or {}) == 0 then
            status = GREY .. "Nobody rolled.|r"
        elseif state.tie then
            status = GOLD .. (state.need > 1
                and ("Tie for the last %d copies: click names to pick, or re-roll between the tied."):format(state.need)
                or "Tie: click a name to pick, or re-roll between the tied.") .. "|r"
        else
            status = GOLD .. (state.slots > 1
                and ("Rolls closed: click names to assign the %d copies left."):format(state.slots)
                or "Rolls closed: click a name to assign the item.") .. "|r"
        end
    elseif phase == "review" then
        timeText = ("%d s"):format(math.ceil(state.reviewLeft or 0))
        status = GREEN .. "Review: click an icon at the side to change an assignment, then Finish.|r"
    else
        timeText = ""
        status = GREEN .. (state.awardedText or "") .. "|r " .. GREY .. ("Next in %d s.|r"):format(math.ceil(state.wait or 0))
    end
    if state.test then status = status .. " " .. GREY .. "(test: nothing is sent)|r" end
    Header(state.item, count, timeText, status)
    FillLiveRows(state)

    for action, button in pairs(win.controls) do
        if Run().Can(action) then button:Enable() else button:Disable() end
    end
    local review = phase == "review"
    local resume = Run().Can("resume")
    win.controls.pause[(not review and not resume) and "Show" or "Hide"](win.controls.pause)
    win.controls.resume[(not review and resume) and "Show" or "Hide"](win.controls.resume)
    for _, name in ipairs({ "extend", "skip", "reroll", "de" }) do
        win.controls[name][review and "Hide" or "Show"](win.controls[name])
    end
    win.controls.finish[review and "Show" or "Hide"](win.controls.finish)
    for cat, b in pairs(win.rollButtons) do
        if type(cat) == "number" then
            if Run().Can("roll") then b:Enable() else b:Disable() end
        end
    end
    if Run().Can("pass") then win.rollButtons.pass:Enable() else win.rollButtons.pass:Disable() end
end

-------------------------------------------------
-- The changes view
-------------------------------------------------
local function RefreshEdit(state, hist)
    local lot = hist.lot
    local free = Run().FreeCopies(lot)
    local live
    if state.item and (state.phase == "rolling" or state.phase == "paused") then
        live = ("now rolling: item %d (%d s)"):format(state.index, math.ceil(state.remaining))
    elseif state.phase == "review" then
        live = ("session ends in %d s"):format(math.ceil(state.reviewLeft or 0))
    end
    local status
    if not Run().CanEdit(lot) then
        status = GREY .. "This item is being rolled for."
    else
        status = GOLD .. ("Click a name to give it a copy, X to take an assignment back. Free copies: %d."):format(free)
    end
    Header(lot, ("Changing item %d of %d%s"):format(win.editIndex, #state.queue, live and ("  -  " .. live) or ""),
        "", status .. "|r")
    FillEditRows(hist)
    local canEdit = Run().CanEdit(lot) and free > 0
    if canEdit then
        win.manualAssign:Enable()
    else
        win.manualAssign:Disable()
    end
    if canEdit and CL.Disenchant.Name() then win.deButton:Enable() else win.deButton:Disable() end
end

-------------------------------------------------
-- The icons at the side
-------------------------------------------------
local function RefreshStrip(state)
    local history = Run().History()
    local first = math.max(1, #history - STRIP_MAX + 1)
    local shown = 0
    local function Put(data)
        shown = shown + 1
        local b = win.strip.buttons[shown]
        b.data = data
        b.icon:SetTexture(IconOf(data.lot))
        local r, g, bl = 0.5, 0.5, 0.5
        if data.live then
            r, g, bl = 1, 1, 1
        else
            local given, count = #Run().AwardsFor(data.lot), data.lot.count or 1
            if given >= count then r, g, bl = 0.25, 1, 0.25
            elseif given > 0 then r, g, bl = 1, 0.6, 0.1 end
        end
        if data.index and win.editIndex == data.index then r, g, bl = 1, 0.82, 0 end
        b.bg:SetColorTexture(r, g, bl, 1)
        b:Show()
    end
    for i = first, #history do Put({ lot = history[i].lot, index = i }) end
    if state.item and state.recorded ~= state.index then Put({ lot = state.item, live = true }) end
    for i = shown + 1, #win.strip.buttons do win.strip.buttons[i]:Hide() end
    if shown > 0 then win.strip:Show() else win.strip:Hide() end
end

-------------------------------------------------
-- Showing the right view
-------------------------------------------------
local function SetMode(mode)
    local running = mode ~= "list"
    for _, region in ipairs(win.listParts) do
        if running then region:Hide() end
    end
    for _, region in ipairs(win.runParts) do
        if running then region:Show() else region:Hide() end
    end
    for _, region in ipairs(win.liveParts) do
        if mode == "live" then region:Show() else region:Hide() end
    end
    for _, region in ipairs(win.editParts) do
        if mode == "edit" then region:Show() else region:Hide() end
    end
    if not running then win.strip:Hide() end
    win.title:SetText(running and "Loot session: running" or "Loot session")
end

local function Refresh()
    if not win or not win:IsShown() then return end
    if Run().Active() then
        local state = Run().State()
        local hist = win.editIndex and Run().History()[win.editIndex]
        if not hist then win.editIndex = nil end
        SetMode(hist and "edit" or "live")
        win:SetHeight(RUN_HEAD_H + 14 + RUN_ROWS * RUN_ROW_H + RUN_FOOT_H)
        if hist then RefreshEdit(state, hist) else RefreshRun() end
        RefreshStrip(state)
    else
        win.editIndex = nil
        SetMode("list")
        for _, row in ipairs(win.rows) do row:Hide() end
        win.sub:Show()
        win.refresh:Show()
        win.deOpen:Show()
        win.start:Show()
        win.test:Show()
        RefreshList()
    end
end
Session.Refresh = Refresh

-------------------------------------------------
-- Building the window
-------------------------------------------------
local function TextBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 22)
    box:SetFontObject("ChatFontNormal")
    box:SetAutoFocus(false)
    box:SetTextInsets(4, 4, 0, 0)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

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
            ItemTooltip(self, row.entry)
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

    f.deOpen = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.deOpen:SetSize(90, 22)
    f.deOpen:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 94, 10)
    f.deOpen:SetText("Disenchant")
    f.deOpen:SetScript("OnClick", function() CL.Disenchant.Toggle() end)
    f.deOpen:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local name = CL.Disenchant.Name()
        GameTooltip:AddLine(name and ("Disenchanter: " .. name) or "Ask who can disenchant and designate one.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.deOpen:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.refresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.refresh:SetSize(76, 22)
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
    f.listParts = { f.sub, f.refresh, f.start, f.test, f.deOpen }
    for _, row in ipairs(f.rows) do f.listParts[#f.listParts + 1] = row end

    ---------------- what the session and the changes share: the item and the rolls
    f.runParts, f.liveParts, f.editParts = {}, {}, {}
    local function Part(list, region)
        list[#list + 1] = region
        region:Hide()
        return region
    end
    local iconButton = Part(f.runParts, CreateFrame("Button", nil, f))
    iconButton:SetSize(36, 36)
    iconButton:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    f.runIcon = iconButton:CreateTexture(nil, "ARTWORK")
    f.runIcon:SetAllPoints()
    iconButton:SetScript("OnEnter", function(self)
        local state = Run().State()
        local lot = state and ((win.editIndex and Run().History()[win.editIndex] and Run().History()[win.editIndex].lot)
            or state.item)
        if not lot then return end
        ItemTooltip(self, lot)
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.runName = Part(f.runParts, f:CreateFontString(nil, "ARTWORK", "GameFontNormal"))
    f.runName:SetPoint("TOPLEFT", f, "TOPLEFT", 58, -40)
    f.runName:SetWidth(WIN_W - 170)
    f.runName:SetJustifyH("LEFT")
    f.runName:SetWordWrap(false)
    f.runCount = Part(f.runParts, f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"))
    f.runCount:SetPoint("TOPLEFT", f, "TOPLEFT", 58, -58)
    f.runTime = Part(f.runParts, f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"))
    f.runTime:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -40)
    f.runTime:SetJustifyH("RIGHT")
    f.runStatus = Part(f.runParts, f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"))
    f.runStatus:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -80)
    f.runStatus:SetWidth(WIN_W - 28)
    f.runStatus:SetJustifyH("LEFT")

    f.runRows = {}
    for i = 1, RUN_ROWS do
        local row = Part(f.runParts, CreateFrame("Button", nil, f))
        row:SetSize(WIN_W - 20, RUN_ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(RUN_HEAD_H + 14 + (i - 1) * RUN_ROW_H))
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.1)
        row.hl:Hide()
        row.who = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.who:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.who:SetWidth(180)
        row.who:SetJustifyH("LEFT")
        row.who:SetWordWrap(false)
        row.roll = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.roll:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.roll:SetJustifyH("RIGHT")
        -- the X that takes an assignment back (changes view)
        row.cancel = CreateFrame("Button", nil, row)
        row.cancel:SetSize(18, 18)
        row.cancel:SetPoint("LEFT", row, "LEFT", 196, 0)
        local cx = row.cancel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        cx:SetPoint("CENTER")
        cx:SetText("|cffff5555X|r")
        row.cancel:SetScript("OnClick", function()
            local award = row.award
            if not award then return end
            CL.MasterLoot.Confirmation(
                ("Take %s back from %s?"):format(award.item.name or "?", ShortName(award.winner)),
                "The copy is free again.", function() Run().Unassign(award) end, "Take back")
        end)
        row.cancel:Hide()
        row:SetScript("OnEnter", function(self)
            if self:IsMouseEnabled() and self.entry then self.hl:Show() end
        end)
        row:SetScript("OnLeave", function(self) self.hl:Hide() end)
        row:SetScript("OnClick", function(self)
            local e = self.entry
            if not (e and not e.assigned) then return end
            if win.editIndex then
                local hist = Run().History()[win.editIndex]
                if not hist then return end
                CL.MasterLoot.Confirmation(
                    ("Give %s to %s?"):format(hist.lot.name or "?", e.name),
                    ("Roll: %s %d"):format(Run().Label(e.cat), e.value),
                    function() Run().AssignManual(hist.lot, e.name, e) end, "Give")
            elseif Run().Can("choose") then
                local state = Run().State()
                CL.MasterLoot.Confirmation(
                    ("Assign %s to %s?"):format(state.item.name or "?", e.name),
                    ("Roll: %s %d"):format(Run().Label(e.cat), e.value),
                    function() Run().Award(e.name) end, "Assign")
            end
        end)
        f.runRows[i] = row
    end

    ---------------- the session: the master looter's rolls and the controls
    f.rollButtons = {}
    local function RollButton(key, label, width, x0, onClick, tip)
        local b = Part(f.liveParts, CreateFrame("Button", nil, f, "UIPanelButtonTemplate"))
        b:SetSize(width, 22)
        b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x0, 42)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.rollButtons[key] = b
        return b
    end
    for cat = 1, 3 do
        local ranges = { 100, 99, 90 }
        RollButton(cat, ("%s%s 1-%d|r"):format(Run().CatColor(cat), Run().Label(cat), ranges[cat]), 92, 12 + (cat - 1) * 98,
            function() Run().RollAs(cat) end, "Roll yourself: the same /roll the players make.")
    end
    RollButton("pass", "Pass", 60, 12 + 3 * 98, function() Run().PassMe() end, "Take your roll back: you are out for this item.")

    f.controls = {}
    local function Control(action, label, width, x0, onClick, tip)
        local b = Part(f.liveParts, CreateFrame("Button", nil, f, "UIPanelButtonTemplate"))
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
        f.controls[action] = b
        return b
    end
    Control("pause", "Pause", 66, 12, function() Run().Pause() end, "Stop the timer. The group is told.")
    Control("resume", "Resume", 66, 12, function() Run().Resume() end, "Start the timer again. The group is told.")
    Control("extend", "+10 s", 52, 82, function() Run().Extend() end, "Add ten seconds. The group is told.")
    Control("skip", "Skip", 48, 138, function() Run().Skip() end, "Leave this item unassigned and go on.")
    Control("reroll", "Re-roll", 62, 190, function() Run().Reroll() end, "Only the tied players roll again.")
    Control("de", "To DE", 58, 256, function() Run().GiveToDE() end, "Send the copies still to give to the disenchanter.")
    Control("finish", "Finish now", 100, 12, function() Run().Finish() end, "End the session: the winners get their whispers.")
    Control("cancel", "Cancel", 66, WIN_W - 78, function() Run().Cancel() end, "End the session now. The group is told.")

    ---------------- the changes: give a copy to anybody, and back
    local label = Part(f.editParts, f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"))
    label:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 48)
    label:SetText("Give a copy by hand to:")
    f.manualBox = Part(f.editParts, TextBox(f, 150))
    f.manualBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 150, 44)
    f.manualAssign = Part(f.editParts, CreateFrame("Button", nil, f, "UIPanelButtonTemplate"))
    f.manualAssign:SetSize(80, 22)
    f.manualAssign:SetPoint("LEFT", f.manualBox, "RIGHT", 6, 0)
    f.manualAssign:SetText("Assign")
    local function ManualAssign()
        local hist = win.editIndex and Run().History()[win.editIndex]
        if not hist then return end
        local name = f.manualBox:GetText()
        if name == nil or name:match("^%s*$") then return end
        CL.MasterLoot.Confirmation(("Give %s to %s?"):format(hist.lot.name or "?", name), "By hand: no roll.",
            function()
                if Run().AssignManual(hist.lot, name) then f.manualBox:SetText("") end
            end, "Give")
    end
    f.manualAssign:SetScript("OnClick", ManualAssign)
    f.manualBox:SetScript("OnEnterPressed", ManualAssign)
    f.backButton = Part(f.editParts, CreateFrame("Button", nil, f, "UIPanelButtonTemplate"))
    f.backButton:SetSize(150, 22)
    f.backButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
    f.backButton:SetText("Back to the session")
    f.backButton:SetScript("OnClick", function()
        f.editIndex = nil
        Refresh()
    end)
    f.deButton = Part(f.editParts, CreateFrame("Button", nil, f, "UIPanelButtonTemplate"))
    f.deButton:SetSize(130, 22)
    f.deButton:SetPoint("LEFT", f.backButton, "RIGHT", 6, 0)
    f.deButton:SetText("To the disenchanter")
    f.deButton:SetScript("OnClick", function()
        local hist = f.editIndex and Run().History()[f.editIndex]
        if not hist then return end
        Run().AssignToDE(hist.lot)
    end)

    ---------------- the icons at the side
    local strip = CreateFrame("Frame", nil, f)
    strip:SetSize(STRIP_ICON + 6, (STRIP_ICON + 6) * (STRIP_MAX + 1))
    strip:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, -40)
    strip.buttons = {}
    for i = 1, STRIP_MAX + 1 do
        local b = CreateFrame("Button", nil, strip)
        b:SetSize(STRIP_ICON, STRIP_ICON)
        b:SetPoint("TOPLEFT", strip, "TOPLEFT", 2, -2 - (i - 1) * (STRIP_ICON + 6))
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
        b.bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        b.bg:SetColorTexture(0.5, 0.5, 0.5, 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b:SetScript("OnEnter", function(self)
            local d = self.data
            if not d then return end
            ItemTooltip(self, d.lot)
            if d.live then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Being rolled for. Click to go back to it.", 1, 1, 1, true)
            else
                GameTooltip:AddLine(" ")
                local awards = Run().AwardsFor(d.lot)
                for _, a in ipairs(awards) do
                    GameTooltip:AddLine(("%s: %s"):format(ShortName(a.winner),
                        a.cat and ("%s %d"):format(Run().Label(a.cat), a.value) or "by hand"), 0.25, 1, 0.25)
                end
                local free = Run().FreeCopies(d.lot)
                if free > 0 then
                    GameTooltip:AddLine(("%d cop%s not assigned"):format(free, free == 1 and "y" or "ies"), 0.7, 0.7, 0.7)
                end
                GameTooltip:AddLine("Click to change an assignment.", 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            local d = self.data
            if not d then return end
            f.editIndex = d.index   -- nil for the item in play: back to the session
            Refresh()
        end)
        b:Hide()
        strip.buttons[i] = b
    end
    strip:Hide()
    f.strip = strip

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
