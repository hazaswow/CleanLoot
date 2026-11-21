-- The loot pool, "Take all" and the session list, against the stub client.
-- Run with lua tools/test_lootpool.lua.
local WOW = dofile("tools/wowenv.lua")
local CL = WOW.CL
local ML, Pool, TA, Session = CL.MasterLoot, CL.LootPool, CL.TakeAll, CL.Session
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1 io.write("FAIL: " .. label .. "\n") end
end

local said = {}
local realPrint = print
print = function(...) said[#said + 1] = table.concat({ ... }, " ") end
local function sayMatches(p)
    for _, line in ipairs(said) do if line:find(p, 1, true) then return true end end
    return false
end

-- the game's own strings
BIND_TRADE_TIME_REMAINING = "You may trade this item with players that were also eligible to receive this loot within the next %s."
INT_SPELL_DURATION_HOURS = "%d |4hour:hr;"
INT_SPELL_DURATION_MIN = "%d min"
INT_SPELL_DURATION_SEC = "%d sec"
ITEM_SOULBOUND = "Soulbound"
ITEM_BIND_ON_EQUIP = "Binds when equipped"

-- the group and chat
local method, masterParty, masterRaid = "master", 0, nil
function GetLootMethod() return method, masterParty, masterRaid end
local inRaid, inGroup, leader, assist = false, true, false, false
function IsInRaid() return inRaid end
function IsInGroup() return inGroup end
function UnitIsGroupLeader() return leader end
function UnitIsGroupAssistant() return assist end
local sent = {}
function SendChatMessage(msg, channel) sent[#sent + 1] = { msg = msg, channel = channel } end
function UnitName() return "Hazas War" end
function GetActiveLootRollIDs() return {} end   -- a loading screen restores running rolls: none here

local serverTime = 1000000
function GetServerTime() return serverTime end

-- the bags, as the default reader sees them
local bags = {}      -- bag -> slot -> { guid, link, itemID, quality, lines }
local function put(bag, slot, item) bags[bag] = bags[bag] or {} bags[bag][slot] = item end
C_Container = {
    GetContainerNumSlots = function(bag) return bag <= 1 and 8 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local it = bags[bag] and bags[bag][slot]
        if not it then return nil end
        return { hyperlink = it.link, itemID = it.itemID, quality = it.quality }
    end,
}
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
C_Item = C_Item or {}
C_Item.GetItemGUID = function(location)
    local it = bags[location.bag] and bags[location.bag][location.slot]
    return it and it.guid
end
local reads = 0
function Pool.ReadLines(bag, slot)
    reads = reads + 1
    local it = bags[bag][slot]
    return it.lines
end

local function link(id, name, q)
    return ("|cff%s|Hitem:%d::::::::60:1491::1::1:28:5242:::::|h[%s]|h|r"):format(q == 4 and "a335ee" or "0070dd", id, name)
end
local function TRADE(text) return BIND_TRADE_TIME_REMAINING:gsub("%%s", text) end
local function reset()
    said, sent, bags, reads = {}, {}, {}, 0
    method, masterParty, masterRaid = "master", 0, nil
    inRaid, inGroup, leader, assist = false, true, false, false
    CL.db.pool = {}
    CL.db.masterEnabled, CL.db.masterAnnounce, CL.db.masterRaidWarning = true, true, false
    CL.db.masterTakeButton, CL.db.masterTakeAuto = true, false
    CL.db.gargulAsked = true
    serverTime = 1000000
    if Session.Window() then Session.Window():Hide() end
end

-- 1. Reading a tooltip
check(select(1, Pool.Classify({ "Boots", TRADE("1 hour 59 min") })) == "tradable"
    and select(2, Pool.Classify({ "Boots", TRADE("1 hour 59 min") })) == 7140, "'1 hour 59 min' is 7140 seconds")
check(select(2, Pool.Classify({ TRADE("45 min") })) == 2700, "'45 min' is 2700 seconds")
check(select(2, Pool.Classify({ TRADE("2 hr 5 sec") })) == 7205, "hours and seconds add up (2 hr 5 sec)")
check(Pool.Classify({ "Boots", ITEM_BIND_ON_EQUIP }) == "boe", "'Binds when equipped' is a bind-on-equip item")
check(Pool.Classify({ "Boots", ITEM_SOULBOUND }) == nil, "a soulbound item with no trade line is nothing to hand out")
check(Pool.Classify({ "Boots", ITEM_BIND_ON_EQUIP, ITEM_SOULBOUND }) == nil, "a bound bind-on-equip item is not offered")
check(Pool.Classify({ "Boots", ITEM_SOULBOUND, TRADE("30 min") }) == "tradable", "the trade line wins over 'Soulbound'")
check(Pool.Classify({ "Boots", "Level 60" }) == nil, "a plain item is nothing to hand out")

-- 2. Scanning the bags
reset()
put(0, 1, { guid = "G1", link = link(100, "Gloves of Test", 4), itemID = 100, quality = 4, lines = { "Gloves", TRADE("1 hour 20 min") } })
put(0, 2, { guid = "G2", link = link(101, "Boe Sword", 3), itemID = 101, quality = 3, lines = { "Sword", ITEM_BIND_ON_EQUIP } })
put(0, 3, { guid = "G3", link = link(102, "Bound Ring", 4), itemID = 102, quality = 4, lines = { "Ring", ITEM_SOULBOUND } })
put(1, 1, { guid = "G4", link = link(103, "Old Cloak", 4), itemID = 103, quality = 4, lines = { "Cloak", TRADE("10 min") } })
put(1, 2, { guid = "G5", link = "|cff9d9d9d|Hitem:104::::::::60:::::|h[Junk]|h|r", itemID = 104, quality = 0, lines = { "Junk", ITEM_BIND_ON_EQUIP } })
check(Pool.Scan() == true, "a scan with new items says the list changed")
local list = Pool.List()
check(#list == 3, "three items to hand out: the two tradable and the bind-on-equip (" .. #list .. ")")
check(list[1].name == "Old Cloak" and list[2].name == "Gloves of Test" and list[3].name == "Boe Sword",
    "oldest first: least time left, then the next, then bind-on-equip last (" .. list[1].name .. ", " .. list[2].name .. ", " .. list[3].name .. ")")
check(list[1].remaining == 600 and list[2].remaining == 4800 and list[3].remaining == nil, "time left from the tooltip; none for bind-on-equip")
check(reads == 4, "each new item's tooltip is read once, the junk one never (" .. reads .. ")")
reads = 0
check(Pool.Scan() == false and reads == 0, "a second scan of the same bags reads no tooltip and changes nothing")

-- time passes: the deadlines run down, and an expired item goes
serverTime = serverTime + 700
bags[1][1].lines = { "Cloak", ITEM_SOULBOUND }   -- the game: its trade time is over, it is bound now
list = Pool.List()
check(list[1].name == "Gloves of Test" and list[1].remaining == 4100, "700 seconds later the first deadline is gone (" .. list[1].name .. ")")
check(#list == 2, "...the expired item left the list")
Pool.Scan()
check(#Pool.List() == 2, "...and stays out after a scan")

-- an item that leaves the bags leaves the list
bags[0][2] = nil
check(Pool.Scan() == true and #Pool.List() == 1, "an item traded away leaves the list")

-- an item the client has not loaded: nothing vanishes on that look
bags[0][4] = { guid = nil, link = link(105, "Loading", 4), itemID = 105, quality = 4, lines = {} }
bags[0][1] = nil
Pool.Scan()
check(#Pool.List() == 1, "a look with an unloaded slot removes nothing")
bags[0][4] = nil
Pool.Scan()
check(#Pool.List() == 0, "...a complete look does")

-- 3. Leaving items out
reset()
put(0, 1, { guid = "A", link = link(200, "First", 4), itemID = 200, quality = 4, lines = { TRADE("30 min") } })
put(0, 2, { guid = "B", link = link(201, "Second", 4), itemID = 201, quality = 4, lines = { TRADE("90 min") } })
Pool.Scan()
check(#Pool.Offered() == 2, "every eligible item is offered by default")
Pool.SetExcluded("A", true)
check(#Pool.Offered() == 1 and Pool.Offered()[1].name == "Second", "leaving one out removes it from the offer")
check(#Pool.List() == 2 and Pool.List()[1].excluded, "...it stays in the list, marked")
Pool.SetExcluded("A", false)
check(#Pool.Offered() == 2, "ticking it again offers it again")
check(Pool.SetExcluded("nope", true) == false, "an unknown item cannot be excluded")
Pool.SetExcluded("B", true)
Pool.Scan()
check(CL.db.pool.B.excluded == true, "the choice is saved with the list")

-- 4. Keeping it up to date, cheaply
reset()
put(0, 1, { guid = "A", link = link(200, "First", 4), itemID = 200, quality = 4, lines = { TRADE("30 min") } })
WOW.FireEvent("BAG_UPDATE_DELAYED")
WOW.FireEvent("BAG_UPDATE_DELAYED")
WOW.FireEvent("BAG_UPDATE_DELAYED")
check(#Pool.List() == 0, "a bag event does not scan at once")
WOW.Advance(1.1)
check(#Pool.List() == 1 and reads == 1, "...one look a second later for any number of events")
masterParty = 3
put(0, 2, { guid = "B", link = link(201, "Second", 4), itemID = 201, quality = 4, lines = { TRADE("30 min") } })
WOW.FireEvent("BAG_UPDATE_DELAYED")
WOW.Advance(2)
check(#Pool.List() == 1, "not the master looter: the bags are not followed")
masterParty = 0
CL.db.masterEnabled = false
WOW.FireEvent("BAG_UPDATE_DELAYED")
WOW.Advance(2)
check(#Pool.List() == 1, "master loot switched off: the bags are not followed")
CL.db.masterEnabled = true
WOW.FireEvent("PLAYER_ENTERING_WORLD")
WOW.Advance(6)
check(#Pool.List() == 2, "a loading screen gets a look too, a few seconds later")

-- 5. The session window
reset()
put(0, 1, { guid = "A", link = link(200, "First", 4), itemID = 200, quality = 4, lines = { TRADE("30 min") } })
put(0, 2, { guid = "B", link = link(201, "Second", 3), itemID = 201, quality = 3, lines = { ITEM_BIND_ON_EQUIP } })
SlashCmdList.CLEANLOOT("session")
local win = Session.Window()
check(win and win:IsShown(), "/cll session opens the window")
local rows = {}
for _, r in ipairs(win.rows) do if r.entry then rows[#rows + 1] = r end end
check(#rows == 2 and rows[1].name:GetText() == "First" and rows[2].name:GetText() == "Second", "it lists the items, oldest first")
check(rows[1].check:GetChecked() and rows[2].check:GetChecked(), "every box is ticked by default")
check(rows[1].time:GetText():find("30m", 1, true) and rows[2].time:GetText():find("no limit", 1, true), "the time left, or 'no limit'")
check(win.sub:GetText():find("2 of 2 items offered", 1, true), "the header counts what is offered")
rows[1].check:SetChecked(false)
rows[1].check.__scripts.OnClick(rows[1].check)
check(CL.db.pool.A.excluded == true and win.sub:GetText():find("1 of 2 items offered", 1, true), "unticking a box leaves the item out")
SlashCmdList.CLEANLOOT("session")
check(not win:IsShown(), "/cll session again closes it")
reset()
SlashCmdList.CLEANLOOT("session")
check(Session.Window().sub:GetText():find("Nothing to hand out", 1, true), "an empty list says why")
masterParty = 3
Session.Refresh()
check(Session.Window().sub:GetText():find("Only the master looter", 1, true), "not the master looter: it says only his bags are followed")
Session.Window():Hide()

-- 6. Chat channels
reset()
inRaid = true
check(ML.Channel() == "RAID", "in a raid the messages go to /ra")
CL.db.masterRaidWarning = true
check(ML.Channel() == "RAID", "...also with the /rw option when you are not allowed to warn")
leader = true
check(ML.Channel() == "RAID_WARNING", "...and /rw when the option is on and you lead")
leader, assist = false, true
check(ML.Channel() == "RAID_WARNING", "...or assist")
inRaid = false
check(ML.Channel() == "PARTY", "in a party they go to /p")
inGroup = false
check(ML.Channel() == nil, "alone there is no channel")
said = {}
check(ML.Say("[CleanLoot] hello") == false and sayMatches("hello"), "alone a message is only printed")

-- 7. Candidates: the exact name wins, a first name only when it is unique
local candidates = { "Hazas Lock", "Hazas War", "Teki La" }
function GetMasterLootCandidate(slot, index) return candidates[index] end
check(ML.FindCandidate(1, "Hazas War") == 2 and ML.FindCandidate(1, "Hazas Lock") == 1, "two alts with the same first name are told apart by the full name")
check(ML.FindCandidate(1, "Hazas") == nil, "a first name fitting two players matches neither")
check(ML.FindCandidate(1, "Teki") == 3, "a first name fitting one player matches it")
check(ML.FindCandidate(1, "Nobody") == nil, "an unknown name matches nothing")

-- 8. Take all
reset()
inRaid = true
local slotsData = {
    { link = link(300, "Epic Helm", 4), quality = 4, quantity = 1 },
    { link = nil, quality = 1, quantity = 12 },                       -- money: no link
    { link = link(301, "Blue Belt", 3), quality = 3, quantity = 1 },
    { link = link(302, "Green Cloak", 2), quality = 2, quantity = 1 },
    { link = link(303, "Locked Thing", 4), quality = 4, quantity = 1, locked = true },
}
local threshold = 3
function GetLootThreshold() return threshold end
function GetNumLootItems() return #slotsData end
function GetLootSlotLink(slot) return slotsData[slot] and slotsData[slot].link end
function GetLootSlotInfo(slot)
    local s = slotsData[slot]
    return "icon", "name", s.quantity, nil, s.quality, s.locked
end
local gave = {}
function GiveMasterLoot(slot, index) gave[#gave + 1] = { slot = slot, index = index } end
candidates = { "Teki La", "Hazas War", "Iso Tope" }

local slots = TA.Slots()
check(#slots == 2 and slots[1].slot == 3 and slots[2].slot == 1, "only the items at or above the loot threshold, not money or locked ones (" .. #slots .. ")")
threshold = 2
check(#TA.Slots() == 3, "a lower threshold takes more")
threshold = 3
check(TA.Available(), "available to the master looter with something to take")
masterParty = 3
check(not TA.Available() and TA.Run(false) == false and sayMatches("only the master looter"), "not the master looter: not available, and it says so")
masterParty = 0
CL.db.masterEnabled = false
check(not TA.Available(), "master loot off: not available")
CL.db.masterEnabled = true

said, sent, gave = {}, {}, {}
check(TA.Run(false) == true, "Take all starts")
check(#gave == 2 and gave[1].slot == 3 and gave[1].index == 2 and gave[2].slot == 1 and gave[2].index == 2,
    "it gives each item to you (your index in the list is 2)")
check(#sent == 1 and sent[1].channel == "RAID" and sent[1].msg:find("Taking the items for the master looter", 1, true),
    "the group is told first, in /ra")
WOW.FireEvent("LOOT_SLOT_CLEARED", 3)
WOW.Advance(0.5)
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
WOW.Advance(1)
check(#sent == 3, "then one message per item, as the game confirms it (" .. #sent .. ")")
check(sent[2].msg:find("|Hitem:301:", 1, true) and sent[2].msg:find("[Blue Belt]", 1, true) and not sent[2].msg:find("|cn", 1, true),
    "...with the item's link (" .. sent[2].msg .. ")")
check(sent[3].msg:find("[Epic Helm]", 1, true) and sent[3].channel == "RAID", "...each in /ra")
WOW.Advance(4)
check(not sayMatches("did not confirm"), "nothing is reported when the game confirmed everything")

-- one is refused: it is reported, not announced
said, sent, gave = {}, {}, {}
TA.Run(false)
WOW.FireEvent("LOOT_SLOT_CLEARED", 3)
WOW.Advance(4)
check(sayMatches("did not confirm taking") and sayMatches("Epic Helm"), "an item the game did not hand over is reported")
check(#sent == 2, "...and not announced (header + the confirmed one)")

-- the list of players is late
said, sent, gave = {}, {}, {}
candidates = {}
TA.Run(false)
check(#gave == 0, "no list of players yet: nothing is called")
candidates = { "Teki La", "Hazas War", "Iso Tope" }
WOW.Advance(0.6)
check(#gave == 2, "...it tries again a moment later")
WOW.FireEvent("LOOT_SLOT_CLEARED", 3)
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
WOW.Advance(5)
candidates = { "Teki La", "Iso Tope" }
said, sent, gave = {}, {}, {}
TA.Run(false)
WOW.Advance(3)
check(#gave == 0 and sayMatches("could not find you"), "never found in the list: it gives up and says so")
candidates = { "Teki La", "Hazas War", "Iso Tope" }

-- a stack and the party channel
reset()
inRaid, inGroup = false, true
slotsData = { { link = link(400, "Stack of Things", 4), quality = 4, quantity = 3 } }
said, sent, gave = {}, {}, {}
TA.Run(false)
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
WOW.Advance(1)
check(sent[1].channel == "PARTY" and sent[2].channel == "PARTY" and sent[2].msg:find(" x3", 1, true), "in a party it is /p, and a stack shows its count")
-- /rw
reset()
inRaid, leader = true, true
CL.db.masterRaidWarning = true
slotsData = { { link = link(401, "Thing", 4), quality = 4, quantity = 1 } }
sent, gave = {}, {}
TA.Run(false)
check(sent[1].channel == "RAID_WARNING", "with the option on and the lead, it goes to /rw")
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
WOW.Advance(5)

-- 9. The button and the automatic take
reset()
inRaid = true
gave = {}
slotsData = { { link = link(500, "Epic Helm", 4), quality = 4, quantity = 1 } }
WOW.FireEvent("LOOT_OPENED")
WOW.Advance(0.2)
local btn = TA.Button()
check(btn and btn:IsShown(), "opening the loot window as master looter shows the Take all button")
check(#gave == 0, "...and takes nothing by itself while the automatic option is off")
btn.__scripts.OnClick(btn)
check(#gave == 1, "a click takes")
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
WOW.Advance(5)
slotsData = {}
WOW.FireEvent("LOOT_CLOSED")
check(not btn:IsShown(), "closing the loot window hides it")
CL.db.masterTakeButton = false
slotsData = { { link = link(501, "Other Helm", 4), quality = 4, quantity = 1 } }
WOW.FireEvent("LOOT_OPENED")
WOW.Advance(0.2)
check(not btn:IsShown(), "the button option off: no button")
CL.db.masterTakeButton = true
masterParty = 3
WOW.FireEvent("LOOT_OPENED")
WOW.Advance(0.2)
check(not btn:IsShown(), "not the master looter: no button")
masterParty = 0
slotsData = {}
WOW.FireEvent("LOOT_OPENED")
WOW.Advance(0.2)
check(not btn:IsShown(), "an empty window: no button")

reset()
inRaid = true
slotsData = { { link = link(502, "Auto Helm", 4), quality = 4, quantity = 1 } }
CL.db.masterTakeAuto = true
gave = {}
function IsShiftKeyDown() return true end
WOW.FireEvent("LOOT_OPENED")
WOW.Advance(0.2)
check(#gave == 0, "automatic take: holding Shift skips it")
function IsShiftKeyDown() return false end
WOW.FireEvent("LOOT_OPENED")
WOW.Advance(0.2)
check(#gave == 1, "automatic take: it takes when the loot window opens")
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
WOW.Advance(5)
masterParty = 3
gave = {}
WOW.FireEvent("LOOT_OPENED")
WOW.Advance(0.2)
check(#gave == 0, "automatic take: only for the master looter")
masterParty = 0
CL.db.masterEnabled = false
WOW.FireEvent("LOOT_OPENED")
WOW.Advance(0.2)
check(#gave == 0, "automatic take: not while master loot is off")
CL.db.masterEnabled, CL.db.masterTakeAuto = true, false

-- 10. The options tab
local W = CL.Options.widgets
check(CL.Options.pages.master and CL.Options.pages.master.tab, "the options window has a Master loot tab")
CL.Options.Open("master")
check(CL.Options.CurrentPage() == "master" and CL.Options.masterPanel:IsShown(), "it opens on that tab")
for _, name in ipairs({ "masterEnabled", "masterWindow", "masterAnnounce", "masterRaidWarning", "masterTakeButton",
    "masterTakeAuto", "sessionOpen", "gargulAsk" }) do
    check(W[name] ~= nil, "the tab has " .. name)
end
CL.MasterLoot.SetEnabled(false)
check(not W.masterTakeButton:IsEnabled() and not W.masterRaidWarning:IsEnabled() and not W.masterTakeAuto:IsEnabled(),
    "the switch off greys what depends on it")
CL.MasterLoot.SetEnabled(true)
W.masterRaidWarning:SetChecked(true)
W.masterRaidWarning.__scripts.OnClick(W.masterRaidWarning)
check(CL.db.masterRaidWarning == true, "the /rw option is saved")
CL.db.masterRaidWarning = false
W.sessionOpen.__scripts.OnClick(W.sessionOpen)
check(Session.Window():IsShown(), "the tab's button opens the session window")
Session.Window():Hide()
slotsData = {}
said = {}
SlashCmdList.CLEANLOOT("take")
check(sayMatches("nothing to take"), "/cll take with nothing in the window says so")

print = realPrint
io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
