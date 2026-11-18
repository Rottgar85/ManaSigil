# Changelog

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
