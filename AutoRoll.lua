-- Auto-roll: answer a loot roll for you, by item (always Need the Gurubashi Idols)
-- or by quality (Greed every green). Rules only ever answer for you when the answer
-- is possible and safe; otherwise the roll frame opens as usual and you decide.
--
-- Saved in the saved variables:
--   autoItems   = { [itemID] = { roll = 0|1|2, name = "..." } }
--   autoQuality = { [2..5]   = 0|1|2 }        (absent = off; rolls start at green)
--   autoRollEnabled, autoRollSay              (master switch, chat line when it rolls)

local _, CL = ...

local AutoRoll = {}
CL.AutoRoll = AutoRoll

local ROLL = CL.ROLL
local Plain = CL.Plain

-- Rolls do not exist below green, so there is nothing to automate for white and grey.
AutoRoll.QUALITIES = { 2, 3, 4, 5 }
local QUALITY_NAME = { [2] = "Green", [3] = "Blue", [4] = "Epic", [5] = "Legendary" }
function AutoRoll.QualityName(q) return QUALITY_NAME[q] or "?" end

local function Items()
    local db = CL.db
    if not db.autoItems then db.autoItems = {} end
    return db.autoItems
end

local function Qualities()
    local db = CL.db
    if not db.autoQuality then db.autoQuality = {} end
    return db.autoQuality
end

local function ValidRoll(rollType)
    return rollType == ROLL.NEED or rollType == ROLL.GREED or rollType == ROLL.PASS
end

-- Something changed: the options page and the open roll frames show the rules.
local function Changed()
    if CL.Options and CL.Options.Refresh then CL.Options.Refresh() end
    if CL.RollFrames and CL.RollFrames.RefreshAuto then CL.RollFrames.RefreshAuto() end
end

-------------------------------------------------
-- Items
-------------------------------------------------
-- The item id of an item link, an "item:123" string or a number; nil otherwise.
function AutoRoll.ItemID(value)
    value = Plain(value)
    if type(value) == "number" then
        return value > 0 and math.floor(value) or nil
    end
    if type(value) ~= "string" then return nil end
    local id = value:match("item:(%d+)") or value:match("^%s*(%d+)%s*$")
    id = tonumber(id)
    return (id and id > 0) and id or nil
end

-- A name to show for an item: the link's own, else what the client knows, else its id.
function AutoRoll.NameOf(itemID, link)
    if type(link) == "string" then
        local name = link:match("|h%[(.-)%]|h")
        if name then return name end
    end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if get and itemID then
        local ok, name = pcall(get, itemID)
        if ok and type(name) == "string" then return name end
    end
    return "item " .. tostring(itemID)
end

function AutoRoll.ItemRule(itemID)
    return itemID and Items()[itemID] or nil
end

function AutoRoll.SetItem(itemID, rollType, name)
    if not (itemID and ValidRoll(rollType)) then return false end
    Items()[itemID] = { roll = rollType, name = name or AutoRoll.NameOf(itemID) }
    Changed()
    return true
end

function AutoRoll.RemoveItem(itemID)
    local items = Items()
    if not (itemID and items[itemID]) then return false end
    items[itemID] = nil
    Changed()
    return true
end

