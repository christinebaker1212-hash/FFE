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

(updated as work goes on)
