# FF1 for Game Boy: the native rewrite

Owner's decision (2026-11-21, binding): **"it must become 100% native code, absolutely no NES
layer"**, and asked to choose, **a full hand-written rewrite**: FF1's whole engine (field,
battle, menus, events, music) is written by hand as native Game Boy code from what the
disassembly says each routine does. Only *data* comes from the user's ROM at build time. This
replaces static recompilation for FF1 (the recompiled build stays available until the native
one reaches parity, so the owner can keep playing).

## Rules (unchanged from CLAUDE.md, and what changes)

- Nothing game-specific in the repo: every game byte (maps, tiles, text, stats, songs,
  formations, FF3 icons) is read from the user's ROMs when the build runs. The native engine is
  our own code, written from understanding the original (Entroper/FF1Disassembly in
  `build/ref/`, matched to the Japanese ROM); no game code is copied or translated
  instruction by instruction.
- Game rules exactly as on the Famicom (formulas, RNG table use, encounter rates, AI, events),
  with the owner's chosen bug fixes (`gb_layout.bug_fixes`).
- Screens as already approved (the GB layouts of the recompiled build are the reference).
- Lot Check standards (`docs/gb-release-checks.md`) are designed in from the start:
  - work RAM fits the Game Boy's own 8 KB WRAM (no NES RAM image, no nametable shadows), so
    cart RAM holds only the save, the suspend point and the options, enabled only around each
    access (2.3 met literally);
  - LCD off only in V-Blank, VRAM/OAM only in their windows, soft reset, memory cleared at boot,
    DMG / SGB / CGB from one ROM, FF3 is still the only Color-only game.
- 0 lag frames on DMG and CGB by construction: one engine frame per GB frame, the picture
  drawn natively (GB map / tiles / OAM written directly), graphics converted and DMG-shaded at
  build time.
- Owner's additions for the native game: **names up to 6 letters**; **FF3's icons** (weapon,
  armour, item, white / black magic, from the user's FF3 ROM, font file offset `0x1B000`,
  codes `$5C-$75`) before item and spell names.

## Architecture

- `tools/gbn/data.py` (build time): reads the English NES ROM made by the existing pipeline
  (NES ROM -> MMC5 split -> English insert) and the FF3 ROM; writes GB-ready data banks:
  - map tiles: standard maps (64x64) and the overworld (256x256) decompressed; per tileset
    the 128 metatiles as 2x2 GB tile numbers + CGB palette + DMG shade map;
  - graphics: NES CHR converted to GB 2bpp, pre-shaded per palette for DMG, CGB palettes in
    RGB555;
  - text: the English strings (dialogue, menus, battle) in our own encoding, already wrapped
    to the GB layouts; FF3 icon glyphs;
  - game tables: classes, items, weapons, armour, spells, monsters, formations, domains,
    teleports, map objects, treasure, shops, prices, level-up tables, the RNG table, songs.
