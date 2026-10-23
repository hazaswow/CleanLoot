-- Minimap button (LibDBIcon + LibDataBroker), the standard way, so minimap
-- button collectors and the addon compartment pick it up too.
--   Left-click   toggle Blizzard's Loot Rolls history window
--   Right-click  options
--   Shift-click  simulate a few drops

local ADDON_NAME, CL = ...

-- (not called Minimap: that is Blizzard's minimap frame)
local Button = {}
CL.MinimapButton = Button

local BUTTON_NAME = "CleanLoot"

-- Forever already has a loot history window (GroupLootHistoryFrame, load-on-demand),
-- with every drop and who rolled what, so CleanLoot does not ship its own.
function Button.ToggleLootHistory()
    if not _G.GroupLootHistoryFrame and C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_GroupLootHistoryFrame")
    end
    local frame = _G.GroupLootHistoryFrame
    if not frame then
        CL.Print("the loot history window is not available.")
        return
    end
    frame:SetShown(not frame:IsShown())
end

function Button.Setup()
    local LibStub = _G.LibStub
    if not (LibStub and LibStub.GetLibrary) then return end
    local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
    local dbicon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    if not (ldb and dbicon) then return end

    CL.db.minimap = CL.db.minimap or { hide = false }

    local object = ldb:NewDataObject(BUTTON_NAME, {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        OnClick = function(_, button)
            if button == "RightButton" then
                CL.Options.Open()
            elseif IsShiftKeyDown() then
                CL.Sim.Start(3)
            else
                Button.ToggleLootHistory()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(("CleanLoot v%s"):format(CL.Version()))
            tooltip:AddLine("Left-click: loot history", 1, 1, 1)
            tooltip:AddLine("Right-click: options", 1, 1, 1)
            tooltip:AddLine("Shift-click: simulate drops", 0.6, 0.6, 0.6)
        end,
    }) or ldb:GetDataObjectByName(BUTTON_NAME)

    if object and not dbicon:IsRegistered(BUTTON_NAME) then
        dbicon:Register(BUTTON_NAME, object, CL.db.minimap)
    end
    Button.icon = dbicon
end

function Button.SetHidden(hide)
    CL.db.minimap = CL.db.minimap or {}
    CL.db.minimap.hide = hide and true or false
    local dbicon = Button.icon
    if not dbicon then return end
    if hide then dbicon:Hide(BUTTON_NAME) else dbicon:Show(BUTTON_NAME) end
end
