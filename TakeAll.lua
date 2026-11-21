-- Take all: the master looter gives every master-loot item of the open loot window to
-- himself, to hand them out later (the loot pool then keeps them, with their trade deadlines).
-- A button under the loot window does it, or it happens by itself when the loot window opens
-- (an option; holding Shift skips it). The group is told in the chat, one message per item.
--
-- "Every item" means the ones at or above the loot threshold the game's group settings define:
-- those are the master-loot items; the rest is looted the normal way.

local _, CL = ...

local TA = {}
CL.TakeAll = TA

local ML = CL.MasterLoot

local TRIES = 4             -- the list of players is not always there the moment the window opens
local TRY_DELAY = 0.5
local CONFIRM_WAIT = 3      -- seconds the game has to confirm a hand-out to yourself
local SAY_GAP = 0.35        -- between two chat messages

local function Threshold()
    local get = rawget(_G, "GetLootThreshold")
    local value = type(get) == "function" and get()
    return type(value) == "number" and value or 2
end

local function MyName()
    local name = type(UnitName) == "function" and UnitName("player")
    return type(name) == "string" and name or nil
end

-- The master-loot items of the open loot window:
--   { { slot, link, quality, quantity }, ... }  (last slot first, like the game's own loops)
function TA.Slots()
    local list = {}
    local count = type(GetNumLootItems) == "function" and GetNumLootItems()
    if type(count) ~= "number" then return list end
    local threshold = Threshold()
    for slot = count, 1, -1 do
        local link = GetLootSlotLink(slot)
        if type(link) == "string" then   -- money has no link
            local _, _, quantity, _, quality, locked = GetLootSlotInfo(slot)
            if not locked and type(quality) == "number" and quality >= threshold then
                list[#list + 1] = { slot = slot, link = link, quality = quality,
                    quantity = type(quantity) == "number" and quantity or 1 }
            end
        end
    end
    return list
end

-- Can it be done now: master looter, master loot on, something to take.
function TA.Available()
    return ML.Enabled() and ML.IsMasterLooter() and #TA.Slots() > 0
end

-------------------------------------------------
-- The chat: one message at a time, so a big drop does not trip the game's flood limit
-------------------------------------------------
local queue, flushing = {}, false

local function Next()
    local message = table.remove(queue, 1)
    if not message then
        flushing = false
        return
    end
    ML.Say(message)
    C_Timer.After(SAY_GAP, Next)
end

local function Enqueue(message)
    queue[#queue + 1] = message
    if not flushing then
        flushing = true
        Next()
    end
end

-------------------------------------------------
-- Taking
-------------------------------------------------
local pending = {}   -- slot -> { link, quality, quantity, token }

local function Take(slots, attempt, announced)
    local me = MyName()
    local todo = {}
    if me then
        for _, s in ipairs(slots) do
            local index = ML.FindCandidate(s.slot, me)
            if index then todo[#todo + 1] = { slot = s, index = index } end
        end
    end
    if #todo == 0 then
        if attempt < TRIES then
            C_Timer.After(TRY_DELAY, function() Take(slots, attempt + 1, announced) end)
        else
            CL.Print("could not find you in the loot window's list of players, nothing was taken.")
        end
        return
    end

    if not announced then
        Enqueue("[CleanLoot] Taking the items for the master looter, to assign them later:")
    end
    local token = {}
    for _, t in ipairs(todo) do
        pending[t.slot.slot] = { link = t.slot.link, quality = t.slot.quality, quantity = t.slot.quantity, token = token }
        local ok, err = pcall(GiveMasterLoot, t.slot.slot, t.index)
        if not ok then
            pending[t.slot.slot] = nil
            CL.Print("could not take an item: " .. tostring(err))
        end
    end
    -- the game confirms each one by clearing its slot; the others did not go through
    C_Timer.After(CONFIRM_WAIT, function()
        for slot, p in pairs(pending) do
            if p.token == token then
                pending[slot] = nil
                CL.Print("the game did not confirm taking " .. (ML.ChatLink(p.link, "an item", p.quality)) .. ".")
            end
        end
    end)
end

-- Take every master-loot item of the open loot window. `auto`: it started by itself (nothing
-- is said when there is nothing to take).
function TA.Run(auto)
    if not ML.Enabled() then return false end
    if not ML.IsMasterLooter() then
        if not auto then CL.Print("only the master looter can take the loot for later.") end
        return false
    end
    local slots = TA.Slots()
    if #slots == 0 then
        if not auto then CL.Print("nothing to take: no item at or above the loot threshold in this window.") end
        return false
    end
    Take(slots, 1, false)
    return true
end

-------------------------------------------------
-- The button under the loot window
-------------------------------------------------
local button

local function CreateButton()
    local b = CreateFrame("Button", "CleanLootTakeAll", UIParent, "UIPanelButtonTemplate")
    b:SetSize(96, 22)
    b:SetText("Take all")
    b:SetFrameStrata("HIGH")
    b:SetToplevel(true)
    b:SetScript("OnClick", function() TA.Run(false) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Take all", 1, 1, 1)
        GameTooltip:AddLine("Gives you every item at or above the loot threshold, to hand out later.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    return b
end

function TA.Button() return button end

-- Show it under the loot window while there is something to take, hide it otherwise.
function TA.UpdateButton()
    local wanted = CL.db and CL.db.masterTakeButton and TA.Available()
    if not wanted then
        if button then button:Hide() end
        return
    end
    button = button or CreateButton()
    button:ClearAllPoints()
    local lootFrame = rawget(_G, "LootFrame")
    if type(lootFrame) == "table" and lootFrame.IsShown then
        button:SetPoint("TOP", lootFrame, "BOTTOM", 0, 8)
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
    button:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("LOOT_SLOT_CLEARED")
events:SetScript("OnEvent", function(_, event, slot)
    if not CL.db then return end
    if event == "LOOT_SLOT_CLEARED" then
        local p = pending[slot]
        if p then
            pending[slot] = nil
            local quantity = p.quantity > 1 and (" x" .. p.quantity) or ""
            Enqueue(ML.ChatLink(p.link, "?", p.quality) .. quantity)
        end
        TA.UpdateButton()
    elseif event == "LOOT_CLOSED" then
        if button then button:Hide() end
    else
        -- LOOT_OPENED: the window's contents are there a moment later
        C_Timer.After(0.1, function()
            TA.UpdateButton()
            if CL.db.masterTakeAuto and not (type(IsShiftKeyDown) == "function" and IsShiftKeyDown() == true) then
                TA.Run(true)
            end
        end)
    end
end)
