-- The roll frame skins against the stub client. Run with lua tools/test_skin.lua.
local WOW = dofile("tools/wowenv.lua")
local CL, RF = WOW.CL, WOW.CL.RollFrames
local failures, checks = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1 io.write("FAIL: " .. label .. "\n") end
end

local INFO = {}
local function roll(rollID, item)
    item = item or {}
    INFO[rollID] = { id = item.id or 7001, name = item.name or "Real Item", quality = item.quality or 4,
        canNeed = item.canNeed ~= false }
    WOW.FireEvent("START_LOOT_ROLL", rollID, 20000)
end
function GetLootRollItemInfo(rollID)
    local i = INFO[rollID]
    if not i then return nil end
    return 135000, i.name, 1, i.quality, false, i.canNeed, true, false, nil, nil
end
function GetLootRollItemLink(rollID)
    local i = INFO[rollID]
    return i and ("|cffa335ee|Hitem:%d::::::::|h[%s]|h|r"):format(i.id, i.name) or nil
end
function RollOnLoot() end
local said = {}
print = function(...) said[#said + 1] = table.concat({ ... }, " ") end
local function sayMatches(p)
    for _, line in ipairs(said) do if line:find(p, 1, true) then return true end end
    return false
end

local ORDER = CL.ROLL_ORDER

-- 1. The flat skin is the default
check(CL.db.rollSkin == "clean" and RF.Skin() == "clean", "the flat skin is the default")
roll(3001)
local f = RF.GetFrame(3001)
check(f and f.skin == "clean" and f:GetWidth() == 252 and f:GetHeight() == 70, "the flat frame is 252 x 70")
check(not f.buttons[1].art:IsShown() and not f.slot:IsShown(), "...with no classic art")

-- 2. The classic skin dresses an open frame at once
RF.SetSkin("blizzard")
check(CL.db.rollSkin == "blizzard" and RF.Skin() == "blizzard", "the choice is saved")
check(f.skin == "blizzard" and f:GetWidth() == 262 and f:GetHeight() == 84, "an open frame takes the classic size")
check(f.slot:IsShown() and f.slot.outline:IsShown(), "the icon gets its coloured frame")
for _, t in ipairs(ORDER) do
    local b = f.buttons[t]
    check(b.art:IsShown() and not b.label:IsShown() and b:GetWidth() == 28, "button " .. t .. " is the classic picture, with no label")
end

-- a button is dimmed when the answer is not possible
RF.StopAll()
roll(3002, { canNeed = false })
f = RF.GetFrame(3002)
check(f.buttons[1].unavailable and f.buttons[1]:GetAlpha() < 1, "an unavailable button is dimmed")
check(not f.buttons[2].unavailable and f.buttons[2]:GetAlpha() == 1, "an available one is not")

-- the frame height with a watched item's note
CL.db.watchItems = { [7005] = { name = "Noted", note = "BiS" } }
RF.StopAll()
roll(3003, { id = 7005, name = "Noted" })
f = RF.GetFrame(3003)
check(f.watched and f:GetHeight() == 84 + 14, "a note adds one line to the classic frame too (" .. tostring(f:GetHeight()) .. ")")
CL.db.watchItems = {}

-- 3. Back to the flat skin
RF.StopAll()
roll(3004)
f = RF.GetFrame(3004)
RF.SetSkin("clean")
check(f.skin == "clean" and f:GetWidth() == 252 and f:GetHeight() == 70, "the flat size comes back")
check(not f.slot:IsShown() and f.buttons[1].label:IsShown() and not f.buttons[1].art:IsShown() and f.buttons[1]:GetWidth() == 72,
    "...and the flat buttons")
check(f.buttons[1]:GetAlpha() == 1, "...at full strength")

-- 4. Every pooled frame follows, shown or not, and so does one made later
RF.StopAll()
RF.SetSkin("blizzard")
local all = true
for i = 1, 8 do
    local fr = rawget(_G, "CleanLootRollFrame" .. i)
    if fr and fr.skin ~= "blizzard" then all = false end
end
check(all, "a frame that is not in use follows the skin too")
for i = 3010, 3012 do roll(i) end
check(RF.GetFrame(3010).skin == "blizzard" and RF.GetFrame(3012):GetHeight() == 84, "the next rolls open in the saved skin")
RF.StopAll()

-- 5. The answers still work in the classic skin
roll(3020)
f = RF.GetFrame(3020)
local answered
function RollOnLoot(id, kind) answered = { id, kind } end
f.buttons[2].__scripts.OnMouseDown(f.buttons[2])
f.buttons[2].__scripts.OnMouseUp(f.buttons[2])
f.buttons[2].__scripts.OnClick(f.buttons[2], "LeftButton")
check(answered and answered[1] == 3020 and answered[2] == 2, "a click on the coin rolls Greed")
check(RF.GetFrame(3020) == nil, "...and closes the frame")

-- 6. An auto-roll rule shows on the classic button
CL.db.autoItems = { [7001] = { roll = 1, name = "Real Item" } }
CL.db.autoQuality = {}
CL.db.autoRollEnabled = true
CL.db.autoConfirm = false
roll(3030, { canNeed = false })   -- the rule cannot fire: the frame is shown
f = RF.GetFrame(3030)
check(f and f.buttons[1].auto, "the button of an auto-roll rule is marked")
CL.db.autoItems = {}
RF.StopAll()

-- 7. The options
CL.RollFrames.SetSkin("blizzard")

local W = CL.Options.widgets
check(W.skinClean and W.skinBlizzard, "the options page has both choices")
CL.Options.Refresh()
check(W.skinBlizzard:GetChecked() and not W.skinClean:GetChecked(), "they show the saved skin")
W.skinClean:SetChecked(true)
W.skinClean.__scripts.OnClick(W.skinClean)
check(RF.Skin() == "clean" and W.skinClean:GetChecked() and not W.skinBlizzard:GetChecked(), "ticking the flat one switches to it, exclusively")

-- the queue label follows the width
RF.SetSkin("blizzard")
for i = 3100, 3109 do roll(i) end
check(RF.QueuedCount() >= 1, "(a big drop queues)")
RF.StopAll()
RF.SetSkin("clean")

io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
