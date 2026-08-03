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
        OPT_HEADER       = "Options",
        OPT_STACK_DIR    = "Stacking direction",
        OPT_GROW_UP      = "Upwards (1st at bottom)",
        OPT_GROW_DOWN    = "Downwards (Blizzard default)",
        OPT_STYLE        = "Visual style",
        OPT_SKIN_CLASSIC = "Improved classic",
        OPT_SKIN_ELVUI   = "ElvUI inspired",
        OPT_CONFIRM      = "Confirmations",
        OPT_NO_CONFIRM   = "Skip popups (roll/BoP)",
        OPT_SIMPLE_DEL   = "Simple Delete confirmation",
        OPT_SCALE        = "Frame scale",
        OPT_HIDE_SPAM    = "Hide roll messages from chat",
        OPT_AUTO_GREED   = "Auto-greed greens",
        OPT_AUTO_DE      = "Auto-DE greens (else greed)",
        OPT_WINNER_POPUP = "Winner popup (log closed)",
        RULE_CREATED     = "auto-roll rule set: %s on %s",
        RULES_TITLE      = "Auto-roll rules",
        RULES_BTN        = "Auto-roll rules",
        RULES_ADD        = "Add",
        RULES_EMPTY      = "No rules yet. Add an item below or right-click a roll button.",
        RULES_ITEM_LABEL = "Item name or ID:",
        RULE_REMOVED     = "auto-roll rule removed: %s",
        HIST_BTN         = "History",
        HELP_HISTORY     = "  /cll history   - open the roll history window",
        HELP_RULES       = "  /cll arr       - open the auto-roll rules window",
        ABOUT_TITLE      = "CleanLoot",
        ABOUT_SUBTITLE   = "Clean, lightweight loot roll frames for 3.3.5 / Ascension (CoA).",
        ABOUT_GUIDE      = "Quick guide",
        ABOUT_G_LOG      = "|cffffd200Roll log|r: one window with every item and who rolled what. Click an item to fold/unfold. Open it from the minimap button or /cll history.",
        ABOUT_G_POPUP    = "|cffffd200Winner popup|r: a small popup shows each winner for 12s when the log is closed. Click it to open the full log. Toggle in Options: \"Winner popup\".",
        ABOUT_G_AUTOOPEN = "|cffffd200Auto-open|r: opens the log on every drop. Off by default; enable in Options: \"Auto-open roll log on drop\".",
        ABOUT_G_AUTORULE = "|cffffd200Auto-roll rules|r: right-click a roll button to always roll that way for that item (it won\'t appear again). Manage rules with the button below or /cll arr.",
        ABOUT_G_AUTOGREED= "|cffffd200Auto-greed|r: auto-greed (or DE) green items. Enable in Options.",
        ABOUT_G_COUNTERS = "|cffffd200Vote counters|r: each roll button shows how many picked it; mouse over for names, even if the button is grayed.",
        ABOUT_OPEN_RULES = "Auto-roll rules",
        ABOUT_COMMANDS   = "Commands",
        ABOUT_OPEN_TEST  = "Open test mode",
        ABOUT_OPEN_OPTS  = "Open options",
        ABOUT_OPEN_HIST  = "Open history",
        ABOUT_HIDE_MM    = "Hide minimap button",
        LOG_TITLE        = "Roll log",
        LOG_EMPTY        = "No rolls yet",
        OPT_AUTO_OPEN    = "Auto-open roll log on drop",
        MINIMAP_TT_LEFT  = "Left-click: roll history",
        MINIMAP_TT_RIGHT = "Right-click: test mode",
        EVERYONE_PASSED  = "everyone passed",
        MSG_LOOTSPAM_ON  = "the '%s' interface option was enabled (required for the winners recap and the roll tooltips).",
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
        OPT_HEADER       = "Options",
        OPT_STACK_DIR    = "Direction d'empilement",
        OPT_GROW_UP      = "Vers le haut (1er en bas)",
        OPT_GROW_DOWN    = "Vers le bas (defaut Blizzard)",
        OPT_STYLE        = "Style visuel",
        OPT_SKIN_CLASSIC = "Classique ameliore",
        OPT_SKIN_ELVUI   = "Inspire d'ElvUI",
        OPT_CONFIRM      = "Confirmations",
        OPT_NO_CONFIRM   = "Ignorer les popups (roll/BoP)",
        OPT_SIMPLE_DEL   = "Confirmation simple pour Delete",
        OPT_SCALE        = "Echelle des fenetres",
        OPT_HIDE_SPAM    = "Masquer les messages de roll du chat",
        OPT_AUTO_GREED   = "Greed auto verts",
        OPT_AUTO_DE      = "DE auto verts (sinon greed)",
        OPT_WINNER_POPUP = "Popup gagnant (journal ferme)",
        RULE_CREATED     = "regle auto-roll definie : %s sur %s",
        RULES_TITLE      = "Regles auto-roll",
        RULES_BTN        = "Regles auto-roll",
        RULES_ADD        = "Ajouter",
        RULES_EMPTY      = "Aucune regle. Ajoute un objet ci-dessous ou clic-droit un bouton de roll.",
        RULES_ITEM_LABEL = "Nom ou ID de objet :",
        RULE_REMOVED     = "regle auto-roll supprimee : %s",
        HIST_BTN         = "Historique",
        HELP_HISTORY     = "  /cll history   - ouvre la fenetre d'historique des rolls",
        HELP_RULES       = "  /cll arr       - ouvre la fenetre des regles d'auto-roll",
        ABOUT_TITLE      = "CleanLoot",
        ABOUT_SUBTITLE   = "Fenetres de loot roll legeres et epurees pour 3.3.5 / Ascension (CoA).",
        ABOUT_GUIDE      = "Guide rapide",
        ABOUT_G_LOG      = "|cffffd200Journal des rolls|r : une fenetre avec chaque objet et qui a roll quoi. Clic sur un objet pour plier/deplier. Ouvre-le via le bouton minimap ou /cll history.",
        ABOUT_G_POPUP    = "|cffffd200Popup du gagnant|r : un petit popup montre chaque gagnant 12s quand le journal est ferme. Clic pour ouvrir le journal complet. Option : \"Popup gagnant\".",
        ABOUT_G_AUTOOPEN = "|cffffd200Ouverture auto|r : ouvre le journal a chaque drop. Desactive par defaut ; active dans Options : \"Ouvrir le journal au drop\".",
        ABOUT_G_AUTORULE = "|cffffd200Regles auto-roll|r : clic droit un bouton de roll pour toujours roll ainsi cet objet (il ne reapparaitra plus). Gere les regles via le bouton ci-dessous ou /cll arr.",
        ABOUT_G_AUTOGREED= "|cffffd200Auto-greed|r : greed (ou DE) auto sur les objets verts. Active dans Options.",
        ABOUT_G_COUNTERS = "|cffffd200Compteurs|r : chaque bouton affiche combien l\'ont choisi ; survole pour les noms, meme si le bouton est grise.",
        ABOUT_OPEN_RULES = "Regles auto-roll",
        ABOUT_COMMANDS   = "Commandes",
        ABOUT_OPEN_TEST  = "Ouvrir le mode test",
        ABOUT_OPEN_OPTS  = "Ouvrir les options",
        ABOUT_OPEN_HIST  = "Ouvrir l'historique",
        ABOUT_HIDE_MM    = "Masquer le bouton de la minimap",
        LOG_TITLE        = "Journal des rolls",
        LOG_EMPTY        = "Aucun roll pour le moment",
        OPT_AUTO_OPEN    = "Ouvrir le journal au drop d'un item",
        MINIMAP_TT_LEFT  = "Clic gauche : historique des rolls",
        MINIMAP_TT_RIGHT = "Clic droit : mode test",
        EVERYONE_PASSED  = "tout le monde a passe",
        MSG_LOOTSPAM_ON  = "l'option d'interface '%s' a ete activee (necessaire pour le recap des gagnants et les tooltips de roll).",
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

-- Real error messages always stay visible (useful for support).
-- Purely diagnostic messages only show in debug mode
-- (/cll debugmode), to avoid spamming an end user's chat.
local function PrintError(context, err)
    print(ERR .. L.ERR_GENERIC:format(tostring(context), tostring(err)))
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

-- Skin a button with an ElvUI-like flat look: dark background, 1px border,
-- gold text, subtle highlight on hover. Strips the default Blizzard textures.
local function SkinElvButton(btn)
    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end
    if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    EnsureBackdropSupport(btn)
    btn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(0.09, 0.09, 0.09, 1)
    btn:SetBackdropBorderColor(0, 0, 0, 1)
    local fs = btn:GetFontString()
    if fs then
        fs:SetTextColor(1, 0.82, 0)
        if fs.SetFont then
            local file, _, flags = fs:GetFont()
            if file then fs:SetFont(file, 11, flags) end
        end
    end
    btn:HookScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.18, 0.18, 1)
        self:SetBackdropBorderColor(1, 0.82, 0, 0.8)
    end)
    btn:HookScript("OnLeave", function(self)
        self:SetBackdropColor(0.09, 0.09, 0.09, 1)
        self:SetBackdropBorderColor(0, 0, 0, 1)
    end)
