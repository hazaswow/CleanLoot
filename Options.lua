-- Options: a window of our own (/cll), with a page per topic, built from plain
-- widgets with no dependency on Blizzard's option templates beyond the check button
-- and the button. The game's settings only keep a small page that opens it.

local _, CL = ...

local Options = {}
CL.Options = Options

local widgets = {}
Options.widgets = widgets

-------------------------------------------------
-- Widgets
-------------------------------------------------
local function Text(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function Checkbox(parent, label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local fs = cb.Text
    if type(fs) ~= "table" then
        fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    end
    fs:SetText(label)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        Options.Refresh()
    end)
    cb.Sync = function() cb:SetChecked(get() and true or false) end
    return cb
end

-- A flat horizontal slider (a track and a thumb), so it does not depend on any
-- slider template the client may or may not still ship.
local function Slider(parent, label, x, y, min, max, step, fmt, get, set)
    Text(parent, label, x, y)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(220, 16)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 24)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.15, 0.15, 0.15, 1)
    track:SetPoint("LEFT", s, "LEFT", 0, 0)
    track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
    track:SetHeight(4)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.9, 0.75, 0.2, 1)
    thumb:SetSize(8, 16)
    s:SetThumbTexture(thumb)

    local value = Text(parent, "", x + 232, y - 24)
    s:SetScript("OnValueChanged", function(self, v)
        if self.syncing then return end
        v = tonumber(("%.2f"):format(math.floor(v / step + 0.5) * step))
        set(v)
        value:SetText(fmt:format(v))
    end)
    s.Sync = function()
        s.syncing = true
        s:SetValue(get())
        value:SetText(fmt:format(get()))
        s.syncing = false
    end
    return s
end

