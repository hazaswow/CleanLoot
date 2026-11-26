-- Putting the won items in the trade window, and the next trade, against the stub client.
-- Run with lua tools/test_tradefill.lua.
local WOW = dofile("tools/wowenv.lua")
local CL = WOW.CL
local ML, TF, Pool = CL.MasterLoot, CL.TradeFill, CL.LootPool
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

-- the group: I am the master looter, Teki La and Yan Yarrow are with me
function GetLootMethod() return "master", 0, nil end
function IsInRaid() return false end
function IsInGroup() return true end
function GetNumGroupMembers() return 3 end
function UnitName(unit)
    if unit == "player" then return "Hazas War" end
    if unit == "party1" then return "Teki La" end
    if unit == "party2" then return "Yan Yarrow" end
    if unit == "NPC" then return nil end
    return nil
end
function GetActiveLootRollIDs() return {} end
local serverTime = 1000000
function GetServerTime() return serverTime end

-- the trade partner
local npc
function GetUnitName(unit) if unit == "NPC" then return npc end return UnitName(unit) end

-- the bags: [bag][slot] = { guid, link, itemID, quality, locked }
local bags = {}
local function link(id, uniq) return ("|cffa335ee|Hitem:%d:::::::%s:60:1491::1::1:28:5242:::::|h[Item %d]|h|r"):format(id, uniq, id) end
local function bagsReset() bags = { [0] = {} } end
function Pool.NumSlots(bag) return bag == 0 and 16 or 0 end
function Pool.ReadSlot(bag, slot)
    local it = bags[bag] and bags[bag][slot]
    if not it then return nil end
    return { guid = it.guid, link = it.link, itemID = it.itemID, quality = 4 }
end
C_Container = C_Container or {}
function C_Container.GetContainerItemInfo(bag, slot)
    local it = bags[bag] and bags[bag][slot]
    return it and { isLocked = it.locked or false } or nil
end
local cursor
function C_Container.PickupContainerItem(bag, slot) cursor = { bag = bag, slot = slot } end
function CursorHasItem() return cursor ~= nil end
function ClearCursor() cursor = nil end

-- the trade window
local tradeSlots = {}
function GetTradePlayerItemLink(i) return tradeSlots[i] and tradeSlots[i].link or nil end
function ClickTradeButton(i)
    if cursor then
        tradeSlots[i] = { bag = cursor.bag, slot = cursor.slot, link = bags[cursor.bag][cursor.slot].link }
        cursor = nil
    end