end

-- Replace a Blizzard UIPanelCloseButton's art with a flat ElvUI-style square
-- bearing a gold "x", with a hover highlight. Keeps the button's OnClick.
local function SkinElvCloseButton(btn)
    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end
    if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    btn:SetSize(20, 20)
    EnsureBackdropSupport(btn)
    btn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(0.09, 0.09, 0.09, 1)
    btn:SetBackdropBorderColor(0, 0, 0, 1)
    local x = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    x:SetPoint("CENTER", 0, 0)
    x:SetText("x")
    x:SetTextColor(1, 0.82, 0)
    btn.__xLabel = x
    btn:HookScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.18, 0.18, 1)
        self:SetBackdropBorderColor(1, 0.82, 0, 0.8)
        if self.__xLabel then self.__xLabel:SetTextColor(1, 1, 1) end
    end)
    btn:HookScript("OnLeave", function(self)
        self:SetBackdropColor(0.09, 0.09, 0.09, 1)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        if self.__xLabel then self.__xLabel:SetTextColor(1, 0.82, 0) end
    end)
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
        frameSize       = { 224, 70 },
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
    iconSize     = 28,
    iconPos      = { 4, -4 },
    namePos      = { 36, -6 },
    barInset     = 4,
    barHeight    = 8,
    buttonHeight = 15,
    buttonTop    = { 4, -36 },
}

local currentSkin = {}
local testFrame
local RefreshTestFrameSkin
local HandleWinMessage
local function CopySkin(name)
    for k, v in pairs(SKINS[name] or SKINS.classic) do
        currentSkin[k] = v
    end