-- The item rules, by name: { { id =, roll =, name = }, ... }.
function AutoRoll.List()
    local list = {}
    for id, rule in pairs(Items()) do
        local name = rule.name
        -- remembered before the client knew the item: ask again now
        if not name or name:match("^item %d+$") then name = AutoRoll.NameOf(id) end
        list[#list + 1] = { id = id, roll = rule.roll, name = name }
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return list
end

-- The next answer when a rule's button is clicked again on the options page.
function AutoRoll.NextRoll(rollType)
    if rollType == ROLL.NEED then return ROLL.GREED end
    if rollType == ROLL.GREED then return ROLL.PASS end
    return ROLL.NEED
end

-------------------------------------------------
-- Qualities
-------------------------------------------------
function AutoRoll.QualityRule(quality)
    return Qualities()[quality]
end

-- rollType nil switches the quality's rule off.
function AutoRoll.SetQuality(quality, rollType)
    if not QUALITY_NAME[quality] then return false end
    if rollType ~= nil and not ValidRoll(rollType) then return false end
    Qualities()[quality] = rollType
    Changed()
    return true
end

-------------------------------------------------
-- Deciding and answering
-------------------------------------------------
-- The answer the rules want for an item, and which kind of rule it is ("item" or
-- "quality"). An item rule wins over the quality one. nil = no rule, or auto-roll off.
function AutoRoll.Rule(itemID, quality)
    local db = CL.db
    if not (db and db.autoRollEnabled) then return nil end
    local rule = AutoRoll.ItemRule(itemID)
    if rule then return rule.roll, "item" end
    if quality and QUALITY_NAME[quality] then
        local rollType = Qualities()[quality]
        if rollType ~= nil then return rollType, "quality" end
    end
    return nil
end

local function Say(fmt, ...)
    if CL.db.autoRollSay then CL.Print(fmt:format(...)) end
end

-- Called for every roll that starts, before its frame. Returns true when the roll was
-- answered (the caller then shows no frame). Anything that makes the answer
-- impossible or unsafe returns false: the frame opens and the player chooses.
function AutoRoll.Try(rollID, info, link)
    local itemID = AutoRoll.ItemID(link)
    local rollType, kind = AutoRoll.Rule(itemID, info.quality)
    if rollType == nil then return false end

    local shown = (type(link) == "string" and link) or info.name or "?"
    local why
    if rollType == ROLL.NEED and not info.canNeed then
        why = "Need is not available on it"
    elseif rollType == ROLL.GREED and not info.canGreed then
        why = "Greed is not available on it"
    elseif rollType ~= ROLL.PASS and info.bop and not CL.db.autoConfirm then
        -- the game would ask to confirm: that prompt stays yours unless you let us accept it
        why = "it binds when picked up and the confirmation is yours (see the auto-accept option)"
    end
    if why then
        CL.Debug("roll %s: %s rule says %s but %s, left to the player", tostring(rollID), kind,
            CL.ROLL_NAME[rollType], why)
        Say("not auto-rolled %s: %s.", shown, why)
        return false
    end

    if not CL.API.Roll(rollID, rollType) then
        CL.Debug("roll %s: the auto %s was refused by the game, left to the player", tostring(rollID),
            CL.ROLL_NAME[rollType])
        return false
    end
    CL.Debug("roll %s: auto-rolled %s (%s rule)", tostring(rollID), CL.ROLL_NAME[rollType], kind)
    Say("auto-rolled %s on %s.", CL.ROLL_NAME[rollType], shown)
    return true
end

-- A right-click on a roll button: remember "always this answer" for the item, or
-- forget it when that button is already the rule. Returns "added", "removed" or nil
-- (nothing to remember: the item is unknown).
function AutoRoll.ToggleForItem(link, itemName, rollType)
    local itemID = AutoRoll.ItemID(link)
    if not itemID then
        CL.Print("this item cannot be remembered for auto-roll.")
        return nil
    end
    local name = AutoRoll.NameOf(itemID, link)
    if itemName and name == "item " .. itemID then name = itemName end
    local rule = AutoRoll.ItemRule(itemID)
    if rule and rule.roll == rollType then
        AutoRoll.RemoveItem(itemID)
        CL.Print(("auto-roll removed for %s."):format(name))
        return "removed"
    end
    AutoRoll.SetItem(itemID, rollType, name)
    CL.Print(("from now on: always %s on %s%s."):format(CL.ROLL_NAME[rollType], name,
        CL.db.autoRollEnabled and "" or " (auto-roll is switched off in the options)"))
    return "added"
end

-------------------------------------------------
-- Slash command: /cll auto [need|greed|pass <item>] | remove <item> | list
-------------------------------------------------
local ARG_ROLL = { need = ROLL.NEED, greed = ROLL.GREED, pass = ROLL.PASS }

function AutoRoll.Command(arg)
    local sub, rest = (arg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local key = sub:lower()
    if key == "" then
        CL.Options.OpenAutoRoll()
    elseif key == "list" then
        local list = AutoRoll.List()
        if #list == 0 then
            CL.Print("no item rule yet. Right-click a roll button, or: /cll auto need|greed|pass [item].")
        end
        for _, r in ipairs(list) do
            print(("  %s: always %s (item %d)"):format(r.name, CL.ROLL_NAME[r.roll], r.id))
        end
        for _, q in ipairs(AutoRoll.QUALITIES) do
            local rollType = AutoRoll.QualityRule(q)
            if rollType ~= nil then print(("  all %s items: %s"):format(QUALITY_NAME[q]:lower(), CL.ROLL_NAME[rollType])) end
        end
    elseif ARG_ROLL[key] then
        local id = AutoRoll.ItemID(rest)
        if not id then
            CL.Print("give an item: shift-click it into the chat line, or type its id.")
            return
        end
        AutoRoll.SetItem(id, ARG_ROLL[key], AutoRoll.NameOf(id, rest))
        CL.Print(("from now on: always %s on %s."):format(CL.ROLL_NAME[ARG_ROLL[key]], AutoRoll.NameOf(id, rest)))
    elseif key == "remove" then
        local id = AutoRoll.ItemID(rest)
        if id and AutoRoll.RemoveItem(id) then
            CL.Print(("auto-roll removed for %s."):format(AutoRoll.NameOf(id, rest)))
        else
            CL.Print("no rule for that item.")
        end
    else
        CL.Print("/cll auto  |  /cll auto need|greed|pass <item>  |  /cll auto remove <item>  |  /cll auto list")
    end
end
