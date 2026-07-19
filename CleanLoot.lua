-- CleanLoot
-- Standalone reskin of the group loot roll frames (Need/Greed/Disenchant/Pass).
-- No ElvUI dependency. Compatible with 3.3.5 (Ascension / Conquest of Azeroth).

local ADDON_NAME = ...

CleanLootDB = CleanLootDB or {}

-------------------------------------------------
-- Localization
-------------------------------------------------
-- enUS is the reference (fallback) locale. Any key missing from a locale
-- automatically falls back to English through the metatable.
local LOCALES = {
    enUS = {
        TEST_ITEM        = "Test item",
        TOOLTIP_NOBODY   = "Nobody yet",
        OPT_TITLE        = "CleanLoot - Options",
        OPT_STACK_DIR    = "Stacking direction",
        OPT_GROW_UP      = "Upwards (1st at bottom)",
        OPT_GROW_DOWN    = "Downwards (Blizzard default)",
        OPT_STYLE        = "Visual style",
        OPT_SKIN_CLASSIC = "Improved classic",
        OPT_SKIN_ELVUI   = "ElvUI inspired",
        OPT_CONFIRM      = "Confirmations",
        OPT_NO_CONFIRM   = "Skip popups (roll/BoP)",
        OPT_SIMPLE_DEL   = "Simple Delete confirmation",
        OPT_WIN_RECAP    = "Show roll winners recap",
        OPT_SCALE        = "Frame scale",
        MSG_LOOTSPAM_ON  = "the '%s' interface option was enabled (required for the winners recap and the roll tooltips).",
        WINS_TITLE       = "Roll winners",
        MSG_TEST_OPEN    = "test mode + options opened. Drag the window with left click, type /cll stop when done.",
        MSG_TEST_STOP    = "test mode disabled, position saved.",
        MSG_RESET        = "position reset to default.",
        MSG_DEBUG_ON     = "debug mode enabled.",
        MSG_DEBUG_OFF    = "debug mode disabled.",
        HELP_HEADER      = "available commands:",
        HELP_TEST        = "  /cll test      - show a dummy window to reposition + options",
        HELP_STOP        = "  /cll stop      - hide the test window and save position",
        HELP_RESET       = "  /cll reset     - reset position to default",
        HELP_OPTIONS     = "  /cll options   - open the options panel only",
        HELP_DEBUGMODE   = "  /cll debugmode - toggle diagnostic messages (for bug reports)",
        HELP_DEBUG       = "  /cll debug     - diagnose loot frames on this client",
        HELP_SCAN        = "  /cll scan      - list ALL regions of GroupLootFrame1",
        ERR_GENERIC      = "error in %s (%s)",
        DIAG_INCOMPLETE  = "%s incomplete at display time (missing: %s)",
        DIAG_TEST_STATE  = "test mode - IsShown=%s IsVisible=%s size=%dx%d anchored=%s",
        DBG_NOCONFIRM    = "  Skip popups (roll/BoP): %s",
        DBG_FOUND        = "  %s: found (visible=%s, size=%dx%d, anchored=%s)",
        DBG_MISSING      = "  %s: |cffff0000NOT FOUND|r",
        SCAN_HEADER      = "regions of GroupLootFrame1 (run during a real roll for best results):",
        SCAN_NOFRAME     = "GroupLootFrame1 not found.",
    },
    frFR = {
        TEST_ITEM        = "Objet de test",
        TOOLTIP_NOBODY   = "Personne pour l'instant",
        OPT_TITLE        = "CleanLoot - Options",
        OPT_STACK_DIR    = "Direction d'empilement",
        OPT_GROW_UP      = "Vers le haut (1er en bas)",
        OPT_GROW_DOWN    = "Vers le bas (defaut Blizzard)",
        OPT_STYLE        = "Style visuel",
        OPT_SKIN_CLASSIC = "Classique ameliore",
        OPT_SKIN_ELVUI   = "Inspire d'ElvUI",
        OPT_CONFIRM      = "Confirmations",
        OPT_NO_CONFIRM   = "Ignorer les popups (roll/BoP)",
        OPT_SIMPLE_DEL   = "Confirmation simple pour Delete",
        OPT_WIN_RECAP    = "Recap des gagnants de roll",
        OPT_SCALE        = "Echelle des fenetres",
        MSG_LOOTSPAM_ON  = "l'option d'interface '%s' a ete activee (necessaire pour le recap des gagnants et les tooltips de roll).",
        WINS_TITLE       = "Gains de roll",
        MSG_TEST_OPEN    = "mode test + options ouverts. Glisse la fenetre avec le clic gauche, tape /cll stop quand t'as fini.",
        MSG_TEST_STOP    = "mode test desactive, position sauvegardee.",
        MSG_RESET        = "position reinitialisee (position par defaut).",
        MSG_DEBUG_ON     = "mode debug active.",
        MSG_DEBUG_OFF    = "mode debug desactive.",
        HELP_HEADER      = "commandes disponibles:",
        HELP_TEST        = "  /cll test      - affiche une fenetre factice a repositionner + options",
        HELP_STOP        = "  /cll stop      - cache la fenetre de test et sauvegarde la position",
        HELP_RESET       = "  /cll reset     - reinitialise la position par defaut",
        HELP_OPTIONS     = "  /cll options   - ouvre uniquement le panneau d'options",
        HELP_DEBUGMODE   = "  /cll debugmode - active/desactive les messages de diagnostic (pour rapporter un bug)",
        HELP_DEBUG       = "  /cll debug     - diagnostique les frames de loot sur ce client",
        HELP_SCAN        = "  /cll scan      - liste TOUTES les regions de GroupLootFrame1",
        -- Diagnostic output keys (ERR_GENERIC, DIAG_*, DBG_*, SCAN_*) are
        -- intentionally NOT translated: they fall back to English so that
        -- bug reports are readable regardless of the client language.
    },
}

local L = setmetatable(LOCALES[GetLocale()] or {}, { __index = LOCALES.enUS })

local MSG = "|cff33ff99CleanLoot|r: "
local ERR = "|cffff0000CleanLoot|r: "
local DIAG = "|cffff9900CleanLoot|r: "

-- Real error messages always stay visible (useful for support).
-- Purely diagnostic messages only show in debug mode
-- (/cll debugmode), to avoid spamming an end user's chat.
local function PrintError(context, err)
    print(ERR .. L.ERR_GENERIC:format(tostring(context), tostring(err)))
end

local function PrintDiag(text)
    if CleanLootDB.debugMode then
        print(DIAG .. text)
    end
end

-------------------------------------------------
-- Backdrop compatibility
-------------------------------------------------
-- Three cases encountered depending on the client:
--   1. Native, working SetBackdrop (the 3.3.5 norm)        -> nothing to do
--   2. SetBackdrop missing, or present but silent (no-op)  -> manual shim
--   3. Newer client requiring BackdropTemplateMixin        -> mixin
-- Case 2 is detectable: after a successful SetBackdrop, GetBackdrop must
-- return the definition. If it does not, we replace the frame's backdrop
-- methods with a manual-texture equivalent (CreateTexture works everywhere;
-- verified on the affected clients).
local TEST_BACKDROP = { bgFile = "Interface\\ChatFrame\\ChatFrameBackground" }

local function InstallBackdropShim(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)

    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local tex = frame:CreateTexture(nil, "BORDER")
        if side == "TOP" then
            tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            tex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            tex:SetHeight(1)
        elseif side == "BOTTOM" then
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            tex:SetHeight(1)
        elseif side == "LEFT" then
            tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            tex:SetWidth(1)
        else
            tex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            tex:SetWidth(1)
        end
        table.insert(edges, tex)
    end

    frame.__shimBg = bg
    frame.__shimEdges = edges

    frame.SetBackdrop = function(self, def)
        if def then
            self.__shimBg:Show()
            for _, e in ipairs(self.__shimEdges) do e:Show() end
        else
            self.__shimBg:Hide()
            for _, e in ipairs(self.__shimEdges) do e:Hide() end
        end
    end
    frame.SetBackdropColor = function(self, r, g, b, a)
        self.__shimBg:SetTexture(r or 0, g or 0, b or 0, a or 1)
    end
    frame.SetBackdropBorderColor = function(self, r, g, b, a)
        for _, e in ipairs(self.__shimEdges) do
            e:SetTexture(r or 0, g or 0, b or 0, a or 1)
        end
    end
end