end
CopySkin("classic")

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
-- "Who rolled what" tracking + tooltip when hovering the buttons
-------------------------------------------------
-- The game broadcasts a system message for each choice ("X has selected
-- Greed for: [Item]"). Instead of hardcoded English patterns, we build the
-- patterns from Blizzard global strings (LOOT_ROLL_NEED, etc.), which are
-- already translated to the client language: parsing is therefore
-- automatically localized. English fallback if the globals do not exist.
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

-- Win-announcement patterns ("X won: [Item]" / "You won: [Item]"), used by
-- HandleWinMessage to resolve a log entry. Built from Blizzard global strings
-- (auto-localized) with an English fallback.
local WIN_PATTERNS = {}
do
    -- Others: "%s won: %s" -> capture the player (first %s).
    local other = LOOT_ROLL_WON or LOOT_ITEM_WHILE_ROLLING or "%s won: %s"
    if type(other) == "string" then
        local p = other:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        -- First %%s = player (capture), second %%s = item (ignore).
        p = p:gsub("%%%%s", "(.+)", 1):gsub("%%%%s", ".+")
        table.insert(WIN_PATTERNS, { pattern = "^" .. p, isSelf = false })
    end
    -- Self: "You won: %s" -> no player capture.
    local mine = LOOT_ROLL_YOU_WON or "You won: %s"
    if type(mine) == "string" then
        local p = mine:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        p = p:gsub("%%%%s", ".+")
        table.insert(WIN_PATTERNS, { pattern = "^" .. p, isSelf = true })
    end
end
if #WIN_PATTERNS == 0 then
    WIN_PATTERNS = {
        { pattern = "^(.+) won:", isSelf = false },
        { pattern = "^You won:", isSelf = true },
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


-- Session history: newest first, capped. Each entry captured when a roll is
-- won or fully resolved: { itemLink, winner, winType, winValue, rolls = {...} }.
local rollItemLinks = {}   -- rollID -> item link (for history/detail display)
local rollValuesByName = {}  -- item name -> { {player, type, value}, ... }


-------------------------------------------------
-- Combined roll log (data model for the unified recap window)
-- One ordered list of items. Each item holds every group member as a row
-- (name + "waiting" until they roll, then type + value). While unresolved
-- the item is expanded; once resolved it collapses and its rows are sorted
-- Need > Greed/DE > Pass, then by roll value descending. Replaces both the
-- old winners recap and the history window.
-------------------------------------------------
local MAX_LOG_ITEMS = 100
local rollLog = {}                  -- newest first
local rollLogByName = {}            -- item name -> entry (for live updates)

local ROLL_PRIORITY = { Need = 1, Greed = 2, Disenchant = 2, Pass = 3, Waiting = 4 }

-- Snapshot the current party/raid roster (names), to pre-fill every item's
-- rows with "waiting" players (option A). Non-rollers are pruned on resolve.
local function GetGroupRoster()
    local names = {}
    local me = UnitName("player")
    if me then table.insert(names, me) end
    local nRaid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    local nParty = (GetNumPartyMembers and GetNumPartyMembers()) or 0
    if nRaid > 0 then
        for i = 1, nRaid do
            local n = UnitName("raid"..i)
            if n and n ~= me then table.insert(names, n) end
        end
    elseif nParty > 0 then
        for i = 1, nParty do
            local n = UnitName("party"..i)
            if n then table.insert(names, n) end
        end
    end
    return names
end

local RefreshRollLogWindow  -- forward (defined with the window)
local OpenRollLogWindow     -- forward

-- Called at START_LOOT_ROLL: always start a FRESH entry for this item, even if
-- the same item name already has a (resolved) entry from a previous roll. This
-- is what makes repeated drops of the same item each get their own roll block
-- and their own vote list, instead of accumulating into one shared entry.
local function StartNewLogEntry(itemName, link, icon)
    local e = {
        name = itemName, link = link, icon = icon,
        resolved = false, expanded = false, winner = nil,
        players = {}, order = {},
    }
    for _, pname in ipairs(GetGroupRoster()) do
        e.players[pname] = { name = pname, type = "Waiting", value = nil }
        table.insert(e.order, pname)
    end
    rollLogByName[itemName] = e   -- active entry for this name = the new one
    table.insert(rollLog, 1, e)
    while #rollLog > MAX_LOG_ITEMS do
        local removed = table.remove(rollLog)
        -- Only clear the name map if it still points at the removed entry.
        if removed and removed.name and rollLogByName[removed.name] == removed then
            rollLogByName[removed.name] = nil
        end
    end
    return e
end

-- Active (in-progress) entry for an item name, used by chat updates. Returns
-- nil if the current entry is already resolved (so late/duplicate chat lines
-- can't pollute a finished roll). Falls back to creating one if a chat line
-- somehow arrives with no active entry (e.g. START missed).
local function GetActiveLogEntry(itemName, createIfMissing)
    local e = rollLogByName[itemName]
    if e and not e.resolved then return e end
    if e and e.resolved then
        return createIfMissing and StartNewLogEntry(itemName, e.link, e.icon) or nil
    end
    if createIfMissing then return StartNewLogEntry(itemName) end
    return nil
end

local function LogPlayerRoll(itemName, playerName, rollType, value)
    if not itemName or not playerName then return end
    local e = GetActiveLogEntry(itemName, true)
    if not e then return end
    local p = e.players[playerName]
    if not p then
        p = { name = playerName }
        e.players[playerName] = p
        table.insert(e.order, playerName)
    end
    p.type = rollType or p.type
    if value then p.value = value end
    if RefreshRollLogWindow then RefreshRollLogWindow() end
end

local function SortResolvedPlayers(e)
    local rows = {}
    for _, pname in ipairs(e.order) do
        local p = e.players[pname]
        if p and p.type ~= "Waiting" then table.insert(rows, p) end
    end
    table.sort(rows, function(a, b)
        local pa = ROLL_PRIORITY[a.type] or 9
        local pb = ROLL_PRIORITY[b.type] or 9
        if pa ~= pb then return pa < pb end
        return (a.value or 0) > (b.value or 0)
    end)
    return rows
end

local NotifyWinnerPopup  -- forward (defined with the popup)

local function ResolveLogEntry(itemName, winnerName)
    local e = rollLogByName[itemName]
    if not e then return end
    e.resolved = true
    e.expanded = false
    e.winner = winnerName
    e.sortedRows = SortResolvedPlayers(e)
    if RefreshRollLogWindow then RefreshRollLogWindow() end
    -- Fire the ephemeral winner popup (only shows if enabled and the big
    -- log window is closed; handled inside NotifyWinnerPopup).
    if NotifyWinnerPopup then
        local winValue
        if e.sortedRows and e.sortedRows[1] and e.sortedRows[1].name == winnerName then
            winValue = e.sortedRows[1].value
        end
        NotifyWinnerPopup(e.link or ("["..(e.name or "item").."]"), winnerName, winValue, e.icon)
    end
end

local rollChoiceWatcher = CreateFrame("Frame")
rollChoiceWatcher:RegisterEvent("CHAT_MSG_LOOT")
rollChoiceWatcher:RegisterEvent("START_LOOT_ROLL")
rollChoiceWatcher:RegisterEvent("CANCEL_LOOT_ROLL")

rollChoiceWatcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "START_LOOT_ROLL" then
        rollChoices[arg1] = { Need = {}, Greed = {}, Disenchant = {}, Pass = {} }
        rollValues[arg1] = {}
        local link = GetLootRollItemLink and GetLootRollItemLink(arg1)
        if link then rollItemLinks[arg1] = link end
        local icon, name = GetLootRollItemInfo(arg1)
        if (not name or name == "") and link then
            name = link:match("%[(.-)%]")
        end
        if name and name ~= "" then
            rollIDByName[name] = arg1
            rollValuesByName[name] = {}
            -- Create the combined-log entry now, pre-filled with the roster.
            StartNewLogEntry(name, link, icon)
            -- Open FIRST (if enabled), then refresh: RefreshRollLogWindow
            -- early-returns when the window isn't shown, so opening must come
            -- before the refresh or the first drop would show nothing.
            if CleanLootDB.autoOpenRecap and OpenRollLogWindow then
                OpenRollLogWindow()
            elseif RefreshRollLogWindow then
                RefreshRollLogWindow()
            end
        end
    elseif event == "CANCEL_LOOT_ROLL" then
        for nm, id in pairs(rollIDByName) do
            if id == arg1 then rollIDByName[nm] = nil end
        end
        rollChoices[arg1] = nil
        rollValues[arg1] = nil
    elseif event == "CHAT_MSG_LOOT" then
        local text = arg1

        -- Roll value line? "Need Roll - 87 for [Item] by Bob".
        for _, def in ipairs(rollValuePatterns) do
            local value, itemName, player = text:match(def.pattern)
            if value and player then
                local bare = itemName and itemName:match("%[(.-)%]") or itemName
                if bare then
                    if not rollValuesByName[bare] then rollValuesByName[bare] = {} end
                    table.insert(rollValuesByName[bare], {
                        player = player, type = def.type, value = tonumber(value),
                    })
                    LogPlayerRoll(bare, player, def.type, tonumber(value))
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
                -- Update the combined log with the choice (value fills in later
                -- from the "X Roll - N" line).
                if itemName then
                    LogPlayerRoll(itemName, playerName, def.choice, nil)
                end
                break
            end
        end
    end
end)


-- Collect the players who picked a given roll type for a roll, reading from
-- the combined roll log (falls back to the older rollChoices capture). Shared
-- by the mouseover tooltip and the persistent on-button counters.
local function CollectRollVoters(rollID, choiceKey)
    local names = {}
    local itemName = select(2, GetLootRollItemInfo(rollID))
    if (not itemName or itemName == "") then
        local link = rollItemLinks[rollID]
        if link then itemName = link:match("%[(.-)%]") end
    end
    local e = itemName and rollLogByName[itemName]
    if e then
        for _, pname in ipairs(e.order) do
            local p = e.players[pname]
            if p and p.type == choiceKey then
                if p.value then
                    table.insert(names, ("%s (%d)"):format(p.name, p.value))
                else
                    table.insert(names, p.name)
                end
            end
        end
    else
        local choices = rollChoices[rollID]
        local list = choices and choices[choiceKey] or {}
        for _, n in ipairs(list) do table.insert(names, n) end
    end
    return names
end

local function ShowRollChoiceTooltip(button, frame, choiceKey)
    local rollID = frame.rollID
    if not rollID or rollID < 0 then return end

    local names = CollectRollVoters(rollID, choiceKey)

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

-- Update the persistent vote counters shown in each button's corner.
local function UpdateButtonCounts(frame)
    if not frame.__buttons then return end
    local rollID = frame.rollID
    for _, btn in ipairs(frame.__buttons) do
        if btn.__countFS and btn.__choiceKey then
            local n = 0
            if rollID and rollID >= 0 then
                n = #CollectRollVoters(rollID, btn.__choiceKey)
            end
            btn.__countFS:SetText(n > 0 and tostring(n) or "")
        end
    end
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
    if RefreshRollLogWindow then
        RefreshRollLogWindow()
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

-- Auto-roll rules (per item) + unified auto-roll decision
-- Rules are keyed by lowercased item name -> roll type (1 Need, 2 Greed,
-- 3 Disenchant, 0 Pass), persisted in CleanLootDB.autoRollRules. A per-item
-- rule takes priority over the global auto-greed. When an auto-roll applies,
-- the roll frame is not shown at all (handled by StartRollFrame).
-------------------------------------------------
local ROLLTYPE_NAME = { [1] = "Need", [2] = "Greed", [3] = "Disenchant", [0] = "Pass" }

local function GetAutoRollRules()
    CleanLootDB.autoRollRules = CleanLootDB.autoRollRules or {}
    return CleanLootDB.autoRollRules
end

-- A rule value is either a plain number (legacy: roll type only) or a table
-- { type = N, link = itemLink }. These helpers normalize both.
local function RuleType(v)
    if type(v) == "table" then return v.type end
    return v
end
local function RuleLink(v)
    if type(v) == "table" then return v.link end
    return nil
end

local function GetAutoRollRule(itemName)
    if not itemName then return nil end
    return RuleType(GetAutoRollRules()[itemName:lower()])
end

local function SetAutoRollRule(itemName, rollType, itemLink)
    if not itemName or itemName == "" then return end
    -- Try to enrich with a link if not given (resolves by name/ID via cache).
    if not itemLink then
        local _, link = GetItemInfo(itemName)
        itemLink = link
    end
    GetAutoRollRules()[itemName:lower()] = { type = rollType, link = itemLink }
end

local function RemoveAutoRollRule(itemNameLower)
    if not itemNameLower then return end
    GetAutoRollRules()[itemNameLower] = nil
end

-- Is a given roll type actually available for this roll? Reads the native
-- button state (reliable on this server), same source as the gray-out.
local function IsRollTypeAvailable(rollID, rollType)
    if rollType == 0 then return true end  -- Pass always allowed
    local _, nativeName = FindNativeFrameByRollID(rollID)
    if not nativeName then return true end  -- can't tell -> allow
    local suffix = (rollType == 1 and "NeedButton") or (rollType == 2 and "GreedButton")
        or (rollType == 3 and "DisenchantButton")
    local btn = suffix and _G[nativeName..suffix]
    -- Need button is "RollButton" on 3.3.5 if "NeedButton" is absent.
    if rollType == 1 and not btn then btn = _G[nativeName.."RollButton"] end
    if not btn then return true end
    local shown = (not btn.IsShown) or btn:IsShown()
    local enabled = (not btn.IsEnabled) or btn:IsEnabled()
    return shown and enabled
end

-- Decide the auto-roll type for a roll, or nil if none applies. Per-item rule
-- first, then global auto-greed (green only). Returns nil if the chosen type
-- isn't available (option a: leave the frame for manual choice).
local function GetAutoRollDecision(rollID, itemName, quality)
    -- 1) Per-item rule (any quality).
    local rule = GetAutoRollRule(itemName)
    if rule ~= nil then
        if IsRollTypeAvailable(rollID, rule) then return rule end
        return nil  -- rule not applicable this drop -> manual
    end
    -- 2) Global auto-greed, green (uncommon = 2) only.
    local mode = CleanLootDB.autoGreen
    if mode and mode ~= "off" and quality == 2 then
        if mode == "de" then
            if IsRollTypeAvailable(rollID, 3) then return 3 end
            return 2  -- fall back to Greed
        end
        return 2  -- greed
    end
    return nil
