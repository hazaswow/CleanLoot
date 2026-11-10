-- Controller mode (opt-in; "keyboard rolls" inside): select a visible roll, inspect it,
-- answer Need / Greed / Pass with key or gamepad bindings, or /cll commands. Nothing here
-- runs unless "Enable controller mode" is ticked in the options.

local _, CL = ...

local K = {}
CL.Keyboard = K

local selectedID, selectedFrame
local inspection, inspectionAnchor

-- The actions that can carry a key, in the order the options panel lists them.
K.ACTIONS = {
    { action = "CLEANLOOT_NEED", label = "Need" },
    { action = "CLEANLOOT_NEXT", label = "Next" },
    { action = "CLEANLOOT_GREED", label = "Greed" },
    { action = "CLEANLOOT_PREVIOUS", label = "Previous" },
    { action = "CLEANLOOT_PASS", label = "Pass" },
    { action = "CLEANLOOT_INSPECT", label = "Inspect" },
}

local function Eligible(f)
    if not f or not f.rollID then return false end
    if CL.Plain(f.link) or CL.Plain(f.itemName) then return true end
    for _, rollType in ipairs(CL.ROLL_ORDER) do
        if f.buttons[rollType] and not f.buttons[rollType].unavailable then return true end
    end
    return false
end

local function Reason(f, rollType)
    local reason = CL.Plain(rollType == CL.ROLL.NEED and f.reasonNeed or f.reasonGreed)
    return (reason and rawget(_G, "LOOT_ROLL_INELIGIBLE_REASON" .. tostring(reason)))
        or ("You can't roll %s on this item."):format(CL.ROLL_NAME[rollType])
end

-------------------------------------------------
-- Inspection tooltip (its own tooltip, beside the stack)
-------------------------------------------------
local function EnsureInspectionAnchor()
    if not inspectionAnchor then
        inspectionAnchor = CreateFrame("Frame", nil, UIParent)
        inspectionAnchor:SetSize(252, 1)
        inspectionAnchor:Show()
    end
end

local function EnsureInspection()
    if inspection then return end
    EnsureInspectionAnchor()
    inspection = CreateFrame("GameTooltip", "CleanLootInspectionTooltip", UIParent, "GameTooltipTemplate")
    inspection:SetClampedToScreen(true)
    inspection:EnableMouse(false)
end

function K.Layout()
    if CL.db.keyboardEnabled and #CL.RollFrames.VisibleFrames() > 0 then EnsureInspectionAnchor() end
    if not inspectionAnchor then return end
    local up = CL.db.growDirection == "UP"
    inspectionAnchor:ClearAllPoints()
    inspectionAnchor:SetScale(CL.db.frameScale or CL.DEFAULT_SCALE)
    inspectionAnchor:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", CL.RollFrames.Anchor(),
        up and "BOTTOMLEFT" or "TOPLEFT")
    if not inspection then return end
    inspection:ClearAllPoints()
    if CL.db.keyboardInspectSide == "LEFT" then
        inspection:SetPoint(up and "BOTTOMRIGHT" or "TOPRIGHT", inspectionAnchor,
            up and "BOTTOMLEFT" or "TOPLEFT", -12, 0)
    else
        inspection:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", inspectionAnchor,
            up and "BOTTOMRIGHT" or "TOPRIGHT", 12, 0)
    end
end

-- The roll the inspection shows: the one under the mouse (default), or the selected one.
local hoveredFrame, hoveredID

local function InspectionFrame()
    if not CL.db.keyboardInspectSticky then return hoveredFrame end
    return selectedFrame
end