local function EnsureBackdropSupport(frame)
    if not frame or frame.__cleanLootBackdropReady then return end
    frame.__cleanLootBackdropReady = true

    if frame.SetBackdrop then
        if BackdropTemplateMixin and Mixin then
            pcall(Mixin, frame, BackdropTemplateMixin)
        end
        -- Real check: a SetBackdrop that sets nothing is silent.
        local ok = pcall(frame.SetBackdrop, frame, TEST_BACKDROP)
        if ok and frame.GetBackdrop and frame:GetBackdrop() then
            pcall(frame.SetBackdrop, frame, nil)
            return -- native backdrop works
        end
    end

    InstallBackdropShim(frame)
end

-------------------------------------------------
-- Skin profiles
-------------------------------------------------
local SKINS = {
    classic = {
        backdrop = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        bg              = { 0.05, 0.05, 0.05, 0.95 },
        border          = { 0, 0, 0, 1 },
        showButtonSkin  = false,
        buttonBg        = { 0.08, 0.08, 0.08, 0.9 },
        buttonHover     = { 0.20, 0.20, 0.20, 0.9 },
        buttonBorder    = { 0.25, 0.25, 0.25, 1 },
        fontSize        = 11,
        hideCornerAlways      = false,
        -- Dragon only visible from this quality upward (5 = legendary).
        -- Below that (green/blue/epic) or unknown quality: hidden.
        cornerMinQuality      = 5,
        compact         = false,
        frameSize       = nil,
    },
    elvui = {
        backdrop = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        },
        bg              = { 0.06, 0.06, 0.06, 1 },
        border          = { 0, 0, 0, 1 },
        showButtonSkin  = true,
        buttonBg        = { 0.10, 0.10, 0.10, 1 },
        buttonHover     = { 0.13, 0.53, 0.82, 0.35 },
        buttonBorder    = { 0, 0, 0, 1 },
        fontSize        = 10,
        hideCornerAlways      = true,
        cornerMinQuality      = nil,
        compact         = true,
        frameSize       = { 210, 58 },
    },
}

local TIMER_COLOR_START = { 1, 0.82, 0 }
local TIMER_COLOR_END   = { 0.80, 0.10, 0.10 }

-- Button labels: Blizzard global strings (already localized to the client
-- language), with an English fallback if missing on this client.
local BUTTON_LABELS = {
    RollButton       = NEED or "Need",
    NeedButton       = NEED or "Need",
    GreedButton      = GREED or "Greed",
    DisenchantButton = DISENCHANT or "Disenchant",
    PassButton       = PASS or "Pass",
}

local COMPACT_METRICS = {
    iconSize     = 26,
    iconPos      = { 4, -4 },
    namePos      = { 34, -6 },
    barInset     = 4,
    barHeight    = 4,
    buttonHeight = 13,
    buttonTop    = { 4, -32 },
}

local currentSkin = {}
local testFrame
local winsFrame
local RefreshTestFrameSkin
local RefreshWinsSkin
local HandleWinMessage
local function CopySkin(name)
    for k, v in pairs(SKINS[name] or SKINS.classic) do
        currentSkin[k] = v
    end
end
CopySkin("classic")

local skinnedFrames = {}
local skinnedFramesSet = {}
local skinnedButtons = {}

-------------------------------------------------
-- Generic helpers
-------------------------------------------------
local function LerpColor(startColor, endColor, fraction)
    local r = startColor[1] + (endColor[1] - startColor[1]) * fraction
    local g = startColor[2] + (endColor[2] - startColor[2]) * fraction
    local b = startColor[3] + (endColor[3] - startColor[3]) * fraction
    return r, g, b
end

-- Remaining-time bar: yellow at the start -> red toward the end.
local function UpdateTimerColor(bar)
    if not bar or not bar.GetMinMaxValues or not bar.SetStatusBarColor then return end
    local minV, maxV = bar:GetMinMaxValues()
    if not maxV or not minV or maxV <= minV then return end
    local value = bar:GetValue() or maxV
    local elapsedFraction = (maxV - value) / (maxV - minV)
    if elapsedFraction < 0 then elapsedFraction = 0 elseif elapsedFraction > 1 then elapsedFraction = 1 end
    local r, g, b = LerpColor(TIMER_COLOR_START, TIMER_COLOR_END, elapsedFraction)
    bar:SetStatusBarColor(r, g, b)
end

local function SnapshotPoints(region)
    if not region then return nil end
    local numPoints = (region.GetNumPoints and region:GetNumPoints()) or 1
    local points = {}
    for i = 1, numPoints do
        local point, relTo, relPoint, x, y = region:GetPoint(i)
        if not point then break end
        table.insert(points, { point = point, relTo = relTo, relPoint = relPoint, x = x, y = y })
    end
    return #points > 0 and points or nil
end

local function RestorePoints(region, points)
    if not region or not points then return end
    region:ClearAllPoints()
    for _, p in ipairs(points) do
        region:SetPoint(p.point, p.relTo, p.relPoint, p.x, p.y)
    end
end

-- Native "dragon" ornament on the left edge: only visible when quality
-- reaches cornerMinQuality (legendary by default in classic skin).
-- Unknown quality = hidden, to avoid any dragon flash before the quality
-- has been read.
local function UpdateCornerVisibility(frame, quality)
    if not frame.__corner and not frame.__decoration then return end

    local hide = currentSkin.hideCornerAlways
    if not hide then
        if not currentSkin.cornerMinQuality then
            hide = true
        elseif not quality or quality < currentSkin.cornerMinQuality then
            hide = true
        end
    end

    for _, tex in ipairs({ frame.__corner, frame.__decoration }) do
        if tex then
            if hide then
                tex:Hide()
            else
                tex:Show()
            end
        end
    end
end

