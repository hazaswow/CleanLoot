-- Master loot: the roll result window and the hand-out, against the stub client.
-- Run with lua tools/test_masterloot.lua.
local WOW = dofile("tools/wowenv.lua")
local CL, ML = WOW.CL, WOW.CL.MasterLoot
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

-- the loot method, the group, the chat, the loot window
local method, masterParty, masterRaid = "master", 0, nil
function GetLootMethod() return method, masterParty, masterRaid end
local inRaid, inGroup = false, true
function IsInRaid() return inRaid end
function IsInGroup() return inGroup end
local sent = {}
function SendChatMessage(msg, channel) sent[#sent + 1] = { msg = msg, channel = channel } end
local LINK = "|cnIQ3:|Hitem:9458::::::::60:1491::1::1:28:5242:::::|h[Thermaplugg's Central Core]|h|r"
local slots = { LINK }
function GetNumLootItems() return #slots end
function GetLootSlotLink(slot) return slots[slot] end
local candidates = { "Humark Clearsight", "Teki La", "Hazas War", "Iso Tope" }
function GetMasterLootCandidate(slot, index) return candidates[index] end
local gave = {}
function GiveMasterLoot(slot, index)
    gave[#gave + 1] = { slot = slot, index = index }
end
function GetCursorPosition() return 400, 300 end

-- the loot history
local function Entry(name, class, state, roll, isSelf)
    return { playerName = name, playerClass = class, state = state, roll = roll, isSelf = isSelf or false, isWinner = false }
end
WOW.drops = {}
C_LootHistory = {
    GetAllEncounterInfos = function() return { { encounterID = 0 } } end,
    GetSortedDropsForEncounter = function() return {} end,
    GetSortedInfoForDrop = function(_, key) return WOW.drops[key] end,
}
local function Drop(key, infos, link)
    WOW.drops[key] = { lootListKey = key, itemHyperlink = link or LINK, playerRollState = 3, allPassed = false, rollInfos = infos }
end
local function reset()
    said, sent, gave = {}, {}, {}
    method, masterParty, masterRaid = "master", 0, nil
    inRaid, inGroup = false, true
    slots = { LINK }
    CL.db.masterWindow, CL.db.masterAnnounce = true, true
    ML.CloseAll()
    CL.Results.ForgetRolls()
end

local function over(key)
    WOW.FireEvent("LOOT_ROLLS_COMPLETE", key)
    WOW.Advance(1)
end
local function Standard(key)
    Drop(key, {
        Entry("Teki La", "PRIEST", 3, 44), Entry("Hazas War", "WARRIOR", 3, 36, true),
        Entry("Iso Tope", "MAGE", 3, 14), Entry("Humark Clearsight", "HUNTER", 3, 7),
        Entry("Za Bo", "ROGUE", 5), Entry("Late Comer", "DRUID", 4),
    })
end

-- 1. Who is the master looter
check(ML.IsMasterLoot() and ML.IsMasterLooter(), "master loot, party index 0: you are the master looter")
masterParty = 2
check(ML.IsMasterLoot() and not ML.IsMasterLooter(), "master loot, another player's party index: you are not")
masterParty, masterRaid = nil, 3
function UnitIsUnit(a, b) return a == "raid3" and b == "player" end
check(ML.IsMasterLooter(), "in a raid: your raid index makes you the master looter")
masterRaid = 5
check(not ML.IsMasterLooter(), "...another raid index does not")
method = "group"
check(not ML.IsMasterLoot() and not ML.IsMasterLooter(), "group loot is not master loot")
method, masterParty, masterRaid = 2, 0, nil
check(ML.IsMasterLoot() and ML.IsMasterLooter(), "a numeric loot method (2) works too")
method = "master"

-- 2. The rolls are over: the window opens, whatever the game says about a winner
reset()
Standard(7001)
CL.Results.Watch(7001)
CL.Results.RefreshWaiting(true)
check(#CL.Results.Waiting() == 1, "(before the end the waiting card lists the player who has not answered)")
over(7001)
CL.Results.RefreshWaiting(true)
check(#CL.Results.Waiting() == 0, "once the rolls are over nobody is waited for any more")
check(#ML.Windows() == 1, "master loot: the rolls are over, the window opens")
local win = ML.Windows()[1]
check(win.name:GetText() == "Thermaplugg's Central Core", "the window names the item")
local rows = {}
for _, row in ipairs(win.rows) do if row.entry then rows[#rows + 1] = row end end
check(#rows == 4, "four rows, the ones who rolled (" .. #rows .. ")")
check(rows[1].who:GetText() == "Teki La" and rows[2].who:GetText() == "You", "best roll first, you shown as You")
check(rows[1].roll:GetText():find("44", 1, true) and rows[1].roll:GetText():find("|cffffd100", 1, true), "the best roll is gold")
check(win.foot:GetText():find("1 passed", 1, true) and win.foot:GetText():find("1 did not roll", 1, true),
    "the footer counts who passed and who did not roll (" .. tostring(win.foot:GetText()) .. ")")
check(win.sub:GetText():find("Click a name", 1, true), "the master looter is told to click a name")
over(7001)
check(#ML.Windows() == 1, "a second 'complete' for the same roll does not open a second window")

-- 3. Not master loot, or the game named a winner: no window of ours
reset()
method = "group"
Standard(7002)
over(7002)
check(#ML.Windows() == 0, "group loot: no window (the winner popup does that)")
reset()
Standard(7003)
WOW.drops[7003].rollInfos[1].isWinner = true
WOW.drops[7003].winner = WOW.drops[7003].rollInfos[1]
over(7003)
check(#ML.Windows() == 0, "the game named a winner: no window")
reset()
CL.db.masterWindow = false
Standard(7004)
over(7004)
check(#ML.Windows() == 0, "the option is off: no window")
reset()
Drop(7005, { Entry("Za Bo", "ROGUE", 5), Entry("Late Comer", "DRUID", 4) })
over(7005)
check(#ML.Windows() == 0, "nobody rolled: no window")

-- 4. Everybody sees it, only the master looter can click
reset()
masterParty = 3
Standard(7006)
over(7006)
win = ML.Windows()[1]
check(win and win.sub:GetText():find("The master looter gives the item", 1, true), "another player: the help says who gives it")
local row1 = win.rows[1]
row1.__scripts.OnClick(row1)
check(not (ML.Confirm() and ML.Confirm():IsShown()), "...and a click on a name does nothing")

-- 5. A tie is flagged
reset()
Drop(7007, { Entry("Teki La", "PRIEST", 3, 44), Entry("Iso Tope", "MAGE", 3, 44), Entry("Humark Clearsight", "HUNTER", 3, 7) })
over(7007)
win = ML.Windows()[1]
check(win.rows[1].who:GetText():find("tie", 1, true) and win.rows[2].who:GetText():find("tie", 1, true)
    and not win.rows[3].who:GetText():find("tie", 1, true), "two equal best rolls are both marked as a tie")

-- 6. Need beats Greed whatever the numbers
reset()
Drop(7008, { Entry("Teki La", "PRIEST", 3, 98), Entry("Iso Tope", "MAGE", 0, 3) })
over(7008)
win = ML.Windows()[1]
check(win.rows[1].who:GetText() == "Iso Tope", "a Need roll of 3 is above a Greed roll of 98")

-- 7. The hand-out: a click, a confirmation at the mouse, then the game's call
reset()
Standard(7009)
over(7009)
win = ML.Windows()[1]
row1 = win.rows[1]
row1.__scripts.OnClick(row1)
local box = ML.Confirm()
check(box and box:IsShown(), "a click on a name opens the confirmation")
check(box.text:GetText():find("Teki La", 1, true) and box.text:GetText():find("Thermaplugg's Central Core", 1, true),
    "...naming the item and the player (" .. tostring(box.text:GetText()) .. ")")
check(box.detail:GetText():find("44", 1, true), "...and the roll")
local point = { box:GetPoint() }
check(point[1] == "CENTER" and point[4] == 400 and point[5] == 300, "...placed at the mouse")
check(#gave == 0, "nothing is handed out before it is confirmed")
box.cancel.__scripts.OnClick(box.cancel)
check(not box:IsShown() and #gave == 0, "Cancel hands nothing out")

row1.__scripts.OnClick(row1)
box.give.__scripts.OnClick(box.give)
check(#gave == 1 and gave[1].slot == 1 and gave[1].index == 2, "Give calls GiveMasterLoot with the slot and the player's index")
check(#sent == 0 and not win.given, "...and says nothing until the game confirms")
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
check(win.given == "Teki La", "the slot clearing is the confirmation")
check(#sent == 1 and sent[1].channel == "PARTY", "the group is told, in /p")
local m = sent[1].msg
check(m:find("[CleanLoot]", 1, true) == 1 and m:find("given to Teki La for roll Greed 44", 1, true), "...what, to whom, for which roll (" .. m .. ")")
check(m:find("|Hitem:9458::::::::60:1491::1::1:28:5242:::::|h[Thermaplugg's Central Core]|h", 1, true)
    and m:find("|cff", 1, true) and not m:find("|cn", 1, true), "...with the item as a classic coloured link")
check(win.sub:GetText():find("Given to Teki La", 1, true), "the window says who got it")
row1.__scripts.OnClick(row1)
check(not box:IsShown() and #gave == 1, "a given item cannot be given again")
WOW.Advance(21)
check(#ML.Windows() == 0, "the window closes by itself a while after the hand-out")

-- in a raid it is /ra
reset()
inRaid = true
Standard(7010)
over(7010)
win = ML.Windows()[1]
win.rows[2].__scripts.OnClick(win.rows[2])
ML.Confirm().give.__scripts.OnClick(ML.Confirm().give)
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
check(#sent == 1 and sent[1].channel == "RAID" and sent[1].msg:find("given to Hazas War for roll Greed 36", 1, true), "in a raid the announcement goes to /ra")

-- the announcement can be switched off
reset()
CL.db.masterAnnounce = false
Standard(7011)
over(7011)
win = ML.Windows()[1]
win.rows[1].__scripts.OnClick(win.rows[1])
ML.Confirm().give.__scripts.OnClick(ML.Confirm().give)
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
check(win.given == "Teki La" and #sent == 0 and sayMatches("given to Teki La"), "announcement off: the hand-out is told to you only")

-- alone, there is nobody to tell
reset()
inGroup = false
Standard(7012)
over(7012)
win = ML.Windows()[1]
win.rows[1].__scripts.OnClick(win.rows[1])
ML.Confirm().give.__scripts.OnClick(ML.Confirm().give)
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
check(#sent == 0 and sayMatches("given to Teki La"), "not in a group: no chat message, you are told")

-- 8. Things that stop a hand-out
reset()
Standard(7013)
over(7013)
win = ML.Windows()[1]
slots = {}
win.rows[1].__scripts.OnClick(win.rows[1])
ML.Confirm().give.__scripts.OnClick(ML.Confirm().give)
check(#gave == 0 and sayMatches("not in an open loot window"), "no loot window with the item: nothing is called, you are told")
slots = { "|cnIQ1:|Hitem:1::::|h[Other]|h|r", LINK }
said = {}
win.rows[1].__scripts.OnClick(win.rows[1])
ML.Confirm().give.__scripts.OnClick(ML.Confirm().give)
check(#gave == 1 and gave[1].slot == 2, "the item is found in whichever slot it is")
WOW.Advance(3)
check(sayMatches("the game did not confirm"), "a refusal (no confirmation in time) is reported")
check(not win.given and #sent == 0, "...and nothing is announced")
candidates = { "Humark Clearsight", "Iso Tope" }
said, gave = {}, {}
win.rows[1].__scripts.OnClick(win.rows[1])
ML.Confirm().give.__scripts.OnClick(ML.Confirm().give)
check(#gave == 0 and sayMatches("Teki La is not on the loot window's list"), "a player the game does not list cannot be given the item")
candidates = { "Humark Clearsight", "Teki La", "Hazas War", "Iso Tope" }

-- the chat line is the other confirmation; the first name works for a full one
said, sent, gave = {}, {}, {}
candidates = { "Humark", "Teki", "Hazas", "Iso" }
win.rows[1].__scripts.OnClick(win.rows[1])
ML.Confirm().give.__scripts.OnClick(ML.Confirm().give)
check(#gave == 1 and gave[1].index == 2, "a first name in the list matches the full name")
WOW.FireEvent("CHAT_MSG_LOOT", "Teki La receives loot: " .. LINK .. ".")
check(win.given == "Teki La" and #sent == 1, "the 'receives loot' line confirms it too")
candidates = { "Humark Clearsight", "Teki La", "Hazas War", "Iso Tope" }

-- 9. Several windows, side by side, at most four
reset()
for i = 1, 5 do
    Standard(7100 + i)
    over(7100 + i)
end
check(#ML.Windows() == 4, "at most four windows at once")
local w1, w2 = ML.Windows()[1], ML.Windows()[2]
local p = { w2:GetPoint() }
check(p[1] == "TOPLEFT" and p[2] == w1 and p[3] == "TOPRIGHT", "the next window sits beside the previous one")
ML.Close(w1)
check(#ML.Windows() == 3, "a window closes with its X")

-- 10. The simulator
reset()
local sim = ML.Simulate()
check(sim and sim.simulated and #ML.Windows() == 1, "/cll sim master opens a window")
check(sim.name:GetText() == "Sim Rare Blade", "...for a made-up item")
sim.rows[1].__scripts.OnClick(sim.rows[1])
ML.Confirm().give.__scripts.OnClick(ML.Confirm().give)
check(sim.given and #sent == 0 and #gave == 0, "a simulated hand-out calls nothing and says nothing to the group")
check(sayMatches("given to"), "...it is only printed")
said = {}
SlashCmdList.CLEANLOOT("sim master")
check(#ML.Windows() == 2, "the slash command works too")

-- 11. The options
check(CL.Options.widgets.masterWindow and CL.Options.widgets.masterAnnounce, "the General page has the two master-loot options")
CL.Options.widgets.masterWindow:SetChecked(false)
CL.Options.widgets.masterWindow.__scripts.OnClick(CL.Options.widgets.masterWindow)
check(CL.db.masterWindow == false, "the window option can be switched off")
CL.db.masterWindow = true

-- 11b. A roll that lands after the window opened joins it
reset()
Drop(7300, { Entry("Teki La", "PRIEST", 3, 44), Entry("Iso Tope", "MAGE", 3, 14) })
over(7300)
win = ML.Windows()[1]
local function rowCount(w) local n = 0 for _, r in ipairs(w.rows) do if r.entry then n = n + 1 end end return n end
check(rowCount(win) == 2, "the window opens with the rolls known at the end")
WOW.drops[7300].rollInfos[#WOW.drops[7300].rollInfos + 1] = Entry("Humark Clearsight", "HUNTER", 3, 91)
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 0, 7300)
check(rowCount(win) == 3 and win.rows[1].who:GetText() == "Humark Clearsight", "a late roll joins the window, and takes the top (" .. tostring(win.rows[1].who:GetText()) .. ")")
check(#ML.Windows() == 1, "...in the same window")
win.rows[1].__scripts.OnClick(win.rows[1])
ML.Confirm().give.__scripts.OnClick(ML.Confirm().give)
WOW.FireEvent("LOOT_SLOT_CLEARED", 1)
WOW.drops[7300].rollInfos[#WOW.drops[7300].rollInfos + 1] = Entry("Late Comer", "DRUID", 3, 99)
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 0, 7300)
check(rowCount(win) == 3 and win.given, "once the item is given the window no longer changes")

-- nobody had rolled when the roll ended: the window comes when the first roll does
reset()
Drop(7301, { Entry("Teki La", "PRIEST", 4), Entry("Iso Tope", "MAGE", 4) })
over(7301)
check(#ML.Windows() == 0, "nobody rolled at the end: no window yet")
WOW.drops[7301].rollInfos[1].state, WOW.drops[7301].rollInfos[1].roll = 3, 55
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 0, 7301)
check(#ML.Windows() == 1 and rowCount(ML.Windows()[1]) == 1, "...it opens when a roll arrives")
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 0, 7301)
check(#ML.Windows() == 1, "...once")
-- an update for a roll we never handled does nothing
Drop(7302, { Entry("Teki La", "PRIEST", 3, 10) })
WOW.FireEvent("LOOT_HISTORY_UPDATE_DROP", 0, 7302)
check(#ML.Windows() == 1, "a history update for another roll opens nothing")
reset()

-- 12. Gargul also announces hand-outs: ask once which one keeps doing it
local function fakeGargul(on)
    local g = { Settings = { values = { ["AwardingLoot.awardMessagesEnabled"] = on }, setCalls = 0 } }
    function g.Settings:get(key) return self.values[key] end
    function g.Settings:set(key, value) self.values[key] = value self.setCalls = self.setCalls + 1 return true end
    return g
end
local function resetGargul()
    reset()
    Gargul = nil
    CL.db.gargulAsked = nil
    if ML.GargulBox() then ML.GargulBox():Hide() end
end

resetGargul()
check(ML.GargulAnnounces() == nil and not ML.AskGargul(false), "no Gargul: nothing to ask")
SlashCmdList.CLEANLOOT("gargul")
check(sayMatches("Gargul is not installed"), "/cll gargul says so when it is not there")

resetGargul()
Gargul = fakeGargul(true)
check(ML.GargulAnnounces() == true and ML.GargulConflict(), "Gargul with its award messages on, and ours on: a conflict")
check(ML.MaybeAskGargul() == true and ML.GargulBox():IsShown(), "the master looter is asked")
local gb = ML.GargulBox()
gb.both.__scripts.OnClick(gb.both)
check(not gb:IsShown() and CL.db.gargulAsked and CL.db.masterAnnounce and Gargul.Settings.values["AwardingLoot.awardMessagesEnabled"] == true,
    "Keep both changes nothing")
check(ML.MaybeAskGargul() == false and not gb:IsShown(), "...and it is not asked again")
SlashCmdList.CLEANLOOT("gargul")
check(gb:IsShown(), "/cll gargul asks again whenever you want")
gb:Hide()

resetGargul()
Gargul = fakeGargul(true)
ML.MaybeAskGargul()
gb = ML.GargulBox()
gb.mine.__scripts.OnClick(gb.mine)
check(CL.db.masterAnnounce == false and Gargul.Settings.values["AwardingLoot.awardMessagesEnabled"] == true and Gargul.Settings.setCalls == 0,
    "Turn off CleanLoot's: only our option goes off, Gargul is not touched")
check(not ML.GargulConflict(), "...and there is no conflict any more")
CL.db.masterAnnounce = true

resetGargul()
Gargul = fakeGargul(true)
ML.MaybeAskGargul()
gb = ML.GargulBox()
gb.theirs.__scripts.OnClick(gb.theirs)
check(Gargul.Settings.values["AwardingLoot.awardMessagesEnabled"] == false and CL.db.masterAnnounce == true,
    "Turn off Gargul's: its Award messages go off, ours stay on")
check(not ML.GargulConflict(), "...and there is no conflict any more")

-- when it is not asked
resetGargul()
Gargul = fakeGargul(false)
check(not ML.MaybeAskGargul(), "Gargul's award messages already off: nothing to ask")
resetGargul()
Gargul = fakeGargul(true)
CL.db.masterAnnounce = false
check(not ML.MaybeAskGargul(), "our announcements off: nothing to ask")
SlashCmdList.CLEANLOOT("gargul")
check(sayMatches("nothing is announced twice") and not ML.GargulBox():IsShown(), "...and /cll gargul explains the state instead")
resetGargul()
Gargul = fakeGargul(true)
masterParty = 2
check(not ML.MaybeAskGargul(), "not the master looter: not asked")
masterParty = 0
function InCombatLockdown() return true end
check(not ML.MaybeAskGargul(), "in combat: not asked")
function InCombatLockdown() return false end
check(ML.MaybeAskGargul(), "...out of combat it is")
ML.GargulBox():Hide()

-- the triggers
resetGargul()
Gargul = fakeGargul(true)
WOW.FireEvent("PARTY_LOOT_METHOD_CHANGED")
WOW.Advance(2)
check(ML.GargulBox() and ML.GargulBox():IsShown(), "becoming master looter asks (a moment after the change)")
ML.GargulBox():Hide()
resetGargul()
Gargul = fakeGargul(true)
Standard(7200)
over(7200)
check(ML.GargulBox() and ML.GargulBox():IsShown(), "so does the first roll result window as master looter")
ML.GargulBox():Hide()

-- the options button only shows when Gargul is there
resetGargul()
CL.Options.Refresh()
check(not CL.Options.widgets.gargulAsk:IsShown(), "no Gargul: no button on the General tab")
Gargul = fakeGargul(true)
CL.Options.Refresh()
check(CL.Options.widgets.gargulAsk:IsShown(), "Gargul installed: the button is there")
CL.Options.widgets.gargulAsk.__scripts.OnClick(CL.Options.widgets.gargulAsk)
check(ML.GargulBox():IsShown(), "...and asks")
ML.GargulBox():Hide()
Gargul = nil
CL.db.gargulAsked = nil

print = realPrint
io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