local function ShowInspection()
    local target = InspectionFrame()
    if not (CL.db.keyboardEnabled and CL.db.keyboardInspect and Eligible(target)) then
        if inspection then inspection:Hide() end
        return
    end
    EnsureInspection()
    inspection:SetOwner(inspectionAnchor, "ANCHOR_NONE")
    K.Layout()
    inspection:ClearLines()
    local link = CL.Plain(target.link)
    local name = CL.Plain(target.itemName)
    local shown = false
    if link then shown = pcall(inspection.SetHyperlink, inspection, link) end
    if not shown then
        local r, g, b = CL.QualityColor(target.quality)
        inspection:SetText(name or "Item details unavailable", r, g, b)
    else
        local pawnUpdate = CL.db.keyboardPawn and rawget(_G, "PawnUpdateTooltip")
        if type(pawnUpdate) == "function" then
            local ok, err = pcall(pawnUpdate, inspection:GetName(), "SetHyperlink", link)
            if not ok then CL.Debug("Pawn inspection update failed: %s", tostring(err)) end
        end
    end
    inspection:Show()
end

-------------------------------------------------
-- Key hints on the selected roll's buttons
-------------------------------------------------
local bindingActions = {
    [CL.ROLL.NEED] = "CLEANLOOT_NEED",
    [CL.ROLL.GREED] = "CLEANLOOT_GREED",
    [CL.ROLL.PASS] = "CLEANLOOT_PASS",
}

-- The first key bound to an action, as text ("Shift-2"), or nil when unbound.
function K.KeyText(action)
    local getKey = rawget(_G, "GetBindingKey")
    if type(getKey) ~= "function" then return nil end
    local ok, key = pcall(getKey, action)
    key = ok and CL.Plain(key) or nil
    if type(key) ~= "string" or key == "" then return nil end
    local getText = rawget(_G, "GetBindingText")
    if type(getText) == "function" then
        local textOK, text = pcall(getText, key, "KEY_", true)
        text = textOK and CL.Plain(text) or nil
        if type(text) == "string" and text ~= "" then return text end
    end
    return key
end

local function SetBindingText(hint, text)
    hint:SetText(text)
    hint:SetWidth(0)
    local font, _, flags = hint:GetFont()
    if font then
        local size = 9
        hint:SetFont(font, size, flags)
        while size > 6 and hint:GetStringWidth() > 48 do
            size = size - 1
            hint:SetFont(font, size, flags)
        end
    end
    hint:SetWidth(48)
    hint:Show()
end

function K.RefreshBindings()
    if not CL.db then return end
    for _, f in ipairs(CL.RollFrames.VisibleFrames()) do
        for _, rollType in ipairs(CL.ROLL_ORDER) do
            local b = f.buttons[rollType]
            local text = CL.db.keyboardEnabled and f == selectedFrame and not b.unavailable
                and K.KeyText(bindingActions[rollType])
            b.label:ClearAllPoints()
            if text then
                b.label:SetPoint("TOP", b, "TOP", -6, -1)
                SetBindingText(b.binding, text)
            else
                b.label:SetPoint("CENTER")
                b.binding:Hide()
            end
        end
    end
end

-------------------------------------------------
-- Setting a key from CleanLoot's own options (the game's Key Bindings page lists
-- the same actions under "CleanLoot")
-------------------------------------------------
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }

function K.IsModifier(key)
    return MODIFIER_KEYS[key] == true
end

-- "SHIFT-2" for the key just pressed, with the modifiers held, in the order the game expects.
function K.Combo(key)
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end

local function SaveBindingSet()
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

function K.Unbind(action)
    if InCombat() then
        CL.Print("key bindings cannot be changed during combat.")
        return false
    end
    for _, key in ipairs({ GetBindingKey(action) }) do SetBinding(key) end
    SaveBindingSet()
    K.RefreshBindings()
    return true
end

