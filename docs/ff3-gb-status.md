# FF3 Game Boy Color port: status

Brief: `docs/ff3-gb-brief.md`. Target: Game Boy Color only (header CGB flag `$C0`, MBC5 + battery
SRAM), a "Game Boy Color only" screen on DMG / Pocket / Super Game Boy, 0 lag frames, every Lot
Check standard. Code will go in `tools/gb3n/`, docs in `docs/ff3-gb-*.md`.

## Done (2026-11-26)
- ROM checked: `roms/Final Fantasy III (Japan).nes`, SHA-1 `c4443fc24625e3c2bb859525eb44b6b3a80e7c35`
  (matches `README.md`; `roms/` is git-ignored).
- English FF3 NES ROM built with the existing tools:
  `python3 tools/ff3_mmc5/build.py "roms/Final Fantasy III (Japan).nes" build/ff3_mmc5.nes`, then
  `python3 tools/ff3/insert.py build/ff3_mmc5.nes build/ff3_en.nes`. Result SHA-1
  `4a7f1ae4c89305cf161aa3d78fd4416548663f99` = the expected result in `patches/README.md`.
- everything8215/ff3 cloned into `build/ref/ff3` (git-ignored, never committed). What it is:
  an **annotated listing** (`ff3j.asm`: `BB/AAAA: bytes  MNEMONIC ; comment`, 1623 named
  routines), not assembler source, plus `rom-map.txt`, `field-ram.txt`, `battle-ram.txt`,
  event and text dumps. Its bytes match the Japanese ROM: 47,593 listing lines identical, 10
  differences (comment / data-word lines the check misparses). Coverage: 106 KB of code in 8 KB
  banks $10, $1F, $2E-$36, $3A-$3F.
- Facts for the owner's decisions:
  - FF3's field buttons (bank $3E $C1F6-$C2B7): **Start opens the main menu** (Item / Magic /
    Equip / Status / Order / Job / Save; Save only on the world map), **Select shows the next
    living party member as the walking sprite** ($F72C), B makes the Invincible take off, A
    talks / acts. The world map is shown only by the Sight spell and Dwarf Bread ($A525).

## Owner's decisions (2026-11-26)
1. Base: **native rewrite** (as FF1).
2. Select menu: **in the Start menu** (Config and Suspend added; FF3's Order = Formation; Select on
   the map keeps showing the next member).
3. Conveniences: **all four groups** (text / screens, battle, menus / Config / saves, extras). FF3
   already has some: judge each in battle against FF3's own, keep FF3's where better, adapt ours
   to FF3's style where equal or ours has the edge (`docs/ff3-gb-battle-compare.md`).

## Battle comparison (2026-11-26)
`docs/ff3-gb-battle-compare.md`: FF3's own numbers, flash, step-forward, auto-retarget, spell names,
deaths and speed setting stay; ours (adapted, FF3 wording) for the hit label, critical label, cursor
memory, hold-A, enemy counts, low-HP colours, results window. Checked on the NES English build
(cynes, one Altar Cave round) and in the listing; spells / healing / targeting / transition still
to be seen on screen. NES driver for tests: scratch (New Game, names typed by RAM state; FF3 needs
6 letters + A and rejects duplicate names).

## First bootable ROM (2026-11-27)
- Owner chose screen **B** for older systems (title above a framed window, white on black).
- `tools/gb3n/build.py` -> `build/ff3n.gbc` (2 MB MBC5 + battery, 32 KB cart RAM, header CGB $C0,
  SGB flag 0); `tools/gb3n/src/main.s` (boot: work RAM / high RAM / VRAM / OAM cleared, the LCD off
  only in V-Blank, double speed, frame wait with the check and halt race-free, pad with opposite
  directions cancelled, soft reset A+B+Select+Start); `tools/gb3n/tiles.py` (our font and frame
  tiles, the screens; no game data). Color / GBA: a placeholder screen (to be replaced by the
  title). DMG / Pocket / SGB: the notice, with DMG registers only.
- Checked in SameBoy (`build/sbsh`, core built with `tools/gb/sameboy/sameboy-ffe.patch`,
  `SB_LCHK=1`), 710 frames with a soft-reset press, on Game Boy Color, Game Boy, Game Boy Pocket,
  Super Game Boy, Game Boy Advance: strict checker 0, VRAM / OAM checker 0, pictures as expected
  (the SGB shows the notice in its own default palette, as for any Color-only Game Pak).
- Test harness rebuild notes (this session): SameBoy at ea667ad + the patch; RGBDS v0.9.1; the
  `hexdump` stand-in must take the file as its last argument; `sbsh` built with
  `-I<SameBoy>/libretro` when libretro-common is not installed.

