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
15. Owner (2026-11-22): the party's pictures back on the main menu: party window (0,0,12,15)
   with each member's battle pose (x 14, three rows) and name, level (or Dead / Stone /
   Poison) and HP / max beside it; commands (11,0,9,7); orbs (11,6,9,9); Gil (0,15,20,3).
   Choosing a member, the hand points at the picture; the command's hand stays.
16. Owner (2026-11-22): text typed a letter at a time: about 21 letters a second (an adult's
   reading speed, 250 words a minute: TW_RATE 90/256 a frame), twice as fast with A held,
   a soft noise click every second letter (16 ms, volume 5 falling). Dialogue (text.s: the
   page kept in win_tx at $DD40, its letters revealed into the box, one cell a V-Blank),
   shop speech and the menus' description windows (menu.s pen_type). Test builds:
   `build.py --dlg N` opens dialogue N after the map loads.
17. Owner (2026-11-22, later): one style for all screens and consistent transitions.
   - Fades (main.s fade_out / fade_in, bank 0 $1480): every menu, shop and sub-screen change
     and leaving a menu / battle for the map fade out and in, 4 steps of 2 frames. Color: the
     palettes scaled to black (fd_pal = the dialogue page buffer, fd_tmp $C880); DMG / SGB:
     the shades to white (the switched-off screen's colour). FF1's palette cycle before a menu
     stands for the fade-out (fd_skip). The first screen after power-on / a soft reset shows
     without a fade on the Color (mGBA reads palette RAM back as 0 there).
   - The hand hides while a window is still going up (scr_frame / bt_frame) and while text
     types: it never shows in the wrong place.
   - Items screen: a full-width header (gold title, Gil); Formation screen full width with a
     title; item / spell target screens load as screens of their own (faded).
   - Name entry in windows: the job's picture, its name and the name being written on top; the
     letters one case at a time (SELECT switches), digits and signs below, rows two apart; the
     cursor is the hand's finger tile (fits between two letters).
   - Title: Continue grey (Color palette 4) and skipped when there is nothing to continue.
   - Item shop asks How many?; Magic refused (error sound) for members without magic, and
     left / right in the magic screen skip them.
   - The items' icon: a drawn bag (own art in FF3's icon colours).
   - Checked: all 61 standard maps load (Color + DMG), the eight fiends and Chaos won with the
     ending and The End, the 15-puzzle, inn save, soft reset -> title -> New Game; VRAM checker
     0 on Color, DMG and SGB over these runs.
   Ideas for later (owner to choose): docs/ff1-native-ideas.md.
18. Owner (2026-11-22, last) chose from the ideas: battle backdrops yes, HP bars no, battle
   conveniences yes (no Select repeat), Options yes, dash on B only if encounters keep pace.
   - Dash (main.s `move`): B held on foot walks two pixels a frame; a step is still one step,
     so the encounter counter runs per step as before (encounters come as often per tile).
   - Options (main menu, menu.s bank 2 $7280): message speed (FF1's respond rate), text speed
     (Slow / Normal / Fast / Faster / Instant), volume (NR50); kept in cart RAM bank 1 $BF00 with
     a check byte, loaded at boot.
   - Battle: each member's last command and target remembered for the next turn (a dead target:
     the first living enemy); the damage number over the target for a moment (two outlined
     sprites, OBJ palette 4 on the Color), beside the style-A message; at the end one results
     window (Experience, Gil, then two members a page: level, HP gain, the stats that rose)
     instead of a run of messages (btl2.s bank 6 $7480).
   - Backdrops: built (FF1's scenery strip behind the enemies by whole cells, Color / DMG / SGB),
     then mock-ups of it across the full width and over the whole battlefield; the owner
     disliked all of them and chose the pure black battlefield. Removed (pixel blending was
     not possible either: most mixed cells need more than four colours).
19. Owner (2026-11-22): "the music is still messed up; Cornelia messes up every other track".
   Checked every song: FF1's engine (py65 on the ROM) and the GB engine agree exactly frame by frame,
   fresh and after the town theme; SameBoy / Gambatte play them as FF1 (per voice: pitch, envelopes).
   mGBA 0.10 in Color mode ignores the zombie-mode volume steps the GB sound layer uses for volume
   changes inside a note, so there every envelope was garbled (the town theme changes volume nearly
   every frame). The boot now tests zombie mode on a Color (snd.s `snd_zmb`, PCM12) and uses
   restarts where it does not work; mGBA's envelopes now follow FF1's (correlation 0.75-0.98 per
   voice, was 0.1). Tools: `sgbrun` env SGBRUN_WAV (sound, 48 kHz).
20. Owner (2026-11-22, real Game Boy Color): "Cornelia specifically is wrong; once it plays, every
   other song is messed up". Found: the map music restarted from the beginning after every dialogue
   and every return from a menu, because map_music compared the wanted song with FF1's music_track
   ($4B), which FF1 sets to 0 once a song plays. A restart also took square 2 back from a sound
   effect still playing (the dialogue sound), so the two fought over the channel. Now snd_track
   keeps the song asked for last (`mus_cur`) and map_music keeps a song that is already playing (as
   FF1: the map song restarts only after another song, e.g. the menu, a shop, a battle, a fanfare).
   Checked: talking in Cornelia, one engine step per frame (no restarts); the overworld theme after
   it matches FF1's NSF per voice as from a fresh start. Test builds: env GBN_VOLMODE 1 / 2 / 3 force
   the volume method (zombie mode / restarts / note starts only); 0 (release) = the boot test.
21. Owner (2026-11-22, later): title menu centred (boxes at columns 4-15 / 1-18); damage numbers and
   "MISS!" pop up over the target, drop back, hop once and rest, as in FF3 (our own bold 6 x 6 glyphs
   with a 1-pixel outline, battle.py dn_tiles at BTL_DATA $4B00, one sprite each in OAM 35-39 with
   the hand's tiles $F0-$F4 borrowed and restored; animated from bt_frame; DMG / SGB through OBP1:
   white ink, black outline); a member hit flinches (its sprites knocked 8 px back and sliding into
   place while the number shows; no blinking); healing a member at full HP (Potion, Cure family,
   Full Cure; the Heal family when everyone standing is full) shows "It wouldn't have any effect."
   with the error sound and returns to the target with nothing spent, in the menus and in battle;
   the prologue's lines fade smoothly (Color: blue to white continuously over 32 frames, from FF1's
   own colours; DMG / SGB: 32 frames, lighter dither) and A / B show the whole page at once.
   Bug found on the way: dn_t was not cleared at a battle's start, so leftover RAM let the number
   routine write past OAM into battle RAM (it is cleared now; at most 5 glyphs).
22. Owner (2026-11-22, last): improvements from the WonderSwan Color remake's videos, keeping the NES /
   Game Boy look (docs/gb-video-improvements.md has what was seen, taken or not, and how to rebuild
   each in FF2 / FF3). Battle: an enemy about to act flashes (silhouettes made at build time; Color
   white / black with an outline, DMG / SGB white; fiends by palette on the Color), "n HIT(S)" in gold
   over the attacker, each kind's count in the names window, members dart forward to swing / cast.
   Field and menus: the place's name in a banner on entering a new place and on the main menu, the
   play time (in unused save-page bytes), Items Use / Sort / Key Items, equipment Optimize, shops'
   owned / worn counts and magic shops' slot pips, Options with B Dash, Cursor Remember / Reset and
   (Color) the windows' colour, Forget (SELECT on the Magic screen), three save files with previews
   (file 1 where the single save was). Fixed on the way: two calls into another bank (tools/gbn/
   xbank.py now finds them).
23. Owner (2026-11-22, after the mock-up video): the encounter transition (twist / zoom, shattering
   strips, white flash, the battle fading in from white), the party walking in from the right, gradient
   windows on the Color with Options: Gradient On / Off (the top the window colour itself, darker than the
   mock-up), the main menu's crystals centred. Details: docs/gb-video-improvements.md.
