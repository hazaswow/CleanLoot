-- The timed loot session, against the stub client. Run with lua tools/test_session.lua.
local WOW = dofile("tools/wowenv.lua")
local CL = WOW.CL
local ML, Pool, Run, Session = CL.MasterLoot, CL.LootPool, CL.SessionRun, CL.Session
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

RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
local method, masterParty = "master", 0
function GetLootMethod() return method, masterParty, nil end
local inRaid, inGroup = true, true
function IsInRaid() return inRaid end
function IsInGroup() return inGroup end
function UnitIsGroupLeader() return false end
function UnitIsGroupAssistant() return false end
local sent = {}
function SendChatMessage(msg, channel, _, target) sent[#sent + 1] = { msg = msg, channel = channel, target = target } end
function UnitName() return "Hazas War" end
function GetCursorPosition() return 300, 200 end
function GetActiveLootRollIDs() return {} end
local serverTime = 1000000
function GetServerTime() return serverTime end
-- the test stocks the list by hand: a look at the (empty) fake bags must not wipe it
function Pool.Scan() return false end

local function link(id, name)
    return ("|cffa335ee|Hitem:%d::::::::60:1491::1::1:28:5242:::::|h[%s]|h|r"):format(id, name)
end
local function stock(items)
    CL.db.pool = {}
    for i, it in ipairs(items) do
        CL.db.pool["G" .. i] = { itemID = it.id, link = link(it.id, it.name), seen = serverTime - i, expires = serverTime + 3600 * i,
            quality = 4 }
    end
end
local function reset(items)
    if Run.Active() then Run.Cancel() end
    said, sent = {}, {}
    method, masterParty, inRaid, inGroup = "master", 0, true, true
    CL.db.masterEnabled, CL.db.sessionAuto, CL.db.sessionWhisper, CL.db.sessionTime = true, true, true, 30
    CL.db.gargulAsked = true
    stock(items or { { id = 100, name = "Test Blade" } })
    if Session.Window() then Session.Window():Hide() end
    WOW.Advance(2)
    said, sent = {}, {}
end
local function roll(name, value, hi)
    WOW.FireEvent("CHAT_MSG_SYSTEM", ("%s rolls %d (1-%d)"):format(name, value, hi or 100))
end
local function sentTexts()
    local t = {}
    for _, s in ipairs(sent) do t[#t + 1] = s.msg end
    return t
end
local function sentHas(p)
    for _, s in ipairs(sent) do if s.msg:find(p, 1, true) then return true end end
    return false
end
local function sentCount(p)
    local n = 0
    for _, s in ipairs(sent) do if s.msg:find(p, 1, true) then n = n + 1 end end
    return n
end

-- 1. When the game speaks, and the countdown
local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end
check(same(Run.Marks(60), { 15, 5, 3, 2, 1 }), "60 s: reminders at 15 and 5, then 3 2 1")
check(same(Run.Marks(30), { 15, 5, 3, 2, 1 }), "30 s: the same")
check(same(Run.Marks(16), { 15, 5, 3, 2, 1 }), "16 s: the same")
check(same(Run.Marks(15), { 10, 3, 2, 1 }), "15 s: reminder at 10, then 3 2 1 (the 3 is the 3 s reminder)")
check(same(Run.Marks(11), { 10, 3, 2, 1 }), "11 s: reminder at 10")
check(same(Run.Marks(10), { 5, 3, 2, 1 }), "10 s: a single reminder, at 5, then 3 2 1")
CL.db.sessionTime = 5
check(Run.Duration() == 10, "the timer is never under 10 s")
CL.db.sessionTime = 600
check(Run.Duration() == 60, "...nor over 60 s")
CL.db.sessionTime = "x"
check(Run.Duration() == 15, "...and 15 s when the setting is garbage")
CL.db.sessionTime = 30

-- 2. Who can start
reset()
masterParty = 2
local ok, why = Run.CanStart()
check(not ok and why:find("only the master looter", 1, true), "in a group, only the master looter starts a session")
masterParty = 0
check(Run.CanStart() == true, "the master looter can")
CL.db.masterEnabled = false
ok, why = Run.CanStart()
check(not ok and why:find("off", 1, true), "master loot off: no session")
CL.db.masterEnabled = true
CL.db.pool = {}
ok, why = Run.CanStart()
check(not ok and why:find("no item to offer", 1, true), "an empty list: nothing to start")
stock({ { id = 100, name = "Test Blade" } })
CL.db.pool.G1.excluded = true
check(not Run.CanStart(), "every item left out: nothing to start")
CL.db.pool.G1.excluded = nil
inGroup, inRaid, masterParty = false, false, 3
check(Run.CanStart() == true, "alone you can start one, to try it (nobody else to be master looter)")
inGroup, inRaid, masterParty = true, true, 0

-- 3. One item, from start to end
reset({ { id = 100, name = "Test Blade" } })
check(Run.Start() == true, "a session starts")
check(sent[1].channel == "RAID" and sent[1].msg:find("Loot session: 1 item, 30 sec each", 1, true)
    and sent[1].msg:find("1-100=MS 1-99=OS 1-90=Other", 1, true), "it announces itself in /ra (" .. tostring(sent[1] and sent[1].msg) .. ")")
check(sent[2].msg:find("Roll for ", 1, true) and sent[2].msg:find("[Test Blade]", 1, true) and sent[2].msg:find("(1/1)", 1, true)
    and sent[2].msg:find("1-100=MS 1-99=OS 1-90=Other. 30 sec left", 1, true), "...then the item to roll for (" .. tostring(sent[2] and sent[2].msg) .. ")")
roll("Teki La", 44)
roll("Iso Tope", 91, 99)       -- OS
roll("Humark Clearsight", 12)
WOW.Advance(14.5)
check(not sentHas("sec left") or sentCount("sec left") == 1, "(nothing between the prompt and the first reminder)")
sent = {}
WOW.Advance(1)
check(#sent == 1 and sent[1].msg == "15 sec left", "reminder at 15 s (" .. tostring(sent[1] and sent[1].msg) .. ")")
sent = {}
WOW.Advance(9.5)
check(#sent == 1 and sent[1].msg == "5 sec left", "reminder at 5 s")
sent = {}
WOW.Advance(2)
check(same(sentTexts(), { "3" }), "3 comes with no other message (" .. table.concat(sentTexts(), ",") .. ")")
sent = {}
WOW.Advance(1)
check(same(sentTexts(), { "2" }), "then 2")
sent = {}
WOW.Advance(1)
check(same(sentTexts(), { "1" }), "then 1")
sent = {}
WOW.Advance(1.2)
check(sentHas("Rolls closed for") and sentHas("assigned to Teki La for roll MS 44"), "the rolls close and the best MS roll wins (" .. table.concat(sentTexts(), " | ") .. ")")
check(sentCount("sec left") == 0, "no reminder after the countdown")
WOW.Advance(3.5)
check(sentHas("Session over: 1 item assigned"), "the session ends once the last item is done")
check(not Run.Active(), "...and is no longer running")
local whisper
for _, s in ipairs(sent) do if s.channel == "WHISPER" then whisper = s end end
check(whisper and whisper.target == "Teki La" and whisper.msg:find("You won", 1, true) and whisper.msg:find("[Test Blade]", 1, true)
    and whisper.msg:find("Come trade me", 1, true), "the winner gets a whisper to come and trade (" .. tostring(whisper and whisper.msg) .. ")")
check(CL.db.pool.G1.awardedTo == "Teki La" and #Pool.Offered() == 0, "the item is marked as given and no longer offered")
check(Pool.List()[1].awardedTo == "Teki La", "...but stays in the list until traded")

-- 4. The rules for the rolls of a player
reset()
Run.Start()
roll("Teki La", 50)                                -- MS 50
roll("Teki La", 99)                                -- a second MS roll: ignored
roll("Iso Tope", 70, 99)                           -- OS 70
roll("Iso Tope", 95)                               -- upgrade to MS: ignored
roll("Humark Clearsight", 60)                      -- MS 60
roll("Humark Clearsight", 20, 99)                  -- downgrade to OS: replaces
roll("Hazas War", 10, 90)                          -- Other
roll("Nobody", 5, 80)                              -- not one of the ranges
roll("Nobody", 5, 100)
local r = Run.Ranking()
local by = {}
for _, e in ipairs(r) do by[e.name] = e end
check(by["Teki La"].value == 50 and by["Teki La"].cat == 1, "the first roll counts, a second one in the same category is ignored")
check(by["Iso Tope"].cat == 2 and by["Iso Tope"].value == 70, "an upgrade (OS then MS) is ignored")
check(by["Humark Clearsight"].cat == 2 and by["Humark Clearsight"].value == 20, "a downgrade (MS then OS) replaces the roll")
check(by["Hazas War"].cat == 3, "1-90 is Other")
check(by["Nobody"].cat == 1, "(a roll in the right range counts)")
check(#r == 5, "a roll in none of the three ranges is not counted (" .. #r .. ")")
check(r[1].name == "Nobody" or r[1].name == "Teki La", "MS first")
check(r[#r].name == "Hazas War" and r[#r - 1].cat == 2, "then OS, then Other, whatever the numbers")
roll("Teki La", 1, 99)                              -- down to OS with a 1: loses the MS
check(Run.Ranking()[1].name ~= "Teki La", "rolling lower in category loses the priority")
Run.Pass("Hazas War")
check(#Run.Ranking() == 4, "a pass cancels the roll: the player leaves the list")
roll("Hazas War", 33)
check(#Run.Ranking() == 5, "...and a new roll after it counts")
roll("Someone", 5, 100)
local before = #Run.Ranking()
check(Run.HandleRoll("X", 5, 2, 100) == false and #Run.Ranking() == before, "a roll that does not start at 1 is not counted")
Run.Cancel()

-- 5. MS beats OS beats Other, a tie, and the re-roll
reset()
Run.Start()
roll("A One", 3)               -- MS 3
roll("B Two", 99, 99)          -- OS 99
WOW.Advance(31)
check(sentHas("assigned to A One for roll MS 3"), "a low MS roll beats a high OS one")
Run.Cancel()

reset()
Run.Start()
roll("A One", 50)
roll("B Two", 50)
roll("C Three", 20)
WOW.Advance(31)
check(sentHas("Tie for") and sentHas("A One, B Two") and sentHas("The master looter decides"), "a tie for the best roll is announced (" .. table.concat(sentTexts(), " | ") .. ")")
check(not sentHas("assigned to"), "...and nothing is assigned by itself")
check(Run.State().phase == "decide" and Run.Can("reroll") and Run.Can("choose"), "the master looter can re-roll or choose")
sent = {}
check(Run.Reroll() == true and sentHas("Re-roll for") and sentHas("A One, B Two") and sentHas("1-100=MS"), "Re-roll tells the group who rolls again and how")
roll("C Three", 99)           -- not tied: ignored
roll("A One", 10, 99)         -- wrong range: ignored
roll("A One", 80)
roll("B Two", 30)
WOW.Advance(31)
check(sentHas("assigned to A One for roll MS 80"), "only the tied players count in the re-roll")
Run.Cancel()

-- 6. The master looter picks the winner
reset()
CL.db.sessionAuto = false
Run.Start()
roll("A One", 80)
roll("B Two", 90, 99)
WOW.Advance(31)
check(Run.State().phase == "decide" and not sentHas("assigned to"), "automatic off: the best roll is not assigned by itself")
check(Run.Award("Nobody Here") == false, "a name that did not roll cannot be assigned")
check(Run.Award("B Two") == true and sentHas("assigned to B Two for roll OS 90"), "the master looter can pick any roll")
check(Run.Award("A One") == false, "...once")
Run.Cancel()

-- 7. Nobody rolls
reset({ { id = 100, name = "First" }, { id = 101, name = "Second" } })
Run.Start()
WOW.Advance(31)
check(sentHas("No roll for") and sentHas("[First]"), "nobody rolled: it says so")
WOW.Advance(3.5)
check(Run.Active() and sentHas("(2/2)"), "...and the next item comes")
Run.Cancel()

-- 8. The controls, each one tells the group
reset()
Run.Start()
sent = {}
WOW.Advance(10)
check(Run.Pause() == true and sentHas("Session paused"), "Pause tells the group")
local remaining = Run.State().remaining
WOW.Advance(20)
check(math.abs(Run.State().remaining - remaining) < 0.001, "a paused timer does not run")
check(Run.Pause() == false and Run.Can("resume"), "(already paused)")
sent = {}
check(Run.Resume() == true and sentHas("Session resumed") and sentHas("sec left for"), "Resume tells the group how long is left")
sent = {}
check(Run.Extend() == true and sentHas("+10 sec") and sentHas("sec left."), "+10 s tells the group")
check(Run.State().remaining > remaining + 9, "...and adds the time")
-- reminders come again after a time extension
Run.Cancel()
reset()
Run.Start()
WOW.Advance(26)                 -- 4 s left: 15 and 5 already said
sent = {}
Run.Extend()                    -- 14 s left
sent = {}
WOW.Advance(5)                  -- 9 s left: the 5 s reminder is still to come
check(not sentHas("15 sec left"), "an extension does not repeat the reminder of 15 s that is above")
WOW.Advance(4.2)
check(sentHas("5 sec left"), "...the 5 s reminder comes again (" .. table.concat(sentTexts(), ",") .. ")")
Run.Cancel()
reset({ { id = 100, name = "First" }, { id = 101, name = "Second" } })
Run.Start()
sent = {}
check(Run.Skip() == true and sentHas("skipped"), "Skip tells the group")
WOW.Advance(3.5)
check(sentHas("(2/2)"), "...and goes on to the next item")
sent = {}
check(Run.Cancel() == true and sentHas("Session cancelled"), "Cancel tells the group")
check(not Run.Active() and not sentHas("Session over"), "...and ends it")
check(Run.Cancel() == false, "(nothing to cancel)")

-- 9. A cancelled session keeps what was already assigned
reset({ { id = 100, name = "First" }, { id = 101, name = "Second" } })
Run.Start()
roll("Teki La", 77)
WOW.Advance(31)
WOW.Advance(3.5)
sent = {}
Run.Cancel()
local w = {}
for _, s in ipairs(sent) do if s.channel == "WHISPER" then w[#w + 1] = s end end
check(#w == 1 and w[1].target == "Teki La", "what was assigned before a cancel is still whispered")

-- 10. Whispers: one per item, not to yourself, and optional
reset({ { id = 100, name = "First" }, { id = 101, name = "Second" }, { id = 102, name = "Third" } })
Run.Start()
roll("Teki La", 80)
WOW.Advance(31)
WOW.Advance(3.5)
roll("Teki La", 70)
WOW.Advance(31)
WOW.Advance(3.5)
roll("Hazas War", 99)
WOW.Advance(31)
WOW.Advance(3.5)
WOW.Advance(3)
local per = {}
for _, s in ipairs(sent) do if s.channel == "WHISPER" then per[s.target] = (per[s.target] or 0) + 1 end end
check(per["Teki La"] == 2 and per["Hazas War"] == nil, "one whisper per item, and none to yourself (" .. tostring(per["Teki La"]) .. ")")
reset()
CL.db.sessionWhisper = false
Run.Start()
roll("Teki La", 80)
WOW.Advance(31)
WOW.Advance(8)
check(sentCount("Come trade me") == 0, "whispers off: none")

-- 11. Alone and in a party
reset()
inRaid = false
Run.Start()
check(sent[1].channel == "PARTY", "in a party the messages go to /p")
Run.Cancel()
reset()
inGroup, inRaid = false, false
Run.Start()
check(#sent == 0 and sayMatches("Loot session: 1 item"), "alone nothing is sent, it is printed to you")
roll("Hazas War", 55)
WOW.Advance(31)
check(sayMatches("assigned to Hazas War for roll MS 55"), "alone you can roll and win: that is how to try it")
WOW.Advance(8)
check(#sent == 0, "...and no whisper goes to yourself")
inGroup, inRaid = true, true

-- 12. The test session never reaches the group
reset()
check(Run.StartTest() == true and Run.State().test, "a test session starts")
check(#sent == 0 and sayMatches("Loot session:"), "it is only printed to you")
WOW.Advance(35)
WOW.Advance(8)
check(#sent == 0, "a test session sends nothing to the group, whispers included")
check(sayMatches("assigned to"), "...yet it runs: the made-up players roll and somebody wins")
Run.Cancel()
check(CL.db.pool.G1.awardedTo == nil, "a test session does not mark your real items as given")
CL.db.pool = {}
check(Run.StartTest() == true and #Run.State().queue == 2, "with no real item it uses two made-up ones")
Run.Cancel()
CL.db.pool = {}
Run.Start()
check(sayMatches("no item to offer") and not Run.Active(), "(a real session cannot start with nothing)")

-- 13. The window
reset({ { id = 100, name = "Test Blade" }, { id = 101, name = "Test Ring" } })
SlashCmdList.CLEANLOOT("session")
local win = Session.Window()
check(win:IsShown() and win.start:IsEnabled(), "the window opens with Start session enabled")
masterParty = 2
Session.Refresh()
check(not win.start:IsEnabled(), "not the master looter: Start session is greyed")
masterParty = 0
Session.Refresh()
win.start.__scripts.OnClick(win.start)
check(Run.Active() and win.title:GetText() == "Loot session: running", "Start session starts it and shows the session")
check(win.runName:GetText() == "Test Blade" and win.runCount:GetText():find("Item 1 of 2", 1, true), "it shows the item in play (" .. tostring(win.runName:GetText()) .. ")")
check(win.runTime:GetText() == "30 s", "...and the time left")
roll("Teki La", 88)
roll("Iso Tope", 12, 99)
WOW.Advance(0.3)
local rows = {}
for _, row in ipairs(win.runRows) do if row.entry then rows[#rows + 1] = row end end
check(#rows == 2 and rows[1].who:GetText() == "Teki La" and rows[1].roll:GetText():find("MS 88", 1, true), "the rolls appear as they come, best first")
check(rows[2].roll:GetText():find("OS 12", 1, true), "...with their category")
check(win.controls.pause:IsShown() and not win.controls.resume:IsShown() and win.controls.cancel:IsEnabled(), "the controls are there")
win.controls.pause.__scripts.OnClick(win.controls.pause)
check(win.controls.resume:IsShown() and not win.controls.pause:IsShown() and win.runTime:GetText():find("paused", 1, true), "Pause becomes Resume")
win.controls.resume.__scripts.OnClick(win.controls.resume)
win.controls.extend.__scripts.OnClick(win.controls.extend)
check(win.runTime:GetText() == "40 s" or win.runTime:GetText() == "39 s", "+10 s adds ten seconds (" .. tostring(win.runTime:GetText()) .. ")")
win.controls.cancel.__scripts.OnClick(win.controls.cancel)
check(not Run.Active() and win.title:GetText() == "Loot session", "Cancel goes back to the list")

-- picking by a click, with a confirmation at the mouse
reset({ { id = 100, name = "Test Blade" } })
CL.db.sessionAuto = false
Session.Open()
Run.Start()
roll("Teki La", 88)
roll("Iso Tope", 90, 99)
WOW.Advance(31)
win = Session.Window()
rows = {}
for _, row in ipairs(win.runRows) do if row.entry then rows[#rows + 1] = row end end
check(win.runStatus:GetText():find("click a name", 1, true), "rolls closed: the window asks you to click a name")
rows[2].__scripts.OnClick(rows[2])
local box = ML.Confirm()
check(box:IsShown() and box.text:GetText():find("Assign Test Blade to Iso Tope", 1, true), "a click on a name asks for confirmation")
check(not sentHas("assigned to"), "...and nothing is assigned yet")
box.give.__scripts.OnClick(box.give)
check(sentHas("assigned to Iso Tope for roll OS 90"), "confirming assigns it")
Run.Cancel()

-- 14. The commands
reset()
SlashCmdList.CLEANLOOT("session start")
check(Run.Active(), "/cll session start starts a session")
SlashCmdList.CLEANLOOT("session stop")
check(not Run.Active(), "/cll session stop ends it")
said = {}
SlashCmdList.CLEANLOOT("session stop")
check(sayMatches("no session is running"), "(and says so when none runs)")
SlashCmdList.CLEANLOOT("session test")
check(Run.Active() and Run.State().test, "/cll session test starts a test")
Run.Cancel()

-- 15. The options
local W = CL.Options.widgets
check(W.sessionTime and W.sessionAuto and W.sessionWhisper, "the Master loot tab has the session settings")
W.sessionTime:SetValue(45)
W.sessionTime.__scripts.OnValueChanged(W.sessionTime, 45)
check(CL.db.sessionTime == 45, "the timer setting is saved")
CL.db.sessionTime = 30

print = realPrint
io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
