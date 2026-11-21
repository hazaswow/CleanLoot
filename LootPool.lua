-- Loot pool: the items in the master looter's bags that can still be handed out, kept
-- up to date as the bags change.
--
--   * a bind-on-pickup item with the "you may trade this item with the players who were
--     eligible for it within the next X" line (its time left is kept as a deadline), and
--   * a bind-on-equip item that is not bound yet (no deadline).
--
-- Only the master looter is tracked, and only when something changed in the bags (one look a
-- second at most); an item already known is never read again, so a scan is cheap. The list
-- is saved (CleanLootDB.pool, by item GUID) so a /reload or a new login keeps the deadlines
-- and the items the master looter chose to leave out.

local _, CL = ...

local Pool = {}
CL.LootPool = Pool

local MIN_QUALITY = 2       -- green and above: nothing below can be rolled for
local SCAN_DELAY = 1        -- seconds between two looks at the bags, at most
local LOGIN_DELAY = 5       -- bags and item data are not all there right after a loading screen

local ignored = {}          -- GUID -> true: looked at, nothing to hand out (not saved)

local function Store()
    if not CL.db.pool then CL.db.pool = {} end
    return CL.db.pool
end

local function Now()
    local t = type(GetServerTime) == "function" and GetServerTime()
    if type(t) == "number" then return t end
    t = type(time) == "function" and time()
    if type(t) == "number" then return t end
    return math.floor(GetTime())
end
Pool.Now = Now

-------------------------------------------------
-- Reading the tooltip of a bag item
-------------------------------------------------
-- "1 hour 59 min" in the game's own words: the units come from the client's duration formats
-- ("%d hr", "%d min", "%d sec", with their plural forms), the same way Gargul reads it.
local TimeTable
local function BuildTimeTable()
    if TimeTable then return end
    TimeTable = {}
    local formats = {
        { rawget(_G, "INT_SPELL_DURATION_HOURS"), 3600 },
        { rawget(_G, "INT_SPELL_DURATION_MIN"), 60 },
        { rawget(_G, "INT_SPELL_DURATION_SEC"), 1 },
    }
    for _, f in ipairs(formats) do
        local pattern, coefficient = f[1], f[2]
        if type(pattern) == "string" then
            local prefix = ""
            pattern = pattern:gsub("%%d(%s?)", function(space)
                prefix = "(%d+)" .. space
                return ""
            end)
            pattern = pattern:gsub("|4", ""):gsub("[:;]", " ")
            for unit in pattern:gmatch("(%S+)") do
                TimeTable[prefix .. unit] = coefficient
            end
        end
    end
end

local function SecondsIn(line)
    BuildTimeTable()
    local total, found = 0, false
    for pattern, coefficient in pairs(TimeTable) do
        local n = line:match(pattern)
        if n then
            total = total + tonumber(n) * coefficient
            found = true
        end
    end
    return found and total or nil
end

-- The game's "You may trade this item ... within the next %s." as a pattern.
local function TradeNeedle()
    local text = rawget(_G, "BIND_TRADE_TIME_REMAINING")
    if type(text) ~= "string" then return nil end
    return (text:gsub("[%(%)%.%-%+%[%]%?%*%^%$]", "%%%0"):gsub("%%s", ".-"))
end

-- What the tooltip says about handing the item out: "tradable" with the seconds left,
-- "boe" (not bound yet), or nil (nothing to hand out).
function Pool.Classify(lines)
    local needle = TradeNeedle()
    local soulbound, boe = false, false
    local soulText, boeText = rawget(_G, "ITEM_SOULBOUND"), rawget(_G, "ITEM_BIND_ON_EQUIP")
    for _, text in ipairs(lines) do
        if type(text) == "string" then
            if needle and text:find(needle) then
                local seconds = SecondsIn(text)
                if seconds then return "tradable", seconds end
            end
            if text == soulText then soulbound = true end
            if text == boeText then boe = true end
        end
    end
    if boe and not soulbound then return "boe" end
    return nil
end

