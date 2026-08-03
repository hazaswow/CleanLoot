# CLAUDE.md — CleanLoot project guide

This file gives Claude Code the full context of the CleanLoot project. Read it
at the start of every session.

## What CleanLoot is

A World of Warcraft addon for **WotLK 3.3.5**, specifically the **Conquest of
Azeroth (CoA)** private server (Ascension-based, 32-bit client, enUS locale).
It replaces the native group-loot roll frames with its own clean, skinnable
frames and adds loot-management features for group play.

- **Author**: Hazas (GitHub: `hazaswow`, in-game: Hazasfel on Vol'jin realm)
- **Language**: the author works in French; the addon is bilingual (enUS + frFR)
- **UI context**: the author runs a minimal ElvUI + a heavy addon pack
- **Current version**: 4.0.0 (see `CleanLoot.toc`)

## Golden rules when working on this project

1. **Ask clarifying questions before coding** when there is genuine doubt.
   The author strongly prefers this — it avoids wasted iterations. Do not guess
   on ambiguous design decisions; surface options and let him choose.
2. **Validate every change with the Lua runtime before packaging** (see below).
3. **Respect semver strictly** (see below). The author will correct wrong bumps.
4. **Prefer single, comprehensive passes** over many small speculative edits.
5. He validates features **in-game** before layering new ones. Don't stack many
   untested changes at once.

## Semver convention (strict — author enforces this)

`X.Y.Z`:
- **X** (major): breaking change / architecture refactor. *Note: 4.0.0 was a
  deliberate cumulative milestone, NOT a technical break — SavedVariables stayed
  compatible. Don't treat it as license to break things.*
- **Y** (minor): notable new feature.
- **Z** (patch): small tweak or bugfix.

Multiple Z-level changes can be bundled into one release.

## Environment & validation

- **Runtime**: `lua5.4` (install with `apt-get install -y lua5.4` if missing).
- **Syntax check** (run after every edit):
  ```
  lua5.4 -e "local f,err = loadfile('CleanLoot/CleanLoot.lua'); print(f and 'OK' or err)"
  ```
- **Load test**: there is a WoW API stub harness. If it doesn't exist in the
  environment, recreate it — it stubs `CreateFrame`, `GetLootRollItemInfo`,
  party/raid API, `LibStub`, `FauxScrollFrame`, `GetItemInfo`, `RollOnLoot`,
  the `LOOT_ROLL_*` global strings, etc., then `loadfile`s the addon and prints
  `LOADED OK`. In Claude Code you can keep it at `tools/wowenv.lua` in the repo
  instead of `/tmp` so it persists.
- **Unit tests**: for any non-trivial logic (sorting, decision rules, grouping,
  backward-compat), write a small standalone Lua test that mirrors the logic and
  asserts on it. This has caught real bugs. Don't skip it.

## Packaging

The install zip must contain the **whole `CleanLoot/` folder including `Libs/`**.
The user replaces the entire folder in `Interface/AddOns/`.

In Claude Code (local git repo) packaging is simpler than the old chat workflow:
```
cd <repo root>
zip -r CleanLoot.zip CleanLoot -x "*.DS_Store"
```
Attach that zip to the GitHub release. (The old chat-only "zip to /tmp then copy"
workaround is no longer needed on a normal filesystem.)

## Architecture (important — read before touching frames)

**Replacement-frame model.** The native `GroupLootFrame1-4` are NEUTRALIZED
(`SetAlpha(0)`, `EnableMouse(false)`, moved off-screen — NOT `Hide()`, so the
native buttons still compute their state, which we read). Our own pool
`CleanLootFrame1-4` renders everything, fed from `GetLootRollItemInfo`, and rolls
via `RollOnLoot(rollID, type)` where **Need=1, Greed=2, Disenchant=3, Pass=0**.

**CoA quirks that shaped the design:**
- The `rollID` is UNRELIABLE for linking a chat message to a frame. So roll data
  is captured **indexed by item name** (stripped of brackets via
  `:match("%[(.-)%]")`), not by rollID.
- The `canNeed/canGreed/canDisenchant` flags from `GetLootRollItemInfo` are also
  UNRELIABLE (classless server; DE depends on the whole group's enchant skill).
  For button graying we read the REAL native button state instead.
- **Lua gotcha that bit us repeatedly**: native flags return `1/0` (numbers), and
  in Lua `0` is TRUTHY, so `not 0 == false`. Always normalize:
  `local can = (raw == true) or (raw == 1)`.

**Combined roll log** (`rollLog` + `rollLogByName`): one ordered list of items,
each holding every group member as a row (waiting → type + value). Unresolved =
expanded, resolved = collapsed, sorted Need > Greed/DE > Pass then value desc.
Key split to avoid duplicate-item pollution:
- `StartNewLogEntry` (at START_LOOT_ROLL): always a FRESH entry, even if the same
  item name already exists (so repeated drops each get their own vote list).
- `GetActiveLogEntry` (chat updates): only touches the non-resolved entry.

**Forward-reference discipline**: helper blocks must be defined BEFORE frames
whose closures capture them. A right-click auto-roll crash was caused by
`SetAutoRollRule` being defined after `CreateRollFrame`. If you add a helper used
by a button OnClick, define it above `CreateRollFrame`.

## Feature set (all implemented as of 4.0.0)

- Own loot roll frames, `classic` and `elvui` skins (`EnsureBackdropSupport`
  tests native `SetBackdrop` first — ElvUI forks break if a mixin is blindly
  applied).
- Need/Greed/DE grayed when unavailable (read from native button state), with
  **live vote counters** on each button (throttled OnUpdate) + mouseover tooltip
  showing who voted (works even when the button is grayed).
- **Combined roll log window** (replaces the old separate recap + history).
- **Ephemeral winner popup** (12s), only when the log window is closed, click to
  open the log. Same width as the log window.
- **Per-item auto-roll rules**: right-click a roll button to create one (+ rolls
  immediately + chat confirmation); rules window with add-by-name/ID, type change,
  delete, and **grouping by type** (foldable Need/Greed/DE/Pass sections,
  non-empty only). Rules store `{type, link}` with backward-compat for the legacy
  plain-number format. Per-item rule takes PRIORITY over global auto-greed.
- **Masking**: when an auto-roll rule or auto-greed applies (and is available),
  the frame never shows at all — it rolls silently.
- Auto-greed / auto-DE on green (quality 2) items only.
- Minimap button (LibDBIcon + LibDataBroker), hideable in the Interface page.
- Options panel: two columns, gold section titles, ElvUI-skinned buttons
  (`SkinElvButton` / `SkinElvCloseButton`, defined high in the file for global
  scope). Interface (About) page is a structured "quick guide" with per-feature
  config hints — note the `ABOUT_G_*` locale keys are referenced DYNAMICALLY via
  `L[key]` in a loop, so they look unused to a naive grep. Don't delete them.

## Slash commands

`/cll` or `/cleanloot`: `test`, `stop`, `reset`, `options`/`menu`, `history`,
`arr`/`rules` (auto-roll rules window), `debugmode`, `debug`, `scan`.

## Locale gotchas (don't "clean" these away)

- `ABOUT_G_*` keys: used via `L[key]` in the About guide loop.
- `CONFIRM_DISENCHANT_ROLL` / `CONFIRM_LOOT_ROLL`: referenced by string (Blizzard
  StaticPopup names), 3 dynamic uses each.
- `WIN_PATTERNS` / `ROLL_CHOICE_PATTERNS`: these are code variables, not locale
  keys. `WIN_PATTERNS` was once accidentally deleted with old code and crashed on
  every loot message (`ipairs(nil)`) — it's rebuilt from `LOOT_ROLL_WON` /
  `LOOT_ROLL_YOU_WON` globals with an English fallback.

## Files

- `CleanLoot/CleanLoot.lua` — the addon (~3186 lines, single file).
- `CleanLoot/CleanLoot.toc` — metadata; `## Version:` is the source of truth.
- `CleanLoot/Libs/` — 4 embedded libs (LibStub, CallbackHandler-1.0,
  LibDataBroker-1.1, LibDBIcon-1.0), declared in the .toc BEFORE CleanLoot.lua.
- Related published addons by the same author (separate repos): CleanVendor,
  CleanMap.

## Current state / next tasks

- **4.0.0 is ready** and dead-code-cleaned (~478 lines of old recap/history/reskin
  code removed vs the pre-cleanup 3664-line version). No dead functions/vars, no
  orphan references, all referenced locale keys defined.
- **GitHub repo is stale at 3.3.0.** The next task is a proper 4.0.0 release:
  - Update `## Notes` / `## Notes-frFR` in the .toc (they still mention the old
    "roll winners recap, session roll history" which are now the combined log).
  - Write `README.md` (English) covering features, commands, configuration.
  - Write `CHANGELOG.md` covering 3.3.0 → 4.0.0 (cumulative; state clearly that
    4.0.0 is a cumulative milestone, not a technical break).
  - Tag `v4.0.0`, attach `CleanLoot.zip` (named exactly so
    `releases/latest/download/CleanLoot.zip` resolves).

## Possible future ideas (mentioned, not requested)

Win sound on winning a roll; dynamic corner-resize of the roll log window; rule
export/import. Don't build these unless asked.