-------------------------------------------------
-- Skinning of the Need/Greed/Disenchant/Pass buttons
-------------------------------------------------
-- Native code (Ascension included) may RECREATE or re-show its button
-- textures on every roll: a one-time capture at load gets overridden.
-- So we refresh the references and capture any unknown new texture on
-- EVERY visibility pass (which runs on every roll display), so the
-- compact-mode masking holds over time.
local function RefreshButtonTextures(button)
    button.__normalTex = button.__customIcon or (button.GetNormalTexture and button:GetNormalTexture())
    button.__pushedTex = button.GetPushedTexture and button:GetPushedTexture()
    button.__disabledTex = button.GetDisabledTexture and button:GetDisabledTexture()
    button.__highlightTex = button.GetHighlightTexture and button:GetHighlightTexture()

    if button.__allTextures then
        local known = {}
        for _, e in ipairs(button.__allTextures) do known[e.tex] = true end
        for _, region in ipairs({ button:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "Texture"
                and region ~= button.__bg and region ~= button.__customIcon
                and not known[region] then
                table.insert(button.__allTextures, { tex = region, alpha = region:GetAlpha() or 1 })
            end
        end
    end
end

local function ApplyButtonSkinVisibility(button)
    RefreshButtonTextures(button)

    if button.__bg then
        if currentSkin.showButtonSkin then
            button.__bg:SetTexture(unpack(currentSkin.buttonBg))
            button.__bg:Show()
            button.__border:SetBackdropBorderColor(unpack(currentSkin.buttonBorder))
            button.__border:Show()
        else
            button.__bg:Hide()
            button.__border:Hide()
        end
    end

    -- In compact (ElvUI) mode, a text label replaces the native icon.
    -- Native Blizzard button textures often have a FIXED size (32x32 set in
    -- XML): on a 13px-tall compact button they overflow. In compact mode we
    -- hide them ALL (including the hover glow HighlightTexture, the source of
    -- the hover overflow); in classic mode everything is restored.
    --
    local showIcon = not currentSkin.compact
    if button.__normalTex then button.__normalTex:SetAlpha(showIcon and 1 or 0) end
    if button.__pushedTex then button.__pushedTex:SetAlpha(showIcon and 1 or 0) end
    if button.__disabledTex then button.__disabledTex:SetAlpha(showIcon and 1 or 0) end
    if button.__highlightTex then button.__highlightTex:SetAlpha(showIcon and 1 or 0) end

    -- Full sweep: also covers non-standard textures (e.g. the Pass button's
    -- cross on some clients). In classic mode, every texture gets its exact
    -- original alpha back.
    if button.__allTextures then
        for _, entry in ipairs(button.__allTextures) do
            entry.tex:SetAlpha(showIcon and entry.alpha or 0)
        end
    end

    if button.__label then
        if currentSkin.compact then
            button.__label:Show()
        else
            button.__label:Hide()
        end
    end
end

-- IMPORTANT (self-healing): the __cleanLootSkinned flag is only set at the
-- END, after full success. If a step fails (transient error, element not
-- ready yet), the next pass retries everything. Every creation is
-- conditional (if not already-created) to stay idempotent on retry, and
-- hooks have their own immediate latch so they are never duplicated.
local function SkinButton(button, label, iconPath)
    if not button or button.__cleanLootSkinned then return end

    if iconPath then
        if not button.__customIcon then
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT", 2, -2)
            icon:SetPoint("BOTTOMRIGHT", -2, 2)
            icon:SetTexture(iconPath)
            button.__customIcon = icon
        end
        button.__normalTex = button.__customIcon
    else
        button.__normalTex = button.GetNormalTexture and button:GetNormalTexture()
    end
    button.__pushedTex = button.GetPushedTexture and button:GetPushedTexture()
    button.__disabledTex = button.GetDisabledTexture and button:GetDisabledTexture()
    button.__highlightTex = button.GetHighlightTexture and button:GetHighlightTexture()

    if not button.__bg then
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(button)
        button.__bg = bg
    end

    if not button.__border then
        local border = CreateFrame("Frame", nil, button)
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:EnableMouse(false)
        EnsureBackdropSupport(border)
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        button.__border = border
    end

    -- Capture ALL of the button's textures (some clients have extras beyond
    -- the 4 standard ones, e.g. the Pass button's cross) with their original
    -- alpha, for complete masking in compact mode and faithful restoration in
    -- classic mode. Our own textures (__bg, custom icon) are excluded.
    if not button.__allTextures then
        button.__allTextures = {}
        for _, region in ipairs({ button:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "Texture"
                and region ~= button.__bg and region ~= button.__customIcon then
                table.insert(button.__allTextures, { tex = region, alpha = region:GetAlpha() or 1 })
            end
        end
    end

    if label and not button.__label then
        local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER")
        fs:SetFont(fs:GetFont(), 9, "")
        fs:SetText(label)
        button.__label = fs
    end

    if not button.__hoverHooked then
        button.__hoverHooked = true
        button:HookScript("OnEnter", function()
            if currentSkin.showButtonSkin and button.__bg then
                button.__bg:SetTexture(unpack(currentSkin.buttonHover))
                button.__bg:Show()
            end
        end)
        button:HookScript("OnLeave", function()
            ApplyButtonSkinVisibility(button)
        end)
    end

    table.insert(skinnedButtons, button)
    ApplyButtonSkinVisibility(button)

    button.__cleanLootSkinned = true
end

-------------------------------------------------
-- Layout (native Blizzard or compact ElvUI)
-------------------------------------------------
local function ApplyFrameLayout(frame)
    if currentSkin.compact and currentSkin.frameSize then
        local w, h = currentSkin.frameSize[1], currentSkin.frameSize[2]
        frame:SetSize(w, h)

        if frame.__icon then
            frame.__icon:ClearAllPoints()
            frame.__icon:SetPoint("TOPLEFT", frame, "TOPLEFT", COMPACT_METRICS.iconPos[1], COMPACT_METRICS.iconPos[2])
            frame.__icon:SetSize(COMPACT_METRICS.iconSize, COMPACT_METRICS.iconSize)
        end
        if frame.__nameFS then
            frame.__nameFS:ClearAllPoints()
            frame.__nameFS:SetPoint("TOPLEFT", frame, "TOPLEFT", COMPACT_METRICS.namePos[1], COMPACT_METRICS.namePos[2])
            frame.__nameFS:SetWidth(w - COMPACT_METRICS.namePos[1] - 4)
            -- Bounded height: a long name wraps to 2 lines max and is then
            -- truncated, instead of overflowing onto the buttons below.
            frame.__nameFS:SetHeight(22)
            frame.__nameFS:SetJustifyH("LEFT")
            frame.__nameFS:SetJustifyV("TOP")
        end

        local barRef = frame.__timerBar or frame.__timer
        if barRef then
            barRef:ClearAllPoints()
            barRef:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", COMPACT_METRICS.barInset, COMPACT_METRICS.barInset)
            barRef:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -COMPACT_METRICS.barInset, COMPACT_METRICS.barInset)
            barRef:SetHeight(COMPACT_METRICS.barHeight)
        end

        local buttons = frame.__buttons or {}
        local count = #buttons
        if count > 0 then
            local btnW = (w - 8 - (count - 1) * 3) / count
            for i, btn in ipairs(buttons) do
                btn:ClearAllPoints()
                btn:SetSize(btnW, COMPACT_METRICS.buttonHeight)
                if i == 1 then
                    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", COMPACT_METRICS.buttonTop[1], COMPACT_METRICS.buttonTop[2])
                else
                    btn:SetPoint("LEFT", buttons[i - 1], "RIGHT", 3, 0)
                end
            end
        end

        frame.__compactApplied = true

        -- Reapply texture masking on every layout pass (hence on every roll):
        -- native code may recreate/re-show its textures between two displays,
        -- which used to make the Pass cross reappear.
        for _, btn in ipairs(buttons) do
            ApplyButtonSkinVisibility(btn)
        end
    else
        -- In classic mode, positions are only restored if compact mode actually
        -- ran before. Otherwise we NEVER touch the native positions/sizes:
        -- the client (Ascension) may position its buttons dynamically per roll,
        -- and overriding that placement with a snapshot frozen at login can
        -- shift a button's hitbox away from its visual (button visible but
        -- not clickable).
        if frame.__compactApplied then
            frame.__compactApplied = nil

            if frame.__originalSize then
                frame:SetSize(frame.__originalSize[1], frame.__originalSize[2])
            end
            if frame.__icon and frame.__origIconSize then
                frame.__icon:SetSize(frame.__origIconSize[1], frame.__origIconSize[2])
            end
            RestorePoints(frame.__icon, frame.__origPoints and frame.__origPoints.icon)
            RestorePoints(frame.__nameFS, frame.__origPoints and frame.__origPoints.name)
            -- Also restore the name's native DIMENSIONS: the SetWidth/SetHeight
            -- applied by compact mode would otherwise persist after switching back
            -- to classic, and the bounded native height is what keeps a long name
            -- from overflowing the frame (it wraps then truncates).
            if frame.__nameFS and frame.__origNameSize then
                frame.__nameFS:SetWidth(frame.__origNameSize[1])
                frame.__nameFS:SetHeight(frame.__origNameSize[2])
                frame.__nameFS:SetJustifyV("MIDDLE")
            end
            RestorePoints(frame.__timer, frame.__origPoints and frame.__origPoints.timer)
            RestorePoints(frame.__timerBar, frame.__origPoints and frame.__origPoints.timerBar)

            if frame.__buttons and frame.__origPoints and frame.__origPoints.buttons then
                for i, btn in ipairs(frame.__buttons) do
                    RestorePoints(btn, frame.__origPoints.buttons[i])
                    local sz = frame.__origButtonSizes and frame.__origButtonSizes[i]
                    if sz then btn:SetSize(sz[1], sz[2]) end
                end
            end
        end

        -- Restore native texture alphas (without touching positions)
        for _, btn in ipairs(frame.__buttons or {}) do
            ApplyButtonSkinVisibility(btn)
        end
    end
end

-------------------------------------------------
-- "Who rolled what" tracking + tooltip when hovering the buttons
-------------------------------------------------
-- The game broadcasts a system message for each choice ("X has selected
-- Greed for: [Item]"). Instead of hardcoded English patterns, we build the
-- patterns from Blizzard global strings (LOOT_ROLL_NEED, etc.), which are
-- already translated to the client language: parsing is therefore
-- automatically localized. English fallback if the globals do not exist.
local CHOICE_KEYS = {
    RollButton       = "Need",
    NeedButton       = "Need",
    GreedButton      = "Greed",
    DisenchantButton = "Disenchant",
    PassButton       = "Pass",
}

local CHOICE_LABELS = {
    Need       = NEED or "Need",
    Greed      = GREED or "Greed",
    Disenchant = DISENCHANT or "Disenchant",
    Pass       = PASS or "Pass",
}

-- Converts a Blizzard format string ("%s has selected Need for: %s")
-- into a Lua pattern ("^(.+) has selected Need for: (.+)$").
local function FormatToPattern(fmt)
    if not fmt or type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%%%s", "(.+)")
    return "^" .. p .. "$"
end

local ROLL_CHOICE_PATTERNS = {}

local function AddRollPattern(choice, fmt, isSelf)
    local p = FormatToPattern(fmt)
    if p then
        table.insert(ROLL_CHOICE_PATTERNS, { choice = choice, pattern = p, isSelf = isSelf })
    end
end

-- Other players
AddRollPattern("Need",       LOOT_ROLL_NEED)
AddRollPattern("Greed",      LOOT_ROLL_GREED)
AddRollPattern("Disenchant", LOOT_ROLL_DISENCHANT)
AddRollPattern("Pass",       LOOT_ROLL_PASSED)
-- Yourself ("You have selected Need for: X")
AddRollPattern("Need",       LOOT_ROLL_NEED_SELF, true)
AddRollPattern("Greed",      LOOT_ROLL_GREED_SELF, true)
AddRollPattern("Disenchant", LOOT_ROLL_DISENCHANT_SELF, true)
AddRollPattern("Pass",       LOOT_ROLL_PASSED_SELF, true)

-- English fallback if no global string was found on this client
if #ROLL_CHOICE_PATTERNS == 0 then
    ROLL_CHOICE_PATTERNS = {
        { choice = "Need",       pattern = "^(.+) has selected Need for:" },
        { choice = "Greed",      pattern = "^(.+) has selected Greed for:" },
        { choice = "Disenchant", pattern = "^(.+) has selected Disenchant for:" },
        { choice = "Pass",       pattern = "^(.+) passed on:" },
    }
end

local rollChoices = {}

local function GetRollChoices(rollID)
    if not rollChoices[rollID] then
        rollChoices[rollID] = { Need = {}, Greed = {}, Disenchant = {}, Pass = {} }
    end
    return rollChoices[rollID]
end

local function FindRollIDByItemName(itemName)
    if not itemName then return nil end
    for i = 1, 4 do
        local f = _G["GroupLootFrame"..i]
        if f and f.rollID and f.rollID >= 0 then
            local ok, _, name = pcall(GetLootRollItemInfo, f.rollID)
            if ok and name == itemName then
                return f.rollID
            end
        end
    end
    return nil
end

local rollChoiceWatcher = CreateFrame("Frame")
rollChoiceWatcher:RegisterEvent("CHAT_MSG_LOOT")
rollChoiceWatcher:RegisterEvent("START_LOOT_ROLL")
rollChoiceWatcher:RegisterEvent("CANCEL_LOOT_ROLL")

rollChoiceWatcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "START_LOOT_ROLL" then
        rollChoices[arg1] = { Need = {}, Greed = {}, Disenchant = {}, Pass = {} }
    elseif event == "CANCEL_LOOT_ROLL" then
        rollChoices[arg1] = nil
    elseif event == "CHAT_MSG_LOOT" then
        local text = arg1
        if HandleWinMessage and HandleWinMessage(text) then return end
        for _, def in ipairs(ROLL_CHOICE_PATTERNS) do
            local capture = text:match(def.pattern)
            if capture then
                local playerName = def.isSelf and UnitName("player") or capture
                local itemName = text:match("%[(.-)%]")
                local rollID = FindRollIDByItemName(itemName)
                if rollID then
                    local choices = GetRollChoices(rollID)
                    local list = choices[def.choice]
                    local already = false
                    for _, n in ipairs(list) do
                        if n == playerName then already = true break end
                    end
                    if not already then
                        table.insert(list, playerName)
                    end
                end
                break
            end
        end
    end
end)

local function ShowRollChoiceTooltip(button, frame, choiceKey)
    local rollID = frame.rollID
    if not rollID or rollID < 0 then return end

    local choices = rollChoices[rollID]
    local names = choices and choices[choiceKey] or {}

    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:AddLine(("%s (%d)"):format(CHOICE_LABELS[choiceKey] or choiceKey, #names))
    if #names == 0 then
        GameTooltip:AddLine(L.TOOLTIP_NOBODY, 0.6, 0.6, 0.6)
    else
        for _, name in ipairs(names) do
            GameTooltip:AddLine(name, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

-------------------------------------------------
-- Skinning of the loot frame itself
-------------------------------------------------
-- Same self-healing principle as SkinButton: __cleanLootSkinned is only
-- set after full success. A transient failure (silent SetBackdrop,
-- sub-element not created yet...) is automatically retried on the next
-- START_LOOT_ROLL instead of staying broken until a reconnect.
local function SkinLootFrame(frame)
    if not frame or frame.__cleanLootSkinned then return end

    local frameName = frame:GetName()

    if not frame.__originalSize then
        frame.__originalSize = { frame:GetWidth(), frame:GetHeight() }
    end

    EnsureBackdropSupport(frame)
    frame:SetBackdrop(currentSkin.backdrop)
    frame:SetBackdropColor(unpack(currentSkin.bg))
    frame:SetBackdropBorderColor(unpack(currentSkin.border))

    local nameFS = _G[frameName.."Name"] or _G[frameName.."ItemName"]
    if nameFS then
        local font = nameFS:GetFont()
        nameFS:SetFont(font, currentSkin.fontSize, "OUTLINE")
        if not frame.__origNameSize then
            frame.__origNameSize = { nameFS:GetWidth(), nameFS:GetHeight() }
        end
    end
    frame.__nameFS = nameFS

    local iconBorder = _G[frameName.."IconFrameIconBorder"] or _G[frameName.."IconFrameBorder"]
    if iconBorder then
        iconBorder:SetVertexColor(0.6, 0.6, 0.6)
    end

    frame.__icon = _G[frameName.."IconFrame"]
    frame.__corner = _G[frameName.."Corner"]
    frame.__decoration = _G[frameName.."Decoration"]
    if frame.__icon and not frame.__origIconSize then
        frame.__origIconSize = { frame.__icon:GetWidth(), frame.__icon:GetHeight() }
    end

    local buttons = {}
    for _, suffix in ipairs({ "RollButton", "NeedButton", "GreedButton", "DisenchantButton", "PassButton" }) do
        local btn = _G[frameName..suffix]
        if btn then
            local ok, err = pcall(SkinButton, btn, BUTTON_LABELS[suffix])
            if not ok then
                PrintError(frameName..suffix, err)
            end

            local choiceKey = CHOICE_KEYS[suffix]
            if choiceKey and not btn.__tooltipHooked then
                btn.__tooltipHooked = true
                btn:HookScript("OnEnter", function(self)
                    ShowRollChoiceTooltip(self, frame, choiceKey)
                end)
                btn:HookScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            end
            table.insert(buttons, btn)
        end
    end
    frame.__buttons = buttons

    local timer = _G[frameName.."Timer"] or _G[frameName.."RollTimeLeft"]
    local timerBar = _G[frameName.."TimerBar"]
    if timer and timer.SetStatusBarTexture then
        timer:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end
    if timerBar and timerBar ~= timer and timerBar.SetStatusBarTexture then
        timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end
    frame.__timer = (timer and timer.SetStatusBarTexture) and timer or nil
    frame.__timerBar = (timerBar and timerBar ~= timer and timerBar.SetStatusBarTexture) and timerBar or nil

    -- Snapshot native positions, once only (before any modification).
    if not frame.__origPoints then
        frame.__origPoints = {
            icon = SnapshotPoints(frame.__icon),
            name = SnapshotPoints(frame.__nameFS),
            timer = SnapshotPoints(frame.__timer),
            timerBar = SnapshotPoints(frame.__timerBar),
            buttons = {},
        }
        frame.__origButtonSizes = {}
        for i, btn in ipairs(buttons) do
            frame.__origPoints.buttons[i] = SnapshotPoints(btn)
            frame.__origButtonSizes[i] = { btn:GetWidth(), btn:GetHeight() }
        end
    end

    if not frame.__onUpdateHooked then
        frame.__onUpdateHooked = true
        frame:HookScript("OnUpdate", function()
            if frame.__timer then UpdateTimerColor(frame.__timer) end
            if frame.__timerBar then UpdateTimerColor(frame.__timerBar) end
        end)
    end

    UpdateCornerVisibility(frame, nil)
    ApplyFrameLayout(frame)

    if not skinnedFramesSet[frame] then
        skinnedFramesSet[frame] = true
        table.insert(skinnedFrames, frame)
    end

    frame.__cleanLootSkinned = true
end

-- Apply a skin profile to every already-skinned frame/button
local function ApplySkin(name)
    if not SKINS[name] then return end
    CopySkin(name)
    CleanLootDB.skin = name

    for _, frame in ipairs(skinnedFrames) do
        frame:SetBackdrop(currentSkin.backdrop)
        frame:SetBackdropColor(unpack(currentSkin.bg))
        if not frame.rollID or frame.rollID < 0 then
            frame:SetBackdropBorderColor(unpack(currentSkin.border))
        end
        if frame.__nameFS then
            local font = frame.__nameFS:GetFont()
            frame.__nameFS:SetFont(font, currentSkin.fontSize, "OUTLINE")
        end
        ApplyFrameLayout(frame)
        UpdateCornerVisibility(frame, frame.__lastQuality)
    end

    for _, button in ipairs(skinnedButtons) do
        ApplyButtonSkinVisibility(button)
    end

    if RefreshTestFrameSkin then
        RefreshTestFrameSkin()
    end
    if RefreshWinsSkin then
        RefreshWinsSkin()
    end
end

-------------------------------------------------
-- Repositioning (drag & drop + saved position)
-------------------------------------------------
local testModeActive = false

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint()
    CleanLootDB.point = point
    CleanLootDB.relativePoint = relativePoint
    CleanLootDB.x = x
    CleanLootDB.y = y
end

local function RestorePosition(frame)
    if CleanLootDB.point then
        frame:ClearAllPoints()
        frame:SetPoint(CleanLootDB.point, UIParent, CleanLootDB.relativePoint, CleanLootDB.x, CleanLootDB.y)
    end
end

-- Stack the CURRENTLY VISIBLE frames: the first visible one gets the saved
-- position, the rest stack onto it (automatic collapse when a roll
-- resolves). "DOWN" = new items below (Blizzard default),
-- "UP" = stack upward.
local function ApplyLayout()
    local direction = CleanLootDB.growDirection or "DOWN"
    local spacing = 9
    local prevFrame = nil

    for i = 1, 4 do
        local f = _G["GroupLootFrame"..i]
        if f and f:IsShown() then
            if not prevFrame then
                -- Only re-anchor the first visible frame if we actually have
                -- a saved position to apply. Clearing all points without
                -- setting one leaves the frame unanchored: its regions stop
                -- rendering (no background, icon or name) while child
                -- buttons keep floating on screen. Fresh installs that never
                -- used /cll test have no saved position, so we leave the
                -- native anchor untouched in that case.
                if CleanLootDB.point then
                    f:ClearAllPoints()
                    RestorePosition(f)
                end
            else
                f:ClearAllPoints()
                if direction == "UP" then
                    f:SetPoint("BOTTOM", prevFrame, "TOP", 0, spacing)
                else
                    f:SetPoint("TOP", prevFrame, "BOTTOM", 0, -spacing)
                end
            end
            prevFrame = f
        end
    end
end

-- Blizzard sometimes re-evaluates placement on combat transitions.
local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent", function()
    ApplyLayout()
end)

-- User scale (options slider): uniformly multiplies the on-screen size of
-- the loot frames, the mover and the recap, without touching internal
-- proportions. Stacks with the global UI Scale (default options or ElvUI),
-- which these frames already inherit through UIParent.
local function ApplyFrameScale()
    local s = CleanLootDB.frameScale or 1
    for i = 1, 4 do
        local f = _G["GroupLootFrame"..i]
        if f then
            pcall(f.SetScale, f, s)
        end
    end
    if testFrame then testFrame:SetScale(s) end
    if winsFrame then winsFrame:SetScale(s) end
end

-------------------------------------------------
-- Passive diagnostics (only visible in debug mode)
-------------------------------------------------
local function DiagnoseFrameState(frame)
    if not CleanLootDB.debugMode then return end

    local missing = {}
    if not frame.__nameFS then table.insert(missing, "nameFS") end
    if not frame.__icon then table.insert(missing, "icon") end
    if not frame.__buttons or #frame.__buttons == 0 then table.insert(missing, "buttons") end

    if #missing > 0 then
        PrintDiag(L.DIAG_INCOMPLETE:format(frame:GetName() or "?", table.concat(missing, ", ")))
    end
end

local function ColorFrameByQuality(frame)
    local rollID = frame.rollID
    if not rollID or rollID < 0 then return end

    local texture, name, count, quality = GetLootRollItemInfo(rollID)
    if not quality then return end

    frame.__lastQuality = quality

    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        frame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        if frame.__nameFS then
            frame.__nameFS:SetTextColor(color.r, color.g, color.b)
        end
    end

    UpdateCornerVisibility(frame, quality)
end

-------------------------------------------------
-- Test frame (mover)
-- GroupLootFrame1 is protected (Show()/Hide() ignored from addon code):
-- so test mode uses a homemade, unprotected clone with the same skin.
-- The saved position is applied to the real frame through ApplyLayout().
-------------------------------------------------
local function CreateTestFrame()
    if testFrame then return testFrame end

    local f = CreateFrame("Frame", "CleanLootTestFrame", UIParent)
    -- Default size and position set IMMEDIATELY: even if the skin fails
    -- further down, the frame never stays at 0x0 (invisible).
    f:SetSize(252, 84)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")

    local icon = CreateFrame("Frame", nil, f)
    local iconTex = icon:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(icon)
    iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.__icon = icon

    local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetJustifyH("LEFT")
    name:SetText(L.TEST_ITEM)
    name:SetTextColor(0.64, 0.21, 0.93)
    f.__nameFS = name

    local timer = CreateFrame("StatusBar", nil, f)
    timer:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    timer:SetMinMaxValues(0, 1)
    timer:SetValue(0.6)
    f.__timer = timer

    local buttonDefs = {
        { label = BUTTON_LABELS.RollButton,       texture = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
        { label = BUTTON_LABELS.GreedButton,      texture = "Interface\\Buttons\\UI-GroupLoot-Coin-Up" },
        { label = BUTTON_LABELS.DisenchantButton, texture = "Interface\\Buttons\\UI-GroupLoot-DE-Up" },
        { label = BUTTON_LABELS.PassButton,       texture = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" },
    }
    local buttons = {}
    for _, def in ipairs(buttonDefs) do
        local btn = CreateFrame("Button", nil, f)
        btn:SetNormalTexture(def.texture)
        local ok, err = pcall(SkinButton, btn, def.label)
        if not ok then PrintError("TestButton", err) end
        table.insert(buttons, btn)
    end
    f.__buttons = buttons

    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    f:SetScript("OnUpdate", function()
        UpdateTimerColor(timer)
    end)

    testFrame = f
    local ok, err = pcall(RefreshTestFrameSkin)
    if not ok then PrintError("RefreshTestFrameSkin", err) end
    return f
end

local function ApplyTestFrameLayout()
    if not testFrame then return end
    local f = testFrame

    if currentSkin.compact and currentSkin.frameSize then
        local w, h = currentSkin.frameSize[1], currentSkin.frameSize[2]
        f:SetSize(w, h)

        f.__icon:ClearAllPoints()
        f.__icon:SetPoint("TOPLEFT", f, "TOPLEFT", COMPACT_METRICS.iconPos[1], COMPACT_METRICS.iconPos[2])
        f.__icon:SetSize(COMPACT_METRICS.iconSize, COMPACT_METRICS.iconSize)

        f.__nameFS:ClearAllPoints()
        f.__nameFS:SetPoint("TOPLEFT", f, "TOPLEFT", COMPACT_METRICS.namePos[1], COMPACT_METRICS.namePos[2])
        f.__nameFS:SetWidth(w - COMPACT_METRICS.namePos[1] - 4)
        f.__nameFS:SetHeight(22)
        f.__nameFS:SetJustifyV("TOP")

        f.__timer:ClearAllPoints()
        f.__timer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", COMPACT_METRICS.barInset, COMPACT_METRICS.barInset)
        f.__timer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -COMPACT_METRICS.barInset, COMPACT_METRICS.barInset)
        f.__timer:SetHeight(COMPACT_METRICS.barHeight)

        local count = #f.__buttons
        local btnW = (w - 8 - (count - 1) * 3) / count
        for i, btn in ipairs(f.__buttons) do
            btn:ClearAllPoints()
            btn:SetSize(btnW, COMPACT_METRICS.buttonHeight)
            if i == 1 then
                btn:SetPoint("TOPLEFT", f, "TOPLEFT", COMPACT_METRICS.buttonTop[1], COMPACT_METRICS.buttonTop[2])
            else
                btn:SetPoint("LEFT", f.__buttons[i - 1], "RIGHT", 3, 0)
            end
        end
    else
        f:SetSize(252, 84)

        f.__icon:ClearAllPoints()
        f.__icon:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
        f.__icon:SetSize(36, 36)

        f.__nameFS:ClearAllPoints()
        f.__nameFS:SetPoint("TOPLEFT", f.__icon, "TOPRIGHT", 6, -2)
        f.__nameFS:SetWidth(190)
        f.__nameFS:SetHeight(30)
        f.__nameFS:SetJustifyV("TOP")

        f.__timer:ClearAllPoints()
        f.__timer:SetPoint("TOPLEFT", f.__icon, "TOPRIGHT", 6, -22)
        f.__timer:SetSize(190, 8)

        local prev
        for _, btn in ipairs(f.__buttons) do
            btn:ClearAllPoints()
            btn:SetSize(30, 30)
            if prev then
                btn:SetPoint("LEFT", prev, "RIGHT", 4, 0)
            else
                btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
            end
            prev = btn
        end
    end
end

RefreshTestFrameSkin = function()
    if not testFrame then return end

    EnsureBackdropSupport(testFrame)
    testFrame:SetBackdrop(currentSkin.backdrop)
    testFrame:SetBackdropColor(unpack(currentSkin.bg))
    -- Fixed purple border: visually signals test mode.
    testFrame:SetBackdropBorderColor(0.64, 0.21, 0.93, 1)

    if testFrame.__nameFS then
        local font = testFrame.__nameFS:GetFont()
        testFrame.__nameFS:SetFont(font, currentSkin.fontSize, "OUTLINE")
    end

    ApplyTestFrameLayout()

    for _, btn in ipairs(testFrame.__buttons or {}) do
        ApplyButtonSkinVisibility(btn)
    end
end

local function ShowTestFrame()
    local f = CreateTestFrame()
    -- Systematic refresh: if the skin failed at creation time (frame is
    -- cached), retry here instead of staying stuck in the broken state.
    local ok, err = pcall(RefreshTestFrameSkin)
    if not ok then PrintError("RefreshTestFrameSkin", err) end
    RestorePosition(f)
    ApplyFrameScale()
    testModeActive = true
    f:Show()
end

local function HideTestFrame()
    if testFrame then
        testFrame:Hide()
    end
    testModeActive = false
end

-------------------------------------------------
-- Roll winners recap
-------------------------------------------------
-- On each roll win ("X won: [Item]" / "You won: [Item]", detected through
-- Blizzard global strings, hence automatically localized), a line shows up
-- in a small movable window. Hovering a line shows the item's full
-- tooltip. Lines expire after a few seconds; the window hides itself
-- when empty. Optional (see options).
local WIN_DURATION = 12
local MAX_WIN_LINES = 6

-- "Detailed Loot Information" (CVar showLootSpam) is what makes the client
-- broadcast the per-player roll messages ("X has selected...", "X won...").
-- With it disabled, CHAT_MSG_LOOT never fires for those announcements, which
-- silently kills both the winners recap and the "who rolled what" tooltips.
-- When the recap is enabled, we turn the option on ourselves (once per
-- login if needed) and say so in chat, naming the option in the client's
-- own language.
local function EnsureLootSpamCVar()
    if not CleanLootDB.winRecap then return end
    local ok, value = pcall(GetCVar, "showLootSpam")
    if ok and value == "0" then
        local okSet = pcall(SetCVar, "showLootSpam", "1")
        if okSet then
            print(MSG .. L.MSG_LOOTSPAM_ON:format(SHOW_LOOT_SPAM or "Detailed Loot Information"))
        end
    end
end

local winEntries = {}

local WIN_PATTERNS = {}
do
    local function AddWinPattern(fmt, isSelf)
        local p = FormatToPattern(fmt)
        if p then table.insert(WIN_PATTERNS, { pattern = p, isSelf = isSelf }) end
    end
    AddWinPattern(LOOT_ROLL_WON, false)     -- "%s won: %s"
    AddWinPattern(LOOT_ROLL_YOU_WON, true)  -- "You won: %s"
    if #WIN_PATTERNS == 0 then
        table.insert(WIN_PATTERNS, { pattern = "^(.+) won: ", isSelf = false })
        table.insert(WIN_PATTERNS, { pattern = "^You won: ", isSelf = true })
    end
end

local function SaveWinsPosition()
    local point, _, relPoint, x, y = winsFrame:GetPoint()
    if not point then return end
    CleanLootDB.winsPoint = point
    CleanLootDB.winsRelPoint = relPoint
    CleanLootDB.winsX = x
    CleanLootDB.winsY = y
end

local function RestoreWinsPosition()
    if not winsFrame then return end
    winsFrame:ClearAllPoints()
    if CleanLootDB.winsPoint then
        winsFrame:SetPoint(CleanLootDB.winsPoint, UIParent, CleanLootDB.winsRelPoint, CleanLootDB.winsX, CleanLootDB.winsY)
    else
        winsFrame:SetPoint("CENTER", UIParent, "CENTER", 320, 60)
    end
end

local RefreshWinsDisplay

local function CreateWinsFrame()
    if winsFrame then return winsFrame end

    local f = CreateFrame("Frame", "CleanLootWinsFrame", UIParent)
    f:SetSize(220, 40)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWinsPosition()
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 6, -5)
    title:SetText(L.WINS_TITLE)
    f.__title = title

    -- Pool of clickable lines (mouseover -> item tooltip)
    f.__lines = {}
    for i = 1, MAX_WIN_LINES do
        local line = CreateFrame("Button", nil, f)
        line:SetHeight(14)
        line:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -18 - (i - 1) * 15)
        line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -18 - (i - 1) * 15)

        local fs = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetAllPoints(line)
        fs:SetJustifyH("LEFT")
        line.__text = fs

        line:SetScript("OnEnter", function(self)
            if self.__link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, self.__link)
                if ok then GameTooltip:Show() else GameTooltip:Hide() end
            end
        end)
        line:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        line:Hide()
        table.insert(f.__lines, line)
    end

    -- Periodic purge of expired lines (0.5s throttle)
    local acc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 0.5 then return end
        acc = 0
        local now = GetTime()
        local removed = false
        for i = #winEntries, 1, -1 do
            if winEntries[i].expires <= now then
                table.remove(winEntries, i)
                removed = true
            end
        end
        if removed then
            RefreshWinsDisplay()
        end
    end)

    winsFrame = f
    RestoreWinsPosition()
    ApplyFrameScale()
    if RefreshWinsSkin then RefreshWinsSkin() end
    return f