- `tools/gbn/src/*.s` (SM83, our assembler): the engine.
  - `main.s` boot (DMG / SGB / CGB detection, memory clear), main loop, frame wait;
  - `field.s` maps: load, draw rows / columns into the 32x32 GB BG map as the camera moves,
    party movement, collision from tile properties, teleports, NPC objects, talking, events,
    vehicles (ship, canoe, airship), the world map and the 15-puzzle;
  - `text.s` window frames, the menu font, the small battle font, number printing;
  - `menu.s` title, new game (class select, name entry), main menu, items, magic, equipment,
    status, shops, inn, save;
  - `battle.s` formations, the battle screen (approved layout), commands, turn order, damage,
    magic and items, enemy AI, animations, rewards, level-ups;
  - `music.s` FF1's song format played on the GB channels (the native player of the
    recompiled build, `rt/mus.s`, is the starting point), sound effects;
  - `sgb.s`, `save.s` (from the recompiled build's runtime where they are already ours).
- Game state block: FF1's game variables (party, items, gold, flags, positions, battle state)
  kept with the same meaning and byte layout as on the NES where the save format and the
  checks need it (names: 6 bytes, a deliberate change), so the state can be compared with NES
  runs.

## Verification

- **State checks:** the NES build and the native build fed the same inputs, the game state
  block compared at checkpoints (field position, party, items, gold, flags after each scripted
  scene; battle outcomes with the RNG position aligned). Logic that matches the NES gives the
  same state.
- **Pictures:** SameBoy (hardware-like timing) screenshots of every screen, DMG / CGB / SGB
  (mGBA for SGB), against the approved GB layouts of the recompiled build.
- **Lag:** Gambatte lagcheck (0 frames on DMG and CGB).

## Milestones

1. Data extraction and a boot ROM: a standard map (Coneria town) drawn from extracted data,
   the party walking with collision and camera scrolling, DMG / CGB colours.
2. All standard maps and the overworld, teleports, doors and rooms, NPC objects and dialogue.
3. Menus (main menu, items, magic, equipment, status), shops, inn, save / load.
4. Title, prologue, new game (6-letter names), the story scenes.
5. Battle (screen, commands, formulas, AI, magic, items, animations, rewards).
6. Events and vehicles through the whole game, the ending; music and sound effects.
7. Parity checks over the whole game, Lot Check pass, release.

## Progress

- 2026-11-21: milestone 1 started. `tools/gbn/data.py` reads a standard map, its tileset
  (properties, TSA, attributes), the map palettes, the tileset graphics and the party sprite
  from the ROM, converts the tiles to GB format and pre-shades a variant per (tile, palette)
  for DMG (all 61 maps fit: 112-121 variants). `tools/gbn/src/main.s` (1.3 KB): boot (DMG /
  CGB, memory cleared, LCD off only in V-Blank), the map drawn into the 32 x 32 BG ring from
  the metatile tables, the party sprite from FF1's 2 x 2 tables, walking one metatile per 16
  frames with collision from the tile properties, the incoming row / column queued and written
  in V-Blank (CGB palettes into VRAM bank 1). Coneria town walks in mGBA (CGB colours as the
  NES). Next: DMG shades as the recompiled build's rules (the party blends in now), teleports,
  doors / rooms, NPC objects, dialogue.
- 2026-11-21 (later): all 61 standard maps and 8 tilesets from the ROM (2 MB ROM: tilesets in
  banks 8-15, a bank per map), run-time map loading, normal teleports (tile property bits 7-6
  = 10 + FF1's teleport tables), doors and rooms as FF1 does them (no map change: the in-room
  palette set, the door metatile redrawn; CGB swaps the BG palettes, DMG redraws the visible
  metatiles with tiles pre-shaded for the in-room palettes; both sets fit 256 tiles on every
  map, 242 at most). DMG shades by brightness rows (as the recompiled build). The metatile
  queue is a 256-entry ring (no interrupt locks) and the V-Blank flush stops at line 152:
  PyBoy showed entries half-written when 20 metatiles ran past V-Blank. Checked: Coneria town,
  Coneria castle rooms on DMG and CGB (mGBA, PyBoy VRAM = expected metatiles).
- Overworld: 256 x 256 (rows decompressed at build time into banks 84-87), its tileset (256
  tiles, bank 16; palettes / DMG tiles bank 81, 236 DMG variants), movement blocked by the
  vehicle bit (on foot: bit 0), entrances (second property byte bit 7 + FF1's entrance
  table), exit teleports (FF1's exit table), warps and FF1's floor stack (normal teleports
  push x / y / room / map, a warp pops it or returns to the overworld position the party
  entered from). The game starts at the new game's overworld position from the initial save
  page. Checked: start -> Coneria town -> warp out (mGBA, PyBoy).
- Map objects (objects.s): FF1's 15 slots per map with the visibility game flags (hidden ones
  kept, raw id), one object steps per frame after a wait (frame counter + seed, as FF1),
  collision with tiles / the party / each other, a pixel every two frames, walking in place
  when stationary, shown by room state, at most 9 drawn (40 sprites). Sprite tile blocks per
  distinct graphic placed by the build around the map's BG tiles (DMG: pre-shaded to
  brightness ranks, one OBJ palette; CGB: 4 OBJ palettes). Game state ($400-byte save page)
  initialised from the ROM's new-game tables.
