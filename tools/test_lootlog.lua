-- The loot record (who won what) and its window, against the stub client.
-- Run with lua tools/test_lootlog.lua.
local WOW = dofile("tools/wowenv.lua")
local CL = WOW.CL
local Log, Win = CL.LootLog, CL.LootWindow
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1 io.write("FAIL: " .. label .. "\n") end
end
local said = {}
print = function(...) said[#said + 1] = table.concat({ ... }, " ") end

function GetActiveLootRollIDs() return {} end
local serverTime = 1000000
function GetServerTime() return serverTime end
function UnitName(unit) if unit == "player" then return "Hazas War" end end
RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.5, b = 0.04 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }

local where = { name = "Hall of Thanes", kind = "party" }
function GetInstanceInfo() return where.name, where.kind end
function GetRealZoneText() return "Dun Morogh" end
C_LootHistory = C_LootHistory or {}
local encounters = { { encounterID = 3001, encounterName = "Faldrim Anvilmar" }, { encounterID = 3002, encounterName = "Magmatus" },
    { encounterID = 3010, encounterName = "Mutanus the Devourer" } }
C_LootHistory.GetAllEncounterInfos = function() return encounters end

local function link(id, name) return ("|cffa335ee|Hitem:%d::::::::60:::::|h[%s]|h|r"):format(id, name) end
local results = {}
CL.API.GetResult = function(key) return results[key] end
local keyEncounter = {}
CL.API.EncounterForKey = function(key) return keyEncounter[key] end

local function result(key, id, name, winner, extra)
    local r = { key = key, link = link(id, name), name = name, quality = 4, rolls = {}, passes = 0 }
    if winner then r.winner = winner end
    for k, v in pairs(extra or {}) do r[k] = v end
    results[key] = r
    return r
end
local function won(name, class, type_, value, isSelf) return { name = name, class = class, type = type_, value = value, isSelf = isSelf } end

CL.db.winLog = {}

-------------------------------------------------
-- writing it down
-------------------------------------------------
check(Log.Count() == 0, "the record starts empty")
result(1, 270227, "Ephemeral Choker", nil)
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 1)
check(Log.Count() == 0, "a drop nobody has won yet is not written down")

results[1].winner = won("Teki La", "MAGE", 1, 87)
results[1].rolls = { { name = "Teki La", class = "MAGE", type = 1, value = 87, isWinner = true },
    { name = "Hazas War", class = "DRUID", type = 2, value = 40, isSelf = true } }
results[1].passes = 2
results[1].me = { type = 2, value = 40 }
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 1)
check(Log.Count() == 1, "once it has a winner it is written down")
local e = Log.All()[1]
check(e.instance == "Hall of Thanes" and e.boss == "Faldrim Anvilmar" and e.encounterID == 3001, "...with the instance and the boss")
check(e.winner.name == "Teki La" and e.winner.value == 87 and #e.rolls == 2 and e.passes == 2 and e.me.value == 40, "...the winner, the rolls, the passes and my own roll")
check(e.name == "Ephemeral Choker" and e.quality == 4, "...and the item")

WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 1)
check(Log.Count() == 1, "the game reporting the same drop again changes nothing")

result(2, 270228, "Golemheart Stave", nil, { allPassed = true })
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 2)
check(Log.Count() == 2 and Log.All()[2].allPassed == true, "a drop everybody passed on is written down")

-- a new kill of the same boss: the game numbers its drops from 1 again
serverTime = serverTime + 5000
WOW.FireEvent("ENCOUNTER_START", 3001, "Faldrim Anvilmar")
result(1, 270227, "Ephemeral Choker", won("Yan Yarrow", "DRUID", 2, 12))
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 1)
check(Log.Count() == 3 and Log.All()[3].winner.name == "Yan Yarrow", "a later kill with the same keys is a new entry")

-- unreadable values
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", nil, nil)
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 9999, 77)
check(Log.Count() == 3, "an unknown or unreadable drop writes nothing")

CL.db.historyRecord = false
result(3, 1, "Off", won("A B", nil, 1, 1))
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 3)
check(Log.Count() == 3, "with the option off nothing is written down")
CL.db.historyRecord = true

