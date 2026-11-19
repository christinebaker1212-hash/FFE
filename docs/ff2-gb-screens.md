# FF2 on the Game Boy: screen layouts (owner's decisions)

Mock-ups: `tools/gb2/mockup.py` (output in build/mock, graphics from the user's NES build).
Re-layouts are done in the NES code (NES side, `tools/gb2/layout.py`, applied after
`insert.py`), so frame-by-frame RAM checks against that NES variant keep working.

## Battle (approved 2026-11-19: `ff2_mock1_battle.png` + `ff2_mock5_battle_fit.png`)
- All 4 members and every formation fully on screen (owner).
- Survey (`tools/gb2/ff2form.py`, all 128 formations forced on the NES): enemies NES x
  16-159, y 48-143 (12 rows exactly); 126 formations within x 16-143, the Emperor (126)
  x 25-151, formation 90 (three 48-px monsters across) x 17-159. NES party: x 212-238
  (front x 212-214, back row 10-12 px right), y 45 / 72 / 99 / 126 (24 px tall, 27 apart).
- GB: battlefield rows 0-11 = NES y 48-143; enemy area = NES x 20-159 at GB x 0-139
  (formation 90 loses 3 px of an antenna at the left edge; owner's choice); party column
  GB x 140-159: front row x 140, back row x 144 (4 px), members at y 0 / 24 / 48 / 72,
  every sprite whole. The acting member steps forward (8 px, as FF1).
- Bottom rows 12-17: enemy names window (cols 0-7; the command window Fight / Run / Magic
  / Gear opens over it), party window (cols 8-19): name, HP current/max (3-px digits; "Dead"
  in place of the maximum as on the NES), MP. Messages: full-width window over both,
  style A (actor > target / action / result lines), small proportional font. No blinking.

## Battle lists (approved 2026-11-19: `ff2_mock6_battle_lists.png`)
- Magic: full-width bottom window, spells in two columns (pen x 17 / 89, hand at x 0 / 72),
  three rows a page, line 4 "MP cur/max" and "MP Cost n"; moving past the last row turns
  the page.
- Gear: Right Hand + weapon, Left Hand + weapon, Items + item 1, item 2 below it (labels
  and names as translated; hand at the screen edge on the chosen line).

## Field dialogue (approved: `ff2_mock2_dialogue.png`)
Box over the top of the view (GB rows 0-7: frame, 6 lines of 18 columns, frame), the party
below stays visible; same text re-wrapped at 18 columns, a new page of 6 lines on A.

## Main menu, as built (owner approved the revision `ff2_mock9_menu_bg.png`, "but still keep
them inside the border window", 2026-11-19)
- Four portraits are 48 sprites; a Game Boy shows 40, so the portraits are background tiles
  (copied from the ROM at menu start into the menu's unused BG tiles $01-$30). NES colours
  come in 16 x 16 blocks: camera (1, 1), so the party window NES (1,1,12,18) is GB (0,0,12,18)
  and each portrait box (NES cols 2-5, rows 2+4k..5+4k) covers whole attribute quads, with
  the member's portrait palette in a BG palette of its own (menu BG palettes 0-2 are free).
- Per member: name, HP cur/max, MP cur/max (small letters / 3-px digits), status word.
- Commands GB (12,0,8,8), one per row, hand over the frames between the windows; Gil GB
  (12,14,8,4): amount in 3-px digits, "Gil" below.

## Main menu (approved 2026-11-19: option A of `ff2_mock4_menu_portraits.png`; superseded above)
Owner: keep the portraits. Party window over the left 13 columns, full height, one 4-row
block per member: portrait (32 x 32), name, HP current/max, MP current/max (3-px digits),
status word. Commands (Items, Magic, Equip, Status, Save; cols 13-19 rows 0-6) and Gil
(rows 7-9) beside it.

## To draft
Items, magic, equipment, status, shops, keyword dialogue (Ask / Learn), save menu, name
entry, prologue, title, ending, world map (B + Select), Select menu (options / formation /
suspend).

## Battle: how it is built (layout.py, in progress)
- Cameras: battlefield NES (20, 48) for GB lines 0-95; second camera (0, 48) from line 96,
  so the windows live in NES rows 18-23, cols 0-19 of nametable 0 (y maps 1:1 for both,
  only x differs). Party: y = slot * 24 + 48, base x 156 / 160.
- One BG pattern table: on the NES the menu area switches to table 0 (font) at the sprite-0
  split; a DMG cannot hold both tables plus the sprite slots, so in the GB layout the menu
  area stays on table 1 (`fix:FD5B` AND #$EF dropped) and the windows draw with table-1
  tiles not used by this battle's battlefield. Free tiles per battle: backdrop `$00`,
  `$10-$1F` always used; monsters use rectangles of consecutive tiles from the first tile
  of their graphics (`b11:9F14`, table `$9FA5`), bosses a 144-byte tilemap (`b11:9F57`);
  survey (`tools/gb2/ff2tiles.py`, all 128 formations): at most 133 tiles in rows 2-17
  (formation 6), so >= 100 tiles are free in every battle.
- Window code (planned): pool init after the monster tilemaps (free-tile list in RAM);
  small proportional font renderer (glyphs from tools/latin_font.py, 3-px digits) writing
  tile bitmaps to the pool tiles in vblank after the game's own waits; panel routines
  replacing the NES window drawing: names (`b12:910D`), party stats (`b12:912A`), commands
  (`b12:9147`, over the names window; the menu scroll `b12:981D/982C/9AC6` no longer
  slides), message boxes (bank 5 `AA57` open / `AB4F` close, English boxes at `5:AC02`),
  then the magic / Gear / item lists, victory and loot windows. Code in free bank 23,
  called through fixed-bank stubs that switch with `$FA7F` (bank recorded in `$3E`, so
  the asynchronous battle NMI's "return (long)" restores it).
- Free RAM (cynes write logs, random play seed 1, 30000 frames): never written
  `$75C0-$75FF`, `$7FDF-$7FFF`; in battle also `$7800-$78DF` (the box save stack the
  English patch moved to ExRAM; no write during the opening battle). `$74C0-$74FF`,
  `$7BE3-$7BFF`, `$627C-$627F` are written (not free). Banks 23-30 are empty.

## Treasure screen (owner approved the mock-up `ff2_mock7_treasure.png`, 2026-11-19)
- Stacked full-width windows: treasure (GB rows 0-6: ".. Treasure ..", Drop, Done on line 1;
  the 8 treasure slots in two columns on lines 2-5) and inventory (rows 6-17, sharing the
  border: two columns, 10 of the 16 rows, scrolling).
- 64-px columns (text at GB x 8 / 88, hands at x -8 / 72); longer names in narrow letters
  with fewer letter gaps (widest: Diamond Breastplate, ?Sword of the Earth).
- Up / down move through both windows, left / right between the columns.

## Field keyword menus (owner approved `ff2_mock8_keywords.png`, 2026-11-19)
- Dialogue box stays on GB rows 0-7, the party visible on rows 8-9; menus in rows 10-17:
  Ask / Learn / Items (0,10,8,5), hand at the screen edge; keyword / item list a
  full-width window (0,10,20,8) over it, one column from column 1, 6 rows, scrolling;
  Yes / No (12,10,8,4).
- Item names longer than 18 columns (Sulfuric Acid Bottle, Diamond Breastplate, icon +
  Sword of the Earth): owner chose condensed letters on tiles of their own (wording
  unchanged).
