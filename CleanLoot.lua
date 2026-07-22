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
        OPT_HIDE_SPAM    = "Hide roll messages from chat",
        HIST_TITLE       = "Roll history",
        HIST_EMPTY       = "No rolls recorded this session",
        OPT_DETAIL_WINS  = "Detailed roll winners",
        HIST_BTN         = "History",
        HELP_HISTORY     = "  /cll history   - open the roll history window",
        EVERYONE_PASSED  = "everyone passed",
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
        OPT_HIDE_SPAM    = "Masquer les messages de roll du chat",
        HIST_TITLE       = "Historique des rolls",
        HIST_EMPTY       = "Aucun roll enregistre cette session",
        OPT_DETAIL_WINS  = "Recap des rolls detaille",
        HIST_BTN         = "Historique",
        HELP_HISTORY     = "  /cll history   - ouvre la fenetre d'historique des rolls",
        EVERYONE_PASSED  = "tout le monde a passe",
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

    -- Try the frame's own SetBackdrop first, WITHOUT mixing anything in.
    -- ElvUI forks for 3.3.5 may expose a backported BackdropTemplateMixin
    -- global (present even with every module unticked): blindly mixing it
    -- in would override a perfectly working native SetBackdrop with a
    -- differently-behaving one. The mixin is a fallback, never a default.
    if frame.SetBackdrop then
        local ok = pcall(frame.SetBackdrop, frame, TEST_BACKDROP)
        if ok and frame.GetBackdrop and frame:GetBackdrop() then
            pcall(frame.SetBackdrop, frame, nil)
            return -- native backdrop works
        end
    end

    -- Fallback 1: newer-API mixin, then re-test.
    if BackdropTemplateMixin and Mixin then
        pcall(Mixin, frame, BackdropTemplateMixin)
        if frame.SetBackdrop then
            local ok = pcall(frame.SetBackdrop, frame, TEST_BACKDROP)
            if ok and frame.GetBackdrop and frame:GetBackdrop() then
                pcall(frame.SetBackdrop, frame, nil)
                return
            end
        end
    end

    -- Fallback 2: manual texture shim.
    InstallBackdropShim(frame)
end

-------------------------------------------------
-- Skin profiles
-------------------------------------------------
local SKINS = {
    classic = {
        backdrop = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        },
        bg              = { 0.04, 0.04, 0.04, 0.9 },
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
        frameSize       = { 210, 64 },
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
    barHeight    = 7,
    buttonHeight = 14,
    buttonTop    = { 4, -33 },
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

-- Forward declarations for the replacement-frame pool (defined further down
-- but referenced by earlier functions like ApplyFrameScale, ApplySkin).
local NUM_ROLL_FRAMES = 4
local rollFrames = {}
local RefreshAllRollFrameSkins
local ColorRollFrameByQuality

-- Single source of truth for the addon font. Every FontString across the
-- loot frames and the winners window goes through this, so sizes and face
-- stay consistent. Falls back safely if GetFont() returns nil (3.3.5 crash
-- guard). A font selector can later feed CleanLootDB.font here.
local function GetAddonFont()
    -- Uses the client's default font face; only the size is skin-driven.
    local base = STANDARD_TEXT_FONT or ("Fonts" .. "\\" .. "FRIZQT__.TTF")
    return base
end

local function ApplyFont(fs, sizeOverride)
    if not fs then return end
    local curFace = fs:GetFont()
    local face = GetAddonFont() or curFace
    if not face then return end
    fs:SetFont(face, sizeOverride or currentSkin.fontSize or 11, "OUTLINE")
end

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

    -- In compact mode, NATIVE buttons must be fully invisible: not just
    -- their textures, but also the bg/border/label our own skin adds
    -- (otherwise those show as scattered black boxes at their untouched
    -- native positions). Our custom buttons keep the full skin.
    local hideAll = currentSkin.compact and button.__cleanLootNative

    if button.__bg then
        if button.__noButtonBg then
            -- Transparent background, but keep a thin border so the clickable
            -- area is visible (compact ElvUI buttons).
            button.__bg:Hide()
            if button.__border then
                button.__border:SetBackdropBorderColor(unpack(currentSkin.buttonBorder))
                button.__border:Show()
            end
        elseif not hideAll and currentSkin.showButtonSkin then
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
        if currentSkin.compact and not hideAll then
            button.__label:Show()
        else
            button.__label:Hide()
        end
    end

    -- Availability gray-out applied LAST, so it always wins regardless of the
    -- order in which skin refreshes and state updates run. __unavailable is
    -- set by UpdateRollFrameButtonStates from the native button's real state.
    -- __normalTex (the dice/coin/DE icon) is the main visible element in the
    -- classic skin, so it MUST be included or classic never grays out.
    local a = button.__unavailable and 0.35 or 1
    button:SetAlpha(a)
    if button.__label then button.__label:SetAlpha(a) end
    if button.__border then button.__border:SetAlpha(a) end
    if button.__bg then button.__bg:SetAlpha(a) end
    -- Only dim the icon if it's currently shown (don't resurrect a hidden one).
    if button.__normalTex and button.__normalTex:GetAlpha() > 0 then
        button.__normalTex:SetAlpha(a)
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
        ApplyFont(fs, 9)  -- same face as everything else, smaller size
        fs:SetText(label)
        button.__label = fs
    end

    if not button.__hoverHooked then
        button.__hoverHooked = true
        button:HookScript("OnEnter", function()
            if button.__bg and (currentSkin.showButtonSkin or button.__noButtonBg) then
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
local function SetNativeBackdropsShown(frame, shown)
    for _, e in ipairs(frame.__nativeBackdrops or {}) do
        e.tex:SetAlpha(shown and e.alpha or 0)
    end
end

local function ApplyFrameLayout(frame)
    if currentSkin.compact and currentSkin.frameSize then
        SetNativeBackdropsShown(frame, false)
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
        -- The frame has TWO native bars (Timer + TimerBar) on this client;
        -- only one is repositioned. Hide the other, or it stays stretched
        -- at its native geometry and pokes out of the compact frame.
        local otherBar = (barRef == frame.__timerBar) and frame.__timer or frame.__timerBar
        if otherBar and otherBar ~= barRef then
            otherBar:SetAlpha(0)
        end
        if barRef then
            barRef:ClearAllPoints()
            barRef:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", COMPACT_METRICS.barInset, COMPACT_METRICS.barInset)
            barRef:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -COMPACT_METRICS.barInset, COMPACT_METRICS.barInset)
            barRef:SetHeight(COMPACT_METRICS.barHeight)
        end

        -- Native buttons are NEVER moved (their hitbox desyncs from their
        -- visual on this client once repositioned). In compact mode they are
        -- made invisible and mouse-disabled; our custom buttons take over.
        for _, btn in ipairs(frame.__buttons or {}) do
            ApplyButtonSkinVisibility(btn)
            btn:EnableMouse(false)
        end

        local customs = frame.__customButtons or {}
        local count = #customs
        if count > 0 then
            local btnW = (w - 8 - (count - 1) * 3) / count
            for i, btn in ipairs(customs) do
                btn:ClearAllPoints()
                btn:SetSize(btnW, COMPACT_METRICS.buttonHeight)
                if i == 1 then
                    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", COMPACT_METRICS.buttonTop[1], COMPACT_METRICS.buttonTop[2])
                else
                    btn:SetPoint("LEFT", customs[i - 1], "RIGHT", 3, 0)
                end
                ApplyButtonSkinVisibility(btn)
                btn:Show()
            end
        end

        frame.__compactApplied = true
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

        end

        -- Restore native backdrops and both bars' visibility.
        SetNativeBackdropsShown(frame, true)
        if frame.__timer then frame.__timer:SetAlpha(1) end
        if frame.__timerBar then frame.__timerBar:SetAlpha(1) end

        -- Hide the compact custom buttons; restore native alphas and mouse
        -- input (positions are never touched in either mode anymore).
        for _, btn in ipairs(frame.__customButtons or {}) do
            btn:Hide()
        end
        for _, btn in ipairs(frame.__buttons or {}) do
            ApplyButtonSkinVisibility(btn)
            btn:EnableMouse(true)
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

