-- Our own loot roll frames. They are independent of Blizzard's GroupLootFrameN
-- (hidden separately by Native.lua), fed through CL.API so they work for real and
-- simulated rolls alike.

local _, CL = ...

local RF = {}
CL.RollFrames = RF

local MAX_FRAMES = 8
-- Two skins: "clean" (CleanLoot's flat dark frames, the default) and "blizzard" (the game's classic
-- roll frame: dialog border, dice / coin / pass buttons, slot-framed icon).
local DIMS = { clean = { w = 252, h = 70 }, blizzard = { w = 262, h = 84 } }
local NOTE_H = 14   -- a watchlist note adds one line to the frame
local WATCH_R, WATCH_G, WATCH_B = 0.25, 1, 0.95   -- the watchlist's outline and note: cyan, no quality uses it
local SPACING = 6
local FLAT = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
    bgFile = FLAT, edgeFile = FLAT, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local DIALOG = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 11, top = 11, bottom = 11 },
}
local BUTTON_ART = {   -- roll type -> the classic button texture (-Up / -Down)
    [1] = "Interface\\Buttons\\UI-GroupLoot-Dice",
    [2] = "Interface\\Buttons\\UI-GroupLoot-Coin",
    [0] = "Interface\\Buttons\\UI-GroupLoot-Pass",
}

local function Skin()
    return (CL.db and CL.db.rollSkin == "blizzard") and "blizzard" or "clean"
end

local function Dims() return DIMS[Skin()] end

local pool = {}      -- every frame ever created
local active = {}    -- frames in use, oldest first (drives the stack order)
local queue = {}     -- rolls waiting for a free frame, oldest first (big drops)
local queueLabel     -- "+N more waiting" under/over the stack
local byRollID = {}  -- rollID -> frame
local anchor         -- movable 1x1 frame the whole stack hangs from

-------------------------------------------------
-- Helpers
-------------------------------------------------
local function InsertLink(link)
    local fn = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
    if fn then fn(link) end
end

local function Preview(link)
    local fn = DressUpLink or DressUpItemLink
    if fn then fn(link) end
end

-- A button's look: the classic art follows its state (greyed when unavailable, green when an
-- auto-roll rule answers with it); the flat skin draws its own state in the label.
local function PaintButton(b)
    if Skin() ~= "blizzard" then
        b:SetAlpha(1)
        return
    end
    b.art:SetDesaturated(b.unavailable and true or false)
    if b.auto and not b.unavailable then b.art:SetVertexColor(0.5, 1, 0.5) else b.art:SetVertexColor(1, 1, 1) end
    b:SetAlpha(b.unavailable and 0.55 or 1)
end

-- The quality colour: the flat skin's border, the classic skin's slot around the icon. The name
-- takes it in both.
local function PaintQuality(f)
    local r, g, b = CL.QualityColor(f.quality)
    f.name:SetTextColor(r, g, b)
    if Skin() == "blizzard" then
        f:SetBackdropBorderColor(1, 1, 1, 1)
        f.slot:SetVertexColor(r, g, b)
    else
        f:SetBackdropBorderColor(r, g, b, 1)
    end
end

local function GetAnchor()
    if anchor then return anchor end
    anchor = CreateFrame("Frame", "CleanLootAnchor", UIParent)
    anchor:SetSize(1, 1)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    local p = CL.db and CL.db.point
    if p then
        anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    end
    return anchor
end

local function SavePosition()
    local point, _, relPoint, x, y = anchor:GetPoint()
    if CL.db then CL.db.point = { point, relPoint, x, y } end
end

-------------------------------------------------
-- Frame construction
-------------------------------------------------
-- One tooltip line per player: you in gold, others in their class colour, with
-- the roll value when the game has revealed it.
local function AddPlayerLines(list)
    for _, v in ipairs(list) do
        local r, g, b = 0.8, 0.8, 0.8
        if v.name == "You" then
            r, g, b = 1, 0.82, 0
        else
            local c = v.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[v.class]
            if c then r, g, b = c.r, c.g, c.b end
        end
        if v.value then
            GameTooltip:AddDoubleLine(v.name, tostring(v.value), r, g, b, 1, 1, 1)
        else
            GameTooltip:AddLine(v.name, r, g, b)
        end
    end
