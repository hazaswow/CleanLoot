-- The rules for the rolls of one item in a loot session, shared by the master looter's session
-- and by the window of the other players, so both always see the same ranking.
--
--   1-100 = MS   1-99 = OS   1-90 = Other      (MS beats OS beats Other, whatever the numbers)
--
-- A roll can only go down: the first roll of a player counts, a later one in a LOWER category
-- (MS then OS, OS then Other) replaces it, the same category again or a higher one is ignored.
-- A pass cancels the roll. In a re-roll only the named players count, in one category.
--
-- A "book" is any table with `rolls` (name -> { cat, value }), `passed` (name -> true) and
-- optionally `restrict` ({ names = set, cat = n }): the session state itself is one.

local _, CL = ...

local Book = {}
CL.RollBook = Book

local CAT_OF = { [100] = 1, [99] = 2, [90] = 3 }
Book.LABEL = { "MS", "OS", "Other" }
Book.RANGE = { 100, 99, 90 }

function Book.New()
    return { rolls = {}, passed = {} }
end

-- The category of a roll's range, nil when it is none of the three.
function Book.Category(low, high)
    if low ~= 1 then return nil end
    return CAT_OF[high]
end

-- A roll seen in the chat. Returns true when it counts.
function Book.Add(book, name, value, low, high)
    if type(name) ~= "string" or type(value) ~= "number" then return false end
    local cat = Book.Category(low, high)
    if not cat then return false end
    if book.restrict then
        if not book.restrict.names[name] or cat ~= book.restrict.cat then return false end
    end
    local old = book.rolls[name]
    if old and cat <= old.cat then return false end   -- the same category again, or an upgrade
    book.rolls[name] = { cat = cat, value = value }
    book.passed[name] = nil
    return true
end

-- A pass: the roll is cancelled and the player leaves the list.
function Book.Pass(book, name)
    book.rolls[name] = nil
    book.passed[name] = true
end

-- The rolls, best first: { { name, cat, value, tied }, ... }, and how many share the best roll.
function Book.Ranking(book)
    local list = {}
    for name, r in pairs(book.rolls) do
        list[#list + 1] = { name = name, cat = r.cat, value = r.value }
    end
    table.sort(list, function(a, b)
        if a.cat ~= b.cat then return a.cat < b.cat end
        if a.value ~= b.value then return a.value > b.value end
        return a.name < b.name
    end)
    local top, tied = list[1], 0
    for _, e in ipairs(list) do
        if top and e.cat == top.cat and e.value == top.value then tied = tied + 1 end
    end
    for _, e in ipairs(list) do
        e.tied = tied > 1 and top and e.cat == top.cat and e.value == top.value or false
    end
    return list, tied
end
