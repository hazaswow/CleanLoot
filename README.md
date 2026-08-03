# CleanLoot

A lightweight, standalone reskin of the group loot roll frames (Need/Greed/Disenchant/Pass) for **WoW 3.3.5**, built and tested on **Ascension (Conquest of Azeroth)**. **No ElvUI required.**

## Features

- Renders its **own** loot roll frames on top of the hidden native ones — no native glitches (gold backdrop, double bars, stuck buttons)
- Two visual styles: **Improved Classic** (clean dark look) or **ElvUI-inspired compact**
- **Movable** and **scalable** frames (scale slider in options)
- Stack direction of your choice (upward or downward); items collapse neatly when a roll resolves
- Border and item name **colored by item quality**; roll timer fades **yellow → red**
- **Need/Greed/Disenchant buttons gray out** when unavailable (Disenchant is group-aware), independently of each other
- **Live vote counters** on each button, with a mouseover tooltip showing who voted — works even while the button is grayed out
- **Icon interaction**: hover for tooltip, Shift-hover to compare, **Ctrl+left-click** to preview the appearance, **Shift+left-click** to link in chat
- **Combined roll log** (`/cll history`): one window listing every item, with each group member's vote; unresolved items stay expanded, resolved ones collapse and sort Need > Greed/DE > Pass, then value
- **Ephemeral winner popup** (12s) when an item resolves and the log window is closed — click it to open the log
- **Per-item auto-roll rules**: right-click a roll button to always roll that way for that item; manage rules from `/cll arr` (add by name/ID, change type, delete, grouped by type)
- **Masking**: when an auto-roll rule or auto-greed applies, the roll frame never appears — it rolls silently
- **Auto-greed / auto-DE** on green (uncommon) items only
- **Minimap button** (left-click: roll log, right-click: test mode), hideable from the options
- Optional **confirmation popup skipping** (BoP rolls, BoP loot)
- Optional **simple Delete confirmation** (Yes/No instead of typing "DELETE")
- Optional **hide roll messages** from the chat window
- Automatic **EN/FR localization** based on the client language

## Installation

1. Download the latest release zip (or `Code → Download ZIP`).
2. Extract it into `Interface/AddOns/`.
3. Make sure the folder is named exactly `CleanLoot` (rename it if it ends with `-main`), and that it contains the `Libs/` subfolder.
4. Restart the game.

## Commands

| Command | Effect |
|---|---|
| `/cll test` | Show dummy frames to preview the skin and reposition everything (drag with left click) + open options |
| `/cll stop` | Close test mode and save positions |
| `/cll options` / `/cll menu` | Open the options panel only |
| `/cll history` | Open the combined roll log window |
| `/cll arr` / `/cll rules` | Open the auto-roll rules window |
| `/cll reset` | Reset positions to default |
| `/cll debugmode` | Toggle diagnostic messages (turn on before reporting a bug, then share a chat screenshot) |
| `/cll debug` | Diagnose the loot frames on this client |
| `/cll scan` | List all regions of GroupLootFrame1 (advanced debugging) |

## Notes

- Diagnostic output is always in English regardless of the client language, so bug reports stay readable.
- The `Libs/` folder (LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0) is required for the minimap button and must be kept alongside `CleanLoot.lua`.

## Reporting bugs

Run `/cll debugmode`, reproduce the issue, and share a screenshot of your chat along with your client language and the skin you use.

## Author

**Hazas**