-- the master looter hands an item out
keyEncounter[10] = 3002
local mres = result(10, 270230, "Kindlegem Girdle", nil)
Log.Hand(mres, { name = "Teki La", class = "MAGE", type = 1, value = 55 })
local h = Log.All()[4]
check(h and h.source == "master" and h.boss == "Magmatus" and h.winner.name == "Teki La", "a master loot hand-out is written down under its boss")
Log.Hand(mres, { name = "Teki La", class = "MAGE", type = 1, value = 55 })
check(Log.Count() == 4, "...once")

-- a loot session
serverTime = serverTime + 10
where = { name = "Stormwind City", kind = "none" }
local n = Log.Session({
    { item = { link = link(1, "Sword"), name = "Sword", quality = 4 }, winner = "Teki La", cat = 1, value = 90 },
    { item = { link = link(2, "Dust"), name = "Dust", quality = 2 }, winner = "Yan Yarrow", de = true },
    { item = { link = link(3, "Cloak"), name = "Cloak", quality = 3 }, winner = "Zed Zeta" },
}, { "MS", "OS", "Other" })
check(n == 3 and Log.Count() == 7, "the awards of a session are written down")
local s = Log.All()[5]
check(s.instance == "Loot sessions" and s.winner.label == "MS 90" and Log.All()[6].winner.label == "to disenchant" and Log.All()[7].winner.label == "by hand",
    "...with how each was given")