-- Maps item name -> active rollID, maintained at START/CANCEL time when the
-- name is reliably available. Far more robust than re-querying
-- GetLootRollItemInfo on every chat message (which can return a slightly
-- different or nil name on this client, giving rollID=nil).
local rollIDByName = {}

local function FindRollIDByItemName(itemName)
    if not itemName then return nil end
    -- Primary: the name map filled at START_LOOT_ROLL.
    if rollIDByName[itemName] then return rollIDByName[itemName] end
    -- Fallback: query the live frames.
    for i = 1, NUM_ROLL_FRAMES do
        local f = rollFrames[i]
        if f and f.rollID and f.rollID >= 0 then
            local ok, _, name = pcall(GetLootRollItemInfo, f.rollID)
            if ok and name == itemName then
                return f.rollID
            end
        end
    end
    return nil
end

-- Roll VALUES (the dice number), captured from "X Roll - N for [Item] by
-- Player" messages. Stored per rollID as { {player, type, value}, ... }.
-- type is one of Need/Greed/Disenchant. Also fed into the session history.
local rollValues = {}
local rollValuePatterns = {}
do
    -- Blizzard globals: e.g. "Need Roll - %d for %s by %s".
    local defs = {
        { type = "Need",       fmt = LOOT_ROLL_NEED_PREFIX or "Need Roll - %d for %s by %s" },
        { type = "Greed",      fmt = LOOT_ROLL_GREED_PREFIX or "Greed Roll - %d for %s by %s" },
        { type = "Disenchant", fmt = LOOT_ROLL_DISENCHANT_PREFIX or "Disenchant Roll - %d for %s by %s" },
    }
    for _, d in ipairs(defs) do
        if type(d.fmt) == "string" then
            -- Build a pattern capturing value, item, player in order.
            local p = d.fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            p = p:gsub("%%%%d", "(%%d+)")
            p = p:gsub("%%%%s", "(.+)")
            table.insert(rollValuePatterns, { type = d.type, pattern = "^" .. p })
        end
    end
end

local function GetRollValues(rollID)
    if not rollValues[rollID] then rollValues[rollID] = {} end
    return rollValues[rollID]
end

-- Session history: newest first, capped. Each entry captured when a roll is
-- won or fully resolved: { itemLink, winner, winType, winValue, rolls = {...} }.
local MAX_HISTORY = 100
local rollHistory = {}
local rollItemLinks = {}   -- rollID -> item link (for history/detail display)
local rollValuesByName = {}  -- item name -> { {player, type, value}, ... }

-- Same winning-tier logic, but keyed by item name (robust: the name is in
-- every roll/win message, unlike a rollID that must be resolved).
local function ComputeWinningTierByName(itemName)
    local vals = rollValuesByName[itemName] or {}
    local need, greedde = {}, {}
    for _, v in ipairs(vals) do
        if v.type == "Need" then
            table.insert(need, v)
        elseif v.type == "Greed" or v.type == "Disenchant" then
            table.insert(greedde, v)
        end
    end
    local tier, list
    if #need > 0 then
        tier, list = "Need", need
    elseif #greedde > 0 then
        tier, list = "GreedDE", greedde
    else
        return "Pass", {}
    end
    table.sort(list, function(a, b) return (a.value or 0) > (b.value or 0) end)
    return tier, list
end

local rollChoiceWatcher = CreateFrame("Frame")
rollChoiceWatcher:RegisterEvent("CHAT_MSG_LOOT")
rollChoiceWatcher:RegisterEvent("START_LOOT_ROLL")
rollChoiceWatcher:RegisterEvent("CANCEL_LOOT_ROLL")

rollChoiceWatcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "START_LOOT_ROLL" then
        rollChoices[arg1] = { Need = {}, Greed = {}, Disenchant = {}, Pass = {} }
        rollValues[arg1] = {}
        -- Cache the item link now, while the roll is live (needed later for
        -- the detailed/history display, when the roll may be gone).
        local link = GetLootRollItemLink and GetLootRollItemLink(arg1)
        if link then rollItemLinks[arg1] = link end
        -- Map the item name -> rollID for reliable chat-message matching.
        local name = select(2, GetLootRollItemInfo(arg1))
        if (not name or name == "") and link then
            name = link:match("%[(.-)%]")
        end
        if name and name ~= "" then
            rollIDByName[name] = arg1
            rollValuesByName[name] = {}  -- fresh capture for this item
        end
    elseif event == "CANCEL_LOOT_ROLL" then
        -- Clear the name map entry for this roll.
        for nm, id in pairs(rollIDByName) do
            if id == arg1 then rollIDByName[nm] = nil end
        end
        rollChoices[arg1] = nil
        rollValues[arg1] = nil
    elseif event == "CHAT_MSG_LOOT" then
        local text = arg1

        -- Roll value line? "Need Roll - 87 for [Item] by Bob". Index by item
        -- NAME (present in every message) rather than a fragile rollID lookup.
        for _, def in ipairs(rollValuePatterns) do
            local value, itemName, player = text:match(def.pattern)
            if value and player then
                local bare = itemName and itemName:match("%[(.-)%]") or itemName
                if bare then
                    if not rollValuesByName[bare] then rollValuesByName[bare] = {} end
                    table.insert(rollValuesByName[bare], {
                        player = player, type = def.type, value = tonumber(value),
                    })
                end
                return
            end
        end

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

-- Computes the "winning tier" of a roll from captured values:
--   any Need  -> Need rolls only
--   else      -> Greed + Disenchant together (same tier)
--   else      -> everyone passed
-- Returns tier ("Need"|"GreedDE"|"Pass") and a sorted-desc list of
-- { player, type, value } for that tier.
local function ComputeWinningTier(rollID)
    local vals = rollValues[rollID] or {}
    local need, greedde = {}, {}
    for _, v in ipairs(vals) do
        if v.type == "Need" then
            table.insert(need, v)
        elseif v.type == "Greed" or v.type == "Disenchant" then
            table.insert(greedde, v)
        end
    end

    local tier, list
    if #need > 0 then
        tier, list = "Need", need
    elseif #greedde > 0 then
        tier, list = "GreedDE", greedde
    else
        return "Pass", {}
    end

    table.sort(list, function(a, b) return (a.value or 0) > (b.value or 0) end)
    return tier, list
end

local function RecordHistory(rollID, winner, winType, winValue)
    local link = rollItemLinks[rollID] or (GetLootRollItemLink and GetLootRollItemLink(rollID))
    local _, list = ComputeWinningTier(rollID)
    table.insert(rollHistory, 1, {
        link = link,
        winner = winner,
        winType = winType,
        winValue = winValue,
        rolls = list,
        time = GetTime(),
    })
    while #rollHistory > MAX_HISTORY do
        table.remove(rollHistory)
    end
end

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
        ApplyFont(nameFS)
        if not frame.__origNameSize then
            frame.__origNameSize = { nameFS:GetWidth(), nameFS:GetHeight() }
        end
    end
    frame.__nameFS = nameFS

    local iconBorder = _G[frameName.."IconFrameIconBorder"] or _G[frameName.."IconFrameBorder"]
    if iconBorder then
        iconBorder:SetVertexColor(0.6, 0.6, 0.6)
    end

    -- Native parchment/gold backdrop textures behind the name/button area.
    -- Sized for the native frame, they poke out of the smaller compact frame
    -- (the "classic skin showing behind compact" artifact), so we hide them
    -- in compact mode and restore them in classic.
    frame.__nativeBackdrops = {}
    for _, suffix in ipairs({ "NameFrame", "SlotTexture", "Background" }) do
        local tex = _G[frameName..suffix]
        if tex and tex.SetAlpha then
            table.insert(frame.__nativeBackdrops, { tex = tex, alpha = tex:GetAlpha() or 1 })
        end
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
            -- No text label on native buttons: they are never repositioned,
            -- so a label would show at their native spot in compact mode
            -- (the scattered-duplicates bug). Labels live on our custom
            -- buttons only.
            btn.__cleanLootNative = true
            local ok, err = pcall(SkinButton, btn, nil)
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

    -- Compact-mode custom buttons. Native buttons on this client can end up
    -- with their hitbox desynced from their visual once repositioned (the
    -- long-standing "Pass does nothing" bug), so in compact mode we never
    -- move them at all: they are made invisible and mouse-disabled, and
    -- these homemade buttons call the roll API (RollOnLoot) directly.
    if not frame.__customButtons then
        frame.__customButtons = {}
        local defs = {
            { key = "Need",       rollType = 1, label = BUTTON_LABELS.RollButton },
            { key = "Greed",      rollType = 2, label = BUTTON_LABELS.GreedButton },
            { key = "Disenchant", rollType = 3, label = "DE" },
            { key = "Pass",       rollType = 0, label = BUTTON_LABELS.PassButton },
        }
        for _, def in ipairs(defs) do
            local btn = CreateFrame("Button", nil, frame)
            btn.__rollType = def.rollType
            btn.__noButtonBg = true  -- transparent bg: label + hover only
            local ok, err = pcall(SkinButton, btn, def.label)
            if not ok then PrintError("CustomButton", err) end
            btn:SetScript("OnClick", function(self)
                local id = frame.rollID
                if id and id >= 0 then
                    RollOnLoot(id, self.__rollType)
                end
            end)
            btn:HookScript("OnEnter", function(self)
                ShowRollChoiceTooltip(self, frame, def.key)
            end)
            btn:HookScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            btn:Hide()
            table.insert(frame.__customButtons, btn)
        end
    end

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

-- Apply a skin profile: refresh the replacement-frame pool and the recap.
local function ApplySkin(name)
    if not SKINS[name] then return end
    CopySkin(name)
    CleanLootDB.skin = name

    if RefreshAllRollFrameSkins then
        RefreshAllRollFrameSkins()
    end
    -- Re-color any frame currently bound to a live roll (border/name).
    for _, f in ipairs(rollFrames) do
        if f.rollID and f.rollID >= 0 and ColorRollFrameByQuality then
            ColorRollFrameByQuality(f)
        end
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

