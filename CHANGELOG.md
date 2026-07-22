# Changelog

## 3.3.0
Major update. The addon no longer reskins Blizzard's loot roll frames — it now renders its own, which eliminates a whole class of native-frame glitches.

**New architecture**
- Replacement frames: the native GroupLootFrames are hidden and the addon draws its own frames on top (fed by the game's roll info, rolling through the standard API). This removes the native gold backdrop bleeding through, double timer bars, recreated button textures, and desynced button hitboxes for good.

**New features**
- Roll winners recap: a small movable window lists who won each item, with the roll type icon (Need/Greed/Disenchant) and the winning roll value.
- Session roll history (`/cll history` or the History button): every item rolled this session, with the winner, type and value, and each item's rolls expandable per line (click to unfold). Session-only, capped at 100 entries.
- Correct winning-tier logic: any Need beats Greed/Disenchant; Greed and Disenchant share a tier (highest roll wins); otherwise everyone passed.
- Need / Greed / Disenchant buttons now gray out when unavailable, read from the client's real per-button state (so Disenchant correctly greys when nobody in the group can disenchant, independently of the other buttons).
- Item interaction on the roll frame icon: hover for the tooltip, Shift-hover to compare, Ctrl+left-click to preview the appearance (dressing room), Shift+left-click to link in chat.
- Option to hide roll messages from the chat window (the recap and tooltips still receive the data).
- Icon zoom to crop the ugly rounded border, thin quality-colored borders, deeper purple for epics, unified font across all windows.

**Fixes**
- Both skins no longer break when an ElvUI fork is loaded (native SetBackdrop is tried before any backported mixin).
- Recap/history capture reworked to be keyed by item name, robust to this server's unreliable roll IDs.
- Numerous compact-skin cleanups (no stray boxes, single timer bar, transparent buttons with a thin delimiter border).

## 2.3.3
- All frame-touching setup (hooks, skinning, backdrop probing) is deferred from ADDON_LOADED to PLAYER_ENTERING_WORLD. At /reload time, ADDON_LOADED fires while the client is still rebuilding its UI; touching Blizzard frames that early is a plausible trigger for hard client crashes (Error #132) on fragile custom clients. ADDON_LOADED now runs pure Lua only.

## 2.3.2
- Hardened against a client crash on /reload reported with font addons: every SetFont call now guards against GetFont() returning nil (SetFont(nil, ...) is a known 3.3.5 client crash).
- Frame scale is clamped to a sane range (guards against SetScale(0) from a corrupted saved value).

## 2.3.1
- Fixed: re-enabling "Show roll winners recap" while `/cll test` is open now brings the recap preview back immediately.

## 2.3
- The addon now auto-enables the *Detailed Loot Information* interface option (with a chat notice) when the winners recap is active — required for the recap and the roll tooltips to receive any data.

## 2.2.2
- Fixed: on fresh installs with no saved position, the first loot frame lost its native anchor (invisible frame content, floating buttons).

## 2.2.1
- Fixed: the Pass button's cross reappearing in the compact skin (native code recreates its textures on every roll; masking is now reapplied and new textures captured each time).
- Classic skin no longer touches native button geometry at all (fixes the Pass button becoming unclickable on some clients).

## 2.2
- Added a frame scale slider (0.8–1.5) applying to the loot frames, the mover and the recap.

## 2.1
- Added the roll winners recap window (optional, movable, item tooltip on hover, test-mode preview).
- Full button texture sweep with original-alpha restoration (covers non-standard textures).

## 2.0
- Major rewrite: self-healing skinning (transient failures retry on the next roll instead of requiring a reconnect), backdrop support detection with a manual-texture fallback, EN/FR localization, roll message parsing generated from Blizzard global strings (works in any client language), debug mode, publish-ready cleanup.

## 1.x
- Initial versions: classic/ElvUI skins, mover and test mode, stack direction, quality coloring, yellow→red timer, who-rolled-what tooltips, auto-confirm options, simple Delete confirmation.
