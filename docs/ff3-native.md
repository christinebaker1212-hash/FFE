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
- 2026-11-22: Item menu (`src/item.s`, mocks S1 / S2): the inventory one item a row (icon from
  0D/B500 in VRAM bank 1, name, count), 13 rows scrolling; A marks, A again uses, A on another
  swaps (3C/9FA5), B unmarks / leaves; use (3D/A033): prompt from t8200 $5B + n in a top box,
  the item's row, a party window (name, HP in the status colour), the member hand; effects:
  Potion 30 / Hi-Potion 120 (3D/A4B5 power: base + base * (random / 2) / 256, x 3, one target;
  FF3's random table walk fix:C711), Elixir (HP / MP to max), Phoenix Down, the status cures
  (stone, toad, silence, blind, poison), Luck Mallet (mini toggled); a member the item does
  nothing for asks again (as 3D/A13C). Text decoder: t_open shared, a canvas target for menu
  messages. Later in this menu: the trash can, Midgard Bread, the Otter's Head, spell items.
- 2026-11-22: Magic menu (`src/magic.s`, mock S3): name + Use / Swap / Item (words from t8200
  $36), 3 levels a page ("Lv n  MP cur/max", 3 slots: the $6207 bit masks laid out as 3D/A2B4,
  written back as 3D/A1C9); Use: the class check (per-item job masks precomputed from 30/9400
  class bytes and 00/8900, 35/B8FD), MP of the level, the caster's status, then the field
  spells of 3C/9971 (Cure 42 / Cura 125 / Curaga 180 / Curaja 220 or full on one, Life, Life2,
  Heal, Soft, Blindna, Poisona, Toad, Mini) on one member or all (left / right; the healing
  multiplier job level / 32 + level / 16 + spirit / 16 + 1, divided by the living targets:
  3D/A466 / 3C/9B7A), MP - 1; Swap (3C/96F5); Item (3C/9897, $016B / $016E). Later: Exit /
  Warp / Sight.
- 2026-11-22: FF3's equipment recalculation 31/AA16 (battle algorithm $05) written natively
  (`src/equip.s` eq_calc: hand types, weapon type, element-boost bits (FF3's bug kept: cleared at
  31/AF16), the 5 items' properties 30/9400, stat bonuses +5, mod. stats capped 99, hit
  multiplier / %, Monk / Karateka unarmed attack, bow + arrow, dual wield, shields, absorbed /
  weak elements, evade multiplier / %, defense, status resistance, magic evasion / defense ->
  $611C-$612F; FF3's zero page as HRAM Z_xx, its $7400 buffer as WRAM). Check: on the new-game
  party it reproduces FF3's own $6110-$612F byte for byte. Equip menu (mock S4): name, Attack… /
  Defense… (from t8200 $3E), the 5 slots (empty: t8200 $DD-$E1), Remove Equipment (3C/9DA2),
  taking items off (3C/9D68, "inventory full" $016B), the slot's inventory items (3C/9C3C: class
  check, the weapon combination table 3C/9D4B, arrows up to 20, "Can't equip." $016F), values
  recomputed after every change.
- 2026-11-22: Job menu (`src/job.s`, owner's choice J1): name + job, Capacity; the open jobs
  (crystals: fix:F38A) one a row (condensed name, job level, CP cost), 12 a page (left / right);
  CP costs as 3D/AD85 (nibble differences x 4 - job level, at least 0); the checks of 3D/AE23
  (minimum level, no equipment, capacity) with their messages; "Change jobs?" (A); the change as
  3D/AB8F (CP paid, job level / EXP swapped through $6210, base stats and MP growth of the new
  job, its level table replayed level by level 3D/AC31: stats + amount and MP + 1 capped at 99,
  mod. stats = base, current MP at most max), values recomputed. FF3's bank $39 copied whole
  into JOB_BANK. Menu messages up to 4 lines.
- 2026-11-22: Save menu (`src/save.s`, owner's choice V1; on world maps only, as FF3): the three
  files (lead member, Lv, save count) and the chosen file's party, "This erases old data." Yes /
  No, FF3's slot format and checks (3D/AE5C / AE97: $6019 = $5A, the byte-sum complement in
  $601A; the world position as FF3's view corner), the save count as $7F38-$7F3A, "Saving is
  complete.", then "You can turn the power off now." (no RESET on a Game Boy); cart RAM bank 0,
  enabled only around each access.
  Bank 0 was full: the menu modules (menu, Select menu, item, magic, equip, job, save) now run in
  their own ROM bank CODE1 (80), entered by a bank-0 far call; the small tables they read are
  generated next to them (menu.py code_data: palettes, digits, the hand, command words, job-name
  tile counts, EXP table, class masks, the GB-only words); tiles come from MENU_BANK through a DMA
  helper (vcopyx); bank-0 routines that switch ROM banks (text, npc graphics, the walking
  character) restore the caller's bank (rbank). World maps: their BG tiles $70-$FF are map
  tiles, so the full-screen menus load the font there while they cover the screen and put the
  world tiles back on closing; the dialogue box / Select boxes on world maps use a font copy in
  VRAM bank 1 (no npcs there) and the menu window palette (the world palettes have none); the
  hand moved to sprite tiles $10-$13.
- 2026-11-22: the boot screens (`title.py`, `src/title.s`): a suspend point first ("Continue from
  Suspend point?" Yes: restored and erased); the prophecy (t8000 0 / 1 from the ROM, unwrapped
  and laid out as 8 GB pages of up to 8 centred lines of 18, broken at sentences; each page
  fades in (the text colour only), holds 3 s or until a button, fades out); the load menu (New
  Game, Battle Speed (FF3's message speed, left / right), the three files as on the save screen,
  the chosen file's party; a file loads into the save block and starts on its world map at its
  position); New Game: the name entry (t8200 $21 grid, ten letters a row; FF3's rules of 3D/B895:
  six letters, A types and then confirms, B backs up into the previous member, no name like an
  earlier member's), then map 0 with world 0 at FF3's start position on the map stack. The LCD
  goes on once at boot with black palettes. `build.py` without --map / --group builds the real
  boot; with them the test start as before.
- 2026-11-22: Lot Check items: the Color-only screen on other models ("This Game Pak is designed
  only for use with the Game Boy Color(TM) system.", this project's TM glyph, LCD off in V-Blank,
  then halt; checked in PyBoy DMG) and the soft reset (A + B + Start + Select in the joypad read:
  cart RAM and sound off, the boot path).
- 2026-11-22: sound (`src/snd.s`; owner: "the music is horribly wrong. Reference and adapt this
  music", with the NSF). FF3's own driver (bank $36: 8003 update, 8925 music, 8B9D effects, the
  volume / pitch envelopes) written for the GB and run from the V-Blank interrupt; its variables
  keep FF3's layout ($7F40-$7FFF at $CC40-$CCFF) and the song data are read from four GB banks
  (81-84: FF3's bank $36 + one of the song banks $37 / $38 / $39 / $09, so the driver's NES
  addresses map directly). Output: pulse 1 / 2 -> CH1 / CH2 (duty, volume, period through a
  2048-entry period table; a volume change retriggers), triangle -> CH3 (a 32-step triangle
  wave, silent when FF3's linear-counter value is 0), noise -> CH4 (NES period -> the nearest GB
  NR43); the DMC voice only clears its key flag (FF3 only silences it). Checks
  (`tools/gb3n/sndcmp.py`, with the owner's NSF, never kept in the repo):
  - `state`: FF3's driver in the NSF (py65) and the GB driver (PyBoy) frame by frame from the song
    start: all 63 songs in the NSF identical over 900 frames (song $36 is not in the NSF). This
    found one bug (the DMC key flag).
  - `voices`: each voice alone, NES by libgme (`build/nsfrender`), GB by mGBA (test builds with
    env GB_SND_MASK = NR51), audio cut at each side's frame rate (NES 60.10 Hz, GB 59.73 Hz: the
    GB plays the same frames 0.6% slower) and the GB put through the Color's output filter
    (mGBA leaves it out; without it volume steps read as 60 Hz thumps). Pulses / triangle: the
    same notes and lengths (frames sounding on one side only: 0-5 per voice, pitch median 0
    cents); noise a little brighter (about +1-2 semitones of spectral centroid, the NR43 steps).
    (Found with it: the alignment lag must come from all voices, a silent GB window counted as
    misses, and the two frame rates kept apart, else the comparison drifts.)
  Music in the game: a map's song on every map load (property byte 10; bit 7: the song from
  conditional trigger script $38 + n at 2C/8870, as fix:E8DB; checked: map 10 -> $0C as FF3), a
  world map's song and sound effect from 3B/A027 / A047 by world and vehicle, event command $F8
  (songs, fade out, resume, stop, sound effects), song 1 on the prophecy and the load menu.
  `build.py --song N` builds a test ROM that plays song N throughout.
  Later the same day: the NES pulse sweep (rising / falling jingles, songs 48-53) runs in software
  for both GB pulses (divider, reload, mute rule; the period's high bits kept from key-on as
  FF3's hold path writes only $4002 / $4006). `sndcmp.py voices` over all songs: pulses and
  triangle sound on the same frames as the NSF (a note's end differs by at most one frame: the GB
  driver runs from the LCD interrupt, a third of the way into its frame), pitch median 0 cents;
  sweep slides agree within the 2-frame measuring window. Fixed with it: the driver's bank
  writes went through the rom_bank shadow, so code in another bank (CODE1 menus) lost its bank
  when the interrupt returned; it now writes the MBC5 register directly.
- 2026-11-23: shops and inns (`shop.py`, `src/shop.s`), from talking to persons $E3-$FB / $E0-$E2
  (the trigger script loaded as FF3's $7B00). Shops as 3D/AF1F: buy 1 / 4 / 10 (FF3's discounts:
  4p - 104p / 256, 10p - 510p / 256), not enough gil, 99 a slot, a free slot; sell 1 / all at
  half price, key items and the toad / mini magic refused; FF3's cursor / confirm / error sounds.
  GB layout (windows sharing borders, as FF1's GB shop): message 3 lines (rows 0-4), a band with
  the choices (Buy / Sell / Exit, 1 / 4 / 10, 1 / All at FF3's columns) and the shop's name or
  How many? beside the gil (rows 4-7), the eight goods one a row (rows 8-15: icon, name, price at
  the right; the 135 names longer than ten letters drawn at build time in the condensed letters,
  banks 85-87) or the inventory to sell (scrolling, name : count). Inns as 3C/8E8D: cost = living
  members x 5 x the script's price, the question's pages in a box, Yes / No and the gil with its
  last page, gil taken (or "You don't have enough money."), HP restored, then the inn's event.
  Checked in PyBoy: buying (gil, inventory, discount prices), selling (75 Gil for a Potion),
  the inn (40 Gil, HP to max). Fixed with it: t_num printed every number in text as 0 (chest
  gil, prices); text code $04 (a price); menu strings ({0E}) unwrapped at 20 columns before the
  18-column rewrap ("You're carrying too much to buy more." no longer leaves "too" alone).
  Not yet: the shop's party sprites that show who can equip an item; the fat chocobo ($FC-).
  Next: battle (its music comes with it), vehicles.
- 2026-11-23: **battle** (`src/btl*.s`), FF3's battle code ported routine by routine from the
  disassembly, the presentation native. Logic in CODE2 (bank 89), presentation in CODE3 (bank
  110), shared helpers in bank 0 (`btlbase.s`); build.py makes the bank-0 stubs for calls between
  the two banks (A passed and returned). Done: encounters (map / world rates and groups), init
  (monster set and counts, slots, character / monster properties, equipment 31/AA16, strike first
  / ambush / back attack), FF3's target cursor (32/9A1C: the 2 x 4 grid per formation), monster
  AI (31/A732 with the special-attack scripts and target rules), the attack order (34/9777 with
  FF3's quicksort), the turn loop (34/8074), Fight (35/A104 knight cover, 30/9E8A + 31/A000: hits,
  evade, elements, crits, damage, drain, weapon statuses, two hands), magic (31/AF77 and all 57
  attack effects, reflect, the magic messages), the action script (34/8FF7 with its RAM effects:
  text buffer, status merges, near fatal, monster deaths' experience and slots), poison, the
  battle-over check, victory (35/BB49: experience, gil, capacity, drops, job and character level
  ups), the save back, rows, the inventory consolidated, defeat -> the start. Presentation: the
  battlefield and party column (owner's layout), one full-width message window for FF3's five
  message windows (the target after the attacker behind an arrow, long texts wrapped), damage
  numerals as sprites, monsters removed when they die. **Checks** (`btlcmp.py ID --turns N` /
  `--end`: the NES from build/ff3/cave.state with the same party and seed, A pressed on both):
  battles $04 / $08 identical after two turns (all battle state, the RNG counters included),
  battle $10 (monster spells killing three members) after one turn, battle $04 to the field:
  the save block $6000-$63FF identical. Not yet: Item / Magic / job commands for the members,
  run / escape actions, confusion / sleep actions, bosses' graphics, back attacks, the walk-in,
  attack / spell animations (a pause for now), summons' animations.
- 2026-11-23 (later): battle commands Item (35/ADAF: FF3's hand / inventory grid, swaps with the
  two-hand, shield and arrow rules, items used with their targets) and Magic (35/B648: the spell
  list from the learned bits, X for spells the job can't cast, MP per level) in the owner's tall
  list window; the job commands (jump, terrain, peep, scan, steal, buildup, sing, scare, cheer)
  and their actions, run / escape, asleep / paralysed / confused members; bosses (2A/8000
  tilemaps, 2E/9068 graphics, 2E/8FC0 attribute data: Land Turtle as the NES), event battles
  ($F7), back attacks (mirrored battlefield, the party on the left), the battle's end (Fanfare
  with the cheer, Requiem). Battle code now in banks 89 / 110 / 111 with bank-0 stubs. Checks:
  battles $00-$04 end to end with the save block identical to the NES, $05-$08 the same defeat.
- 2026-11-23 (later): **vehicles** (`src/veh.s`, FF3 bank 3E): the vehicle in $600F, passability
  by vehicle, canoe / ship boarding and getting off (the ship parked), airships boarded with A,
  the ship taking off as the Enterprise, landing by FF3's landing masks, speeds, the vehicle and
  parked-vehicle sprites (0B/8800), the event commands $CA / $CB / $CE / $CF, the Invincible's
  inside (A beside it, B aboard). Not yet: the Invincible's sprite and jump, the Nautilus diving /
  surfacing, the floating continent's edge, lift-off / landing animations, the chocobo running
  off, the fat chocobo.
- 2026-11-23 (later): the Invincible (sprite 3C/8857, its jump 3D/B66F, parked with its shadow),
  the Nautilus diving / surfacing, the floating continent's edge (airships down to worlds 2 / 3),
  the fat chocobo (bank and withdraw, 3D/B383), monster-in-a-chest battles.
- 2026-11-23 (later): **cutscenes** (`src/cut.s`, bank CODE5 with NES bank 1F at $6000; data
  `cut.py`, banks CUTD / CUTD2): the crystal prologue ($DB, 1F/A326), the epilogue ($DC, 1F/B146)
  and the ending with the end credits ($DD, 1F/B5B6 / B94A), all as native code from the
  disassembly with FF3's timing. Kit: FF3's cutscene graphics directory (1F/A01B, its RLE
  sources decompressed at build time), palette sets (1F/B300) and fades (1F/A0E8 / A10A), its
  sprite list turned into GB OAM each frame (camera, culling, attributes), text pages re-laid out
  for the GB view (staff lines as they are, story pages wrapped at 18 from the script). The
  epilogue's pages scroll up through the 32-row BG ring (each row written as it comes into view);
  star scenes run at FF3's NES pace (2 frames an iteration, a V-Blank count). Ending: the land
  revealed from the middle, clouds, crystal, night / dawn / day, birds, flash; credits: the party
  (names, levels), the cast, 20 staff pages revealed from the edges, THE END over the stars; FF3's
  4-tiles-a-frame graphics pace kept so the credits keep the NES's timing (within 3%). Checked in
  SameBoy against the NES (cynes) frame by frame at key points.
  Next: the field effects ($D0 shake, $D1 / $E2 flash, $D2 / $D3 blue dusk, $DA dance, $E0 / $E1
  palettes), show / hide player and guest, the guest NPC that follows the party ($EE), the
  special animations ($EF: statues and the Saronia gate (map tiles + $602E, also re-applied on
  world 3 loads), explosions, Bahamut, the Invincible rising, the circling stars), then battle
  animations.
- 2026-11-23 (later): **field effects and the rest of the event script**: the guest NPC ($EE: it
  follows four steps behind on maps, onto the party's tile on world maps where the party waits
  for it; its graphics / colours; B talks to it), show / hide party and guest (C8-CD), screen shake
  ($D0), flash ($D1 / $E2), blue dusk and back ($D2 / $D3), map palettes ($E0 / $E1), people's
  dance ($DA), jumps / circle / spin (object commands A / B / E / F), special animations ($EF,
  `src/anim.s` in bank CODE6 with 3A / 3B / 3C tables at their NES addresses): explosions,
  statues and Saronia's gate (map tiles + $602E, re-applied on world 3 loads), the airship /
  boulder breaking up, cannon balls, the Enterprise landing, the Invincible rising, Bahamut,
  circling stars and lights, the spinning walker ($602F bit 6). World map: FF3's extra sprite
  graphics (3D/BDE0) and objects each frame (Leviathan's shadow, boulder, whirlpool, Hein's
  castle and Bahamut orbits, the floating continent overhead, the chocobo running off).
  Fixed: the parked-Invincible code had cleared OAM 4-27 on every map (people hidden on maps).
  Test hook (RAM, `tst_choc`): $D0-$E3 runs that event command, $F0-$FF special animation n.
  Next: battle animations, then the parity / Lot Check pass on the native build.
- 2026-11-23 (battle animations, `src/btlanim.s` CODE7, `src/btlfx.s` CODE8): attacks (FF3 33/A0C0:
  blades, blunt, claws, bare hands, bow + arrows, harp, boomerang, full moon, shuriken; the
  projectile vectors 33/BF5F-BFE4 with FF3's sine table, the angle to the target 33/A7A5, hit
  animations 0-5 with FF3's random calls), monsters' attacks and the hit on members. Whole battles
  with each weapon give the NES's save block (`BTL_POKE="6203=.. 6205=.." btlcmp.py ID --end`).
  Magic (34/8577, 33/BAFD): the black / white casting, the flight to each target, the spell's hit
  frames (06/8C00 lists, 00/9708 frames, 6 x 6 sprites). Item spells skip the casting as FF3 does
  ($CC set). **The 8 x 16 sprite mode**: FF3 shows up to 36 effect sprites next to the party's 24
  (NES: 64 sprites); the GB has 40. While a spell shows, the party's and the effect's 8 x 8 sprites
  are paired into 8 x 16 sprites (vertical neighbours of one palette), each pair's tiles composed
  (flips put into the pixels) from a WRAM 5 mirror of VRAM bank 1 sprite tiles into 64 slots
  (tiles $00-$7F, restored from the mirror after), staged in WRAM 6 and sent by GDMA in V-Blank
  (24 pairs a frame); least recently used slots are reused, the party's pairs kept while its
  sprites stay. Measured: the casting loop runs one step a frame as on the NES.
  Cross-bank stubs are 6 bytes now (`far_s`), which freed ~650 bytes of bank 0.
  Then: the special spells (kill, drain, quake, earthquake with FF3's random shake, meteo,
  tsunami, glare / explode flashes, enemy flame / blizzard / thunder with the party hidden as FF3
  does), the reflection wall, the post-spell split / brak2 / toad / mini (state as FF3: slots,
  experience counts), the monsters' pre-attack flash (attribute table by GDMA), the death /
  escape wipe (2F/BB94: diagonal, the new tilemap over the old), defend, cheer, scare, buildup
  (overload burst), jump (leaving / landing, $7E22), row changes, the party's escape, the victory
  cheer tiles (2F/A963). Fixed: numerals ($69-$75) and the hand ($76-$79) moved off the members'
  animation tiles (digits showed in victory poses). Parity: btlcmp `--end` identical (battles 0-4,
  weapon pokes). Then: the battle start walk-in (2F/B469); no white screen at a battle's start /
  end (the LCD stays on behind black, as the field's loads; the battle's window off at its end);
  summons (`src/btlsum.s`, CODE9 with bank 32 at $6000): FF3's casting, the party's palettes
  cycled / faded, the creature from 2A/9440 (size, place, palettes, layout) as 8 x 16 pairs with
  the party hidden (Leviathan 8 x 9 = 40 pairs), in / out; attacks done: chocobo dash / shake /
  kick, Ramuh's mind blast and bolts (the hit frames via 33/B943), Ifrit's healing light, Titan's
  clobber / stomp (FF3's random places) and earthen fury, Shiva's icy stare, Odin's protective
  light / slash / Zantetsuken (FF3's state: experience, slots cleared), Leviathan's demon eye /
  tidal wave (FF3's random shakes; the wave sprites still to draw), Bahamut's aura / rend.
  Fixed: the 8 x 16 mode's data had sat under the stack ($C800 down); its flags are in HRAM now,
  its sprite list in WRAM 5 and the tile mirror in WRAM 6.
  Remaining: mesmerize, diamond dust, hellfire, inferno, cyclone (visual only, no random calls),
  mega flare and the cannon (FF3's random places: needed for parity), the tidal wave's waves, the
  flare wave's cloud (10/8BD5), the boss death, the split's fade-in.