-- (Combat-transition repositioning watcher removed: the replacement frames
-- are ours and never get repositioned by the client, unlike the old native
-- GroupLootFrames.)

-- User scale (options slider): uniformly multiplies the on-screen size of
-- the loot frames, the mover and the recap, without touching internal
-- proportions. Stacks with the global UI Scale (default options or ElvUI),
-- which these frames already inherit through UIParent.
local function ApplyFrameScale()
    local s = tonumber(CleanLootDB.frameScale) or 1
    -- SetScale(0) can crash the client; clamp to a sane range and repair
    -- any corrupted saved value.
    if s < 0.5 or s > 2 then
        s = 1
        CleanLootDB.frameScale = 1
    end
    for _, f in ipairs(rollFrames) do
        pcall(f.SetScale, f, s)
    end
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

-- Grays out the compact custom buttons according to what the item allows
-- (canNeed/canGreed/canDisenchant from GetLootRollItemInfo). Pass is always
-- available.
local function UpdateCustomButtonStates(frame)
    if not frame.__customButtons then return end
    local rollID = frame.rollID
    if not rollID or rollID < 0 then return end

    local ok, _, _, _, _, _, canNeed, canGreed, canDE = pcall(GetLootRollItemInfo, rollID)
    if not ok then return end

    local allowed = { [1] = canNeed, [2] = canGreed, [3] = canDE, [0] = true }
    for _, btn in ipairs(frame.__customButtons) do
        local can = allowed[btn.__rollType]
        if can == nil then can = true end
        if can then
            btn:Enable()
            btn:SetAlpha(1)
        else
            btn:Disable()
            btn:SetAlpha(0.35)
        end
    end
end

local function ColorFrameByQuality(frame)
    local rollID = frame.rollID
    if not rollID or rollID < 0 then return end

    local texture, name, count, quality = GetLootRollItemInfo(rollID)
    if not quality then return end

    frame.__lastQuality = quality

    -- Slight overrides over the default quality palette: the stock epic
    -- color reads pink on this UI; use a deeper purple for it. Tweak or add
    -- entries here (indexed by quality) to adjust border/name colors.
    local QUALITY_TWEAKS = { [4] = { r = 0.55, g = 0.18, b = 0.87 } }
    local color = QUALITY_TWEAKS[quality]
        or (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality])
    if color then
        frame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        if frame.__nameFS then
            frame.__nameFS:SetTextColor(color.r, color.g, color.b)
        end
    end

    UpdateCornerVisibility(frame, quality)
end

-------------------------------------------------
-- Replacement frames (homemade pool)
-- Instead of reskinning Blizzard's GroupLootFrames (native NameFrame,
-- double bars, recreated textures, capricious hitboxes...), we hide them
-- entirely and render our own frames on top, fed from GetLootRollItemInfo
-- and rolling through RollOnLoot directly. Same rendering path as the old
-- test frame, generalized into a pool of 4.
-------------------------------------------------
local rollFrameByRollID = {}