- Text (text.s, text.py): our Latin font + FF1's window frame tiles; DMG: placed per map in the
  free BG tiles (variants now only for the metatiles a map uses: at least 108 tiles free);
  CGB: VRAM bank 1, palette 7 = FF1's window colours. The English dialogue (translation files)
  re-wrapped at build time to the approved box: 20 x 8 in the window layer, 18 x 6 text,
  pages on A; cut at line 64 by LYC; objects under it hidden. CGB runs in double speed.
- Talking (talk.s, talkconst.py): FF1's 42 talk routine kinds written natively; each object's
  kind comes from the ROM's jump table (named as the disassembly names it: one address per
  name, checked), its 4 data bytes from the ROM's talk table, and the routines' constants
  (object ids, battles, teleports, item addresses) from the operands in the ROM. Effects:
  game flags, items, objects shown / hidden, the class change, the smith's sword (the ROM's
  weapon slot table), teleports after the box closes (battles: later). Checked: townsperson
  and the King of Coneria (DMG / CGB).
- New game (screens.s, ui.py; code bank 2, our own UI code): title (Continue / New Game /
  Message Speed), FF1's class select in the approved 4-box layout (class battle sprites from
  the ROM: DMG pre-shaded by brightness rank, CGB in FF1's battle sprite palettes), name entry
  with **names up to 6 letters** (letter grid, B deletes / goes back, Start ends), then each
  member's class, name (letters 5-6 at save-page offset $3E) and FF1's starting stats from
  the ROM's class table; level-1 MP for the magicians. Ends on the overworld start. Banked
  code never maps another bank into its own window: data from other banks via far_copy.
  Checked: PyBoy (DMG), mGBA (CGB).
- Menus (menu.s, code bank 2; screens now drawn into a RAM copy of the map, uploaded in
  V-Blank, so descriptions and updates need no blank screen): main menu (party with HP and
  level, commands, Gil, the four orbs from FF1's orb tiles), Items (13 a page; FF1's item
  effects: Potion / Antidote / Golden Needle on a member, Sleeping Bag / Tent / Cottage with
  the save question, Lute / Rod plates, Floating Stone, the fairy's bottle; descriptions from
  the project's English re-wrapped), Magic (three levels a page; FF1's out-of-battle spells
  with the ROM's spell ids and formulas: cure and heal families, Life / Full-Life, Pure,
  Soft, Warp and Exit through the floor stack), Weapons / Armor (FF1's Equip / Swap / Drop,
  class permissions, same-type unequip, stat adjustments incl. Black Belt / Master; an
  equipped item shows its icon as a dark silhouette on a white box), Status (level,
  experience, to the next level from FF1's table, stats, class sprite). Item / spell routine
  constants are read from the ROM's routines (talkconst.item_routines / magic_routines).
  Save: the save page to cart RAM with a mark and a sum. Test builds: `build.py --init
  ADDR=VAL,..` seeds the save page.
- Shops (shop.s, from FF1's EnterShop and shop loops): weapon / armour (buy, give to a member
  with a free slot, sell for half, stats readjusted), item shops and the caravan (99 at most),
  white / black magic (class permissions, already known, the level full), inn (HP / MP full,
  saved), clinic (revive with 1 HP). Shop type, items, inn / clinic prices and magic
  permissions come from the ROM's tables (names.shop_tables); entered by walking onto a door
  tile whose second property byte is a shop number, as FF1. Layout: speech (0,0,20,6),
  title, commands / Yes-No / names, the 5-item list with prices, Gil.
- Battle, part 1 (btl.s / btl2.s in bank 6, data bank 92, enemy graphics banks 93-94; from
  FF1's banks 0B / 0C): formations and enemy generation (9-small / 4-large / mix; fiend /
  Chaos graphics later), the screen in the approved layout (enemies from FF1's graphics pages,
  DMG pre-shaded by the formation's palettes, CGB in FF1's colours; the party's battle
  sprites; the windows with a small proportional font rendered into tiles and uploaded in
  V-Blank), commands (Fight / Run; B goes back a member), FF1's turn order shuffle, physical
  attacks with FF1's hit / damage / critical / ailment formulas (the weapon's critical rate,
  element and category applied: FF1's bugs fixed as in the recompiled build), enemy morale /
  sleep / paralysis / confusion recovery, running (level from the record), poison, messages
  in the approved style (attacker -> target, result lines), victory with experience divided
  by the members standing and gold, FF1's level ups (hit / magic defence bonuses, MP charges,
  HP, stats, Black Belt adjustments), defeat -> back to the title. Random encounters (FF1's
  step RNG, overworld domains, map rates, spiked tiles) and talk battles. Test builds:
  `build.py --battle F` starts with formation F, `--enc N` sets the overworld rate.
