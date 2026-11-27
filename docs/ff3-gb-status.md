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
- Battle flow, part 1 (`src/batflow.s`, bank 58): the attack order ($9777, with FF3's own
  recursive sort, which decides ties), executing an action ($9DE4: status checks, targets, mp,
  summons as their own attacker at $7875) and every action: fight (a Knight covering a weak ally,
  waking sleepers, arrows / shuriken used up), magic, items, sleep / paralysis, rows, defend,
  run / escape, jump, terrain (backfire), scan, peep, steal, buildup, sing, scare, cheer; the
  battle-over check and the cannon blast. Shared helpers moved to bank 0 (`src/batlib.s`); the
  algorithms are called through a bank-0 dispatcher, as FF3's $FDF3. Checked: attack order 60
  states, execute action 300 states, battle over / cannon 40: 0 differences. FF3 quirks kept:
  Scan's weak-element loop shifts its counter after the first find and writes every message to
  one queue slot; Scare sets every monster's level to the first one's - 3.
- Battle flow, part 2 (`src/batvict.s`, `src/batloop.s`): poison, victory (experience shared by
  the living, gil, capacity, drops, job experience by command use, job levels, level ups with hp /
  stat / mp bonuses), the status for display, and the main loop's bookkeeping (turn and action
  starts, command-use counts, monster rows, first strike / ambush / back attack, near-fatal,
  defence back, used items returned, the end-of-battle write-back, battle init). Checked with
  batdiff (50-150 states each): 0 differences. FF3 quirks kept: a dropped item whose stack is at
  99 goes on looking for a zero from the count's place; experience is capped by testing 9,999,999
  but storing 10,000,767.
- Battle setup (`src/batsetup.s`): the monster set and ids, counts randomized, the formation
  tilemap, slot types, counts per type, the battle random table (FF3's generator; the seed on the
  GB is our own sum, as FF3's is its zero page's), and the after-action magic message. Checked: 0
  differences over 100 states each.
- First playable battles (2026-11-27): random encounters on maps and world maps (FF3's rates,
  groups, chances and field random table), the battle driver in FF3's main-loop order, the screen
  (`src/batscr.s`, `src/batui.s`): monsters from FF3's formation positions (columns 0-17, rows
  0-11), the party's battle sprites at the right edge, the party window, FF3's four commands per
  job (row change with left / right twice), target choice, magic and item lists (FF3's job check,
  target rules), FF3's action scripts shown in a top window (attacker, attack / hits / Miss,
  target, status) and a bottom message window (the message queue with its variables), damage
  numbers as sprites, monster deaths with FF3's experience credit, victory messages, back to the
  map. Checked in SameBoy: battles fought to defeat (soft restart) and to victory, strict checker
  and VRAM checker 0.
- Bosses from FF3's tilemaps (2A/8000; graphics pointer decoded as 2F/A3BB, summons flipped),
  monster / boss palettes from FF3's attribute data (2F/A857, a bit per 16 x 16 block), the party's
  palettes by job (2E/9E01), event battles ($F7), the battle id's high byte from the world (2E/9E8E).
- Battle to do: attack / spell animations, the layout per the owner's mock-up choice, monster
  chests (done since: see below).