end

RefreshWinsSkin = function()
    if not winsFrame then return end
    EnsureBackdropSupport(winsFrame)
    winsFrame:SetBackdrop(currentSkin.backdrop)
    winsFrame:SetBackdropColor(unpack(currentSkin.bg))
    winsFrame:SetBackdropBorderColor(unpack(currentSkin.border))
end

RefreshWinsDisplay = function()
    if not winsFrame then return end

    if #winEntries == 0 then
        winsFrame:Hide()
        return
    end

    for i, line in ipairs(winsFrame.__lines) do
        local entry = winEntries[i]
        if entry then
            line.__link = entry.link
            line.__text:SetText(entry.text)
            line:Show()
        else
            line.__link = nil
            line:Hide()
        end
    end

    local count = math.min(#winEntries, MAX_WIN_LINES)
    winsFrame:SetHeight(22 + count * 15 + 4)
    winsFrame:Show()
end

-- Recap test mode: a dummy (non-expiring) entry to preview and reposition
-- the window, on the same cycle as the loot roll mover.
local function ShowWinsTest()
    if not CleanLootDB.winRecap then return end
    CreateWinsFrame()

    for i = #winEntries, 1, -1 do
        if winEntries[i].isTest then table.remove(winEntries, i) end
    end

    local me = UnitName("player") or "?"
    table.insert(winEntries, 1, {
        text = ("%s: |cffa335ee[%s]|r"):format(me, L.TEST_ITEM),
        link = nil,
        isTest = true,
        expires = GetTime() + 3600,
    })

    -- Purple border: same "test mode" visual signal as the mover.
    winsFrame:SetBackdropBorderColor(0.64, 0.21, 0.93, 1)
    RefreshWinsDisplay()
end

local function HideWinsTest()
    if not winsFrame then return end
    for i = #winEntries, 1, -1 do
        if winEntries[i].isTest then table.remove(winEntries, i) end
    end
    RefreshWinsDisplay()
    RefreshWinsSkin() -- restores the current skin's border
end

-- Called for every CHAT_MSG_LOOT message; returns true if it was a win
-- announcement (handled), to avoid useless work afterwards.
HandleWinMessage = function(text)
    if not CleanLootDB.winRecap then return false end

    for _, def in ipairs(WIN_PATTERNS) do
        local capture = text:match(def.pattern)
        if capture then
            local playerName = def.isSelf and (UnitName("player") or "?") or capture
            -- Full colored link for display, bare link for the tooltip.
            local coloredLink = text:match("|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r")
            local bareLink = text:match("|H(item:[^|]+)|h")
            local displayName = coloredLink or text:match("%[(.-)%]") or "?"

            CreateWinsFrame()
            table.insert(winEntries, 1, {
                text = ("%s: %s"):format(playerName, displayName),
                link = bareLink,
                expires = GetTime() + WIN_DURATION,
            })
            while #winEntries > MAX_WIN_LINES do
                table.remove(winEntries)
            end
            RefreshWinsDisplay()
            return true
        end
    end
    return false
end

-------------------------------------------------
-- Simple confirmation for item deletion
-- Replaces typing the word "DELETE" with a simple Yes/No.
-------------------------------------------------
local originalDeleteGoodItem

local function ApplyDeleteConfirmOverride()
    local d = StaticPopupDialogs and StaticPopupDialogs["DELETE_GOOD_ITEM"]
    if not d then return end

    if not originalDeleteGoodItem then
        originalDeleteGoodItem = {
            hasEditBox            = d.hasEditBox,
            maxLetters            = d.maxLetters,
            OnShow                = d.OnShow,
            EditBoxOnEnterPressed = d.EditBoxOnEnterPressed,
            EditBoxOnTextChanged  = d.EditBoxOnTextChanged,
        }
    end

    if CleanLootDB.simpleDeleteConfirm then
        d.hasEditBox = nil
        d.maxLetters = nil
        d.OnShow = function(self)
            self.button1:Enable()
        end
        d.EditBoxOnEnterPressed = nil
        d.EditBoxOnTextChanged = nil
    else
        d.hasEditBox            = originalDeleteGoodItem.hasEditBox
        d.maxLetters            = originalDeleteGoodItem.maxLetters
        d.OnShow                = originalDeleteGoodItem.OnShow
        d.EditBoxOnEnterPressed = originalDeleteGoodItem.EditBoxOnEnterPressed
        d.EditBoxOnTextChanged  = originalDeleteGoodItem.EditBoxOnTextChanged
    end
end

-------------------------------------------------
-- Automatic confirmations (roll + BoP loot)
-------------------------------------------------
local confirmWatcher = CreateFrame("Frame")

local function SetupAutoConfirm()
    if CleanLootDB.noConfirm then
        confirmWatcher:RegisterEvent("CONFIRM_LOOT_ROLL")
        confirmWatcher:RegisterEvent("CONFIRM_DISENCHANT_ROLL")
        confirmWatcher:RegisterEvent("LOOT_BIND_CONFIRM")
    else
        confirmWatcher:UnregisterEvent("CONFIRM_LOOT_ROLL")
        confirmWatcher:UnregisterEvent("CONFIRM_DISENCHANT_ROLL")
        confirmWatcher:UnregisterEvent("LOOT_BIND_CONFIRM")
    end
end

local CONFIRM_POPUP_TYPES = {
    CONFIRM_LOOT_ROLL       = true,
    LOOT_BIND               = true,
    CONFIRM_DISENCHANT_ROLL = true,
}

local function AutoAcceptMatchingPopup()
    for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local popup = _G["StaticPopup"..i]
        if popup and popup:IsShown() and CONFIRM_POPUP_TYPES[popup.which] then
            local button = _G["StaticPopup"..i.."Button1"]
            if button and button:IsEnabled() then
                button:Click()
            end
        end
    end
end

confirmWatcher:SetScript("OnEvent", function(self, event, arg1, arg2)
    if not CleanLootDB.noConfirm then return end

    if event == "CONFIRM_LOOT_ROLL" or event == "CONFIRM_DISENCHANT_ROLL" then
        local ok, err = pcall(ConfirmLootRoll, arg1, arg2)
        if not ok then PrintError("ConfirmLootRoll", err) end
    elseif event == "LOOT_BIND_CONFIRM" then
        local ok, err = pcall(ConfirmLootSlot, arg1)
        if not ok then PrintError("ConfirmLootSlot", err) end
    end

    AutoAcceptMatchingPopup()
end)

-------------------------------------------------
-- Options panel
-------------------------------------------------
local optionsFrame

local function CreateOptionsFrame()
    if optionsFrame then return optionsFrame end

    local f = CreateFrame("Frame", "CleanLootOptionsFrame", UIParent)
    f:SetSize(230, 316)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    EnsureBackdropSupport(f)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    title:SetText(L.OPT_TITLE)

    local dirLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dirLabel:SetPoint("TOPLEFT", 18, -42)
    dirLabel:SetText(L.OPT_STACK_DIR)

    local upBtn = CreateFrame("CheckButton", "CleanLootGrowUpButton", f, "UICheckButtonTemplate")
    upBtn:SetPoint("TOPLEFT", 14, -58)
    _G[upBtn:GetName().."Text"]:SetText(L.OPT_GROW_UP)

    local downBtn = CreateFrame("CheckButton", "CleanLootGrowDownButton", f, "UICheckButtonTemplate")
    downBtn:SetPoint("TOPLEFT", 14, -80)
    _G[downBtn:GetName().."Text"]:SetText(L.OPT_GROW_DOWN)

    upBtn:SetScript("OnClick", function()
        upBtn:SetChecked(true)
        downBtn:SetChecked(false)
        CleanLootDB.growDirection = "UP"
        ApplyLayout()
    end)
    downBtn:SetScript("OnClick", function()
        downBtn:SetChecked(true)
        upBtn:SetChecked(false)
        CleanLootDB.growDirection = "DOWN"
        ApplyLayout()
    end)

    local skinLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skinLabel:SetPoint("TOPLEFT", 18, -110)
    skinLabel:SetText(L.OPT_STYLE)

    local classicBtn = CreateFrame("CheckButton", "CleanLootSkinClassicButton", f, "UICheckButtonTemplate")
    classicBtn:SetPoint("TOPLEFT", 14, -126)
    _G[classicBtn:GetName().."Text"]:SetText(L.OPT_SKIN_CLASSIC)

    local elvBtn = CreateFrame("CheckButton", "CleanLootSkinElvUIButton", f, "UICheckButtonTemplate")
    elvBtn:SetPoint("TOPLEFT", 14, -148)
    _G[elvBtn:GetName().."Text"]:SetText(L.OPT_SKIN_ELVUI)

    classicBtn:SetScript("OnClick", function()
        classicBtn:SetChecked(true)
        elvBtn:SetChecked(false)
        ApplySkin("classic")
    end)
    elvBtn:SetScript("OnClick", function()
        elvBtn:SetChecked(true)
        classicBtn:SetChecked(false)
        ApplySkin("elvui")
    end)

    local confirmLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    confirmLabel:SetPoint("TOPLEFT", 18, -172)
    confirmLabel:SetText(L.OPT_CONFIRM)

    local noConfirmBtn = CreateFrame("CheckButton", "CleanLootNoConfirmButton", f, "UICheckButtonTemplate")
    noConfirmBtn:SetPoint("TOPLEFT", 14, -188)
    _G[noConfirmBtn:GetName().."Text"]:SetText(L.OPT_NO_CONFIRM)

    noConfirmBtn:SetScript("OnClick", function()
        local checked = noConfirmBtn:GetChecked() and true or false
        CleanLootDB.noConfirm = checked
        SetupAutoConfirm()
    end)

    local simpleDeleteBtn = CreateFrame("CheckButton", "CleanLootSimpleDeleteButton", f, "UICheckButtonTemplate")
    simpleDeleteBtn:SetPoint("TOPLEFT", 14, -210)
    _G[simpleDeleteBtn:GetName().."Text"]:SetText(L.OPT_SIMPLE_DEL)

    simpleDeleteBtn:SetScript("OnClick", function()
        local checked = simpleDeleteBtn:GetChecked() and true or false
        CleanLootDB.simpleDeleteConfirm = checked
        ApplyDeleteConfirmOverride()
    end)

    local winRecapBtn = CreateFrame("CheckButton", "CleanLootWinRecapButton", f, "UICheckButtonTemplate")
    winRecapBtn:SetPoint("TOPLEFT", 14, -232)
    _G[winRecapBtn:GetName().."Text"]:SetText(L.OPT_WIN_RECAP)

    winRecapBtn:SetScript("OnClick", function()
        local checked = winRecapBtn:GetChecked() and true or false
        CleanLootDB.winRecap = checked
        if checked then
            EnsureLootSpamCVar()
            -- If test mode is still open, bring the recap preview back
            -- immediately instead of requiring a /cll test round-trip.
            if testModeActive then
                local ok, err = pcall(ShowWinsTest)
                if not ok then PrintError("ShowWinsTest", err) end
            end
        elseif winsFrame then
            winsFrame:Hide()
        end
    end)

    -- Frame scale (0.8 to 1.5, 0.05 steps)
    local scaleSlider = CreateFrame("Slider", "CleanLootScaleSlider", f, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 22, -276)
    scaleSlider:SetWidth(180)
    scaleSlider:SetMinMaxValues(0.8, 1.5)
    scaleSlider:SetValueStep(0.05)
    _G["CleanLootScaleSliderLow"]:SetText("0.8")
    _G["CleanLootScaleSliderHigh"]:SetText("1.5")
    _G["CleanLootScaleSliderText"]:SetText(L.OPT_SCALE)

    scaleSlider.__init = false
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        _G["CleanLootScaleSliderText"]:SetText(("%s: %.2f"):format(L.OPT_SCALE, value))
        -- Do not overwrite the saved value during initialization
        if self.__init then
            CleanLootDB.frameScale = value
            ApplyFrameScale()
        end
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
        if testModeActive then
            HideTestFrame()
            HideWinsTest()
            print(MSG .. L.MSG_TEST_STOP)
        end
    end)

    f.upBtn, f.downBtn, f.classicBtn, f.elvBtn, f.noConfirmBtn, f.simpleDeleteBtn, f.winRecapBtn, f.scaleSlider =
        upBtn, downBtn, classicBtn, elvBtn, noConfirmBtn, simpleDeleteBtn, winRecapBtn, scaleSlider
    optionsFrame = f
    return f
