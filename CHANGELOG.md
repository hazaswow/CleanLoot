# Changelog

## 1.0.0
First release, for **WoW Forever**.

- Own loot roll frames (Need / Greed / Pass) in place of Blizzard's, with item tooltip, Ctrl+click preview, Shift+click link, quality colours and a timer.
- Live vote counters on each button, with the list of players on hover (class coloured, with the roll once revealed), also on greyed-out buttons.
- A "hasn't rolled yet" clock with the players still deciding.
- Big drops: rolls beyond the 8 frames wait in a queue (with a "+N more" label) instead of being lost; rolls still running come back after a `/reload`; item data not loaded yet is retried; an expired frame closes itself.
- Blizzard's own roll frames are hidden and stop catching clicks (alpha and mouse state only, the managed container is never moved).
- Chat filter for the per-roll lines; who won what and loot receipts stay visible.
- Minimap button (loot history / options) and an options panel under Options > AddOns. Default scale 1.10.
- `/cll sim` drop simulator and `/cll debug` roll tracing.
