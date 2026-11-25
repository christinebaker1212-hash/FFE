# FF1 native build: screen audit and polish proposals (2026-11-25)

Owner (2026-11-25): "a polish pass on every menu in the game to bring it up to a higher standard,
making certain GB is on par with CGB. Give suggestions, and I'll approve. First, audit every screen."
Also: "animate the water in castles and caves."

Owner's answer (2026-11-25): "W2, and do all of A, B and C". Outcomes at the end of this file and in
`docs/ff1-native.md` item 45.

## How the audit was made
SameBoy (patched core, `tools/gb/sameboy/sameboy-ffe.patch`), the same inputs on Game Boy Color, plain
Game Boy and Super Game Boy, shots side by side. Test ROMs: `build.py --start 0,X,Y --init ...` with a
mid-game party (Warrior / Red Mage / White Mage / Black Mage, level 15, a six-letter name, one member
poisoned, equipment, spells, consumables, key items, two orbs lit, 123456 Gil); one ROM per Cornelia
shop (started below each door), `--battle 62` for battle, the release ROM for the title side.
The VRAM/OAM checker read 0 on all three systems on every tour.

Screens covered: prologue, title, Extras (Sound Test, Bestiary), CLASSIC / MODERN and their
descriptions, party creation, job list, name entry; field, place banner, dialogue; main menu, Items
(Use / Key Items, target window, using a Potion), Magic (list, target window), Equip (slots, list,
preview), Status, Options, Suspend, Formation; weapon / armour / white magic / item shops, inn and
the save files, clinic; battle commands, enemy target, Magic, Medicine, Items, messages, results;
overworld, world map.

Harness notes (scratch scripts): the title's Down skips Message Speed (left / right change it), so one
Down from New Game is Extras; the prologue's second page waits for A, and the title takes ~300
frames to accept input after it; hold keys 6 frames.

## Water in castles and caves (finding)
FF1's castle and cave maps have no water tiles. The large blue / teal fields (Cornelia Castle 2F, the
Castle of Ordeals' upper floors, the Temple of Chaos of the past, the Waterfall Cave) are the flat
one-colour background outside the walls (one solid tile), so shifting it shows nothing. The textured
blue tiles found by a scan are cave and Undersea Shrine floors. On the world map, coasts and river
banks already move where they show sea or river. Options for the owner:
- W1. Leave castles and caves as FF1 has them.
- W2. Animate the overworld waterfall (metatile $46, one place), falling downwards.
- W3. Treat the flat blue backgrounds as water and give them a moving ripple (the towns' pattern in
  their colours). This adds a look FF1 does not have.
- W4. The owner names the places meant.

## A. Faults found (fix)
1. **Color: gradient bands where windows share lines.** The gradient is per line, so the shop list
   beside the Gil window takes the Gil window's colours (a lighter band) and loses its bottom edge
   there; every shop's buy / sell list.
2. **Shop buy list:** the "Own / Worn" line is printed on the speech window's bottom border row, and
   the Gil window covers the list's last price row.
3. **Item / magic target window:** it and the text window below share a border row; after an item is
   used the row flips from the lower window's top edge to the upper window's bottom edge.
4. **Battle enemy window:** a long name is cut and the count joined to it ("Tyrannosaur1").
5. **Battle:** a dead member's lying pose overlaps the member below by a few pixels.
6. **Color:** the party-creation boxes are flat blue; every other window has the gradient.
7. Wording: "Ok to start on CLASSIC?" -> "OK" (as "OK to begin with this party?").
8. Level label differs per screen: "L15" (main menu), "Lv 15" (Equip), "Level 15" (Status).
9. To check: the Super Game Boy draws the Tyrannosaurus orange, the Color blue (formation 62); match
   the NES on both.

## B. Plain Game Boy / Super Game Boy on par with the Color
10. **Greyed-out choices:** the title's Continue (no save) is grey on the Color only; on DMG / SGB it
    looks selectable. DMG: light-grey text (a second text shade); SGB: a grey palette for the cells.
