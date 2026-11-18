# Changelog

## 1.3.3 – 2026-11-18

- `/msig debug` now shows the installed version, the current text/color/warning settings, a self-test of every step of the hidden-mana display (percent, color, warning) and the last errors
- Errors when changing an option are reported in the chat instead of interrupting the options panel

## 1.3.2 – 2026-11-18

- Tick detection with hidden mana values now only uses the server mana updates (`UNIT_POWER_UPDATE`); the almost continuous `UNIT_POWER_FREQUENT` events no longer count as ticks
- Colors: choosing the **text color** now switches the number color to "Fixed" (before, the gradient covered it, so the change was not visible); choosing the full/half gradient colors switches back to the gradient. Color tooltips explain which setting they belong to
- `/msig debug` shows how many mana events of each type arrived and the time between the server updates

## 1.3.1 – 2026-11-18

- Tick timer and five-second rule now also work when the game hides the mana values (detected from the mana events and your spell casts)
- More robust start: the mana and tick tracking now runs even if another part of the addon (e.g. the options panel) fails to load; such errors are reported once in the chat with the exact cause instead of stopping the addon
- **Hidden mana values:** percentage, color gradient and the red blinking low-mana warning now also work when the game hides your current mana (computed by the game itself via curves). The warning sound needs readable mana values
- `/msig debug` additionally shows the time between the last mana ticks

## 1.3.0 – 2026-11-18

- **Color gradient for the numbers:** green when mana is full, yellow in the middle, red when low (or a fixed color). The point where it is yellow is adjustable, and the three colors can be changed
- Optional: the ring, pie or bar itself uses the gradient too
- **Low mana warning** at a threshold you type in – in percent or in mana points
  - numbers turn red and blink (or the whole display blinks, or no blinking)
  - warning sound: raid warning, ready check, alarm clock, whisper or map ping – plays once, or repeats every x seconds
  - optional: only in combat

## 1.2.1 – 2026-11-18

- **New directions** for ring and pie: left to right and right to left (in addition to clockwise, counter-clockwise, bottom to top, top to bottom)
- **Pie slices** from halves and quarters up to thousandths (2, 3, 4 … 100, 250, 500, 1000); with many slices the divider lines are left out
- Pie is now completely filled up to the center (it used to fade out towards the middle)

## 1.2.0 – 2026-11-18

- **Display modes:** Ring, Pie or Bar (`/msig mode ring|pie|bar`). Bar mode also works when the game hides mana values.
- **MP5 display:** shows your mana regeneration per 5 seconds – the value that applies right now, or both (normal / during the five-second rule)
- **Direction** of the mana display and of the timer: clockwise, counter-clockwise, bottom to top or top to bottom (ring and pie fill like a liquid)
- **Pie fill:** smooth or in slices (ticks), number of slices adjustable
- **Bars:** free width and height, horizontal or vertical, fill direction in both ways
- **Timer behaviour:** five-second rule and tick timer can each fill up or empty out
- Timer ring hides when mana is full (optional), border glows during the five-second rule (optional)
- Every decoration part (wings, halo, glow, horns ...) can be hidden individually
- The backup bar for hidden mana values can be switched off
- Options: tooltips for every setting, settings without effect in the current mode are greyed out, removed the redundant "Scale" slider (merged into base size)
- Fixed symbols being cut into half circles when rotated (own rotation math, round symbols are never rotated)
- Background and border now adapt to the outermost ring
- New `/msig debug` command for troubleshooting

## 1.1.2 – 2026-11-17

- Fixed the automatic CurseForge upload
- Includes 1.1.0: English localization (follows the game client language), German on `deDE` clients

## 1.1.1 – 2026-11-17

- Releases are now uploaded to CurseForge automatically
- Includes everything from 1.1.0: English localization (follows the game client language), German on `deDE` clients

## 1.1.0 – 2026-11-17

- English localization: the addon now follows the game client language – German on `deDE` clients, English on all others (options, tooltips, chat messages, theme/symbol names)
- Addon list description available in English and German

## 1.0.0 – 2026-11-17

First release.

- Mana ring (outer) with spark
- Five-second rule tracker (inner ring) with countdown
- Mana tick timer (2 s cycle, `+amount` on tick)
- 9 themes, chosen automatically by class: Angel Wings, Shadow Wings, Demon Pact, Arcane Runes, Grove of Nature, Holy Light, Stormcaller, Wilderness, Classic
- Theme colors and decoration selectable independently
- 11 ring symbols or a solid circle per ring
- Adjustable sizes: rings, symbols, background, border, text, spark, decoration
- 9 customizable colors
- Minimap button (on/off, options, draggable)
- Options panel with live preview, slash commands `/msig`
- Fallback display if mana values are hidden in combat (secret values)