local function PushButton(parent, label, x, y, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

-- Where to find the author. WoW cannot open a browser, so a click on one of these
-- shows the address in a box to copy (Ctrl+C).
local LINKS = {
    { label = "Twitch", url = "https://www.twitch.tv/hazaswow",
      text = "I stream WoW, come say hi:", textX = 16, buttonX = 168 },
    { label = "Ko-fi", url = "https://ko-fi.com/hazas",
      text = "Help me pay my Claude subscription:", textX = 256, buttonX = 462 },
}

local linkFrame
local function ShowLink(link)
    if not linkFrame then
        local f = CreateFrame("Frame", "CleanLootLinkFrame", UIParent)
        f:SetSize(340, 96)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:EnableMouse(true)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
        f.title = Text(f, "", 14, -12, "GameFontNormal")
        Text(f, "Press Ctrl+C: it copies the link and closes this box.", 14, -68, "GameFontDisableSmall")

        local box = CreateFrame("EditBox", nil, f)
        box:SetSize(312, 22)
        box:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
        box:SetFontObject("ChatFontNormal")
        box:SetAutoFocus(false)
        box:SetTextInsets(4, 4, 0, 0)
        local boxBg = box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints()
        boxBg:SetColorTexture(0.15, 0.15, 0.15, 1)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        box:SetScript("OnEnterPressed", function() f:Hide() end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        -- Ctrl+C (Cmd+C on a Mac) copies the selected address: close once the copy is done
        box:SetScript("OnKeyDown", function(_, key)
            if key ~= "C" then return end
            if (IsControlKeyDown and IsControlKeyDown()) or (IsMetaKeyDown and IsMetaKeyDown()) then
                C_Timer.After(0.15, function() if f:IsShown() then f:Hide() end end)
            end
        end)
        box:SetScript("OnTextChanged", function(self, user)   -- read-only: put the address back
            if user and f.url then self:SetText(f.url) self:HighlightText() end
        end)
        f.box = box
        f:SetScript("OnHide", function() box:ClearFocus() end)
        linkFrame = f
    end
    linkFrame.url = link.url
    linkFrame.title:SetText(link.label)
    linkFrame.box:SetText(link.url)
    linkFrame:Show()
    linkFrame.box:SetFocus()
    linkFrame.box:HighlightText()
end

-- A key field for a binding: click, press a key (modifiers count), Esc cancels,
-- right-click clears. The same binding as the one in the game's Key Bindings page.
local function KeyField(parent, action, x, y, width)
    local K = CL.Keyboard
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 24)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:RegisterForClicks("AnyUp")
    local capturing

    local function Show()
        btn:SetText(capturing and "Press a key..." or K.KeyText(action) or "Not bound")
    end
    local function Stop()
        capturing = false
        btn:EnableKeyboard(false)
        btn:EnableGamePadButton(false)
        Show()
    end

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            K.Unbind(action)
            Stop()
            return
        end
        capturing = true
        btn:EnableKeyboard(true)
        btn:EnableGamePadButton(true)   -- a controller button counts as a key
        if btn.SetPropagateKeyboardInput then btn:SetPropagateKeyboardInput(false) end
        Show()
    end)
    local function OnKey(_, key)
        if K.IsModifier(key) then return end
        if key ~= "ESCAPE" then K.Bind(K.Combo(key), action) end
        Stop()
    end
    btn:SetScript("OnKeyDown", OnKey)
    btn:SetScript("OnGamePadButtonDown", OnKey)
    btn:SetScript("OnHide", function() if capturing then Stop() end end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Click, then press a key or a controller button", 1, 1, 1)
        GameTooltip:AddLine("Right-click clears it.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:EnableKeyboard(false)
    btn:EnableGamePadButton(false)
    btn.Sync = function() if capturing then Stop() else Show() end end
    return btn
end

-- A checkbox that only means something while controller mode is on: greyed out otherwise.
local function DependsOnKeyboard(cb)
    local sync = cb.Sync
    cb.Sync = function()
        sync()
        if CL.db.keyboardEnabled then cb:Enable() else cb:Disable() end
    end
    return cb
end

-------------------------------------------------
-- Panel
-------------------------------------------------
function Options.Refresh()
    for _, w in pairs(widgets) do
        if w.Sync then w.Sync() end
    end
end

local function SetDirection(direction)
    CL.db.growDirection = direction
    CL.RollFrames.Layout()
end

local function Build(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel.name = "General"
    Options.panel = panel

    Text(panel, "CleanLoot", 16, -16, "GameFontNormalLarge")
    Text(panel, "v" .. CL.Version(), 110, -20, "GameFontDisableSmall")

    Text(panel, "Roll frames", 16, -56, "GameFontNormalLarge")
    Text(panel, "Stacking direction", 16, -84)
    widgets.down = Checkbox(panel, "Downwards", 16, -102,
        function() return CL.db.growDirection ~= "UP" end,
        function() SetDirection("DOWN") end)
    widgets.up = Checkbox(panel, "Upwards (first at the bottom)", 16, -126,
        function() return CL.db.growDirection == "UP" end,
        function() SetDirection("UP") end)
    widgets.scale = Slider(panel, "Frame scale", 16, -166, 0.8, 1.5, 0.05, "%.2f",
        function() return CL.db.frameScale or CL.DEFAULT_SCALE end,
        function(v) CL.db.frameScale = v CL.RollFrames.Layout() end)
    widgets.native = Checkbox(panel, "Hide Blizzard's own roll frames", 16, -216,
        function() return CL.db.hideNative end,
        function(v) CL.Native.SetHidden(v) end)
    widgets.chat = Checkbox(panel, "Hide roll messages from the chat (winners stay)", 16, -242,
        function() return CL.db.hideRollSpam end,
        function(v) CL.db.hideRollSpam = v end)
    widgets.lock = Checkbox(panel, "Lock the frames' and popup's position", 16, -268,
        function() return CL.db.locked end,
        function(v) CL.db.locked = v end)
    widgets.autoConfirm = Checkbox(panel, "Auto-accept bind-on-pickup prompts", 16, -294,
        function() return CL.db.autoConfirm end,
        function(v) CL.db.autoConfirm = v end)
    widgets.reset = PushButton(panel, "Reset position", 20, -326, 140, function()
        CL.RollFrames.ResetPosition()
        CL.Results.ResetPosition()
    end)

    Text(panel, "Minimap", 16, -368, "GameFontNormalLarge")
    widgets.minimap = Checkbox(panel, "Hide the minimap button", 16, -392,
        function() return CL.db.minimap and CL.db.minimap.hide end,
        function(v) CL.MinimapButton.SetHidden(v) end)

    -- second column, beside the short rows of the first
    Text(panel, "Loot toasts", 330, -56, "GameFontNormalLarge")
    Text(panel, "The \"You won\" banner Blizzard shows.", 330, -84, "GameFontDisableSmall")
    widgets.toastHide = Checkbox(panel, "Hide it", 330, -102,
        function() return CL.db.hideToasts end,
        function(v) CL.Toasts.SetHidden(v) end)
    widgets.toastHideInPopup = Checkbox(panel, "Hide it only for popup items", 330, -126,
        function() return CL.db.hideToastsInPopup end,
        function(v) CL.Toasts.SetHiddenInPopup(v) end)
    widgets.toastScale = Slider(panel, "Size", 330, -164, 0.5, 1.5, 0.05, "%.2f",
        function() return CL.db.toastScale or 1 end,
        function(v) CL.Toasts.SetScale(v) end)
    widgets.toastMove = PushButton(panel, "Move", 334, -214, 80, function() CL.Toasts.ToggleMover() end)
    widgets.toastReset = PushButton(panel, "Reset", 420, -214, 80, function() CL.Toasts.ResetPosition() end)

    Text(panel, "Winner popup", 330, -260, "GameFontNormalLarge")
    Text(panel, "Who won each roll and with what; your own roll too.", 330, -288, "GameFontDisableSmall")
    widgets.results = Checkbox(panel, "Show it", 330, -306,
        function() return CL.db.showResults end,
        function(v)
            CL.db.showResults = v
            if not v then CL.Results.Clear() end
        end)
    widgets.resultsDown = Checkbox(panel, "Stack downwards", 330, -330,
        function() return CL.Results.Direction() ~= "UP" end,
        function() CL.Results.SetDirection("DOWN") end)
    widgets.resultsUp = Checkbox(panel, "Stack upwards", 470, -330,
        function() return CL.Results.Direction() == "UP" end,
        function() CL.Results.SetDirection("UP") end)
    widgets.waiting = Checkbox(panel, "Show who hasn't rolled yet", 330, -354,
        function() return CL.db.showWaiting end,
        function(v)
            CL.db.showWaiting = v
            CL.Results.RefreshWaiting(true)
        end)
    widgets.resultsMove = PushButton(panel, "Move", 334, -388, 80, function() CL.Results.ToggleSample() end)
    widgets.resultsReset = PushButton(panel, "Reset", 420, -388, 80, function() CL.Results.ResetPosition() end)

    Text(panel, "Testing", 330, -430, "GameFontNormalLarge")
    Text(panel, "Fake loot rolls with a simulated group.", 330, -456, "GameFontDisableSmall")
    widgets.sim = PushButton(panel, "Simulate 3 drops", 334, -478, 120, function() CL.Sim.Start(3) end)
    widgets.simColors = PushButton(panel, "Each colour", 458, -478, 100, function() CL.Sim.Colors() end)
    widgets.simClear = PushButton(panel, "Clear", 562, -478, 64, function() CL.Sim.Clear() end)

    -- a discreet corner: who makes this, and where to find them
    for i, link in ipairs(LINKS) do
        Text(panel, link.text, link.textX, -540, "GameFontDisableSmall")
        widgets["link" .. i] = PushButton(panel, link.label, link.buttonX, -535, 70, function() ShowLink(link) end)
    end

    -- values may have changed through a slash command since the panel was built
    panel:SetScript("OnShow", Options.Refresh)
    return panel
end

-- The page of controller mode: the switch, the inspection tooltip and the keys.
local function BuildController(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel.name = "Controller mode"
    Options.controllerPanel = panel

    Text(panel, "Controller mode", 16, -16, "GameFontNormalLarge")
    Text(panel, "Play the loot rolls with a gamepad or the keyboard: select a roll, then answer Need, Greed or Pass.",
        16, -44, "GameFontDisableSmall")
    widgets.keyboard = Checkbox(panel, "Enable controller mode", 16, -72,
        function() return CL.db.keyboardEnabled end,
        function(v) CL.Keyboard.SetEnabled(v) end)

    Text(panel, "Inspection", 16, -116, "GameFontNormalLarge")
    widgets.inspect = DependsOnKeyboard(Checkbox(panel, "Show an item inspection tooltip", 16, -142,
        function() return CL.db.keyboardInspect end,
        function(v) CL.Keyboard.SetInspect(v) end))
    widgets.inspectSticky = DependsOnKeyboard(Checkbox(panel, "Keep it on the selected roll (no mouse)", 16, -166,
        function() return CL.db.keyboardInspectSticky end,
        function(v) CL.Keyboard.SetInspectSticky(v) end))
    widgets.pawn = DependsOnKeyboard(Checkbox(panel, "Include Pawn upgrade info", 16, -190,
        function() return CL.db.keyboardPawn end,
        function(v) CL.Keyboard.SetPawn(v) end))
    local pawnSync = widgets.pawn.Sync
    widgets.pawn.Sync = function()
        pawnSync()
        if not rawget(_G, "PawnUpdateTooltip") then widgets.pawn:Disable() end  -- nothing to include without Pawn
    end
    widgets.inspectLeft = DependsOnKeyboard(Checkbox(panel, "Show it on the left side", 16, -214,
        function() return CL.db.keyboardInspectSide == "LEFT" end,
        function(v) CL.Keyboard.SetSide(v and "LEFT" or "RIGHT") end))

    -- the keys of controller mode, set here instead of hunting for them in Key Bindings
    Text(panel, "Key bindings", 16, -262, "GameFontNormalLarge")
    Text(panel, "Click a field, then press a key or a controller button. Right-click clears it.",
        16, -290, "GameFontDisableSmall")
    for i, entry in ipairs(CL.Keyboard.ACTIONS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x, y = 16 + col * 290, -316 - row * 32
        Text(panel, entry.label, x, y - 5, "GameFontNormalSmall")
        widgets["key" .. i] = KeyField(panel, entry.action, x + 62, y, 150)
    end
    Text(panel, "The same actions are in the game's Key Bindings page, under CleanLoot, and work as commands:",
        16, -420, "GameFontDisableSmall")
    Text(panel, "/cll next, /cll previous, /cll inspect, /cll need, /cll greed, /cll pass", 16, -438, "GameFontDisableSmall")

    panel:SetScript("OnShow", Options.Refresh)
    return panel
end

-- A one-line text box with a plain dark background (no Blizzard template).
local function TextBox(parent, x, y, width)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 22)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetFontObject("ChatFontNormal")
    box:SetAutoFocus(false)
    box:SetTextInsets(4, 4, 0, 0)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

-- A shift-click on an item (bags, loot, chat, the Dungeon Journal) goes into `box` while it
-- has the focus. The client's function that puts a link in the chat line is
-- ChatFrameUtil.InsertLink (ChatEdit_InsertLink on older clients): hooking it is how the
-- addons already installed on Forever do it. Hook only one of them, so a link is not
-- inserted twice.
local function TakeLinks(box)
    if not rawget(_G, "hooksecurefunc") then return end
    local function insert(text)
        if type(text) == "string" and box:HasFocus() then box:Insert(text) end
    end
    local util = rawget(_G, "ChatFrameUtil")
    if type(util) == "table" and type(util.InsertLink) == "function" then
        hooksecurefunc(util, "InsertLink", insert)
    elseif rawget(_G, "ChatEdit_InsertLink") then
        hooksecurefunc("ChatEdit_InsertLink", insert)
    end
end

local AUTO_ROWS = 10  -- item rules shown at once; the mouse wheel scrolls the rest

-- The page of auto-roll: the switch, a rule per quality, and the item rules.
local function BuildAutoRoll(parent)
    local AR = CL.AutoRoll
    local panel = CreateFrame("Frame", nil, parent)
    panel.name = "Auto-roll"
    Options.autoRollPanel = panel

    Text(panel, "Auto-roll", 16, -16, "GameFontNormalLarge")
    Text(panel, "Answer a roll for you. If an answer is not possible, the roll stays yours.", 16, -44, "GameFontDisableSmall")
    widgets.autoOn = Checkbox(panel, "Enable auto-roll", 16, -72,
        function() return CL.db.autoRollEnabled end,
        function(v) CL.db.autoRollEnabled = v end)
    widgets.autoSay = Checkbox(panel, "Tell me in the chat when it answers", 16, -96,
        function() return CL.db.autoRollSay end,
        function(v) CL.db.autoRollSay = v end)

    -- by quality: rolls start at green, so there is no white or grey row
    Text(panel, "By quality", 16, -140, "GameFontNormalLarge")
    Text(panel, "An item rule (right) wins over these.", 16, -166, "GameFontDisableSmall")
    local choices = { { "Off", nil }, { "Need", CL.ROLL.NEED }, { "Greed", CL.ROLL.GREED }, { "Pass", CL.ROLL.PASS } }
    local xs = { 86, 138, 196, 254 }
    for i, quality in ipairs(AR.QUALITIES) do
        local y = -190 - (i - 1) * 30
        local label = Text(panel, AR.QualityName(quality), 16, y - 6, "GameFontHighlightSmall")
        local r, g, b = CL.QualityColor(quality)
        label:SetTextColor(r, g, b)
        for k, choice in ipairs(choices) do
            local rollType = choice[2]
            widgets["autoQ" .. quality .. "_" .. k] = Checkbox(panel, choice[1], xs[k], y,
                function() return AR.QualityRule(quality) == rollType end,
                function() AR.SetQuality(quality, rollType) end)
        end
    end
    Text(panel, "Bind-on-pickup items only roll for you when", 16, -330, "GameFontDisableSmall")
    Text(panel, "\"Auto-accept bind-on-pickup prompts\" is ticked.", 16, -346, "GameFontDisableSmall")
    Text(panel, "The same rules work as commands:", 16, -388, "GameFontDisableSmall")
    Text(panel, "/cll auto need|greed|pass [item]", 16, -406, "GameFontDisableSmall")
    Text(panel, "/cll auto remove [item]   /cll auto list", 16, -424, "GameFontDisableSmall")

    -- item rules, second column
    Text(panel, "Item rules", 330, -56, "GameFontNormalLarge")
    Text(panel, "Right-click Need, Greed or Pass on a roll to add one,", 330, -84, "GameFontDisableSmall")
    Text(panel, "or paste an item link (or its id) here and pick the answer:", 330, -100, "GameFontDisableSmall")
    local box = TextBox(panel, 334, -122, 290)
    widgets.autoBox = box
    TakeLinks(box)
    local function Add(rollType)
        local text = box:GetText()
        local id = AR.ItemID(text)
        if not id then
            CL.Print("paste an item link, or type an item id.")
            return
        end
        AR.SetItem(id, rollType, AR.NameOf(id, text))
        box:SetText("")
        box:ClearFocus()
    end
    widgets.autoAddNeed = PushButton(panel, "Add Need", 334, -150, 86, function() Add(CL.ROLL.NEED) end)
    widgets.autoAddGreed = PushButton(panel, "Add Greed", 424, -150, 86, function() Add(CL.ROLL.GREED) end)
    widgets.autoAddPass = PushButton(panel, "Add Pass", 514, -150, 86, function() Add(CL.ROLL.PASS) end)

    local list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", panel, "TOPLEFT", 330, -190)
    list:SetSize(300, AUTO_ROWS * 26)
    list:EnableMouseWheel(true)
    local offset = 0
    local rows = {}
    for i = 1, AUTO_ROWS do
        local y = -(i - 1) * 26
        local row = {}
        row.name = Text(list, "", 4, y - 5, "GameFontHighlightSmall")
        row.name:SetWidth(170)
        row.name:SetWordWrap(false)
        row.roll = PushButton(list, "", 178, y, 60, function()
            if row.id then AR.SetItem(row.id, AR.NextRoll(row.rule), row.itemName) end
        end)
        row.remove = PushButton(list, "X", 242, y, 28, function()
            if row.id then AR.RemoveItem(row.id) end
        end)
        rows[i] = row
    end
    local count = Text(panel, "", 330, -190 - AUTO_ROWS * 26 - 6, "GameFontDisableSmall")
    list.Sync = function()
        local rules = AR.List()
        local maxOffset = math.max(0, #rules - AUTO_ROWS)
        if offset > maxOffset then offset = maxOffset end
        for i, row in ipairs(rows) do
            local rule = rules[i + offset]
            if rule then
                row.id, row.rule, row.itemName = rule.id, rule.roll, rule.name
                row.name:SetText(rule.name)
                row.roll:SetText(CL.ROLL_NAME[rule.roll])
                row.name:Show() row.roll:Show() row.remove:Show()
            else
                row.id = nil
                row.name:SetText("")
                row.name:Hide() row.roll:Hide() row.remove:Hide()
            end
        end
        if #rules == 0 then
            count:SetText("No item rule yet.")
        elseif #rules > AUTO_ROWS then
            count:SetText(("%d rules, scroll for more. Click an answer to change it."):format(#rules))
        else
            count:SetText(("%d rule%s. Click an answer to change it."):format(#rules, #rules == 1 and "" or "s"))
        end
    end
    list:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta)
        list.Sync()
    end)
    widgets.autoList = list

    panel:SetScript("OnShow", Options.Refresh)
    return panel
end

local WATCH_ROWS = 10  -- watched items shown at once; the mouse wheel scrolls the rest

-- The page of the watchlist: items to be reminded of, each with an optional note.
local function BuildWatchlist(parent)
    local WL, AR = CL.Watchlist, CL.AutoRoll
    local panel = CreateFrame("Frame", nil, parent)
    panel.name = "Watchlist"
    Options.watchPanel = panel

    Text(panel, "Watchlist", 16, -16, "GameFontNormalLarge")
    Text(panel, "Items you want to be reminded of. When one drops, its roll frame pulses.", 16, -44, "GameFontDisableSmall")
    widgets.watchOn = Checkbox(panel, "Highlight watched items on the roll frames", 16, -72,
        function() return CL.db.watchEnabled end,
        function(v)
            CL.db.watchEnabled = v
            CL.RollFrames.RefreshWatch()
        end)

    Text(panel, "Add an item", 16, -116, "GameFontNormalLarge")
    Text(panel, "Paste an item link (shift-click it here) or its id:", 16, -144, "GameFontDisableSmall")
    local box = TextBox(panel, 20, -164, 290)
    widgets.watchBox = box
    Text(panel, "A note for yourself (optional):", 16, -196, "GameFontDisableSmall")
    local noteBox = TextBox(panel, 20, -216, 290)
    noteBox:SetMaxLetters(WL.MAX_NOTE)
    widgets.watchNoteBox = noteBox
    TakeLinks(box)
    widgets.watchAdd = PushButton(panel, "Add to the watchlist", 20, -248, 170, function()
        local text = box:GetText()
        local id = WL.ItemID(text)
        if not id then
            CL.Print("paste an item link, or type an item id.")
            return
        end
        local note = noteBox:GetText()
        WL.Add(id, AR.NameOf(id, text), note ~= "" and note or nil)
        box:SetText("")
        noteBox:SetText("")
        box:ClearFocus()
        noteBox:ClearFocus()
    end)
    Text(panel, "The same from the chat:", 16, -300, "GameFontDisableSmall")
    Text(panel, "/cll watch [item] [note]", 16, -318, "GameFontDisableSmall")
    Text(panel, "/cll watch note [item] <text>", 16, -336, "GameFontDisableSmall")
    Text(panel, "/cll watch remove [item]   /cll watch list", 16, -354, "GameFontDisableSmall")
    Text(panel, "/cll sim always drops one watched item, to try it.", 16, -388, "GameFontDisableSmall")

    Text(panel, "Watched items", 330, -56, "GameFontNormalLarge")
    local list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", panel, "TOPLEFT", 330, -90)
    list:SetSize(300, WATCH_ROWS * 26)
    list:EnableMouseWheel(true)
    local offset = 0
    local rows = {}
    for i = 1, WATCH_ROWS do
        local y = -(i - 1) * 26
        local row = {}
        row.name = Text(list, "", 4, y - 5, "GameFontHighlightSmall")
        row.name:SetWidth(120)
        row.name:SetWordWrap(false)
        row.note = TextBox(list, 128, y, 134)
        row.note:SetMaxLetters(WL.MAX_NOTE)
        row.note:SetScript("OnEditFocusLost", function(self)
            if row.id then WL.SetNote(row.id, self:GetText()) end
        end)
        row.remove = PushButton(list, "X", 266, y, 28, function()
            if row.id then WL.Remove(row.id) end
        end)
        rows[i] = row
    end
    local count = Text(panel, "", 330, -90 - WATCH_ROWS * 26 - 6, "GameFontDisableSmall")
    list.Sync = function()
        local items = WL.List()
        local maxOffset = math.max(0, #items - WATCH_ROWS)
        if offset > maxOffset then offset = maxOffset end
        for i, row in ipairs(rows) do
            local item = items[i + offset]
            if item then
                row.id = item.id
                row.name:SetText(item.name)
                row.note:SetText(item.note)
                row.name:Show() row.note:Show() row.remove:Show()
            else
                row.id = nil
                row.name:SetText("")
                row.note:SetText("")
                row.name:Hide() row.note:Hide() row.remove:Hide()
            end
        end
        if #items == 0 then
            count:SetText("Nothing watched yet.")
        elseif #items > WATCH_ROWS then
            count:SetText(("%d items, scroll for more. Type in a note to change it."):format(#items))
        else
            count:SetText(("%d item%s. Type in a note to change it."):format(#items, #items == 1 and "" or "s"))
        end
    end
    list:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta)
        list.Sync()
    end)
    widgets.watchList = list

    panel:SetScript("OnShow", Options.Refresh)
    return panel
end

-------------------------------------------------
-- The window
-------------------------------------------------
-- CleanLoot has a window of its own, not a page in the game's settings: that one is modal,
-- so nothing else (the bags, the Dungeon Journal, a chat link to shift-click) could stay
-- open beside it. This one is a plain movable frame; Esc closes it like any other.
local WINDOW_W, WINDOW_H = 680, 640

local PAGES = {
    { key = "general",    label = "General",         width = 90,  build = Build },
    { key = "controller", label = "Controller mode", width = 130, build = BuildController },
    { key = "auto",       label = "Auto-roll",       width = 90,  build = BuildAutoRoll },
    { key = "watch",      label = "Watchlist",       width = 90,  build = BuildWatchlist },
}
Options.pages = {}   -- key -> { panel =, tab = }

local function Fill(frame, r, g, b, a, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

local function Border(frame, r, g, b, a)
    local function edge(from, to, width, height)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a)
        t:SetPoint(from)
        t:SetPoint(to)
        if width then t:SetWidth(width) else t:SetHeight(height) end
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1)
end

local function SelectPage(key)
    for _, def in ipairs(PAGES) do
        local page = Options.pages[def.key]
        local on = def.key == key
        if on then page.panel:Show() else page.panel:Hide() end
        page.tab.bg:SetColorTexture(on and 0.2 or 0.1, on and 0.18 or 0.1, on and 0.1 or 0.12, 1)
        page.tab.label:SetTextColor(on and 1 or 0.65, on and 0.82 or 0.65, on and 0 or 0.65)
        if on then page.tab.line:Show() else page.tab.line:Hide() end
    end
    Options.current = key
end

function Options.CurrentPage() return Options.current end

local function SavePosition(frame)
    local point, _, relPoint, x, y = frame:GetPoint()
    if point then CL.db.optionsPoint = { point, relPoint, x, y } end
end

local function CreateWindow()
    local f = CreateFrame("Frame", "CleanLootOptions", UIParent)
    f:SetSize(WINDOW_W, WINDOW_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    local p = CL.db.optionsPoint
    if type(p) == "table" and p[1] then
        f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
    -- a small screen: shrink the window to fit
    local screen = UIParent:GetHeight()
    if type(screen) == "number" and screen > 0 and screen < WINDOW_H + 60 then
        f:SetScale(math.max(0.6, (screen - 60) / WINDOW_H))
    end
    Fill(f, 0.06, 0.06, 0.08, 0.97)
    Border(f, 0.4, 0.33, 0.12, 1)

    Text(f, "CleanLoot", 16, -10, "GameFontNormalLarge")
    Text(f, "v" .. CL.Version(), 112, -15, "GameFontDisableSmall")

    local close = CreateFrame("Button", nil, f)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    local x = close:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    x:SetPoint("CENTER")
    x:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -66)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    f.content = content

    local x0 = 10
    for _, def in ipairs(PAGES) do
        local tab = CreateFrame("Button", nil, f)
        tab:SetSize(def.width, 24)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -36)
        x0 = x0 + def.width + 4
        tab.bg = Fill(tab, 0.1, 0.1, 0.12, 1)
        tab.line = tab:CreateTexture(nil, "ARTWORK")
        tab.line:SetColorTexture(0.9, 0.75, 0.2, 1)
        tab.line:SetPoint("BOTTOMLEFT")
        tab.line:SetPoint("BOTTOMRIGHT")
        tab.line:SetHeight(2)
        tab.label = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        tab.label:SetPoint("CENTER")
        tab.label:SetText(def.label)
        tab:SetScript("OnClick", function() SelectPage(def.key) end)

        local panel = def.build(content)
        panel:SetAllPoints(content)
        panel:Hide()
        Options.pages[def.key] = { panel = panel, tab = tab }
    end
    SelectPage("general")

    -- Esc closes it, like the game's own windows
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "CleanLootOptions")
    end
    f:Hide()
    Options.window = f   -- only once it is whole: a page that failed to build leaves no half window
    return f
end

-- The game's own settings keep a page, so the addon stays listed there: it points at the window.
local function CloseGameSettings()
    local panel = rawget(_G, "SettingsPanel")
    if panel and panel.Close then pcall(panel.Close, panel) end
end

local function BuildSettingsPage()
    local panel = CreateFrame("Frame")
    panel.name = "CleanLoot"
    Options.settingsPanel = panel
    Text(panel, "CleanLoot", 16, -16, "GameFontNormalLarge")
    Text(panel, "v" .. CL.Version(), 110, -20, "GameFontDisableSmall")
    Text(panel, "CleanLoot has a window of its own, so the bags, the journal or the chat", 16, -56, "GameFontHighlightSmall")
    Text(panel, "can stay open beside it. Open it with /cll, a right-click on the minimap", 16, -74, "GameFontHighlightSmall")
    Text(panel, "button, or this button:", 16, -92, "GameFontHighlightSmall")
    widgets.settingsOpen = PushButton(panel, "Open CleanLoot options", 20, -122, 190, function()
        CloseGameSettings()
        Options.Open()
    end)
    return panel
end

function Options.Setup()
    CreateWindow()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local panel = BuildSettingsPage()
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        Options.category = category
    end
    Options.Refresh()
end

-- Opens the window (on a page when one is named: "general", "controller", "auto", "watch").
function Options.Open(key)
    if not Options.window then
        CL.Print("the options window is not available.")
        return
    end
    if key and Options.pages[key] then SelectPage(key) end
    Options.window:Show()
    Options.Refresh()
end

-- /cll and the minimap button: open it, or close it when it is already open.
function Options.Toggle()
    if Options.window and Options.window:IsShown() then
        Options.window:Hide()
    else
        Options.Open()
    end
end

function Options.OpenController() Options.Open("controller") end
function Options.OpenAutoRoll() Options.Open("auto") end
function Options.OpenWatchlist() Options.Open("watch") end
