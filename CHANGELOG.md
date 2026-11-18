# Changelog

## 1.5.1 – 2026-11-18

- **Fixed:** Lua error in the sandbox (`Sandbox.lua:38 … secret number value`) every frame when the game hides the mana values: the size of a text showing a hidden value is hidden too. Such texts are now measured with an invisible placeholder of the same font size
- Sandbox errors can no longer stop the display and are reported only once
- Fixed: numbers, timer and MP5 could not be moved in the sandbox (`attempt to index local 'point' (a secret string value)`, `Frame:SetPoint(): Usage`). When a text shows a hidden mana value, the game hides even its anchor points. The display now keeps track of its own anchor points instead of asking the game
- **Every module can be moved on its own** in the sandbox: mana display (ring / pie / bar), timer (inner ring / timer bar), background, border, decoration, numbers, second number, timer text and MP5. Every part has a name tag that you can grab too – this way parts that lie underneath others (background, border) can be moved as well
- **Sandbox handling:** click directly on a text (or the timer / decoration) and drag it. While you drag, everything else fades into the background until you let go. Texts lie above the decoration, so a click on a text always grabs the text. Empty texts (timer) show a sample text while the sandbox is open

## 1.5.0 – 2026-11-18

- **Green sandbox for your own arrangement:** while the options window is open, a green area appears around the display
  - drag the numbers, second number, timer text, MP5 line, timer bar (or inner ring) and the decoration with the mouse – each part is labeled
  - nothing can be moved past the green border
  - drag the title bar to move the whole display
  - right-click a part to put it back; "Reset arrangement" in the options resets everything
  - the arrangement is saved separately for ring, pie and bar; the sandbox can be switched off

## 1.4.1 – 2026-11-18

- **Fixed:** mounting, melee abilities and other spells without mana cost no longer start the five-second rule when the game hides the mana values. Only spells that cost mana count

## 1.4.0 – 2026-11-18

- **Colors of the bars:** new section in the options. The mana bar (ring / pie / bar) and the timer bar (tick timer / five-second rule) each have their own setting:
  - fixed color, or
  - their own gradient with three colors (full / half / low for mana, empty / middle / full for the timer) and an adjustable middle point
- Independent of the color gradient of the numbers. Choosing a color switches the bar to the matching mode
- The former option "Color the mana display too" is carried over into the new mana bar gradient
- **Visual effects can be switched on and off individually:** decoration rotates, wings float, glow pulses, lightning flickers, spark pulses, border pulses during the five-second rule, flash on every mana tick. Switched-off effects return the decoration to its resting position

## 1.3.3 – 2026-11-18

- **Fixed:** in bar mode with hidden mana values the display stopped updating every frame ("FontString:SetText(): Font not set"). Because of this the text mode (percent/value), the colors and the low-mana warning had no effect. All texts now get a font right away
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