- Battle, part 2 (btl3.s): magic (the spell list two levels a page with FF3's icons rendered
  into the small font, targets by the spell's target bits, FF1's 18 spell effects with its hit
  / damage rules, the spells' messages from the ROM's table, ailment added / cured messages,
  LOK2's evasion-down bug fixed), the enemy AI (spell / special attack chances, the lists in
  turn), confused enemies casting Fire on their side, Medicine (Potion / Antidote with this
  round's counts), Items (equipment spells, weapons / armour pages).
  Not yet: fiend / Chaos graphics, battle animations and sound effects.
- Continue / soft reset: the title offers Continue when cart RAM holds a valid save (mark
  "FF1N", the page, a 16-bit sum); A+B+Start+Select resets to the title (Lot Check); the
  save records the overworld position (FF1: scroll = position - 7) in save page $10/$11.

- Vehicles (main.s ow_canmove / ow_abutton / veh_oam): canoe, ship, airship with FF1's rules
  (board / unboard / dock, the canal object, landing only where tile byte 0 bit 3 is clear,
  no encounters in the air, 3/256 on the ship), the vehicle sprites from FF1's tables and OW
  object graphics, walking poison damage, the caravan, chime tiles. The bridge sets FF1's
  bridgescene flag (the story scene itself: next).

- Story pages (prologue before the title, the bridge story), fiend / Chaos battle graphics,
  music (sound.py / snd.s: FF1's music engine as native code from the recompiled build's port,
  song data from a copy of the user's bank 13, output to the GB channels with a period ->
  frequency table made at build time; map / vehicle / event tracks). Not yet: sound effects
  (battle hits, menu cursor), the ending sequence after Chaos.

- Sound effects (snd.s, sound.sfx_data): FF1's menu cursor / select / error sounds (their
  register values read from the ROM's code) and its three battle sounds (data_BattleSoundEffects),
  played on CH2 / CH4 while the music leaves square 2 alone (FF1's sq2_sfx); the NES sweep runs in
  software (two half-frame clocks a frame); the ship's and airship's noise on the overworld. Menu
  sounds come from read_pad while a menu screen is open (sfx_menu); errors where FF1 plays them
  (equip, drop, item / magic targets, a dead caster).
- Battle animations (btl4.s, battle.obj_bank): FF1's poses (standing, walking, attacking, cheering,
  crouching when low / ill, lying dead, stone), the walk forward / back, the weapon swing (the
  weapon's graphic and palette), the spell cast (graphic, the background flash), explosions on
  hit enemies, the screen shake on enemy attacks, enemies erased row by row, the victory cheer.
  No blinking (owner). Battle windows: blanked on screen before new text, rows go up whole.

- Lineup menu (Select; FF1 EnterLineupMenu: slots sliding, the leader never dead / stone,
  records reordered on leaving), the world map (B + Select on the overworld: the 128 x 128
  picture made at build time from the user's ROM by FF1's rule, drawn a pixel row a frame with
  FF1's tone, the marks), the party's map sprite is the leader's class (CGB colours, DMG ranks
  per map). The 15-puzzle (B x 55, then A + B on the ship; FF1's pieces as 8 x 16 sprites,
  shuffle, slides, the reward). The title's message speed (FF1's respond rate) sets the battle
  message wait. Super Game Boy: the border, a palette set per screen (sgb.py, src/sgb.s).

- Lot Check pass (docs/gb-release-checks.md "FF1 native build"), lag (field steps 16 frames;
  loops end early in the frame), the airship's takeoff / landing (FF1's animation, noise and
  shadow), vehicles in FF1's 2 x 2 order, the ending as FF1 (epilogue music, timed pages,
  "The End" traced and filled from the ROM's moves), Chaos' dissolve. The FFE Builder makes FF1
  from this build (the FF III ROM, if chosen, for the icons).