end

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

        -- Persistent vote counter in the bottom-right corner (like a stack
        -- count). Shows the number of players who picked this type, only when
        -- >= 1. Full detail (who + values) stays on the mouseover tooltip.
        local countFS = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        countFS:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
        countFS:SetText("")
        btn.__countFS = countFS

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        -- Snapshot the target rollID on mouse-DOWN, not on click (mouse-up).
        -- Between the two, this pooled frame's roll can resolve on its own
        -- (someone else finishes rolling, or the timer runs out) and get
        -- immediately reassigned to a brand new item that just dropped —
        -- without this, OnClick would re-read f.rollID and vote on that new
        -- item instead of the one the player actually clicked.
        btn:SetScript("OnMouseDown", function(self)
            self.__clickRollID = f.rollID
        end)
        btn:SetScript("OnClick", function(self, mouseButton)
            local id = self.__clickRollID
            if not (id and id >= 0) then return end
            if mouseButton == "RightButton" then
                -- Create a per-item auto-roll rule for THIS choice, then roll
                -- it now (if available). The item won't reappear next time.
                if self:IsEnabled() then
                    local itemName = select(2, GetLootRollItemInfo(id))
                    local itemLink = rollItemLinks[id]
                    if (not itemName or itemName == "") and itemLink then
                        itemName = itemLink:match("%[(.-)%]")
                    end
                    if itemName and itemName ~= "" then
                        SetAutoRollRule(itemName, self.__rollType, itemLink)
                        print(MSG .. L.RULE_CREATED:format(
                            ROLLTYPE_NAME[self.__rollType] or "?", itemLink or itemName))
                        local ok, err = pcall(RollOnLoot, id, self.__rollType)
                        if not ok then PrintError("RollOnLoot", err) end
                    end
                end
            else
                -- Left click: normal roll.
                if self:IsEnabled() then
                    local ok, err = pcall(RollOnLoot, id, self.__rollType)
                    if not ok then PrintError("RollOnLoot", err) end
                end
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
    f:SetScript("OnUpdate", function(self, elapsed)
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
        -- Keep the persistent vote counters current for the whole roll, but
        -- throttled to ~4x/sec to stay cheap.
        if self.rollID and self.rollID >= 0 then
            self.__countAcc = (self.__countAcc or 0) + (elapsed or 0)
            if self.__countAcc >= 0.25 then
                self.__countAcc = 0
                if UpdateButtonCounts then UpdateButtonCounts(self) end
            end
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

    -- Decide auto-roll BEFORE showing anything: if a per-item rule or the
    -- global auto-greed applies (and is available), roll without ever showing
    -- the frame. The item simply never appears.
    local autoType = GetAutoRollDecision(rollID, name, quality)
    if autoType ~= nil then
        f.rollID = nil                       -- release the frame we reserved
        rollFrameByRollID[rollID] = nil
        local rid = rollID
        local waiter = CreateFrame("Frame")
        local acc = 0
        waiter:SetScript("OnUpdate", function(self, e)
            acc = acc + (e or 0)
            if acc < 0.1 then return end
            self:SetScript("OnUpdate", nil)
            pcall(RollOnLoot, rid, autoType)
        end)
        return
    end

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
    UpdateButtonCounts(f)
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
-- Loot-spam CVar (needed for roll capture)
-------------------------------------------------
-- "Detailed Loot Information" (CVar showLootSpam) is what makes the client
-- broadcast the per-player roll messages ("X has selected...", "X won...").
-- With it disabled, CHAT_MSG_LOOT never fires for those announcements, which
-- silently kills both the winners recap and the "who rolled what" tooltips.
-- When the recap is enabled, we turn the option on ourselves (once per
-- login if needed) and say so in chat, naming the option in the client's
-- own language.
local function EnsureLootSpamCVar()
    -- Always needed: the roll log captures values from these chat messages,
    -- independently of any display option.
    local ok, value = pcall(GetCVar, "showLootSpam")
    if ok and value == "0" then
        local okSet = pcall(SetCVar, "showLootSpam", "1")
        if okSet then
            print(MSG .. L.MSG_LOOTSPAM_ON:format(SHOW_LOOT_SPAM or "Detailed Loot Information"))
        end
    end
end

-- Recap test mode: a dummy (non-expiring) entry to preview and reposition
-- the window, on the same cycle as the loot roll mover.
local function ShowWinsTest()
    -- Populate the combined log with a fake resolved item and open the window.
    local me = UnitName("player") or "You"
    local testName = L.TEST_ITEM or "Test item"
    local e = StartNewLogEntry(testName, nil)
    e.players = {}
    e.order = {}
    local demo = {
        { name = me,       type = "Need",  value = 92 },
        { name = "Aludra",  type = "Need",  value = 47 },
        { name = "Baric",   type = "Greed", value = 80 },
        { name = "Cyndra",  type = "Pass" },
    }
    for _, d in ipairs(demo) do
        e.players[d.name] = d
        table.insert(e.order, d.name)
    end
    e.__isTest = true
    ResolveLogEntry(testName, me)  -- collapses + sorts
    e.expanded = true              -- but show it expanded for the preview
    if OpenRollLogWindow then OpenRollLogWindow() end
end

local function HideWinsTest()
    -- Remove the test item from the log.
    for i = #rollLog, 1, -1 do
        if rollLog[i].__isTest then
            local nm = rollLog[i].name
            table.remove(rollLog, i)
            if nm then rollLogByName[nm] = nil end
        end
    end
    if RefreshRollLogWindow then RefreshRollLogWindow() end
end

-- Called for every CHAT_MSG_LOOT message; returns true if it was a win
-- announcement (handled), to avoid useless work afterwards.

HandleWinMessage = function(text)
    for _, def in ipairs(WIN_PATTERNS) do
        local capture = text:match(def.pattern)
        if capture then
            local playerName = def.isSelf and (UnitName("player") or "?") or capture
            local itemName = text:match("%[(.-)%]")

            -- Make sure any last-moment roll values are captured, then resolve
            -- the combined-log entry (collapses it, sorts, marks winner).
            if itemName then
                ResolveLogEntry(itemName, playerName)
                -- Clear captured values for this item (roll resolved).
                rollValuesByName[itemName] = nil
            end
            return true
        end
    end
    return false
end

-------------------------------------------------
-- Combined roll log window (replaces the old winners recap + history)
-- One scrollable list of items. Unresolved items are expanded and show every
-- group member (waiting until they roll); resolved items collapse to a header
-- (click to expand) with rows sorted Need > Greed/DE > Pass, value desc.
-------------------------------------------------
local logFrame
local LOG_VISIBLE_ROWS = 8
local LOG_ROW_H = 18

local ICON_BY_TYPE = {
    Need       = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    Greed      = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    Disenchant = "Interface\\Buttons\\UI-GroupLoot-DE-Up",
    Pass       = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}

-- Flatten rollLog into display rows (item headers + player rows for expanded).
local function BuildLogRows()
    local rows = {}
    for _, e in ipairs(rollLog) do
        local arrow = e.expanded and "-" or "+"
        local nameText = e.link and (e.link:match("|c%x+|Hitem.-|h.-|h|r") or e.link) or ("["..(e.name or "item").."]")
        -- If link isn't a full colored link, show the bracketed name.
        if e.link and not e.link:find("|H") then nameText = "["..e.name.."]" end
        local header
        if e.resolved and e.winner then
            header = ("%s %s  (%s)"):format(arrow, nameText, e.winner)
        elseif e.resolved then
            header = ("%s %s  (%s)"):format(arrow, nameText, L.EVERYONE_PASSED or "-")
        else
            header = ("%s %s"):format(arrow, nameText)
        end
        table.insert(rows, {
            isHeader = true, entry = e, text = header, link = e.link,
            itemIcon = e.icon,
        })

        if e.expanded then
            local prows
            if e.resolved and e.sortedRows then
                prows = e.sortedRows
            else
                prows = {}
                for _, pn in ipairs(e.order) do
                    local pp = e.players[pn]
                    if pp then table.insert(prows, pp) end
                end
            end
            for _, p in ipairs(prows) do
                local label
                if p.type == "Waiting" or not p.type then
                    label = ("%s  -  ..."):format(p.name)
                elseif p.value then
                    label = ("%s  -  %d"):format(p.name, p.value)
                else
                    label = ("%s"):format(p.name)
                end
                table.insert(rows, {
                    isPlayer = true,
                    text = label,
                    icon = (p.type ~= "Waiting") and ICON_BY_TYPE[p.type] or nil,
                })
            end
        end
    end
    return rows
end

RefreshRollLogWindow = function()
    if not logFrame or not logFrame:IsShown() then return end
    local rows = BuildLogRows()
    local total = #rows
    FauxScrollFrame_Update(logFrame.__scroll, total, LOG_VISIBLE_ROWS, LOG_ROW_H)
    local offset = FauxScrollFrame_GetOffset(logFrame.__scroll)
    for i = 1, LOG_VISIBLE_ROWS do
        local line = logFrame.__lines[i]
        local row = rows[offset + i]
        if row then
            line.__text:SetText(row.text)
            line.__link = row.link
            line.__entry = row.entry
            if row.isHeader then
                -- Item line: larger item icon, bigger font, no indent.
                line.__icon:SetSize(18, 18)
                line.__icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                line.__icon:ClearAllPoints()
                line.__icon:SetPoint("LEFT", 0, 0)
                if row.itemIcon then
                    line.__icon:SetTexture(row.itemIcon); line.__icon:Show()
                else
                    line.__icon:Hide()
                end
                ApplyFont(line.__text, 12)
                line.__text:ClearAllPoints()
                line.__text:SetPoint("LEFT", line.__icon, "RIGHT", 4, 0)
                line.__text:SetPoint("RIGHT", line, "RIGHT", 0, 0)
            else
                -- Player line: small roll-type icon, small font, indented.
                line.__icon:SetSize(12, 12)
                line.__icon:SetTexCoord(0, 1, 0, 1)
                line.__icon:ClearAllPoints()
                line.__icon:SetPoint("LEFT", 22, 0)
                if row.icon then
                    line.__icon:SetTexture(row.icon); line.__icon:Show()
                else
                    line.__icon:Hide()
                end
                ApplyFont(line.__text, 10)
                line.__text:ClearAllPoints()
                line.__text:SetPoint("LEFT", line.__icon, "RIGHT", 4, 0)
                line.__text:SetPoint("RIGHT", line, "RIGHT", 0, 0)
            end
            line:Show()
        else
            line.__link, line.__entry = nil, nil
            line:Hide()
        end
    end
    logFrame.__empty:SetShown(total == 0)
end

local function CreateLogFrame()
    if logFrame then return logFrame end

    local f = CreateFrame("Frame", "CleanLootLogFrame", UIParent)
    f:SetSize(230, 32 + LOG_VISIBLE_ROWS * LOG_ROW_H + 6)
    if CleanLootDB.logPoint then
        f:SetPoint(CleanLootDB.logPoint, UIParent, CleanLootDB.logRelPoint, CleanLootDB.logX, CleanLootDB.logY)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 320, 60)
    end
    f:SetFrameStrata("DIALOG")
    EnsureBackdropSupport(f)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, rel, x, y = self:GetPoint()
        CleanLootDB.logPoint, CleanLootDB.logRelPoint, CleanLootDB.logX, CleanLootDB.logY = pt, rel, x, y
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText(L.LOG_TITLE)
    ApplyFont(title, 12)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    SkinElvCloseButton(closeBtn)

    local scroll = CreateFrame("ScrollFrame", "CleanLootLogScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LOG_ROW_H, function() RefreshRollLogWindow() end)
    end)
    f.__scroll = scroll

    f.__lines = {}
    for i = 1, LOG_VISIBLE_ROWS do
        local line = CreateFrame("Button", nil, f)
        line:SetHeight(LOG_ROW_H)
        line:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28 - (i - 1) * LOG_ROW_H)
        line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -28 - (i - 1) * LOG_ROW_H)

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
            if self.__entry then
                self.__entry.expanded = not self.__entry.expanded
                RefreshRollLogWindow()
            end
        end)
        table.insert(f.__lines, line)
    end

    local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOP", 0, -60)
    empty:SetText(L.LOG_EMPTY)
    empty:Hide()
    f.__empty = empty

    f:Hide()
    logFrame = f
    return f
