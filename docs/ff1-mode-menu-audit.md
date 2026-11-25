# FF1 native build: CLASSIC / MODERN and the main menu, measured against Nintendo practice (2026-11-25)

Owner (2026-11-25): "Audit the Classic/Modern selection. Is this how Nintendo would do it? Audit the
main menu. Is this how Nintendo would do it? Offer alternatives and fixes."

## How the audit was made
SameBoy (the patched core), release-equivalent builds: `build/pict.gb` (title -> New Game ->
CLASSIC / MODERN -> descriptions -> question) and `build/pic.gb` (Cornelia Castle, level-15 party
Warrior / Red Mage / White Mage / Black Mage, one member poisoned, 123456 Gil), each on Game Boy
Color, plain Game Boy with Black windows and plain Game Boy with White windows. VRAM/OAM checker 0
on every run. The Super Game Boy was not run again: these screens follow the plain Game Boy's Black
windows there (earlier audit, B15) and nothing in them is SGB-specific.

"How Nintendo would do it" is measured against:
- Nintendo's Lot Check terminology (our own `docs/gb-release-checks.md` 4.1: "A Button",
  "B Button", "Control Pad", ...).
- Nintendo-published Game Boy / Game Boy Color RPG menus (Pokemon Red / Blue / Gold / Silver,
  Link's Awakening DX) and Square's Game Boy RPGs (the SaGa / Final Fantasy Legend games), the
  project's stated layout model.
- Nintendo's own mode choice (Fire Emblem's Classic / Casual: the choices with a description of the
  highlighted one on the same screen, then a confirmation) and Final Fantasy I & II: Dawn of Souls
  (Nintendo published it in North America: commands in a column, the party with HP and MP).

## Part 1: CLASSIC / MODERN

What it does now (`ng_mode`, `src/loc.s`): after New Game, a small window on black with CLASSIC /
MODERN (no header). A opens a second, full-screen window with 16 packed lines describing the choice;
A again opens "OK to start on / CLASSIC?" with Yes / No (Yes first, Left / Right). B on the choice
returns to the title; B on the description or the question returns to the choice.

Verdict: the idea is Nintendo-like (a choice at New Game, changeable later, confirmed with Yes / No,
as Fire Emblem does), but its presentation is not. Findings:

M1. **Two steps to read what a choice means.** The description is a separate screen reached with A,
    so the player cannot compare the two without going back and forth. Nintendo shows the
    highlighted choice's description at once, on the same screen, and updates it when the cursor
    moves (Fire Emblem's mode choice, Pokemon's options).
M2. **A wall of text.** 16 lines with no blank rows; the lines touch (descenders of "gameplay" meet
    "to" below). The text names 3 of the 5 settings the choice makes: Modern does not say it also
    remembers the battle cursor and turns on the Color's gradient windows; Classic does not say
    there is no dash.
M3. **"Houses" is not this game's word.** The item is called Cottage in this translation (the Items
    screen lists Sleeping Bag / Tent / Cottage). "Inns or Houses" -> "Inns or Cottages".
M4. **Button wording.** "Dashing is enabled with B" names a button the way Lot Check does not
    accept; Nintendo writes "Hold the B Button to dash." (`docs/gb-release-checks.md` 4.1 also says
    the menus name no hardware: true again once this is fixed.)