end

local function ShowOptions()
    local f = CreateOptionsFrame()

    local dir = CleanLootDB.growDirection or "DOWN"
    f.upBtn:SetChecked(dir == "UP")
    f.downBtn:SetChecked(dir == "DOWN")

    local skin = CleanLootDB.skin or "classic"
    f.classicBtn:SetChecked(skin == "classic")
    f.elvBtn:SetChecked(skin == "elvui")

    f.noConfirmBtn:SetChecked(CleanLootDB.noConfirm and true or false)
    f.simpleDeleteBtn:SetChecked(CleanLootDB.simpleDeleteConfirm and true or false)
    f.winRecapBtn:SetChecked(CleanLootDB.winRecap and true or false)

    f.scaleSlider.__init = false
    f.scaleSlider:SetValue(CleanLootDB.frameScale or 1)
    f.scaleSlider.__init = true

    f:Show()
end

-------------------------------------------------
-- Slash commands
-------------------------------------------------
local function HandleCommand(msg)
    msg = strtrim(msg or ""):lower()

    if msg == "test" then
        local ok1, err1 = pcall(ShowTestFrame)
        if not ok1 then PrintError("ShowTestFrame", err1) end

        local ok2, err2 = pcall(ShowOptions)
        if not ok2 then PrintError("ShowOptions", err2) end

        local ok3, err3 = pcall(ShowWinsTest)
        if not ok3 then PrintError("ShowWinsTest", err3) end

        if CleanLootDB.debugMode and ok1 and testFrame then
            PrintDiag(L.DIAG_TEST_STATE:format(
                tostring(testFrame:IsShown()), tostring(testFrame:IsVisible()),
                testFrame:GetWidth() or 0, testFrame:GetHeight() or 0,
                testFrame:GetPoint() and "1" or "0"))
        end

        print(MSG .. L.MSG_TEST_OPEN)
    elseif msg == "stop" then
        HideTestFrame()
        HideWinsTest()
        print(MSG .. L.MSG_TEST_STOP)
    elseif msg == "reset" then
        CleanLootDB.point = nil
        CleanLootDB.winsPoint = nil
        if winsFrame then RestoreWinsPosition() end
        print(MSG .. L.MSG_RESET)
    elseif msg == "options" or msg == "menu" then
        ShowOptions()
    elseif msg == "debugmode" then
        CleanLootDB.debugMode = not CleanLootDB.debugMode
        print(MSG .. (CleanLootDB.debugMode and L.MSG_DEBUG_ON or L.MSG_DEBUG_OFF))
    elseif msg == "debug" then
        print(MSG .. "debug:")
        print(L.DBG_NOCONFIRM:format(tostring(CleanLootDB.noConfirm)))
        for i = 1, 4 do
            local name = "GroupLootFrame"..i
            local f = _G[name]
            if f then
                print(L.DBG_FOUND:format(
                    name, tostring(f:IsShown()), f:GetWidth() or 0, f:GetHeight() or 0,
                    f:GetPoint() and "1" or "0"))
            else
                print(L.DBG_MISSING:format(name))
            end
        end
    elseif msg == "scan" then
        local frame = _G["GroupLootFrame1"]
        if not frame then
            print(ERR .. L.SCAN_NOFRAME)
            return
        end
        print(MSG .. L.SCAN_HEADER)
        local regions = { frame:GetRegions() }
        for i, region in ipairs(regions) do
            local objType = region.GetObjectType and region:GetObjectType() or "?"
            local name = (region.GetName and region:GetName()) or "(?)"
            local shown = region.IsShown and tostring(region:IsShown()) or "?"
            local w = (region.GetWidth and region:GetWidth()) or 0
            local h = (region.GetHeight and region:GetHeight()) or 0
            if objType == "Texture" then
                local tex = region.GetTexture and region:GetTexture()
                print(("  [%d] %s (Texture) shown=%s %dx%d file=%s"):format(
                    i, tostring(name), shown, w, h, tostring(tex)))
            else
                print(("  [%d] %s (%s) shown=%s %dx%d"):format(
                    i, tostring(name), objType, shown, w, h))
            end
        end
    else
        print(MSG .. L.HELP_HEADER)
        print(L.HELP_TEST)
        print(L.HELP_STOP)
        print(L.HELP_RESET)
        print(L.HELP_OPTIONS)
        print(L.HELP_DEBUGMODE)
        print(L.HELP_DEBUG)
        print(L.HELP_SCAN)
    end
