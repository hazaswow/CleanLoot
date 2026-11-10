-- Keyboard roll scenarios against the stub client. Run with lua tools/test_keyboard.lua.
local WOW = dofile("tools/wowenv.lua")
local CL, RF = WOW.CL, WOW.CL.RollFrames
local K = CL.Keyboard
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1 io.write("FAIL: " .. label .. "\n") end
end

local function info(bop, canNeed, canGreed)
    return { name = "Test Item", texture = 123, quality = 3, count = 1, bop = bop,
        canNeed = canNeed ~= false, canGreed = canGreed ~= false, reasonNeed = 3 }
end
local function start(id, item)
    return RF.Start(id, item or info(), "|Hitem:123|h[Test Item]|h", 60000)
end
local rolls = {}
function RollOnLoot(id, kind) rolls[#rolls + 1] = { id, kind } end
function StaticPopup_FindVisible(which) return which == "CONFIRM_LOOT_ROLL" and WOW.lootPopup or nil end
WOW.bindings = { CLEANLOOT_NEED = "1", CLEANLOOT_GREED = "SHIFT-2", CLEANLOOT_PASS = "ALT-3" }
function GetBindingKey(action) return WOW.bindings[action] end
function GetBindingText(key) return "key:" .. key end
LOOT_ROLL_INELIGIBLE_REASON3 = "Cannot Need this."

check(CL.db.keyboardEnabled == false and CL.db.keyboardInspect == false, "keyboard and inspection default off")
local a, b = start(1001), start(1002)
check(rawget(_G, "CleanLootInspectionToggle") == nil, "disabled keyboard rolls do not show an inspection button")
SlashCmdList.CLEANLOOT("need")
check(K.SelectedID() == nil and #rolls == 0 and not a.selection:IsShown(), "disabled commands do not select or roll")
check(not a.buttons[CL.ROLL.NEED].binding:IsShown(), "bindings are hidden when keyboard rolls are disabled")
local W = CL.Options.widgets
check(W.keyboard and W.inspect and W.inspectLeft and W.inspectRight, "keyboard settings exist (inspection is a checkbox)")
check(not W.inspect:IsEnabled() and not W.inspectLeft:IsEnabled() and not W.inspectRight:IsEnabled(),
    "the inspection options are greyed out while keyboard rolls are off")
W.keyboard:SetChecked(true)
W.keyboard.__scripts.OnClick(W.keyboard)
check(CL.db.keyboardEnabled and K.SelectedID() == nil, "enabling with inspection off leaves the stack unchanged")
check(W.inspect:IsEnabled() and W.inspectLeft:IsEnabled() and W.inspectRight:IsEnabled(),
    "...and the inspection options come alive")
check(rawget(_G, "CleanLootInspectionToggle") == nil, "no inspection button is ever added to the roll stack")
W.inspect:SetChecked(true)
W.inspect.__scripts.OnClick(W.inspect)
check(CL.db.keyboardInspect and K.SelectedID() == 1001 and CleanLootInspectionTooltip:IsShown(),
    "ticking the inspection checkbox enables it and selects the oldest item")
W.inspect:SetChecked(false)
W.inspect.__scripts.OnClick(W.inspect)
check(not CL.db.keyboardInspect and not CleanLootInspectionTooltip:IsShown() and K.SelectedID() == 1001,
    "unticking it disables inspection without clearing selection")
CL.db.growDirection = "UP"
RF.Layout()
W.inspectLeft.__scripts.OnClick(W.inspectLeft)
check(CL.db.keyboardInspectSide == "LEFT", "the side can be set while the tooltip is hidden")
W.inspectRight.__scripts.OnClick(W.inspectRight)
CL.db.growDirection = "DOWN"
RF.Layout()
K.SetEnabled(false)
check(not W.inspect:IsEnabled(), "turning keyboard rolls off greys the inspection options out again")
K.SetEnabled(true)

SlashCmdList.CLEANLOOT("need")
check(K.SelectedID() == 1001 and #rolls == 0 and a.selection:IsShown(), "first roll action selects oldest without rolling")
check(a.buttons[CL.ROLL.NEED].binding:IsShown() and a.buttons[CL.ROLL.NEED].binding:GetText() == "key:1"
    and a.buttons[CL.ROLL.GREED].binding:GetText() == "key:SHIFT-2"
    and a.buttons[CL.ROLL.PASS].binding:GetText() == "key:ALT-3", "selected roll shows the formatted roll bindings")
check((a.buttons[CL.ROLL.NEED].label:GetPoint()) == "TOP", "binding hints leave room for the button label")
check(not b.buttons[CL.ROLL.NEED].binding:IsShown(), "unselected rolls do not show bindings")
SlashCmdList.CLEANLOOT("next")
check(K.SelectedID() == 1002 and not a.selection:IsShown() and b.selection:IsShown(), "next selects the next item")
check(not a.buttons[CL.ROLL.NEED].binding:IsShown() and b.buttons[CL.ROLL.NEED].binding:IsShown(),
    "binding hints follow selection")
WOW.bindings.CLEANLOOT_NEED = "CTRL-4"
WOW.FireEvent("UPDATE_BINDINGS")
check(b.buttons[CL.ROLL.NEED].binding:GetText() == "key:CTRL-4", "changed bindings update immediately")
WOW.bindings.CLEANLOOT_NEED = nil
WOW.FireEvent("UPDATE_BINDINGS")
check(not b.buttons[CL.ROLL.NEED].binding:IsShown(), "unbound actions do not show a hint")
WOW.bindings.CLEANLOOT_NEED = "1"
WOW.FireEvent("UPDATE_BINDINGS")
local formatBinding = GetBindingText
GetBindingText = nil
WOW.FireEvent("UPDATE_BINDINGS")
check(b.buttons[CL.ROLL.NEED].binding:GetText() == "1", "raw key is shown when binding text formatting is unavailable")
GetBindingText = formatBinding
WOW.bindings.CLEANLOOT_GREED = "CTRL-SHIFT-LONGKEY"
WOW.FireEvent("UPDATE_BINDINGS")
local _, bindingSize = b.buttons[CL.ROLL.GREED].binding:GetFont()
check(bindingSize < 9 and bindingSize >= 6 and b.buttons[CL.ROLL.GREED].binding:GetWidth() == 48,
    "long bindings are reduced to fit beside vote counters")
WOW.bindings.CLEANLOOT_GREED = "SHIFT-2"
WOW.FireEvent("UPDATE_BINDINGS")
SlashCmdList.CLEANLOOT("next")
check(K.SelectedID() == 1001, "next wraps")
CleanLootKeyboardAction("previous")
check(K.SelectedID() == 1002, "previous binding wraps")
local c = start(1003)
check(K.SelectedID() == 1002 and b.selection:IsShown(), "new item does not steal selection")
RF.Stop(1001)
check(K.SelectedID() == 1002, "removing an earlier item preserves selection")
RF.Stop(1002)
check(K.SelectedID() == 1003 and c.selection:IsShown(), "selected removal advances to the following item")

SlashCmdList.CLEANLOOT("inspect")
local tip = CleanLootInspectionTooltip
check(CL.db.keyboardInspect and tip and tip:IsShown() and tip.link == c.link, "inspect shows a separate tooltip for the selection")
check(W.inspect:GetChecked(), "the Inspect command ticks the checkbox in the options")
check(tip ~= GameTooltip, "inspection uses a separate tooltip")
check(not table.concat(tip.lines, " "):find("Need", 1, true)
    and not table.concat(tip.lines, " "):find("Greed", 1, true)
    and not table.concat(tip.lines, " "):find("Pass", 1, true), "inspection omits roll choices")
GameTooltip:SetOwner(c.icon, "ANCHOR_RIGHT")
GameTooltip:SetText("Mouseover")
GameTooltip:Show()
GameTooltip:Hide()
check(tip:IsShown() and tip.link == c.link, "mouseover does not replace or hide inspection")
local pawnCalls = {}
function PawnUpdateTooltip(name, method, link)
    pawnCalls[#pawnCalls + 1] = { name, method, link }
    _G[name]:AddLine("Pawn upgrade")
end
SlashCmdList.CLEANLOOT("next")
check(#pawnCalls == 1 and pawnCalls[1][1] == "CleanLootInspectionTooltip"
    and pawnCalls[1][2] == "SetHyperlink" and pawnCalls[1][3] == c.link,
    "Pawn receives the inspection tooltip and selected item link")
check(table.concat(tip.lines, " "):find("Pawn upgrade", 1, true), "Pawn can add upgrade information to inspection")
SlashCmdList.CLEANLOOT("next")
local pawnLines = 0
for _, line in ipairs(tip.lines) do if line == "Pawn upgrade" then pawnLines = pawnLines + 1 end end
check(#pawnCalls == 2 and pawnLines == 1, "refreshing inspection does not duplicate Pawn lines")
PawnUpdateTooltip = function() error("Pawn unavailable") end
SlashCmdList.CLEANLOOT("next")
check(K.SelectedID() == 1003 and tip:IsShown() and tip.link == c.link,
    "Pawn errors leave inspection usable")
PawnUpdateTooltip = nil
CL.Options.widgets.inspectLeft.__scripts.OnClick(CL.Options.widgets.inspectLeft)
check(CL.db.keyboardInspectSide == "LEFT" and (tip:GetPoint()) == "TOPRIGHT", "inspection side can be set to left")
CL.Options.widgets.inspectRight.__scripts.OnClick(CL.Options.widgets.inspectRight)
check(CL.db.keyboardInspectSide == "RIGHT" and (tip:GetPoint()) == "TOPLEFT", "inspection side can be set to right")
RF.Stop(1003)
check(K.SelectedID() == nil and not tip:IsShown() and CL.db.keyboardInspect,
    "empty stack hides inspection without changing the option")
local d = start(1004, info(false, false))
check(K.SelectedID() == 1004 and tip:IsShown() and d.selection:IsShown(), "enabled inspection returns with the next item")
check(not d.buttons[CL.ROLL.NEED].binding:IsShown() and d.buttons[CL.ROLL.GREED].binding:IsShown(),
    "unavailable roll choices have no key hint")
WOW.chat = {}
SlashCmdList.CLEANLOOT("need")
check(#rolls == 0 and RF.GetFrame(1004) == d and K.SelectedID() == 1004
    and table.concat(WOW.chat, " "):find("Cannot Need this.", 1, true),
    "unavailable choice explains the reason and leaves selection intact")

local realRoll = CL.API.Roll
CL.API.Roll = function() return false end
WOW.chat = {}
SlashCmdList.CLEANLOOT("greed")
check(RF.GetFrame(1004) == d and K.SelectedID() == 1004 and #WOW.chat > 0, "an explicit roll failure reports and keeps the item selected")
CL.API.Roll = realRoll
SlashCmdList.CLEANLOOT("greed")
check(#rolls == 1 and rolls[1][1] == 1004 and rolls[1][2] == CL.ROLL.GREED and not RF.GetFrame(1004), "successful Greed rolls and closes the selected item")
check(CL.db.keyboardInspect and not tip:IsShown(), "inspection remains enabled after the last roll")

local bop = start(1005, info(true))
start(1006)
WOW.lootPopup = true
SlashCmdList.CLEANLOOT("need")
check(#rolls == 1 and RF.GetFrame(1005) == bop, "an open loot confirmation blocks roll commands")
WOW.lootPopup = false
local popupFinder = StaticPopup_FindVisible
StaticPopup_FindVisible = false
StaticPopup1 = CreateFrame("Frame", "StaticPopup1", UIParent)
StaticPopup1.which = "CONFIRM_LOOT_ROLL"
StaticPopup1:Show()
SlashCmdList.CLEANLOOT("need")
check(#rolls == 1 and RF.GetFrame(1005) == bop, "visible loot confirmation is detected without the finder API")
StaticPopup1:Hide()
StaticPopup_FindVisible = popupFinder
SlashCmdList.CLEANLOOT("need")
check(#rolls == 2 and RF.GetFrame(1005) == bop and K.SelectedID() == 1005, "bind-on-pickup Need stays selected pending confirmation")
WOW.lootPopup = true
SlashCmdList.CLEANLOOT("next")
SlashCmdList.CLEANLOOT("pass")
check(#rolls == 2 and K.SelectedID() == 1006, "confirmation blocks rolling even after navigating")
WOW.lootPopup = false
SlashCmdList.CLEANLOOT("previous")
check(K.SelectedID() == 1005 and RF.GetFrame(1005), "declining confirmation leaves the original roll available")
SlashCmdList.CLEANLOOT("need")
WOW.FireEvent("CANCEL_LOOT_ROLL", 1005)
check(K.SelectedID() == 1006 and RF.GetFrame(1005) == nil, "resolved confirmation advances on the client cancellation event")
RF.StopAll()

start(1007, info(true))
SlashCmdList.CLEANLOOT("pass")
check(RF.GetFrame(1007) == nil, "passing on a bind-on-pickup item needs no confirmation")
local fake = CL.Sim.Start(1)[1]
CL.Sim.GetRoll(fake).info.bop = true
RF.GetFrame(fake).bop = true
SlashCmdList.CLEANLOOT("greed")
check(RF.GetFrame(fake) == nil, "simulated bind-on-pickup rolls do not wait for a real confirmation")
CL.Sim.Clear()

for id = 1101, 1109 do start(id) end
check(RF.ActiveCount() == 8 and RF.QueuedCount() == 1 and K.SelectedID() == 1101, "inspection selects from visible rolls only")
for i = 1, 8 do SlashCmdList.CLEANLOOT("next") end
check(K.SelectedID() == 1101, "cycling does not select the hidden queue")
local reused = RF.GetFrame(1101)
RF.Stop(1101)
check(RF.GetFrame(1109) == reused and K.SelectedID() == 1102, "frame reuse promotes the queue without selecting the wrong item")
RF.Stop(1102)
check(K.SelectedID() == 1103, "selection continues in queue order")
K.SetEnabled(false)
check(K.SelectedID() == nil and not tip:IsShown() and CL.db.keyboardInspect,
    "disabling clears selection but remembers inspection")
check(not RF.GetFrame(1103).buttons[CL.ROLL.NEED].binding:IsShown()
    and (RF.GetFrame(1103).buttons[CL.ROLL.NEED].label:GetPoint()) == "CENTER", "disabling restores the plain button layout")
K.SetEnabled(true)
check(K.SelectedID() == 1103 and tip:IsShown(), "re-enabling restores inspection and selection")
SlashCmdList.CLEANLOOT("inspect")
check(not tip:IsShown() and not CL.db.keyboardInspect and K.SelectedID() == 1103, "inspect toggle hides the area but preserves selection")
RF.StopAll()

local noLink = RF.Start(1201, info(), nil, 60000)
local missingLinkCalls = 0
PawnUpdateTooltip = function() missingLinkCalls = missingLinkCalls + 1 end
SlashCmdList.CLEANLOOT("inspect")
check(K.SelectedID() == 1201 and tip:IsShown() and tip.lines[1] == "Test Item", "inspection falls back to the item name without a link")
check(missingLinkCalls == 0, "Pawn is not called without an item link")
PawnUpdateTooltip = nil
RollOnLoot = function() error("client rejected call") end
WOW.chat = {}
SlashCmdList.CLEANLOOT("need")
check(RF.GetFrame(1201) == noLink and K.SelectedID() == 1201 and #WOW.chat > 0, "client API errors are reported without removing the roll")
RollOnLoot = function(id) WOW.FireEvent("CANCEL_LOOT_ROLL", id) end
start(1202)
SlashCmdList.CLEANLOOT("pass")
check(RF.GetFrame(1201) == nil and K.SelectedID() == 1202, "synchronous cancellation cannot close the next selected roll")
WOW.Advance(63)
check(RF.GetFrame(1202) == nil and K.SelectedID() == nil and not tip:IsShown() and CL.db.keyboardInspect,
    "timer expiry clears selection while preserving the inspection toggle")

-- Answering by mouse and by key is the same: a bind-on-pickup roll keeps its frame
RF.StopAll()
RollOnLoot = function(id, kind) rolls[#rolls + 1] = { id, kind } end
local function clickButton(f, rollType)
    local btn = f.buttons[rollType]
    btn.__scripts.OnMouseDown(btn)
    btn.__scripts.OnClick(btn, "LeftButton")
end
CL.db.autoConfirm = false
local m1 = start(1301, info(true))
local before = #rolls
clickButton(m1, CL.ROLL.NEED)
check(#rolls == before + 1 and rolls[#rolls][1] == 1301 and RF.GetFrame(1301) == m1,
    "a click on Need for a bind-on-pickup item keeps the frame (the game asks to confirm)")
clickButton(m1, CL.ROLL.PASS)
check(RF.GetFrame(1301) == nil, "...and Pass on it closes it at once (no confirmation)")
local m2 = start(1302, info(true))
clickButton(m2, CL.ROLL.GREED)
check(RF.GetFrame(1302) == m2, "Greed on a bind-on-pickup item waits as well")
WOW.FireEvent("CANCEL_LOOT_ROLL", 1302)
check(RF.GetFrame(1302) == nil, "...until the game closes the roll (the prompt was accepted)")
local m3 = start(1303, info(false))
clickButton(m3, CL.ROLL.NEED)
check(RF.GetFrame(1303) == nil, "an ordinary item closes at once, as always")
CL.db.autoConfirm = true
local m4 = start(1304, info(true))
clickButton(m4, CL.ROLL.NEED)
check(RF.GetFrame(1304) == nil, "with auto-accept on, a bind-on-pickup roll closes at once too")
CL.db.autoConfirm = false

-- The game's confirmation prompt: left alone by default, answered only on request
local confirmed, hidden = {}, {}
function ConfirmLootRoll(id, kind) confirmed[#confirmed + 1] = { id, kind } end
function StaticPopup_Hide(which) hidden[#hidden + 1] = which end
WOW.FireEvent("CONFIRM_LOOT_ROLL", 1301, CL.ROLL.NEED, 1)
check(#confirmed == 0 and #hidden == 0, "by default CleanLoot leaves the confirmation prompt to the player")
CL.db.autoConfirm = true
WOW.FireEvent("CONFIRM_LOOT_ROLL", 1301, CL.ROLL.NEED, 1)
check(#confirmed == 1 and confirmed[1][1] == 1301 and confirmed[1][2] == CL.ROLL.NEED and hidden[1] == "CONFIRM_LOOT_ROLL",
    "with auto-accept on the prompt is answered and closed")
CL.db.autoConfirm = false
check(CL.Options.widgets.autoConfirm ~= nil, "the options panel has the auto-accept checkbox")
local ac = CL.Options.widgets.autoConfirm
ac:SetChecked(true)
ac.__scripts.OnClick(ac)
check(CL.db.autoConfirm == true, "ticking it turns auto-accept on")
ac:SetChecked(false)
ac.__scripts.OnClick(ac)
check(CL.db.autoConfirm == false, "...and unticking turns it off")

-- Keys set from the options panel
local bindingSaves = 0
function IsControlKeyDown() return WOW.ctrl or false end
function IsAltKeyDown() return WOW.alt or false end
function GetCurrentBindingSet() return 1 end
function SaveBindings() bindingSaves = bindingSaves + 1 end
function GetBindingAction(key)
    for action, k in pairs(WOW.bindings) do if k == key then return action end end
    return ""
end
function SetBinding(key, action)
    for a, k in pairs(WOW.bindings) do if k == key then WOW.bindings[a] = nil end end
    if action then WOW.bindings[action] = key end
    return true
end
function GetBindingName(action) return "name of " .. action end
WOW.bindings = { CLEANLOOT_NEED = "1" }
local needKey, passKey = CL.Options.widgets.key1, CL.Options.widgets.key5
check(needKey and passKey and CL.Options.widgets.key6, "the options panel has a key field per action")
needKey.Sync()
passKey.Sync()
check(needKey:GetText() == "key:1" and passKey:GetText() == "Not bound", "a key field shows the key, or that it is not bound")
needKey.__scripts.OnClick(needKey, "LeftButton")
check(needKey:GetText() == "Press a key...", "clicking a key field waits for a key")
needKey.__scripts.OnKeyDown(needKey, "LSHIFT")
check(needKey:GetText() == "Press a key...", "a modifier alone does not count")
WOW.shift = true
needKey.__scripts.OnKeyDown(needKey, "F5")
WOW.shift = false
check(WOW.bindings.CLEANLOOT_NEED == "SHIFT-F5" and bindingSaves == 1 and needKey:GetText() == "key:SHIFT-F5",
    "a key with its modifiers is bound, saved and shown")
WOW.chat = {}
passKey.__scripts.OnClick(passKey, "LeftButton")
WOW.shift = true
passKey.__scripts.OnKeyDown(passKey, "F5")
WOW.shift = false
check(WOW.bindings.CLEANLOOT_PASS == "SHIFT-F5" and WOW.bindings.CLEANLOOT_NEED == nil
    and table.concat(WOW.chat, " "):find("was bound to", 1, true), "a key another action had is taken over, and it says so")
needKey.Sync()
check(needKey:GetText() == "Not bound", "...and the other field shows it lost its key")
passKey.__scripts.OnClick(passKey, "LeftButton")
passKey.__scripts.OnKeyDown(passKey, "ESCAPE")
check(WOW.bindings.CLEANLOOT_PASS == "SHIFT-F5" and passKey:GetText() == "key:SHIFT-F5", "Escape cancels without changing the key")
passKey.__scripts.OnClick(passKey, "RightButton")
check(WOW.bindings.CLEANLOOT_PASS == nil and passKey:GetText() == "Not bound", "right-click clears the key")
local savesBefore = bindingSaves
WOW.combat = true
needKey.__scripts.OnClick(needKey, "LeftButton")
needKey.__scripts.OnKeyDown(needKey, "F6")
WOW.combat = false
check(WOW.bindings.CLEANLOOT_NEED == nil and bindingSaves == savesBefore, "keys cannot be changed during combat")

-- The binding declarations: grouped by category, named for a search
local xml = assert(io.open("Bindings.xml", "rb")):read("a")
check(xml:find('category="CleanLoot"', 1, true) and not xml:find("header=", 1, true),
    "bindings are declared under the CleanLoot category, with no raw header")
local allNamed = true
for _, entry in ipairs(K.ACTIONS) do
    local name = rawget(_G, "BINDING_NAME_" .. entry.action)
    if type(name) ~= "string" or not name:find("CleanLoot", 1, true) or not xml:find(entry.action, 1, true) then allNamed = false end
end
check(allNamed, "every binding has a readable name that carries the addon name")

-- Waiting on rolls: the card at the start of the popup
RF.StopAll()
local R = CL.Results
CL.Sim.SetGroupSize(4)
CL.db.growDirection, CL.db.resultsDirection = "DOWN", nil
CL.Sim.Start(2)
local simIDs = {}
for id = 900001, 901000 do if RF.GetFrame(id) then simIDs[#simIDs + 1] = id end end
check(#simIDs == 2 and R.WaitingShown(), "the waiting card shows while players have not rolled")
local wc = R.WaitCard()
check(wc.line:GetText() == "4 players haven't rolled", "...counting each player once (" .. tostring(wc.line:GetText()) .. ")")
wc.__scripts.OnEnter(wc)
local waitTip = table.concat(GameTooltip.lines, "\n")
check(waitTip:find("Hasn't rolled yet (4)", 1, true) and waitTip:find("Aludra | 2/2", 1, true),
    "hovering lists them with how many of the rolls on screen they are undecided on")
CL.Sim.Vote(simIDs[1], "Aludra", CL.ROLL.NEED)
check(wc.line:GetText() == "4 players haven't rolled", "a player who rolled on one item is still waited for on the other")
CL.Sim.Vote(simIDs[2], "Aludra", CL.ROLL.GREED)
check(wc.line:GetText() == "3 players haven't rolled", "...and not any more once both are answered")
local card = R.Show({ name = "x", quality = 3, rolls = {}, passes = 0,
    winner = { name = "Z", class = "MAGE", type = CL.ROLL.GREED, value = 5 } }, true)
local cp = { card:GetPoint() }
check(cp[1] == "TOPLEFT" and cp[2] == wc and cp[3] == "BOTTOMLEFT", "result cards stack after the waiting card, going down")
CL.db.resultsDirection = "UP"
R.Layout()
cp = { card:GetPoint() }
local wp = { wc:GetPoint() }
check(wp[1] == "BOTTOMLEFT" and cp[1] == "BOTTOMLEFT" and cp[2] == wc and cp[3] == "TOPLEFT",
    "...and going up the waiting card stays first, at the bottom")
CL.db.resultsDirection = nil
R.Clear()
CL.db.showWaiting = false
R.RefreshWaiting()
check(not R.WaitingShown(), "the option turns the waiting card off")
CL.db.showWaiting = true
R.RefreshWaiting()
check(R.WaitingShown(), "...and back on")
local ww = CL.Options.widgets.waiting
check(ww ~= nil, "the options panel has the waiting checkbox")
ww:SetChecked(false)
ww.__scripts.OnClick(ww)
check(CL.db.showWaiting == false and not R.WaitingShown(), "unticking it hides the card")
ww:SetChecked(true)
ww.__scripts.OnClick(ww)
check(CL.db.showWaiting == true and R.WaitingShown(), "...and ticking shows it again")
for _, name in ipairs({ "Aludra", "Baric", "Cyndra", "Dorun" }) do
    for _, id in ipairs(simIDs) do CL.Sim.Vote(id, name, CL.ROLL.PASS) end
end
check(not R.WaitingShown(), "once everyone has rolled the card goes")
CL.Sim.Clear()
R.Clear()

io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
