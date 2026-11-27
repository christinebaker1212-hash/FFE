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

## Chests, transitions, world maps (2026-11-27)
- Chests and other treasures ($3F $E917 / $F549: contents 01/9C00 / 9D00, arrows x20, gil maps
  with item prices, treasure switches, the open chest $7D), locked doors (the Thief), item names
  and amounts inserted in messages.
- Map changes with the LCD on: black palettes, the load behind a mode-2 STAT guard, palettes
  applied in V-Blank (no white frames on a real Color). A house entry takes ~19 black frames:
  to compare with the NES's own load time and shorten.
- World maps: the four 256 x 256 maps unpacked at build time (banks 32-47), tilesets / palettes /
  256 BG tiles per world pair; walking (on-foot rule: property 1 bit 0), world triggers (events
  by script id, entrances through 00/8800 / 00/8840), back to the world where the party stood,
  exits through the exit tables (00/8880 / 00/88C0). Checked: the Floating Continent, an
  entrance into map 78 and back out. The dialogue box has its own palette (7) and FF3's frame
  tiles in VRAM bank 1, so it works over both map kinds.
- Build checks: RAM sections may not overlap (found and fixed three); GB3N_GAPS=bank lists free
  space.

## Sound (2026-11-27)
- FF3's sound driver written natively (`tools/gb3n/src/sound.s`, bank 0): channel scripts, all
  commands, repeats / voltas, volume envelopes (attack / decay / release), pitch envelopes, tempo,
  fades, song banks, sound effects on pulse 2 / noise. Its state keeps FF3's `$7F40` layout (work
  RAM bank 1 `$DD00`). Song data: GB banks 50-53 (NES bank $36 + the song bank).
- Checked against FF3's own 6502 driver run in py65 (scratch harness: both start from the same
  state, the 192-byte page compared every frame): songs $01 $02 $05 $10 $15 $1E $22 $2B $30 $37
  $3A $3C $40 (600-900 frames each) and sound effects $00 $01 $04 $10 $25 $28 $3F over a song:
  0 frames differ. Two faults found by it and fixed (a channel's end keeps its volume; a sound
  effect's start mutes the old one and clears the tick counters).
- Output stage: pulses -> CH1 / CH2 (duty, volume restarts the note), triangle -> CH3 (a 32-step
  triangle wave), noise -> CH4 (NR43 nearest to the NES period). Recorded audio: the pitches are
  FF3's (522 / 293 / 585 Hz pulses, 130 Hz triangle).
- Songs: each map's (properties byte 10; bit 7 the conditional script $38 + n at 2C/8870), the
  world maps' by world and vehicle (3B/A027), event command $F8 (songs, fade, resume, stop, sound
  effects). The driver runs after each frame's V-Blank work, and from the V-Blank interrupt while
  a map loads (an HRAM `mapbank` lets the interrupt map back the bank in use).
- Later: the timer at the NES's 60.0988 Hz, volume changes without restarts (FF1's way).

## Battle algorithms (2026-11-27)
- FF3's battle algorithms written natively (`src/batcore.s`, `batmagic.s`, `batinit.s`, `batequip.s`):
  character / monster setup ($31 $A400, monster stats, special attack scripts), the equipment update
  ($AA16: hit / attack / evade / defence / magic values from job, stats and equipment), monster
  action choice ($A732: run, special attacks, boss scripts in order, targets), the fight effect
  ($9E8A: hits, two hands, back row, criticals, elements, defending, jump / buildup, drain, status),
  magic and item effects ($AF77 / $A65E: all 49 attack effects, reflect, m.evade, elements,
  absorb, split / summon / self-destruct / barrier shift / Odin / Bahamut, kill, life, toad /
  mini), inventory consolidation, confusion, random targets; FF3's battle random number
  generator and its helpers (multiply, divide, bit masks).
- Memory as FF3's: its zero page in `BZ` ($C400) and its $6000-$63FF / $7400-$7FFF in work RAM
  bank 2 (low 12 bits kept), so the code reads like the listing and can be compared byte for byte.
- `tools/gb3n/test/batdiff.py` runs FF3's own 6502 code (py65, the user's ROM) and ours (SameBoy,
  a GB3N_TEST=1 build) on the same random battle states and compares all battle RAM: 0 differences
  over 150-300 states per routine. Three FF3 quirks found by it and kept: an empty first monster
  slot loads a monster record into ROM ($A45A's LDX sets Z); a monster petrified by status is also
  marked dead ($BDF4 tests INY's flags); the run-penalty undo subtracts with FF3's leftover carry.
- Next: the battle flow (bank $34/$35: turn order, commands, actions, messages, victory) and the
  battle screen (layout from the mock-up sheet), random encounters.

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
