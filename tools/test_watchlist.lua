-- Watchlist scenarios against the stub client. Run with lua tools/test_watchlist.lua.
local WOW = dofile("tools/wowenv.lua")
local CL, RF, WL = WOW.CL, WOW.CL.RollFrames, WOW.CL.Watchlist
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1 io.write("FAIL: " .. label .. "\n") end
end

-- what the client says about each roll
local INFO = {}
local function roll(rollID, item)
    INFO[rollID] = { id = item.id or 7001, name = item.name or "Real Item", quality = item.quality or 4 }
    WOW.FireEvent("START_LOOT_ROLL", rollID, 20000)
end
function GetLootRollItemInfo(rollID)
    local i = INFO[rollID]
    if not i then return nil end
    return 135000, i.name, 1, i.quality, false, true, true, false, nil, nil
end
function GetLootRollItemLink(rollID)
    local i = INFO[rollID]
    return i and ("|cffa335ee|Hitem:%d::::::::|h[%s]|h|r"):format(i.id, i.name) or nil
end
function RollOnLoot() end
local said = {}
local realPrint = print
print = function(...) said[#said + 1] = table.concat({ ... }, " ") end
local function sayMatches(p)
    for _, line in ipairs(said) do if line:find(p, 1, true) then return true end end
    return false
end
local function reset()
    said = {}
    CL.db.watchItems = {}
    CL.db.watchEnabled = true
    CL.db.autoItems, CL.db.autoQuality = {}, {}
    CL.RollFrames.StopAll()
    CL.Sim.Clear()
end
local function tooltipOf(f)
    GameTooltip:Hide()
    f.icon.__scripts.OnEnter(f.icon)
    return table.concat(GameTooltip.lines, "\n")
end

-- 1. Nothing changes until an item is watched
check(CL.db.watchEnabled == true, "the highlight is on by default")
check(next(CL.db.watchItems or {}) == nil, "nothing is watched by default")
roll(2001, {})
local f = RF.GetFrame(2001)
check(f and not f.watched and not f.watch:IsShown() and f:GetHeight() == 70, "an unwatched item looks as before")
check(not f.note:IsShown(), "...with no note line")
reset()

-- 2. A watched item: outline, no note, same height
WL.Add(7001, "Real Item")
roll(2002, {})
f = RF.GetFrame(2002)
check(f.watched and f.watch:IsShown(), "a watched item gets the outline")
check(f:GetHeight() == 70 and not f.note:IsShown(), "...at the usual height, with no note line")
check(tooltipOf(f):find("On your watchlist", 1, true), "the icon's tooltip says it is on the watchlist")
roll(2003, { id = 7002, name = "Other" })
local g = RF.GetFrame(2003)
check(g and not g.watched and not g.watch:IsShown(), "another item is not highlighted")
reset()

-- 3. A note shows on the frame, which grows by one line
WL.Add(7001, "Real Item", "BiS for my mage")
roll(2004, {})
f = RF.GetFrame(2004)
check(f.note:IsShown() and f.note:GetText() == "BiS for my mage", "the note shows on its own line")
check(f:GetHeight() == 84, "...and the frame is one line taller")
check(tooltipOf(f):find("Watchlist: BiS for my mage", 1, true), "the tooltip repeats the note")
reset()

-- 4. The outline pulses, gently
WL.Add(7001, "Real Item")
roll(2005, {})
f = RF.GetFrame(2005)
local lo, hi = 2, -1
for _ = 1, 140 do
    WOW.Advance(0.05)
    local a = f.watch:GetAlpha()
    if a < lo then lo = a end
    if a > hi then hi = a end
end
check(lo >= 0.39 and lo < 0.55, "the pulse dims to about 40% (lowest " .. ("%.2f"):format(lo) .. ")")
check(hi <= 1.0001 and hi > 0.95, "...and comes back to full (highest " .. ("%.2f"):format(hi) .. ")")
reset()

-- 5. The master switch
WL.Add(7001, "Real Item", "note")
CL.db.watchEnabled = false
roll(2006, {})
f = RF.GetFrame(2006)
check(not f.watched and not f.watch:IsShown() and not f.note:IsShown() and f:GetHeight() == 70,
    "switched off: no outline, no note")
CL.db.watchEnabled = true
RF.RefreshWatch()
check(f.watched and f.watch:IsShown() and f.note:IsShown(), "switched on again: the open frame lights up")
reset()

-- 6. Changes reach the frames that are open
roll(2007, {})
f = RF.GetFrame(2007)
check(not f.watched, "not watched yet")
WL.Add(7001, "Real Item", "now watched")
check(f.watched and f.note:GetText() == "now watched" and f:GetHeight() == 84, "adding the item lights the open frame")
WL.SetNote(7001, "changed")
check(f.note:GetText() == "changed", "editing the note updates it")
WL.SetNote(7001, "")
check(f.watched and not f.note:IsShown() and f:GetHeight() == 70, "an empty note drops the line, the outline stays")
WL.Remove(7001)
check(not f.watched and not f.watch:IsShown(), "removing the item clears the frame")
reset()

-- 7. A frame is clean when it is reused
WL.Add(7001, "Real Item", "note")
roll(2008, {})
f = RF.GetFrame(2008)
RF.Stop(2008)
check(not f.watched and not f.watch:IsShown(), "a closed frame forgets the highlight")
roll(2009, { id = 7002, name = "Other" })
check(RF.GetFrame(2009) == f and not f.watched and f:GetHeight() == 70 and not f.note:IsShown(),
    "...the next item in the same frame is not highlighted")
reset()

-- 8. Notes are kept short and plain
WL.Add(7001, "Real Item", "  a|cffff0000red|r note  ")
check(WL.Entry(7001).note == "a cffff0000red r note", "escape codes and edge spaces are removed (got '" .. WL.Entry(7001).note .. "')")
WL.SetNote(7001, string.rep("x", 200))
check(#WL.Entry(7001).note == WL.MAX_NOTE, "a long note is cut")
check(WL.Add(nil, "x") == false and WL.SetNote(99999, "n") == false and WL.Remove(99999) == false,
    "unknown items and missing ids are refused")
reset()

-- 9. Reading an item and its note from a pasted line
local word, text = WL.SplitItem("|cffa335ee|Hitem:999::::::::|h[Some Idol]|h|r for the guild bank")
check(WL.ItemID(word) == 999 and text == "for the guild bank", "a link then a note: the item and the note are split")
word, text = WL.SplitItem("1000")
check(WL.ItemID(word) == 1000 and text == "", "a bare id has no note")
word, text = WL.SplitItem("item:1001 reminder text")
check(WL.ItemID(word) == 1001 and text == "reminder text", "item:<id> then a note works too")
local link, note = WL.SplitItem("|cnIQ3:|Hitem:5::::::::|h[A Name With Spaces]|h|r and a note")
check(link:find("A Name With Spaces", 1, true) and note == "and a note", "SplitItem keeps a link with spaces whole")
reset()

-- 10. The options page
local W = CL.Options.widgets
check(W.watchOn and W.watchBox and W.watchNoteBox and W.watchAdd and W.watchList, "the watchlist page exists")
check(CL.Options.pages.watch and CL.Options.pages.watch.panel == CL.Options.watchPanel, "it is a tab of the options window")
CL.Options.Refresh()
check(W.watchOn:GetChecked(), "the switch shows its saved value")

W.watchBox:SetText("|cffa335ee|Hitem:600::::::::|h[Gamma]|h|r")
W.watchNoteBox:SetText("farm this")
W.watchAdd.__scripts.OnClick(W.watchAdd)
check(WL.Entry(600) and WL.Entry(600).name == "Gamma" and WL.Entry(600).note == "farm this", "Add takes a link and a note")
check(W.watchBox:GetText() == "" and W.watchNoteBox:GetText() == "", "...and empties both boxes")
W.watchBox:SetText("601")
W.watchAdd.__scripts.OnClick(W.watchAdd)
check(WL.Entry(601) and WL.Entry(601).note == "", "Add takes a bare id, no note")
W.watchBox:SetText("600")
W.watchAdd.__scripts.OnClick(W.watchAdd)
check(WL.Entry(600).note == "farm this", "adding an item again with no note keeps its note")
check(WL.Entry(600).name == "Gamma", "...and its name (a bare id does not turn it into a placeholder)")
W.watchBox:SetText("not an item")
said = {}
W.watchAdd.__scripts.OnClick(W.watchAdd)
check(sayMatches("paste an item link") and WL.Entry(0) == nil, "bad input adds nothing and says so")

local names = {}
for _, e in ipairs(WL.List()) do names[#names + 1] = e.name end
check(table.concat(names, ",") == "Gamma,item 601", "the list is sorted by name (got " .. table.concat(names, ",") .. ")")
CL.Options.Refresh()
-- the first row is Gamma: its note box edits the note when it loses the focus
local list = W.watchList
local rows = {}
for _, child in ipairs({ list:GetChildren() }) do rows[#rows + 1] = child end
-- rows are plain tables inside the closure: reach them through the widgets they created
local noteBoxes, removeButtons = {}, {}
for _, frame in ipairs(WOW.frames) do
    if frame:GetParent() == list and frame.__scripts.OnEditFocusLost then noteBoxes[#noteBoxes + 1] = frame end
    if frame:GetParent() == list and frame.GetText and frame:GetText() == "X" then removeButtons[#removeButtons + 1] = frame end
end
check(#noteBoxes == 10 and #removeButtons == 10, "the list has ten rows, each with a note box and a remove button")
check(noteBoxes[1]:GetText() == "farm this", "the first row shows its item's note")
noteBoxes[1]:SetText("changed in the list")
noteBoxes[1].__scripts.OnEditFocusLost(noteBoxes[1])
check(WL.Entry(600).note == "changed in the list", "leaving a note box saves what was typed")
removeButtons[1].__scripts.OnClick(removeButtons[1])
check(WL.Entry(600) == nil and WL.Entry(601) ~= nil, "the X button removes that row's item")
W.watchOn:SetChecked(false)
W.watchOn.__scripts.OnClick(W.watchOn)
check(CL.db.watchEnabled == false, "unticking the switch turns the highlight off")
W.watchOn:SetChecked(true)
W.watchOn.__scripts.OnClick(W.watchOn)
reset()

-- a shift-click on an item goes into the box that has the focus
do
    local box = W.watchBox
    local link = "|cffa335ee|Hitem:700::::::::|h[Shifted]|h|r"
    rawset(box, "Insert", function(self, t) self:SetText(self:GetText() .. t) end)
    box:SetText("")
    rawset(box, "HasFocus", function() return false end)
    ChatFrameUtil.InsertLink(link)
    check(box:GetText() == "", "a shift-click does nothing while the box has no focus")
    rawset(box, "HasFocus", function() return true end)
    ChatFrameUtil.InsertLink(link)
    check(box:GetText() == link, "...and goes into the box while it has the focus (ChatFrameUtil.InsertLink)")
    box:SetText("")
end

-- 11. /cll sim always drops a watched item
CL.Sim.Start(1)
check(RF.ActiveCount() == 1, "with nothing watched /cll sim works as before")
reset()
WL.Add(2589, "Item2589", "sim test")     -- a real item for the stub client
for run = 1, 20 do
    CL.Sim.Start(3)
    local found = false
    for _, frame in ipairs(RF.VisibleFrames()) do
        if frame.watched and frame.link and frame.link:find("item:2589", 1, true) then found = true end
    end
    check(found and RF.ActiveCount() == 3, "run " .. run .. ": /cll sim 3 has the watched item among three drops")
    CL.RollFrames.StopAll()   -- (not reset: the list must stay)
    CL.Sim.Clear()
end
CL.Sim.Start(1)
check(RF.ActiveCount() == 1 and RF.VisibleFrames()[1].watched, "/cll sim with one drop is the watched item")
f = RF.VisibleFrames()[1]
check(f.note:IsShown() and f.note:GetText() == "sim test", "...with its note")
reset()

-- an item the client does not know (not cached yet) is made up, with a link of its own
WL.Add(555555, "Unknown Thing", "made up")
CL.Sim.Start(2)
local made
for _, frame in ipairs(RF.VisibleFrames()) do
    if frame.link and frame.link:find("item:555555", 1, true) then made = frame end
end
check(made and made.watched and made.itemName == "Unknown Thing", "an item the client does not know is made up and highlighted")
reset()
WL.Add(555555, "Unknown Thing")
WL.Add(2589, "Item2589")
local seen = {}
for _ = 1, 30 do
    CL.Sim.Start(1)
    local frame = RF.VisibleFrames()[1]
    seen[frame.link:match("item:(%d+)")] = true
    CL.RollFrames.StopAll()   -- (not reset: the list must stay)
    CL.Sim.Clear()
end
check(seen["555555"] and seen["2589"], "with several watched items each one comes up")

-- a switched-off highlight: the drop shows, not highlighted, and the list is not forced into /cll sim
CL.db.watchEnabled = false
WL.Add(2589, "Item2589")
CL.Sim.Start(1)
check(RF.ActiveCount() == 1 and not RF.VisibleFrames()[1].watched, "with the highlight off the drop shows, but not highlighted")
CL.RollFrames.StopAll()
CL.Sim.Clear()
CL.Sim.Start(3)
check(RF.ActiveCount() == 3, "with the highlight off /cll sim still gives three drops")
reset()

print = realPrint
io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
