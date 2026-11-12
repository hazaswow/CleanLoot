-- Auto-roll scenarios against the stub client. Run with lua tools/test_autoroll.lua.
local WOW = dofile("tools/wowenv.lua")
local CL, RF, AR = WOW.CL, WOW.CL.RollFrames, WOW.CL.AutoRoll
local N, G, P = CL.ROLL.NEED, CL.ROLL.GREED, CL.ROLL.PASS
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1 io.write("FAIL: " .. label .. "\n") end
end

-- what the client says about each roll
local INFO = {}
local function roll(rollID, item)
    INFO[rollID] = {
        id = item.id or 12345, name = item.name or "Real Item", quality = item.quality or 4,
        bop = item.bop or false, canNeed = item.canNeed ~= false, canGreed = item.canGreed ~= false,
    }
    WOW.FireEvent("START_LOOT_ROLL", rollID, 20000)
end
function GetLootRollItemInfo(rollID)
    local i = INFO[rollID]
    if not i then return nil end
    return 135000, i.name, 1, i.quality, i.bop, i.canNeed, i.canGreed, false, nil, nil
end
function GetLootRollItemLink(rollID)
    local i = INFO[rollID]
    return i and ("|cffa335ee|Hitem:%d::::::::|h[%s]|h|r"):format(i.id, i.name) or nil