11. **Better / worse previews** (shops' party window, Equip): red / green numbers on the Color only.
    Add an arrow after the new value on every system (up / down / equal), keeping the colours.
12. **Gold labels** (screen headers, "L1", status labels, "File 1", "Formation"): Color only. SGB:
    a gold palette for those cells (attribute blocks); DMG: unchanged, or a small marker.
13. **Pictures on black windows (DMG):** job pictures in menus and the party in battle are dark grey on
    black (Warrior, Red Mage, Monk hard to see). Options: (a) a DMG window shade option, Black /
    Dark grey; (b) menu pictures drawn with a lighter sprite shade map (darkest colour as dark grey,
    with a black outline); (c) both.
14. **Options:** the Color has Window Red / Green / Blue / Gradient; DMG / SGB have no window setting.
    SGB: window colour presets (the SGB can show them); DMG: the window shade of 13a.
15. **SGB backgrounds:** outside the windows the SGB shows blue (shops, Suspend, title, CLASSIC /
    MODERN); the Color and DMG show black. Make it black.

## C. Polish
16. **Name entry:** the letter grid's rows are packed together and read as vertical strips. Proposal:
    one case at a time as now, 8 columns x 6 rows with a blank line between rows (48 slots: letters,
    digits, punctuation), the hand at the letter's left.
17. **Shop buy list:** price on the name's line (right-aligned), up to 8 items visible, a header line
    for Own / Worn inside the list window.
18. **Non-casters:** Status shows sixteen "0/0" MP values for a Warrior; show the MP block only for
    casters. In battle, Magic opens empty level rows: grey the command, or show "No spells".
19. **Sound Test:** a song name beside the number (our own labels for the 24 songs, e.g. "Prelude",
    "Cornelia Castle"), "Now playing" while a song runs.
20. **Bestiary:** entry numbers (001-128) so unseen slots read "012 ------".
21. **Formation:** a second, still hand on the member picked first; the title in a header window as on
    the other screens.
22. **Battle results:** the empty command box beside the party window stays open; hide it.
23. **Key Items:** their own icon (a key) instead of the consumables' bag.
24. **Options:** values right-aligned in their own column with a gap ("Text Speed   Normal"); the
    Color's window settings under a "Window" heading.
25. **World map:** no party marker showed in the shots (it may blink between them): a clear
    "You are here" mark on all systems.

## Proposed order
A (faults) first, then B (parity), then the C items the owner picks.

## Outcomes (2026-11-25)
- W2 done: the world map's waterfall falls a pixel per water step (W1 / W3 / W4 not chosen).
- A1 done by A2's layout: the shop's Gil window beside the list is gone (an info window below takes the
  full width), so no two windows share a line there.
- A2 done: one line an entry (names up to 17 letters inside the frame), six shown; an info window with the
  price, Own / Worn and the Gil.
- A3 done: after a use only the target window's inside is redrawn; the text window's top edge stays.
- A4 done: a name too long is cut with '.' and a gap before the count ('Tyrannosa. 1').
- A5 not a fault: the lying pose ends above the next member's rows.
- A6 not a fault: CLASSIC sets the gradient off by design (Options turns it on).
- A7 done ('OK to start on'); A8 done ('Lv 15' on the main menu, Equip and Status).
- A9 done: per formation the SGB takes the enemy colours from palette A alone / B alone / both, by the
  enemies present (the Tyrannosaurus blue as on the Color).
- B10, B12 done: gold labels and grey choices in other inks on DMG / SGB (DMG light / dark grey; SGB a
  gold palette over the labels' area).
- B11 done: an arrow up / down between the values on every system (colours kept on the Color).
- B13, B14 done: DMG Options 'Window' Black / White (White: dark text on white windows, the job pictures
  readable; the lit orbs then show dark); SGB Options Window Red / Green / Blue as the Color's.
- B15 backed out: a frame cell holds outside and inside pixels and takes one SGB palette (a blue halo or a
  black inner rim), and screens with more windows than one attribute packet holds stayed blue. Hardware
  limit; left blue.
- C16 done: three pages (capitals / small letters / digits and signs, Select), rows with a blank row between.
  Owner's addition: Start with no name types a preset name for the job.
- C17 done as A2 (one line an entry plus the info window: 39 of the 71 entries are too long for the name
  and the price on one line).
- C18 done: '-' for a non-caster's MP; battle Magic with no spell: the error sound.
- C19, C20, C22, C23 done (song names and 'Now playing'; Bestiary numbers; no empty window beside the
  results; the key icon).
- C21 half done: the still hand on the member picked first. The header window was not added: the four
  24-pixel members at FF1's 32-pixel pitch need rows 2-17, so a header (rows 0-2) would cut the first one;
  the title stays a gold label inside the window.
- C24 left as is (labels up to 13 letters, values up to 7: one column with a gap does not fit 18).
- C25 not a fault: FF1's 'you are here' mark blinks.
