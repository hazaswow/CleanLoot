-- Messages between CleanLoot users in the same group: the master looter's session tells the
-- other players' windows what is going on (the item in play, the time left, who won...), and a
-- player tells the master looter when he passes. Everything else (the rolls themselves) is the
-- game's own /roll, so players without CleanLoot take part too.
--
-- One addon message is "kind<TAB>field<TAB>field...", at most 255 characters, on the prefix
-- CLEANLOOT, through the group's channel (/raid, /party or the instance chat). The kinds:
--
--   master looter -> players
--     S version sid count seconds       a session starts (count = items, seconds = time per item)
--     I sid index total copies link secs   the item in play (and how many copies it has)
--     P sid index paused secs           paused or resumed, with the time left
--     R sid index names cat secs        a re-roll between the tied players only
--     C sid index                       the rolls are closed
--     W sid index name cat value        somebody won a copy (cat and value empty: given by hand)
--     X sid index name                  that assignment was taken back
--     Z sid index                       the item was skipped
--     E sid  /  K sid                   the session ended  /  was cancelled
--   player -> master looter
--     Q sid index                       I pass
--
-- A player's window only believes the master looter of the group: a message from anybody else
-- is ignored.

local _, CL = ...

local Comm = {}
CL.Comm = Comm

local PREFIX = "CLEANLOOT"
local VERSION = 1
local SEP = "\t"
Comm.VERSION = VERSION

if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
end

-- The channel of the group: the instance chat in a group made by the dungeon finder, else
-- the raid or the party. nil alone.
function Comm.Channel()
    local instance = rawget(_G, "LE_PARTY_CATEGORY_INSTANCE")
    if instance and type(IsInGroup) == "function" and IsInGroup(instance) == true then return "INSTANCE_CHAT" end
    if type(IsInRaid) == "function" and IsInRaid() == true then return "RAID" end
    if type(IsInGroup) == "function" and IsInGroup() == true then return "PARTY" end
    return nil
end

function Comm.Encode(kind, ...)
    local parts = { kind }
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    return table.concat(parts, SEP)
end

-- "kind", { fields } from a message text.
function Comm.Decode(text)
    if type(text) ~= "string" then return nil end
    local fields = {}
    for part in (text .. SEP):gmatch("([^" .. SEP .. "]*)" .. SEP) do fields[#fields + 1] = part end
    local kind = table.remove(fields, 1)
    if not kind or kind == "" then return nil end
    return kind, fields
end

-- Send to the group. Returns true when it went out.
function Comm.Send(kind, ...)
    local channel = Comm.Channel()
    if not channel or not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return false end
    local text = Comm.Encode(kind, ...)
    if #text > 255 then
        CL.Debug("comm: %s message too long (%d), not sent", kind, #text)
        return false
    end
    local ok = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel)
    return ok
end

-- Is `sender` the master looter of the group?
function Comm.FromMasterLooter(sender)
    local name = CL.MasterLoot.MasterLooterName()
    return name ~= nil and CL.MasterLoot.SameName(sender, name)
end

local handlers = {}
-- Register what to do with a kind of message: fn(fields, sender).
function Comm.On(kind, fn)
    handlers[kind] = fn
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, _, prefix, text, _, sender)
    if prefix ~= PREFIX or not CL.db then return end
    sender = CL.Plain(sender)
    text = CL.Plain(text)
    if type(sender) ~= "string" then return end
    local me = type(UnitName) == "function" and UnitName("player")
    if type(me) == "string" and CL.MasterLoot.SameName(sender, me) then return end   -- our own messages come back
    local kind, fields = Comm.Decode(text)
    local handler = kind and handlers[kind]
    if handler then
        local ok, err = pcall(handler, fields, sender)
        if not ok then CL.Debug("comm: %s from %s failed: %s", kind, sender, tostring(err)) end
    end
end)
