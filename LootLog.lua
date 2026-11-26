-- The record of who won what, kept by CleanLoot itself: the game's own loot history lasts one
-- group and its window is the one that keeps breaking. Every roll the game decides (a winner, or
-- everybody passing), every item handed out as master looter and every loot session award is
-- written down with the instance and the boss it came from, so the window (LootWindow.lua) can
-- show it by instance, by boss, or all of it.
--
--   CL.db.winLog = { entry, ... }   oldest first, capped
--   entry = { id, t, instance, boss, encounterID, link, name, quality,
--             winner = { name, class, type, value, label, isSelf } | nil,
--             allPassed, rolls = { { name, class, type, value, isWinner }, ... }, passes, me, source }
--   source: "roll" (the game's roll), "master" (handed out by the master looter), "session"

local _, CL = ...

local Log = {}
CL.LootLog = Log

local Plain = CL.Plain
local KEEP = 300
local MAX_ROLLS = 10
local SAME_DROP = 1200   -- seconds: the same encounter and key within this is the same drop
local SESSIONS = "Loot sessions"

local live = {}          -- id -> entry, the drops seen since the login

local function Store()
    CL.db.winLog = CL.db.winLog or {}
    return CL.db.winLog
end

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

function Log.Enabled()
    return CL.db ~= nil and CL.db.historyRecord ~= false
end

function Log.Keep()
    local n = CL.db and tonumber(CL.db.historyKeep)
    return n and math.max(50, math.min(2000, math.floor(n))) or KEEP
end

local function Changed()
    if CL.LootWindow and CL.LootWindow.Refresh then CL.LootWindow.Refresh() end
end

-------------------------------------------------
-- Where and which boss
-------------------------------------------------
-- The instance (or the zone, outdoors) you are in.
function Log.Where()
    local ok, name, kind = pcall(GetInstanceInfo)
    name, kind = ok and Plain(name) or nil, ok and Plain(kind) or nil
    if type(name) == "string" and name ~= "" and kind ~= "none" then return name end
    local zone = GetRealZoneText and Plain(GetRealZoneText())
    if type(zone) == "string" and zone ~= "" then return zone end
    return "Elsewhere"
end

-- The encounter's name from the game's loot history, then from what CleanLoot learned.
function Log.BossName(encounterID)
    local H = C_LootHistory
    if H and H.GetAllEncounterInfos then
        local ok, list = pcall(H.GetAllEncounterInfos)
        if ok and type(list) == "table" then
            for _, enc in ipairs(list) do
                if Plain(enc.encounterID) == encounterID then
                    local name = Plain(enc.encounterName)
                    if type(name) == "string" and name ~= "" then return name end
                end
            end
        end
    end
    local learned = CL.LootLearn and CL.LootLearn.Get(encounterID)
    if learned and learned.name and learned.name ~= "?" then return learned.name end
    return "Unknown boss"
end

local function ItemName(link)
    return type(link) == "string" and link:match("|h%[(.-)%]|h") or "?"
end

-------------------------------------------------
-- Writing it down
-------------------------------------------------
local function Prune()
    local store, keep = Store(), Log.Keep()
    while #store > keep do table.remove(store, 1) end
end

-- The entry of a drop already written down (this login, or a recent one before a /reload).
local function Find(id, now)
    local e = live[id]
    if e and now - e.t <= SAME_DROP then return e end
    local store = Store()
    for i = #store, math.max(1, #store - 40), -1 do
        if store[i].id == id and now - store[i].t <= SAME_DROP then
            live[id] = store[i]
            return store[i]
        end
    end
    return nil
end

local function CompactRolls(res)
    local rolls = {}
    for i, r in ipairs(res.rolls or {}) do
        if i > MAX_ROLLS then break end
        rolls[i] = { name = r.name, class = r.class, type = r.type, value = r.value, isWinner = r.isWinner or nil }
    end
    return rolls
end

-- A finished roll (the shape of CL.API.GetResult) as an entry. `encounterID` is the boss it came from.
function Log.FromResult(res, encounterID, source, winnerOverride)
    if not Log.Enabled() or type(res) ~= "table" or type(res.link) ~= "string" then return nil end
    local now = Now()
    local id = ("%s:%s:%s"):format(source or "roll", tostring(encounterID or "?"), tostring(res.key))
    local e = Find(id, now)
    local isNew = e == nil
    if isNew then
        e = { id = id, t = now }
        Store()[#Store() + 1] = e
        live[id] = e
        e.instance = Log.Where()
        e.boss = encounterID and Log.BossName(encounterID) or "Unknown boss"
        e.encounterID = encounterID
    end
    e.source = source or "roll"
    e.link, e.name, e.quality = res.link, res.name or ItemName(res.link), res.quality
    local w = winnerOverride or res.winner
    if w then
        e.winner = { name = w.name, class = w.class, type = w.type, value = w.value, label = w.label,
            isSelf = w.isSelf or nil }
    end
    e.allPassed = res.allPassed or nil
    e.rolls = CompactRolls(res)
    e.passes = res.passes
    e.me = res.me
    if isNew then Prune() end
    Changed()
    return e
end

-- A drop the game's history reports on: written down once it has a winner or everybody passed.
function Log.Capture(encounterID, key)
    encounterID, key = Plain(encounterID), Plain(key)
    if type(encounterID) ~= "number" or key == nil then return nil end
    local res = CL.API.GetResult(key)
    if not res or not (res.winner or res.allPassed) then return nil end
    return Log.FromResult(res, encounterID, "roll")
end

-- The master looter handed the item of `res` to `who` (one row of its rolls).
function Log.Hand(res, who)
    if type(res) ~= "table" or type(who) ~= "table" then return nil end
    local encounterID = CL.API.EncounterForKey and CL.API.EncounterForKey(res.key)
    return Log.FromResult(res, encounterID, "master", {
        name = who.name, class = who.class, type = who.type, value = who.value, isSelf = who.isSelf,
    })
end

-- The awards of a finished loot session: { { item = { link, name, quality }, winner, cat, value, de }, ... }.
-- `labels` turns a roll category into its word (MS, OS, Other).
function Log.Session(awards, labels)
    if not Log.Enabled() or type(awards) ~= "table" then return 0 end
    local now, n = Now(), 0
    local day = date and date("%d/%m") or "?"
    local store = Store()
    for _, a in ipairs(awards) do
        local item = a.item or {}
        if type(item.link) == "string" and a.winner then
            local label
            if a.de then label = "to disenchant"
            elseif a.cat and labels and labels[a.cat] then label = ("%s %s"):format(labels[a.cat], tostring(a.value))
            else label = "by hand" end
            n = n + 1
            store[#store + 1] = {
                id = ("session:%d:%d"):format(now, n), t = now, instance = SESSIONS, boss = "Session " .. day,
                link = item.link, name = item.name or ItemName(item.link), quality = item.quality,
                winner = { name = a.winner, label = label }, source = "session", rolls = {},
            }
        end
    end
    if n > 0 then Prune() Changed() end
    return n
end

-------------------------------------------------
-- Reading it
-------------------------------------------------
function Log.All() return Store() end

function Log.Count() return #Store() end

function Log.Clear()
    CL.db.winLog = {}
    live = {}
    Changed()
end

local function IsMine(e)
    if e.winner and e.winner.isSelf then return true end
    local me = type(UnitName) == "function" and UnitName("player")
    return e.winner ~= nil and type(me) == "string" and CL.MasterLoot ~= nil
        and CL.MasterLoot.SameName(e.winner.name, me) or false
end
Log.IsMine = IsMine

-- The instances, the most recently active first, each with its bosses in the order they were met:
--   { { name, count, last, bosses = { { name, count, last }, ... } }, ... }
function Log.Tree(mineOnly)
    local byInstance, list = {}, {}
    for _, e in ipairs(Store()) do
        if not mineOnly or IsMine(e) then
            local inst = byInstance[e.instance]
            if not inst then
                inst = { name = e.instance, count = 0, last = 0, bosses = {}, byBoss = {} }
                byInstance[e.instance] = inst
                list[#list + 1] = inst
            end
            inst.count = inst.count + 1
            if e.t > inst.last then inst.last = e.t end
            local boss = inst.byBoss[e.boss]
            if not boss then
                boss = { name = e.boss, count = 0, last = 0 }
                inst.byBoss[e.boss] = boss
                inst.bosses[#inst.bosses + 1] = boss
            end
            boss.count = boss.count + 1
            if e.t > boss.last then boss.last = e.t end
        end
    end
    table.sort(list, function(a, b)
        if a.last ~= b.last then return a.last > b.last end
        return a.name < b.name
    end)
    for _, inst in ipairs(list) do inst.byBoss = nil end
    return list
end

-- The entries of a selection, newest first. `sel`: nil (everything), { instance = name } or
-- { instance = name, boss = name }.
function Log.Select(sel, mineOnly)
    local out = {}
    local store = Store()
    for i = #store, 1, -1 do
        local e = store[i]
        if (not sel or not sel.instance or e.instance == sel.instance)
            and (not sel or not sel.boss or e.boss == sel.boss)
            and (not mineOnly or IsMine(e)) then
            out[#out + 1] = e
        end
    end
    return out
end

-------------------------------------------------
-- Events
-------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")
frame:RegisterEvent("ENCOUNTER_START")
frame:SetScript("OnEvent", function(_, event, a, b)
    if not (CL.db and Log.Enabled()) then return end
    if event == "ENCOUNTER_START" then
        a = Plain(a)
        if type(a) == "number" then
            local prefix = "roll:" .. a .. ":"
            for id in pairs(live) do
                if id:sub(1, #prefix) == prefix then live[id] = nil end
            end
        end
    else
        local ok, err = pcall(Log.Capture, a, b)
        if not ok and CL.db.debug then CL.Print("loot log: " .. tostring(err)) end
    end
end)