local ICON_TEXTURES = {
    { rollType = 1, key = "Need",       label = BUTTON_LABELS.RollButton,  texture = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
    { rollType = 2, key = "Greed",      label = BUTTON_LABELS.GreedButton, texture = "Interface\\Buttons\\UI-GroupLoot-Coin-Up" },
    { rollType = 3, key = "Disenchant", label = "DE",                      texture = "Interface\\Buttons\\UI-GroupLoot-DE-Up" },
    { rollType = 0, key = "Pass",       label = BUTTON_LABELS.PassButton,  texture = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" },
}

local ApplyRollFrameLayout
local RefreshRollFrameSkin
local UpdateRollFrameButtonStates

local function CreateRollFrame(index)
    local f = CreateFrame("Frame", "CleanLootFrame"..index, UIParent)
    f:SetSize(252, 84)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    -- Icon (with its own texture) + a decoration/corner reference kept nil:
    -- our frames have no native dragon, so UpdateCornerVisibility is a no-op.
    local icon = CreateFrame("Frame", nil, f)
    icon:EnableMouse(true)
    local iconTex = icon:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(icon)
    -- Zoom ~30% into the icon to crop the ugly rounded border (like WeakAuras).
    -- 0.15 inset on each side = 30% total crop.
    iconTex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    f.__icon = icon
    f.__iconTex = iconTex

    -- Item tooltip on hover (with Shift = compare handled natively by the
    -- client). Ctrl+left-click = dress-up/inspect the item's appearance.
    -- Shift+left-click = link in chat.
    icon:SetScript("OnEnter", function(self)
        local id = f.rollID
        if id and id >= 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if pcall(GameTooltip.SetLootRollItem, GameTooltip, id) then
                GameTooltip:Show()
            else
                GameTooltip:Hide()
            end
        end
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icon:SetScript("OnMouseUp", function(self, button)
        local id = f.rollID
        if not (id and id >= 0) then return end
        if button == "LeftButton" then
            local link = GetLootRollItemLink(id)
            if IsControlKeyDown() and link and DressUpItemLink then
                DressUpItemLink(link)
            elseif IsShiftKeyDown() and link and ChatEdit_InsertLink then
                ChatEdit_InsertLink(link)
            end
        end
    end)

    local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetJustifyH("LEFT")
    ApplyFont(name)
    f.__nameFS = name

    local timer = CreateFrame("StatusBar", nil, f)
    timer:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    timer:SetMinMaxValues(0, 1)
    timer:SetValue(1)
    f.__timer = timer

    -- Roll buttons: icon (native art) + text label; roll through RollOnLoot.
    local buttons = {}
    for _, def in ipairs(ICON_TEXTURES) do
        local btn = CreateFrame("Button", nil, f)
        btn.__rollType = def.rollType
        btn.__choiceKey = def.key
        btn:SetNormalTexture(def.texture)
        local ok, err = pcall(SkinButton, btn, def.label)
        if not ok then PrintError("RollFrameButton", err) end
        btn:SetScript("OnClick", function(self)
            local id = f.rollID
            -- Don't roll a type the item disallows (a disabled button means
            -- canNeed/canGreed/canDE was false): RollOnLoot with an illegal
            -- type raises a Lua error on 3.3.5. pcall guards anything else.
            if id and id >= 0 and self:IsEnabled() then
                local ok, err = pcall(RollOnLoot, id, self.__rollType)
                if not ok then PrintError("RollOnLoot", err) end
            end
        end)
        btn:HookScript("OnEnter", function(self)
            ShowRollChoiceTooltip(self, f, def.key)
        end)
        btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(buttons, btn)
    end
    f.__buttons = buttons

    -- First frame is the movable anchor; others stack onto it.
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    if index == 1 then
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            SavePosition(self)
        end)
    end

    -- Timer countdown: we drive it ourselves from START_LOOT_ROLL's rollTime.
    f:SetScript("OnUpdate", function(self)
        if self.__endTime and self.__duration and self.__duration > 0 then
            local remaining = self.__endTime - GetTime()
            if remaining < 0 then remaining = 0 end
            self.__timer:SetValue(remaining / self.__duration)
        end
        UpdateTimerColor(self.__timer)

        -- Re-evaluate button availability for the first couple of seconds:
        -- on this client, canNeed/canGreed/canDisenchant from
        -- GetLootRollItemInfo are sometimes not populated yet at
        -- START_LOOT_ROLL time, so a one-shot check would leave unusable
        -- buttons ungrayed.
        if self.rollID and self.rollID >= 0 and self.__stateUntil and GetTime() < self.__stateUntil then
            if UpdateRollFrameButtonStates then UpdateRollFrameButtonStates(self) end
        end
    end)

    return f
end

local function GetRollFrame(index)
    if not rollFrames[index] then
        rollFrames[index] = CreateRollFrame(index)
        RefreshRollFrameSkin(rollFrames[index])
    end
    return rollFrames[index]
end

ApplyRollFrameLayout = function(f)
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
            btn.__noButtonBg = true
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
        f.__timer:SetSize(190, 10)

        local prev
        for _, btn in ipairs(f.__buttons) do
            btn.__noButtonBg = false
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

RefreshRollFrameSkin = function(f)
    if not f then return end
    EnsureBackdropSupport(f)
    f:SetBackdrop(currentSkin.backdrop)
    f:SetBackdropColor(unpack(currentSkin.bg))
    f:SetBackdropBorderColor(unpack(currentSkin.border))
    ApplyFont(f.__nameFS)
    ApplyRollFrameLayout(f)
    for _, btn in ipairs(f.__buttons or {}) do
        ApplyButtonSkinVisibility(btn)
    end
end

RefreshAllRollFrameSkins = function()
    for _, f in ipairs(rollFrames) do
        RefreshRollFrameSkin(f)
    end
end

-- Stack visible replacement frames like the old ApplyLayout did.
local function LayoutRollFrames()
    local direction = CleanLootDB.growDirection or "DOWN"
    local spacing = 9
    local prev = nil
    for i = 1, NUM_ROLL_FRAMES do
        local f = rollFrames[i]
        if f and f:IsShown() then
            f:ClearAllPoints()
            if not prev then
                if CleanLootDB.point then
                    f:SetPoint(CleanLootDB.point, UIParent, CleanLootDB.relativePoint, CleanLootDB.x, CleanLootDB.y)
                else
                    f:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
                end
            elseif direction == "UP" then
                f:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
            else
                f:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
            end
            prev = f
        end
    end
end

ColorRollFrameByQuality = function(f)
    local id = f.rollID
    if not id or id < 0 then return end
    local texture, name, count, quality = GetLootRollItemInfo(id)
    local QUALITY_TWEAKS = { [4] = { r = 0.55, g = 0.18, b = 0.87 } }
    local color = quality and (QUALITY_TWEAKS[quality] or (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]))
    if color then
        f:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        if f.__nameFS then f.__nameFS:SetTextColor(color.r, color.g, color.b) end
    end
end

-- Finds the native GroupLootFrame bound to a given rollID (Blizzard sets
-- .rollID on each). Used to read the real state its buttons computed.
local function FindNativeFrameByRollID(rollID)
    for i = 1, 4 do
        local nf = _G["GroupLootFrame"..i]
        if nf and nf.rollID == rollID then
            return nf, "GroupLootFrame"..i
        end
    end
    return nil
end

UpdateRollFrameButtonStates = function(f)
    local id = f.rollID
    if not id or id < 0 then return end
    local ok, _, _, _, _, _, canNeed, canGreed, canDE = pcall(GetLootRollItemInfo, id)
    if not ok then return end

    -- On this server, GetLootRollItemInfo's can* flags are not reliable
    -- (Need can be restricted per item, and Disenchant depends on ANYONE in
    -- the group having Enchanting). The native (hidden) buttons already
    -- reflect the truth the client computed, so we read their shown/enabled
    -- state instead, and only fall back to the flags if a native button is
    -- missing.
    local _, nativeName = FindNativeFrameByRollID(id)
    if nativeName then
        local function nativeState(suffix, fallback)
            local btn = _G[nativeName..suffix]
            if not btn then return fallback end
            local shown = (not btn.IsShown) or btn:IsShown()
            local enabled = (not btn.IsEnabled) or btn:IsEnabled()
            return shown and enabled
        end
        -- Native Need button is "RollButton" on 3.3.5; some clients also
        -- expose "NeedButton". Try both.
        local needBtn = _G[nativeName.."NeedButton"] or _G[nativeName.."RollButton"]
        if needBtn then
            local shown = (not needBtn.IsShown) or needBtn:IsShown()
            local enabled = (not needBtn.IsEnabled) or needBtn:IsEnabled()
            canNeed = shown and enabled
        end
        canGreed = nativeState("GreedButton", canGreed)
        canDE = nativeState("DisenchantButton", canDE)
    end

    local allowed = { [1] = canNeed, [2] = canGreed, [3] = canDE, [0] = true }
    for _, btn in ipairs(f.__buttons) do
        local raw = allowed[btn.__rollType]
        if raw == nil then raw = true end
        -- CRITICAL: native flags return 1/0 (numbers), and in Lua 0 is TRUTHY.
        -- So `not 0` is false and the gray-out never triggered. Normalize to a
        -- real boolean: only 1/true count as "can".
        local can = (raw == true) or (raw == 1)
        if can then btn:Enable() else btn:Disable() end
        btn.__unavailable = not can
        ApplyButtonSkinVisibility(btn)
    end