24. Owner (2026-11-23), fixed:
   - Music on DMG / Pocket (Cornelia, the Temple of Fiends, then every song): retriggering
     channel 3 while it plays corrupts wave RAM on a plain Game Boy (reproduced in SameBoy:
     `0123456789ABCDEF` became `BADCBA9889ABCDEF` on entering Cornelia, for good). The triangle
     now changes pitch without a restart while it sounds (as the NES triangle keeps its phase);
     a stopped channel is restarted with its DAC off and the wave RAM written again
     (snd.s `.ft`, `nr30_w`). Checked in SameBoy on DMG, Pocket, Color 0-E and GBA.
   - Monsters striking first: the party's command slots were never cleared, so each member ran
     leftover bytes (a garbled spell).
   - Teleports into a room behind a door: the room is shown from the start (build time:
     data.room_teles finds the 9 such teleports in the user's ROM; load_map takes ml_room;
     the Color picks the room palette at load).
   - Town transition: on the overworld the DMG curtain tile was an overworld tile (water); a
     solid black tile is added to the overworld's DMG set. The wipe's first frame showed the
     window over the whole screen (enabled at WX 167; at the bottom edge with a late V-Blank).
     DMG keeps the switched-off (white) screen while a map loads: the black masked load takes
     38 frames there instead of 16.
   - The gradient fades with the screen (ramp rebuilt per fade step; faster ramp builder).
   - The file picker opens on the file in use (drawing the three files moved it to file 3).
   - Attacks in the remake's timing (measured at 60 fps in the owner's videos): the result is
     worked out first (a silent pass, RNG restored), then: dart forward 2 frames with the hit
     count, 6 frames, weapon raised 4, swing, one hit burst at a time (3 frames each), the
     number and all the text together, held 52 frames at message speed 1 (FF1: 120), cleared
     together; a dead enemy breaks up in sliding strips (~30 frames; fiends: their flash, the
     screen shaking, slower); then the member darts back.
   - Running away: the party turns round (mirrored sprites) and runs off to the right.
   Fiend deaths checked with a cheated test party (build.py --init: 999 HP, damage / hit rate /
   absorb / evade 255) against the Lich and Tiamat on the Color and DMG. This found that the
   dissolve's cell count was E + (E-1) + .. instead of E x E (normal enemies lost 10 of 16
   tiles, fiends 36 of 64) and that the final clear used a normal enemy's position for a fiend
   (its robe stayed through the results); both fixed, and the names window is counted again
   once an enemy is gone.
   Open: party names "messed up after the inn save / a menu" not reproduced (names in RAM and
   on screen stay right through the inn save, the file screen and the menus, DMG and Color).
25. Owner (2026-11-23, real Game Boy Color and ModRetro Chromatic): the music broke after walking
   into Cornelia, and every song after. The owner found the cause: the town-entry wipe sound left
   square 1's hardware sweep on (NR10 = $1A), so every later note on that channel slid down. Fixed
   (wipe clears NR10; the music clears it at each square-1 note). Cornelia's peaks before: 64-387 Hz
   (the melody bent into the bass), after: 521 / 656 / 1037 / 1312 Hz. The triangle restarts each
   note again on the Color (legato on the plain Game Boy only). Name entry: a 6 x 10 grid so the
   whole hand fits before each letter.
26. Owner (2026-11-23, battle "up to par"; the owner chose from a list):
   - A swing per hit (at least 1, at most 8), each hit's burst on the target; "n HIT(S)" only after
     the swings, with the number.
   - The bottom message window only for what numbers cannot show (owner's pick): no window for
     plain hits / damage / misses / kills / "HP recovered!"; status effects, critical hits,
     ineffective, running away, victory and level ups stay (bt_quiet, bq_line / bq_num).
   - A top window (window layer cut at line 24, over the enemies and, with the sprites off for its
     lines, over the party) with the spell / enemy ability / item spell's name during the cast, and
     the target's name while one is chosen (hidden when the target stands under it).
   - Healing numbers in green (CGB OBJ palette 6; DMG OBP0); party lines yellow under a quarter of
     the HP, red when down (CGB BG palettes 4 / 5); every ailment named (Dead, Stone, Numb, Sleep,
     Mute, Conf., Blind, Poison; before, any ailment but death / stone read "Poison").
   - Room: the small font's glyphs (1 KB) and the acting enemy's flash moved to bank 104 (BTL6_BANK,
     src/btl6.s; bank-6 routines through x_* bank_call wrappers), level up / Chaos' death to bank
     6's freed space.
27. Owner (2026-11-23, later): names corrupted after "Who will carry it?" (Rienne -> RiRine), weapons
   not kept, the town transition breaking the message window and the place-name banner. One bug:
   `obj_anim` clobbered `obj_frame`'s slot count (B), so after a townsperson finished a step the
   object loop ran on through RAM (text buffers, font table, game flags, party records). Fixed by
   saving BC; a write watchpoint over a long town idle shows 396 stray writes before, 0 after.
   Also the battle name window's flags moved out of the map queue (walking overwrote them: sprites
   hidden and a junk palette under field windows). Weapons were never lost by saves: Inn save /
   Continue and Suspend / resume keep them (checked in SameBoy with a party made in the game).
   Battle: the target's name window at the bottom for enemies in the top rows and for the first
   member (was hidden there); SELECT turns it off / on (owner).
28. Owner (2026-11-23, last; "this game must be playable through normally"), fixed:
   - the prologue fades in from the boot logo's white;
   - gradient: the field windows repainted the map's palette 0 after Options (menus' copy left
     on), the music skipped frames with no colour records, quick Options presses were lost (the
     whole gradient rebuilt per press);
   - battle: EXP / Gil (the reward loop lost its counter through `pop af` and read leftover
     bytes of empty slots), no level ups at all (a fall-through broken by moving code), dead
     enemies erased in the wrong place and coming back, names / counts not updated after a
     blow, the weapon hidden in every swing (the hand-hide during tile uploads), the target
     window drawn over while shown;
   - the save screen cleared File 2's rows instead of the chosen file's;
   - the wipe sound shared square 1 with the music engine, and the next song's first notes were
     overwritten (the song now starts after the wipe opens);
   - the overworld bridge and canal were never drawn; the party's lower half hidden in forests.
   Checked by playing from New Game in SameBoy (grinding near Cornelia, the inn, saves): rewards
   equal FF1's sums, levels 2 and 3 reached. Saves made with older ROMs can carry flags / names /
   weapons damaged by the object-loop bug (item 27): start a new game.
29. Owner (2026-11-23, night), fixed:
   - dungeons used the overworld's encounter table (only FF1's 64 overworld domains were copied:
     Iron Golems in the present Temple of Chaos); all 128 domains now come from the ROM;
   - the battle name window flashed a message window of garbage between targets (`lcdc_on` set
     before the window's rows were up); the weapon now goes away after the swings, so it no longer
     covers the hit count;
   - intro: no line shows before its fade (both systems); plain Game Boy: square 2 notes never
     started (the triangle's legato path skipped the pulses' trigger);
   - gradient menus: the build took ~15 frames of a menu's load (the masked load's STAT guard held
     the CPU through modes 2 / 3 while it ran; a division per window and line; a coverage check
     per cell); now 3 frames, the menu shows on the same frame as without the gradient, event
     lists identical to the old build. Records on lines next to each other were lost when a
     handler ran late (the magic list's top in the window above's darkest colour): the STAT
     handler takes a reached record at once;
   - every window colour 0-31 on each channel (through the Options screen), 32 combinations (the
     cube's corners and 24 random ones, on the main menu and Items) and the field banner at 8
     extreme colours: the ramp equals the model of `gr_ramp_mk`, and each palette value shows as
     one screen colour on every line (cell palettes from the attribute map). Two timing faults
     found and fixed: the music ran inside the line handler with interrupts off, so a colour
     record after a short gap came a line late (line events may now interrupt the music; V-Blank
     still waits), and the music sat in the longest gap, so it could start late and run into
     V-Blank (a fade step a frame late): it now runs from the first record at or after line 64,
     after that record's colours, as without the gradient. Sound: the music registers equal the
     gradient-off run's frame for frame; only the cursor beep can start a frame apart, and with
     bright colours leaving a menu takes 1-5 frames longer (~40 colour records a frame cost CPU
     time while the menu fades out);
   - party creation: "OK to begin with this party?" no longer blanks the top row (a 5-row window
     between the rows of boxes; only the lower pictures hidden under it);
   - magic menus (owner): the field list shows one level a page (its MP above, its spells below,
     empty levels skipped); the battle list a level a column (L1 L2, MP, three spells each).
30. Owner (2026-11-24):
   - overworld: the bridge, canal and parked ship / airship anchored to the map (their sprites took
     only the whole-tile offset to the party; the scroll within a step is now subtracted);
   - sound closer to the NES on both systems: the music runs at the NES's 60.0988 Hz from the
     timer (TAC 4096 Hz; TMA with a fraction: DMG 188 + 40/256, Color double speed 120 + 79/256;
     604 ticks in 600 frames), ticks from line 124 on wait for the STAT line-64 event so V-Blank
     uploads are never held up; the triangle starts at its middle and (Color) stops there; pulse
     volume steps unrolled. Tools: `tools/gbn/sndref.py` (NES APU model reference from the NES
     ROM, SameBoy recording of the GB build), the SameBoy watch core's `SB_VCHK=1`;
   - data audit against the FF1 disassembly and the Japanese ROM: `tools/gbn/audit.py`,
     `docs/ff1-data-audit.md` (no wrong address, no damaged data);
   - Options: Auto Retarget (off by default: an attack or one-enemy spell on an enemy already gone
     goes to the first living one), holding A in battle selects quickly (18 frames, then a press
     every 6);
   - Options: **Modern MP** (off by default; `src/mmp.s`, `tools/gbn/modern_mp.py`). Dawn of Souls
     MP instead of charges. Data taken once from the FINAL FANTASY wiki and kept in
     `tools/gbn/modern_mp.py` (owner: in the repository, no downloads when building):
     spell costs ("Magic (Final Fantasy)", matched to spell ids by FF1's NES names), starting MP
     and strong levels ("Final Fantasy stats"), the rule ("Stat growth": floor(INT / 4) + 1 a
     level, +10-12 on a strong level or 1 in 8 otherwise; Knight / Ninja only after the class
     change, Black Belt / Master never). Each member's MP sits in the magic page at +$30 (current,
     maximum, a mark, the mode its MP is in); the maximum grows at every level up in both modes;
     a mode change converts by the same weighted fraction (charges weighted by the average cost of
     their level), after the owner's warning ("Switching between MP modes mid-game may leave you
     with more or less MP than usual. Is this OK?"). A save from before the option gets its
     maximum estimated (level, job, INT; Knight / Ninja from their charges). Shown: the battle
     party window's MP at the right of the HP (Poison shortened to "Pois." then), the battle
     list's header "L1 Cost n ... L2 MP m" (the hand's spell), the field Magic screen's
     "MP cur/max" and each spell's cost, the Status screen's MP. Inns / the House fill it.
     Checked from the town save (CGB and DMG): the switch both ways (3/2/1 charges -> 10/10 MP;
     5/10 MP -> charges 2/1/1), Cure twice in the field (10 -> 4), "Not enough MP." for Dia at
     4, Dia in battle (10 -> 5), a level up (Red Mage L2, INT 10: max 10 -> 13 in both modes),
     the estimate for a Red Mage L20 INT 30 (246, as worked by hand), and the battle list and
     party window unchanged with the option off.
