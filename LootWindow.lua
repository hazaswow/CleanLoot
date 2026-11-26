-- The loot record window (/loot, and the minimap button): who won what, picked by instance or by boss.
-- It takes the place of the game's own "Loot Rolls" window, which keeps failing, and keeps
-- its way of working: a list of the drops with the item and the winner, the rolls in the
-- tooltip, a click on an item to link it in the chat. The data is LootLog.lua's.

local _, CL = ...

local W = {}
CL.LootWindow = W

local WIN_W, WIN_H = 580, 342
local TOP = 68
local LEFT_W = 150
local TREE_ROWS, TREE_H = 12, 20
local LIST_ROWS, LIST_H = 10, 24
local LIST_W = 388
-- the columns of a drop (x in the row, width): item, kind of roll, the roll, the winner
local COL_ITEM, COL_ITEM_W = 32, 166
local COL_KIND, COL_KIND_W = 204, 56
local COL_ROLL, COL_ROLL_W = 262, 30
local COL_WHO, COL_WHO_W = 300, 86
local FLAT = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
    bgFile = FLAT, edgeFile = FLAT, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local GREY = "|cffb3b3b3"
local GOLD = "|cffffd100"

local win
local state = { sel = nil, mine = false, treeOff = 0, listOff = 0, collapsed = {}, open = {} }
local flat = {}      -- the tree as shown, one line per row
local shown = {}     -- the entries of the selection
local lines = {}     -- the list as shown: an item, then the rolls of the items that are opened

local function Log() return CL.LootLog end

local function Hex(r, g, b)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function ClassColor(class)
    if type(class) == "string" then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
            return c.r, c.g, c.b
        end
    end
    return 0.8, 0.8, 0.8
end

local function ShortName(name)
    return type(name) == "string" and (name:match("^([^%-]+)") or name) or "?"
end

local function WhoText(w)
    if w.isSelf then return GOLD .. "You|r" end
    return Hex(ClassColor(w.class)) .. ShortName(w.name) .. "|r"
end

-- "Need 87", "MS 54", "to disenchant", or nil.
local function RollText(w)
    if w.label then return w.label end
    local word = w.type and CL.ROLL_NAME and CL.ROLL_NAME[w.type]
    if not word then return nil end
    return w.value and (word .. " " .. w.value) or word
end

-- The second line of a drop: who got it and how.
function W.WinnerText(e)
    local w = e.winner
    if w then
        local verb = e.source == "roll" and "Won by " or "Given to "
        local how = RollText(w)
        return verb .. WhoText(w) .. (how and ("  " .. GREY .. how .. "|r") or "")
    end
    if e.allPassed then return GREY .. "Everybody passed|r" end
    return GREY .. "No winner|r"
end

-- The three columns of a drop: the kind of roll, the roll, who got it.
function W.Columns(e)
    local w = e.winner
    if not w then
        if e.allPassed then return "Pass", "", GREY .. "Everybody|r" end
        return "", "", GREY .. "-|r"
    end
    local kind, value
    if w.label then
        kind, value = w.label:match("^(%S+) (%d+)$")
        if not kind then kind, value = w.label, "" end
    else
        kind = w.type and CL.ROLL_NAME and CL.ROLL_NAME[w.type] or ""
        value = w.value and tostring(w.value) or ""
    end
    return kind, value, WhoText(w)
end

-- Ctrl-click: the item on the character (the dressing room); Shift-click: its link in the chat.
local function Preview(link)
    local fn = DressUpLink or DressUpItemLink
    if fn then fn(link) end
end

local function InsertLink(link)
    local fn = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
    if fn then fn(link) end
end

local function Age(t)
    local d = (GetServerTime and GetServerTime() or time()) - (t or 0)
    if d < 60 then return "now" end
    if d < 3600 then return ("%dm"):format(math.floor(d / 60)) end
    if d < 86400 then return ("%dh"):format(math.floor(d / 3600)) end
    return date and date("%d/%m", t) or "?"
end

