-- The messages between CleanLoot users and the window of a player in a loot session, against
-- the stub client. Run with lua tools/test_playerwindow.lua.
local WOW = dofile("tools/wowenv.lua")
local CL = WOW.CL
local ML, Comm, PW, Run, Book, Pool = CL.MasterLoot, CL.Comm, CL.PlayerWindow, CL.SessionRun, CL.RollBook, CL.LootPool
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1 io.write("FAIL: " .. label .. "\n") end
end

local said = {}
local realPrint = print
print = function(...) said[#said + 1] = table.concat({ ... }, " ") end

RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
local method, masterParty = "master", 2
function GetLootMethod() return method, masterParty, nil end
local inRaid, inGroup, inInstanceGroup = true, true, false
function IsInRaid() return inRaid end
function IsInGroup(category)
    if category ~= nil then return inInstanceGroup end
    return inGroup
end
function UnitIsGroupLeader() return false end
function UnitIsGroupAssistant() return false end
function UnitName(unit)
    if unit == "player" then return "Hazas War" end
    if unit == "party2" then return "Teki La" end
    return nil
end
function GetActiveLootRollIDs() return {} end
function GetCursorPosition() return 300, 200 end
local serverTime = 1000000
function GetServerTime() return serverTime end
function Pool.Scan() return false end

local sentChat, sentAddon, rolled = {}, {}, {}
function SendChatMessage(msg, channel, _, target) sentChat[#sentChat + 1] = { msg = msg, channel = channel, target = target } end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, text, channel) sentAddon[#sentAddon + 1] = { prefix = prefix, text = text, channel = channel } end,
}
function RandomRoll(lo, hi) rolled[#rolled + 1] = { lo, hi } end

local LINK = "|cffa335ee|Hitem:100:::::::7:60:1491::1::1:28:5242:::::|h[Twin Blade]|h|r"
local SEP = "\t"
local function msg(kind, ...)
    local parts = { kind }
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    return table.concat(parts, SEP)
end
-- a message from another player's CleanLoot
local function receive(sender, kind, ...)
    WOW.FireEvent("CHAT_MSG_ADDON", "CLEANLOOT", msg(kind, ...), "RAID", sender)
end
local function roll(name, value, hi)
    WOW.FireEvent("CHAT_MSG_SYSTEM", ("%s rolls %d (1-%d)"):format(name, value, hi or 100))
end
local function sentKinds()
    local t = {}
    for _, a in ipairs(sentAddon) do t[#t + 1] = a.text:match("^(%a)") end
    return table.concat(t)
end
local function reset()
    if Run.Active() then Run.Cancel() end
    PW.Reset()
    WOW.Advance(10)
    sentChat, sentAddon, rolled, said = {}, {}, {}, {}
    method, masterParty, inRaid, inGroup, inInstanceGroup = "master", 2, true, true, false
    CL.db.masterEnabled, CL.db.sessionJoin, CL.db.sessionAuto, CL.db.sessionWhisper, CL.db.sessionTime = true, true, true, true, 30
    CL.db.pool = {}
end

-- 1. The roll book, shared by both sides
local book = Book.New()
check(Book.Add(book, "A", 50, 1, 100) and not Book.Add(book, "A", 90, 1, 100), "the first roll counts, the same category again does not")
check(Book.Add(book, "A", 10, 1, 99) and book.rolls.A.cat == 2, "a roll in a lower category replaces it")
check(not Book.Add(book, "A", 99, 1, 100) and book.rolls.A.cat == 2, "...never a higher one")
check(not Book.Add(book, "B", 5, 1, 80) and not Book.Add(book, "B", 5, 2, 100), "a roll in none of the ranges is not counted")
Book.Pass(book, "A")
check(book.rolls.A == nil and book.passed.A, "a pass cancels the roll")
book.restrict = { names = { C = true }, cat = 1 }
check(not Book.Add(book, "D", 5, 1, 100) and not Book.Add(book, "C", 5, 1, 99) and Book.Add(book, "C", 5, 1, 100), "a re-roll counts only the named players, in their category")

-- 2. The message format
check(Comm.Encode("I", "sid", 2, LINK) == "I" .. SEP .. "sid" .. SEP .. "2" .. SEP .. LINK, "a message is its kind and its fields, tab separated")
local kind, fields = Comm.Decode(Comm.Encode("I", "sid", 2, LINK, ""))
check(kind == "I" and fields[1] == "sid" and fields[2] == "2" and fields[3] == LINK and fields[4] == "", "it decodes back, links and empty fields included")
check(Comm.Decode("") == nil and Comm.Decode(nil) == nil, "nothing decodes to nothing")
check(Comm.Channel() == "RAID", "in a raid the channel is /raid")
inRaid = false
check(Comm.Channel() == "PARTY", "in a party it is /party")
LE_PARTY_CATEGORY_INSTANCE = 2
inInstanceGroup = true
check(Comm.Channel() == "INSTANCE_CHAT", "in a group made by the dungeon finder it is the instance chat")
inInstanceGroup, LE_PARTY_CATEGORY_INSTANCE = false, nil
inGroup = false
check(Comm.Channel() == nil and Comm.Send("S", 1) == false, "alone there is no channel, nothing is sent")
inGroup, inRaid = true, true
check(Comm.Send("S", 1, "x") == true and sentAddon[1].prefix == "CLEANLOOT" and sentAddon[1].channel == "RAID", "a message goes on the CLEANLOOT prefix")
sentAddon = {}
check(Comm.Send("I", string.rep("x", 300)) == false and #sentAddon == 0, "a message over 255 characters is not sent")

-- 3. Who is believed
reset()
check(ML.MasterLooterName() == "Teki La", "the master looter is found from the party index")
masterParty = 0
check(ML.MasterLooterName() == "Hazas War", "...you, when the index is 0")
masterParty = 2
method = "group"
check(ML.MasterLooterName() == nil, "no master looter in group loot")
method = "master"
receive("Iso Tope", "S", 1, "s1", 2, 15)
check(PW.State() == nil, "a session message from somebody who is not the master looter is ignored")
receive("Teki La", "S", 2, "s1", 2, 15)
check(PW.State() == nil, "...so is another protocol version")
WOW.FireEvent("CHAT_MSG_ADDON", "OTHERADDON", msg("S", 1, "s1", 2, 15), "RAID", "Teki La")
check(PW.State() == nil, "...and another addon's prefix")
receive("Teki La", "S", 1, "s1", 2, 15)
check(PW.State() and PW.State().sid == "s1" and PW.State().count == 2, "the master looter's start is taken")
receive("Teki La-Realm", "I", "s1", 1, 2, 3, LINK, 15)
check(PW.State().lot and PW.State().index == 1, "his name with a realm is his name too")
reset()
CL.db.sessionJoin = false
receive("Teki La", "S", 1, "s1", 2, 15)
check(PW.State() == nil, "the option off: no window")
CL.db.sessionJoin = true
CL.db.masterEnabled = false
receive("Teki La", "S", 1, "s1", 2, 15)
check(PW.State() == nil, "master loot off: no window")
CL.db.masterEnabled = true
method = "group"
receive("Teki La", "S", 1, "s1", 2, 15)
check(PW.State() == nil, "no master loot in the group: not believed")
method = "master"
WOW.FireEvent("CHAT_MSG_ADDON", "CLEANLOOT", msg("S", 1, "s1", 2, 15), "RAID", "Hazas War")
check(PW.State() == nil, "your own message coming back is ignored")

-- 4. A session as a player sees it
reset()
receive("Teki La", "S", 1, "s1", 2, 15)
receive("Teki La", "I", "s1", 1, 2, 3, LINK, 15)
local win = PW.Window()
check(win and win:IsShown(), "the window opens with the first item")
check(win.name:GetText() == "Twin Blade x3" and win.count:GetText():find("Item 1 of 2", 1, true), "it shows the item, its copies and where we are (" .. tostring(win.name:GetText()) .. ")")
check(win.title:GetText():find("Teki La", 1, true), "...and whose session it is")
WOW.Advance(0.3)
check(win.time:GetText() == "15 s" or win.time:GetText() == "14 s", "the time left runs (" .. tostring(win.time:GetText()) .. ")")
check(win.buttons[1]:IsEnabled() and win.buttons[2]:IsEnabled() and win.buttons[3]:IsEnabled() and win.buttons.pass:IsEnabled(), "the roll buttons are on")
roll("Teki La", 50)
roll("Iso Tope", 20, 99)
roll("Hazas War", 77)
roll("Hazas War", 99, 99)      -- an OS roll after an MS one: replaces it
WOW.Advance(0.3)
local rows = {}
for _, row in ipairs(win.rows) do if row:IsShown() then rows[#rows + 1] = row end end
check(#rows == 3 and rows[1].who:GetText() == "Teki La" and rows[1].roll:GetText():find("MS 50", 1, true), "everybody's rolls, best first")
check(rows[2].who:GetText() == "You" and rows[2].roll:GetText():find("OS 99", 1, true), "your own roll shows as You, and the downgrade replaced the MS roll")
check(rows[1].roll:GetText():find(CL.SessionRun.CatColor(1), 1, true) and rows[3].roll:GetText():find(CL.SessionRun.CatColor(2), 1, true), "each kind of roll has its colour")

win.buttons[1].__scripts.OnClick(win.buttons[1])
win.buttons[2].__scripts.OnClick(win.buttons[2])
win.buttons[3].__scripts.OnClick(win.buttons[3])
check(#rolled == 3 and rolled[1][1] == 1 and rolled[1][2] == 100 and rolled[2][2] == 99 and rolled[3][2] == 90, "the buttons make the game's own /roll in the three ranges")
sentAddon = {}
win.buttons.pass.__scripts.OnClick(win.buttons.pass)
check(#sentAddon == 1 and sentAddon[1].text == msg("Q", "s1", 1), "Pass tells the master looter's session (" .. tostring(sentAddon[1] and sentAddon[1].text) .. ")")
WOW.Advance(0.3)
local count = 0
for _, row in ipairs(win.rows) do if row:IsShown() then count = count + 1 end end
check(count == 2, "...and takes you out of the list")

receive("Teki La", "P", "s1", 1, 1, 9)
check(PW.State().paused and PW.State().remaining == 9 and not win.buttons[1]:IsEnabled(), "a pause stops the timer and the buttons")
WOW.Advance(5)
check(PW.State().remaining == 9, "(the timer stays where it was)")
roll("Late Comer", 10)
WOW.Advance(0.3)
count = 0
for _, row in ipairs(win.rows) do if row:IsShown() then count = count + 1 end end
check(count == 2, "a roll during the pause is not counted")
receive("Teki La", "P", "s1", 1, 0, 25)
check(not PW.State().paused and PW.State().remaining == 25 and win.buttons[1]:IsEnabled(), "resuming, or a time extension, sets the time left")

receive("Teki La", "C", "s1", 1)
check(PW.State().phase == "closed" and not win.buttons[1]:IsEnabled(), "the rolls close: no more buttons")
receive("Teki La", "W", "s1", 1, "Teki La", 1, 50)
WOW.Advance(0.3)
rows = {}
for _, row in ipairs(win.rows) do if row:IsShown() then rows[#rows + 1] = row end end
check(rows[1].roll:GetText():find("won", 1, true), "a winner is marked in the list")
check(not win.status:GetText():find("You won", 1, true), "(you did not win)")
receive("Teki La", "W", "s1", 1, "Hazas War", 2, 99)
check(win.status:GetText():find("You won it", 1, true), "when you win, the window says so")
receive("Teki La", "X", "s1", 1, "Hazas War")
check(not win.status:GetText():find("You won it", 1, true), "an assignment taken back takes it away")

-- a second item, a skipped one, a re-roll
receive("Teki La", "I", "s1", 2, 2, 1, LINK, 15)
check(win.count:GetText():find("Item 2 of 2", 1, true) and win.name:GetText() == "Twin Blade" and #PW.State().awards == 0, "the next item starts afresh")
receive("Teki La", "R", "s1", 2, "Teki La,Iso Tope", 1, 15)
check(PW.State().book.restrict and PW.State().book.restrict.cat == 1 and win.status:GetText():find("Re-roll", 1, true), "a re-roll is announced")
check(win.buttons[1]:IsEnabled() and not win.buttons[2]:IsEnabled() and not win.buttons[3]:IsEnabled(), "...with only the category of the tie to roll in")
roll("Hazas War", 40)
roll("Teki La", 40)
WOW.Advance(0.3)
count = 0
for _, row in ipairs(win.rows) do if row:IsShown() then count = count + 1 end end
check(count == 1, "only the tied players' rolls count in a re-roll (" .. count .. ")")
receive("Teki La", "Z", "s1", 2)
check(PW.State().phase == "skipped", "a skipped item is shown as skipped")

-- a message of another session, or from the wrong player, changes nothing
local phaseBefore = PW.State().phase
receive("Teki La", "C", "other", 2)
receive("Iso Tope", "E", "s1")
check(PW.State().phase == phaseBefore, "messages of another session or sender change nothing")

-- the end
receive("Teki La", "E", "s1")
check(PW.State().phase == "over" and win.status:GetText():find("over", 1, true), "the end of the session is shown")
WOW.Advance(9)
check(PW.State() == nil and not win:IsShown(), "...and the window goes by itself")
receive("Teki La", "S", 1, "s2", 1, 15)
receive("Teki La", "I", "s2", 1, 1, 1, LINK, 15)
receive("Teki La", "K", "s2")
check(PW.State().phase == "cancelled", "a cancelled session is shown as cancelled")
WOW.Advance(9)

-- joining late: the start was missed
receive("Teki La", "I", "s3", 3, 5, 1, LINK, 12)
check(PW.State() and PW.State().sid == "s3" and win:IsShown(), "an item message with no start before it still opens the window")
WOW.Advance(20)   -- the master looter's closing message never comes
check(PW.State() == nil or PW.State().phase == "closed", "a window never left waiting for ever (the time ran out)")
reset()

-- 5. The master looter's side
CL.db.pool = {
    G1 = { itemID = 100, link = LINK, seen = serverTime - 1, expires = serverTime + 3600, quality = 4 },
    G2 = { itemID = 100, link = LINK:gsub(":7:60:", ":8:60:"), seen = serverTime - 2, expires = serverTime + 3700, quality = 4 },
}
masterParty = 0
sentAddon = {}
Run.Start()
check(sentAddon[1].text:match("^S") and sentAddon[1].text:find(SEP .. "1" .. SEP, 1, true) and sentAddon[1].channel == "RAID", "a session announces itself to the players' windows")
local sid = Run.State().sid
local _, f = Comm.Decode(sentAddon[1].text)
check(f[1] == "1" and f[2] == sid and f[3] == "1" and f[4] == "30", "...with its id, the number of items and the time per item")
local _, fi = Comm.Decode(sentAddon[2].text)
check(sentAddon[2].text:match("^I") and fi[1] == sid and fi[2] == "1" and fi[3] == "1" and fi[4] == "2" and fi[5] == LINK and fi[6] == "30",
    "the item in play goes with its link and its copies (" .. tostring(sentAddon[2].text) .. ")")
check(#sentAddon[2].text <= 255, "(and fits in one message)")
sentAddon = {}
Run.Pause()
Run.Resume()
Run.Extend()
check(sentKinds() == "PPP", "pause, resume and +10 s tell the windows")
local _, fp = Comm.Decode(sentAddon[1].text)
check(fp[3] == "1", "(the pause says paused)")
sentAddon = {}
roll("A One", 90) roll("B Two", 80)
WOW.Advance(45)
check(sentKinds():find("^CWW") ~= nil, "closing and each winner are told (" .. sentKinds() .. ")")
local _, fw = Comm.Decode(sentAddon[2].text)
check(fw[3] == "A One" and fw[4] == "1" and fw[5] == "90", "a winner goes with his name, kind of roll and value")
sentAddon = {}
local lot = Run.History()[1] and Run.History()[1].lot
WOW.Advance(3.5)
lot = Run.History()[1].lot
Run.Unassign(Run.AwardsFor(lot)[1])
check(sentKinds() == "X", "taking an assignment back is told")
Run.AssignManual(lot, "Zed Zeta")
check(sentKinds() == "XW", "...and giving one by hand")
sentAddon = {}
Run.Finish()
check(sentKinds() == "E", "the end is told")

-- players pass
reset()
masterParty = 0
CL.db.pool = { G1 = { itemID = 100, link = LINK, seen = serverTime - 1, expires = serverTime + 3600, quality = 4 } }
Run.Start()
sid = Run.State().sid
roll("Iso Tope", 70)
roll("Teki La", 60)
receive("Iso Tope", "Q", sid, 1)
check(#Run.Ranking() == 1 and Run.Ranking()[1].name == "Teki La", "a player's pass takes his roll out of the master looter's list")
receive("Teki La", "Q", "other", 1)
check(#Run.Ranking() == 1, "a pass for another session is ignored")
receive("Teki La", "Q", sid, 2)
check(#Run.Ranking() == 1, "...and for another item")
sentAddon = {}
Run.Cancel()
check(sentKinds() == "K", "a cancelled session is told")

-- a test session and a solo session tell nobody
reset()
masterParty = 0
CL.db.pool = { G1 = { itemID = 100, link = LINK, seen = serverTime - 1, expires = serverTime + 3600, quality = 4 } }
sentAddon = {}
Run.StartTest()
WOW.Advance(40)
Run.Cancel()
check(#sentAddon == 0, "a test session tells no window")
inGroup, inRaid = false, false
Run.Start()
check(#sentAddon == 0, "alone, nothing is sent")
Run.Cancel()

print = realPrint
io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
