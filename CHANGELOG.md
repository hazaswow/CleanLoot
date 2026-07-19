# Changelog

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