end

-- Button tooltip: who chose this type so far, and for a greyed-out button the
-- client's reason it is unavailable.
local function ShowButtonTooltip(btn, f)
    local list = f.votes and f.votes[btn.rollType]
    local n = list and #list or 0
    local reasonText
    if btn.unavailable then
        local reason = (btn.rollType == CL.ROLL.NEED) and f.reasonNeed or f.reasonGreed
        reasonText = reason and _G["LOOT_ROLL_INELIGIBLE_REASON" .. tostring(reason)]
        reasonText = reasonText or ("You can't roll %s on this item."):format(CL.ROLL_NAME[btn.rollType])
    end
    if n == 0 and not reasonText and not btn.auto then return end

    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    if n > 0 then
        GameTooltip:AddLine(("%s (%d)"):format(CL.ROLL_NAME[btn.rollType], n), 1, 1, 1)
        AddPlayerLines(list)
    end
    if reasonText then GameTooltip:AddLine(reasonText, 1, 0.2, 0.2, true) end
    if btn.auto then
        GameTooltip:AddLine(("Auto: always %s on this item. Right-click removes it."):format(CL.ROLL_NAME[btn.rollType]),
            0.3, 1, 0.3, true)
    end
    GameTooltip:Show()
end

-- The clock in the corner: players who have not chosen yet.
local function ShowPendingTooltip(f)
    local list = f.votes and f.votes.pending
    if not list or #list == 0 then return end
    GameTooltip:SetOwner(f.pendingFrame, "ANCHOR_TOP")
    GameTooltip:AddLine(("Hasn't rolled yet (%d)"):format(#list), 1, 1, 1)
    AddPlayerLines(list)
    GameTooltip:Show()
end

-- Pull the current votes into the frame: the small number on each button and the
-- "hasn't rolled yet" clock.
local function ApplyVotes(f)
    local votes = f.rollID and CL.API.GetVotes(f.rollID)
    f.votes = votes
    for rollType, b in pairs(f.buttons) do
        local list = votes and votes[rollType]
        local n = list and #list or 0
        b.count:SetText(n > 0 and n or "")
        -- keep an open tooltip in step with the new numbers
        if GameTooltip:IsShown() and GameTooltip:IsOwned(b) then ShowButtonTooltip(b, f) end
    end

    local pending = votes and votes.pending
    local waiting = pending and #pending or 0
    if waiting > 0 then
        f.pendingCount:SetText(waiting)
        f.pendingFrame:Show()
    else
        f.pendingFrame:Hide()
    end
    if GameTooltip:IsShown() and GameTooltip:IsOwned(f.pendingFrame) then
        if waiting > 0 then ShowPendingTooltip(f) else GameTooltip:Hide() end
    end
end

local function CreateRollButton(f, rollType)
    local b = CreateFrame("Button", nil, f, "BackdropTemplate")
    b:SetSize(72, 20)
    b:SetBackdrop(BACKDROP)
    b:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    b:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    b.rollType = rollType

    local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText(CL.ROLL_NAME[rollType])
    b.label = label

    -- the classic skin: the game's own dice / coin / pass pictures instead of a flat button
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetAllPoints()
    b.art:SetTexture((BUTTON_ART[rollType] or BUTTON_ART[0]) .. "-Up")
    b.art:Hide()
    b.glow = b:CreateTexture(nil, "HIGHLIGHT")
    b.glow:SetAllPoints()
    b.glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()

    local binding = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    binding:SetPoint("BOTTOM", b, "BOTTOM", -6, 1)
    binding:SetJustifyH("CENTER")
    binding:SetWordWrap(false)
    binding:Hide()
    b.binding = binding

    -- how many players chose this type (empty at 0)
    local count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    count:SetText("")
    b.count = count

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- Snapshot the target roll on mouse-DOWN: between down and up the roll can
    -- end by itself and this pooled frame be handed to a new item, which would
    -- then receive the click: a vote on the wrong item.
    b:SetScript("OnMouseDown", function(self)
        self.clickRollID, self.clickBop = f.rollID, f.bop
        self.clickLink, self.clickName = f.link, f.itemName
        self.art:SetTexture((BUTTON_ART[self.rollType] or BUTTON_ART[0]) .. "-Down")
    end)
    b:SetScript("OnMouseUp", function(self)
        self.art:SetTexture((BUTTON_ART[self.rollType] or BUTTON_ART[0]) .. "-Up")
    end)
    b:SetScript("OnClick", function(self, button)
        local id, bop, link, name = self.clickRollID, self.clickBop, self.clickLink, self.clickName
        if not id or self.unavailable then return end
        self.clickRollID, self.clickBop, self.clickLink, self.clickName = nil, nil, nil, nil
        if button == "RightButton" then
            -- "always this answer for this item": remember it (or forget it), and answer now
            if CL.AutoRoll.ToggleForItem(link, name, self.rollType) == "added" then
                RF.Answer(id, self.rollType, bop)
            end
            return
        end
        RF.Answer(id, self.rollType, bop)
    end)
    b:SetScript("OnEnter", function(self)
        if not self.unavailable and Skin() == "clean" then self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end
        ShowButtonTooltip(self, f)
    end)
    b:SetScript("OnLeave", function(self)
        if Skin() == "clean" then self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1) end
        GameTooltip:Hide()
    end)
    return b
end

local function CreateRollFrame(index)
    local f = CreateFrame("Frame", "CleanLootRollFrame" .. index, UIParent, "BackdropTemplate")
    f:SetSize(DIMS.clean.w, DIMS.clean.h)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.04, 0.04, 0.04, 0.9)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    local selection = CreateFrame("Frame", nil, f, "BackdropTemplate")
    selection:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
    selection:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
    selection:SetBackdrop({ edgeFile = FLAT, edgeSize = 3 })
    selection:SetBackdropBorderColor(1, 1, 1, 1)
    selection:Hide()
    f.selection = selection

    -- watchlist: a thin outline inside the frame that pulses gently (the white selection
    -- outline of controller mode stays outside, so both can show)
    local watch = CreateFrame("Frame", nil, f, "BackdropTemplate")
    watch:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    watch:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    watch:SetBackdrop({ edgeFile = FLAT, edgeSize = 2 })
    watch:SetBackdropBorderColor(WATCH_R, WATCH_G, WATCH_B, 1)
    watch:Hide()
    watch.t = 0
    watch:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + (elapsed or 0)
        self:SetAlpha(0.7 + 0.3 * math.sin(self.t * 4.5))   -- about 1.4 s a cycle, between 40% and 100%
    end)
    f.watch = watch
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not RF.CanMove() then return end
        self.dragging = true
        GetAnchor():StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = nil
        GetAnchor():StopMovingOrSizing()
        SavePosition()
    end)
    f:Hide()

    -- Item icon: hover = tooltip, Ctrl+click = preview, Shift+click = link.
    local icon = CreateFrame("Button", nil, f)
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()
    icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.slot = icon:CreateTexture(nil, "OVERLAY")   -- the classic skin's slot around the icon
    icon.slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    icon.slot:SetPoint("CENTER", icon, "CENTER", 0, -1)
    icon.slot:Hide()
    f.slot = icon.slot
    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    icon.count:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetScript("OnEnter", function(self)
        if not (f.link or f.itemName) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if f.link then
            pcall(GameTooltip.SetHyperlink, GameTooltip, f.link)
        else
            -- no hyperlink (a made-up simulator item): at least name + colour
            local r, g, b = CL.QualityColor(f.quality)
            GameTooltip:SetText(f.itemName, r, g, b)
        end
        if f.watched then
            local note = f.watchNote
            GameTooltip:AddLine(note and note ~= "" and ("Watchlist: " .. note) or "On your watchlist",
                WATCH_R, WATCH_G, WATCH_B, true)
        end
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icon:SetScript("OnClick", function()
        if not f.link then return end
        if IsControlKeyDown() then Preview(f.link)
        elseif IsShiftKeyDown() then InsertLink(f.link) end
    end)
    f.icon = icon

    local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
    name:SetSize(156, 14)  -- leaves the corner free for the "hasn't rolled yet" clock
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    f.name = name

    -- the watchlist note, in the line left under the timer bar when the frame is a little taller
    local note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -43)
    note:SetSize(190, 11)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(false)
    note:SetTextColor(WATCH_R, WATCH_G, WATCH_B)
    note:Hide()
    f.note = note

    -- "Hasn't rolled yet": a small clock in the top-right corner with how many
    -- players are still deciding; hover lists them. Hidden when nobody is waiting.
    local pending = CreateFrame("Frame", nil, f)
    pending:SetSize(16, 16)
    pending:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    pending:EnableMouse(true)
    local clock = pending:CreateTexture(nil, "ARTWORK")
    clock:SetAllPoints()
    clock:SetTexture("Interface\\ICONS\\INV_Misc_PocketWatch_02")
    clock:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local waiting = pending:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    waiting:SetPoint("RIGHT", pending, "LEFT", -3, 0)
    waiting:SetText("")
    pending:SetScript("OnEnter", function() ShowPendingTooltip(f) end)
    pending:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pending:Hide()
    f.pendingFrame, f.pendingCount = pending, waiting

    local barBG = f:CreateTexture(nil, "BACKGROUND")
    barBG:SetColorTexture(0.12, 0.12, 0.12, 1)
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetStatusBarTexture(FLAT)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetSize(190, 8)
    bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -24)
    barBG:SetAllPoints(bar)
    f.bar, f.barBG = bar, barBG

    f.buttons = {}
    local prev
    for _, rollType in ipairs(CL.ROLL_ORDER) do
        local b = CreateRollButton(f, rollType)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        else
            b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
        end
        f.buttons[rollType] = b
        prev = b
    end

    RF.ApplySkin(f)

    f:SetScript("OnUpdate", function(self, elapsed)
        if not self.endTime then return end
        local remaining = self.endTime - GetTime()
        if remaining < 0 then remaining = 0 end
        local frac = self.duration > 0 and (remaining / self.duration) or 0
        self.bar:SetValue(frac)
        -- yellow -> red as the timer runs out
        self.bar:SetStatusBarColor(0.8 + 0.2 * frac, 0.1 + 0.72 * frac, 0.1 * (1 - frac))

        -- The roll is over once its timer is. The server normally closes the frame
        -- itself (CANCEL_LOOT_ROLL); if it ever does not, an expired frame must not
        -- sit on a slot forever and keep newer rolls waiting.
        if remaining <= 0 then
            self.expiredFor = (self.expiredFor or 0) + (elapsed or 0)
            if self.expiredFor > 2 and self.rollID then
                CL.Debug("roll %s: timer over for 2s and no cancel from the server, closing it", tostring(self.rollID))
                CL.OnRollGone(self.rollID)
            end
        else
            self.expiredFor = nil
        end
    end)

    return f