## Menus, saves, title (2026-11-27; `src/menu.s`, bank B_MENU = 76)
- Start on the map: the main menu (FF3's commands from its text $31 + Config / Suspend): commands
  and Gil / CP on the left, the party (job pictures, Lv or ailment as FF3's 3F/F299, HP) on the
  right. Full-screen shadow copied by general DMA in one V-Blank; the map reloads after, the
  people kept where they were (`npc_keep`, also after battles).
- Order (FF3's row toggle), Status (FF3's values after its equipment update, 34/803D, run in the
  battle banks with the save page in work RAM bank 2).
- Save (world map only, as FF3): FF3's three files, its checksum (3D/AE5C) and save count; the
  title (FF3's game load menu 3D/B9F6): files 1-3 and New Game. Cart RAM is enabled only around
  each access; each file has our own check (magic + 16-bit sum) besides FF3's; a bad file shows
  "Damaged". Checked: save, soft reset, load from the title.
- New Game: the four names (FF3's 3D/B895 flow; our 9 x 5 grid, SELECT switches case).
- Item (FF3's choose-twice: use / swap / trash; its item effects and healing formula 3D/A48A;
  spells taught from items with FF3's three places a level), Magic (FF3's field spells 3C/99FF:
  Cure family with the caster's multiplier, Raise / Arise, status cures, Toad / Minimum toggles,
  one or all, MP per level; a spell back into the pack), Equip (FF3's slot rules 3C/9C3C, hand
  pairs 3C/9D4B, arrows up to 20, remove / remove all, the job check from 30/9400 and 00/8900),
  Job (jobs by crystals 3F/F38A, CP cost 3D/AD85, checks 3D/AE23, change 3D/AB8F with the new
  job's level-ups from bank 39), Config (FF3's message speed $6010; the battle message wait uses
  it as 34/9450), Suspend (cart RAM bank 1 with its own check, resumed once from the title).
- Owner (2026-11-27): main menu flipped: the party on the left, commands and Gil / CP on the right.
- Inns ($E0-$E2: 5 x the living x the script's rate, FF3's texts, HP to max for the living, the
  script's rest event after) and shops ($E3-$FB: Buy with 1 / 4 / 10 and FF3's discounts 3D/B281,
  Sell 1 / All at half, key items and Toad / Minimum not sold, FF3's carry check) as full-screen
  windows; the map comes back with its people where they were. Fat Chocobo: later.
- Event commands added: $D0 / $D1 sounds, $D4 / $D5 HP / MP to max, $D6 / $D7 passages, $D8
  reset, $D9 the ship chained, $DE the surface world, $DF, $E8 / $E9 status, $EA-$ED gil / CP
  (too little: the event ends with FF3's story text 2 / 3), $EE guest. Still stubs: $D2 / $D3
  palette darkening, $DA dance, $DB / $DC prologue / epilogue, $DD ending, $E0-$E2, $EF.
- Lesson: menu variables live in the map's tables ($C800-$CEFF): read results before the map is
  reloaded, and initialise flags (m_pal) on entry.
- Vehicles (`src/vehicle.s`): FF3's per-vehicle passability masks (3E/C6CD), boarding the canoe
  on rivers and the ship by walking into it, leaving them onto land (the ship parked there),
  A: the Enterprise taking off, boarding / landing the airships (landing flags 3E/C851; the
  Enterprise lands as the ship), the chocobo leaving; the party drawn as its vehicle (3E/DCAA,
  tiles from NES 0B at OBJ $20), the parked vehicle (3E/DAD4..), world songs and encounter
  rates / groups per vehicle, no entrances from vehicles. Saves keep FF3's $6009 format (the
  party's tile - 7) and the vehicle ($600F). Checked: boarding, sailing, landing the ship.
  Not yet: the airship's shadow and lift-off / landing animations, the Invincible, the
  Nautilus diving, chocobo forests, the airship's double speed.
- Worlds: airships off the Floating Continent's edge (tile $64) to world 2 / 3 and back at
  (32, 224); the Nautilus diving ($1E sea, $6020 bit 7) and surfacing; the Invincible entered
  with A / B (FF3's entrance 0); party event commands $CA / $CB / $CE / $CF set vehicles.
- Exit spell and Otter's Head: out to the world map where the party went in.
- Select on the map (owner's decision: FF3's own): the next member shows (3F/F72C), with FF3's
  walking graphics (job, toad $16, mini $17) and palettes (3A/9050) - these were always job 0
  before.
- The opening crawl at power-on (FF3's prophecy, 3A/8726; skipped after a soft reset as FF3):
  story texts 0 / 1 on FF3's dark blue, each line fading in to white then grey, A / B the next
  page, Start on to the files; FF3's lines re-flowed for 20 columns, 8 to a screen.
- Prologue ($DB), epilogue ($DC), ending ($DD): FF3's cutscene engine (NES bank $1F) written
  natively (`src/cut.s`, `src/cutend.s`; data `tools/gb3n/cutdata.py`): the crystal flashes and
  rises, the title / staff / story pages fade in one by one; the epilogue's starfield (FF3's
  3D stars) with the pages scrolling up through it; the ending's scene (its band opening from the
  middle by line splits, the clouds, the crystal's glow, the greyscale flicker, the Invincible
  flying off, the flash), the end credits (each member walking in with the weapon, name and
  level; the guests; the staff pages revealed from both edges by a pair of job sprites) and The
  End over the stars. All text from the English ROM (bank $2D pages, 10/9640 credits), placed for
  20 x 18. The cast pages (ids 1-8) were never translated in the NES patch (Japanese bytes shown
  as Latin letters there): `script/ff3/cast.json` gives them in the translation's names.
- Hand cursor: FF3's own 16 x 16 hand (0D/B440) with its cursor palette (owner reported the
  placeholder looked mangled).
- People as FF3 (3B/AEEB-B2C6, AF97, B110, 3F/E494): wandering one at a time with FF3's
  counters and random table, animation types and speeds per person, the walkers' bob, facing the
  party when spoken to, bridge priority; event person commands $0A-$0F (jumps, walking frames on /
  off, circle, spin) and $DA (dance); screen effects $D0 (shake), $D1 / $E2 (grey flash), $D2 /
  $D3 (FF3's hue steps to blue and back), $E0 / $E1 (palettes again) (`src/evfx.s`); poison
  damage per step and damage floors (grey flicker, 1 HP) (3B/A09B, A0B1).
- World-map sprites as FF3 (3E/D85A; `src/wspr.s`, bank B_WSPR): FF3's tiles $80-$FF per world
  (3D/BDE0), parked ship / Nautilus / airship, the parked Invincible and its shadow, the boulder,
  the whirlpool, Hein's castle circling (FF3's sine table, object commands 0 / 2), the continent
  seen from below, the Leviathan's shadow, the chocobo running off, the chained ship's chain, the
  airship's shadow, the spin ($602F bit 6), the party as the Invincible; party and people drawn at
  FF3's offsets above their cells (GB = NES - 48).
- Special animations $EF 0-E (`src/sa.s`, 3B/A4FA): the Enterprise coming down, the boulder /
  airship explosion, the lights and stars closing in, Saronia's cannonballs and the airship shot
  down, the four statues and Saronia's gate (with FF3's tile swaps, also re-applied when world 3
  loads: 3A/8FD1), the Invincible rising, the flying castle's spirals, Bahamut flying to the party,
  the circling stars; each leaves FF3's game state.
- Guest (`src/guest.s`): following the party with FF3's trail and speeds, its picture and palette,
  B to talk; boarding an airship waits for it (3E/C379), it waits at the party after a canoe / ship.
- Vehicle animations (`src/wspr.s` va_*): lift-off / landing with the shadow, the Enterprise
  turning into the airship and back, the Nautilus diving / surfacing; FF3's speeds (3E/CD76:
  airship 4 on its first step, then 8); the Invincible's jump (3D/B66F, 3E/C20E, D622: up, over the
  mountains while they last, down).
- Underwater (3A/9442): the small bubbles, the big bubble, the school of fish.
- Water animation (`src/water.s`, 3A/858F, 3D/B7F9): the sea / map water strips shifting, two
  bytes a frame in FF3's order; under the sea the tiles sway. The flags come from the last map
  loaded, as on the Famicom.
- The party's priority (3E/D9A7, 3F/E900): legs behind forests, bridges from above in front.
- The Fat Chocobo (3D/B383): Deposit / Withdraw / Exit, FF3's 99 limit, key items refused, its
  messages and animated picture.
- RAM rule learnt: the stack is $CF00-$CFFF (the build refuses RAM sections there), and anything an
  interrupt reads must not live in the map tables ($C400-$CEFF).
- The minimap (Sight, the Midgard Bread: 3A/88A3; `src/mini.s`, bank B_MINI): its screen data
  made at build time by running FF3's own set-up in py65 (`tools/gb3n/minimap.py`, which also
  renders the mock-ups `build/mock3/minimap_*.png`); FF3's logo on top, the 128 x 112 picture with
  its border (the outer frame left out for 20 x 18); drawn 8 rows at a time with FF3's noise, towns
  as sprites (36 at most: the GB's 40 sprites), the flashing marker, hidden while A / a direction
  is held.
- Warp (3C/9AD0: "Go back how many?" 0-45, back through the maps entered, past the first one out),
  FF3's map flags (39/BC00: no magic, no warp for Exit / Warp / Otter's Head, no size change for
  the Maiden's Kiss / Luck Mallet). Fixed: the world map's return point was overwritten by the map's
  own position after a menu or a battle inside a map.
- Monster chests (3F/F5A1: the item, then the battle once the message closes); triggers wait for
  the dialogue box as FF3's (3F/E213).
- The magic menu's Swap (3C/96F5: Use / Swap / Item; two living members' spell lists exchanged).
- After equipping (3C/9E4B): the item's stat bonuses from FF3's properties buffer ($7400 + 8 slot
  + 6) each with its message ("Strength 5 up!" .. "Bolt power up!", t8200 $3F-$46).
- Battle presentation from FF3's animation layer (banks $2F / $32 / $33), started: the monsters'
  pre-attack flash (2F/B024: the attacker in the windows' palette every other frame, 8 frames), the
  characters drawn by FF3's pose frames (32/9111 with its frame / position tables from the ROM;
  2F/B607: standing, kneeling when weak or ailing, lying when dead, toad / mini; the graphics type
  reloaded as 2F/B651). Test hook: GB3N_STORY=bat GB3N_BATTLE=id (Start fights that battle).
- Weapon swings (`src/banim.s`, 33/A0C0): stepping forward, each hand's swings 8 frames a hit with
  FF3's arm poses (the job's animation tiles at OBJ $39), the weapon's sprite frames (32/9357, its
  8 tiles from NES 2B/B000 in bank B_ANIM, its palette as OBJ palette 3), slice / blunt / claw hits
  on the target (32/97B2, FF3's rng 0 for the random places, as on the Famicom); fists and claws
  (33/A2FB). A monster's hit on a member (33/A8B8): the hit pose, knock-back (half FF3's: the
  party column is at the screen's edge), four shakes, FF3's sounds (a critical hit's own).
- Spell casting (33/B09B): the cast pose, black magic's frames and bubbles, white magic's stars
  circling and closing in (FF3's vectors and sine table 10/9A80), the spell's palette (2E/91D0),
  graphics sets from 33/BEB2 packed into B_ANIM at build time. Test hook GB3N_ANTEST=spell
  (GB3N_ANTYPE=type, GB3N_ANTGT=char, GB3N_ANKIND=kind: every Fight shows that animation).
- The animation code is in its own bank (B_BANIM 85, `src/banim.s`); B_BSCR calls it through
  far_call wrappers (xa_*), it calls back through xb_*.
- Spells after the casting (2026-11-27): the projectile (33/B276; FF3 aims by angle tables made for
  its NES layout, here the line runs to the target's centre), the hit (33/B68D: the spell's 24 tiles
  from NES bank $15 in B_MAGIC, its frame list 06/8C00 and 6 x 6 frames 00/9708 packed in B_ANIM,
  flips, 4 frames each, Life's last 16 frames, the spell's sound 34/83A0), monsters' spells too.
  The animation types of 33/BC2B: Kill (the ring of 8 widening round the caster, then flying off),
  Quake (the party shaking or the screen shaking 64 frames: the battlefield's rows only, by SCX),
  Meteor / Cave-In (six fireballs, FF3's x scaled 5 / 8 to our field), Drain (8 sprites closing
  in), Earthquake, Glare / Mind Blast / Megaflare / Explode (the backdrop flashing in 32/804B's
  colour), the monsters' Flame / Blizzard / Thunder (bank 06's 6 x 16 grids over the party), type
  10's streaks over the party, Summon / Split's sound.
- The party into the BG while a big effect runs (`an_bgon`): FF3's frames take up to 36 sprites
  besides the party's 24 (the GB has 40); members standing on whole cells clear of windows are
  copied into BG tiles $90.. (VRAM bank 1) with BG palettes 2-5 = OBJ palettes 0-3, their sprites
  hidden; effects on members use the OBJ-behind-BG bit, so the party stays in front as in FF3's
  sprite order.
- Other actions (34/843E): Defend (33/ABF7), Cheer (A92B), Scare (A988), Build Up and its overload
  (AB27), Jump (AAB8: crouch, up and away, hidden in the air; AA15: the dragoon's falling sprite
  29/B9C0 onto the target and bouncing, then down into place), running away (33/BC89: turning one by
  one, running off right; minis and toads their own way), an ineffective cast (34/8555). The party
  drawer takes per-member frames / offsets (an_pf, an_pxo, an_pyo).
- Summons (2026-11-27, `src/bsumn.s`): the pre-animation (33/AFB0: the spinner, four sprites
  flying off), the party's colours cycling and fading (32/8CBA, 8CA7; FF3's NES colours kept in a
  shadow, converted for the Color), the summon (2A/9440's properties and maps, its tiles from NES
  0D/9800 in bank B_SUMN) coming in from the right, its attack, fading out, the party back with its
  colours cycling, the healing summons' spells on the targets after (2F/B158). FF3 draws a summon in
  up to 54 sprites: here Chocobo / Shiva / Ramuh / Odin / Leviathan / Bahamut are drawn in the
  window layer (tiles at BG $90.., BG palettes 2-4, WX / WY to the pixel; the window cut at line 95
  by the line interrupt), Ifrit and Titan (who move about) in sprites (30 at most, the rest for
  their effects). All 24 attacks: Chocobo's escape / stumble / kick (its tiles by turns, set 9 into
  the window's tiles), Mesmerize (the battlefield's lines waving: SCX per line from the STAT
  interrupt, c_split mode 3), Icy Stare / Slash (the targets' cells in a palette of their own by
  turns), Diamond Dust (40 snowflakes), Mind Blast (the monsters' palettes cycling white), Ramuh's
  bolts (spell $2A's hit), Hellfire, Inferno (Ifrit's palettes cycling, his rush with the backdrop
  flashing, flames row by row: 34/8739's rows), Clobber / Stomp (Titan's fists), Earthen Fury (the
  screen shaking), Barrier / Healing Light / Aura (flashes, then their spells), Zantetsuken (Odin
  riding off in the BG cells, the battlefield cut in 24-line bands sliding apart: c_split mode 4,
  the monsters fading; FF3's state changes: beaten types counted at $7DD3, types cleared), Demon Eye,
  Cyclone (40 of FF3's 64 tornado sprites), Tidal Wave (with the shake), Rend, Megaflare (two
  explosions, the monsters in red). Whole-screen effects use FF3's coordinates scaled 5 / 8.
  Megaflare's colour emphasis (PPU $2001) is shown as the white backdrop only. Test hooks:
  GB3N_ANKIND='$02' GB3N_ANSUM='$id x 16 + attack'.
- Reflect (33/B64F): the spell's reflection at the target (palette $B1, 33/B5BB's sprites), then its
  hit on the one it bounces onto ($7EB9). Ranged weapons (33/A0C0): bow (with arrows in the other
  hand: the left hand with the right's hits), harp, boomerang, full moon, shuriken: their poses and
  sprite frames as FF3, the projectile in a straight line to the target's centre (FF3 aims by angle
  tables made for its NES layout), the arrows / shuriken stuck round the target with each hit,
  the boomerang's hits at the target and its way back. Test hook GB3N_ANWPN (the right hand's type).
- Monsters coming and going (`src/batfx.s`): a boss's entry and death (2F/BE97 / BEA4: its graphics
  in 4-tile blocks, each written 8 frames with its rows pushed apart, even rows right and odd rows
  left, 7 down to 0 coming in, 1 up to 8 going, sound $3C every 4 blocks), the final boss's death
  (2F/BF93: the music fading out, the screen grey three times, then as the others; the message
  speed set to 8 after it, as FF3), the ordinary monsters' death and getting away (2F/BB94: FF3
  sweeps a gradient diagonally; here a diagonal edge sweeps their cells, the cells on it masked
  pixel by pixel, 37 frames, sound $31). Test hooks: GB3N_WIPETEST, GB3N_BATHI (event battles).
