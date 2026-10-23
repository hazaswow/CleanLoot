-- "Hide roll messages from chat": every roll produces a burst of lines ("X has
-- selected Greed for: [item]", "Y passed on: [item]", "Need Roll - 52 for ... by Z").
-- Those are filtered out of the chat frame. Only the chat DISPLAY is filtered: the
-- CHAT_MSG_LOOT event itself still reaches every addon, and the loot history window
-- keeps everything.
--
-- Kept visible on purpose: the lines saying who won what ("X won: [item]", and
-- "You won: [item]" when it is you), and the usual "You receive loot".
--
-- The patterns are built from the client's own global strings, so they are right
-- in any language. Each starts with a clickable |HlootHistory:N|h[Loot]|h prefix.

local _, CL = ...

local Filter = {}
CL.ChatFilter = Filter

local SOURCES = {
    "LOOT_ROLL_NEED", "LOOT_ROLL_GREED", "LOOT_ROLL_PASSED",                  -- someone chose
    "LOOT_ROLL_NEED_SELF", "LOOT_ROLL_GREED_SELF", "LOOT_ROLL_PASSED_SELF",   -- you chose
    "LOOT_ROLL_ROLLED_NEED", "LOOT_ROLL_ROLLED_GREED",                        -- roll values
}

local patterns = {}

-- "%s has selected Need for: %s" -> a Lua pattern ("%s" -> ".+", "%d" -> "%d+").
local function ToPattern(fmt)
    local p = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%%%s", ".+"):gsub("%%%%d", "%%d+")
    return "^" .. p
end

function Filter.Build()
    patterns = {}
    for _, name in ipairs(SOURCES) do
        local fmt = _G[name]
        if type(fmt) == "string" then patterns[#patterns + 1] = ToPattern(fmt) end
    end
end

-- ChatFrame message filter: true = hide the line.
function Filter.Hide(_, _, msg)
    if not (CL.db and CL.db.hideRollSpam) then return false end
    -- text the client marks as secret cannot be read, so it cannot be matched
    if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return false end
    for _, pattern in ipairs(patterns) do
        if msg:match(pattern) then return true end
    end
    return false
end

function Filter.Setup()
    Filter.Build()
    if ChatFrame_AddMessageEventFilter then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", Filter.Hide)
    end
end