## Next steps (native rewrite)
1. (done) Vehicles (FF1 ProcessOWInput / OWCanMove, bank 0F): `vehicle` 1 foot, 2 canoe, 4 ship,
   8 airship; blocked if tile byte 0 & vehicle; on foot onto water: BoardCanoe (needs
   has_canoe = save $12, tile byte 0 bit 1 clear) or BoardShip (ship_vis/x/y = save $00-$02
   at the target); ship: moving onto land = UnboardBoat (tile byte 0 bit 0 clear) and
   DockShip (the ship stays where it was), canal (save $0C-$0E) lets the ship through, tile
   byte 0 & $21 = $20 docks; canoe: UnboardBoat onto land, BoardShip; airship (save $04-$06):
   A on the airship's tile flies (FlyAirship), A in the air lands (LandAirship: not where
   tile byte 0 bit 3 is set); random encounters: 3/256 on the ship, none in the air (tile
   byte 1 bit 6 only checked for foot / canoe / ship); MapPoisonDamage on foot (poisoned
   members lose 1 HP a step, not below 1); caravan (tile byte 0 bits 7-6 = 10: shop 70 unless
   the fairy object is shown); chime tiles need the Chime; IsOnBridge sets bridgescene (the
   bridge story). Vehicle sprites: FF1's OW object graphics (bank 9 $9C00, sprite tiles
   $10-$6F) and its vehicle sprite tables.
2. Fiend / Chaos battle graphics (FF1 PrepareEnemyFormation_Fiend / _Chaos, data_FiendTSA /
   data_ChaosTSA in bank 0B: 8 x 8 / 14 x 12 TSA, their own palettes).
3. (done: music) Music and sound effects: a native player for FF1's music data (bank 0D MusicPlay format:
   the recompiled build's rt/mus.s documents it) driving the GB APU directly; battle SFX.
4. (done) Story scenes, prologue, the minimap, the 15-puzzle, options (message speed).
5. (done) Battle polish: animations and poses; sound effects.
6. (done) SGB, Lot Check pass, lag check, the builder, FF1's transitions (the battle
   transition's emphasis flashing, the palette cycling around menus / shops, the screen wipe on
   map changes), the story pages' shutters, the bridge scene as FF1 (its music, the four story
   pages, then FF1's four credits pages read from the ROM's lut_CreditsText at build time, a
   32-frame stall). Left: the owner's play-test on hardware.
7. (done) Loads on the Color behind a black mask (no white frames: the LCD stays on, palettes
   black, a mode-2 STAT guard keeps VRAM writes out of mode 3; `lcd_off` / `lcd_on` in
   main.s); DMG / SGB keep the LCD-off loads. Load times measured against FF1 on the NES:
   menu 60 vs 63 frames from the press, town entry black 11 vs 12, battle start black 10 vs
   20.
10. Owner (2026-11-22): the battle party pictures / colours (the battle and lineup loaders read
   the job pictures two classes on; SGB battle: each member's rows in its job's palette); the
   equipment screen in a modern Final Fantasy style (screens.s eqm_*: main menu Items / Magic /
   Equip / Status; one screen per member with picture, name, job, level, the five slots with
   FF3's icons and Attack / Accuracy / Defense / Evasion; a slot lists Remove and every
   unequipped item of the party's packs that fits the slot and the job, with an old > new preview,
   green better / red worse on the Color; items from another member's pack trade places with
   the replaced one, keeping FF1's four weapons / four armour per member and FF1's stat rules);
   Potion / Antidote / Golden Needle used again and again (the target window stays open).