end

OpenRollLogWindow = function()
    local f = CreateLogFrame()
    if not f:IsShown() then f:Show() end
    RefreshRollLogWindow()
end

local function ToggleRollLogWindow()
    local f = CreateLogFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        RefreshRollLogWindow()
    end
end

-- Back-compat alias: everything that used to open the history now opens the
-- combined log.
local function ToggleHistory()
    ToggleRollLogWindow()
end

-------------------------------------------------
-- Winner popup (ephemeral)
-- Small movable frame that lists recent roll winners ("Winner: [Item]"),
-- each line lasting ~12s. Only shows when the big log window is closed and
-- the option is enabled. Clicking it opens the full log window.
-------------------------------------------------
local winnerPopup
local WINNER_POPUP_DURATION = 12
local WINNER_POPUP_MAX = 6
local winnerLines = {}   -- { text, link, expires }
local RefreshWinnerPopup  -- forward

local function CreateWinnerPopup()
    if winnerPopup then return winnerPopup end
    local f = CreateFrame("Button", "CleanLootWinnerPopup", UIParent)
    f:SetSize(230, 20)  -- same width as the Roll Log window
    if CleanLootDB.winnerPopupPoint then
        f:SetPoint(CleanLootDB.winnerPopupPoint, UIParent, CleanLootDB.winnerPopupRelPoint,
            CleanLootDB.winnerPopupX, CleanLootDB.winnerPopupY)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 300, 120)
    end
    f:SetFrameStrata("MEDIUM")
    EnsureBackdropSupport(f)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, rel, x, y = self:GetPoint()
        CleanLootDB.winnerPopupPoint, CleanLootDB.winnerPopupRelPoint = pt, rel
        CleanLootDB.winnerPopupX, CleanLootDB.winnerPopupY = x, y
    end)
    -- Click opens the full log window (and hides the popup).
    f:SetScript("OnClick", function()
        if OpenRollLogWindow then OpenRollLogWindow() end
        f:Hide()
    end)
    f:SetScript("OnEnter", function(self)
        if self.__topLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if pcall(GameTooltip.SetHyperlink, GameTooltip, self.__topLink) then GameTooltip:Show() end
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.__lines = {}
    for i = 1, WINNER_POPUP_MAX do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -4 - (i - 1) * 15)
        fs:SetPoint("RIGHT", f, "RIGHT", -6, 0)
        fs:SetJustifyH("LEFT")
        ApplyFont(fs)
        f.__lines[i] = fs
    end

    -- Expiry ticker.
    f:SetScript("OnUpdate", function(self, elapsed)
        if testModeActive then return end  -- keep the demo line while positioning
        self.__acc = (self.__acc or 0) + elapsed
        if self.__acc < 0.5 then return end
        self.__acc = 0
        local now = GetTime()
        local changed = false
        for i = #winnerLines, 1, -1 do
            if winnerLines[i].expires <= now then
                table.remove(winnerLines, i); changed = true
            end
        end
        if changed then RefreshWinnerPopup() end
    end)

    winnerPopup = f
    return f
end