end

-- An unavailable roll type is greyed out but the button stays ENABLED: a
-- disabled Button may not deliver mouse-over, and the tooltip (who chose it, why
-- it is unavailable) must work on exactly those buttons. Clicks are ignored.
local function SetButtonAvailable(btn, available)
    btn.unavailable = not available
    btn:Enable()
    if available then
        btn.label:SetTextColor(1, 0.82, 0)
        btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    else
        btn.label:SetTextColor(0.4, 0.4, 0.4)
        btn:SetBackdropColor(0.04, 0.04, 0.04, 0.9)
    end
    PaintButton(btn)
end

-- Dresses a frame in the current skin: backdrop, sizes and places of everything on it.
function RF.ApplySkin(f)
    local skin = Skin()
    local d = DIMS[skin]
    local classic = skin == "blizzard"
    f.skin = skin
    f:SetSize(d.w, d.h)
    if classic then
        f:SetBackdrop(DIALOG)
        f:SetBackdropColor(1, 1, 1, 1)
    else
        f:SetBackdrop(BACKDROP)
        f:SetBackdropColor(0.04, 0.04, 0.04, 0.9)
        f:SetBackdropBorderColor(0, 0, 0, 1)
    end

    local inset = classic and 4 or 1
    f.watch:ClearAllPoints()
    f.watch:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.watch:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)

    f.icon:SetSize(classic and 40 or 36, classic and 40 or 36)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", classic and 16 or 8, classic and -14 or -8)
    f.slot:SetSize(classic and 73 or 66, classic and 73 or 66)
    f.slot:SetShown(classic)

    f.name:ClearAllPoints()
    if classic then
        f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 62, -16)
    else
        f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 6, -2)
    end
    f.name:SetSize(classic and 159 or 156, 14)

    f.note:ClearAllPoints()
    f.note:SetPoint("TOPLEFT", f, "TOPLEFT", classic and 17 or 50, classic and -76 or -43)
    f.note:SetSize(classic and 228 or 190, 11)

    f.pendingFrame:ClearAllPoints()
    f.pendingFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", classic and -17 or -8, classic and -15 or -8)

    f.bar:SetStatusBarTexture(classic and "Interface\\TargetingFrame\\UI-StatusBar" or FLAT)
    f.bar:ClearAllPoints()
    if classic then
        f.bar:SetSize(228, 9)
        f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -64)
        f.barBG:SetColorTexture(0, 0, 0, 0.55)
    else
        f.bar:SetSize(190, 8)
        f.bar:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 6, -24)
        f.barBG:SetColorTexture(0.12, 0.12, 0.12, 1)
    end

    local prev
    for _, rollType in ipairs(CL.ROLL_ORDER) do
        local b = f.buttons[rollType]
        b:ClearAllPoints()
        if classic then
            b:SetSize(28, 28)
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", f, "TOPLEFT", 62, -32) end
            b:SetBackdrop(nil)
        else
            b:SetSize(72, 20)
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8) end
            b:SetBackdrop(BACKDROP)
            b:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
            b:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        end
        b.art:SetShown(classic)
        b.glow:SetShown(classic)
        b.label:SetShown(not classic)
        b.count:ClearAllPoints()
        if classic then b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2) else b.count:SetPoint("RIGHT", b, "RIGHT", -4, 0) end
        b.binding:ClearAllPoints()
        b.binding:SetPoint("BOTTOM", b, "BOTTOM", classic and 0 or -6, classic and 2 or 1)
        prev = b
        if f.rollID then SetButtonAvailable(b, not b.unavailable) end
        PaintButton(b)
    end
    if f.rollID then PaintQuality(f) end