-------------------------------------------------
-- by instance and boss
-------------------------------------------------
local tree = Log.Tree()
check(#tree == 2 and tree[1].name == "Loot sessions" and tree[2].name == "Hall of Thanes", "the instances come most recent first")
check(tree[2].count == 4 and #tree[2].bosses == 2 and tree[2].bosses[1].name == "Faldrim Anvilmar" and tree[2].bosses[1].count == 3,
    "...with their bosses and counts")
check(#Log.Select() == 7, "no selection shows everything")
check(#Log.Select({ instance = "Hall of Thanes" }) == 4, "an instance shows its drops")
local fal = Log.Select({ instance = "Hall of Thanes", boss = "Faldrim Anvilmar" })
check(#fal == 3 and fal[1].winner.name == "Yan Yarrow", "a boss shows its drops, newest first")
check(#Log.Select({ instance = "Nowhere" }) == 0, "an unknown instance shows nothing")

-- what I won
Log.All()[3].winner.isSelf = true
check(#Log.Select(nil, true) == 1 and Log.Tree(true)[1].count == 1, "'only what I won' keeps my wins")
Log.All()[3].winner.isSelf = nil

-- the cap
CL.db.historyKeep = 50
for i = 1, 70 do
    results[100 + i] = nil
    result(100 + i, 5000 + i, "Filler " .. i, won("X Y", nil, 1, 1))
    WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3010, 100 + i)
end
check(Log.Count() == 50, "the record keeps only as many drops as asked (" .. Log.Count() .. ")")
check(Log.All()[50].name == "Filler 70", "...the oldest go first")
CL.db.historyKeep = 300

-------------------------------------------------
-- the window
-------------------------------------------------
Log.Clear()
check(Log.Count() == 0, "erasing empties the record")
where = { name = "Hall of Thanes", kind = "party" }
serverTime = serverTime + 100
result(1, 270227, "Ephemeral Choker", won("Teki La", "MAGE", 1, 87))
results[1].rolls = { { name = "Teki La", class = "MAGE", type = 1, value = 87, isWinner = true },
    { name = "Hazas War", class = "DRUID", type = 2, value = 40 } }
results[1].passes = 2
result(2, 270230, "Kindlegem Girdle", won("Hazas War", "DRUID", 2, 33, true))
result(3, 6473, "Armor of the Fang", nil, { allPassed = true })
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3001, 1)
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3002, 2)
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3010, 3)
where = { name = "Wailing Caverns", kind = "party" }
result(4, 6474, "Serpent's Shoulders", won("Yan Yarrow", "DRUID", 1, 70))
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3010, 4)
where = { name = "Hall of Thanes", kind = "party" }

Win.Open()
local w = Win.Window()
check(w and w:IsShown(), "the window opens")
check(w.heading:GetText():find("Hall of Thanes", 1, true), "it opens on the instance you are in (" .. tostring(w.heading:GetText()) .. ")")
local function rowTexts()
    local t = {}
    for _, r in ipairs(w.treeRows) do if r:IsShown() and r.item then t[#t + 1] = r.text:GetText() end end
    return t
end
local tree = rowTexts()
check(tree[1]:find("All loot", 1, true) and tree[1]:find("(4)", 1, true), "the tree starts with 'All loot' and its count (" .. tostring(tree[1]) .. ")")
local function find(pat) for i, t in ipairs(rowTexts()) do if t:find(pat, 1, true) then return i end end end
check(find("Wailing Caverns") and find("Hall of Thanes") and find("Faldrim") ~= nil and find("Magmatus") ~= nil, "instances and their bosses are listed")
local function shownEntries()
    local t = {}
    for _, r in ipairs(w.listRows) do if r:IsShown() and r.entry then t[#t + 1] = r.entry end end
    return t
end
check(#shownEntries() == 3, "the drops of the instance are listed (" .. #shownEntries() .. ")")

-- pick a boss
local idx = find("Magmatus")
w.treeRows[idx].__scripts.OnClick(w.treeRows[idx])
local list = shownEntries()
check(#list == 1 and list[1].name == "Kindlegem Girdle" and w.heading:GetText():find("Magmatus", 1, true), "a boss shows only its drops")

-- all loot
w.treeRows[1].__scripts.OnClick(w.treeRows[1])
check(#shownEntries() == 4, "'All loot' shows everything")

-- an instance
idx = find("Wailing Caverns")
w.treeRows[idx].__scripts.OnClick(w.treeRows[idx])
check(#shownEntries() == 1 and shownEntries()[1].name == "Serpent's Shoulders", "an other instance shows its own drops")

-- fold an instance
idx = find("Hall of Thanes")
w.treeRows[idx].toggle.__scripts.OnClick(w.treeRows[idx].toggle)
check(find("Magmatus") == nil and find("Hall of Thanes") ~= nil, "folding an instance hides its bosses")
w.treeRows[idx].toggle.__scripts.OnClick(w.treeRows[idx].toggle)
check(find("Magmatus") ~= nil, "...and unfolding brings them back")

-- what I won
w.mineCheck:SetChecked(true)
w.mineCheck.__scripts.OnClick(w.mineCheck)
w.treeRows[1].__scripts.OnClick(w.treeRows[1])
list = shownEntries()
check(#list == 1 and list[1].name == "Kindlegem Girdle", "'only what I won' filters the list")
w.mineCheck:SetChecked(false)
w.mineCheck.__scripts.OnClick(w.mineCheck)

-- the lines
local function row(name) for _, r in ipairs(w.listRows) do if r.entry and r.entry.name == name then return r end end end
w.treeRows[1].__scripts.OnClick(w.treeRows[1])
local ch = row("Ephemeral Choker")
check(ch.kind:GetText():find("Need", 1, true) and ch.roll:GetText() == "87" and ch.who:GetText():find("Teki La", 1, true),
    "a drop shows the kind of roll, the roll and the winner in their own columns")
check(row("Kindlegem Girdle").who:GetText():find("You", 1, true), "a drop I won says 'You'")
local ap = row("Armor of the Fang")
check(ap.kind:GetText():find("Pass", 1, true) and ap.who:GetText():find("Everybody", 1, true) and ap.roll:GetText() == "",
    "a drop everybody passed on says so")
local k, v = Win.Columns({ winner = { name = "A B", label = "MS 54" }, source = "session" })
check(k == "MS" and v == "54", "a session award's label is split into kind and roll")
k, v = Win.Columns({ winner = { name = "A B", label = "to disenchant" }, source = "session" })
check(k == "to disenchant" and v == "", "...and a label without a roll stays whole")
check(Win.WinnerText({ winner = { name = "A B", label = "to disenchant" }, source = "session" }):find("Given to", 1, true), "a hand-out says 'Given to'")

-- the tooltip
local r = row("Ephemeral Choker")
r.__scripts.OnEnter(r)
local tip = table.concat(GameTooltip.lines, "\n")
check(tip:find("Hall of Thanes", 1, true) and tip:find("Faldrim Anvilmar", 1, true), "the tooltip says where it dropped")

-- opening an item shows the players who rolled
local linked, previewed
ChatFrameUtil.InsertLink = function(l) linked = l end
function DressUpLink(l) previewed = l end
local function subLines()
    local t = {}
    for _, rr in ipairs(w.listRows) do
        if rr:IsShown() and not rr.entry and rr.sub:GetText() ~= "" then t[#t + 1] = rr end
    end
    return t
end
check(#subLines() == 0, "no item is opened at first")
r.__scripts.OnClick(r)
local subs = subLines()
check(#subs == 3, "a click opens the item: its 2 rolls and the passes (" .. #subs .. ")")
check(subs[1].sub:GetText():find("Teki La", 1, true) and subs[1].kind:GetText():find("Need", 1, true) and subs[1].roll:GetText() == "87"
    and subs[1].who:GetText():find("Winner", 1, true), "a player's line has the name, the kind of roll, the roll and a mark for the winner")
check(subs[2].roll:GetText() ~= "" and not subs[2].who:GetText():find("Winner", 1, true), "...the others carry no winner mark")
check(subs[3].sub:GetText():find("2 passed", 1, true), "...and the passes close the list")
check(w.listRows[1].entry ~= nil, "the opened item stays on its line")
r.__scripts.OnClick(r)
WOW.shift = true
r.__scripts.OnClick(r)
WOW.shift = false
check(linked == r.entry.link and #subLines() == 0, "shift-click links the item and does not open it")
WOW.ctrl = true
r.__scripts.OnClick(r)
WOW.ctrl = false
check(previewed == r.entry.link and #subLines() == 0, "ctrl-click shows the item's look in the dressing room and does not open it")
r.__scripts.OnClick(r)
r.__scripts.OnClick(r)
check(#subLines() == 0, "a second click closes it")
local noRolls = row("Armor of the Fang")
noRolls.__scripts.OnClick(noRolls)
check(#subLines() == 1 and subLines()[1].sub:GetText():find("No rolls recorded", 1, true), "an item without rolls says so")
noRolls.__scripts.OnClick(noRolls)

-- scrolling
for i = 1, 20 do
    results[200 + i] = nil
    result(200 + i, 7000 + i, "Many " .. i, won("X Y", nil, 1, 1))
    WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 3010, 200 + i)
end
Win.Refresh()
local before = shownEntries()[1].name
w.listRows[1]:GetParent().__scripts.OnMouseWheel(w.listRows[1]:GetParent(), -3)
check(shownEntries()[1].name ~= before, "the wheel scrolls the list")
w.listRows[1]:GetParent().__scripts.OnMouseWheel(w.listRows[1]:GetParent(), 50)
check(shownEntries()[1].name == before, "...and stops at the top")

-- empty
Log.Clear()
Win.Refresh()
check(#shownEntries() == 0 and w.count:GetText():find("0 drop", 1, true), "an empty record shows an empty list")

-- closing
w:Hide()
Win.Toggle()
check(w:IsShown(), "Toggle opens it")
Win.Toggle()
check(not w:IsShown(), "...and closes it")

-------------------------------------------------
-- /loot and the game's window
-------------------------------------------------
local calls = {}
SlashCmdList = SlashCmdList or {}
SlashCmdList.BLIZZLOOT = function(msg) calls[#calls + 1] = "blizzard:" .. tostring(msg) end
SLASH_BLIZZLOOT1 = "/loot"
SLASH_BLIZZLOOT2 = "/lootrolls"
Win.InstallSlash()
check(SlashCmdList.BLIZZLOOT ~= nil, "the game's /loot entry stays registered")
SlashCmdList.BLIZZLOOT("")
check(w:IsShown() and #calls == 0, "/loot opens CleanLoot's window instead of the game's")
w:Hide()
CL.db.historyReplace = false
SlashCmdList.BLIZZLOOT("x")
check(calls[1] == "blizzard:x" and not w:IsShown(), "with the option off /loot goes back to the game's own")
CL.db.historyReplace = true

-- the game's Loot Rolls window is put away
GroupLootHistoryFrame:Hide()
Win.GuardBlizzard()
GroupLootHistoryFrame:Show()
GroupLootHistoryFrame.__scripts.OnShow(GroupLootHistoryFrame)
WOW.Advance(0.5)
check(not GroupLootHistoryFrame:IsShown(), "the game's own window is hidden when it pops up")
CL.db.historyReplace = false
GroupLootHistoryFrame:Show()
GroupLootHistoryFrame.__scripts.OnShow(GroupLootHistoryFrame)
WOW.Advance(0.5)
check(GroupLootHistoryFrame:IsShown(), "with the option off it is left alone")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