end

-- Fill a replacement frame from a live rollID and show it.
local function StartRollFrame(rollID, rollTime)
    -- Find a free frame (not currently bound to a roll).
    local f
    for i = 1, NUM_ROLL_FRAMES do
        local cand = GetRollFrame(i)
        if not cand.rollID then f = cand break end
    end
    if not f then f = GetRollFrame(1) end

    f.rollID = rollID
    rollFrameByRollID[rollID] = f

    local texture, name, count, quality, bop, canNeed, canGreed, canDE = GetLootRollItemInfo(rollID)
    f.__iconTex:SetTexture(texture)
    if f.__nameFS then
        f.__nameFS:SetText(name or "")
    end

    local dur = (rollTime and rollTime > 0 and rollTime / 1000) or 60
    f.__duration = dur
    f.__endTime = GetTime() + dur
    f.__stateUntil = GetTime() + 2  -- re-check button availability for 2s
    f.__timer:SetValue(1)

    RefreshRollFrameSkin(f)
    ColorRollFrameByQuality(f)
    UpdateRollFrameButtonStates(f)
    f:Show()
    LayoutRollFrames()
end

local function StopRollFrame(rollID)
    local f = rollFrameByRollID[rollID]
    if not f then return end
    f.rollID = nil
    f.__endTime = nil
    rollFrameByRollID[rollID] = nil
    f:Hide()
    LayoutRollFrames()
end

-- Hide/neutralize the native Blizzard loot frames: we render our own.
local nativeHidden = {}
local function NeutralizeNativeFrames()
    for i = 1, 4 do
        local nf = _G["GroupLootFrame"..i]
        if nf and not nativeHidden[nf] then
            nativeHidden[nf] = true
            nf:SetAlpha(0)
            nf:EnableMouse(false)
            -- Move it far off-screen so nothing native ever shows. Hooking
            -- OnShow to re-hide covers the client re-showing it each roll.
            nf:HookScript("OnShow", function(self)
                self:SetAlpha(0)
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", 500, 0)
            end)
            nf:ClearAllPoints()
            nf:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", 500, 0)
        end
    end
end

local function ShowTestFrame()
    -- Test mode drives a real pool frame (index 1) with dummy data so the
    -- preview is identical to a live roll. A fixed rollID of -1 marks it as
    -- test (buttons no-op on rollID < 0).
    NeutralizeNativeFrames()
    local f = GetRollFrame(1)
    f.rollID = -1
    f.__iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    if f.__nameFS then f.__nameFS:SetText(L.TEST_ITEM) end
    f.__duration = 60
    f.__endTime = GetTime() + 60
    f.__timer:SetValue(0.6)

    RefreshRollFrameSkin(f)
    -- Purple border signals test mode.
    f:SetBackdropBorderColor(0.64, 0.21, 0.93, 1)
    for _, btn in ipairs(f.__buttons) do btn:Enable() btn:SetAlpha(1) end

    f:ClearAllPoints()
    if CleanLootDB.point then
        f:SetPoint(CleanLootDB.point, UIParent, CleanLootDB.relativePoint, CleanLootDB.x, CleanLootDB.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    end
    ApplyFrameScale()
    testModeActive = true
    f:Show()
end

local function HideTestFrame()
    local f = rollFrames[1]
    if f and f.rollID == -1 then
        f.rollID = nil
        f.__endTime = nil
        f:Hide()
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

-- Roll-type icons, shared by the recap and history windows.
local TYPE_ICON = {
    Need       = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    Greed      = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    Disenchant = "Interface\\Buttons\\UI-GroupLoot-DE-Up",
}

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

-- Optional chat cleanup: ChatFrame message filters hide messages from the
-- chat DISPLAY only; the CHAT_MSG_LOOT event still fires for addons, so the
-- recap and roll tooltips keep working. Win announcements are only hidden
-- when the recap is enabled, so the information is never lost.
local function SpamFormatToPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("%%%%s", ".+")
    p = p:gsub("%%%%d", "%%d+")
    return "^" .. p .. "$"
end

local EXTRA_SPAM_PATTERNS = {}
for _, fmt in ipairs({ LOOT_ROLL_ALL_PASSED, LOOT_ROLL_PASSED_AUTO,
                       LOOT_ROLL_ROLLED_NEED, LOOT_ROLL_ROLLED_GREED, LOOT_ROLL_ROLLED_DE }) do
    local p = SpamFormatToPattern(fmt)
    if p then table.insert(EXTRA_SPAM_PATTERNS, p) end
end

local function RollSpamFilter(self, event, msg)
    if not CleanLootDB.hideRollSpam or type(msg) ~= "string" then return false end
    for _, def in ipairs(ROLL_CHOICE_PATTERNS) do
        if msg:match(def.pattern) then return true end
    end
    for _, p in ipairs(EXTRA_SPAM_PATTERNS) do
        if msg:match(p) then return true end
    end
    if CleanLootDB.winRecap then
        for _, def in ipairs(WIN_PATTERNS) do
            if msg:match(def.pattern) then return true end
        end
    end
    return false
end

if ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", RollSpamFilter)
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
    f:SetSize(240, 40)
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
    ApplyFont(title)
    f.__title = title

    -- Pool of clickable lines (mouseover -> item tooltip)
    f.__lines = {}
    for i = 1, MAX_WIN_LINES do
        local line = CreateFrame("Button", nil, f)
        line:SetHeight(14)
        line:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -18 - (i - 1) * 15)
        line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -18 - (i - 1) * 15)

        local typeIcon = line:CreateTexture(nil, "ARTWORK")
        typeIcon:SetSize(12, 12)
        typeIcon:SetPoint("LEFT", 0, 0)
        line.__typeIcon = typeIcon

        local fs = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", typeIcon, "RIGHT", 3, 0)
        fs:SetPoint("RIGHT", line, "RIGHT", 0, 0)
        fs:SetJustifyH("LEFT")
        ApplyFont(fs)
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
    -- Same bg table as the loot frames => identical opacity by construction.
    winsFrame:SetBackdropColor(unpack(currentSkin.bg))
    winsFrame:SetBackdropBorderColor(unpack(currentSkin.border))
    ApplyFont(winsFrame.__title)
    for _, line in ipairs(winsFrame.__lines or {}) do
        ApplyFont(line.__text)
    end
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
            if line.__typeIcon then
                local icon = entry.winType and TYPE_ICON[entry.winType]
                if icon then
                    line.__typeIcon:SetTexture(icon)
                    line.__typeIcon:Show()
                    line.__text:SetPoint("LEFT", line.__typeIcon, "RIGHT", 3, 0)
                else
                    line.__typeIcon:Hide()
                    line.__text:SetPoint("LEFT", line, "LEFT", 0, 0)
                end
            end
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
local TYPE_ABBR = { Need = NEED or "Need", Greed = GREED or "Greed", Disenchant = "DE" }

