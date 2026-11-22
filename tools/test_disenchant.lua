-- The disenchanter: asking, answering, designating, and what a session does with him, against the
-- stub client. Run with lua tools/test_disenchant.lua.
local WOW = dofile("tools/wowenv.lua")
local CL = WOW.CL
local ML, DE, Run, Pool, PW = CL.MasterLoot, CL.Disenchant, CL.SessionRun, CL.LootPool, CL.PlayerWindow
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
local leader = false
function UnitIsGroupLeader() return leader end
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

local sentChat, sentAddon = {}, {}
function SendChatMessage(msg, channel, _, target) sentChat[#sentChat + 1] = { msg = msg, channel = channel, target = target } end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, text, channel) sentAddon[#sentAddon + 1] = { prefix = prefix, text = text, channel = channel } end,
}
-- item 100 is armor, 200 is a mount (misc), 300 a weapon
C_Item = C_Item or {}
C_Item.GetItemInfoInstant = function(link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    local class = ({ [100] = 4, [200] = 15, [300] = 2 })[id] or 4
    return id, "type", "subtype", "equip", "Interface\\Icons\\Test", class, 0
end

local function link(id, name, uniq)
    return ("|cffa335ee|Hitem:%d:::::::%s:60:1491::1::1:28:5242:::::|h[%s]|h|r"):format(id, uniq or "", name)
end
local function stock(items)
    CL.db.pool = {}
    for i, it in ipairs(items) do
        CL.db.pool["G" .. i] = { itemID = it.id, link = link(it.id, it.name, it.uniq or tostring(i)), seen = serverTime - i,
            expires = serverTime + 3600 * i, quality = it.quality or 4 }
    end
end
local function roll(name, value, hi)
    WOW.FireEvent("CHAT_MSG_SYSTEM", ("%s rolls %d (1-%d)"):format(name, value, hi or 100))
end
local function sentHas(p)
    for _, s in ipairs(sentChat) do if s.msg:find(p, 1, true) then return true end end
    return false
end
local function reset()
    if Run.Active() then Run.Cancel() end
    PW.Reset()
    WOW.Advance(10)
    sentChat, sentAddon, said = {}, {}, {}
    method, masterParty, inRaid, inGroup, leader = "master", 0, true, true, false
    CL.db.masterEnabled, CL.db.sessionAuto, CL.db.sessionWhisper, CL.db.sessionTime = true, true, true, 30
    CL.db.deKeyword, CL.db.deKeep, CL.db.sessionDEAuto, CL.db.deName = "de", false, true, nil
    DE.candidates, DE.askedAt = {}, nil
    CL.db.pool = {}
    if DE.window then DE.window:Hide() end
end

-- 1. The word
reset()
check(DE.Keyword() == "de", "the default word is de")
CL.db.deKeyword = "  DEZ "
check(DE.Keyword() == "dez", "a custom word is lower-cased and trimmed")
CL.db.deKeyword = ""
check(DE.Keyword() == "de", "...an empty one falls back to the default")
CL.db.deKeyword = "de"

-- 2. Asking
reset()
masterParty = 2
check(DE.Ask() == false and sayMatches("only the master looter"), "in a group only the master looter can ask")
masterParty = 0
CL.db.masterEnabled = false
check(DE.Ask() == false, "master loot off: no question")
CL.db.masterEnabled = true
check(DE.Ask() == true and DE.IsAsking(), "the master looter asks")
check(sentChat[1].channel == "RAID" and sentChat[1].msg:find("Who can disenchant?", 1, true) and sentChat[1].msg:find('"de"', 1, true),
    "in /ra, naming the word (" .. tostring(sentChat[1] and sentChat[1].msg) .. ")")
inRaid = false
sentChat = {}
DE.Ask()
check(sentChat[1].channel == "PARTY", "in a party it is /p")
inRaid, leader = true, true
CL.db.masterRaidWarning = true
sentChat = {}
DE.Ask()
check(sentChat[1].channel == "RAID_WARNING", "with the /rw option and the lead it is /rw")
CL.db.masterRaidWarning = false
inGroup, inRaid = false, false
sentChat, said = {}, {}
DE.Ask()
check(#sentChat == 0 and sayMatches("Who can disenchant?"), "alone it is only printed")
inGroup, inRaid = true, true

-- 3. Hearing the answers
reset()
check(DE.Hear("de", "Teki La") == false and #DE.candidates == 0, "an answer when nobody asked is ignored")
DE.Ask()
check(DE.Hear("de", "Teki La") and #DE.candidates == 1 and DE.candidates[1].name == "Teki La", "the word alone is an answer")
check(DE.Hear("  DE ", "Iso Tope") and #DE.candidates == 2, "capitals and spaces do not matter")
check(DE.Hear("de 300", "Humark Clearsight") and DE.candidates[3].skill == 300, "a number after it is the skill")
check(DE.Hear("de 375", "Teki La") and #DE.candidates == 3 and DE.candidates[1].skill == 375, "an answer again from the same player updates him")
check(not DE.Hear("dez", "Nobody") and not DE.Hear("de please", "Nobody") and not DE.Hear("hello", "Nobody") and #DE.candidates == 3,
    "anything else is not an answer")
check(not DE.Hear("de", "") and not DE.Hear("de", nil), "(an answer needs somebody who said it)")
WOW.FireEvent("CHAT_MSG_RAID", "de", "Zed Zeta")
WOW.FireEvent("CHAT_MSG_PARTY", "de", "Yan Yarrow")
WOW.FireEvent("CHAT_MSG_WHISPER", "de 200", "Xan Xylo")
check(#DE.candidates == 6, "answers come from the raid, the party and whispers (" .. #DE.candidates .. ")")
WOW.FireEvent("CHAT_MSG_SAY", "de", "Stranger")
check(#DE.candidates == 6, "(not from /say: not the group)")
DE.StopAsking()
check(not DE.IsAsking() and not DE.Hear("de", "Late Comer"), "once stopped, answers are ignored")
DE.Ask()
check(#DE.candidates == 0, "asking again starts a fresh list")
WOW.Advance(181)
check(not DE.IsAsking(), "the question closes by itself after three minutes")
DE.Ask()
for i = 1, 20 do DE.Hear("de", "Player" .. i) end
check(#DE.candidates == 12, "the list is capped")

-- 4. Designating
reset()
check(DE.Name() == nil, "nobody to begin with")
sentChat = {}
check(DE.Designate("Teki La") == true and DE.Name() == "Teki La" and CL.db.deName == "Teki La", "designating saves the name")
check(sentChat[1].channel == "RAID" and sentChat[1].msg:find("Teki La is the designated disenchanter", 1, true), "...and tells the group")
check(DE.Designate("   ") == false and DE.Designate(nil) == false and DE.Name() == "Teki La", "an empty name designates nobody")
check(DE.Clear() == true and DE.Name() == nil and DE.Clear() == false, "clearing removes him")
DE.Ask()
DE.Designate("Iso Tope")
check(not DE.IsAsking(), "designating closes the question")

-- 5. The window
reset()
DE.Ask()
DE.Hear("de 300", "Teki La")
DE.Hear("de", "Iso Tope")
SlashCmdList.CLEANLOOT("de")
local win = DE.window
check(win and win:IsShown(), "/cll de opens the window")
check(win.current:GetText():find("nobody yet", 1, true) and win.sub:GetText():find("Listening", 1, true), "it says nobody is designated, and that it listens")
local rows = {}
for _, row in ipairs(win.rows) do if row:IsShown() then rows[#rows + 1] = row end end
check(#rows == 2 and rows[1].who:GetText() == "Teki La" and rows[1].skill:GetText():find("300", 1, true), "the answers are listed, with the skill when given")
rows[2].__scripts.OnClick(rows[2])
local box = ML.Confirm()
check(box:IsShown() and box.text:GetText():find("Make Iso Tope the disenchanter", 1, true), "a click on a name asks first")
check(DE.Name() == nil, "(nobody yet)")
box.give.__scripts.OnClick(box.give)
check(DE.Name() == "Iso Tope" and win.current:GetText():find("Iso Tope", 1, true), "confirming designates him")
check(win.clear:IsEnabled(), "...and 'No one' is available")
win.clear.__scripts.OnClick(win.clear)
check(DE.Name() == nil, "'No one' clears him")
win.box:SetText("Humark Clearsight")
win.byName.__scripts.OnClick(win.byName)
check(DE.Name() == "Humark Clearsight", "somebody who did not answer can be designated by name")
win.ask.__scripts.OnClick(win.ask)
check(DE.IsAsking() and #DE.candidates == 0, "the button asks again, with a fresh list")
win.stop.__scripts.OnClick(win.stop)
check(not DE.IsAsking(), "Stop closes the question")
SlashCmdList.CLEANLOOT("de")
check(not win:IsShown(), "/cll de again closes the window")

-- 6. The commands
reset()
SlashCmdList.CLEANLOOT("de ask")
check(DE.IsAsking() and DE.window:IsShown(), "/cll de ask opens the window and asks")
SlashCmdList.CLEANLOOT("de stop")
check(not DE.IsAsking(), "/cll de stop")
SlashCmdList.CLEANLOOT("de Teki La")
check(DE.Name() == "Teki La", "/cll de <name> designates")
SlashCmdList.CLEANLOOT("de clear")
check(DE.Name() == nil, "/cll de clear")

-- 7. A session gives the disenchanter what nobody wants
local function session(items)
    reset()
    stock(items)
    DE.Designate("Iso Tope")
    sentChat, sentAddon = {}, {}
    Run.Start()
end
local function waitItem()
    WOW.Advance(31)
end

session({ { id = 100, name = "Armor Piece" } })
waitItem()
check(sentHas("No roll for") and sentHas("goes to Iso Tope to disenchant"), "an item nobody rolls for goes to the disenchanter (" .. table.concat((function() local t = {} for _, s in ipairs(sentChat) do t[#t + 1] = s.msg end return t end)(), " | ") .. ")")
check(CL.db.pool.G1.awardedTo == "Iso Tope" and #Pool.Offered() == 0, "...it is marked as given and no longer offered")
local de = Run.AwardsFor(Run.History()[1].lot)[1]
check(de and de.de and de.winner == "Iso Tope" and not de.cat, "the award is marked as a disenchant, with no roll")
local wmsg
for _, a in ipairs(sentAddon) do if a.text:match("^W") then wmsg = a.text end end
check(wmsg and wmsg:find("Iso Tope", 1, true) and wmsg:sub(-2) == "DE", "the players' windows are told it is a disenchant (" .. tostring(wmsg) .. ")")
WOW.Advance(3.5)
sentChat = {}
Run.Finish()
WOW.Advance(2)
local whisper
for _, s in ipairs(sentChat) do if s.channel == "WHISPER" then whisper = s end end
check(whisper and whisper.target == "Iso Tope" and whisper.msg:find("You are the disenchanter", 1, true) and whisper.msg:find("trade me the materials", 1, true),
    "he is whispered: come, disenchant, trade the materials back (" .. tostring(whisper and whisper.msg) .. ")")

session({ { id = 100, name = "Armor Piece" } })
CL.db.deKeep = true
waitItem()
WOW.Advance(3.5)
sentChat = {}
Run.Finish()
WOW.Advance(2)
whisper = nil
for _, s in ipairs(sentChat) do if s.channel == "WHISPER" then whisper = s end end
check(whisper and whisper.msg:find("the materials are yours", 1, true), "or the materials are his, when the option says so")

-- items that cannot be disenchanted, or when the option or the designation is off
session({ { id = 200, name = "Mount" } })
waitItem()
check(sentHas("No roll for") and not sentHas("disenchant"), "an item that is not armor or a weapon is not sent to him")
session({ { id = 100, name = "White Thing", quality = 1 } })
waitItem()
check(not sentHas("disenchant"), "...nor a white one")
session({ { id = 100, name = "Legendary", quality = 5 } })
waitItem()
check(not sentHas("disenchant"), "...nor a legendary one")
session({ { id = 300, name = "Weapon Piece", quality = 2 } })
waitItem()
check(sentHas("goes to Iso Tope to disenchant"), "a green weapon is")
reset()
stock({ { id = 100, name = "Armor Piece" } })
CL.db.sessionDEAuto = false
DE.Designate("Iso Tope")
sentChat = {}
Run.Start()
waitItem()
check(sentHas("No roll for") and not sentHas("disenchant"), "the option off: he gets nothing by himself")
reset()
stock({ { id = 100, name = "Armor Piece" } })
Run.Start()
waitItem()
check(sentHas("No roll for") and not sentHas("disenchant"), "nobody designated: nothing goes to him")
Run.Cancel()

-- copies nobody rolled for
reset()
stock({ { id = 100, name = "Twin Armor", uniq = "1" }, { id = 100, name = "Twin Armor", uniq = "2" }, { id = 100, name = "Twin Armor", uniq = "3" } })
DE.Designate("Iso Tope")
sentChat = {}
Run.Start()
roll("A One", 90)
waitItem()
check(sentHas("assigned to A One") and sentHas("x2 goes to Iso Tope to disenchant"), "three copies, one roll: the other two go to the disenchanter")
check(CL.db.pool.G1.awardedTo == "A One" and CL.db.pool.G2.awardedTo == "Iso Tope" and CL.db.pool.G3.awardedTo == "Iso Tope", "...each copy is recorded")
Run.Cancel()

-- the master looter sends an item to him
reset()
stock({ { id = 100, name = "Armor Piece" } })
CL.db.sessionAuto = false
DE.Designate("Iso Tope")
sentChat = {}
Run.Start()
roll("A One", 50)
waitItem()
check(Run.Can("de"), "when the rolls are closed the master looter can send the item to the disenchanter")
check(Run.GiveToDE() == true and sentHas("goes to Iso Tope to disenchant") and Run.State().phase == "between", "...and it goes")
check(Run.GiveToDE() == false, "(once)")
Run.Cancel()

-- changing an item afterwards
reset()
stock({ { id = 100, name = "Armor Piece" } })
DE.Designate("Iso Tope")
Run.Start()
roll("A One", 50)
waitItem()
local lot = Run.History()[1].lot
Run.Unassign(Run.AwardsFor(lot)[1])
sentChat, sentAddon = {}, {}
check(Run.AssignToDE(lot) == true and sentHas("goes to Iso Tope to disenchant"), "a free copy can be sent to the disenchanter afterwards")
check(Run.AwardsFor(lot)[1].de and CL.db.pool.G1.awardedTo == "Iso Tope", "...and is recorded as a disenchant")
check(Run.AssignToDE(lot) == false, "(no free copy left)")
Run.Cancel()
reset()
stock({ { id = 100, name = "Armor Piece" } })
Run.Start()
roll("A One", 50)
waitItem()
check(Run.AssignToDE(Run.History()[1].lot) == false, "nobody designated: nothing to send to")
Run.Cancel()

-- a test session changes nothing real, and he is not whispered when it is you
reset()
stock({ { id = 100, name = "Armor Piece" } })
DE.Designate("Hazas War")
sentChat = {}
Run.Start()
waitItem()
WOW.Advance(3.5)
Run.Finish()
WOW.Advance(2)
local self_whisper = false
for _, s in ipairs(sentChat) do if s.channel == "WHISPER" then self_whisper = true end end
check(not self_whisper and CL.db.pool.G1.awardedTo == "Hazas War", "if the master looter is the disenchanter himself nobody is whispered")

-- 8. The player's window
reset()
masterParty = 2
local function receive(sender, kind, ...)
    local parts = { kind }
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    WOW.FireEvent("CHAT_MSG_ADDON", "CLEANLOOT", table.concat(parts, "\t"), "RAID", sender)
end
receive("Teki La", "S", 1, "s1", 1, 15)
receive("Teki La", "I", "s1", 1, 1, 1, link(100, "Armor Piece", "1"), 15)
receive("Teki La", "W", "s1", 1, "Iso Tope", "", "DE")
local pwin = PW.Window()
check(pwin.status:GetText():find("Iso Tope will disenchant it", 1, true), "another player sees who will disenchant it (" .. tostring(pwin.status:GetText()) .. ")")
receive("Teki La", "W", "s1", 1, "Hazas War", "", "DE")
check(pwin.status:GetText():find("You are to disenchant it", 1, true), "the disenchanter himself is told to come and trade")
PW.Reset()

-- 9. The options
local W = CL.Options.widgets
check(CL.Options.pages.de and W.deOpen and W.deKeyword and W.deKeep and W.sessionDEAuto, "the options have a Disenchanter tab")
rawset(W.deKeyword, "HasFocus", function() return false end)
CL.Options.Open("de")
check(CL.Options.CurrentPage() == "de", "it opens on that tab")
W.deKeyword:SetText("dez")
W.deKeyword.__scripts.OnEditFocusLost(W.deKeyword)
check(CL.db.deKeyword == "dez" and DE.Keyword() == "dez", "the word is saved")
W.deKeyword:SetText("  ")
W.deKeyword.__scripts.OnEditFocusLost(W.deKeyword)
check(CL.db.deKeyword == "de", "an empty word goes back to the default")
W.deKeep:SetChecked(true)
W.deKeep.__scripts.OnClick(W.deKeep)
check(CL.db.deKeep == true, "the keep-the-materials option is saved")
CL.db.deKeep = false
CL.Disenchant.Designate("Teki La")
CL.Options.Refresh()
check(W.deCurrent:GetText():find("Teki La", 1, true), "the tab shows who is designated")
W.deOpen.__scripts.OnClick(W.deOpen)
check(DE.window:IsShown(), "its button opens the window")

print = realPrint
io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