local tip
-- The tooltip lines of a bag slot. (Replaceable: the tests feed their own.)
function Pool.ReadLines(bag, slot)
    tip = tip or CreateFrame("GameTooltip", "CleanLootScanTip", nil, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetBagItem(bag, slot)
    local lines = {}
    for i = 1, tip:NumLines() do
        local fs = _G["CleanLootScanTipTextLeft" .. i]
        lines[#lines + 1] = fs and fs:GetText() or ""
    end
    tip:Hide()
    return lines
end

-------------------------------------------------
-- Reading the bags
-------------------------------------------------
function Pool.LastBag()
    local n = rawget(_G, "NUM_BAG_SLOTS")
    return type(n) == "number" and n or 4
end

function Pool.NumSlots(bag)
    local n = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
    return type(n) == "number" and n or 0
end

-- { guid, link, itemID, quality } of what is in a slot, nil when it is empty. (Replaceable.)
function Pool.ReadSlot(bag, slot)
    local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
    if type(info) ~= "table" then return nil end
    local guid
    if ItemLocation and C_Item and C_Item.GetItemGUID then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        guid = location and C_Item.GetItemGUID(location)
    end
    return { guid = guid, link = info.hyperlink, itemID = info.itemID, quality = info.quality }
end

-------------------------------------------------
-- The list
-------------------------------------------------
local function Changed()
    if CL.Session and CL.Session.Refresh then CL.Session.Refresh() end
end

-- Look at the bags: new hand-outable items come in, what left (traded, used, expired) goes out.
-- Returns true when the list changed.
function Pool.Scan()
    local store = Store()
    local now = Now()
    local present, incomplete, changed = {}, false, false

    for bag = 0, Pool.LastBag() do
        for slot = 1, Pool.NumSlots(bag) do
            local item = Pool.ReadSlot(bag, slot)
            if item then
                if not item.guid or type(item.link) ~= "string" or item.quality == nil then
                    incomplete = true   -- the client has not loaded it yet: judge nothing on this look
                else
                    present[item.guid] = true
                    if not store[item.guid] and not ignored[item.guid] then
                        if item.quality < MIN_QUALITY then
                            ignored[item.guid] = true
                        else
                            local kind, seconds = Pool.Classify(Pool.ReadLines(bag, slot))
                            if kind == "tradable" then
                                store[item.guid] = { itemID = item.itemID, link = item.link, seen = now,
                                    expires = now + seconds, quality = item.quality }
                                changed = true
                            elseif kind == "boe" then
                                store[item.guid] = { itemID = item.itemID, link = item.link, seen = now,
                                    quality = item.quality }
                                changed = true
                            else
                                ignored[item.guid] = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- what left the bags or ran out of time goes (only after a complete look: a slot the
    -- client had not loaded must not make an item vanish)
    for guid, entry in pairs(store) do
        local expired = entry.expires and entry.expires <= now
        if expired or (not incomplete and not present[guid]) then
            store[guid] = nil
            changed = true
        end
    end
    if not incomplete then
        for guid in pairs(ignored) do
            if not present[guid] then ignored[guid] = nil end   -- gone from the bags: forget it
        end
    end
    if changed then Changed() end
    return changed
end

local function Name(link)
    return type(link) == "string" and link:match("|h%[(.-)%]|h") or "?"
end

-- The items, oldest first so the ones about to become untradable come first; the bind-on-equip
-- ones (no deadline) last:
--   { { guid, itemID, link, name, quality, seen, expires, remaining, excluded }, ... }
function Pool.List()
    local now = Now()
    local list = {}
    for guid, e in pairs(Store()) do
        if not (e.expires and e.expires <= now) then   -- an item past its deadline is no longer on offer
            list[#list + 1] = { guid = guid, itemID = e.itemID, link = e.link, name = Name(e.link),
                quality = e.quality, seen = e.seen, expires = e.expires,
                remaining = e.expires and e.expires - now or nil,
                excluded = e.excluded and true or false }
        end
    end
    table.sort(list, function(a, b)
        if (a.expires ~= nil) ~= (b.expires ~= nil) then return a.expires ~= nil end   -- deadlines before no deadline
        if a.expires and a.expires ~= b.expires then return a.expires < b.expires end
        if a.seen ~= b.seen then return (a.seen or 0) < (b.seen or 0) end
        return tostring(a.guid) < tostring(b.guid)
    end)
    return list
end

-- The ones offered in a session: all of them, but those the master looter left out.
function Pool.Offered()
    local list = {}
    for _, e in ipairs(Pool.List()) do
        if not e.excluded then list[#list + 1] = e end
    end
    return list
end

function Pool.SetExcluded(guid, excluded)
    local entry = Store()[guid]
    if not entry then return false end
    entry.excluded = excluded and true or nil
    Changed()
    return true
end

-- "1h 42m", "42m", "35s"
function Pool.FormatTime(seconds)
    seconds = math.floor(seconds or 0)
    if seconds >= 3600 then return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
    if seconds >= 60 then return ("%dm"):format(math.floor(seconds / 60)) end
    return ("%ds"):format(seconds)
end

-------------------------------------------------
-- Keeping it up to date
-------------------------------------------------
-- Only the master looter is followed.
function Pool.Active()
    local ML = CL.MasterLoot
    return CL.db ~= nil and ML ~= nil and ML.Enabled() and ML.IsMasterLooter()
end

local queued
-- Ask for a look at the bags soon: many bag events in a row make one look.
function Pool.Request(delay)
    if queued then return end
    queued = true
    C_Timer.After(delay or SCAN_DELAY, function()
        queued = false
        if Pool.Active() then Pool.Scan() end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
events:SetScript("OnEvent", function(_, event)
    -- right after a loading screen the group is not known yet: the look decides when it happens
    if event == "PLAYER_ENTERING_WORLD" then
        Pool.Request(LOGIN_DELAY)
    elseif event == "PARTY_LOOT_METHOD_CHANGED" then
        Pool.Request(1.5)
    elseif Pool.Active() then
        Pool.Request(SCAN_DELAY)   -- a bag changed
    end
end)