M5. **Capitals.** CLASSIC / MODERN / OPTIONS are in capitals; every other label in the game is in
    mixed case (the main menu's "Options"). Nintendo keeps one style per game: "Classic", "Modern",
    "Options".
M6. **No header.** Every other screen has a header window (screens unified, item 41); this one is a
    lone window on black. Header: "Game Style" (or "Select a Mode").
M7. **Question wording.** "OK to start on / CLASSIC?" reads oddly. To match the party screen's "OK to
    begin with this party?": "OK to begin in / Classic style?".
M8. **"True to the original".** Nintendo's in-game text does not talk about other versions of a
    game; say what the style does instead ("The game's own rules.").
M9. (Good as it is) B backs out at every step, Yes is first, the choice is changeable in Options and
    the text says so, the question comes before anything is set.

### Alternatives (pick one)

**Alternative A (recommended): one screen, live description.** Header, the two choices, and a
description window below that changes as the cursor moves; A asks the question; B goes back to the
title. Descriptions in short lines with the Options names:

```
+------------------+
|Game Style        |
+------------------+
+------------------+
| >Classic         |
|  Modern          |
+------------------+
+------------------+
|The game's own    |
|rules: spell      |
|charges, restored |
|at Inns and with  |
|Cottages. No dash.|
|Targets stay as   |
|chosen.           |
|                  |
|Change any of this|
|later in Options. |
+------------------+
```
Modern's text: "Spells share one MP pool per member. Hold the B Button to dash. The party
retargets when a target falls, and the battle cursor remembers its place." (+ "Windows shade from
top to bottom." on the Color.)

**Alternative B: a settings table.** The same screen, but the description is the list of settings
the highlighted style sets, with the exact Options labels and values, so nothing is hidden and the
player learns where to change them:

```
+------------------+
|Game Style        |
+------------------+
+--------++--------+
| >Classic||  Modern|
+--------++--------+
+------------------+
|B Dash         Off|
|Cursor       Reset|
|Auto Retarget  Off|
|Modern MP      Off|
|Gradient       Off|   (Color only)
|                  |
|Change any of this|
|later in Options. |
+------------------+
```

**Alternative C: no choice at New Game.** Most Nintendo Game Boy games have no such screen: the
game starts with one set of defaults (Classic, the game's own) and the Options menu holds the rest.
Simplest, but the player who wants Modern must find five options.

Fixes M3-M5 and M7 apply to whichever is chosen (and to the current screen if it stays).

## Part 2: the main menu

What it does now (`menu_main` / `mm_draw`, `src/menu.s`): party window (0,0,12,14) with each member's
battle picture and three lines (name; level or ailment; HP / max), commands (11,0,9,8) Items / Magic
/ Equip / Status / Options / Suspend (Save with the code), orbs (11,7,9,7), place / play time / Gil
(0,13,20,5). The hand starts on Items at every opening; B closes; Formation is on Select on the map.

Verdict: the structure is the one Nintendo and Square used (a command column beside the party, money
and time below, as Dawn of Souls), and the information is right. The details below are where a
Nintendo-published game would differ.

N1. **The hand sits across two window frames.** The 16-px hand left of the commands covers the party
    window's right border, the gap and the command window's left border. Nintendo keeps the cursor
    inside the window it selects in. Fixes (pick one):
    - N1a: commands window drawn over the party window from column 10 (the party text ends at column
      9): the hand then rests on the command window's own edge only, the gap and second frame gone.
    - N1b: labels of up to 6 letters from column 13 (Options -> "Config", Dawn of Souls' word;
      Suspend -> "Quit"), the command window from column 10: the whole hand inside the window.
    - N1c: leave it (the owner's hand rule puts the fingertip just before the text).
N2. **Start does not close the menu.** Start opens it, but only B closes it. Nintendo's rule is that
    the button that opens a menu also closes it (Pokemon: Start or B). Fix: Start closes it too.
N3. **The cursor goes back to Items every time.** Pokemon keeps the menu cursor where it was. Fix:
    remember the last command while the game is on (or follow the Options "Cursor" setting:
    Remember / Reset, now used by battles only).
N4. **Formation is hidden.** It is only on Select on the map (as on the NES). Dawn of Souls lists it in
    the menu. Fix: a seventh command "Formation" under Status; the command window becomes 9 rows and
    the orbs window 6 (the orbs fit exactly: 4 rows inside).
N5. **No low-HP warning.** Battle shows a member under a quarter of their HP in yellow and a dead /
    stoned one in red (Color); the main menu shows them all alike. Nintendo's HP displays warn (the
    Pokemon HP bar turns yellow, then red). Fix: the battle's colours on the main menu's lines (Color);
    on the plain Game Boy / SGB nothing (no spare shade), or a blinking-free mark such as "!" after HP.
N6. **Modern MP is not shown.** With Modern MP on, MP is per member like HP, and Dawn of Souls shows it
    on its main menu; here it is only on the Magic and Status screens. No room in the current
    layout (three lines, seven columns); see Alternative MM-B, or leave it.
N7. (Good as it is) Ailment in place of the level (Pokemon does the same), the error sound for magic
    on a dead / stoned member, wrap-around up / down, the pictures one pixel clear of the text, the
    place / time / Gil window, B back to the map, Suspend asking before it acts.

### Alternatives

**MM-A (recommended): the approved layout with fixes N1, N2, N3, N4 and N5.** Small changes, same
look. Shown with N1b (labels of up to 6 letters from column 13, the command window from column 10
drawn over the party window's edge) and N4 ("Order", the 6-letter name for Formation):

```
 0         1
 01234567890123456789
+---------+---------+
|PP Dune  | >Items  |
|PP Lv 15 |  Magic  |
|PP245/310|  Equip  |
|PP Rienne|  Status |
|PP Lv 15 |  Order  |
|PP265/320|  Config |
|PP Jojo  |  Quit   |
|PP Poison+---------+
|PP285/330|  (o)(o) |
|PP Leo   |  (o)(o) |
|PP Lv 15 |         |
|PP305/340+---------+
+---------+---------+
|Cornelia Castle    |
|Time           0:00|
|Gil          123456|
+-------------------+
```
(PP = the member's picture; Jojo's lines in yellow when under a quarter of their HP, red when dead or
stoned, on the Color.) With N1a instead, the labels stay as they are and the hand rests on the
command window's own left edge.

**MM-B: party full width, commands across the bottom.** Each member gets a full-width line set
(name and level; HP; the spell charges of levels 1-8 in Classic, "MP 12/30" with Modern MP, "-" for a non-caster), the commands are a 2 x 3 grid in
a bottom window with the hand fully inside, opened over the party window as the design rules ask.
The orbs and place / time / Gil move to a second page on Select (or to Status):

```
+------------------+
|PP Dune      Lv 15|
|PP HP 245/310     |
|PP -              |
|PP Rienne    Lv 15|
|PP HP 265/320     |
|PP 4 3 2 1 0 0 0 0|
|PP Jojo     Poison|
|PP HP 285/330     |
|PP 4 3 2 0 0 0 0 0|
|PP Leo       Lv 15|
|PP HP 305/340     |
|PP 4 4 2 1 0 0 0 0|
+------------------+
| >Items    Magic  |
|  Equip    Status |
|  Options  Suspend|
+------------------+
```
Gains: MP / charges always visible (N6), the hand inside the window (N1), room to breathe. Costs:
the orbs, place, time and Gil leave the first page; a bigger change to an approved screen.

**MM-C: Pokemon-style.** Start opens only a narrow command column over the map; the party, orbs and
Gil are on their own screens. Most Game Boy-like, least FF1-like; listed for completeness, not
recommended.

## Summary of fixes
| # | Screen | Fix | Size |
|---|---|---|---|
| M1 | Classic / Modern | one screen with a live description (Alt. A or B) | medium |
| M2 | Classic / Modern | short, complete descriptions (all five settings) | small |
| M3 | Classic / Modern | "Houses" -> "Cottages" | tiny |
| M4 | Classic / Modern | "Hold the B Button to dash." | tiny |
| M5 | Classic / Modern | "Classic" / "Modern" / "Options" in mixed case | tiny |
| M6 | Classic / Modern | header "Game Style" | small |
| M7 | Classic / Modern | "OK to begin in / Classic style?" | tiny |
| M8 | Classic / Modern | no "true to the original" | tiny |
| N1 | Main menu | hand inside the command window (a or b) | small |
| N2 | Main menu | Start closes the menu | tiny |
| N3 | Main menu | the command cursor remembered | tiny |
| N4 | Main menu | a Formation ("Order") command | small |
| N5 | Main menu | low-HP / dead colours as in battle (Color) | small |
| N6 | Main menu | MP / charges on the main menu (needs MM-B) | large |