-- One key per action: the previous key of the action goes, and a key another action
-- had is taken over (and said so).
function K.Bind(key, action)
    if InCombat() then
        CL.Print("key bindings cannot be changed during combat.")
        return false
    end
    local previous = GetBindingAction and GetBindingAction(key) or ""
    for _, old in ipairs({ GetBindingKey(action) }) do SetBinding(old) end
    SetBinding(key, action)
    SaveBindingSet()
    if type(previous) == "string" and previous ~= "" and previous ~= action then
        local name = GetBindingName and GetBindingName(previous) or previous
        CL.Print(("%s was bound to %s: it is now yours."):format(GetBindingText and GetBindingText(key) or key,
            tostring(name)))
    end
    K.RefreshBindings()
    return true
end

-------------------------------------------------
-- Selection
-------------------------------------------------
local function Select(f)
    if selectedFrame then selectedFrame.selection:Hide() end
    selectedFrame = Eligible(f) and f or nil
    selectedID = selectedFrame and selectedFrame.rollID or nil
    if selectedFrame then selectedFrame.selection:Show() end
    K.RefreshBindings()
    ShowInspection()
end

local function First()
    for _, f in ipairs(CL.RollFrames.VisibleFrames()) do
        if Eligible(f) then return f end
    end
end

function K.OnChanged()
    if not CL.db.keyboardEnabled then return end
    if selectedID and CL.RollFrames.GetFrame(selectedID) == selectedFrame then
        K.RefreshBindings()
        ShowInspection()
    elseif CL.db.keyboardInspect and CL.db.keyboardInspectSticky then
        Select(First())   -- the inspection follows the selection: there is always one
    else
        Select(nil)
    end
end

