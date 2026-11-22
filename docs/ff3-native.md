# FF3 for the Game Boy Color: the native engine

Owner (2026-11-22): **"Using the lessons learned from Final Fantasy I GB's branch, continue native
translation of FF3 until 100% native code is achieved."** As for FF1 (branch
`claude/compassionate-bell-bo3yq2`, `docs/ff1-native.md`): FF3's engine is written by hand as
native Game Boy Color code from what the disassembly (everything8215/ff3; the annotated source
`build/ff3/src_gb`, generated from the listing and the user's ROM, never committed) says each
routine does. Only *data* comes from the user's ROM at build time. The recompiled build
(`tools/gb3`) stays available until the native one reaches parity.

## Rules
- Nothing game-specific in the repo: every byte (maps, tiles, palettes, text, stats, scripts,
  songs) is read from the user's ROM when the build runs (`tools/gb3n/data.py`).
- Game rules exactly as on the Famicom (formulas, RNG use, encounter rates, AI, events).
- Screens as already approved for the recompiled build (`docs/ff3-gb-status.md`), the owner's
  standing requests built in from the start: Select menu (Options / Suspend; B + Select changes
  the walking member), suspend points, menus shown complete with fades (no half-drawn windows,
  no white flashes), condensed names in lists, dialogue paged at sentence / speaker boundaries
  with natural line breaks, music checked against the owner's NSF (never committed).
- Lot Check designed in (`docs/gb-release-checklist.md`): Color only with the warning screen,
  LCD off only in V-Blank, VRAM / OAM in their windows, cart RAM only around save accesses,
  soft reset, memory cleared at boot.
- 0 lag frames: one engine frame per GB frame, the picture written natively.

## Verification
- Data decoders checked against the NES (cynes) RAM / CHR of the same scene
  (`/tmp` scripts in the session; the checks will move into `tools/gb3n/check.py`).
- State checks: the NES and the native build with the same inputs, FF3's game state block
  ($6000-$7FFF layout kept where the save and the checks need it) compared at checkpoints.
- Pictures: SameBoy / mGBA screenshots of every screen; lag: Gambatte lagcheck.

## Milestones
1. Boot, a normal map from the ROM's data, the party walking (passability), camera, sprites.
2. All maps loaded at run time, the world maps, triggers (exits, doors, stairs, treasure),
   NPC objects, the event script interpreter, dialogue.
3. Menus (main, items, magic, equipment, status, jobs, order, save, Select menu / suspend /
   options), shops, inns.
4. Title, prophecy, new game (names), the story scenes and cutscenes.
5. Battle (formations, the approved layout, commands, jobs, magic, summons, items, AI,
   animations, rewards, capacity, levels).
6. Vehicles (Nautilus, Invincible, chocobos, ...), music and sound effects, the ending.
7. Parity checks over the whole game, Lot Check pass, release.

## Data (FF3 formats, as decoded in data.py)
- Map properties: 16 bytes, 02/A000 + 16 id (02/B000 for the second set): byte 0 bits 5-7
  tileset, bits 0-4 start x; byte 1 bits 0-4 start y (bit 5 gil chests 16-31, bits 6-7 water
  animations); byte 2 title; byte 3 fill metatile (outside 0-31); bytes 5-9 palettes (general
  palettes 00/9100, /9200, /9300: BG 0-2, OBJ 2-3); byte 10 song; byte 14 treasure set.
- Layout: id 00/8A00 (00/8B00 from world 2), pointer 11/8000 + 2 id (page low 5 bits | $80,
  bank $11 + top 3 bits), RLE (bit 7: value, then count) into 32 x 32 metatiles.
- Tileset (8): 01/A380 + $200 ts: TL, TR, BL, BR tile ids (128 each); 01/B180 + $80 ts:
  palette per metatile; 01/B500 + $100 ts: 2 property bytes per metatile; metatiles $80-$FF =
  copies through 3A/93C1 (triggers).
- Properties byte 1: bit 7 trigger (byte 2 high nibble = trigger type, fix:E669 table), bit 6
  random battles, bits 0-2: 0 stairs, 1 / 2 floor level, 3 impassable, 4-7 bridge.
- BG tiles: subset id 00/8C00 (00/8D00 from world 2); 00/8E00 + 16 id: 8 block pointers
  (bank 3 + top 3 bits), block lengths fix:DF00; menu window / font 0D/B700 (144 tiles at $70).
- Map character: 0E/8000 + $100 job (16 tiles); its colours 00/9690 + 4 job.

## Progress
- 2026-11-22: milestone 1: `tools/gb3n/data.py` (map properties, layout, tileset, palettes,
  BG / character tiles; checked against the NES RAM and CHR of map 181: layout, metatiles,
  attributes, properties, palettes and tiles identical apart from FF3's run-time trigger ids
  and water frames), `tools/gb3n/src/main.s` (boot on a Color with double speed and cleared
  memory, the map drawn into a 16 x 16 metatile BG ring, d-pad walking one metatile in 16
  frames with FF3's passability rule, the entering line queued and written in V-Blank, the
  character sprite), `tools/gb3n/build.py` (`build/ff3n.gbc`; `--map ID --world W`).
  Then: walking frames and facing from fix:DC1A / DC2A (attributes converted to CGB OAM).
- 2026-11-22: milestone 2 started: every map packed at build time (`build.py pack`: 3 map
  groups x 256 ids = 768 entries of 64 bytes: layout / tile set banks, tileset, start, fill,
  title, song, flags, the 32 NES colours; 244 distinct layouts 16 a bank, 59 BG tile sets 4 a
  bank, the 8 tilesets, the walking characters; 1 MB ROM). `load_map` (cur_grp / cur_map)
  copies the entry, layout and tileset tables into WRAM bank 1 (FF3 rewrites trigger tiles at
  run time), the tiles into VRAM and the palettes through NES_RGB. Checked: maps 1, 6, 12, 20,
  40, 60, 100, 181 (castles, towns, shrine, field, crystal hall, cave).
  ROM banks: 8 tilesets, 9-11 map entries (group 0: world 0 / props 02/A000, group 1: world 1 /
  props 02/B000, group 2: worlds 2+ / tables 00/8B00, 00/8D00), 12-27 layouts, 28-43 BG tiles,
  44 characters + frames.
- 2026-11-22: triggers: ids given at load as 3A L3A_91C8 (tiles $60-$63 / $70-$7C, per tile
  and per type counters, TRIG_T / TRIG_O from 3A/921F / 923F); fix:E669 types: 0 exit to the
  previous map, 1 exit to the world, 4 entrance, 5 door (shown open, metatile $7E), 6 locked door
  (the unlock flag comes with events), C-E impassable, F event (scripts later). A map stack
  (group, map, x, y; 16 levels) as FF3's nested `map main` calls ($29 / $2A / $48 pushed).
  Map loads during play keep the LCD on (FF1 lesson): palettes black in V-Blank, tiles by
  general-purpose DMA 64 blocks a V-Blank, the view through the queue two rows a frame, then the
  palettes. Checked: town house door in and out (map 6 -> 7 -> 6).
- 2026-11-22: world maps: tilemaps decoded at build time (06/9000.. row pointers + RLE, fix:CCBB /
  CC47) into ROM banks 48-63 (worlds 0 / 1 share one), world tilesets (L3A_8F43: common
  metatiles 0-63 + the world's 64-127, attributes, properties), tiles (FDDC6: 0A/8C00 + 0A/9400 +
  $400 (w & 6)), palettes (L3A_9091), entrance destinations (00/8800, 00/8840). Groups 3-7 =
  world 0-4 (`build.py --group 3 [--x --y]`); coordinates wrap at 256 on a world map. On foot:
  impassable when property 1 bit 0 is set (fix:C65D mask 1); entrances (property 1 bit 7,
  property 2 bit 7 clear) enter map 00/8800 + id of the world's map set, the world position
  pushed. Checked (PyBoy state + pictures): world 0 walking, castle entrance -> map 78 ->
  exit -> back on the world map at the entrance.
- 2026-11-22: NPCs (`src/npc.s`): object blocks in FF3's layout ($7000 / $7100 -> N_OBJ / N_OB2),
  lists from 2C/8000 (map properties byte 4), npc switches (save block $6080, new-game values
  00/B600), speeds (01/9E00 / 9F00), graphics ids (00/9400 / 9500) and the three graphics
  formats of FDF41 (converted at build time), the animation frames (3B/B41A), FF3's random
  movement (one npc a frame, fix:FE00 random table), npc passability (L3B_B110 / B0C5: party
  destination, tile, z-level, other npcs), frame selection by movement type, priority halves,
  the party blocked by npcs (fix:E3F1, marks them touched). Sprites 3 pixels up as FF3 (party
  too). Checked against the NES (map 6 entered through a poked entrance trigger: elder and
  the two flower pots; NPC graphics slots of map 181 identical to the NES CHR RAM).
- 2026-11-22: dialogue (`text.py`, `src/text.s`): every string of the four dialogue tables read
  from the English ROM, the NES layout (26 columns) undone into paragraphs, laid out again for
  the GB box (owner's request: pleasant pages): 18 columns, 4 lines a page, paragraphs balanced
  (fewest lines, least ragged), whole paragraphs / sentences per page, a sentence longer than a
  page split at a clause; the box in the window layer at the top (20 x 6), cut at line 48 by an
  LYC interrupt, tiles above sprites; a page turns on any button (fix:ECAB).
  Events (`src/event.s`): A in front of a person (fix:EA26 / E494; it turns to the party), its
  script (2C/8200 / 8400: conditional blocks on the event switches, dialogue ids -> $0740),
  the event script (2C/8600; banks 2C / 2D copied whole), one command a frame while the party
  stands (fix:D219, $FE repeat of the previous command): npc commands (move / face / show / hide
  / animation), party moves / facing, dialogue ($F0 / $F1), event and npc switches, items
  ($E7 / $F6, "Can't carry anymore."), gil, HP / MP restore, exits / entrances, waits, end.
  Checked: map 6, the elder Dahn's two pages.
- 2026-11-22: treasures and trigger events: per-map treasure / trigger lists (10/A000 / A200 by
  map properties bytes 14 / 15), chests opened at load by the treasure switches ($6040, all on
  at a new game), A on a chest / hidden treasure (fix:E917 / F549: contents 01/9C00 / 9D00,
  arrows x20, inventory 3C/937E, gil chests by item price 10/9E00, switch toggled, the chest
  redrawn open, messages $0101 / $0102 / $0150 / $0159 / $0176), locked doors (Thief: unlocked
  flag $6021, $017A, else $0103), type-F trigger tiles (2C/8880 scripts, 3C/9274 switch update,
  then the tile's own passability), map titles (byte 2, t8200) when a map comes up; dialogue
  codes {02} / {18} item names (icons and leading blanks dropped), {03} price, {05} gil.
  Checked: map 181 chest (Potion), the cave's trigger scene.
- 2026-11-22: new game state computed at build time as 3A L3A_8E76 (GAME_BANK $5400). Field
  main menu (`menu.py`, `src/menu.s`), owner's mock N5B / N6: party window (name + Lv, job name
  condensed from the ROM's names, HP cur/max in the status colour of 3C/95D7: green / orange /
  pink, MP of the 8 levels in 3-px digits with slashes), commands (t8200 $0131), Gil / Capacity
  in small digits, guest window; FF3's hand (fix:D5EB, tiles $E4). It is the window layer over
  the whole screen with the menu palettes (fix:E1BC) in CGB palettes 4-7: the field's BG map,
  tiles and palettes 0-3 are never touched, so opening / closing is one frame with no white
  flash and no palette change on exit (the owner's three recompiled-build complaints). The
  stack moved to WRAM 0 (the menu canvas is in WRAM bank 2).
- 2026-11-22: the walking character from $600E (graphics: toad / mini / job, fix:DD2D; colours
  3A/9050 incl. the Onion Knights' per-slot colours); B + Select = fix:F72C (next living member);
  Select menu (owner's decision): Options (Battle Speed = FF3's message speed 1-8, Music / Sound
  Volume 0-7) and Suspend ("Create a Suspend Point and return to the Title?" Yes / No: the save
  block, the place and the map stack to cart RAM bank 1 with the RAM enabled only around the
  copy, then a restart). The boxes are the window layer at the top cut by LYC at the box's
  height (the field and the party stay visible below). Module code now placed one after the
  other in bank 0 by build.py (`engine_src`), RAM sections after.
- 2026-11-22: character select (3D/A6B4), Status (mock S5: labels from t8200 $0147, condensed
  where the mock has them, values as 3C/8998: level / job level + 1, EXP, to next level from
  39/80B0, HP / MP, the 5 stats $6117-$611B, attack $6123 + $6128 with multiplier $6121 + $6126,
  hit % (3C/89DE), defense $612D x $612B, evasion $612C, magic defense $611F, magic evasion
  $611E; toad / mini 1), Order (3D/A696: battle row $620F toggled). Found: general-purpose
  DMA ignores the low 4 bits of the source address (tile data must be 16-aligned).
  Next: NPC objects, the event script interpreter and dialogue (text decoder, window, the
  owner's pleasant paging), random battles hook, vehicles later.