end

SLASH_CLEANLOOT1 = "/cleanloot"
SLASH_CLEANLOOT2 = "/cll"
SlashCmdList["CLEANLOOT"] = HandleCommand

-------------------------------------------------
-- Init
-------------------------------------------------
-- Self-healing: the OnShow/OnHide hooks are installed once per frame
-- (immediate latch, near-infallible operation), but the SKIN is retried
-- on every START_LOOT_ROLL as long as frame.__cleanLootSkinned is not
-- set (it only is after full success). A transient failure at load thus
-- heals itself on the next roll, instead of requiring a
-- reconnect.
local hookedFrames = {}

local function EnsureFrameHooked(frame)
    if not frame then return end

    if not hookedFrames[frame] then
        hookedFrames[frame] = true

        frame:HookScript("OnShow", function(self)
            -- Catch-up: if the skin failed previously, retry here.
            if not self.__cleanLootSkinned then
                local okS, errS = pcall(SkinLootFrame, self)
                if not okS then PrintError("SkinLootFrame", errS) end
            end

            DiagnoseFrameState(self)

            local ok1, err1 = pcall(ColorFrameByQuality, self)
            if not ok1 then PrintError("ColorFrameByQuality", err1) end

            local ok2, err2 = pcall(ApplyFrameLayout, self)
            if not ok2 then PrintError("ApplyFrameLayout", err2) end

            local ok3, err3 = pcall(ApplyLayout)
            if not ok3 then PrintError("ApplyLayout", err3) end
        end)

        -- When a roll resolves, remaining items fill the gap.
        frame:HookScript("OnHide", function()
            ApplyLayout()
        end)
    end

    if not frame.__cleanLootSkinned then
        local ok, err = pcall(SkinLootFrame, frame)
        if not ok then PrintError("SkinLootFrame", err) end
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("START_LOOT_ROLL")

watcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        CleanLootDB.growDirection = CleanLootDB.growDirection or "DOWN"
        CleanLootDB.skin = CleanLootDB.skin or "classic"
        if CleanLootDB.noConfirm == nil then CleanLootDB.noConfirm = false end
        if CleanLootDB.simpleDeleteConfirm == nil then CleanLootDB.simpleDeleteConfirm = false end
        if CleanLootDB.debugMode == nil then CleanLootDB.debugMode = false end
        if CleanLootDB.winRecap == nil then CleanLootDB.winRecap = true end
        if CleanLootDB.frameScale == nil then CleanLootDB.frameScale = 1 end
        CopySkin(CleanLootDB.skin)
        ApplyDeleteConfirmOverride()
        SetupAutoConfirm()

        for i = 1, 4 do
            EnsureFrameHooked(_G["GroupLootFrame"..i])
        end

        ApplyFrameScale()
        ApplyLayout()
        EnsureLootSpamCVar()
    elseif event == "PLAYER_LOGIN" then
        -- Some CVars are only reliably readable at login time.
        EnsureLootSpamCVar()
    elseif event == "START_LOOT_ROLL" then
        -- Guaranteed catch-up: the frames necessarily exist at this point, and
        -- any previously failed skin is retried here.
        for i = 1, 4 do
            local frame = _G["GroupLootFrame"..i]
            EnsureFrameHooked(frame)
            if frame and frame:IsShown() then
                local ok1, err1 = pcall(ColorFrameByQuality, frame)
                if not ok1 then PrintError("ColorFrameByQuality", err1) end
                local ok2, err2 = pcall(ApplyFrameLayout, frame)
                if not ok2 then PrintError("ApplyFrameLayout", err2) end
            end
        end
        ApplyFrameScale()
        ApplyLayout()
    end
end)