end
local initiated = {}
function InitiateTrade(unit) initiated[#initiated + 1] = unit end
local near = true
function CheckInteractDistance() return near end

-- the pool follows the bags
function Pool.Scan()
    local present = {}
    for slot = 1, 16 do local it = bags[0][slot] if it then present[it.guid] = true end end
    for guid in pairs(CL.db.pool) do if not present[guid] then CL.db.pool[guid] = nil end end
    return true
end

local nextGuid = 0
local function give(who, id, extra)
    nextGuid = nextGuid + 1
    local guid = "G" .. nextGuid
    local slot = 1
    while bags[0][slot] do slot = slot + 1 end
    local l = link(id, tostring(nextGuid))
    bags[0][slot] = { guid = guid, link = l, itemID = id, locked = extra and extra.locked }
    CL.db.pool[guid] = { itemID = id, link = l, seen = serverTime, expires = serverTime + 5000, quality = 4,
        awardedTo = who, awardedRoll = "MS 50" }
    return guid
end

local function reset(opts)
    bagsReset(); CL.db.pool = {}; tradeSlots = {}; cursor = nil; initiated = {}; said = {}
    npc = nil; near = true
    CL.db.tradeFill, CL.db.tradeNext = true, true
    WOW.FireEvent("TRADE_CLOSED")
    WOW.Advance(5)
    said = {}
end
local function openTrade(name)
    npc = name
    WOW.FireEvent("TRADE_SHOW")
    WOW.Advance(3)
end
-- the trade goes through: what is in the slots leaves the bags
local function complete()
    for i = 1, 6 do
        local s = tradeSlots[i]
        if s then bags[s.bag][s.slot] = nil end
    end
    tradeSlots = {}
    WOW.FireEvent("TRADE_CLOSED")
    WOW.Advance(5)
end
local function slotsUsed() local n = 0 for i = 1, 6 do if tradeSlots[i] then n = n + 1 end end return n end

-------------------------------------------------
-- a player's items go in the window
-------------------------------------------------
reset()
check(TF.Partner() == nil, "no window, no partner")
npc = "Teki La-Realm"
check(TF.Partner() == "Teki La", "the realm is cut off the partner's name")
npc = nil

reset()
local a = give("Teki La", 100)
local b = give("Teki La", 101)
local other = give("Yan Yarrow", 102)
local free = give(nil, 103)
check(#TF.Pending("Teki La") == 2, "two items are owed to Teki La")
check(#TF.Pending("Yan Yarrow") == 1 and #TF.Pending("Nobody") == 0, "...one to Yan, none to somebody else")
openTrade("Teki La")
check(slotsUsed() == 2, "the two items are in the window")
check(tradeSlots[1].link == bags[0][1].link and tradeSlots[2].link == bags[0][2].link, "...Teki's items, in order")
check(sayMatches("put 2 items for Teki La"), "it says what it did")
check(cursor == nil, "the cursor is left empty")
complete()
check(sayMatches("everything for Teki La is handed over"), "once traded, it says everything is handed over")
check(#initiated == 0, "...and opens no further trade")
check(CL.db.pool[other] ~= nil and CL.db.pool[free] ~= nil, "the others' items are untouched")

-- somebody who won nothing
reset()
give("Yan Yarrow", 102)
openTrade("Teki La")
check(slotsUsed() == 0 and #said == 0, "a player who won nothing gets nothing, and no noise")

-- the option
reset()
give("Teki La", 100)
CL.db.tradeFill = false
openTrade("Teki La")
check(slotsUsed() == 0, "with the option off nothing is placed")

-- not the master loot switch on
reset()
give("Teki La", 100)
ML.SetEnabled(false)
openTrade("Teki La")
check(slotsUsed() == 0, "with the master loot features off nothing is placed")
ML.SetEnabled(true)

-------------------------------------------------
-- more than six
-------------------------------------------------
reset()
for i = 1, 8 do give("Teki La", 200 + i) end
openTrade("Teki La")
check(slotsUsed() == 6, "six items fill the six slots")
check(sayMatches("2 more for a next trade"), "...and it says two are left")
complete()
check(#TF.Pending("Teki La") == 2, "two are still owed")
check(initiated[1] == "party1" and #initiated == 1, "the next trade is opened with Teki La by itself")
check(sayMatches("2 more items for Teki La: opening the next trade"), "...and it says so")
openTrade("Teki La")
check(slotsUsed() == 2, "the second trade gets the two left")
complete()
check(sayMatches("everything for Teki La is handed over") and #initiated == 1, "...and that is the end")

-- far away
reset()
for i = 1, 7 do give("Teki La", 300 + i) end
openTrade("Teki La")
near = false
complete()
check(#initiated == 0 and sayMatches("1 more item for Teki La: trade with him again"), "too far for a trade: he is told to come back")

-- the option for the next trade is off
reset()
for i = 1, 7 do give("Teki La", 300 + i) end
CL.db.tradeNext = false
openTrade("Teki La")
complete()
check(#initiated == 0 and sayMatches("trade with him again"), "with the option off the next trade is left to the players")

-- not in the group any more
reset()
for i = 1, 7 do give("Zed Zeta", 300 + i) end
openTrade("Zed Zeta")
complete()
check(#initiated == 0 and sayMatches("trade with him again"), "somebody who left the group cannot be traded with by itself")

-- cancelled
reset()
for i = 1, 3 do give("Teki La", 400 + i) end
openTrade("Teki La")
check(slotsUsed() == 3, "three items placed")
tradeSlots = {}
WOW.FireEvent("TRADE_CLOSED")
WOW.Advance(5)
check(#initiated == 0 and not sayMatches("handed over") and not sayMatches("opening"), "a cancelled trade starts nothing and claims nothing")

-------------------------------------------------
-- awkward cases
-------------------------------------------------
-- something already in the window
reset()
local x = give("Teki La", 500)
give("Teki La", 501)
openTrade("Teki La")
check(slotsUsed() == 2, "baseline: both placed")
tradeSlots, cursor = {}, nil
tradeSlots[1] = { bag = 0, slot = 1, link = bags[0][1].link }   -- he put the first one in by hand
WOW.FireEvent("TRADE_CLOSED") WOW.Advance(5)
said = {}
openTrade("Teki La")
check(slotsUsed() == 2 and tradeSlots[2] and tradeSlots[2].link == bags[0][2].link, "an item already in the window is not put twice")
check(sayMatches("1 already there"), "...and it says so")

-- two copies of the same item
reset()
give("Teki La", 600)
give("Teki La", 600)
openTrade("Teki La")
check(slotsUsed() == 2 and tradeSlots[1].link ~= tradeSlots[2].link, "two copies of one item both go in, each its own copy")

-- holding something
reset()
give("Teki La", 100)
cursor = { bag = 0, slot = 9 }
openTrade("Teki La")
check(slotsUsed() == 0 and sayMatches("holding an item"), "with an item on the cursor nothing is touched")
cursor = nil

-- a locked item
reset()
give("Teki La", 100, { locked = true })
give("Teki La", 101)
openTrade("Teki La")
check(slotsUsed() == 1 and sayMatches("1 could not be taken"), "a locked item is skipped and reported")

-- the window closes in the middle
reset()
for i = 1, 5 do give("Teki La", 700 + i) end
npc = "Teki La"
WOW.FireEvent("TRADE_SHOW")
WOW.Advance(0.5)   -- the first items go in
local part = slotsUsed()
WOW.FireEvent("TRADE_CLOSED")
WOW.Advance(1)
check(part >= 1 and part < 5 and slotsUsed() == part, "a window closed in the middle stops the filling")
check(cursor == nil, "...without an item stuck on the cursor")

-- an item the player won back is not given twice
reset()
local g = give("Teki La", 800)
CL.db.pool[g].awardedTo = nil
openTrade("Teki La")
check(slotsUsed() == 0, "an item taken back from the winner is not handed over")

-- the disenchanter's items too
reset()
local d = give("Teki La", 900)
CL.db.pool[d].awardedRoll = "disenchant"
openTrade("Teki La")
check(slotsUsed() == 1, "what is given to the disenchanter goes in the window as well")

realPrint = nil
io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
