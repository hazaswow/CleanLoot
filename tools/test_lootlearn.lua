-- What drops where, learned from boss kills and the game's loot history, against the stub client.
-- Run with lua tools/test_lootlearn.lua.
local WOW = dofile("tools/wowenv.lua")
local CL = WOW.CL
local Learn = CL.LootLearn
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1 io.write("FAIL: " .. label .. "\n") end
end
local said = {}
print = function(...) said[#said + 1] = table.concat({ ... }, " ") end
local function sayMatches(p)
    for _, line in ipairs(said) do if line:find(p, 1, true) then return true end end
    return false
end

function GetActiveLootRollIDs() return {} end
local function link(id, name) return ("|cffa335ee|Hitem:%d::::::::60:::::|h[%s]|h|r"):format(id, name) end

-- the game's loot history: [encounterID][key] = drop
local history = {}
C_LootHistory = C_LootHistory or {}
function C_LootHistory.GetSortedInfoForDrop(encounterID, key)
    return history[encounterID] and history[encounterID][key] or nil
end
C_LootHistory.GetAllEncounterInfos = function() return {} end
local where = { name = "Hall of Thanes", id = 2800 }
function GetInstanceInfo() return where.name, "party", 1, "Normal", 5, 0, false, where.id end

local function kill(id, name, success)
    WOW.FireEvent("ENCOUNTER_END", id, name, 1, 5, success == nil and 1 or success)
end
local function drop(id, key, item)
    history[id] = history[id] or {}
    history[id][key] = { itemHyperlink = item, lootListKey = key }
    WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", id, key)
end

CL.db.learned = nil

-------------------------------------------------
-- kills and drops
-------------------------------------------------
check(#Learn.List() == 0, "nothing learned at the start")
WOW.FireEvent("ENCOUNTER_START", 3001, "Faldrim Anvilmar", 1, 5)
kill(3001, "Faldrim Anvilmar")
check(Learn.Get(3001).kills == 1 and Learn.Get(3001).name == "Faldrim Anvilmar", "a boss kill is written down")
check(Learn.Get(3001).instance == 2800 and Learn.Get(3001).iname == "Hall of Thanes", "...with the instance it happened in")
drop(3001, 1, link(270227, "Ephemeral Choker"))
drop(3001, 2, link(271096, "Aetherwisp Bracers"))
local items = Learn.Items(3001)
check(#items == 2, "two drops, two items")
check(Learn.Get(3001).items[270227].drops == 1, "each dropped once")

-- the game reports a change to the same drop (a roll, the winner)
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 1)
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 1)
check(Learn.Get(3001).items[270227].drops == 1, "the same drop reported again counts once")

-- a second kill
WOW.FireEvent("ENCOUNTER_START", 3001, "Faldrim Anvilmar", 1, 5)
kill(3001, "Faldrim Anvilmar")
history[3001] = {}
drop(3001, 1, link(270227, "Ephemeral Choker"))   -- the keys start again
check(Learn.Get(3001).kills == 2 and Learn.Get(3001).items[270227].drops == 2, "a second kill counts, even if the game numbers its drops from 1 again")
local it = Learn.Items(3001)
check(it[1].itemID == 270227 and it[1].chance == 1 and it[2].chance == 0.5, "the chance is drops over kills (1 and 1/2)")
check(it[1].name == "Ephemeral Choker", "the item name is read from its link")

-- a wipe
WOW.FireEvent("ENCOUNTER_START", 3002, "Magmatus", 1, 5)
kill(3002, "Magmatus", 0)
check(Learn.Get(3002) == nil, "a wipe is not a kill")

-- another boss, another instance
where = { name = "Wailing Caverns", id = 43 }
kill(3010, "Mutanus the Devourer")
drop(3010, 5, link(6473, "Armor of the Fang"))
check(Learn.Get(3010).iname == "Wailing Caverns", "an other instance is kept apart")
check(#Learn.List() == 2 and Learn.List()[1].iname == "Hall of Thanes", "the list is by instance name")

-- the instance cannot be read
where = { name = nil, id = nil }
kill(3011, "Somebody")
check(Learn.Get(3011) ~= nil and Learn.Get(3011).instance == nil, "a kill is still noted when the instance is hidden")

-- things that must not break it
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 9999, 1)   -- not in the history
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", nil, nil)
history[3001][50] = { itemHyperlink = nil }
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 50)
check(Learn.Get(9999) == nil, "a drop the history does not know creates nothing")
check(Learn.Get(3001).items[270227].drops == 2, "...and a drop without a link changes nothing")
check(not Learn.Drop("x", 1, link(1, "A")) and not Learn.Drop(3001, 1, "no link"), "bad input is refused")

-- an item dropped twice in one kill counts twice (two drops)
WOW.FireEvent("ENCOUNTER_START", 3020, "Twin", 1, 5)
kill(3020, "Twin")
drop(3020, 1, link(777, "Twin Blade"))
drop(3020, 2, link(777, "Twin Blade"))
check(Learn.Get(3020).items[777].drops == 2 and Learn.Items(3020)[1].chance == 1, "two copies in one kill count as two drops, the chance stays at most 100%")

-------------------------------------------------
-- the option and the command
-------------------------------------------------
CL.db.learnLoot = false
kill(3030, "Off")
check(Learn.Get(3030) == nil, "with the option off nothing is written down")
CL.db.learnLoot = true

said = {}
Learn.Command("")
check(sayMatches("boss") and sayMatches("Hall of Thanes - Faldrim Anvilmar: 2 kills, 2 items"), "/cll learned lists the bosses")
said = {}
Learn.Command("faldrim")
check(sayMatches("Hall of Thanes - Faldrim Anvilmar: 2 kills") and sayMatches("Ephemeral Choker") and sayMatches("2/2"), "/cll learned <boss> lists its items with drops/kills")
said = {}
Learn.Command("nobody")
check(sayMatches("no boss matches"), "an unknown boss is said")
Learn.Command("clear")
check(#Learn.List() == 0, "/cll learned clear forgets it all")
said = {}
Learn.Command("")
check(sayMatches("nothing learned yet"), "...and says nothing is learned")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
