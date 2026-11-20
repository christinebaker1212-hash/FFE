# Game Boy ports: native presentation over recompiled game logic

Approach for reaching **0% slowdown on DMG and CGB** in the FF1 / FF2 / FF3 Game Boy ports
(owner's decision 2026-11-20, from the FF2 DMG speed diagnosis). It refines the existing
method in CLAUDE.md ("keep recompiling the user's ROM; write native GB versions of hot
routines, above all the graphics paths"); every rule there still holds.

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
