-- Watchlist: items you want to be reminded of. When one of them drops, its roll frame
-- gets a gently pulsing outline, and the note you wrote for it shows on the frame.
-- Nothing is rolled for you: this only draws the eye (auto-roll answers, this reminds).
--
-- Saved in the saved variables:
--   watchItems   = { [itemID] = { name = "...", note = "..." } }   (note may be empty)
--   watchEnabled                                                   (master switch)

local _, CL = ...

local Watchlist = {}
CL.Watchlist = Watchlist

-- Long notes would not fit on a roll frame.
Watchlist.MAX_NOTE = 60

local function Items()
    local db = CL.db
    if not db.watchItems then db.watchItems = {} end
    return db.watchItems
end

-- The options page and the open roll frames show the list.
local function Changed(skipOptions)
    if not skipOptions and CL.Options and CL.Options.Refresh then CL.Options.Refresh() end
    if CL.RollFrames and CL.RollFrames.RefreshWatch then CL.RollFrames.RefreshWatch() end
end

local function CleanNote(note)
    if type(note) ~= "string" then return "" end
    note = note:gsub("[%c|]", " "):gsub("^%s+", ""):gsub("%s+$", "")   -- no escape codes in a note
    if #note > Watchlist.MAX_NOTE then note = note:sub(1, Watchlist.MAX_NOTE) end
    return note
end

-- Same ids as auto-roll: an item link, "item:123" or a number.
function Watchlist.ItemID(value)
    return CL.AutoRoll.ItemID(value)
end

-- The entry of a watched item (or nil), whatever the master switch says.
function Watchlist.Entry(itemID)
    return itemID and Items()[itemID] or nil
end

-- What a roll frame wants to know: is this item highlighted, and with which note?
-- Returns nil when it is not, or when the highlight is switched off.
function Watchlist.Lookup(link)
    local db = CL.db
    if not (db and db.watchEnabled) then return nil end
    local entry = Watchlist.Entry(Watchlist.ItemID(link))
    if not entry then return nil end
    return entry.note or "", entry.name
end

function Watchlist.Add(itemID, name, note)
    if not itemID then return false end
    local old = Items()[itemID]
    -- a placeholder ("item 600", the client did not know the item) never replaces a real name
    if old and old.name and not old.name:match("^item %d+$") and (not name or name:match("^item %d+$")) then
        name = old.name
    end
    Items()[itemID] = {
        name = name or CL.AutoRoll.NameOf(itemID),
        note = note ~= nil and CleanNote(note) or (old and old.note) or "",
    }
    Changed()
    return true
end

function Watchlist.Remove(itemID)
    local items = Items()
    if not (itemID and items[itemID]) then return false end
    items[itemID] = nil
    Changed()
    return true
end

-- Edit the note of a watched item. The options page is not rebuilt: its note box is
-- the one being typed in.
function Watchlist.SetNote(itemID, note)
    local entry = Watchlist.Entry(itemID)
    if not entry then return false end
    entry.note = CleanNote(note)
    Changed(true)
    return true
end

-- The watched items, by name: { { id =, name =, note = }, ... }.
function Watchlist.List()
    local list = {}
    for id, entry in pairs(Items()) do
        local name = entry.name
        if not name or name:match("^item %d+$") then name = CL.AutoRoll.NameOf(id) end   -- the client knows it now
        list[#list + 1] = { id = id, name = name, note = entry.note or "" }
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return list
end

-- One watched item at random (the simulator uses it so the highlight can be seen).
function Watchlist.Random()
    local list = Watchlist.List()
    if #list == 0 then return nil end
    return list[math.random(#list)]
end

-------------------------------------------------
-- Reading an item and its note from a line the player typed or pasted
-------------------------------------------------
-- Splits "<item> <note>": the item is a link (it contains spaces), "item:123" or a number,
-- the rest of the line is the note.
function Watchlist.SplitItem(text)
    text = text or ""
    local link = text:match("^%s*(|c.-|r)") or text:match("^%s*(|H.-|h%[.-%]|h)")
    if link then
        local _, stop = text:find(link, 1, true)
        return link, (text:sub(stop + 1):gsub("^%s+", ""):gsub("%s+$", ""))
    end
    local word, rest = text:match("^%s*(%S+)%s*(.-)%s*$")
    return word, rest
end
