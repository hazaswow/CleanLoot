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

local Plain = CL.Plain

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
-- Slash command: /cll watch [item [note]] | note <item> <text> | remove <item> | list
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

function Watchlist.Command(arg)
    local sub, rest = (arg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local key = sub:lower()
    if key == "" then
        CL.Options.OpenWatchlist()
    elseif key == "list" then
        local list = Watchlist.List()
        if #list == 0 then CL.Print("the watchlist is empty. /cll watch [item] [note]") end
        for _, e in ipairs(list) do
            print(("  %s%s (item %d)"):format(e.name, e.note ~= "" and (" - " .. e.note) or "", e.id))
        end
    elseif key == "remove" then
        local word = Watchlist.SplitItem(rest)
        local id = Watchlist.ItemID(word)
        if id and Watchlist.Remove(id) then
            CL.Print(("%s is no longer on the watchlist."):format(CL.AutoRoll.NameOf(id, word)))
        else
            CL.Print("that item is not on the watchlist.")
        end
    elseif key == "note" then
        local word, note = Watchlist.SplitItem(rest)
        local id = Watchlist.ItemID(word)
        if id and Watchlist.SetNote(id, note) then
            CL.Print(note ~= "" and ("note saved for %s."):format(CL.AutoRoll.NameOf(id, word))
                or ("note cleared for %s."):format(CL.AutoRoll.NameOf(id, word)))
        else
            CL.Print("that item is not on the watchlist. Add it first: /cll watch [item] [note]")
        end
    else
        -- anything else is an item, optionally followed by its note
        local word, note = Watchlist.SplitItem(arg)
        local id = Watchlist.ItemID(word)
        if not id then
            CL.Print("/cll watch  |  /cll watch [item] [note]  |  /cll watch note [item] <text>  |  /cll watch remove [item]  |  /cll watch list")
            return
        end
        Watchlist.Add(id, CL.AutoRoll.NameOf(id, word), note)
        CL.Print(("%s is on the watchlist%s."):format(CL.AutoRoll.NameOf(id, word),
            CleanNote(note) ~= "" and (": " .. CleanNote(note)) or ""))
    end
end