- Back attacks (`src/batbk.s`; FF3 keeps the normal layout and mirrors at the output: 33/B19B,
  33/AC93, 3F/F942): the battlefield's rows 0-11 written mirrored (column 19 - c, x-flip toggled;
  a reversed copy as fast as the normal one), the top window two columns right so the party's
  columns stay beside it; every cell writer through `bs_mcell` / `an_mcell`; the sprites mirrored
  before each V-Blank's OAM transfer and back after (damage digits moved as whole numbers, the
  windows' hands left). Summons (the window layer cannot be mirrored): Chocobo, Shiva, Ramuh in
  sprites (as Ifrit / Titan), Odin, Leviathan, Bahamut in mirrored BG cells, redrawn by `an_frame`
  under the guard (new place first, then the old cells it does not cover). Test hook GB3N_BACKTEST.
- The Invincible's cannon (34/807E, 34/992D, 35/A50B, action script 3 and its command $0E): the
  damage at the turn's start, "Covering fire from the cannon!", the ball on its arc and the
  explosions (32/84C9), the numbers, the deaths. Test hook GB3N_CANNON.
- Flare Wave (10/8BD5): the boss's palette cycling green 104 frames, then the wave's column
  (10/8D30 shapes, 10/8D80 sprite lists) sweeping right on its sine, then the red flash.
- Battle messages wrap at spaces over the window's rows (the English is longer than FF3's lines).
- Fixed on the way: the party's cells after a big spell were restored one per row (a diagonal of
  blank cells over the top window), Odin's cells all showed column 0 of his map, Odin's charge
  flickered, Megaflare left a white backdrop, a ranged projectile aimed up flew down, animation
  graphics sets 12-17 were never packed (the cannon's, two summon attacks', one battle animation's).
- The final boss's death as FF3 (10/8A85): three grey flashes, then 16 columns clearing their
  byte of the boss's tiles at 10/8A4C's speeds (the raster dissolve), the screen scrolled up a line
  every 16 frames and shaken by 10/8A5C, then 2F/BFB8's fade. Test hook GB3N_FDTEST (with
  GB3N_BATHI=1, battle $78).
- Stone characters: FF3 draws them in the BG from the kneeling tiles (28/8080) with BG palette 3;
  here the kneeling frame as sprites in OBJ palette 5, a copy of the windows' palette.
- Battle backdrops: none (the black battlefield of mock-up A; FF3's backdrop strip, the airship's
  among them, would come with mock-up B if the owner chooses it).

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