RefreshWinnerPopup = function()
    local f = winnerPopup
    if not f then return end
    if #winnerLines == 0 then f:Hide(); return end
    for i = 1, WINNER_POPUP_MAX do
        local fs = f.__lines[i]
        local entry = winnerLines[i]
        if entry then fs:SetText(entry.text); fs:Show() else fs:Hide() end
    end
    f.__topLink = winnerLines[1] and winnerLines[1].link
    f:SetHeight(8 + math.min(#winnerLines, WINNER_POPUP_MAX) * 15)
    f:Show()
end

NotifyWinnerPopup = function(displayLink, winnerName, winValue, icon, force)
    if not force and not CleanLootDB.winnerPopup then return end
    -- Only when the big log window is closed (unless forced, e.g. test mode).
    if not force and logFrame and logFrame:IsShown() then return end
    CreateWinnerPopup()
    local who = winnerName or "?"
    local text
    if winValue then
        text = ("%s - %d: %s"):format(who, winValue, displayLink)
    else
        text = ("%s: %s"):format(who, displayLink)
    end
    table.insert(winnerLines, 1, {
        text = text,
        link = displayLink and displayLink:match("|H(item:[^|]+)|h") and displayLink or nil,
        expires = GetTime() + WINNER_POPUP_DURATION,
    })
    while #winnerLines > WINNER_POPUP_MAX do table.remove(winnerLines) end
    RefreshWinnerPopup()
end

-------------------------------------------------
-- Auto-roll rules management window
-- Lists all rules (item name + type), lets you change a rule's type via a
-- dropdown, remove it, or add a new one by item name or item ID.
-------------------------------------------------
local optionsFrame
local rulesFrame
local RULES_VISIBLE = 12
local RULES_ROW_H = 22
local RefreshRulesWindow

local RULE_TYPE_CYCLE = { [1] = 2, [2] = 3, [3] = 0, [0] = 1 }  -- Need->Greed->DE->Pass->Need

local function CreateRulesFrame()
    if rulesFrame then return rulesFrame end
    local f = CreateFrame("Frame", "CleanLootRulesFrame", UIParent)
    f:SetSize(340, 60 + RULES_VISIBLE * RULES_ROW_H + 60)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    EnsureBackdropSupport(f)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(L.RULES_TITLE)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    SkinElvCloseButton(closeBtn)

    -- Rows (item name + type button + remove button).
    f.__rows = {}
    for i = 1, RULES_VISIBLE do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(310, RULES_ROW_H)
        row:SetPoint("TOPLEFT", 16, -44 - (i - 1) * RULES_ROW_H)

        -- Clickable name area: shows the item link, tooltip on hover,
        -- shift-click to link in chat.
        local nameBtn = CreateFrame("Button", nil, row)
        nameBtn:SetSize(180, RULES_ROW_H)
        nameBtn:SetPoint("LEFT", 0, 0)
        local nameFS = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFS:SetAllPoints(nameBtn)
        nameFS:SetJustifyH("LEFT")
        nameBtn.__fs = nameFS
        row.__name = nameFS
        nameBtn:SetScript("OnEnter", function(self)
            if row.__name.__link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if pcall(GameTooltip.SetHyperlink, GameTooltip, row.__name.__link) then
                    GameTooltip:Show()
                end
            end
        end)
        nameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        nameBtn:SetScript("OnClick", function()
            if IsShiftKeyDown() and row.__name.__link and ChatEdit_InsertLink then
                ChatEdit_InsertLink(row.__name.__link)
            end
        end)
        row.__nameBtn = nameBtn

        local typeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        typeBtn:SetSize(80, 18)
        typeBtn:SetPoint("LEFT", 184, 0)
        SkinElvButton(typeBtn)
        row.__typeBtn = typeBtn

        local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        delBtn:SetSize(24, 18)
        delBtn:SetPoint("LEFT", 270, 0)
        delBtn:SetText("X")
        SkinElvButton(delBtn)
        row.__delBtn = delBtn

        row:Hide()
        f.__rows[i] = row
    end

    -- Add section: item name/ID edit box + type dropdown + Add button.
    local addLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("BOTTOMLEFT", 16, 40)
    addLabel:SetText(L.RULES_ITEM_LABEL)

    local edit = CreateFrame("EditBox", "CleanLootRuleAddEdit", f, "InputBoxTemplate")
    edit:SetSize(150, 20)
    edit:SetPoint("BOTTOMLEFT", 20, 16)
    edit:SetAutoFocus(false)
    f.__edit = edit

    -- Type selector for the new rule (cycles Need/Greed/DE/Pass).
    local addType = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addType:SetSize(80, 20)
    addType:SetPoint("LEFT", edit, "RIGHT", 8, 0)
    addType.__rollType = 2  -- default Greed
    addType:SetText(ROLLTYPE_NAME[addType.__rollType])
    SkinElvButton(addType)
    addType:SetScript("OnClick", function(self)
        self.__rollType = RULE_TYPE_CYCLE[self.__rollType] or 2
        self:SetText(ROLLTYPE_NAME[self.__rollType])
    end)
    f.__addType = addType

    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 20)
    addBtn:SetPoint("LEFT", addType, "RIGHT", 8, 0)
    addBtn:SetText(L.RULES_ADD)
    SkinElvButton(addBtn)
    addBtn:SetScript("OnClick", function()
        local input = edit:GetText()
        if not input or input == "" then return end
        input = input:gsub("^%s+", ""):gsub("%s+$", "")
        -- Resolve name + link. Numeric input = item ID; otherwise item name.
        local itemName, itemLink = input, nil
        if input:match("^%d+$") then
            local n, link = GetItemInfo(tonumber(input))
            if n then itemName = n end
            itemLink = link
        else
            local n, link = GetItemInfo(input)
            if n then itemName = n end
            itemLink = link
        end
        SetAutoRollRule(itemName, addType.__rollType, itemLink)
        print(MSG .. L.RULE_CREATED:format(ROLLTYPE_NAME[addType.__rollType] or "?", itemLink or itemName))
        edit:SetText("")
        RefreshRulesWindow()
    end)

    local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOP", 0, -50)
    empty:SetWidth(300)
    empty:SetText(L.RULES_EMPTY)
    empty:Hide()
    f.__empty = empty

    f:Hide()
    rulesFrame = f
    return f
end

RefreshRulesWindow = function()
    local f = rulesFrame
    if not f then return end

    -- Group rules by roll type. Only non-empty groups are shown, each with a
    -- foldable header (Need / Greed / Disenchant / Pass).
    local groups = { [1] = {}, [2] = {}, [3] = {}, [0] = {} }
    local total = 0
    for nameLower, v in pairs(GetAutoRollRules()) do
        local t = RuleType(v)
        if groups[t] then
            table.insert(groups[t], { key = nameLower, rollType = t, link = RuleLink(v) })
            total = total + 1
        end
    end
    for _, g in pairs(groups) do
        table.sort(g, function(a, b) return a.key < b.key end)
    end

    f.__empty:SetShown(total == 0)

    -- Build a flat display list of header + item rows, in type order.
    local display = {}
    local ORDER = { 1, 2, 3, 0 }  -- Need, Greed, DE, Pass
    for _, t in ipairs(ORDER) do
        local g = groups[t]
        if #g > 0 then
            f.__rulesExpanded = f.__rulesExpanded or { [1] = true, [2] = true, [3] = true, [0] = true }
            local expanded = f.__rulesExpanded[t]
            table.insert(display, { isHeader = true, rollType = t, count = #g, expanded = expanded })
            if expanded then
                for _, rule in ipairs(g) do
                    table.insert(display, { isItem = true, rule = rule })
                end
            end
        end
    end

    for i, row in ipairs(f.__rows) do
        local d = display[i]
        if d and d.isHeader then
            -- Group header: "[+/-] Type (count)", clickable to fold.
            local arrow = d.expanded and "-" or "+"
            row.__name:SetText(("%s %s (%d)"):format(arrow, ROLLTYPE_NAME[d.rollType] or "?", d.count))
            row.__name:SetTextColor(1, 0.82, 0)
            row.__name.__link = nil
            row.__typeBtn:Hide()
            row.__delBtn:Hide()
            local rt = d.rollType
            row.__nameBtn:SetScript("OnClick", function()
                f.__rulesExpanded[rt] = not f.__rulesExpanded[rt]
                RefreshRulesWindow()
            end)
            row.__nameBtn:SetScript("OnEnter", nil)
            row:Show()
        elseif d and d.isItem then
            local rule = d.rule
            local dispLink = rule.link
            if not dispLink then
                local _, link = GetItemInfo(rule.key)
                dispLink = link
            end
            row.__name:SetText("   " .. (dispLink or rule.key))
            row.__name:SetTextColor(1, 1, 1)
            row.__name.__link = dispLink
            row.__nameBtn:SetScript("OnEnter", function(self)
                if row.__name.__link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if pcall(GameTooltip.SetHyperlink, GameTooltip, row.__name.__link) then
                        GameTooltip:Show()
                    end
                end
            end)
            row.__nameBtn:SetScript("OnClick", function()
                if IsShiftKeyDown() and row.__name.__link and ChatEdit_InsertLink then
                    ChatEdit_InsertLink(row.__name.__link)
                end
            end)
            row.__typeBtn:Show()
            row.__typeBtn:SetText(ROLLTYPE_NAME[rule.rollType] or "?")
            row.__typeBtn:SetScript("OnClick", function()
                local cur = GetAutoRollRules()[rule.key]
                local nextType = RULE_TYPE_CYCLE[RuleType(cur)] or 2
                GetAutoRollRules()[rule.key] = { type = nextType, link = RuleLink(cur) }
                RefreshRulesWindow()
            end)
            row.__delBtn:Show()
            row.__delBtn:SetScript("OnClick", function()
                RemoveAutoRollRule(rule.key)
                print(MSG .. L.RULE_REMOVED:format(rule.link or rule.key))
                RefreshRulesWindow()
            end)
            row:Show()
        else
            row:Hide()
        end
    end
end

local function ToggleRulesWindow()
    local f = CreateRulesFrame()
    if f:IsShown() then
        f:Hide()
    else
        -- Anchor to the right of the options panel if it's open, so the rules
        -- window doesn't stack underneath it. Otherwise keep the centered
        -- default. The user can still drag it anywhere afterwards.
        if optionsFrame and optionsFrame:IsShown() then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", optionsFrame, "TOPRIGHT", 8, 0)
        end
        f:Show()
        RefreshRulesWindow()
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
local function CreateOptionsFrame()
    if optionsFrame then return optionsFrame end

    local f = CreateFrame("Frame", "CleanLootOptionsFrame", UIParent)
    f:SetSize(400, 340)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    EnsureBackdropSupport(f)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.94)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    title:SetText(L.OPT_TITLE)

    local dirLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dirLabel:SetPoint("TOPLEFT", 16, -40)
    dirLabel:SetText(L.OPT_STACK_DIR)
    dirLabel:SetTextColor(1, 0.82, 0)
    do
        local _ul = f:CreateTexture(nil, "ARTWORK")
        _ul:SetTexture(1, 0.82, 0, 0.35)
        _ul:SetHeight(1)
        _ul:SetPoint("TOPLEFT", dirLabel, "BOTTOMLEFT", 0, -2)
        _ul:SetWidth(165)
    end

    local optLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optLabel:SetPoint("TOPLEFT", 210, -40)
    optLabel:SetText(L.OPT_HEADER or "Options")
    optLabel:SetTextColor(1, 0.82, 0)
    do
        local _ul = f:CreateTexture(nil, "ARTWORK")
        _ul:SetTexture(1, 0.82, 0, 0.35)
        _ul:SetHeight(1)
        _ul:SetPoint("TOPLEFT", optLabel, "BOTTOMLEFT", 0, -2)
        _ul:SetWidth(175)
    end

    -- Constrain each checkbox label width so long texts (esp. French) wrap
    -- instead of overflowing into the other column. WoW word-wraps a
    -- FontString automatically once it has a fixed width.
    local function ConstrainLabel(btn, width)
        local t = _G[btn:GetName().."Text"]
        if t then
            t:SetWidth(width or 150)
            t:SetJustifyH("LEFT")
            if t.SetWordWrap then pcall(t.SetWordWrap, t, true) end
            -- Non-truncating multi-line: allow the label to grow downward.
            if t.SetMaxLines then pcall(t.SetMaxLines, t, 2) end
        end
    end

    local upBtn = CreateFrame("CheckButton", "CleanLootGrowUpButton", f, "UICheckButtonTemplate")
    upBtn:SetPoint("TOPLEFT", 14, -56)
    _G[upBtn:GetName().."Text"]:SetText(L.OPT_GROW_UP)
    ConstrainLabel(upBtn, 150)

    local downBtn = CreateFrame("CheckButton", "CleanLootGrowDownButton", f, "UICheckButtonTemplate")
    downBtn:SetPoint("TOPLEFT", 14, -76)
    _G[downBtn:GetName().."Text"]:SetText(L.OPT_GROW_DOWN)
    ConstrainLabel(downBtn, 150)

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

    local skinLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skinLabel:SetPoint("TOPLEFT", 16, -110)
    skinLabel:SetText(L.OPT_STYLE)
    skinLabel:SetTextColor(1, 0.82, 0)
    do
        local _ul = f:CreateTexture(nil, "ARTWORK")
        _ul:SetTexture(1, 0.82, 0, 0.35)
        _ul:SetHeight(1)
        _ul:SetPoint("TOPLEFT", skinLabel, "BOTTOMLEFT", 0, -2)
        _ul:SetWidth(165)
    end

    local classicBtn = CreateFrame("CheckButton", "CleanLootSkinClassicButton", f, "UICheckButtonTemplate")
    classicBtn:SetPoint("TOPLEFT", 14, -126)
    _G[classicBtn:GetName().."Text"]:SetText(L.OPT_SKIN_CLASSIC)
    ConstrainLabel(classicBtn, 150)

    local elvBtn = CreateFrame("CheckButton", "CleanLootSkinElvUIButton", f, "UICheckButtonTemplate")
    elvBtn:SetPoint("TOPLEFT", 14, -146)
    _G[elvBtn:GetName().."Text"]:SetText(L.OPT_SKIN_ELVUI)
    ConstrainLabel(elvBtn, 150)

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

    local confirmLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    confirmLabel:SetPoint("TOPLEFT", 16, -172)
    confirmLabel:SetText(L.OPT_CONFIRM)
    confirmLabel:SetTextColor(1, 0.82, 0)
    do
        local _ul = f:CreateTexture(nil, "ARTWORK")
        _ul:SetTexture(1, 0.82, 0, 0.35)
        _ul:SetHeight(1)
        _ul:SetPoint("TOPLEFT", confirmLabel, "BOTTOMLEFT", 0, -2)
        _ul:SetWidth(165)
    end

    local noConfirmBtn = CreateFrame("CheckButton", "CleanLootNoConfirmButton", f, "UICheckButtonTemplate")
    noConfirmBtn:SetPoint("TOPLEFT", 14, -188)
    _G[noConfirmBtn:GetName().."Text"]:SetText(L.OPT_NO_CONFIRM)
    ConstrainLabel(noConfirmBtn, 150)

    noConfirmBtn:SetScript("OnClick", function()
        local checked = noConfirmBtn:GetChecked() and true or false
        CleanLootDB.noConfirm = checked
        SetupAutoConfirm()
    end)

    local simpleDeleteBtn = CreateFrame("CheckButton", "CleanLootSimpleDeleteButton", f, "UICheckButtonTemplate")
    simpleDeleteBtn:SetPoint("TOPLEFT", 14, -208)
    _G[simpleDeleteBtn:GetName().."Text"]:SetText(L.OPT_SIMPLE_DEL)
    ConstrainLabel(simpleDeleteBtn, 150)

    simpleDeleteBtn:SetScript("OnClick", function()
        local checked = simpleDeleteBtn:GetChecked() and true or false
        CleanLootDB.simpleDeleteConfirm = checked
        ApplyDeleteConfirmOverride()
    end)

    local winRecapBtn = CreateFrame("CheckButton", "CleanLootWinRecapButton", f, "UICheckButtonTemplate")
    winRecapBtn:SetPoint("TOPLEFT", 208, -56)
    _G[winRecapBtn:GetName().."Text"]:SetText(L.OPT_AUTO_OPEN)
    ConstrainLabel(winRecapBtn, 168)

    winRecapBtn:SetScript("OnClick", function()
        local checked = winRecapBtn:GetChecked() and true or false
        CleanLootDB.autoOpenRecap = checked
    end)

    local hideSpamBtn = CreateFrame("CheckButton", "CleanLootHideSpamButton", f, "UICheckButtonTemplate")
    hideSpamBtn:SetPoint("TOPLEFT", 208, -78)
    _G[hideSpamBtn:GetName().."Text"]:SetText(L.OPT_HIDE_SPAM)
    ConstrainLabel(hideSpamBtn, 168)
    hideSpamBtn:SetScript("OnClick", function()
        CleanLootDB.hideRollSpam = hideSpamBtn:GetChecked() and true or false
    end)

    -- Auto-roll on green items: two mutually exclusive checkboxes.
    local autoGreedBtn = CreateFrame("CheckButton", "CleanLootAutoGreedButton", f, "UICheckButtonTemplate")
    autoGreedBtn:SetPoint("TOPLEFT", 208, -100)
    _G[autoGreedBtn:GetName().."Text"]:SetText(L.OPT_AUTO_GREED)
    ConstrainLabel(autoGreedBtn, 168)

    local autoDEBtn = CreateFrame("CheckButton", "CleanLootAutoDEButton", f, "UICheckButtonTemplate")
    autoDEBtn:SetPoint("TOPLEFT", 208, -122)
    _G[autoDEBtn:GetName().."Text"]:SetText(L.OPT_AUTO_DE)
    ConstrainLabel(autoDEBtn, 168)

    local winnerPopupBtn = CreateFrame("CheckButton", "CleanLootWinnerPopupButton", f, "UICheckButtonTemplate")
    winnerPopupBtn:SetPoint("TOPLEFT", 208, -144)
    _G[winnerPopupBtn:GetName().."Text"]:SetText(L.OPT_WINNER_POPUP)
    ConstrainLabel(winnerPopupBtn, 168)
    winnerPopupBtn:SetScript("OnClick", function(self)
        CleanLootDB.winnerPopup = self:GetChecked() and true or false
    end)
    f.winnerPopupBtn = winnerPopupBtn

    autoGreedBtn:SetScript("OnClick", function(self)
        if self:GetChecked() then
            CleanLootDB.autoGreen = "greed"
            autoDEBtn:SetChecked(false)
        else
            CleanLootDB.autoGreen = "off"
        end
    end)
    autoDEBtn:SetScript("OnClick", function(self)
        if self:GetChecked() then
            CleanLootDB.autoGreen = "de"
            autoGreedBtn:SetChecked(false)
        else
            CleanLootDB.autoGreen = "off"
        end
    end)

    local histBtn = CreateFrame("Button", "CleanLootHistoryButton", f, "UIPanelButtonTemplate")
    histBtn:SetSize(120, 22)
    histBtn:SetPoint("TOPLEFT", 16, -244)
    histBtn:SetText(L.HIST_BTN)
    histBtn:SetScript("OnClick", function() ToggleHistory() end)
    SkinElvButton(histBtn)

    local rulesBtn = CreateFrame("Button", "CleanLootRulesButton", f, "UIPanelButtonTemplate")
    rulesBtn:SetSize(150, 22)
    rulesBtn:SetPoint("LEFT", histBtn, "RIGHT", 8, 0)
    rulesBtn:SetText(L.RULES_BTN)
    rulesBtn:SetScript("OnClick", function() ToggleRulesWindow() end)
    SkinElvButton(rulesBtn)

    -- Frame scale (0.8 to 1.5, 0.05 steps) — on its own line below the buttons.
    local scaleSlider = CreateFrame("Slider", "CleanLootScaleSlider", f, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 100, -294)
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
    SkinElvCloseButton(closeBtn)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
        if testModeActive then
            HideTestFrame()
            HideWinsTest()
            print(MSG .. L.MSG_TEST_STOP)
        end
    end)

    f.hideSpamBtn = hideSpamBtn
    f.autoGreedBtn = autoGreedBtn
    f.autoDEBtn = autoDEBtn
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
    f.winRecapBtn:SetChecked(CleanLootDB.autoOpenRecap and true or false)
    f.winnerPopupBtn:SetChecked(CleanLootDB.winnerPopup and true or false)
    f.hideSpamBtn:SetChecked(CleanLootDB.hideRollSpam and true or false)
    f.autoGreedBtn:SetChecked(CleanLootDB.autoGreen == "greed")
    f.autoDEBtn:SetChecked(CleanLootDB.autoGreen == "de")

    f.scaleSlider.__init = false
    f.scaleSlider:SetValue(CleanLootDB.frameScale or 1)
    f.scaleSlider.__init = true

    f:Show()
end

-- Full test-mode start/stop, shared by the /cll test|stop commands and the
-- minimap button so they behave identically (roll frame + options + recap).
local function StartTestMode()
    local ok1, err1 = pcall(ShowTestFrame)
    if not ok1 then PrintError("ShowTestFrame", err1) end
    local ok2, err2 = pcall(ShowOptions)
    if not ok2 then PrintError("ShowOptions", err2) end
    local ok3, err3 = pcall(ShowWinsTest)
    if not ok3 then PrintError("ShowWinsTest", err3) end
    -- Force the winner popup with a demo line so it can be positioned even
    -- though the log window is open during test mode.
    if NotifyWinnerPopup then
        local me = UnitName("player") or "You"
        NotifyWinnerPopup("["..(L.TEST_ITEM or "Test item").."]", me, 92, nil, true)
    end
    print(MSG .. L.MSG_TEST_OPEN)
end

local function StopTestMode()
    HideTestFrame()
    HideWinsTest()
    if optionsFrame then optionsFrame:Hide() end
    -- Clear the forced test popup.
    if winnerPopup then
        wipe(winnerLines)
        winnerPopup:Hide()
    end
    print(MSG .. L.MSG_TEST_STOP)
end

local function ToggleTestMode()
    if testModeActive then
        StopTestMode()
    else
        StartTestMode()
    end
end

-------------------------------------------------
-- Interface > AddOns panel (info/guide page)
-------------------------------------------------
local function CreateAboutPanel()
    local panel = CreateFrame("Frame", "CleanLootAboutPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "CleanLoot"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.ABOUT_TITLE)

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetWidth(560)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(L.ABOUT_SUBTITLE)

    -- Quick guide: key features and how to configure them, point by point.
    local guideHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    guideHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    guideHeader:SetText(L.ABOUT_GUIDE)

    local anchor = guideHeader
    for _, key in ipairs({
        "ABOUT_G_LOG", "ABOUT_G_POPUP", "ABOUT_G_AUTOOPEN",
        "ABOUT_G_AUTORULE", "ABOUT_G_AUTOGREED", "ABOUT_G_COUNTERS",
    }) do
        local bullet = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        bullet:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (anchor == guideHeader) and 0 or 0, -8)
        bullet:SetWidth(560)
        bullet:SetJustifyH("LEFT")
        bullet:SetSpacing(2)
        bullet:SetText("- " .. (L[key] or ""))
        anchor = bullet
    end

    -- Commands (compact).
    local cmdHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cmdHeader:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    cmdHeader:SetText(L.ABOUT_COMMANDS)

    local cmdText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cmdText:SetPoint("TOPLEFT", cmdHeader, "BOTTOMLEFT", 0, -6)
    cmdText:SetWidth(560)
    cmdText:SetJustifyH("LEFT")
    cmdText:SetSpacing(3)
    cmdText:SetText(table.concat({
        L.HELP_TEST, L.HELP_OPTIONS, L.HELP_HISTORY, L.HELP_RULES,
    }, "\n"))

    -- Buttons (ElvUI-skinned).
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(150, 24)
    testBtn:SetPoint("TOPLEFT", cmdText, "BOTTOMLEFT", 0, -18)
    testBtn:SetText(L.ABOUT_OPEN_TEST)
    testBtn:SetScript("OnClick", function()
        if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
        ShowTestFrame()
    end)
    SkinElvButton(testBtn)

    local optsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    optsBtn:SetSize(150, 24)
    optsBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
    optsBtn:SetText(L.ABOUT_OPEN_OPTS)
    optsBtn:SetScript("OnClick", function()
        if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
        ShowOptions()
    end)
    SkinElvButton(optsBtn)

    local histBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    histBtn:SetSize(150, 24)
    histBtn:SetPoint("TOPLEFT", testBtn, "BOTTOMLEFT", 0, -8)
    histBtn:SetText(L.ABOUT_OPEN_HIST)
    histBtn:SetScript("OnClick", function()
        if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
        ToggleHistory()
    end)
    SkinElvButton(histBtn)

    local rulesBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    rulesBtn:SetSize(150, 24)
    rulesBtn:SetPoint("LEFT", histBtn, "RIGHT", 8, 0)
    rulesBtn:SetText(L.ABOUT_OPEN_RULES)
    rulesBtn:SetScript("OnClick", function()
        if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
        ToggleRulesWindow()
    end)
    SkinElvButton(rulesBtn)

    -- Minimap button visibility toggle (lives only here, in the Interface panel).
    local hideMMBtn = CreateFrame("CheckButton", "CleanLootHideMinimapButton", panel, "InterfaceOptionsCheckButtonTemplate")
    hideMMBtn:SetPoint("TOPLEFT", histBtn, "BOTTOMLEFT", 0, -16)
    _G[hideMMBtn:GetName().."Text"]:SetText(L.ABOUT_HIDE_MM)
    hideMMBtn:SetScript("OnClick", function(self)
        local hidden = self:GetChecked() and true or false
        CleanLootDB.minimap = CleanLootDB.minimap or {}
        CleanLootDB.minimap.hide = hidden
        local LibStub = _G.LibStub
        local icon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
        if icon then
            if hidden then icon:Hide("CleanLoot") else icon:Show("CleanLoot") end
        end
    end)
    panel:SetScript("OnShow", function()
        hideMMBtn:SetChecked(CleanLootDB.minimap and CleanLootDB.minimap.hide)
    end)

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    return panel
end

-------------------------------------------------
-- Minimap button (LibDBIcon + LibDataBroker)
-- Left-click: roll history. Right-click: test mode. Draggable around the
-- minimap (position saved), and grabbable by minimap-button collectors
-- since it follows the standard LibDBIcon convention.
-------------------------------------------------
local function SetupMinimapButton()
    local LibStub = _G.LibStub
    if not LibStub then return end
    local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
    local icon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    if not ldb or not icon then return end

    CleanLootDB.minimap = CleanLootDB.minimap or { hide = false }

    local dataObject = ldb:NewDataObject("CleanLoot", {
        type = "launcher",
        icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
        OnClick = function(_, button)
            if button == "LeftButton" then
                ToggleHistory()
            elseif button == "RightButton" then
                ToggleTestMode()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("CleanLoot")
            tt:AddLine(L.MINIMAP_TT_LEFT, 1, 1, 1)
            tt:AddLine(L.MINIMAP_TT_RIGHT, 1, 1, 1)
        end,
    })

    if dataObject and not icon:IsRegistered("CleanLoot") then
        icon:Register("CleanLoot", dataObject, CleanLootDB.minimap)
    end
end

-------------------------------------------------
-- Slash commands
-------------------------------------------------
local function HandleCommand(msg)
    msg = strtrim(msg or ""):lower()

    if msg == "test" then
        StartTestMode()
    elseif msg == "stop" then
        StopTestMode()
    elseif msg == "reset" then
        CleanLootDB.point = nil
        CleanLootDB.logPoint = nil
        if logFrame then
            logFrame:ClearAllPoints()
            logFrame:SetPoint("CENTER", UIParent, "CENTER", 320, 60)
        end
        print(MSG .. L.MSG_RESET)
    elseif msg == "history" then
        ToggleHistory()
    elseif msg == "arr" or msg == "rules" then
        ToggleRulesWindow()
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
        print(L.HELP_RULES)
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

    -- Interface > AddOns guide page (created once).
    local okAbout, errAbout = pcall(CreateAboutPanel)
    if not okAbout then PrintError("CreateAboutPanel", errAbout) end

    -- Minimap button (created once).
    local okMM, errMM = pcall(SetupMinimapButton)
    if not okMM then PrintError("SetupMinimapButton", errMM) end
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
        if CleanLootDB.noConfirm == nil then CleanLootDB.noConfirm = true end
        if CleanLootDB.simpleDeleteConfirm == nil then CleanLootDB.simpleDeleteConfirm = true end
        if CleanLootDB.debugMode == nil then CleanLootDB.debugMode = false end
        if CleanLootDB.hideRollSpam == nil then CleanLootDB.hideRollSpam = true end
        if CleanLootDB.autoGreen == nil then CleanLootDB.autoGreen = "off" end
        if CleanLootDB.autoOpenRecap == nil then CleanLootDB.autoOpenRecap = false end
        if CleanLootDB.winnerPopup == nil then CleanLootDB.winnerPopup = true end
        if CleanLootDB.autoRollRules == nil then CleanLootDB.autoRollRules = {} end
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