31. Owner (2026-11-24, later):
   - Modern MP's Dawn of Souls data kept in the repository (`tools/gbn/modern_mp.py`): no downloads.
   - Battle: a spell's number and flinch went to whoever the previous attack hit (bt_effect never
     set df_player / bt_tgt: a spell on an enemy after an enemy hit a member showed by the member);
     effects, then numbers, then deaths (an enemy's death waits for its number's pop; the top window
     closes before an effect under it); healing: no hit reaction, green ink with the damage
     numbers' outline; enemy deaths: rows vanish in place (no sliding).
   - Sound: the clicks at volume steps found by recording each channel of every song (NES model vs
     SameBoy, DMG and Color) and counting samples that overshoot both neighbours: a step down was
     fifteen +1 zombie writes (the channel played every louder level ~30 cycles). Now two writes
     ($F7, $F8: verified on SameBoy DMG / Pocket / Color 0-E / GBA and Gambatte with a test ROM;
     the Color tests it at boot, mGBA adds 1 instead), the tick's volume applied with the note's
     restart, NRx2 and NRx4 3 cycles apart, $4015 off as volume 0 with the DAC on. All 24 songs:
     Color 4 marks left (note-start phase resets, as the NES), plain Game Boy 0-3 per channel.
   - New Game asks CLASSIC or MODERN (the owner's texts; Classic: charges, no retarget, cursor
     reset, no dash, no gradient; Modern: the opposite).
   - Options (Color): LCD Default / GBC Corrected / GBA Corrected (`src/cc.s`: a curve per channel
     and raised saturation, applied where a screen's own colours are written; fades work from the
     read-back palettes).
   - The airship's view (`src/air.s`, the approved mock-up): per-line SCY from a mode-0 STAT
     interrupt, a sky band (window; Color gradient, DMG shades and haze), blended with the ship's
     height, rows py-10 .. py+5 streamed, off in menus.