HandleWinMessage = function(text)
    for _, def in ipairs(WIN_PATTERNS) do
        local capture = text:match(def.pattern)
        if capture then
            local playerName = def.isSelf and (UnitName("player") or "?") or capture
            local coloredLink = text:match("|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r")
            local bareLink = text:match("|H(item:[^|]+)|h")
            local displayName = coloredLink or text:match("%[(.-)%]") or "?"
            local itemName = text:match("%[(.-)%]")

            -- Resolve tier/value by ITEM NAME (present in the message).
            local winType, winValue, rolls
            if itemName then
                local tier, list = ComputeWinningTierByName(itemName)
                rolls = list
                if list[1] then
                    winValue = list[1].value
                    winType = list[1].type
                end
            end

            -- Record history (always, with whatever we have).
            table.insert(rollHistory, 1, {
                link = coloredLink or ("["..(itemName or "item").."]"),
                bareLink = bareLink,
                winner = playerName,
                winType = winType,
                winValue = winValue,
                rolls = rolls or {},
                time = GetTime(),
            })
            while #rollHistory > MAX_HISTORY do table.remove(rollHistory) end

            -- Clear captured values for this item (roll resolved).
            rollValuesByName[itemName] = nil

            if CleanLootDB.winRecap then
                local prefix
                if winValue then
                    prefix = ("%s - %d"):format(playerName, winValue)
                else
                    prefix = playerName
                end
                CreateWinsFrame()
                table.insert(winEntries, 1, {
                    text = ("%s: %s"):format(prefix, displayName),
                    link = bareLink,
                    winType = winType,
                    detailRolls = rolls,
                    itemName = itemName,
                    expires = GetTime() + WIN_DURATION,
                })
                while #winEntries > MAX_WIN_LINES do
                    table.remove(winEntries)
                end
                RefreshWinsDisplay()
            end
            return CleanLootDB.winRecap and true or false
        end
    end
    return false
end

-------------------------------------------------
-- Roll history window (session only)
-- Opened via /cll history or the options button. Lists past items with the
-- winner, winning type/value, and each item's winning-tier rolls, which can
-- be expanded/collapsed per item.
-------------------------------------------------
local historyFrame
local historyExpanded = {}  -- index -> bool

local HISTORY_LINES = 14
local HIST_LINE_H = 16
local RefreshHistory

local function CreateHistoryFrame()
    if historyFrame then return historyFrame end

    local f = CreateFrame("Frame", "CleanLootHistoryFrame", UIParent)
    f:SetSize(320, 30 + HISTORY_LINES * HIST_LINE_H + 16)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    EnsureBackdropSupport(f)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText(L.HIST_TITLE)
    ApplyFont(title, 12)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    local scroll = CreateFrame("ScrollFrame", "CleanLootHistoryScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, HIST_LINE_H, function() RefreshHistory() end)
    end)
    f.__scroll = scroll

    f.__lines = {}
    for i = 1, HISTORY_LINES do
        local line = CreateFrame("Button", nil, f)
        line:SetHeight(HIST_LINE_H)
        line:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28 - (i - 1) * HIST_LINE_H)
        line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -28 - (i - 1) * HIST_LINE_H)

        local icon = line:CreateTexture(nil, "ARTWORK")
        icon:SetSize(12, 12)
        icon:SetPoint("LEFT", 0, 0)
        line.__icon = icon

        local fs = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", icon, "RIGHT", 3, 0)
        fs:SetPoint("RIGHT", line, "RIGHT", 0, 0)
        fs:SetJustifyH("LEFT")
        ApplyFont(fs)
        line.__text = fs

        local hl = line:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(0.3, 0.5, 0.8, 0.15)

        line:SetScript("OnEnter", function(self)
            if self.__link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if pcall(GameTooltip.SetHyperlink, GameTooltip, self.__link) then GameTooltip:Show() end
            end
        end)
        line:SetScript("OnLeave", function() GameTooltip:Hide() end)
        line:SetScript("OnClick", function(self)
            if self.__histIndex then
                historyExpanded[self.__histIndex] = not historyExpanded[self.__histIndex]
                RefreshHistory()
            end
        end)
        table.insert(f.__lines, line)
    end

    local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOP", 0, -60)
    empty:SetText(L.HIST_EMPTY)
    empty:Hide()
    f.__empty = empty

    -- New frames are shown by default; hide it so the first ToggleHistory
    -- call opens it instead of seeing it already-shown and closing it (the
    -- "have to click twice the first time" bug).
    f:Hide()

    historyFrame = f
    return f
end