local function IconOf(link)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(instant) == "function" and link then
        local ok, _, _, _, _, icon = pcall(instant, link)
        if ok and icon ~= nil then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Tooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = e.link and pcall(GameTooltip.SetHyperlink, GameTooltip, e.link)
    if not ok then GameTooltip:SetText(e.name or "?") end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(("%s - %s  (%s ago)"):format(e.instance or "?", e.boss or "?", Age(e.t)), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(W.WinnerText(e), 1, 1, 1)
    if e.rolls and #e.rolls > 0 then
        GameTooltip:AddLine("Rolls", 1, 0.82, 0)
        for _, r in ipairs(e.rolls) do
            local left = Hex(ClassColor(r.class)) .. ShortName(r.name) .. "|r" .. (r.isWinner and (GOLD .. "  (winner)|r") or "")
            GameTooltip:AddDoubleLine(left, RollText(r) or "-", 1, 1, 1, 1, 1, 1)
        end
    end
    if e.passes and e.passes > 0 then
        GameTooltip:AddLine(("%d passed"):format(e.passes), 0.7, 0.7, 0.7)
    end
    if e.me and e.me.type then
        GameTooltip:AddLine("You: " .. (RollText(e.me) or "-"), 0.25, 1, 0.25)
    end
    GameTooltip:AddLine("Click: who rolled   Ctrl: preview   Shift: link", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

-------------------------------------------------
-- What is shown
-------------------------------------------------
local function SameSel(a, b)
    return a and b and a.instance == b.instance and a.boss == b.boss
end

local function BuildTree()
    flat = {}
    local tree = Log().Tree(state.mine)
    local total = 0
    for _, inst in ipairs(tree) do total = total + inst.count end
    flat[1] = { kind = "all", count = total, sel = nil }
    local stillThere = state.sel == nil
    for _, inst in ipairs(tree) do
        flat[#flat + 1] = { kind = "instance", name = inst.name, count = inst.count, sel = { instance = inst.name } }
        if state.sel and not state.sel.boss and state.sel.instance == inst.name then stillThere = true end
        if not state.collapsed[inst.name] then
            for _, boss in ipairs(inst.bosses) do
                flat[#flat + 1] = { kind = "boss", name = boss.name, count = boss.count,
                    sel = { instance = inst.name, boss = boss.name } }
            end
        end
        for _, boss in ipairs(inst.bosses) do
            if state.sel and state.sel.boss == boss.name and state.sel.instance == inst.name then stillThere = true end
        end
    end
    if not stillThere then state.sel = nil end
end

local function SelText()
    local s = state.sel
    if not s then return "All loot" end
    if s.boss then return ("%s%s|r  >  %s"):format(GOLD, s.instance, s.boss) end
    return GOLD .. s.instance .. "|r"
end

local function Thumb(bar, offset, total, visible)
    if total <= visible then bar:Hide() return end
    bar:Show()
    local h = bar:GetHeight()
    local size = math.max(16, h * visible / total)
    bar.thumb:SetHeight(size)
    bar.thumb:ClearAllPoints()
    bar.thumb:SetPoint("TOP", bar, "TOP", 0, -((h - size) * offset / (total - visible)))
end

local function RefreshTree()
    local maxOff = math.max(0, #flat - TREE_ROWS)
    if state.treeOff > maxOff then state.treeOff = maxOff end
    for i = 1, TREE_ROWS do
        local row, item = win.treeRows[i], flat[i + state.treeOff]
        row.item = item
        if not item then
            row:Hide()
        else
            row:Show()
            local selected = (item.kind == "all" and state.sel == nil) or SameSel(item.sel, state.sel)
            row.highlight:SetShown(selected)
            row.toggle:SetShown(item.kind == "instance")
            if item.kind == "all" then
                row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
                row.text:SetText(("All loot  %s(%d)|r"):format(GREY, item.count))
            elseif item.kind == "instance" then
                row.text:SetPoint("LEFT", row, "LEFT", 22, 0)
                row.text:SetText(("%s%s|r  %s(%d)|r"):format(GOLD, item.name, GREY, item.count))
                row.toggle.glyph:SetText(state.collapsed[item.name] and "+" or "-")
            else
                row.text:SetPoint("LEFT", row, "LEFT", 26, 0)
                row.text:SetText(("%s  %s(%d)|r"):format(item.name, GREY, item.count))
            end
        end
    end
    Thumb(win.treeBar, state.treeOff, #flat, TREE_ROWS)
end

-- The lines of the list: each item, and under an opened one the players who rolled for it.
local function BuildLines()
    lines = {}
    for _, e in ipairs(shown) do
        lines[#lines + 1] = { e = e }
        if state.open[e.id] then
            for _, r in ipairs(e.rolls or {}) do lines[#lines + 1] = { e = e, roll = r } end
            if e.passes and e.passes > 0 then
                lines[#lines + 1] = { e = e, note = ("%d passed"):format(e.passes) }
            end
            if #(e.rolls or {}) == 0 and not (e.passes and e.passes > 0) then
                lines[#lines + 1] = { e = e, note = "No rolls recorded" }
            end
        end
    end
end

local function RefreshList()
    shown = Log().Select(state.sel, state.mine)
    BuildLines()
    local maxOff = math.max(0, #lines - LIST_ROWS)
    if state.listOff > maxOff then state.listOff = maxOff end
    win.heading:SetText(SelText())
    win.count:SetText(("%d drop%s"):format(#shown, #shown == 1 and "" or "s"))
    win.empty:SetShown(#shown == 0)
    for i = 1, LIST_ROWS do
        local row, ln = win.listRows[i], lines[i + state.listOff]
        row.entry = nil
        row.border:SetShown(ln ~= nil and not ln.roll and not ln.note)
        row.icon:SetShown(ln ~= nil and not ln.roll and not ln.note)
        if not ln then
            row:Hide()
        elseif ln.roll or ln.note then
            -- a player who rolled (or a note), under its item
            row:Show()
            row.tint:SetColorTexture(0, 0, 0, 0.3)
            row.name:SetText("")
            row.kind:SetText("")
            row.roll:SetText("")
            row.who:SetText("")
            if ln.roll then
                local r = ln.roll
                local kind, value = RollText(r) or "", ""
                if r.type and CL.ROLL_NAME and CL.ROLL_NAME[r.type] then
                    kind, value = CL.ROLL_NAME[r.type], r.value and tostring(r.value) or ""
                end
                row.sub:SetText(Hex(ClassColor(r.class)) .. ShortName(r.name) .. "|r")
                row.kind:SetText(GREY .. kind .. "|r")
                row.roll:SetText(value)
                row.who:SetText(r.isWinner and (GOLD .. "Winner|r") or "")
            else
                row.sub:SetText(GREY .. ln.note .. "|r")
            end
        else
            local e = ln.e
            row:Show()
            row.entry = e
            row.tint:SetColorTexture(1, 1, 1, state.open[e.id] and 0.07 or 0)
            row.sub:SetText("")
            row.icon:SetTexture(IconOf(e.link))
            local r, g, b = CL.QualityColor(e.quality)
            row.border:SetColorTexture(r or 1, g or 1, b or 1, 1)
            row.name:SetText(e.name or "?")
            row.name:SetTextColor(r or 1, g or 1, b or 1)
            local kind, value, who = W.Columns(e)
            row.kind:SetText(GREY .. kind .. "|r")
            row.roll:SetText(value)
            row.who:SetText(who)
        end
    end
    Thumb(win.listBar, state.listOff, #lines, LIST_ROWS)
end

local function Refresh()
    if not (win and win:IsShown()) then return end
    BuildTree()
    RefreshTree()
    RefreshList()
    win.mineCheck:SetChecked(state.mine)
    win.total:SetText(("%d recorded"):format(Log().Count()))
end
W.Refresh = Refresh

-------------------------------------------------
-- Building the window
-------------------------------------------------
local function Scrollbar(parent, x, y, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(5, height)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.06)
    bar.thumb = bar:CreateTexture(nil, "ARTWORK")
    bar.thumb:SetWidth(5)
    bar.thumb:SetColorTexture(0.4, 0.33, 0.12, 1)
    return bar
end

local function Panel(parent, x, y, w, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(w, h)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.28)
    return p
end

local function Create()
    local f = CreateFrame("Frame", "CleanLootHistory", UIParent, "BackdropTemplate")
    f:SetSize(WIN_W, WIN_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
    f:SetBackdropBorderColor(0.4, 0.33, 0.12, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if point then CL.db.historyPoint = { point, relPoint, x, y } end
    end)
    local p = CL.db.historyPoint
    if type(p) == "table" and p[1] then
        f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    end
    f:SetScript("OnShow", Refresh)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    title:SetText("Loot rolls")
    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    local x = close:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    x:SetPoint("CENTER")
    x:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)

    ---------------- the tree: instances and their bosses
    local left = Panel(f, 10, -TOP, LEFT_W, TREE_ROWS * TREE_H)
    left:EnableMouseWheel(true)
    left:SetScript("OnMouseWheel", function(_, delta)
        state.treeOff = math.max(0, state.treeOff - delta)
        Refresh()
    end)
    f.treeBar = Scrollbar(left, LEFT_W - 6, 0, TREE_ROWS * TREE_H)
    f.treeRows = {}
    for i = 1, TREE_ROWS do
        local row = CreateFrame("Button", nil, left)
        row:SetSize(LEFT_W - 10, TREE_H)
        row:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -(i - 1) * TREE_H)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(0.4, 0.33, 0.12, 0.45)
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.07)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.text:SetJustifyH("LEFT")
        row.text:SetWidth(LEFT_W - 40)
        row.text:SetWordWrap(false)
        row.toggle = CreateFrame("Button", nil, row)
        row.toggle:SetSize(18, TREE_H)
        row.toggle:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.toggle.glyph = row.toggle:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        row.toggle.glyph:SetPoint("CENTER")
        row.toggle:SetScript("OnClick", function()
            local item = row.item
            if item and item.kind == "instance" then
                state.collapsed[item.name] = not state.collapsed[item.name] or nil
                Refresh()
            end
        end)
        row:SetScript("OnClick", function()
            if not row.item then return end
            state.sel = row.item.sel
            state.listOff = 0
            Refresh()
        end)
        f.treeRows[i] = row
    end

    ---------------- the drops of the selection
    f.heading = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.heading:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT_W + 22, -32)
    f.heading:SetJustifyH("LEFT")
    f.count = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -22, -34)
    local function Header(text, x, w, justify)
        local h = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        h:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT_W + 20 + x, -TOP + 14)
        h:SetWidth(w)
        h:SetJustifyH(justify or "LEFT")
        h:SetText(text)
    end
    Header("Item", COL_ITEM, COL_ITEM_W)
    Header("Roll", COL_KIND, COL_KIND_W)
    Header("", COL_ROLL, COL_ROLL_W, "RIGHT")
    Header("Winner", COL_WHO, COL_WHO_W)

    local right = Panel(f, LEFT_W + 20, -TOP, LIST_W + 12, LIST_ROWS * LIST_H)
    right:EnableMouseWheel(true)
    right:SetScript("OnMouseWheel", function(_, delta)
        state.listOff = math.max(0, state.listOff - delta)
        Refresh()
    end)
    f.listBar = Scrollbar(right, LIST_W + 5, 0, LIST_ROWS * LIST_H)
    f.empty = right:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    f.empty:SetPoint("CENTER", right, "CENTER", 0, 0)
    f.empty:SetWidth(LIST_W - 60)
    f.empty:SetText("Nothing here yet. Rolls the game decides, items handed out and loot session awards are listed as they happen.")
    f.listRows = {}
    for i = 1, LIST_ROWS do
        local row = CreateFrame("Button", nil, right)
        row:SetSize(LIST_W, LIST_H)
        row:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -(i - 1) * LIST_H)
        row.tint = row:CreateTexture(nil, "BACKGROUND")
        row.tint:SetAllPoints()
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.06)
        row.border = row:CreateTexture(nil, "BACKGROUND")
        row.border:SetSize(22, 22)
        row.border:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("CENTER", row.border, "CENTER", 0, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local function Cell(font, x, w, justify)
            local c = row:CreateFontString(nil, "ARTWORK", font)
            c:SetPoint("LEFT", row, "LEFT", x, 0)
            c:SetWidth(w)
            c:SetJustifyH(justify or "LEFT")
            c:SetWordWrap(false)
            return c
        end
        row.name = Cell("GameFontHighlight", COL_ITEM, COL_ITEM_W)
        row.sub = Cell("GameFontHighlightSmall", COL_ITEM + 16, COL_ITEM_W - 16)
        row.kind = Cell("GameFontHighlightSmall", COL_KIND, COL_KIND_W)
        row.roll = Cell("GameFontHighlightSmall", COL_ROLL, COL_ROLL_W, "RIGHT")
        row.who = Cell("GameFontHighlightSmall", COL_WHO, COL_WHO_W)
        row:SetScript("OnEnter", function(self) if self.entry then Tooltip(self, self.entry) end end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            local e = self.entry
            if not e then return end
            if e.link and IsControlKeyDown() then
                Preview(e.link)
            elseif e.link and IsShiftKeyDown() then
                InsertLink(e.link)
            else
                state.open[e.id] = not state.open[e.id] or nil
                Refresh()
            end
        end)
        f.listRows[i] = row
    end

    ---------------- the bottom line
    f.mineCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.mineCheck:SetSize(24, 24)
    f.mineCheck:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    f.mineCheck:SetScript("OnClick", function(self)
        state.mine = self:GetChecked() and true or false
        state.listOff, state.treeOff = 0, 0
        Refresh()
    end)
    local mineText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mineText:SetPoint("LEFT", f.mineCheck, "RIGHT", 2, 0)
    mineText:SetText("Only what I won")
    f.total = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.total:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    local erase = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    erase:SetSize(80, 20)
    erase:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    erase:SetText("Erase all")
    erase:SetScript("OnClick", function()
        CL.MasterLoot.Confirmation("Erase the whole record of who won what?", "This cannot be undone.", function()
            Log().Clear()
            state.open = {}
            state.sel = nil
            Refresh()
        end, "Erase")
    end)

    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "CleanLootHistory") end
    f:Hide()
    return f
end

-------------------------------------------------
-- Opening it
-------------------------------------------------
function W.Window() return win end

function W.Select(sel)
    state.sel = sel
    state.listOff = 0
    Refresh()
end

-- Opens on the instance you are in when something was recorded there.
function W.Open()
    if not CL.db then return end
    win = win or Create()
    if not win:IsShown() then
        state.listOff, state.treeOff = 0, 0
        local here = Log().Where()
        state.sel = nil
        for _, inst in ipairs(Log().Tree(state.mine)) do
            if inst.name == here then state.sel = { instance = here } break end
        end
        win:Show()
    end
    Refresh()
end

function W.Toggle()
    if win and win:IsShown() then win:Hide() else W.Open() end
end

-------------------------------------------------
-- /loot, and the game's own window
-------------------------------------------------
local owned = {}   -- SlashCmdList key -> the handler it had before

local function Replacing()
    return CL.db ~= nil and CL.db.historyReplace ~= false
end

local function Handler(msg)
    for _, original in pairs(owned) do
        if not Replacing() and original then original(msg) return end
    end
    W.Toggle()
end

-- /loot opens this window. The game's own handler (when there is one) is kept and called again
-- when the option is off.
function W.InstallSlash()
    local found = false
    if type(SlashCmdList) == "table" then
        for key, fn in pairs(SlashCmdList) do
            if type(key) == "string" and key ~= "CLEANLOOTLOG" and fn ~= Handler then
                for i = 1, 12 do
                    local cmd = rawget(_G, "SLASH_" .. key .. i)
                    if not cmd then break end
                    if type(cmd) == "string" and cmd:lower() == "/loot" and not owned[key] then
                        owned[key] = fn
                        SlashCmdList[key] = Handler
                        found = true
                        break
                    end
                end
            end
        end
    end
    if not found and not owned.CLEANLOOTLOG then
        owned.CLEANLOOTLOG = false
        _G.SLASH_CLEANLOOTLOG1 = "/loot"
        SlashCmdList.CLEANLOOTLOG = Handler
    end
end

-- The game's "Loot Rolls" window pops up on every drop: it is put away while this one replaces it.
local guarded
function W.GuardBlizzard()
    if guarded then return true end
    local f = rawget(_G, "GroupLootHistoryFrame")
    if type(f) ~= "table" or not f.HookScript then return false end
    if f.IsForbidden and f:IsForbidden() then return false end
    local function Away()
        if Replacing() and f:IsShown() then
            C_Timer.After(0, function() if Replacing() and f:IsShown() then f:Hide() end end)
        end
    end
    local ok = pcall(function()
        f:HookScript("OnShow", Away)
        hooksecurefunc(f, "Show", Away)
    end)
    guarded = ok
    if ok then Away() end
    return ok
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")
boot:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        W.InstallSlash()
        C_Timer.After(3, W.GuardBlizzard)
        C_Timer.After(12, W.GuardBlizzard)
    elseif W.GuardBlizzard() then
        self:UnregisterEvent("LOOT_HISTORY_UPDATE_DROP")
    end
end)