end

-------------------------------------------------
-- Layout
-------------------------------------------------
function RF.Layout()
    local grow = (CL.db and CL.db.growDirection) or "DOWN"
    local scale = (CL.db and CL.db.frameScale) or CL.DEFAULT_SCALE
    local base = GetAnchor()
    local prev
    for _, f in ipairs(active) do
        f:SetScale(scale)
        f:ClearAllPoints()
        if not prev then
            if grow == "UP" then
                f:SetPoint("BOTTOMLEFT", base, "BOTTOMLEFT", 0, 0)
            else
                f:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
            end
        elseif grow == "UP" then
            f:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, SPACING)
        else
            f:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -SPACING)
        end
        prev = f
    end

    -- "+N more waiting" past the last frame, so a full stack explains itself
    if #queue > 0 and prev then
        if not queueLabel then
            queueLabel = CreateFrame("Frame", nil, UIParent)
            queueLabel:SetSize(Dims().w, 16)
            queueLabel:SetFrameStrata("DIALOG")
            queueLabel.text = queueLabel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            queueLabel.text:SetPoint("LEFT", queueLabel, "LEFT", 4, 0)
        end
        queueLabel:SetWidth(Dims().w)
        queueLabel.text:SetText(("+%d more waiting for a free slot"):format(#queue))
        queueLabel:SetScale(scale)
        queueLabel:ClearAllPoints()
        if grow == "UP" then
            queueLabel:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, 4)
        else
            queueLabel:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
        end
        queueLabel:Show()
    elseif queueLabel then
        queueLabel:Hide()
    end
    if CL.Keyboard then CL.Keyboard.Layout() end
end

-- The button an auto-roll rule answers with is green (and says so in its tooltip).
local function ApplyAuto(f)
    local AR = CL.AutoRoll
    local rule = AR and f.rollID and AR.ItemRule(AR.ItemID(f.link))
    for rollType, b in pairs(f.buttons) do
        b.auto = (rule and rule.roll == rollType) or false
        if b.unavailable then
            b.label:SetTextColor(0.4, 0.4, 0.4)
        elseif b.auto then
            b.label:SetTextColor(0.3, 1, 0.3)
        else
            b.label:SetTextColor(1, 0.82, 0)
        end
        PaintButton(b)
    end
end

-- A rule was added or removed: the open frames show it.
function RF.RefreshAuto()
    for _, f in ipairs(active) do ApplyAuto(f) end
end

-- Watched items: the pulsing outline, and the note on its own line (the frame grows to fit it).
local function ApplyWatch(f)
    local note = f.rollID and CL.Watchlist and CL.Watchlist.Lookup(f.link) or nil
    local watched = note ~= nil
    if watched and not f.watched then f.watch.t = 0 end   -- start the pulse from the top
    f.watched, f.watchNote = watched, note
    if watched then f.watch:Show() else f.watch:Hide() end
    if watched and note ~= "" then
        f.note:SetText(note)
        f.note:Show()
        f:SetHeight(Dims().h + NOTE_H)
    else
        f.note:SetText("")
        f.note:Hide()
        f:SetHeight(Dims().h)
    end
end

-- The watchlist changed: the open frames show it.
function RF.RefreshWatch()
    for _, f in ipairs(active) do ApplyWatch(f) end
    RF.Layout()
end

-- The skin changed (options, /cll skin): every frame, shown or not, is dressed again.
function RF.RefreshSkin()
    for _, f in ipairs(pool) do
        RF.ApplySkin(f)
        if f.rollID then ApplyWatch(f) ApplyAuto(f) end
    end
    RF.Layout()
end

function RF.SetSkin(skin)
    if skin ~= "blizzard" then skin = "clean" end
    CL.db.rollSkin = skin
    RF.RefreshSkin()
end

function RF.Skin() return Skin() end

-------------------------------------------------
-- Public API
-------------------------------------------------
-- A free frame from the pool, or nil when all MAX_FRAMES are in use.
local function FreeFrame()
    for i = 1, MAX_FRAMES do
        pool[i] = pool[i] or CreateRollFrame(i)
        if not pool[i].rollID then return pool[i] end
    end
    return nil
end

-- Put a roll on a frame and show it. `endTime` is absolute (GetTime based), so a
-- roll that waited in the queue keeps counting down while it waited.
local function Open(f, rollID, info, link, endTime, duration)
    f.rollID = rollID
    f.link = link
    f.itemName, f.quality, f.bop = info.name, info.quality, info.bop
    f.reasonNeed, f.reasonGreed = info.reasonNeed, info.reasonGreed
    f.expiredFor = nil
    byRollID[rollID] = f
    active[#active + 1] = f

    f.icon.tex:SetTexture(info.texture)
    f.icon.count:SetText((info.count or 1) > 1 and info.count or "")
    f.name:SetText(info.name or "?")
    PaintQuality(f)

    SetButtonAvailable(f.buttons[CL.ROLL.NEED], info.canNeed)
    SetButtonAvailable(f.buttons[CL.ROLL.GREED], info.canGreed)
    SetButtonAvailable(f.buttons[CL.ROLL.PASS], true)
    ApplyAuto(f)
    ApplyWatch(f)

    f.duration = duration
    f.endTime = endTime
    f.bar:SetValue(math.max(0, math.min(1, (endTime - GetTime()) / duration)))
    ApplyVotes(f)

    f:Show()
end

-- A frame just freed up: the oldest queued roll that is still running takes it.
local function FillFromQueue()
    while #queue > 0 do
        local f = FreeFrame()
        if not f then return end
        local q = table.remove(queue, 1)
        if q.endTime - GetTime() > 0.5 then
            CL.Debug("roll %s leaves the queue and is shown (%d still waiting)", tostring(q.rollID), #queue)
            Open(f, q.rollID, q.info, q.link, q.endTime, q.duration)
        else
            CL.Debug("roll %s ran out while it was queued, dropped", tostring(q.rollID))
        end
    end
end

function RF.Start(rollID, info, link, rollTime)
    if byRollID[rollID] then return byRollID[rollID] end
    if RF.IsQueued(rollID) then return nil end

    local duration = (rollTime and rollTime > 0) and (rollTime / 1000) or 60
    local endTime = GetTime() + duration

    local f = FreeFrame()
    if not f then
        -- More simultaneous rolls than frames (a big raid drop): never drop one,
        -- queue it; it appears as soon as a slot frees up, like Blizzard's own.
        queue[#queue + 1] = { rollID = rollID, info = info, link = link, endTime = endTime, duration = duration }
        CL.Debug("roll %s queued: all %d frames are in use (%d waiting)", tostring(rollID), MAX_FRAMES, #queue)
        RF.Layout()
        return nil
    end

    Open(f, rollID, info, link, endTime, duration)
    CL.Debug("roll %s shown: %s", tostring(rollID), tostring(info.name))
    RF.Layout()
    if CL.Keyboard then CL.Keyboard.OnChanged() end
    if CL.Results then CL.Results.RefreshWaiting() end
    return f
end

function RF.Stop(rollID)
    -- still waiting in the queue: just forget it
    for i, q in ipairs(queue) do
        if q.rollID == rollID then
            table.remove(queue, i)
            RF.Layout()
            return
        end
    end

    local f = byRollID[rollID]
    if not f then return end
    byRollID[rollID] = nil
    f.rollID, f.link, f.endTime = nil, nil, nil
    f.itemName, f.quality, f.bop, f.votes, f.expiredFor = nil, nil, nil, nil, nil
    f.watched, f.watchNote = nil, nil
    f.watch:Hide()
    local removedIndex
    for i, a in ipairs(active) do
        if a == f then removedIndex = i table.remove(active, i) break end
    end
    f:Hide()
    FillFromQueue()
    RF.Layout()
    if CL.Keyboard then CL.Keyboard.OnRemoved(rollID, removedIndex, f) end
    if CL.Results then CL.Results.RefreshWaiting() end
end

-- Answers a roll (a click or a key). Most answers close the frame at once, like the
-- native one. A bind-on-pickup roll the game wants confirmed (Need or Greed) keeps
-- its frame: the roll is still open until the game takes the answer, so refusing the
-- confirmation leaves the buttons there to answer again, and accepting it makes the
-- game close the roll (CANCEL_LOOT_ROLL). With "accept bind-on-pickup prompts" on
-- there is nothing to refuse, so the frame closes at once. Returns false when the
-- answer was not sent.
function RF.Answer(rollID, rollType, bop)
    if not rollID then return false end
    local simulated = CL.Sim and CL.Sim.GetRoll(rollID)
    local waits = bop and not simulated and rollType ~= CL.ROLL.PASS and not (CL.db and CL.db.autoConfirm)
    if not CL.API.Roll(rollID, rollType) then return false end
    if waits then
        CL.Debug("roll %s: answered, the frame stays until the game closes the roll (bind-on-pickup)", tostring(rollID))
    else
        RF.Stop(rollID)
    end
    return true
end

function RF.IsQueued(rollID)
    for _, q in ipairs(queue) do
        if q.rollID == rollID then return true end
    end
    return false
end

function RF.QueuedCount()
    return #queue
end

-- The stack only moves when it is unlocked (options), or while
-- simulated rolls are on screen -- the natural moment to place it. A real roll
-- frame never moves by accident.
function RF.CanMove()
    if CL.db and not CL.db.locked then return true end
    return (CL.Sim and CL.Sim.ActiveCount() > 0) or false
end

-- Back to the default spot (also forgets the saved one).
function RF.ResetPosition()
    if CL.db then CL.db.point = nil end
    local a = GetAnchor()
    a:ClearAllPoints()
    a:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    RF.Layout()
end

function RF.RefreshVotes(rollID)
    local f = byRollID[rollID]
    if f then ApplyVotes(f) end
end

function RF.StopAll()
    -- the queue first: stopping a frame would otherwise pull a queued roll in
    for i = #queue, 1, -1 do table.remove(queue, i) end
    for rollID in pairs(byRollID) do RF.Stop(rollID) end
end

function RF.ActiveCount()
    return #active
end

function RF.GetFrame(rollID)
    return byRollID[rollID]
end

function RF.VisibleFrames()
    local frames = {}
    for i, f in ipairs(active) do frames[i] = f end
    return frames
end

function RF.Anchor()
    return GetAnchor()
end
