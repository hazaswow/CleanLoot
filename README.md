# CleanLoot

A lightweight, standalone reskin of the group loot roll frames (Need/Greed/Disenchant/Pass) for **WoW 3.3.5**, built and tested on **Ascension (Conquest of Azeroth)**. **No ElvUI required.**

## Features

- Renders its **own** loot roll frames on top of the hidden native ones — no native glitches (gold backdrop, double bars, stuck buttons)
- Two visual styles: **Improved Classic** (clean dark look) or **ElvUI-inspired compact**
- **Movable** and **scalable** frames (scale slider in options)
- Stack direction of your choice (upward or downward); items collapse neatly when a roll resolves
- Border and item name **colored by item quality**; roll timer fades **yellow → red**
- **Need/Greed/Disenchant buttons gray out** when unavailable (Disenchant is group-aware), independently of each other
- **Icon interaction**: hover for tooltip, Shift-hover to compare, **Ctrl+left-click** to preview the appearance, **Shift+left-click** to link in chat
- Hover the roll buttons to see **who rolled what** in your group
- **Roll winners recap** window with roll type icon and winning value
- **Session roll history** (`/cll history`): items, winners, type and value, with per-item expandable rolls
- Optional **confirmation popup skipping** (BoP rolls, BoP loot)
- Optional **simple Delete confirmation** (Yes/No instead of typing "DELETE")
- Optional **hide roll messages** from the chat window
- Automatic **EN/FR localization** based on the client language

## Installation

1. Download the latest release zip (or `Code → Download ZIP`).
2. Extract it into `Interface/AddOns/`.
3. Make sure the folder is named exactly `CleanLoot` (rename it if it ends with `-main`).
4. Restart the game.

## Commands

| Command | Effect |
|---|---|
| `/cll test` | Show dummy frames to preview the skin and reposition everything (drag with left click) + open options |
| `/cll stop` | Close test mode and save positions |
| `/cll options` | Open the options panel only |
| `/cll history` | Open the session roll history window |
| `/cll reset` | Reset positions to default |
| `/cll debugmode` | Toggle diagnostic messages (turn on before reporting a bug, then share a chat screenshot) |
| `/cll debug` | Diagnose the loot frames on this client |
| `/cll scan` | List all regions of GroupLootFrame1 (advanced debugging) |

## Notes

- The winners recap and the roll tooltips rely on the game's detailed loot messages. If the *Detailed Loot Information* interface option is disabled, the addon enables it automatically (and says so in chat) while the recap is active.
- Diagnostic output is always in English regardless of the client language, so bug reports stay readable.

## Reporting bugs

Run `/cll debugmode`, reproduce the issue, and share a screenshot of your chat along with your client language and the skin you use.

## Author

**Hazas**