9. Owner's play-test of the first native ROM (2026-11-21), fixed: job pictures (read two
   classes on: promoted jobs showed), party names (printed at column 0), party creation to the
   owner's design (FF1's default party; A on a member: a job list with every job's picture and
   name, then the name entry; all four named: OK to begin with this party? Yes / No, No resets
   everything), the prologue as FF1's intro (crystal theme; blue screen; lines fading in one
   at a time over 64 frames with FF1's colour steps and flicker; A / B finishes a line; pages
   wait for A / B; Start: the title; Colour by palettes 2-4, DMG / SGB by a BGP raster list on
   the fading line), black outside the windows on the Color, DMG sprites white / light / dark
   on the black screens, the world map with Select pressed a moment before B.
8. (done) Sound as the recompiled build: the pulses at 5/8 of FF1's volume (music, sound
   effects, the world map's tone, the wipe; decays from 9 with longer steps), and the triangle's
   linear and length counters when FF1 clears the control bit (a song's end: before, the last
   triangle note sounded on forever after a jingle). Checked: every FF1 song ($41-$57) played on
   the native and the recompiled build (whose voices were checked against the NES) in SameBoy:
   per-frame pitch-class similarity 0.98-0.99 where both sound, the rests and the jingles'
   lengths the same, loudness within ~5%.
11. Owner (2026-11-22): Suspend as in the recompiled build: main menu Items / Magic / Equip /
   Status / Suspend; "Create a Suspend Point and return to the Title? Suspend points are
   retained when turning off the Power." (No first); Yes saves the field's state (position,
   map, floors, objects, vehicle, encounter counters, the whole save page) to cart RAM bank 1
   with a mark and a sum and returns to the title. Continue (also with no save): "Continue
   from Suspend point?" Yes restores it (erased once resumed) and re-enters the map as after
   a menu; No with a save: "Continue from last save? The suspend point will be lost!"; No
   again, or no save: the title. Music sounds checked against the owner's NSF (pulses 7/8,
   volume steps without retriggers).
12. Owner (2026-11-22): the equipment screen has FF1's two kinds only: a Weapon row, then the
   armour worn (one row per piece, in FF1's type order) and one empty armour row while fewer
   than four are worn; an armour row lists every wearable armour in the party's packs, and a
   piece replaces the worn piece of its type (FF1: one of each). Battle: free targeting (a
   direction picks the nearest living enemy that way, wrapping round); one rule for the hand
   cursor everywhere (fingertip just before the text, finger at its middle row; where the
   text starts at the window's first column the hand points at the second line or the
   picture instead of leaving only a fingertip on screen).
13. Owner (2026-11-22): Magic and Status screens in the equipment screen's style (shared top
   window `mtop`: picture, name, one-line job). Magic: HP on the top window; the eight levels
   as gold L1 .. L8 headers with MP current / maximum, the member's three spells below each
   (icon, name), scrolled with the hand; left / right: the next member; Cure / Cure 4 / Life /
   Pure / Soft cast again and again with the target window open while MP lasts. Status: level;
   HP, MP of every level (two rows), experience and what the next level needs; Str / Agi / Int /
   Vit / Lck and Attack / Accuracy / Defense / Evasion in two columns; gold labels on the
   Color (palette 3); left / right: the next member.
14. Owner (2026-11-22): shops as the new menus. Weapon / armour shops: after the price, a
   party window shows each member's Attack (weapons) or Defense (armour) now and with the item
   (Color: green better, red worse; gold header), or Can't use / Full; then Equip it now?
   (FF1's one weapon / one armour of each type). Selling: one scrolling list of every
   unequipped item of the shop's kind in the party's packs, at half price. Magic shops: the
   spell first, then the party window with OK / Known / Can't learn / Full per member. Item
   shops: a quantity (up / down 1, right / left 10, at most what the Gil buys and 99 owned)
   with the total. The world map, the 15-puzzle and The End moved to ROM bank 99 (F3_BANK)
   to make room in bank 2.