32. Owner (2026-11-24, last):
   - Raster spell effects on the target only (`src/fx.s`): the hit enemy's cells switch to copies of
     its tiles ($C4-$D7, $01-$11), each pass shifts the copies' pixel rows by the element (fire,
     ice, lightning, earth, others), the cells go back after the burst; group spells ripple each
     enemy in turn; fiends / Chaos keep the per-line scroll (alone on the field).
   - Magic shops: Buy / Leave first and after every "Anything else" (FF1's menu).
   - The hand shows only once its window is whole (the Color's gradient build ran before the check).
   - The confirm sound no longer hangs on one pitch while a Color load is masked (the timer's music
     tick was held to the load's end).
   - Super Game Boy packets: every pulse ~5 us (2 us dropped packets on a real SGB / exact emulator:
     after Garland the field kept the battle's colours and its box text was unreadable).
   - People keep facing the party while talked to; the battle target window is always at the bottom.
   - The window cut under the place banner / dialogue box lands in H-Blank (line 24 showed 144 pixels
     of the banner's next row).
   - Not reproduced (asked the owner for the system / enemy): enemy flashes broken, colourless menu
     borders on the world map (the SGB packet fix may cover it).
33. Owner's list (2026-11-24), continued:
   - Reflections on water (`src/refl.s`): on the overworld the party (or the ship) is mirrored in OAM
     36-39 when water is below it, the far row wavering; CGB palettes 4-7 are the sprite palettes
     darkened and tinted blue, DMG / SGB use OBP1.
   - Animated sea and rivers (`src/wanim.s`, `build.py water_anim`, bank 106): the commonest sea and
     river metatiles from the user's ROM, 16 phases made at build time, one upload every 8 frames in
     V-Blank (not under the airship view).
   - Super Game Boy: a border per region (world, town, castle, cave, sea, sky, Chaos, ice, volcano;
     `sgb.py REGION_COLS`, `src/sgbx.s`, sent with the screen frozen and SCX / SCY 0), the SNES's
     own sound effects (waves on the ship, wind in the airship; spell sounds in battle).
   - Smoother loads: the Color already loads behind a black mask; on the plain Game Boy a masked
     load costs ~4 times as long (71 against 12 frames), and its fades go to white, so the LCD-off
     white is kept there.
   - Extras on the title menu (`src/extras.s`, bank 107): a Sound Test (FF1's 24 songs, left / right,
     A plays) and a Bestiary. The Bestiary marks every monster a battle generates (bank 0 `bs_seen0`
     after `bt_prep`) in cart RAM bank 1 $BF80 ("BE", 16 bits, a check; cart RAM on only meanwhile),
     kept for every save file. The list names the met monsters; an entry draws the monster with the
     battle's own loaders from a formation that shows it (`battle.py bestiary_tab`, picked at build
     time: pure formations first), moves the tiles to $92-$FF (the font stays at $9000; DMG shaded
     as in battle, CGB palettes 1 / 2 from the formation), centres it (Chaos over the top 12 rows),
     and lists HP, Attack, Defense, Evade, EXP, Gil, Weak / Resist (FF1's element bits) and the
     traits Undead / Regen. Left / right step to the next met monster.
   - FF1's other category bits are not shown: the ROM gives Goblins / Ogres / Gigas the same bit
     ($04, the disassembly's "Giant") and Lizards / snakes the dragons' bit. The weapon data is
     out of step with them: Wyrmkiller carries $04, Great Sword $08 (Undead), Sun Blade $20 (Water),
     Coral Sword $10 (Were), Werebuster $41, Icebrand $02 (dragons). The native battle applies weapon
     categories (FF1's bug fixed), so these are the bonuses in play now. Owner (2026-11-24): keep them
     as the ROM has them. Smoother loads: fine as long as they keep the same length (so the plain
     Game Boy keeps its short white loads).
34. Owner (2026-11-24, later):
   - Colour correction (GBC / GBA Corrected) broke the battle's extra palettes: `bt_pal5` corrected
     16 of its 48 bytes and read BG 4-7 from the correction buffer's leftovers (the enemy flash as a
     blue square, the party window's low-HP / down lines in junk colours). All 48 corrected now.
   - Water as Final Fantasy Legend III's (studied in the owner's FFL3 ROM, motion only, FF1's own
     tiles): a pixel per 16 frames, the 16 x 16 picture's halves in turn 8 frames apart (sea:
     upper / lower sideways; river: left / right downwards, together when one tile fills every
     corner); 32 half steps.
   - Encounter transition made lovelier: two white pulses, a swirl (rolling ripple, drawn in to
     the party), lines parting while the picture folds onto the party's line into white (colour
     level per frame from a table). Its line handler reads page-aligned SCX / SCY tables by line
     (`hrx`, ~47 cycles a line): the plain Game Boy keeps one step a frame (it took two, and showed
     noise frames when a step ran late); the first frame no longer shows a broken picture.
   - Game over as FF1: game-over music, "<leader>'s party / were wiped out", any button, a fade to
     white, the title (fading in from white after a restart).
35. Owner (2026-11-24, last):
   - Water finer: four bands of 4 lines (river: columns) per 16 x 16 picture, each a pixel per 16
     frames, in turn 4 frames apart (order 0, 2, 1, 3): 64 steps; the build marks which tiles change
     at each step and only those are copied. Color frames in bank 106, DMG frames in bank 108
     (each with its own header).
   - Reflection more faded: on the Color each channel is 3/8 the sprite's and 5/8 the sea's main
     colour (taken by the build from the sea tile and its palette, through the LCD colour mode);
     DMG / SGB OBP1 light grey with a dark-grey outline only.
36. Playthrough from New Game without RAM pokes (2026-11-24; SameBoy, Color and DMG; driver in the
   session scratchpad: menu-driven shops by `sh_cur`, map / teleport / door data from the ROM, a
   foot + ship overworld path search, saved states per stage):
   - Done: party, Cornelia weapon / armour shops, levels outside Cornelia (inn, clinic), Temple of
     Fiends, Garland, the princess's warp, the King's bridge, the bridge story, Pravoka's inn,
     Bikke's pirates, the ship given ("I'll give ya my ship").
   - Then: Elfheim by ship, its shops (weapon / armour upgrades, Heal and Pure bought and used on
     the field), levels 6-10 outside Elfheim (135 battles, inns, Pure curing poison), the Marsh Cave
     down to the Crown's floor (map 28), FF1's guard tile in front of the chest (formation 28, four
     Piscodemons) and the Crown taken. At level 10 the party won but lost three members and fell on
     the way out (FF1's game over, back to the title); being redone at level 13.
   - Then (all as FF1, checked against the disassembly where it looked odd): the Crown at level 13,
     Astos at 14 (a Fight-only party cannot beat him at 13: RUB / DARK, absorb 40; the battle RNG is
     per use, so waiting does not change a fight), the Crystal (the Crown stays), Matoya's Herb, the
     Elf doctor and prince (Mystic Key), the locked rooms (Elf castle, Cornelia: TNT), the princess's
     Lute, Nerrick and the canal, Melmond, the Earth Cave down to the Vampire (beaten at 15) and the
     Star Ruby. Spell deaths keep their HP (FF1's BtlMag_ApplyAilments). Melmond has no clinic or item
     shop (the ROM's shop table). The inn's save screen offers the last file used.
   - Stopped at the Earth Cave's way out: the test driver only fights (no spells, no items in battle)
     and its party (absorb 16 on three members) is wiped by B3's random battles at level 16-17.
     No game bug found since Bikke; the driver needed many fixes (shops, exits / warps, locked
     doors, encounter transitions, entrance tiles).
   - Found and fixed: the sound variables ran past $CFFF into the save page (ship / airship flags
     and the ship's position rewritten by the music: Bikke skipped the ship); `vh_t` shared the
     shop's `sh_id`. The assembler now guards the save page (`PROTECT_RAM`) and lists RAM sections.
   - Checked, not bugs: "Had no effect" when several members hit an enemy already dead (FF1, Auto
     Retarget off); a party wipe at sea at level 3 goes to FF1's game over and the title.
37. Owner (2026-11-24, later):
   - playthrough stopped at the Earth Cave (the test driver gained battle Medicine and running from
     paralysing / stoning / killing formations first);
   - DMG / Pocket music (real hardware: volumes / fades and timing differed from the Color): a plain
     Game Boy now steps a volume down only by $08 writes (fifteen adds = one step down, LSDj's way
     on every DMG) instead of the $F7 / $F8 pair (the mode-change rule, tested only on the Color).
     SameBoy: tick counts equal on both systems (4347 / 4346 in 4320 frames of walking and battles).
     Tried and reverted: running a held tick right after the V-Blank handler's uploads (less jitter)
     took the plain Game Boy's V-Blank time from the window-row streamer (battle windows cleared a
     few letters a frame); held ticks run at line 64 again;
   - polish: the main menu's member text from column 3 (picture at x 7): the command hand no longer
     covers the last HP digit; the shop's party preview values end at column 18 (a six-letter name
     no longer runs into "Full" / "Can't use"), its heading over the values; the Magic screen's empty
     slot gives the error sound only (it showed FF1's "use it in a place like this?" message); the
     Formation menu's pictures fade in with its window (they appeared after the fade);
   - the Konami Code (Up Up Down Down Left Right Left Right B A) on the Formation menu (the B held
     back, the A used up; FF1's magic sound) marks the file (save page $F8 = $A5): Options then show
     LCD (Color) and EXP / Gold multipliers (Normal, 2X, 4X, 8X, 12X; $F9 / $FA in the save page,
     applied to the battle's sums, kept at 65535). Without the mark the LCD option is hidden and the
     colours Default (on loading a file and at New Game). Options are a table-driven list now (id,
     variable, range, value column and format) that scrolls: 7 / 9 rows on a plain Game Boy, 11 / 14
     on the Color (12 shown).
38. Owner (2026-11-24, last): "check all existing screens against colour corrected screens".
   - Method (scratchpad `pt2/cc_tour.py`, `cc_boot2.py`, `cc/cmp.py`): the same tour three times in
     SameBoy with its own colour correction off (`sbsh` env `SB_CC=off`: raw RGB555 in the shots),
     the LCD mode chosen in Options (Default, GBC, GBA Corrected); every Default shot mapped through
     the correction (cc.s's curve and saturation, bit-exact in Python) and compared pixel by pixel:
     each difference is a colour that skipped the correction or got it twice. Tours: town, main
     menu, Items / Magic / Equip / Status / Options, Formation, a shop, the overworld, the world map,
     an encounter and a battle; a soft reset (prologue, title, file select) and a file without the
     Konami Code loaded after it.
   - Fixed: the menus' green / red / gold / grey label colours (`eqm_pal`'s colour 3 came straight
     from the NES table; now corrected, all four made before the palette writes, which wait for
     V-Blank when the LCD is on; its body moved to bank 99); the prologue's colours (`pr_rgb`), the
     battle flash's (`x_nes_rgb`) and the airship's sky (`ap_sky`) were never corrected; the hand's
     colours now change with the LCD mode in Options at once.
   - Fixed (all modes): screens never wrote the windows' palette 7 themselves and kept the last
     screen's; `text_pals` wrote straight to palette RAM, so a masked load put the colours its
     fade-out kept back over it; and a skipped fade-out (FF1's palette cycle before a menu) left an
     older fade's colours to be used. Every screen (`scr_open`) and map load now writes palette 7 /
     5 from `win_pal` through the shadows; the skipped fade-out keeps no colours. This is the likely
     cause of #81 (menu borders without colours after the world map: palette 7 left as the world
     map's), not reproduced exactly.
   - Fixed: loading a file without the Konami Code (and New Game) set the LCD mode back to Default
     but kept `win_pal` corrected for the old mode (menus stayed corrected): it is made again.
   - Checked: after the fixes every screen of the tours matches the computed correction exactly in
     both modes (the rest: the Options value text, people walking, the water's phase).
39. Owner (2026-11-24, last): "finish the polish sweep". Tours (scratchpad `pt2/pol/`): dialogue (townspeople
   in Melmond on the Color, Bikke in Pravoka on a plain Game Boy; a talker that follows moving people),
   battle magic (spells poked into the Red Mage, only her turn's frames kept: Fire / Cure / Blizzard),
   whole battle rounds checked every second frame by a pixel test (names window empty, a window's
   sliver at the top), magic / white / weapon shops and the inn, two dungeons (Earth Cave, Marsh Cave).
   - Fixed: the battle's top name window closed mid-frame, leaving a sliver of its border on the
     lines already drawn (now closed in V-Blank); the enemy names window showed empty for a frame or
     two when it was redrawn (each name's tiles take a frame) and after a message closed (the rows
     below were shown before the names were back): the names are drawn first, then shown.
   - Fixed: the magic shop's party rows ran six-letter names into "Can't learn" (status from column
     9 now, with the equipment shops' "Can't use"); shop speech is re-flowed to the 18-column window
     when that saves lines ("Which magic will / you be learning?").
   - Checked, as FF1: a member paralysed during the round still carries out the command chosen
     before; attacks / spells on an enemy already dead "Had no effect" (Auto Retarget off); the
     screen shakes when an enemy's hit lands. Remaining transition: the message window's rows come
     in top-down over two frames when it opens.
   - Harness: parallel runs overwrote each other's shots (named by mode and frame): shots now carry
     the process id.
40. Owner (2026-11-24, last): "continue polish".
   - Super Game Boy: the party's pictures on menu screens (party creation, main menu, equip / status
     headers, Formation) in their job colours. A sprite takes the colours of the cell under it, so
     they showed in the windows' white / grey; each picture placed by scr_spr23 (up to four a
     screen, keyed by its sprite slot) gets the battle's palette for its job's FF1 sprite palette
     (SGB palette 2 / 3, darkest colour = the window blue), sent with an attribute block when the
     screen is shown and again when a picture moves to other cells (Formation) or changes job.
   - Bestiary: Left / Right turn a page (the list moves 13 rows, the hand keeps its row); Sound
     Test: the hand before "Song", as the other lists.
   - Checked: the ending from a Chaos test battle (`build.py --battle 123`, his HP poked) on the
     Color and a plain Game Boy (dissolve, epilogue pages with their shutters); the Extras screens
     and Bestiary entries on both; SGB battle colours unchanged.
41. Owner (2026-11-24, last): "polish the text formatting and appearance of all text boxes and their
   text". Audited every text offline as the build lays it out (tools/gbn/text.py), then on screen.
   - Dialogue (text.layout_pages): pages made of whole sentences, as few pages as the text needs, their
     sizes even; each page wrapped with balanced breaks that keep the greedy line count: no lone short
     last word (45 texts had one), lines end at sentences' ends where that costs little, no line ends on
     a new sentence's first word. No page holds a single leftover line any more (31 did). Where the
     translation ends a sentence with a line break and no punctuation before an opener ("...in the way /
     At this rate..."), the break stays a line break: no words added (text.paragraphs, _sentence_break:
     openers, "I" unless after a conjunction, signs in capitals; names keep their sentence).
   - Story pages: balanced lines, centred in the window's 12 rows both ways; prologue lines balanced;
     shop speech and the menu texts (item use, descriptions, prompts) laid out the same way (templates
     and FF1's deliberate breaks kept: SHOP_KEEP).
   - Item / magic target window: the name from column 3 with HP / max at the right, the job or ailment
     below, the hand before the name (it sat on the job line and covered the next member's first
     letter; the level dropped there, as FF1's own target screen).
42. Owner (2026-11-25): pre-battle ailments, the White Magic icon, criticals, ailment icons, doors,
   glitches after big formations, then a new ROM.
   - Poison (or stone) from before a battle showed as "Dead": the outside values (1 dead, 2 stone,
     3 poison) were read as battle bits. `bt_ail_in` turns them into bits before anything is drawn.
   - Doors: every closed / locked door metatile is drawn open while the party is inside a room
     (`door_st` in `q_mt`), also after a warp; `room_redraw` on the Color redraws the door cells.
   - White Magic icon in battle: the one-colour battle text inked both of the icon's colours, so the
     orb came out a white blob. In battle names it is font code 2, the orb with its shine left out
     (text.py; `bt_mname` swaps the code).
   - "CRITICAL!": a gold label (battle.py, after the hit labels) beside the member concerned (the
     attacker; the member hit when an enemy struck), shown for 40 frames (A skips), then the hit
     count and the damage number as before; it replaces the "Critical hit!!" line (`bt_critlab`).
   - Ailment icons (our own pictograms, battle.py AIL_PICT): each living member with an ailment shows a
     round bubble in front of its sprite (OAM 28-31; several ailments take turns every 64 frames,
     the worst first; green for poison, gold for numb / confused, white for the rest). A bubble's
     tile is the lying pose's last tile (32 m + 31), handed back when the member dies (`bub_tick`,
     bank 104, every battle frame through `bt_fhook`). The party line shows the icon before the
     status word (small-font codes $8C-$93).
   - After bigger formations (several level ups): the results window's second page wrote its text
     into the first page's tiles while those still showed (jumbled lines): the window is shown empty
     first (`res_pgw`). A message closing let the names / commands be written into its rows' tiles
     while it still showed ("Goblin Guard 4d / Had no effect"): its text is blanked first
     (`msg_blank`, both close paths).
   - Tools: `GBN_GAPS=N build.py` lists the free runs of code bank N (the assembler now returns the
     bytes it claimed).
43. Owner (2026-11-25): "The ocean stops and restarts without holding its last known position" and "Add
   the ocean effect to tiles in towns". Tested in SameBoy, Color and plain Game Boy (scratch scripts:
   each water tile's VRAM matched every frame against the build's pictures, screen brightness, the
   VRAM/OAM checker).
   - Cause: the water's step came from the global frame counter, and every map load (also the reload
     after a menu or a battle) put the tiles back at their first picture; FF1's palette cycle showed
     that picture for ~60 frames, then the water jumped to wherever the counter had got to.
   - The water keeps its own step count (`wa_t`), advanced only while water shows, so menus, battles
     and loads hold it. `load_map` draws every water tile at that step while the LCD is off or masked
     (`wa_drw` -> `wa_load`, bank 99, through `far_copy`), so the first picture is only ever in VRAM
     on black (Color) or white (DMG) load frames. Checked after the main menu (town and overworld)
     and after a battle (overworld): the step shown before is the step shown after, then it goes on.
   - The first version kept `wa_t` / `wa_ok` / `wa_full` at $C6E8, inside the field's metatile queue
     ($C100-$C8FF): walking wrote over them. Now at $CFB8 (fixed RAM after `ly_tab`).
   - Towns (maps 0-7, tileset 0): the water tile ($0F; DMG: the map's pre-shaded copy, used only by
     water metatiles 39-41 / 59, inside rooms too) moves as the sea: two bands of 4 lines, a pixel
     sideways per 16 frames, 8 frames apart (`wa_town`, `wt_cp`; `build.py town_water`, bank 109).
     A new picture every 8 frames; nothing else in the tile data changes.
   - Plain Game Boy overworld water (wrong since item 33): the V-Blank handler leaves the water lines
     148-153; each slot test cost a line and a copy passed at line 151 started at 153, so copies ran
     into line 0's mode 3 (SameBoy: 184 dropped writes per 200 frames, half the frames with sea
     corners at different steps). Now the build lists each step's copies (`$6200 + 16 step`: the
     tiles that change, a tile shown at several corners once; `$6600 + 32 step`: every tile, for a
     redraw) and `wa_run` tests LY right before each copy (start by line 151). The sea and river are
     never torn within themselves on either system (DMG: the river sometimes a frame after the sea);
     a step left unfinished is redrawn whole at the next.
   - Battle (plain Game Boy, older than this work): `bt_vbl`'s tile uploads ran into line 0's mode 3
     when the music timer cut in at line 153, whose LY reads 0, so the tick ran there (~10 lines).
     Ticks read at LY 0-1 are now held to line 64 like those from line 124 on (`tm_late`), and
     `bt_vbl` starts a tile by line 151.
   - VRAM/OAM checker 0 on Color and DMG over: the town (motion, menu), the overworld (motion, menu,
     a battle and back). No lag frames in the town (1200 frames, `wa_tick` every frame).
   - Tools: `build/sbsh` `v` now reads the count from a SameBoy core built with
     `tools/gb/sameboy/sameboy-ffe.patch` (dropped VRAM / OAM writes with bank:PC and LY; `SB_PCLOG=
     addr,..` prints LY whenever code reaches those addresses).
44. Owner (2026-11-25, later): water in castles and caves; a polish pass on every menu, GB on par with CGB,
   audit first. Audit and proposals: `docs/ff1-menu-audit.md` (FF1's castle / cave maps have no water tiles;
   faults, DMG / SGB parity and polish items, waiting for approval).
45. Owner (2026-11-25, later): "W2, and do all of A, B and C" (the audit, `docs/ff1-menu-audit.md`, with each
   item's outcome), then name entry presets, CRITICAL! with the number and spaced from it, and the Sound
   Test code. Checked in SameBoy on Color, plain Game Boy and Super Game Boy, VRAM/OAM checker 0.
   - W2: the world map's waterfall (the one metatile whose two tiles only it uses, found at build time)
     falls a pixel per water step, copied two frames after the step (bank 109 $6C00).
   - A / B / C: see the audit file. Not faults after a look: A5 (a lying member's rows end above the next
     member's), A6 (CLASSIC sets the gradient off by design), C25 (FF1's map mark blinks). B15 (SGB black
     outside the windows) backed out: a frame cell holds outside and inside pixels and takes one palette.
     C17 as one line an entry plus an info window (39 of 71 shop entries are too long for name and price
     on one line). C24 left as is. On the DMG White window option the lit orbs show dark (inverted shades).
   - Name entry: Start with no name types one of the job's preset names (owner's lists; base and promoted
     jobs share one; never the same twice running); Start again accepts it, B clears it whole.
   - CRITICAL! shows with the damage number (OAM 28-31, tiles $EC-$EF), a line below what it would cover:
     a member's critical under its hit count (both by its head), an enemy's critical on a member under the
     bouncing number (`crit_y`, bank 6 $7EB5).
   - **The Sound Test code** (owner): songs 1 9 9 2 1 1 2 4 played in a row (the magic sound confirms)
     arm it (`sc_arm`); the next save loaded, a file or the suspend point, gets `SC_MARK` ($5A, save page
     $FB) and the Konami Code's `KN_MARK`. On such a file: EXP and Gold multipliers Normal, 2X, 4X, 8X,
     12X, 24X, 48X, 64X, 128X (`kn_mul`, a capped 16 x 8 multiply, kept at 65535); Options 'No
     Encounters' On / Off (save page $FC; `enc_step` still counts the step, the roll never fights; story
     battles on fixed squares stay); the main menu's Suspend reads Save and opens the file screen: the file
     as an inn's save plus the exact place (the suspend point's blocks: position, map, objects, vehicles,
     the save page) in cart RAM bank 2 at $A000 + $600 x file, with its own sum. Loading that file resumes
     there (as a suspend point, kept for later loads); an inn's save over the file drops the place. The
     suspend routines take a cart RAM bank and offset (`sus_bk`, `sus_bo`; 0 = the suspend point).
     Checked: code entry, resume, Options (128X, No Encounters), Save in Cornelia Castle, walk away, soft
     reset, Continue, File 1: the party back on the saved square; overworld walk: 1 battle in 5 rolls
     without the option, none in 8 with it.
   - **Fixed (older than this work): cart RAM switched off by the music.** `snd.s` (`aw.fv`) kept a note's
     volume in B, the high byte of BC = the frequency shadow's pointer; the write through BC went to
     $06xx-$0Fxx, the MBC's RAM enable. Cart RAM went off at every note start: the title never saw a
     suspend point (its check runs with the title music), and any save or load running across a note
     could read $FF or lose writes. Found with a SameBoy write watch on $0000-$1FFF. The shadow is now
     right too; register writes differ from before only in two restarts at volume 0 (no audible change).
   - RAM overlaps from this session's additions fixed (`tools/gbn/rammap.py`, new): the battle name
     window's flags on the shop's `sh_id`, the place-name buffer on the Suspend's and name entry's
     variables, the preset's last name on `crit_on`; the Options list holds 16 ids.
46. Owner (2026-11-25, last): the DMG map shifting after talking, the shop hand over the icons, a blank first line
   in the price question, 128X EXP stopping at level 2, spell descriptions for the magic shops.
   - Plain Game Boy: while the dialogue box (or the place-name banner) showed, every line below it was one pixel
     to the right (SameBoy; the Color unaffected). The box's window was cut below its last line by clearing LCDC
     bit 5 in H-Blank. It is now hidden with WX = 167 and stays enabled until `box_vbl` switches it off in
     V-Blank (stat_int `.hb`). Lines below the box and the banner match the map exactly on DMG, SGB and Color.
   - Shop list: icon at column 2, name from 3, the hand in columns 0-1 (it covered the icons). A spell's level
     moved from the row's end to the info window ('Level n' on the Own / Worn row, magic shops). Names there are
     at most 16 letters (`sh_iname`, bank 99): 'Mythril Gauntlets', the one longer name sold, shows as
     'Mythril Gauntlet' in the list and the count window.
   - The price question ('30 Gil, see. / All right? / How about it?', after the inn's offer and every
     purchase) began on the window's second row; now the first.
   - EXP multipliers: FF1 levels a member at most once a battle, so 128X stopped at one level per fight. On a file
     with a multiplier code (KN_MARK, EXP not Normal) `lv_all` (bank 104) repeats the level check while the
     experience reaches the next level; the results record sums the HP gain (16-bit, `res_hph`) and ORs the stats
     raised. A level-1 party reached level 17 in one battle at 128X (experience per battle stays capped at
     65535, the reward's 16 bits). The stats raised take a row of their own in the results (all five fit).
   - Spell descriptions: two proposals, all 64 spells each, in `docs/ff1-magic-descriptions.md` (the owner's
     format and mine); waiting for the owner's choice. Found on the way: Shapera's data, as FF1's, raises the
     enemies' evasion (a known FF1 bug); not changed.
47. Owner (2026-11-25, last): "Yes, fix all spell bugs. Format B."
   - Spell bugs (the disassembly's BUGGED notes on magic, checked one by one against the native engine):
     already right in the native engine: HARM on members (FF1 took the class as the category: Master /
     Wizard counted as undead), Strike / Saber on members (FF1 never loaded or saved the attack), Saber's
     hit bonus (FF1 wrote it to the wrong place; the data gives 0 anyway), Shape (FF1's JMP for BEQ: it always
     missed), Dispel and the barriers on enemies (FF1 read the resistances from ROM and never saved them),
     a confused enemy killing itself (the native turn loop checks the battle's end after every turn), Silence
     stopping items (native: Magic only). Fixed now: Slow on a target already at its least shows no effect
     (FF1 marked it as working); Shapera's data (FF1, Japanese and US alike: the evasion-UP effect $10 on all
     enemies) gets Shape's evasion-down effect $0E at build time (`battle.magic_data`, only when the bytes
     are as found).
   - Magic shop descriptions, format B (`tools/gbn/spelldesc.py`, ROM bank 120 `SDESC_BANK`; the build
     checks no other data lands there): the speech window shows the spell's description at once whenever
     the hand moves in the list (`sh_lvl`, after the info window's Level row). Saber's text is 'Attack +16'
     (its data gives no accuracy). Checked on Color and DMG in the White Magic shop; VRAM/OAM checker 0.
48. Owner (2026-11-25, last): outlines on the party's pictures (from the mock-up: black removed, a 1-px black outline,
   rounded corners), the owner's icon set for items / weapons / armour, and the Super Game Boy's blue windows black.
   - Super Game Boy battles were in the menus' colours (blue field, grey sprites) since the audit's B12: the battle starts
     from scr_open, which switched the gold-label pass on, and scr_show then sent the menus' palettes after the battle's.
     `sgb_btl0` switches the pass off and clears its flag (on the plain Game Boy the pass could also have drawn into
     battle tiles $C0-$FF).
   - Icons (`names.OWNER_ICONS`, the owner's drawings): item (bottle), sword, hammer, knife, axe, staff (staves and rods),
     nunchaku (FF1's claw type), body armour, clothes / robes (new code $0F), shield, helmet, gloves, ring / bracelet.
     Key items and white / black magic keep theirs.
   - Outlines (`src/ul.s`): the outline is drawn in the background under each picture: window-inside pixels next to a
     sprite pixel (four sides only) turn black, in cells with tiles of their own, worked out from the sprite tiles in VRAM.
     Rebuilt at scr_show and whenever a picture moves or changes (Formation swaps, job list, Equip member changes); a cell
     the screen drew again meanwhile keeps the new drawing. Color: VRAM bank 1 tiles $80-$FF, palette 7's black; plain
     Game Boy with White windows: tiles $94-$BF and $E0-$FF (gold-label glyphs now $C0-$DF), black = the pre-shaded font's
     index 0, and the sprites there in the lighter shades used on black. Black windows (plain Game Boy, Super Game Boy)
     need nothing: the see-through parts already show black. Checked: main menu, Equip, Formation (swaps), party
     creation, job list, name entry on Color and DMG White; VRAM/OAM checker 0.
   - Super Game Boy windows black: a picture's cells hold four colours (the shared one and three), so a coloured window
     and a black outline cannot both show there; with black windows the pictures read as on the other systems. The SGB's
     window colour settings left its Options list.
   - Battle: the field is black on every system, so the sprites' see-through parts already show black; no change.

49. Owner (2026-11-25, last): "Black Magician job looks awful in the white background. It should have two 2px high eyes,
    surrounded by black." The Black Magician's face (the shade under the hat, the two 2-px eyes in it) is see-through in
    FF1's sprite and open to the outside below the brim, so the outline alone left it in the window colour. The outline
    now starts from the figure's filled shape (`ul_fill`, src/ul.s): every see-through pixel with sprite pixels left and
    right of it in its row and above and below it in its column is black too, as on the NES's black background. That
    gives the black face around the eyes, and the narrow gaps in the other jobs' robes and arms go black the same way;
    the outer edge keeps its 1-px rounded outline. Worked out at run time from the sprite tiles (any pose); 24 rows of
    bit masks, no table. Checked: job list, party creation, Formation, main menu on Color and DMG White; VRAM/OAM
    checker 0.
50. Owner (2026-11-25, last): main menu "MM-A" (from `docs/ff1-mode-menu-audit.md`), and "be certain that the game
    would pass even the most stringent and picky of lot checkers"; then "Message Speed" -> "Battle Speed".
    - Main menu: the command window from column 10 over the party window's edge, labels from column 13 so the whole
      hand is inside it (Items / Magic / Equip / Status / Order / Config / Quit; Save with the Sound Test code), a
      seventh command Order (FF1's lineup, also Select on the map), the orbs in a 6-row window, START closes the menu
      as B does, the command cursor kept between openings, members under a quarter of their HP in gold and dead /
      stoned members in red on the Color (grey ink on DMG / SGB), as in battle (menu.s, loc.s mm_wins / mm_hpc).
      The Options screen is titled Config to match.
    - Wording (Lot Check 4.1): "Hold the B Button to dash.", "A Button" / "B Button" in the translation's yes / no
      prompts, "Control Pad: song", "Inns or Cottages", "time in Config.", the Suspend question's "power".
    - A strict checker in SameBoy (`SB_LCHK=1`, `tools/gb/sameboy/sameboy-ffe.patch`) and what it found and what was
      fixed: `docs/gb-release-checks.md` "Strict checker". Also: soft reset from every frame wait (fades), the four
      buttons let go before the restart, opposite directions filtered, the SGB border transfer with scroll 0.
    - "Battle Speed" on the title menu and in Config (the setting is FF1's battle message speed).
51. Owner (2026-11-25, last): "I picked A" (Classic / Modern, `docs/ff1-mode-menu-audit.md`): one Game Style screen
    with a live description of the highlighted style; checked on Color, DMG (Black / White windows) and SGB with the
    strict checker (0 findings, VRAM / OAM 0).
52. Owner (2026-11-25, last): "Center the Game Style and prompts." The header, the two styles (the hand before them)
    and each line of "OK to begin in / ... style?" centred; the description stays left-aligned. Then "Nintendo-ify the
    Job selection and Job Picker screen": proposals in `docs/ff1-job-screens-proposals.md` (waiting for the owner).
53. Owner (2026-11-25, last): "P-A, K-A, N" for the party / job / name screens: built (src/pgen.s, bank 110); the job
    picker marks the job with the hand instead of a cheering pose (outline rebuilds too slow with the screen on).
    Details: `docs/ff1-job-screens-proposals.md` "Outcome".
54. Owner (2026-11-25, last): "Sometimes, battles take an exceptionally long time to start. Especially outside
    Elfheim. And when they do start, they look like this" (Analogue Pocket, Color mode: garbled party window, a salmon
    block with mirrored letters over the enemies); then "Battle results softlocked on DMG during a battle" and "Make
    certain to address ANY glitch that would cause ANY loading or softlocks during ANY battle". Causes found and fixed
    (lessons: `docs/gb-lessons.md` "Waits that must always end"):
    - **Slow starts and the garbage (Color):** the picture-outline builder (item 48, src/ul.s) also ran in the battle's
      `scr_show` / `scr_upd`, with its counts left over from the field's metatile queue and its cells in the battle's
      own tables. It worked through hundreds of garbage pictures a VRAM byte at a time (each access waiting for a free
      line in the masked load) and stamped outline cells over the enemies. Reproduced outside Elfheim: 1305 frames from
      the encounter to the first command, now 153 (92 for the next one). The battle's reset (`sgb_btl0`) clears the
      outline state; `ul_chk` refuses out-of-range counts.
    - **Hangs (DMG):** map-row, tile and flash-row uploads ran only inside a V-Blank window that the plain Game Boy's
      battle frame almost never reached (the frame wait returned at line 148): the results and other waits for them
      never ended. Every such upload now falls back to byte-by-byte writes in mode 0 / 1 (`vput`, `row_safe`,
      `row_put`), so it always progresses; the typed letter queue too.
    - **Wrong tiles (Color):** the V-Blank handler changed the VRAM bank under the code it interrupted (attribute rows
      landing in the tile map, its own rows in the attributes); it now keeps the interrupted bank.
    - **Fades (Color):** a fade step waited for "a V-Blank with room" again and again while the handler ran long; it now
      takes the next V-Blank's first line before the handler (`vb_top`), also in the party / name screens' row pushes.
    - **LCD off:** the frame wait and the LY waits return at once with the LCD off (no V-Blank would ever come).
    - **The battle's top window** gets a frame limit and then writes its rows itself (`box_fb` / `box_safe`).
55. Owner (2026-11-25, last): "Nintendo-quality the sequence of going from the naming screen to the world map"; the
    airship / ship / canoe corrupted on the world map; reflections faded in and out, with care at the sides; "one,
    unified palette logic that the game calls for every scene" (shop menu borders blown out); Options in submenus
    plus suggestions. Done:
    - **New game into the world** (src/pal.s ng_out9 / ng_in9): the party screen fades out slowly (8 levels on the
      Color, 3 shade steps on DMG / SGB) while the music's master volume goes down with it, a moment of silence on
      black (white on the plain Game Boy, its switched-off screen), then the world map fades in slowly as the
      overworld theme starts. The party's sprites are made before the fade-in (the vehicle is set after the load).
    - **Parked ship / airship**: their tile base was overwritten by their screen y (`.obj` in make_oam), so they drew
      other tiles at every step.
    - **Palettes** (src/pal.s): the Color's 16 palettes live in shadows (sh_pal BG, pal_ob OBJ); every scene writes
      them through bcps_w / bcpd_w, ocps_w / ocpd_w (pal_blk, text_pals), never the hardware; the V-Blank sends the
      changed halves first (pal_up, deferred if the V-Blank has no room), lcd_on sends all; fades and the encounter
      transition show a scaled copy (fd_tmp, pal_fd) and never read colours back from the screen. The old fade-out
      and masked load read the hardware, catching the gradient's line colours and half-way fade colours as the
      windows' colours (blown-out borders); and writes from the main code landed in drawing time (checker).
    - **Reflections** (src/refl.s, bank 111): three strengths blended into the sea (Color) or lighter OBP1 (DMG /
      SGB), the faintest every other frame (see-through); the strength rises while some part shows and falls when
      none does; each sprite only over an 8 x 8 quarter drawn with open water (REFL_WTAB, made at build time from the
      map's own sea and river tiles), so it slips into the shore in any direction exactly where the water is drawn;
      mirrored about the party's foot (in a forest the legs are hidden but reflected).
    - **Config pages**: Battle Speed, Text Speed, Volume, then Controls / Window / Game pages; proposals for new
      options in `docs/ff1-options-proposals.md`. Volume always showed 0: fixed.
    - Found on the way: on the Super Game Boy, opening a shop or menu while an ambience sound played jumped into RAM
      (ap_stop clobbered pc_menu's HL: crash since item 33); a stray music score pointer read disabled cart RAM
      (mrd returns $FF outside the song data); two row copies tested LY before disabling interrupts (an interrupt
      between them pushed a row into drawing); the big-target raster spell on DMG stored tiles over the gradient's
      flags (the Color's line handler ran on a DMG).
    - Checked with the strict checker: all 128 formations on Color, DMG and SGB (0 findings), random play from the
      field on all three, the new-game sequence on all three.
56. Owner (2026-11-25, last): main menu: the command's hand moved when a second hand appeared (member choice), better
    centring, and no transition when backing out of the member choice. The parked hand was drawn at column 12 (the menu
    draws it at 13): now 13, exactly where it was; B from the member choice returns to the commands on the same screen
    (pick_char puts its second hand away; no redraw, no fade); the party's pictures moved one pixel right (x 8), off the
    window's frame line: gaps to the frame now match the HP figures' on the right.
57. Owner (2026-11-25, last): text shadow (owner chose the suggested one): on the Color a 1 px shadow down and right
    of every letter (text.font_banks bakes it into the Color font in colour 0), and the windows' colour 0 is the window
    colour at a quarter (pal.s wp_dark): darker than every line of the gradient, any Config colour; the frame's outer
    line and the picture outlines take that near-black. The plain Game Boy keeps its black / white text (no gain).
    Also: "slight lag" on menus after the palette rework: loops that waited for the V-Blank and then wrote colours now
    write them first (the shadow is sent in that V-Blank, as the hardware writes were): FF1's colour cycle, the
    encounter transition, the world map, the prologue fade. The main menu now opens and closes with the screen fades
    every other screen uses (no colour cycle, shorter black). A frame of full-colour gradient under black palettes
    before a fade-in removed (gr_dark). Shop: a window under another (shared border row) started its gradient 3 lines
    early, inside the upper window: each window's gradient now starts 3 lines into its top row.
58. Owner (2026-11-25/26): a list of fixes, each checked in SameBoy on the Color and the plain Game Boy (strict
    VRAM / OAM checker 0, random play 4 x 20000 frames 0).
    - Window colour: the Color's default is the NES window blue (text.py WIN_BLUE); Config, Window page: "Return to
      Default" (window colour, gradient on, LCD mode Default, the Game Boy's windows black; A only).
    - Modern MP: no question when it is switched (the party's MP is converted in proportion: nothing is lost).
    - Select on the map shows the next member who is not Dead / Stone (SHOW_WHO in the save page, unsram + $FD);
      the leader stays; Order keeps the person shown. The new picture is drawn into the map queue's ring and
      copied in V-Blanks with the party's sprites hidden for those frames.
    - Bestiary: holding a direction, the list's rows are redrawn in place (rows 4-16) and the next scroll waits
      for them; the hand stays (sf_hk).
    - Doors: the door closed on leaving a room is the last door stepped on (a stale door from another floor was
      drawn after stairs up).
    - Music: boarding / leaving the ship or canoe changes the song (ow_cmm).
    - Canal: on foot its land walks as a bridge until it is blasted (FF1 IsOnBridge -> IsOnCanal).
    - The parked ship / airship sits on its tile as FF1 draws it (3 lines below the party on foot).
    - Reflections on the overworld are cut to the water pixel by pixel (coasts too): the build makes a water mask
      per metatile quarter and pixel row (Color and plain Game Boy each from their own pictures), a whole-quarter
      table, and the party's overworld pictures pre-shaded for the plain Game Boy; each frame the four mirrored
      sprites are whole, hidden or masked into free sprite tiles $70-$73 / $74-$77, uploaded in the V-Blank
      handler right after the OAM copy and switched only once all are up (src/refl.s). Nothing is redone while
      nothing moved.
    - Battle: the target hand sits left of a fiend's / Chaos's picture at its middle (the fiend's own extent
      from its TSA); a fiend's defeat lasts about 3.3 times as long (8 flashes, 8 frames a dissolve step); the
      party lines show "HP/word" with no icon (the bubble by the sprite shows it).
59. Owner (2026-11-26), after the release: towns and the packs.
    - Towns' canal in shadow (tileset 0's shadowed water tile and the corner where the shadow meets open water)
      moves with the water; the corner keeps its edge (build.py town_water2, bank 112; src/wanim.s wt_cp2, each
      tile copied only while the V-Blank lasts).
    - Reflections in towns (maps 0-7): the water there is whole tiles, so a water flag per metatile quarter is
      the mask; per town the first 8 sprite tiles no object, font or map tile uses (none in Onrac: only sprites
      wholly on water show there); OAM 36-39 are left to a ninth map object when one shows; the Color blends
      towards the town water's colour. On the plain Game Boy the masks are kept a frame when the frame is
      already late (a step's end), so no frame is lost.
    - Packs (src/packs.s, bank 107): from the Equip screen (its Packs entry, top right, or SELECT): one member's
      four weapons and four armour (worn ones marked E; left / right the next member). A on an item not worn:
      Give it to another member (each shown with its free slots of that kind); to a full pack: pick the item it
      trades places with (FF1's Trade). SELECT: Drop (Yes / No, No first). The packs stay tidy: worn first, then
      by item, empty slots last. Worn items stay put (changed on the Equip screen).
    - Fixes after the owner's play: the reflection's fourth source tile was kept past the end of its RAM page
      (rf_srcd adds to the low byte only): the upper right of the reflection showed the wrong picture and the
      change signature it overwrote never matched, so the masks were made again every frame (the world map's
      slowdown). Lit crystals on the main menu: their box takes the window colour (palette 6 colour 2), also
      with the gradient off. Tool: a frame-by-frame check that each masked reflection tile is a subset of the
      party tile it mirrors (only the frame a pose changes may differ: the masks are made a frame ahead).

60. Owner (2026-11-26): the list of what was not yet Nintendo quality, all fixed but the SGB window frames.
    - Yes / No asked in place (Packs Drop, the main menu's Suspend in its bottom window, the title's Continue
      questions; packs.s yn_ask); the Trade prompt names both items; on a file's first Equip visit a note about
      Packs (PK_NOTE, unsram + $F7). No text shadow on the item icons (Color).
    - Select on the map: the new member's tiles go up four a V-Blank, the four on screen last, all in one
      V-Blank (main.s ps_next, bank 110): the picture never disappears.
    - Bestiary: a scroll's rows go into the BG map not shown ($9C00), which is then shown in one V-Blank
      (LCDC bit 3; the per-frame copies ly_base / lcdc_on too); leaving the list shows $9800 again (sf_mx is
      sf_one / row_safe's map).
    - Reflections: the cut tiles are made for the frame they show with (no look-ahead); after their upload the
      V-Blank handler writes the four OAM entries prepared by the main code (RF_NEXT, rf_patch: 16 bytes
      unrolled, fits even the plain Game Boy's late uploads). When the frame runs late and the tiles are kept,
      cut parts whose pose changed are hidden that frame (rf_pose). While the reflection shows, map objects stop
      at 8 (od_lim / rf_want). The town table is built from the real field font (it used the 105-code default
      before the font was set): Onrac gets tiles $C8-$CF. The town water copy runs with interrupts off from its
      line test (Onrac, plain Game Boy: a VRAM write at line 0).
    - Fiend / Chaos target hand at the picture's left edge in the hand's rows (battle.py boss_hands, BTL_DATA
      $7FE0; offsets in bt_tdx / bt_tdy); Chaos's hand whole on screen, pointing into him.
    - Measured, no change needed: the world map draws a row a frame and the 15-puzzle slides without a stalled
      frame on both systems; the Status screen's columns are tidy.
    - Formation: a header window, members 3 rows apart, pictures a column clear of six-letter names; the
      picture outlines are taken away while a member slides and drawn again at rest (lu_ulc).
    - Title menu: Extras centred in its box.
    - Not done: the plain Game Boy's white loads (black ones need the screen on while loading: about three
      times the load time; the owner had chosen the loads' length); SGB window frames stay blue (hardware).
    - docs/ff1-hardware-tests.md: the checklist for real hardware.
61. Owner (2026-11-26, later).
    - Reflection: hidden over shore corners that are mostly land (the tile below the party at least half land
      fades it out; cut pieces under half over water hidden); the build gives no mask to tiles under half water
      (the marsh's blue dashes made the plain Game Boy cut the reflection every frame there).
    - Overworld / towns scrolling: each new row / column is drawn a whole step ahead (rows py +- 6, columns
      px +- 7; the airship's view, which shows the whole ring, keeps its rows), queued over the step (q_feed:
      1 metatile a frame walking, 2 dashing) with the queue first in the V-Blank (3 metatiles): no stale rows at
      the top / bottom while running; the plain Game Boy's marsh frames run on time.
    - Boarding: the party walks into the ship / canoe (the vehicle drawn in front at its tile, the party's
      leading half hidden from half way; the vehicle and its song take over when the step ends: veh_pend) and
      sinks into the airship before it takes off.
    - Menus: a name longer than a list row (the 17-letter Gauntlets) ends in one condensed "ts" cell (font
      code '~', text.py KERN_TS; names stay whole).
    - Battle: an enemy's spell / ability name stays in the top window a second at least (bt_bwait in
      bt_ban_off), whatever the battle speed.
    - Shops: Sell lists Everyone's items or one member's pack (left / right, empty packs skipped, "Dune's pack"
      under "Which one?"); after buying and equipping, "Would you like me to buy the old one from you?" (Yes
      sells the replaced item at half its price).
    - Open: all Twelve Sages at once (48 sprites; needs 8 x 16 object sprites or a mid-frame OAM reload),
      shoreline water animated with the sea and every water tile in step, a fake Mode 7 airship view, a window
      colour per save file.
62. Owner (2026-11-26, last).
    - Crescent Lake: all Twelve Sages at once. A map with more than 9 people in a 10 x 9 view (data.tall_maps:
      Crescent Lake) draws its people as 8 x 16 sprites in the frames that need them (src/tall.s: pairs of
      tiles made at build time, bottoms flipped; LCDC bit 2 switched in the V-Blank; on the Color a line handler
      swaps OBJ colour 2 at the 8-line band edges, so each half keeps its own palette). Select, talking and
      menus checked; strict checker 0 on both systems.
    - Water: the coasts' and river banks' water moves with the sea / river, the land and the light foam within
      3 pixels of land stay; every water tile moves in step (build.py water_anim: one list per step, sea and
      river separately). On the plain Game Boy the copies go in the frame's idle H-Blanks (2 bytes per H-Blank,
      lines up to 128; the V-Blank is full there), on the Color in the V-Blank. Marsh excluded (under 64 water
      pixels a tile).
    - Menus: a message waiting for A / B hides only the hands (tiles $7C-$7F), not every sprite: the Magic
      screen's picture no longer vanishes while its outline stays (field-cast refusal, shops, saves).
    - Menus: Heal / Healara / Healaga use the target screen too (a hand at every member, A casts again while MP
      lasts, "It wouldn't have any effect." when all are full); the target screen's bottom row shows the caster's
      "MP x/y" (the level's charges, or Modern MP's points) or "<item> xN", updated after each use.
    - Reflection: cut pixel by pixel again on coast tiles (the half-over-water hiding that left chunks when
      walking in from either side removed), and cheaper on the plain Game Boy (metatiles cached per step,
      per-sprite quarter memo, unrolled row shifts): measured walking at the owner's corner start
      ($FF,155,167): frame end median line 82 -> 47, no late frames on foot, dashing, marsh, Onrac or by ship;
      the Color's picture identical frame by frame.
    - Save files: each keeps its own window colour and gradient choice (save page bytes $F6 / $FE / $FF), set
      when the file is loaded; the file screen shows each file in its own colour on the Color.
    - Airship: the whole world slanted at one even tilt (owner: consistent, not curving to a horizon): every
      line shows the ground foreshortened 1.4 : 1 around the ship's line, above and below; no sky band. The
      flying map ring is rows py - 7 .. + 8. The scroll changes on about 2 lines in 5, so build.py stores each
      height's change lines and an LY = LYC interrupt comes only there, waiting for that line's H-Blank (one
      interrupt every line took half the plain Game Boy's time and dropped frames). Flying frames end by about
      line 56 on the plain Game Boy, no repeated frames; strict checker 0 on DMG / CGB / SGB.
    - Not done: black loads on the plain Game Boy (the owner: only if they do not make loads longer; they need
      the screen on while loading, about three times the load time).
63. Owner (2026-11-26, after item 62).
    - Plain Game Boy: transitions that went to black go to white, as its loads: the town / stairs wipe's curtains
      (BGP 0 on their lines, the band in the scene's shades) and the palette cycle before shops, the world map and
      the puzzle (to white and back). The Super Game Boy and the Color keep black, as their masked loads. (The world
      map itself is drawn on black, a screen, not a transition: unchanged.)
    - File screen (Color): each file shows its own gradient choice with its colour (a ramp per file, flat when that
      file was saved with the gradient off; empty files the current colour and choice), following the fades.
    - Battle: name and message lookups guarded (an enemy slot past 8, an enemy id past 127, an attack id past the
      92 names, a party target past 3, a message number outside 1-80 give no window), for the owner's stray "o&"
      window; not reproduced in some 200,000 frames of random battles.
    - Reflection: stepping down or sideways, the shore-corner fade looks at the tile below the step's end (it came
      up whole, then faded once the step ended).
    - Not reproduced: the reflection "chopping the head" when turning sideways on a corner tile (turns there show
      the new pose in the next frame, rows consistent); a screenshot / place asked for.
64. Owner (2026-11-26, last).
    - No reflections on the overworld (on foot or in a vehicle); towns keep theirs.
    - Plain Game Boy / Super Game Boy: the canoe was invisible facing sideways, and the last 16 vehicle tiles ($60-$6F)
      were blank: the overworld bank's font table ($7F00) had been placed over the DMG vehicle tiles ($7A00-$7FFF).
      They moved to $6A00; build.py place() now refuses two blobs over each other (this was the only overlap).
