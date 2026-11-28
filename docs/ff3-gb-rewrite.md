# FF3 GB: the native port

**Superseded (owner, 2026-11-28): the FF3 base is the native engine from `claude/vibrant-davinci-lc8boi`,
now `tools/gb3n/`; status in `docs/ff3-native.md`.** Kept for its history.

Owner's decision (2026-11-28, binding; see `CLAUDE.md`): FF3 is a **native port, as FF1 was**. We take
FF3 on the NES, use the everything8215/ff3 disassembly (`build/ref/ff3/ff3j.asm`, never committed) to
learn what each part of the game does, and write our own Game Boy Color engine that does it. **No
recompilation, no emulation layer, no code translation.** Every game byte comes from the user's ROM at
build time.

**The goal:** a faithful but updated Final Fantasy III, as an official Nintendo release might be: FF3's
game as on the NES (its rules, formulas, RNG, events, maps, flow) with the FF1 native build's updated
mechanics and polish.

## Base
- **FF1's native engine** (`tools/gbn/`): build skeleton, assembler, test tools and the Game Boy modules
  `docs/gb-native-reuse.md` lists as reusable (palettes and fades, colour correction, font / windows /
  dialogue box, the screen framework and hand cursor, Yes / No, Config / saves / suspend / Lot Check,
  water / reflections, airship view, raster spell effects, the sound output side, the battle
  presentation). Color only: the DMG / SGB halves are dropped. `docs/gb-lessons.md` applies throughout.
- **FF3's logic** written natively from the disassembly: field and world map (maps, metatiles,
  walking, people, triggers, doors, treasures, vehicles), the event scripts and their commands, text,
  menus (jobs, capacity points, equipment, magic, items, the Fat Chocobo), shops, battle rules (the
  existing native battle rules, already checked against FF3's code, are kept), encounters, music.
- **Data converted at build time** (tiles, maps, palettes, pictures, text, tables), so the engine only
  copies.

## Checks
- FF3's behaviour against FF3's own code where it matters (battle formulas, RNG, encounter rates,
  event results), with `tools/gb3n/test/pynes.py` running the user's English ROM headless (RAM identical
  to cynes) and `ff3drive.py` pad scripts.
- The strict SameBoy checker at 0 from the first screen; every screen looked at frame by frame.

## Progress
- 2026-11-28: decision recorded. Kept tools: `inventory.py` (the listing's routines), `test/pynes.py`,
  `test/ff3drive.py`, `test/sbsh3.c`. The translation experiment (`tools/gb3n/core`, `corebuild.py`,
  `fdiff.py`, `callgraph.py`) removed.
- 2026-11-28: the native port's engine (`tools/gb3n/eng`, builder `tools/gb3n/port.py`):
  - field.s: FF1's field core (boot, V-Blank, metatile queue, scroll, party sprite), Color only;
    FF3's normal maps (32 x 32, fill tile, z-levels, stairs, bridges, triggers, doors, the map stack),
    FF3's map main loop order (3F/E1E1), treasures and locked doors (3F/E917), random encounters
    (3D/BDB9), map titles (3F/E24C), the "Game Boy Color only" notice.
  - event.s: FF3's event VM (3E/D219, 3B/A067) and its commands ($C0-$FF; npc commands $00-$BF in
    npc.s), trigger scripts and npc scripts (3C/9319, 92F3), event triggers.
  - npc.s: FF3's objects ($7000 / $7100 layout): loading, random movement, event movement, facing the
    party, touching, sprites (3B/AEEB, B17C, B2FD).
  - dlg.s: FF3's dialogue in FF1's text box (typed at reading speed), item names / amounts.
  - world.s: FF3's world map on foot (3E/C0ED, C65D, entrances / exits, world encounters).
  - bridge.s: the kept modules (FF3's battle rules and screen, the sound driver, the main menu, shops /
    inns, the prophecy / prologue / epilogue / ending cutscenes, the title, names, saves, Suspend) joined
    to the engine; the field's RAM kept in WRAM bank 3 while they run.
  - Plays from power-on: prophecy, title, names, the Altar Cave opening (events, text, the battle),
    chests, encounters, the menu, the world map, towns and castles, shops.
  - Next: FF3's special animations ($EF), vehicles and world-map sprites, guest npcs, item use on
    the map (B), screen effects ($D0-$D3), then a playthrough.

