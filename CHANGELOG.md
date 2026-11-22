# Changelog

## 1.7.0 (in progress)

**Master loot: taking the loot, and your tradable items**
- A **Take all** button under the loot window gives you every master-loot item of the window (the ones at or above the game's loot threshold), to hand them out later. The group is told in the chat: one line saying CleanLoot takes the items for the master looter, then one message per item with its link. An option does it by itself when the loot window opens (hold Shift to skip it). `/cll take` does it from the keyboard.
- CleanLoot now keeps a list of what you can still hand out: the bind-on-pickup items you may still trade (with the time left) and the bind-on-equip ones that are not bound yet. It only follows the master looter, and only reads a bag when something changed. `/cll session` opens the list, oldest first (the items about to become untradable come first, bind-on-equip ones last), every item offered by default, with a box to leave one out.
- All the master looter's messages go to /ra in a raid and /p in a party. An option sends them to /rw instead when you lead or assist.
- The master loot settings now have their own tab in the options window, with the switch, the roll results, taking the loot and the session list.
- Safer hand-outs: a first name is only taken for a player when it fits one player in the loot window's list (two characters called Hazas can no longer be mixed up).
- **Timed loot sessions** (master looter): *Start session* in the `/cll session` window (or `/cll session start`) offers the items of the list one after the other, 15 seconds each by default (10 to 60 in *Options → Master loot*). For each item the group is told in the chat how to roll (`1-100=MS 1-99=OS 1-90=Other`), with reminders and a countdown for the last 3 seconds, and the rolls are read from the game's own `/roll` messages, so players with or without CleanLoot take part the same way. MS beats OS beats Other whatever the numbers; the first roll of a player counts, a later roll in a *lower* category replaces it (never the other way round), and a pass cancels the roll.
- The best roll wins by itself (or untick that to pick every winner yourself with a click and a confirmation). A tie is announced and can be re-rolled between the tied players only. Pause, +10 s, Skip, Cancel and Re-roll each announce themselves in the chat. At the end each winner gets a whisper per item inviting them to come and trade you.
- **Identical items** (same item, enchants, gems and bonuses) are offered together: one roll for all the copies, and the best rolls win a copy each (three copies, the three best rolls). Equal rolls on the last copy are announced and re-rolled between the tied only.
- **Going back:** a small icon for every item already done sits at the side of the window; a click goes back to it to take an assignment back (with a confirmation), give a copy to one of the rolls, or give one by hand to anybody by name. After the last item the session waits 30 seconds (each change gives more time) before the whispers go out, or *Finish now*.
- Each kind of roll has its own colour (MS, OS, Other), and the master looter has roll buttons of his own (MS, OS, Other, Pass) in the session window: they make the game's /roll like everybody's.
- **A window for the other players:** players with CleanLoot get a window while the master looter's session runs, with the item in play, the time left, everybody's rolls as they come in (same colours, same rules) and buttons to roll themselves (MS 1-100, OS 1-99, Other 1-90) or pass. It follows the master looter's CleanLoot through addon messages (only the group's master looter is believed) and reads the rolls from the game's `/roll` messages; players without CleanLoot take part exactly as before, by typing `/roll`. An option turns the window off.
- **A disenchanter:** the master looter asks the group *Who can disenchant?* in /ra (or /p, or /rw with the option); enchanters answer with a short word (`de` by default, and `de 300` adds their skill), and a click on a name makes one of them the designated disenchanter (or `/cll de <name>`; a new *Disenchanter* tab in the options). In a session, items nobody rolls for, and the copies nobody rolled for, go to him (armor and weapons from green to epic), a *To DE* button sends the item in play to him, and a finished item's free copy can be sent to him from the side icons. At the end he is whispered to come and trade you, and either keeps the materials or trades them back to you, as you choose.
- *Test it* (or `/cll session test`) runs a session with made-up players and sends nothing to the group; alone, a real session only prints to you, so you can roll with `/roll` and see it work.
- Not in yet: putting the won items in the trade window by itself when the winner trades you.

## 1.6.0

**Master loot** (new)
- With a master looter the game runs the rolls but names no winner, so nothing showed once they were over. Now, when the rolls end, **everybody in the group** gets a *roll result* window for the item: every roll with the player's name (class coloured), best first (Need above Greed), ties flagged, and how many passed or did not roll. Hover the icon for the item.
- **The master looter can click a name to give that player the item.** A small confirmation opens at the mouse; on *Give* the item is handed out from the boss's open loot window, and once the game confirms it the group is told in the chat, in /p (or /ra in a raid): `[CleanLoot] [item] given to Name for roll Greed 44`. If the game refuses (full bags, too far away, the loot window closed) nothing is announced and you are told why.
- The "Waiting on rolls" card no longer stays up after a master-loot roll is over.
- The whole master-loot part has its own switch (*General* tab, or `/cll master on|off`): off, it watches and announces nothing, and the rest of CleanLoot is untouched. Two more options under it: show the window, and announce the hand-outs in the chat (all on). If **Gargul** is installed, which also announces what you award, CleanLoot asks the master looter once whether to keep both, turn off CleanLoot's master loot features or turn off Gargul's *Award messages* (`/cll gargul` asks again; so does the button on the General tab). `/cll sim master` opens a made-up window to look at it and try the click.
- Honest note: the roll window is built from real master-loot data, but handing an item out through the loot window and the chat announcement have not been tried in a real group yet. If something misbehaves, `/cll debug on` and tell me what you see.

## 1.5.0

**Options window** (new)
- `/cll`, a right-click on the minimap button, or the button in *Game Menu → Options → AddOns → CleanLoot* now opens CleanLoot's own window, with a tab per page (General, Controller mode, Auto-roll, Watchlist). It is not one of the game's modal panels: the bags, the Dungeon Journal or the chat can stay open next to it (so you can shift-click an item into its boxes), you can move it, Esc closes it, and it opens in combat. `/cll` opens it, and closes it again.

**Watchlist** (new; nothing is highlighted until you add an item)
- Keep a list of items you want to be reminded of. When one drops, its roll frame gets a gently pulsing outline, and an optional note you wrote for it (*BiS for my mage*) shows on the frame and in the icon's tooltip.
- Add an item on the new *Watchlist* tab (shift-click it into the box, or paste its link or its id), or with `/cll watch [item] [note]`. Edit a note right in the list, or with `/cll watch note [item] <text>`.
- It only draws the eye: a watched item is never rolled for you. Auto-roll is separate, and both can apply to one item.
- `/cll sim` always drops one watched item first, so you can see it without waiting for a real drop.

**Winner popup**
- Hovering a result card now shows the item's own tooltip first, then who rolled what.

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