## One map on screen (2026-11-27)
- `tools/gb3n/data.py`: FF3's map readers from the listing: map properties (02/A000, 16 bytes per
  map: tileset, start x / y, fill metatile, palettes, song, exits, treasures, triggers), tilesets
  (01/A380: 128 metatiles as UL / UR / DL / DR pages; 01/B180 palette per metatile; 01/B500 tile
  properties, 2 bytes), the RLE tilemap (pointers 11/8000, $3E $CBFA: 32 x 32 metatiles), the BG
  graphics (subset 00/8C00 -> 8 blocks of 26/8/8/14/8/16/16/16 tiles from bank 3+, the count table
  read from the ROM's code at $3E $DF00; menu / text tiles 0D/B700 at $70-$FF), palettes (00/9100,
  9200, 9300 by properties bytes 5-7; palette 3 the window). `python3 tools/gb3n/data.py
  build/ff3_en.nes OUTDIR P..` renders maps to PNG: maps 0-11 look right (rooms, Ur = map 10).
- `src/field.s`: one map's data bank (built from the ROM: GB tiles, metatile pages, CGB palettes,
  the unpacked map) drawn into the 32 x 32 BG ring around the start position (fill metatile
  outside the map), palettes per metatile in VRAM bank 1. `build.py --map P` (default 10, Ur).
- Checked: SameBoy Color picture = the Python render of the ROM's map at the same camera (map rows:
  max difference 4 RGB levels, RGB555 rounding); strict checker 0, VRAM / OAM checker 0 on all five
  systems.

## Walking, maps, entrances (2026-11-27)
- Walking on normal maps with FF3's rules ($3F $E396: property 1 bit 7 trigger by property 2's
  high nibble; low bits stairs / bridge / impassable / z-levels 1-2 with the walked level),
  16-frame steps, rows / columns written into the BG ring in V-Blank, the walking character's
  poses ($3E $DC2A), palettes and bob.
- Any map loaded at run time as FF3's load map does: properties, tileset pages into work RAM,
  the RLE tilemap unpacked (streams repacked into ROM banks 8-11 at build time), trigger tiles
  -> metatiles $80-$FF with their ids in property 2, palettes, graphics subsets (banks 12-16).
- Entrances (the map's entrance list), FF3's start position and facing on entry, the return
  stack, exits to the previous map. Checked in SameBoy: Ur -> a house -> back to Ur on the door
  cell, strict checker 0. World map exits: not yet (no world map).
- Known: a map change turns the LCD off (white on a real Color); to be replaced by FF3's wipe
  / a black mask as FF1 did.

## People, text, talking, events (2026-11-27)
- FF3's save page ($6000-$63FF) in work RAM bank 1 ($D000), set up as FF3's init sram does.
- People: FF3's npc lists (12 slots), switches, graphics (three sources by graphics id), poses,
  walking in place, steps with the destination claimed at once; at most 9 drawn.
- Text: the English tables (script/ff3/*.json) encoded at build time for our font (VRAM bank 1,
  BG in $8800 mode), wrapped to 18 columns, pages of 6 lines. Dialogue box = FF3's top window
  (mock-up A) in the GB window layer, cut at line 64, FF3's frame tiles, typewriter text.
- Talking (A on a person): FF3's conditional scripts and event runner (person / party
  commands, switches, items, dialogue, entrances / exits, waits, repeat). Checked: the child in
  Ur ("Gyah!!", then the event moves people / the party). Strict checker 0.
- Field code in its own ROM bank (B_FIELD = 29); data banks read through far_copy / far_byte
  (bank 0 down to 3.6 KB). Lesson: anything copied to HRAM at boot (the OAM DMA routine) must
  live in bank 0.

## New Game opening (2026-11-27)
- The build starts as FF3's New Game does: map 0 of world 0 at its start position ($3E $C0E6);
  the event trigger under the party runs at once ($3F $E87B / $E6C6: 2C/8880 trigger scripts
  after FF3's vehicle / status switches); events go on across map changes (FF3 never clears
  $6C on a load); event dialogue ($F1) reads the story table 18/8000, person dialogue ($F0)
  18/8400 or 18/8600 by world. Checked against the NES picture: the fall through map 0, the
  cave (map 181), "Ow ow ow..." / "We fell down a pit!" / "Now we're in a fix...", the party's
  moves, the next lines. Strict checker 0.

## Mock-ups sent to the owner (2026-11-27; `tools/gb3n/mockup.py`, PNGs in `build/mock3/`)
- `dialogue.png`: A box at the top, B at the bottom (FF3 itself has a top and a bottom window;
  proposal: use FF3's own choice of top / bottom), 18 columns x 6 lines.
- `battle.png`: A command window over the party window, no backdrop; B the attack with FF3's
  backdrop strip and a top window (attacker > target, hits); C a full-width message.
- `menu.png`: Start menu with Config and Suspend added, party with pictures, Gil / CP / place /
  time. `names.png`: name entry, one case at a time (Select switches), as FF1.
Building continues on what does not depend on them (people, events, chests, world map).

## Next (after the decisions)
- Map the listing's routine names onto the ROM (as `tools/gb/ff1dis.py` did for FF1).
- Walking on the map: the party's walking sprite (FF3's showing character, Select = next member),
  scrolling the BG ring with rows / columns in V-Blank, collision from the tile properties; then
  map changes (entrances / exits), people, text.
