-- What drops where, learned from the game itself. The client does not say who drops what (loot
-- lives on the server), so CleanLoot writes it down as it happens: every boss kill, and every
-- item the game's loot history files under that boss' encounter. Nothing depends on another addon
-- and nothing is guessed: a line here is something that really dropped.
--
--   CL.db.learned[encounterID] = {
--       name, instance (the instance ID), iname (its name), kills,
--       items = { [itemID] = { link, drops } },
--   }
--
-- "drops" over "kills" is the chance seen so far. Only bosses: a kill is an ENCOUNTER_END with
-- success; items arrive through LOOT_HISTORY_UPDATE_DROP, which carries the encounter ID.

local _, CL = ...

local Learn = {}
CL.LootLearn = Learn

local Plain = CL.Plain

local counted = {}   -- [encounterID] = { [lootListKey] = true }: a drop is counted once per attempt

local function Store()
    CL.db.learned = CL.db.learned or {}
    return CL.db.learned
end

local function Enabled()
    return CL.db ~= nil and CL.db.learnLoot ~= false
end

local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("|Hitem:(%d+)")) or nil
end

local function ItemName(link)
    return type(link) == "string" and link:match("|h%[(.-)%]|h") or "?"
end

-- The entry of an encounter, created on first sight.
local function Entry(encounterID, name)
    local store = Store()
    local e = store[encounterID]
    if not e then
        e = { name = name or "?", kills = 0, items = {} }
        store[encounterID] = e
    end
    if name and name ~= "" then e.name = name end
    return e
end

-- Where we are: the instance ID and its name (nil outside, or when the client hides them).
local function Where()
    if not GetInstanceInfo then return nil end
    local ok, name, _, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
    if not ok then return nil end
    name, instanceID = Plain(name), Plain(instanceID)
    if type(name) ~= "string" or type(instanceID) ~= "number" then return nil end
    return instanceID, name
end

-------------------------------------------------
-- Writing it down
-------------------------------------------------
-- A boss was killed.
function Learn.Kill(encounterID, name, instanceID, instanceName)
    if type(encounterID) ~= "number" then return nil end
    local e = Entry(encounterID, name)
    e.kills = e.kills + 1
    if instanceID then e.instance, e.iname = instanceID, instanceName end
    e.last = CL.Now and CL.Now() or (GetServerTime and GetServerTime()) or nil
    return e
end

-- An item dropped from that boss. `key` makes a drop count once however often the game
-- reports a change to it (somebody rolled, the winner came in...). Returns true when it counted.
function Learn.Drop(encounterID, key, link)
    local itemID = ItemID(link)
    if type(encounterID) ~= "number" or not itemID then return false end
    if key ~= nil then
        counted[encounterID] = counted[encounterID] or {}
        if counted[encounterID][key] then return false end
        counted[encounterID][key] = true
    end
    local e = Entry(encounterID)
    local item = e.items[itemID]
    if not item then
        item = { link = link, drops = 0 }
        e.items[itemID] = item
    end
    item.drops = item.drops + 1
    return true
end

-------------------------------------------------
-- Reading it
-------------------------------------------------
function Learn.Get(encounterID)
    return CL.db and CL.db.learned and CL.db.learned[encounterID] or nil
end

-- The bosses seen: { { encounterID, name, iname, instance, kills, items = n }, ... },
-- by instance name, then boss name.
function Learn.List()
    local list = {}
    for id, e in pairs(Store()) do
        local n = 0
        for _ in pairs(e.items) do n = n + 1 end
        list[#list + 1] = { encounterID = id, name = e.name, iname = e.iname or "?", instance = e.instance,
            kills = e.kills, items = n }
    end
    table.sort(list, function(a, b)
        if a.iname ~= b.iname then return a.iname < b.iname end
        return a.name < b.name
    end)
    return list
end

-- The items of a boss, most often dropped first:
--   { { itemID, link, name, drops, kills, chance }, ... }   chance is 0..1 over the kills seen
function Learn.Items(encounterID)
    local e = Learn.Get(encounterID)
    local list = {}
    if not e then return list end
    for itemID, item in pairs(e.items) do
        list[#list + 1] = { itemID = itemID, link = item.link, name = ItemName(item.link), drops = item.drops,
            kills = e.kills, chance = e.kills > 0 and math.min(1, item.drops / e.kills) or nil }
    end
    table.sort(list, function(a, b)
        if a.drops ~= b.drops then return a.drops > b.drops end
        return a.itemID < b.itemID
    end)
    return list
end

-- Bosses whose name or instance contains `text` (any when empty).
function Learn.Find(text)
    text = (text or ""):lower()
    local found = {}
    for _, b in ipairs(Learn.List()) do
        if text == "" or b.name:lower():find(text, 1, true) or b.iname:lower():find(text, 1, true) then
            found[#found + 1] = b
        end
    end
    return found
end

-------------------------------------------------
-- Events
-------------------------------------------------
local function OnDrop(encounterID, key)
    encounterID, key = Plain(encounterID), Plain(key)
    local H = C_LootHistory
    if type(encounterID) ~= "number" or key == nil or not (H and H.GetSortedInfoForDrop) then return end
    local ok, drop = pcall(H.GetSortedInfoForDrop, encounterID, key)
    if not ok or type(drop) ~= "table" then return end
    local link = Plain(drop.itemHyperlink)
    if type(link) == "string" then Learn.Drop(encounterID, key, link) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")
frame:SetScript("OnEvent", function(_, event, a, b, c, d, e)
    if not Enabled() then return end
    if event == "ENCOUNTER_START" then
        a = Plain(a)
        if type(a) == "number" then counted[a] = nil end   -- a new attempt: its drops are new
    elseif event == "ENCOUNTER_END" then
        local id, name, success = Plain(a), Plain(b), Plain(e)
        if type(id) == "number" and success == 1 then
            local instanceID, instanceName = Where()
            Learn.Kill(id, type(name) == "string" and name or nil, instanceID, instanceName)
        end
    else
        local ok, err = pcall(OnDrop, a, b)
        if not ok and CL.db and CL.db.debug then CL.Print("learn: " .. tostring(err)) end
    end
end)
