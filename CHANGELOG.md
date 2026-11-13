# Changelog

## 1.4.1

**Fixed**
- The "Waiting on rolls" card no longer stays up for ever when you leave the zone (a teleport, say) before answering a roll. It goes after the loading screen, and in any case once a roll is too old to still be running.

## 1.4.0

**Auto-roll** (new; nothing is automatic until you make a rule)
- Always Need, Greed or Pass on an item: right-click the button on its roll frame (it turns green; right-click it again to forget the rule), or add it on the new *Auto-roll* page of the options, or with `/cll auto need|greed|pass [item]`.
- Optionally one answer for every green, blue, epic or legendary item. An item rule wins over them.
- It only answers when the answer is possible: a greyed-out button, or a bind-on-pickup Need/Greed while the game's confirmation is yours, leaves the roll to you. With *Auto-accept bind-on-pickup prompts* ticked, those go out too. Pass always goes out. A chat line says what was answered, or why not.
- Rolls it answers show no frame; the winner popup still reports the result.

**Options**
- The link box of the author's corner closes by itself once you copy the link with Ctrl+C.

## 1.3.1

**Options**
- A discreet corner at the bottom of the main options page: I stream WoW on Twitch, and there is a Ko-fi if you want to help me pay my Claude subscription. Each button shows its address in a box to copy. Nothing else in the game changed.

## 1.3.0

**Controller mode** (new, off by default; contributed by chuwix)
- Play the loot rolls with a gamepad or the keyboard: select a roll, then answer Need, Greed or Pass with keys or controller buttons, or with `/cll` commands.
- Everything about it is on its own page of the options, *CleanLoot → Controller mode* (or `/cll controller`), and every option of the mode is off by default.
- Set the keys and controller buttons right there (click a field, press a key or a button, right-click clears), or in Key Bindings under *CleanLoot*.
- Optional item inspection tooltip: it shows while the mouse is over a roll or, for a gamepad, stays on the selected roll. Pawn upgrade info is an option too.

**Bind-on-pickup rolls**
- The roll frame now stays until the game closes the roll, so refusing the game's confirmation prompt no longer loses the buttons (mouse and keys alike).
- New option *Auto-accept bind-on-pickup prompts* (off by default) accepts the prompt for you.

**Winner popup**
- New *Waiting on rolls* card: a small card at the start of the popup while a roll is still open. Hover it for the items still being rolled for, how many players have not rolled on each, and who (you included while you have not answered). On by default; one checkbox turns it off.

## 1.2.1
- The winner popup has its own stacking direction (downwards or upwards) in the options, independent of the roll frames. Until you pick one it follows the roll frames, as before.

## 1.2.0
- **Winner popup**: when a roll ends, a small card says who won the item and with which roll, shown as the game's own dice (Need) or coin (Greed) and the number. Your own roll is always on it (or *You passed* / *You did not roll*). Hover a card for every roll of that drop, Need before Greed; right-click closes it. It fades after ten seconds. The roll lines stay out of the chat: the numbers are here now. On by default; turn it off in the options (*Winner popup*).
- The popup has its own spot, left of the roll frames, and its own **Move** and **Reset** buttons in the options (a sample card to drag, whatever the lock says). `/cll sim` shows a result card too.
- *Loot toasts*: a new option hides Blizzard's "You won" toast **only for the items the winner popup reports**; other loot toasts stay. An item is covered from the start of its roll.
- A roll is followed from `START_LOOT_ROLL` until the game names a winner, from several signals (the roll's start, history updates, the "complete" event), so a result is not missed when one of them is unreadable. Up to eight cards at once, as many as roll frames. `/cll debug` traces each step.

## 1.1.0
- Loot toast options: hide the "You won" banner, change its size, or move the alert banners (*Loot toasts* column in the options). The move box has the size and place of a real toast. Off by default: nothing changes until you use them.
- A simpler `/cll`: it now opens the options panel, where every setting lives. The commands that duplicated an option are gone (`grow`, `scale`, `lock`, `unlock`, `native`), and so is `sim chat`. `/cll sim`, `/cll restore` and `/cll debug` stay; `/cll help` lists them.

## 1.0.1
- The roll frames are now **locked** by default, so a real roll never moves by accident. Unlock them with the new option; they are always movable while `/cll sim` rolls are on screen.
- New two-frame icon, used in the addon list and on the minimap button.
- Internal cleanup.

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