end
local rolled = {}
local refuse = false
function RollOnLoot(rollID, rollType)
    if refuse then error("client rejected call") end
    rolled[#rolled + 1] = { rollID, rollType }
end
local said = {}
local realPrint = print
print = function(...) said[#said + 1] = table.concat({ ... }, " ") end
local function sayMatches(p)
    for _, line in ipairs(said) do if line:find(p, 1, true) then return true end end
    return false
end
local function reset()
    rolled, said = {}, {}
    refuse = false
    CL.db.autoItems, CL.db.autoQuality = {}, {}
    CL.db.autoRollEnabled, CL.db.autoRollSay, CL.db.autoConfirm = true, true, false
    CL.RollFrames.StopAll()
end

-- 1. Nothing changes until a rule exists
check(CL.db.autoRollEnabled == true and CL.db.autoRollSay == true, "auto-roll defaults: on, with a chat line")
check(next(CL.db.autoItems or {}) == nil and next(CL.db.autoQuality or {}) == nil, "no rule exists by default")
roll(1001, {})
check(RF.GetFrame(1001) and #rolled == 0, "without a rule the roll shows its frame as before")
reset()

-- 2. An item rule answers, no frame, one chat line
AR.SetItem(12345, N, "Real Item")
roll(1002, { canNeed = true })
check(#rolled == 1 and rolled[1][1] == 1002 and rolled[1][2] == N, "an item rule rolls Need on the real RollOnLoot")
check(RF.GetFrame(1002) == nil and RF.ActiveCount() == 0, "...and shows no frame")
check(sayMatches("auto-rolled Need"), "...with a chat line")
reset()

-- 3. The chat line can be switched off
AR.SetItem(12345, G, "Real Item")
CL.db.autoRollSay = false
roll(1003, {})
check(#rolled == 1 and rolled[1][2] == G and #said == 0, "autoRollSay off: it still rolls, silently")
reset()

-- 4. The answer is not available: the roll stays yours
AR.SetItem(12345, N, "Real Item")
roll(1004, { canNeed = false })
check(#rolled == 0 and RF.GetFrame(1004), "Need unavailable: nothing sent, the frame opens")
check(sayMatches("not auto-rolled"), "...and says why")
reset()
AR.SetItem(12345, G, "Real Item")
roll(1005, { canGreed = false })
check(#rolled == 0 and RF.GetFrame(1005), "Greed unavailable: the frame opens")
reset()

-- 5. Bind-on-pickup: the confirmation is yours unless auto-accept is on
AR.SetItem(12345, G, "Real Item")
roll(1006, { bop = true })
check(#rolled == 0 and RF.GetFrame(1006), "bind-on-pickup Greed, auto-accept off: the frame opens, nothing sent")
RF.Stop(1006)
CL.db.autoConfirm = true
roll(1007, { bop = true })
check(#rolled == 1 and rolled[1][2] == G and RF.GetFrame(1007) == nil, "bind-on-pickup Greed, auto-accept on: it rolls")
reset()
AR.SetItem(12345, P, "Real Item")
roll(1008, { bop = true })
check(#rolled == 1 and rolled[1][2] == P, "Pass never needs the confirmation: it rolls even when bind-on-pickup")
reset()

-- 6. By quality: green and above only, the item rule wins
check(AR.SetQuality(1, G) == false and AR.SetQuality(0, G) == false, "no rule for white or grey")
check(AR.SetQuality(3, G) == true and AR.QualityRule(3) == G, "a rule for blue")
roll(1009, { id = 777, quality = 3 })
check(#rolled == 1 and rolled[1][2] == G and RF.GetFrame(1009) == nil, "the quality rule rolls Greed on a blue")
roll(1010, { id = 778, quality = 2 })
check(#rolled == 1 and RF.GetFrame(1010), "a green has no rule: its frame opens")
AR.SetItem(777, P, "Seven")
roll(1011, { id = 777, quality = 3 })
check(#rolled == 2 and rolled[2][2] == P, "the item rule (Pass) wins over the quality rule (Greed)")
AR.SetQuality(3, nil)
check(AR.QualityRule(3) == nil, "a quality rule can be switched off")
reset()

-- 7. The master switch
AR.SetItem(12345, G, "Real Item")
CL.db.autoRollEnabled = false
roll(1012, {})
check(#rolled == 0 and RF.GetFrame(1012), "auto-roll off: rules do nothing")
reset()

-- 8. The game refuses the answer: the frame opens
AR.SetItem(12345, G, "Real Item")
refuse = true
roll(1013, {})
check(RF.GetFrame(1013), "RollOnLoot failing leaves the frame to the player")
reset()

-- 9. Right-click on a button: remember and answer; again: forget
roll(1014, {})
local f = RF.GetFrame(1014)
local greed = f.buttons[G]
greed.__scripts.OnMouseDown(greed)
greed.__scripts.OnClick(greed, "RightButton")
check(AR.ItemRule(12345) and AR.ItemRule(12345).roll == G, "right-click Greed remembers Greed for the item")
check(#rolled == 1 and rolled[1][2] == G and RF.GetFrame(1014) == nil, "...and answers the roll now")
check(sayMatches("always Greed"), "...and says so")
-- a later roll of that item with a rule that cannot fire: the button shows it
roll(1015, { bop = true })
f = RF.GetFrame(1015)
check(f and f.buttons[G].auto == true and not f.buttons[N].auto, "the rule's button is marked on the frame")
GameTooltip.lines = {}
greed = f.buttons[G]
greed.__scripts.OnEnter(greed)
local hint = false
for _, l in ipairs(GameTooltip.lines) do if tostring(l):find("Auto: always Greed", 1, true) then hint = true end end
check(hint, "...and its tooltip tells the rule")
greed.__scripts.OnMouseDown(greed)
greed.__scripts.OnClick(greed, "RightButton")
check(AR.ItemRule(12345) == nil and #rolled == 1, "right-click on the rule's button forgets it, without rolling")
check(f.buttons[G].auto == false, "...and the mark goes away")
reset()

-- 10. Right-click on an unavailable button does nothing
roll(1016, { canNeed = false })
f = RF.GetFrame(1016)
local needBtn = f.buttons[N]
needBtn.__scripts.OnMouseDown(needBtn)
needBtn.__scripts.OnClick(needBtn, "RightButton")
check(AR.ItemRule(12345) == nil and #rolled == 0, "right-click on a greyed-out button remembers nothing")
reset()

-- 11. Left clicks are untouched
roll(1017, {})
f = RF.GetFrame(1017)
greed = f.buttons[G]
greed.__scripts.OnMouseDown(greed)
greed.__scripts.OnClick(greed, "LeftButton")
check(#rolled == 1 and AR.ItemRule(12345) == nil and RF.GetFrame(1017) == nil, "a left click answers and remembers nothing")
reset()

-- 12. Commands
SlashCmdList.CLEANLOOT("auto need |cffa335ee|Hitem:999::::::::|h[Some Idol]|h|r")
check(AR.ItemRule(999) and AR.ItemRule(999).roll == N and AR.ItemRule(999).name == "Some Idol",
    "/cll auto need [link] adds a rule, name from the link, case kept")
SlashCmdList.CLEANLOOT("auto greed 1000")
check(AR.ItemRule(1000) and AR.ItemRule(1000).roll == G, "/cll auto greed <id> works with a bare id")
SlashCmdList.CLEANLOOT("auto pass item:1001")
check(AR.ItemRule(1001) and AR.ItemRule(1001).roll == P, "/cll auto pass item:<id> works too")
said = {}
SlashCmdList.CLEANLOOT("auto list")
check(sayMatches("Some Idol") and sayMatches("always Greed"), "/cll auto list shows the rules")
SlashCmdList.CLEANLOOT("auto remove |Hitem:999|h[Some Idol]|h")
check(AR.ItemRule(999) == nil, "/cll auto remove [link] forgets the rule")
said = {}
SlashCmdList.CLEANLOOT("auto need")
check(AR.ItemRule(0) == nil and sayMatches("give an item"), "/cll auto need without an item says what is missing")
WOW.openedCategory = nil
check(pcall(SlashCmdList.CLEANLOOT, "auto") and WOW.openedCategory == WOW.subcategories["Auto-roll"].ID,
    "/cll auto opens the auto-roll page")
reset()

-- 13. The options page
local W = CL.Options.widgets
check(W.autoRollOpen and W.autoOn and W.autoSay and W.autoList and W.autoBox, "the auto-roll page and its button exist")
check(CL.Options.autoRollCategory ~= nil and WOW.subcategories["Auto-roll"].parent == WOW.category,
    "the page is registered under CleanLoot")
WOW.openedCategory = nil
W.autoRollOpen.__scripts.OnClick(W.autoRollOpen)
check(WOW.openedCategory == WOW.subcategories["Auto-roll"].ID, "the button on the main page opens it")
AR.SetItem(500, N, "Alpha")
AR.SetItem(501, G, "Beta")
CL.Options.Refresh()
check(W.autoOn:GetChecked() and W.autoSay:GetChecked(), "the switches show their saved values")
check(W.autoQ3_1:GetChecked() and not W.autoQ3_2:GetChecked(), "quality rows start on Off")
W.autoQ3_2:SetChecked(true)
W.autoQ3_2.__scripts.OnClick(W.autoQ3_2)
check(AR.QualityRule(3) == N and W.autoQ3_2:GetChecked() and not W.autoQ3_1:GetChecked(), "ticking Need on blue sets the rule, exclusively")
check(W.autoQ1_1 == nil and W.autoQ2_1 ~= nil and W.autoQ5_4 ~= nil, "rows are green to legendary only")
W.autoQ3_1:SetChecked(true)
W.autoQ3_1.__scripts.OnClick(W.autoQ3_1)
check(AR.QualityRule(3) == nil, "ticking Off clears it")

W.autoBox:SetText("|cffa335ee|Hitem:600::::::::|h[Gamma]|h|r")
W.autoAddNeed.__scripts.OnClick(W.autoAddNeed)
check(AR.ItemRule(600) and AR.ItemRule(600).roll == N and AR.ItemRule(600).name == "Gamma", "Add Need takes a pasted link")
check(W.autoBox:GetText() == "", "...and empties the box")
W.autoBox:SetText("601")
W.autoAddPass.__scripts.OnClick(W.autoAddPass)
check(AR.ItemRule(601) and AR.ItemRule(601).roll == P, "Add Pass takes a bare id")
W.autoBox:SetText("not an item")
said = {}
W.autoAddGreed.__scripts.OnClick(W.autoAddGreed)
check(sayMatches("paste an item link") and AR.ItemRule(0) == nil, "bad input adds nothing and says so")
local names = {}
for _, r in ipairs(AR.List()) do names[#names + 1] = r.name end
check(table.concat(names, ",") == "Alpha,Beta,Gamma,item 601", "the list is sorted by name (got " .. table.concat(names, ",") .. ")")
check(AR.NextRoll(N) == G and AR.NextRoll(G) == P and AR.NextRoll(P) == N, "an answer cycles Need > Greed > Pass > Need")

-- 14. A simulated drop is auto-answered like a real one, and its result still lands
reset()
CL.db.autoConfirm = true
for q = 2, 5 do AR.SetQuality(q, G) end
-- three items of known quality (the simulator's random drops include white ones, which never roll)
for _, itemID in ipairs({ 2589, 4306, 118 }) do CL.Sim.StartItem(itemID) end
check(RF.ActiveCount() == 0, "simulated drops with quality rules open no frame")
local waiting = CL.Sim.Waiting()
local mine = 0
for _, w in ipairs(waiting) do
    local self = false
    for _, p in ipairs(w.pending) do if p.isSelf then self = true end end
    if not self then mine = mine + 1 end
end
check(#waiting == 3 and mine == 3, "...and you are no longer waited for on any of them")
WOW.Advance(45)
check(CL.Sim.ActiveCount() == 0, "...they finish normally")
CL.Sim.Clear()

print = realPrint
io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
