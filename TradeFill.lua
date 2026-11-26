-- Handing the won items over: when a player who won something in a loot session is in the trade
-- window with the master looter (whoever opened it), his items are put in the window for him.
-- A trade holds six items: when he won more, the next trade follows by itself once this one is
-- done. Nothing is ever accepted for you: you still press Trade.

local _, CL = ...

local TF = {}
CL.TradeFill = TF

local MAX_SLOTS = 6     -- the seventh slot of the window is the "will not be traded" one
local STEP = 0.15       -- between two items, so the client has time to take each one
local OPEN_WAIT = 0.4   -- after the window opens
local DONE_WAIT = 2     -- after it closes: for the bags to catch up before looking at what is left
local NEXT_WAIT = 1     -- before opening the next trade

local open = false      -- the trade window is open
local run = 0           -- identifies the filling in progress (a closed window cancels it)
local last = {}         -- { partner, before } of the last filling, for the follow-up

local function Print(msg) CL.Print(msg) end

local function Enabled()
    return CL.db ~= nil and CL.db.tradeFill ~= false and CL.MasterLoot and CL.MasterLoot.Enabled()
end

-- The name of the other player in the window, without his realm.
function TF.Partner()
    local name
    if GetUnitName then name = GetUnitName("NPC", true) end
    if type(name) ~= "string" or name == "" then name = UnitName and UnitName("NPC") end
    local label = rawget(_G, "TradeFrameRecipientNameText")
    if (type(name) ~= "string" or name == "") and type(label) == "table" and label.GetText then
        name = label:GetText()
    end
    if type(name) ~= "string" or name == "" then return nil end
    return (name:gsub("%-.*$", ""))
end

-- What the master looter owes to `name`: { guid, link, itemID, ... }, oldest first.
function TF.Pending(name)
    local list = {}
    if not name or not CL.LootPool then return list end
    for _, e in ipairs(CL.LootPool.List()) do
        if e.awardedTo and CL.MasterLoot.SameName(e.awardedTo, name) then list[#list + 1] = e end
    end
    return list
end

-- Where an item is in the bags: bag, slot, locked. (Replaceable: the tests have their own bags.)
function TF.Locate(guid)
    local Pool = CL.LootPool
    for bag = 0, Pool.LastBag() do
        for slot = 1, Pool.NumSlots(bag) do
            local item = Pool.ReadSlot(bag, slot)
            if item and item.guid == guid then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                return bag, slot, type(info) == "table" and info.isLocked or false
            end
        end
    end
    return nil
end

local function ItemIDOf(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- The slots of the window: what is already in them (by item) and which are free.
local function Slots()
    local placed, free = {}, {}
    for i = 1, MAX_SLOTS do
        local link = GetTradePlayerItemLink and GetTradePlayerItemLink(i)
        if type(link) == "string" and link ~= "" then
            local id = ItemIDOf(link)
            if id then placed[id] = (placed[id] or 0) + 1 end
        else
            free[#free + 1] = i
        end
    end
    return placed, free
end

-- The unit of a group member by name, nil when he is not there.
function TF.UnitFor(name)
    local prefix, count
    if IsInRaid and IsInRaid() then prefix, count = "raid", (GetNumGroupMembers and GetNumGroupMembers() or 40)
    else prefix, count = "party", 4 end
    for i = 1, count do
        local unit = prefix .. i
        local n = UnitName(unit)
        if n and CL.MasterLoot.SameName(n, name) then return unit end
    end
    return nil
end

-------------------------------------------------
-- Putting the items in the window
-------------------------------------------------
local function Report(name, placed, already, rest, skipped)
    local parts = {}
    if placed > 0 then
        parts[#parts + 1] = ("put %d item%s for %s in the trade window"):format(placed, placed > 1 and "s" or "", name)
    end
    if already > 0 then parts[#parts + 1] = ("%d already there"):format(already) end
    if skipped > 0 then parts[#parts + 1] = ("%d could not be taken from the bags"):format(skipped) end
    if rest > 0 then
        parts[#parts + 1] = ("%d more for a next trade"):format(rest)
    end
    if #parts > 0 then Print(table.concat(parts, ", ") .. ".") end
end

-- Fill the open window for `name` (the partner when omitted). Returns how many items it will place.
function TF.Fill(name)
    name = name or TF.Partner()
    if not name or not open then return 0 end
    local list = TF.Pending(name)
    if #list == 0 then return 0 end
    if CursorHasItem and CursorHasItem() then
        Print("you are holding an item: put it down, then open the trade again.")
        return 0
    end

    local placedNow, free = Slots()
    local queue, already, rest = {}, 0, 0
    for _, e in ipairs(list) do
        if placedNow[e.itemID] and placedNow[e.itemID] > 0 then
            placedNow[e.itemID] = placedNow[e.itemID] - 1
            already = already + 1
        elseif #queue < #free then
            queue[#queue + 1] = { entry = e, slot = free[#queue + 1] }
        else
            rest = rest + 1
        end
    end
    last = { partner = name, before = #list }
    if #queue == 0 then
        Report(name, 0, already, rest, 0)
        return 0
    end

    run = run + 1
    local mine = run
    local done, skipped = 0, 0
    local function Step(i)
        if mine ~= run or not open then return end   -- the window closed, or a newer filling took over
        local item = queue[i]
        if not item then
            if CursorHasItem and CursorHasItem() then ClearCursor() end
            Report(name, done, already, rest, skipped)
            return
        end
        local bag, slot, locked = TF.Locate(item.entry.guid)
        if bag and not locked then
            C_Container.PickupContainerItem(bag, slot)
            ClickTradeButton(item.slot)
            done = done + 1
        else
            skipped = skipped + 1
        end
        C_Timer.After(STEP, function() Step(i + 1) end)
    end
    Step(1)
    return #queue
end

-------------------------------------------------
-- The next trade
-------------------------------------------------
-- Called a moment after a window closed on a filling: what is still owed to the player?
function TF.FollowUp()
    local name, before = last.partner, last.before
    last = {}
    if not name then return end
    if CL.LootPool.Active() then CL.LootPool.Scan() end
    local left = #TF.Pending(name)
    if left == 0 then
        Print(("everything for %s is handed over."):format(name))
        return
    end
    if left >= before then return end   -- nothing left the bags: the trade was cancelled
    local word = left > 1 and "items" or "item"
    local unit = CL.db.tradeNext ~= false and TF.UnitFor(name)
    local near = unit and (not CheckInteractDistance or CheckInteractDistance(unit, 2))
    if unit and near and InitiateTrade then
        Print(("%d more %s for %s: opening the next trade."):format(left, word, name))
        C_Timer.After(NEXT_WAIT, function()
            if not open then pcall(InitiateTrade, unit) end
        end)
    else
        Print(("%d more %s for %s: trade with him again."):format(left, word, name))
    end
end

-------------------------------------------------
-- Events and command
-------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("TRADE_SHOW")
events:RegisterEvent("TRADE_CLOSED")
events:SetScript("OnEvent", function(_, event)
    if event == "TRADE_SHOW" then
        open = true
        if Enabled() then
            C_Timer.After(OPEN_WAIT, function() if open then TF.Fill() end end)
        end
    elseif event == "TRADE_CLOSED" then
        open = false
        run = run + 1   -- a filling in progress stops
        if last.partner then C_Timer.After(DONE_WAIT, TF.FollowUp) end
    end
end)

TF.IsOpen = function() return open end
