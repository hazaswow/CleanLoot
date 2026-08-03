-- Minimal WoW 3.3.5 API stub harness for smoke-loading CleanLoot.lua outside the game client.
-- Not a full API mock: unknown calls fall back to permissive no-op stubs so the addon can
-- execute its top-level/init code without crashing. Real per-feature unit tests belong in
-- their own small standalone Lua scripts (see CLAUDE.md).

-- ---------------------------------------------------------------------
-- Generic auto-vivifying stub object: any method call or field access
-- returns another stub, and plain field assignment works normally.
-- ---------------------------------------------------------------------
local StubMeta = {}
local function NewStub()
    return setmetatable({}, StubMeta)
end
StubMeta.__index = function(t, k)
    local v = function(...) return NewStub() end
    rawset(t, k, v)
    return v
end
StubMeta.__call = function(t, ...) return NewStub() end

-- ---------------------------------------------------------------------
-- Frame stub: supports the handful of methods CleanLoot actually relies
-- on for layout/behavior decisions, backed by real state where it matters.
-- ---------------------------------------------------------------------
local function NewFrame(frameType, name, parent)
    local f = NewStub()
    local points = {}
    local shown = true
    local scripts = {}
    local size = { w = 0, h = 0 }

    rawset(f, "SetPoint", function(self, point, relTo, relPoint, x, y)
        points[#points + 1] = { point, relTo, relPoint, x or 0, y or 0 }
        return self
    end)
    rawset(f, "GetPoint", function(self, i)
        local p = points[i or #points] or { "CENTER", nil, "CENTER", 0, 0 }
        return p[1], p[2], p[3], p[4], p[5]
    end)
    rawset(f, "ClearAllPoints", function(self) points = {} return self end)
    rawset(f, "Show", function(self) shown = true return self end)
    rawset(f, "Hide", function(self) shown = false return self end)
    rawset(f, "IsShown", function(self) return shown end)
    rawset(f, "IsVisible", function(self) return shown end)
    rawset(f, "SetShown", function(self, v) shown = v and true or false return self end)
    rawset(f, "SetSize", function(self, w, h) size.w, size.h = w, h return self end)
    rawset(f, "SetWidth", function(self, w) size.w = w return self end)
    rawset(f, "SetHeight", function(self, h) size.h = h return self end)
    rawset(f, "GetWidth", function(self) return size.w end)
    rawset(f, "GetHeight", function(self) return size.h end)
    rawset(f, "SetScript", function(self, ev, fn) scripts[ev] = fn return self end)
    rawset(f, "GetScript", function(self, ev) return scripts[ev] end)
    rawset(f, "HookScript", function(self, ev, fn)
        local prev = scripts[ev]
        scripts[ev] = function(...) if prev then prev(...) end return fn(...) end
        return self
    end)
    rawset(f, "RegisterEvent", function(self, ev) return self end)
    rawset(f, "UnregisterEvent", function(self, ev) return self end)
    rawset(f, "RegisterForClicks", function(self, ...) return self end)
    rawset(f, "RegisterForDrag", function(self, ...) return self end)
    rawset(f, "SetBackdrop", function(self, bd) rawset(self, "_backdrop", bd) return self end)
    rawset(f, "GetBackdrop", function(self) return rawget(self, "_backdrop") end)
    rawset(f, "SetFont", function(self, font, size, flags)
        if font == nil then return false end
        rawset(self, "_font", { font, size, flags })
        return true
    end)
    rawset(f, "GetFont", function(self)
        local ft = rawget(self, "_font")
        if ft then return ft[1], ft[2], ft[3] end
        return "Fonts\\FRIZQT__.TTF", 10, ""
    end)
    rawset(f, "SetText", function(self, t) rawset(self, "_text", t) return self end)
    rawset(f, "GetText", function(self) return rawget(self, "_text") or "" end)
    rawset(f, "GetName", function(self) return name end)
    rawset(f, "GetObjectType", function(self) return frameType or "Frame" end)
    rawset(f, "GetParent", function(self) return parent end)
    rawset(f, "IsObjectType", function(self, t) return t == (frameType or "Frame") end)
    rawset(f, "CreateFontString", function(self, n, layer, template) return NewFrame("FontString", n, self) end)
    rawset(f, "CreateTexture", function(self, n, layer, template) return NewFrame("Texture", n, self) end)
    rawset(f, "GetRegions", function(self) return end)
    rawset(f, "SetScale", function(self, s) rawset(self, "_scale", s) return self end)
    rawset(f, "GetScale", function(self) return rawget(self, "_scale") or 1 end)
    rawset(f, "SetAlpha", function(self, a) rawset(self, "_alpha", a) return self end)
    rawset(f, "GetAlpha", function(self) return rawget(self, "_alpha") or 1 end)
    rawset(f, "EnableMouse", function(self, v) return self end)
    rawset(f, "SetMovable", function(self, v) return self end)
    rawset(f, "SetClampedToScreen", function(self, v) return self end)
    rawset(f, "StartMoving", function(self) return self end)
    rawset(f, "StopMovingOrSizing", function(self) return self end)

    if name then _G[name] = f end
    return f
end

-- ---------------------------------------------------------------------
-- WoW globals CleanLoot depends on
-- ---------------------------------------------------------------------
_G = _G or {}

function CreateFrame(frameType, name, parent, template)
    return NewFrame(frameType, name, parent)
end

function GetTime() return os.clock() end
function GetLocale() return "enUS" end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end

function GetNumPartyMembers() return 0 end
function GetNumRaidMembers() return 0 end
function UnitName(unit) return "Player" end
function GetGroupRoster() return end

-- Loot roll API
function GetNumLootRollItems() return 0 end
function GetLootRollItemInfo(rollID)
    -- texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant, reasonNeed, reasonGreed, reasonDisenchant
    return "Interface\\Icons\\INV_Misc_QuestionMark", "Test Item", 1, 4, false, 1, 1, 1, nil, nil, nil
end
function GetLootRollItemLink(rollID) return "|cffa335ee|Hitem:12345:0:0:0:0:0:0:0|h[Test Item]|h|r" end
function RollOnLoot(rollID, rollType) end
function GetLootMethod() return "group" end
function ConfirmLootSlot(slot) end

function GetItemInfo(item)
    -- name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture
    return "Test Item", "|cffa335ee|Hitem:12345:0:0:0:0:0:0:0|h[Test Item]|h|r", 4, 80, 1,
        "Miscellaneous", "Junk", 1, "", "Interface\\Icons\\INV_Misc_QuestionMark"
end

function GetCVar(name) return "0" end
function SetCVar(name, val) end

function ChatEdit_InsertLink(link) return false end
function DressUpItemLink(link) end

FauxScrollFrame_GetOffset = function(f) return 0 end
FauxScrollFrame_Update = function(f, numItems, numShown, itemHeight) end
FauxScrollFrame_OnVerticalScroll = function(f, offset, itemHeight, updateFn) end

InterfaceOptions_AddCategory = function(panel) end
StaticPopupDialogs = setmetatable({}, { __newindex = rawset, __index = function() return nil end })
StaticPopup_Show = function(name) return NewFrame("Frame") end
StaticPopup_Hide = function(name) end

SlashCmdList = {}

-- Loot roll global strings (LOOT_ROLL_* etc.), sourced with an English fallback
-- the addon itself expects — provide the base strings it patterns off of.
LOOT_ROLL_YOU_WON = "You won %s"
LOOT_ROLL_WON = "%s won: %s"
NEED = "Need"
GREED = "Greed"
PASS = "Pass"
DISENCHANT = "Disenchant"
YES = "Yes"
NO = "No"
DELETE_ITEM_CONFIRM_STRING = "Are you sure you want to delete %s?"
DELETE_GOOD_ITEM_CONFIRM_STRING = "%s is a valuable item. Are you sure you want to delete it?"

-- WoW's Lua environment aliases several stdlib functions under short names
-- and adds a few table helpers; the 3.3.5 client and these libs assume them.
strmatch = string.match
strfind = string.find
strsub = string.sub
strlower = string.lower
strupper = string.upper
strrep = string.rep
strlen = string.len
strbyte = string.byte
strchar = string.char
format = string.format
gsub = string.gsub
tinsert = table.insert
tremove = table.remove
sort = table.sort
function strsplit(sep, str)
    local parts = {}
    for part in string.gmatch(str, "([^" .. sep .. "]+)") do
        parts[#parts + 1] = part
    end
    return unpack(parts)
end
function strjoin(sep, ...)
    return table.concat({ ... }, sep)
end
function strtrim(s) return s:match("^%s*(.-)%s*$") end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
unpack = unpack or table.unpack

-- ---------------------------------------------------------------------
-- Load the embedded libs for real BEFORE installing the catch-all stub
-- below — LibStub.lua does `local LibStub = LibStub or {...}`, which the
-- catch-all would short-circuit by handing back a stub function instead
-- of the real nil/table it expects on first load.
-- ---------------------------------------------------------------------
local function loadReal(path)
    local chunk, err = loadfile(path)
    if not chunk then
        print("FAILED TO PARSE " .. path .. ": " .. tostring(err))
        os.exit(1)
    end
    local ok, runErr = pcall(chunk)
    if not ok then
        print("FAILED TO RUN " .. path .. ": " .. tostring(runErr))
        os.exit(1)
    end
end

loadReal("Libs/LibStub/LibStub.lua")
loadReal("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
loadReal("Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua")
loadReal("Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua")

-- Any other WoW global the addon touches falls back to a permissive stub
-- (function-that-returns-a-stub for calls, chainable for methods).
setmetatable(_G, {
    __index = function(t, k)
        local v = function(...) return NewStub() end
        rawset(t, k, v)
        return v
    end,
})

local chunk, err = loadfile("CleanLoot.lua")
if not chunk then
    print("PARSE FAILED: " .. tostring(err))
    os.exit(1)
end

local ok, runErr = pcall(chunk)
if not ok then
    print("RUNTIME ERROR: " .. tostring(runErr))
    os.exit(1)
end

print("LOADED OK")
