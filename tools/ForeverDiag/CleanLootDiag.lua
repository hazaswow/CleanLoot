-- CleanLootDiag
-- Dev tool for porting CleanLoot to WoW Forever (Interface 16001, retail UI
-- architecture). It guesses nothing: it records what the client really exposes
-- (APIs, events, native roll frame structure, C_LootHistory data) into
-- CleanLootDiagDB, which WoW writes to disk on /reload or logout.
--
--   /cld        dump API availability + help
--   /cld dump   dump the whole C_LootHistory (every encounter / drop / roll)
--   /cld clear  wipe the recorded log
--
-- Everything is pcall'd on purpose: this addon must never throw, whatever the
-- client does (secret values, missing APIs, unknown events).

local isSecret = _G.issecretvalue or function() return false end
local MAX_LOG = 1200
local PREFIX = "|cff33ff99CleanLootDiag|r: "

CleanLootDiagDB = CleanLootDiagDB or {}

-------------------------------------------------
-- Logging / safe serialization
-------------------------------------------------
local function Log(line)
    local db = CleanLootDiagDB
    db.log = db.log or {}
    db.log[#db.log + 1] = date("%H:%M:%S") .. "  " .. line
    if #db.log > MAX_LOG then table.remove(db.log, 1) end
    return line
end

local function S(v)
    if isSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "string" then return ("%q"):format(v) end
    if t == "table" or t == "function" or t == "userdata" then return "<" .. t .. ">" end
    return tostring(v)
end

local function Dump(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then return S(v) end
    if isSecret(v) then return "<secret table>" end
    if depth >= 3 then return "{...}" end
    local parts = {}
    local ok, err = pcall(function()
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            parts[#parts + 1] = tostring(k) .. "=" .. Dump(v[k], depth + 1)
        end
    end)
    if not ok then parts[#parts + 1] = "<error: " .. tostring(err) .. ">" end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function Pack(...)
    return select("#", ...), { ... }
end

local function Say(msg)
    print(PREFIX .. msg)
end

-- Key names + value types of a frame (no recursion: child frames are listed by
-- name only, otherwise one dump would walk the whole UI).
local function FrameShape(f)
    if not f then return "<nil>" end
    local parts = {}
    local ok, err = pcall(function()
        local keys = {}
        for k in pairs(f) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local v = f[k]
            local t = type(v)
            local extra = ""
            if t == "table" and v.GetObjectType then
                local okT, ot = pcall(v.GetObjectType, v)
                extra = okT and ("(" .. tostring(ot) .. ")") or ""
            elseif t == "number" or t == "boolean" or t == "string" then
                extra = "=" .. S(v)
            end
            parts[#parts + 1] = tostring(k) .. ":" .. t .. extra
        end
    end)
    if not ok then parts[#parts + 1] = "<error: " .. tostring(err) .. ">" end
    return table.concat(parts, ", ")
end

-------------------------------------------------
-- API availability dump
-------------------------------------------------
local GLOBALS = {
    -- 3.3.5 calls CleanLoot uses today
    "GetNumPartyMembers", "GetNumRaidMembers", "GetAddOnMetadata", "SetBackdrop_unused",
    -- modern replacements
    "GetNumGroupMembers", "GetNumSubgroupMembers", "IsInRaid", "IsInGroup",
    -- loot roll
    "GetLootRollItemInfo", "GetLootRollItemLink", "RollOnLoot", "ConfirmLootRoll",
    "GroupLootContainer", "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4",
    "GroupLootContainer_AddFrame", "GroupLootContainer_Update", "GroupLootContainer_RemoveFrame",
    "GroupLootHistoryFrame", "BonusRollFrame",
    -- UI helpers CleanLoot uses
    "BackdropTemplateMixin", "FauxScrollFrame_Update", "FauxScrollFrame_GetOffset",
    "FauxScrollFrame_OnVerticalScroll", "ChatFrame_AddMessageEventFilter", "ChatFrameUtil",
    "ChatEdit_InsertLink", "DressUpItemLink", "DressUpLink", "GetItemInfo",
    "hooksecurefunc", "issecretvalue", "issecrettable", "SecureCmdOptionParse",
    -- localized strings the chat parser is built from
    "LOOT_ROLL_NEED", "LOOT_ROLL_GREED", "LOOT_ROLL_DISENCHANT", "LOOT_ROLL_PASSED",
    "LOOT_ROLL_NEED_SELF", "LOOT_ROLL_GREED_SELF", "LOOT_ROLL_DISENCHANT_SELF", "LOOT_ROLL_PASSED_SELF",
    "LOOT_ROLL_WON", "LOOT_ROLL_YOU_WON", "LOOT_ROLL_NEED_PREFIX", "LOOT_ROLL_GREED_PREFIX",
    "LOOT_ROLL_DISENCHANT_PREFIX", "LOOT_ROLL_ROLLED_NEED", "LOOT_ROLL_ROLLED_GREED",
    "LOOT_ROLL_ROLLED_DE", "LOOT_ROLL_TRANSMOG", "LOOT_ROLL_TRANSMOG_SELF",
    "NEED", "GREED", "PASS", "ROLL_DISENCHANT", "TRANSMOGRIFY", "SHOW_LOOT_SPAM",
    -- gossip / merchant, in case CleanVendor follows
    "GetGossipOptions", "SelectGossipOption", "GetNumGossipOptions", "GetNumGossipActiveQuests",
    "GetMerchantItemInfo", "GetMerchantItemLink", "GetMerchantItemCostInfo", "BuyMerchantItem",
}

local NAMESPACES = {
    C_AddOns = { "GetAddOnMetadata", "LoadAddOn", "IsAddOnLoaded" },
    C_LootHistory = { "GetAllEncounterInfos", "GetSortedDropsForEncounter", "GetSortedInfoForDrop",
        "GetItem", "GetPlayerInfo", "GetNumItems", "GetInfoForEncounter", "CanMasterLoot",
        "GetOverrideDropInfo", "SetExpanded", "GetExpanded", "ClearAll" },
    C_GossipInfo = { "GetOptions", "SelectOption", "GetNumOptions", "GetNumActiveQuests", "GetNumAvailableQuests" },
    C_Item = { "GetItemInfo", "GetItemQualityColor", "GetItemQualityByID" },
    C_Timer = { "After", "NewTicker" },
    C_MerchantFrame = { "GetItemInfo", "GetNumItems" },
    C_CVar = { "GetCVar", "SetCVar" },
}

local TEMPLATES = { "BackdropTemplate", "UICheckButtonTemplate", "UIPanelButtonTemplate",
    "InputBoxTemplate", "FauxScrollFrameTemplate", "UIPanelCloseButton", "UIDropDownMenuTemplate",
    "GameFontNormal", "UIPanelScrollFrameTemplate", "ScrollingEditBoxTemplate" }

local function DumpAPI()
    local out = {}
    local function add(line) out[#out + 1] = line; Log("API  " .. line) end

    local version, build, _, toc = GetBuildInfo()
    add(("build=%s (%s) toc=%s locale=%s"):format(tostring(version), tostring(build), tostring(toc), tostring(GetLocale())))
    add(("WOW_PROJECT_ID=%s CAMELOT=%s CLASSIC=%s MAINLINE=%s"):format(
        tostring(_G.WOW_PROJECT_ID), tostring(_G.WOW_PROJECT_CAMELOT),
        tostring(_G.WOW_PROJECT_CLASSIC), tostring(_G.WOW_PROJECT_MAINLINE)))

    for _, name in ipairs(GLOBALS) do
        local v = _G[name]
        local t = type(v)
        local shown = t
        if t == "string" then shown = "string " .. S(v) end
        add(("global %-34s %s"):format(name, v == nil and "MISSING" or shown))
    end

    for ns, fns in pairs(NAMESPACES) do
        local tbl = _G[ns]
        if type(tbl) ~= "table" then
            add(("namespace %s: MISSING"):format(ns))
        else
            local present, missing = {}, {}
            for _, fn in ipairs(fns) do
                if type(tbl[fn]) == "function" then present[#present + 1] = fn else missing[#missing + 1] = fn end
            end
            add(("namespace %s: present={%s} missing={%s}"):format(ns, table.concat(present, ","), table.concat(missing, ",")))
            local all = {}
            pcall(function() for k, v in pairs(tbl) do if type(v) == "function" then all[#all + 1] = tostring(k) end end end)
            table.sort(all)
            add(("namespace %s: ALL functions = %s"):format(ns, table.concat(all, ",")))
        end
    end

    for _, ename in ipairs({ "EncounterLootDropRollState", "LootRollType", "LootRollState" }) do
        local e = _G.Enum and _G.Enum[ename]
        add(("Enum.%s = %s"):format(ename, e and Dump(e) or "MISSING"))
    end

    for _, tpl in ipairs(TEMPLATES) do
        local ok, err = pcall(CreateFrame, "Frame", nil, UIParent, tpl)
        add(("template %-28s %s"):format(tpl, ok and "ok" or ("FAILED: " .. tostring(err))))
    end

    for _, cv in ipairs({ "showLootSpam", "autoLootDefault", "lootUnderMouse", "chatBubbles" }) do
        local ok, v = pcall(GetCVar, cv)
        add(("cvar %-16s %s"):format(cv, ok and tostring(v) or "error"))
    end

    return out
end

-------------------------------------------------
-- C_LootHistory dump
-------------------------------------------------
local function DumpHistory(label)
    local H = _G.C_LootHistory
    if not H then Log("HISTORY " .. (label or "") .. " C_LootHistory MISSING"); return end
    local ok, err = pcall(function()
        local encounters = H.GetAllEncounterInfos and H.GetAllEncounterInfos() or {}
        Log(("HISTORY %s: %d encounter(s)"):format(label or "", #encounters))
        for _, enc in ipairs(encounters) do
            Log("HISTORY  encounter " .. Dump(enc))
            local drops = H.GetSortedDropsForEncounter and H.GetSortedDropsForEncounter(enc.encounterID) or {}
            for i, drop in ipairs(drops) do
                Log(("HISTORY   drop[%d] %s"):format(i, Dump(drop)))
            end
        end
    end)
    if not ok then Log("HISTORY error: " .. tostring(err)) end
end

-------------------------------------------------
-- Native roll frame inspection
-------------------------------------------------
local function DumpRollFrame(rollID)
    local found
    for i = 1, 12 do
        local f = _G["GroupLootFrame" .. i]
        if f and f.rollID == rollID then
            found = f
            Log(("ROLLFRAME GroupLootFrame%d for rollID %s"):format(i, tostring(rollID)))
            Log("ROLLFRAME  keys: " .. FrameShape(f))
            local ok, children = pcall(function() return { f:GetChildren() } end)
            if ok then
                for _, c in ipairs(children) do
                    local okN, n = pcall(c.GetName, c)
                    local okT, t = pcall(c.GetObjectType, c)
                    Log(("ROLLFRAME  child %s (%s) keys: %s"):format(
                        okN and tostring(n) or "?", okT and tostring(t) or "?", FrameShape(c)))
                end
            end
        end
    end
    if not found then Log("ROLLFRAME no GroupLootFrameN has rollID " .. tostring(rollID)) end
    local c = _G.GroupLootContainer
    if c then Log("ROLLFRAME container keys: " .. FrameShape(c)) end
end

-------------------------------------------------
-- Event recording
-------------------------------------------------
local HANDLERS = {}

HANDLERS.START_LOOT_ROLL = function(rollID)
    local n, info = Pack(GetLootRollItemInfo(rollID))
    local vals = {}
    for i = 1, n do vals[i] = S(info[i]) end
    Log(("ROLL GetLootRollItemInfo(%s) -> %d values: %s"):format(tostring(rollID), n, table.concat(vals, ", ")))
    local okL, link = pcall(GetLootRollItemLink, rollID)
    Log("ROLL GetLootRollItemLink -> " .. (okL and S(link) or "error"))
    Say("roll " .. tostring(rollID) .. " recorded")
    C_Timer.After(0.4, function() DumpRollFrame(rollID) end)
    C_Timer.After(1.5, function() DumpHistory("1.5s after START_LOOT_ROLL") end)
end

HANDLERS.LOOT_HISTORY_UPDATE_DROP = function(encounterID, lootListKey)
    local H = _G.C_LootHistory
    if H and H.GetSortedInfoForDrop then
        local ok, drop = pcall(H.GetSortedInfoForDrop, encounterID, lootListKey)
        Log("DROP " .. (ok and Dump(drop) or ("error " .. tostring(drop))))
    end
end

HANDLERS.PLAYER_LOGIN = function()
    DumpAPI()
    Say("API dump saved. Roll on something, then /reload so WoW writes the file.")
end

local EVENTS = {
    "PLAYER_LOGIN",
    "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS", "LOOT_ROLLS_COMPLETE",
    "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_FULL_UPDATE",
    "LOOT_HISTORY_ROLL_CHANGED", "LOOT_HISTORY_ROLL_COMPLETE", "LOOT_HISTORY_AUTO_SHOW",
    "CHAT_MSG_LOOT", "ENCOUNTER_LOOT_RECEIVED", "LOOT_READY", "LOOT_CLOSED",
    "GROUP_ROSTER_UPDATE",
}

local frame = CreateFrame("Frame")
for _, ev in ipairs(EVENTS) do
    local ok, err = pcall(frame.RegisterEvent, frame, ev)
    if not ok then Log("EVENT " .. ev .. " could not be registered: " .. tostring(err)) end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event ~= "GROUP_ROSTER_UPDATE" then
        local n, args = Pack(...)
        local vals = {}
        for i = 1, n do vals[i] = S(args[i]) end
        Log(("EVENT %s (%d args): %s"):format(event, n, table.concat(vals, ", ")))
    end
    local h = HANDLERS[event]
    if h then
        local ok, err = pcall(h, ...)
        if not ok then Log("handler error in " .. event .. ": " .. tostring(err)) end
    end
end)

-------------------------------------------------
-- Slash commands
-------------------------------------------------
SLASH_CLEANLOOTDIAG1 = "/cld"
SlashCmdList["CLEANLOOTDIAG"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "dump" then
        DumpHistory("manual")
        Say("history dumped. /reload to write the file.")
    elseif msg == "clear" then
        CleanLootDiagDB.log = {}
        Say("log cleared.")
    else
        local out = DumpAPI()
        local missing = 0
        for _, line in ipairs(out) do
            if line:find("MISSING", 1, true) or line:find("FAILED", 1, true) then
                missing = missing + 1
                print("  " .. line)
            end
        end
        Say(("API dump saved (%d missing/failed shown above). Commands: /cld dump, /cld clear. /reload to write the file."):format(missing))
    end
end