function K.OnRemoved(rollID, index, removedFrame)
    if removedFrame then removedFrame.selection:Hide() end
    if hoveredFrame == removedFrame then hoveredFrame, hoveredID = nil, nil end
    if selectedID ~= rollID then
        K.OnChanged()
        return
    end
    local frames = CL.RollFrames.VisibleFrames()
    local nextFrame
    if CL.db.keyboardEnabled and #frames > 0 then
        for offset = 0, #frames - 1 do
            local f = frames[((index - 1 + offset) % #frames) + 1]
            if Eligible(f) then nextFrame = f break end
        end
    end
    Select(nextFrame)
end

function K.SetEnabled(enabled)
    CL.db.keyboardEnabled = enabled and true or false
    if CL.db.keyboardEnabled then K.OnChanged() else Select(nil) end
    K.Layout()
    if CL.Options and CL.Options.Refresh then CL.Options.Refresh() end  -- the options that depend on it
end

-- The inspection tooltip on or off (an option; also the Inspect binding).
function K.SetInspect(enabled)
    CL.db.keyboardInspect = enabled and true or false
    if CL.db.keyboardInspect and CL.db.keyboardEnabled and not selectedID and CL.db.keyboardInspectSticky then
        Select(First())
    else
        ShowInspection()
    end
    K.Layout()
end

-- By default the mouse rolling over a roll shows its inspection and leaving hides it; with
-- "sticky" on, the inspection follows the selected roll and stays up (no mouse needed).
function K.SetInspectSticky(enabled)
    CL.db.keyboardInspectSticky = enabled and true or false
    hoveredFrame, hoveredID = nil, nil
    if CL.db.keyboardInspect and CL.db.keyboardEnabled and CL.db.keyboardInspectSticky and not selectedID then
        Select(First())
    else
        ShowInspection()
    end
    K.Layout()
end

function K.SetPawn(enabled)
    CL.db.keyboardPawn = enabled and true or false
    ShowInspection()
end

-- Which roll the mouse is over, looked at a few times a second while it matters.
function K.UpdateHover()
    if not (CL.db and CL.db.keyboardEnabled and CL.db.keyboardInspect and not CL.db.keyboardInspectSticky) then
        if hoveredFrame then
            hoveredFrame, hoveredID = nil, nil
            ShowInspection()
        end
        return
    end
    local target
    for _, f in ipairs(CL.RollFrames.VisibleFrames()) do
        if f.IsMouseOver and f:IsMouseOver() then target = f break end
    end
    local id = target and target.rollID or nil
    if target ~= hoveredFrame or id ~= hoveredID then
        hoveredFrame, hoveredID = target, id
        ShowInspection()
    end
end

local hoverWatcher = CreateFrame("Frame")
hoverWatcher:Show()
local sinceHoverCheck = 0
hoverWatcher:SetScript("OnUpdate", function(_, elapsed)
    sinceHoverCheck = sinceHoverCheck + (elapsed or 0)
    if sinceHoverCheck < 0.1 then return end
    sinceHoverCheck = 0
    K.UpdateHover()
end)

function K.SetSide(side)
    CL.db.keyboardInspectSide = side == "LEFT" and "LEFT" or "RIGHT"
    K.Layout()
end

function K.SelectedID()
    return selectedID
end

-------------------------------------------------
-- Actions
-------------------------------------------------
local function LootConfirmationOpen()
    local findPopup = rawget(_G, "StaticPopup_FindVisible")
    if type(findPopup) == "function" then
        local ok, popup = pcall(findPopup, "CONFIRM_LOOT_ROLL")
        if ok and popup then return true end
    end
    for i = 1, 4 do
        local popup = rawget(_G, "StaticPopup" .. i)
        if popup and popup.which == "CONFIRM_LOOT_ROLL" and popup:IsShown() then return true end
    end
    return false
end

function K.Action(action)
    if not CL.db.keyboardEnabled then
        CL.Print("Enable controller mode in CleanLoot options first.")
        return
    end
    if action == "inspect" then
        K.SetInspect(not CL.db.keyboardInspect)
        if CL.Options and CL.Options.Refresh then CL.Options.Refresh() end
        return
    end
    local frames = CL.RollFrames.VisibleFrames()
    if not selectedID or CL.RollFrames.GetFrame(selectedID) ~= selectedFrame then
        local first = First()
        Select(first)
        if not first then CL.Print("No visible loot roll to select.") end
        return
    end
    if action == "next" or action == "previous" then
        local index
        for i, f in ipairs(frames) do if f.rollID == selectedID then index = i break end end
        if not index then Select(nil) return end
        local step = action == "next" and 1 or -1
        for offset = 1, #frames do
            local f = frames[((index - 1 + step * offset) % #frames) + 1]
            if Eligible(f) then Select(f) return end
        end
        return
    end
    local rollType = ({ need = CL.ROLL.NEED, greed = CL.ROLL.GREED, pass = CL.ROLL.PASS })[action]
    if rollType == nil then return end
    if LootConfirmationOpen() then
        CL.Print("Answer the loot confirmation first.")
        return
    end
    local button = selectedFrame.buttons[rollType]
    if not button or button.unavailable then
        CL.Print(Reason(selectedFrame, rollType))
        return
    end
    -- the same answer as a click: a bind-on-pickup roll waits for the game's confirmation
    if not CL.RollFrames.Answer(selectedID, rollType, selectedFrame.bop) then
        CL.Print("Roll not submitted; the item remains selected.")
    end
end

BINDING_NAME_CLEANLOOT_NEXT = "CleanLoot: select next loot roll"
BINDING_NAME_CLEANLOOT_PREVIOUS = "CleanLoot: select previous loot roll"
BINDING_NAME_CLEANLOOT_INSPECT = "CleanLoot: toggle loot inspection"
BINDING_NAME_CLEANLOOT_NEED = "CleanLoot: roll Need"
BINDING_NAME_CLEANLOOT_GREED = "CleanLoot: roll Greed"
BINDING_NAME_CLEANLOOT_PASS = "CleanLoot: pass on loot"
function CleanLootKeyboardAction(action) K.Action(action) end

local bindingWatcher = CreateFrame("Frame")
bindingWatcher:RegisterEvent("UPDATE_BINDINGS")
bindingWatcher:SetScript("OnEvent", function()
    K.RefreshBindings()
    if CL.Options and CL.Options.Refresh then CL.Options.Refresh() end
end)
