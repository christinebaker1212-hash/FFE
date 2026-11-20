# Game Boy ports: native presentation over recompiled game logic

Approach for reaching **0% slowdown on DMG and CGB** in the FF1 / FF2 / FF3 Game Boy ports
(owner's decision 2026-11-20, from the FF2 DMG speed diagnosis). It refines the existing
method in CLAUDE.md ("keep recompiling the user's ROM; write native GB versions of hot
routines, above all the graphics paths"); every rule there still holds.

## Owner's mandate (2026-11-20, later; binding)

**The Game Boy and Game Boy Color must not emulate the NES while the game plays.** The
NES-hardware layer worked as a first solution. From here, it is to be replaced with native
routines written from the disassembly (FF1: Entroper/FF1Disassembly, cloned into
`build/ref/` at work time, never committed). The end state has no PPU, APU or mapper
emulation at run time:
- FF1's drawing, sprite and sound routines are native GB code that write GB VRAM, OAM and
  sound registers directly.
- Graphics, palettes and DMG shading come ready-made from build time, made from the user's
  ROM.
- Game logic stays the recompiled code from the user's ROM, with RAM identical to the NES.

### FF1 plan (in this order)

1. **Inventory.** List every site where the recompiled code still reaches the NES-hardware
   layer: PPU registers (`rt_ppu_w*`, `rt_ppu_r*`), OAM DMA (`rt_io_w4014`), APU (`rt_apu_w`),
   mapper (`rt_mmc_*`). For each, give how often it runs (profiles, coverage) and the
   disassembly routine it belongs to (bank_0E/0F.asm etc., US release matched to the
   Japanese ROM). Group the sites by subsystem.
2. **Screen loads and tiles.** Make the CHR sets FF1 loads (map tilesets, battle backdrops
   and enemies, font, sprites) into GB tiles at build time. On DMG, also pre-shade them per
   palette set (map, battle, menu), so loads copy finished tiles and no tile is re-coded at
   run time.
3. **Maps.** Field and town drawing (row/column/attribute routines) write GB tile indices and
   CGB attributes straight from the map data and the pre-shaded tileset. No nametable
   shadow, owner tracking or DMG LCD-on scan.
4. **Sprites.** The map-object, party and battle sprite routines write GB OAM directly
   (GB-ready sprite tiles from build time). The per-frame NES OAM conversion goes. FF1's
   OAM buffer ($0200) is still filled as on the NES, because it is RAM.
5. **Text, windows, menus, battle panel.** Native GB map writes, completing the partial
   natives (`txrun_b`, `dbox_b`, the battle panel rows, the small-font renderer).
6. **Sound.** Sound effects and the remaining APU layer drive GB sound registers directly
   (music already runs on a native engine).
7. **Remove the emulation.** When no site is left, drop the PPU/APU/mapper layers. Keep the
   build-time tables and the natives.

Each step: RAM checks (checkall) identical; pictures compared with the step before; lagcheck
DMG and CGB. A step is done only when its subsystem makes no NES-hardware call any more.

## The principle

- **Game logic stays recompiled** from the user's ROM (formulas, RNG, events, menus' logic):
  the frame-by-frame RAM comparison against the NES remains the safety net for every change.
- **Presentation becomes native Game Boy code**: everything that only produces the picture
  or the sound. Do not imitate the NES PPU / APU at run time where the game's own drawing
  routine can be replaced by a GB routine that does the same job directly.
- The 1:1 translation layer, not the Game Boy, is the bottleneck. A DMG has plenty of power
  for an NES RPG when the presentation is native (Pokemon Gold / Silver: two regions and 251
  species on a DMG cartridge).

## Diagnosis first (measure, then rewrite)

1. Frame pacing: `tools/gb2/lagcheck.py NES GB FRAMES --random 1 [--dmg]` (Gambatte,
   hardware-like timing; FF1: `tools/gb/lagcheck.py`). Find the windows that lag.
2. Profile those windows in mGBA: `sgbrun` with env `SGBRUN_PROF2=200` (PC + bank every 200
   instructions; `--dmg` / `--cgb`), map PCs to the `.sym` file, and sort the samples into
   buckets: picture (PPU emulation, DMG shading, VRAM queue), glue (memory / bank helpers,
   farcalls), game code (translated 6502), music (sound engine + APU emulation), sprites
   (OAM conversion), NES timing loops.
3. FF2's field-with-dialogue stretch on DMG (40% too slow) measured: picture 39%, glue 21%,
   game code 16%, OAM clear loop 7%, music 7%, sprite conversion 6%, timing loops 4%. The
   game itself is a small share; the presentation layer is most of the work.

## The rewrite, in order of payoff

1. **Native picture layer.** Use the disassembly (FF1: Entroper/FF1Disassembly; FF2 / FF3:
   everything8215/ff2, /ff3) to find each NES drawing routine (map scrolling / row and column
   drawing, text printer and windows, menus, battle panels, screen loads) and replace it with
   a GB routine that writes GB VRAM directly.
   - **Reproduce the routine's RAM side effects exactly** (pointers, counters, buffers it
     leaves in NES RAM): the RAM check compares those. Only the PPU writes are free to change.
   - Keep the NES nametable shadow only where the game reads the picture back (`$2007`
     reads), or update it cheaply from the native routine.
   - **Tiles converted at build time** to GB format, from the user's ROM (never committed).
   - **DMG shading decided at build time**, per tileset and palette (or per map, as Pokemon
     G/S ships per-map palettes): pre-shaded tile variants and a BGP per screen, so drawing
     costs nothing extra per tile on DMG. No per-write palette / owner / attribute
     bookkeeping. (FF3 is GBC-only: no DMG shading, but the rest applies.)
   - CGB: write the attribute (VRAM bank 1) cells from the native routine at the same time.
2. **Cut the glue.** Translator: read ROM data directly (banked pointers) instead of through
   helper calls; place hot code in the same bank as its data; avoid farcalls on hot paths.
3. **Native music driver** that plays the game's own song data (format from the
   disassembly) on the GB sound channels, instead of running the NES sound engine and
   imitating the APU.
4. **Native sprites**: draw the game's sprite groups straight into GB OAM, instead of
   converting the whole NES OAM page every frame.
5. **Screen loads**: graphics pre-converted / pre-decompressed at build time, copied with the
   LCD off at full speed (CGB: HDMA, double speed).

## Rules that do not change

- Nothing game-specific in the repo: every game byte (and every derived table) is produced
  from the user's NES ROM when the build runs. Native routines are our own code, written from
  understanding what the original does; never copy game code.
- Game logic exactly as on the Famicom; screens as the owner approved them (mock-ups first).
- After every step: the RAM check (`firstdiff.py`, DMG and CGB) identical, `lagcheck` better,
  screenshots of the affected screens in Gambatte (and mGBA for CGB timing: PyBoy has no
  double speed or VRAM locking).
- Commit and push each step with its measurements in the game's status document.