-- Flattens history into display rows (header rows + expanded roll rows).
local function BuildHistoryRows()
    local rows = {}
    for idx, entry in ipairs(rollHistory) do
        local linkText = entry.link and ("|H"..entry.link.."|h["..(entry.link:match("%[?([^%]|]+)")or"item").."]|h") or "[item]"
        -- Use the stored full link if it already includes color/brackets.
        local shown = entry.link or "[item]"
        local header
        local expandable = entry.rolls and #entry.rolls > 0
        local arrow = expandable and (historyExpanded[idx] and "- " or "+ ") or "  "
        if entry.winner then
            local suffix = ""
            if entry.winType and entry.winValue then
                suffix = (" - %s %d"):format(TYPE_ABBR[entry.winType] or entry.winType, entry.winValue)
            elseif entry.winType then
                suffix = (" - %s"):format(TYPE_ABBR[entry.winType] or entry.winType)
            end
            header = ("%s%s: %s%s"):format(arrow, entry.winner, shown, suffix)
        else
            header = ("%s%s - %s"):format(arrow, shown, L.EVERYONE_PASSED)
        end
        table.insert(rows, { text = header, link = entry.link, histIndex = idx, isHeader = true })

        if expandable and historyExpanded[idx] then
            for _, r in ipairs(entry.rolls) do
                table.insert(rows, {
                    text = ("    %d - %s"):format(r.value or 0, r.player),
                    icon = TYPE_ICON[r.type],
                    isRoll = true,
                })
            end
        end
    end
    return rows
end

RefreshHistory = function()
    if not historyFrame then return end
    local rows = BuildHistoryRows()
    local total = #rows
    FauxScrollFrame_Update(historyFrame.__scroll, total, HISTORY_LINES, HIST_LINE_H)
    local offset = FauxScrollFrame_GetOffset(historyFrame.__scroll)

    for i = 1, HISTORY_LINES do
        local line = historyFrame.__lines[i]
        local row = rows[offset + i]
        if row then
            line.__text:SetText(row.text)
            line.__link = row.link
            line.__histIndex = row.histIndex
            if row.icon then
                line.__icon:SetTexture(row.icon)
                line.__icon:Show()
            else
                line.__icon:Hide()
            end
            line:Show()
        else
            line:Hide()
        end
    end

    historyFrame.__empty:SetShown(total == 0)
end

local function ToggleHistory()
    local f = CreateHistoryFrame()
    if f:IsShown() then
        f:Hide()
    else
        RefreshHistory()
        f:Show()
    end
end



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
    f:SetSize(230, 384)
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
        LayoutRollFrames()
    end)
    downBtn:SetScript("OnClick", function()
        downBtn:SetChecked(true)
        upBtn:SetChecked(false)
        CleanLootDB.growDirection = "DOWN"
        LayoutRollFrames()
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

    local hideSpamBtn = CreateFrame("CheckButton", "CleanLootHideSpamButton", f, "UICheckButtonTemplate")
    hideSpamBtn:SetPoint("TOPLEFT", 14, -254)
    _G[hideSpamBtn:GetName().."Text"]:SetText(L.OPT_HIDE_SPAM)
    hideSpamBtn:SetScript("OnClick", function()
        CleanLootDB.hideRollSpam = hideSpamBtn:GetChecked() and true or false
    end)

    local detailBtn = CreateFrame("CheckButton", "CleanLootDetailWinsButton", f, "UICheckButtonTemplate")
    detailBtn:SetPoint("TOPLEFT", 14, -276)
    _G[detailBtn:GetName().."Text"]:SetText(L.OPT_DETAIL_WINS)
    detailBtn:SetScript("OnClick", function()
        CleanLootDB.detailedWins = detailBtn:GetChecked() and true or false
    end)

    local histBtn = CreateFrame("Button", "CleanLootHistoryButton", f, "UIPanelButtonTemplate")
    histBtn:SetSize(120, 20)
    histBtn:SetPoint("TOPLEFT", 16, -300)
    histBtn:SetText(L.HIST_BTN)
    histBtn:SetScript("OnClick", function() ToggleHistory() end)

    -- Frame scale (0.8 to 1.5, 0.05 steps)
    local scaleSlider = CreateFrame("Slider", "CleanLootScaleSlider", f, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 22, -344)
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

    f.hideSpamBtn = hideSpamBtn
    f.detailBtn = detailBtn
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
    f.hideSpamBtn:SetChecked(CleanLootDB.hideRollSpam and true or false)
    f.detailBtn:SetChecked(CleanLootDB.detailedWins and true or false)

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
    elseif msg == "history" then
        ToggleHistory()
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
        print(L.HELP_HISTORY)
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
local coreInitialized = false

local function InitializeCore()
    if coreInitialized then return end
    coreInitialized = true

    ApplyDeleteConfirmOverride()
    SetupAutoConfirm()
    NeutralizeNativeFrames()

    -- Pre-create the frame pool so the skin is ready before the first roll.
    for i = 1, NUM_ROLL_FRAMES do
        GetRollFrame(i)
    end

    ApplyFrameScale()
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("START_LOOT_ROLL")
watcher:RegisterEvent("CANCEL_LOOT_ROLL")

watcher:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Pure Lua only here (defaults + skin table): zero frame API calls
        -- during the early, fragile phase of a UI (re)load.
        CleanLootDB.growDirection = CleanLootDB.growDirection or "DOWN"
        CleanLootDB.skin = CleanLootDB.skin or "classic"
        if CleanLootDB.noConfirm == nil then CleanLootDB.noConfirm = false end
        if CleanLootDB.simpleDeleteConfirm == nil then CleanLootDB.simpleDeleteConfirm = false end
        if CleanLootDB.debugMode == nil then CleanLootDB.debugMode = false end
        if CleanLootDB.winRecap == nil then CleanLootDB.winRecap = true end
        if CleanLootDB.hideRollSpam == nil then CleanLootDB.hideRollSpam = false end
        if CleanLootDB.detailedWins == nil then CleanLootDB.detailedWins = false end
        if CleanLootDB.frameScale == nil then CleanLootDB.frameScale = 1 end
        CopySkin(CleanLootDB.skin)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Frame work deferred to PEW (UI fully rebuilt), avoids Error #132.
        InitializeCore()
    elseif event == "PLAYER_LOGIN" then
        EnsureLootSpamCVar()
    elseif event == "START_LOOT_ROLL" then
        InitializeCore()
        local rollID, rollTime = arg1, arg2
        local ok, err = pcall(StartRollFrame, rollID, rollTime)
        if not ok then PrintError("StartRollFrame", err) end
    elseif event == "CANCEL_LOOT_ROLL" then
        local ok, err = pcall(StopRollFrame, arg1)
        if not ok then PrintError("StopRollFrame", err) end
    end
end)
