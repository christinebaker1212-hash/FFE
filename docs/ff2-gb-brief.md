# Final Fantasy II Game Boy port: brief for the FF2 session

You are taking over the **Final Fantasy II** Game Boy port in the FFE repository
(`christinebaker1212-hash/FFE`). Another Claude session is still finishing the FF1 port in
the same repository. You own FF2; the owner (the project owner, who builds everything
locally) decides scope and design. Work directly in your own session: **do not use
subagents, Task delegation or workflows** (owner's rule, `CLAUDE.md`).

## Read first, in this order
1. `CLAUDE.md`: binding rules for the whole repo (targets, what may be committed, the
   approach). Its long FF1 status log is reference only: it shows how the FF1 port solved
   problems you will meet again.
2. `README.md`: the translation rules (binding: authenticity, no censorship, full-length
   names, identical experience) and the ROM SHA-1s.
3. `docs/translation-guide.md`, `docs/glossary-ff2.md`.
4. `docs/gb-port.md`, `docs/gb-handoff.md`, `docs/gb-screens.md`: the GB runtime design
   (PPU/APU conversion, tile/nametable/scroll mapping, DMG shading, SGB, CGB), build steps,
   test tools, known limits.
5. `docs/ff2-engine-notes.md`, `docs/ff2-text-engine.md`: what is known about FF2's engine
   and text, and how the English insertion works.

## The target (owner's decisions: binding)
- **Dual-mode cartridge**, like FF1: one ROM that runs on Game Boy (DMG), Super Game Boy
  (SGB palettes and border) and Game Boy Color (CGB colours matching the NES palettes).
  Header CGB flag `$80`, MBC5 sized to the game, battery SRAM. Screen layouts are the
  same in all modes.
- **0% slowdown on Color and on DMG is non-negotiable.** The game never runs slower than
  the Famicom, and the music and sound effects never hitch. Transitions should match the
  NES where possible; "a little longer" is tolerated for transitions only.
- **Base: the everything8215/ff2 disassembly** (https://github.com/everything8215/ff2), not
  static recompilation of the ROM (FF1 stays on recompilation; FF2 and FF3 switch). The
  disassembly source is **packed into the builder**: fetched when the builder is made
  (GitHub Actions / local build), **never committed to this repo**. The English patch gets
  ported onto that source. Verify first that it builds to the Japanese ROM byte for byte
  (SHA-1 in `README.md`).
- **Nothing is distributed.** The repo holds tools only. No game code, graphics, maps,
  music, text or ROM-derived data files, no prebuilt GB ROMs, no patches containing game
  content. Building needs the user's NES ROM (`roms/`, git-ignored; check its SHA-1).
  Build output goes to `build/` (git-ignored).
- **Screen layouts in SaGa / Final Fantasy Legend style** for 160×144 (20×18 tiles), as in
  FF1:
  - party as compact one-line-per-member lists;
  - full-width windows, command windows opening over the party window;
  - enemies in the upper part of the battle screen, party sprites visible in battle;
  - no blinking of actors or targets (the cursor is enough);
  - no two-character-panel splits and no panning across the NES layout.
  Re-layouts are done properly in the game code, not by a runtime that rearranges the
  NES picture. The translation text stays the same; only wrapping and layout change. Show
  the owner mock-ups (PNG, `tools/gb/mockup.py` style) before building a screen.
- **Select-button menu** (asked for FF1, FF2 and FF3): OPTIONS (battle speed, BGM volume,
  SFX volume), FORMATION (the game's own reordering screen), SUSPEND ("Create a Suspend
  Point and return to the Title? Suspend points are retained when turning off the Power.";
  a temporary save kept in SRAM; on CONTINUE: "Continue from Suspend point?", on No with a
  save present "Continue from last save? The suspend point will be lost!", without one the
  New Game flow; resuming erases the suspend point). **How the menu is opened differs
  per game**: ask the owner how FF2 should open it.
- Game logic, formulas, RNG and events stay exactly as on the Famicom unless the owner
  says otherwise.

## Tools you can reuse (shared with FF1)
- `tools/gb/asm_sm83.py`: SM83 assembler (multi-bank, `.sym`, header/checksum writer). No
  outside toolchain: Python 3 only (PyBoy for headless tests: `pip install pyboy`).
- `tools/gb/rt/*.s`: the FF1 runtime. Its NES-hardware layer (PPU/APU/MMC5 conversion,
  DMG shading `dmg_shade.s`, SGB `sgb.s`, CGB palettes, catch-up frame pacing in
  `rt_wait_nmi`) is the model for FF2. With a disassembly base you can call GB-native
  routines directly instead of emulating register writes where that is faster.
- Speed measurement: `build/gbrun` (Gambatte via libretro, hardware-like timing; build:
  `apt-get install libretro-gambatte retroarch-dev`, then
  `gcc -O2 -I/usr/include/libretro-common tools/gb/gambatte/gbrun.c -ldl -o build/gbrun`) and
  `tools/gb/lagcheck.py` (GB frames vs NES frames per window). SGB: `tools/gb/mgba/sgbrun.c`
  (`apt-get install libmgba-dev`, `gcc -O2 tools/gb/mgba/sgbrun.c -lmgba -o build/sgbrun`),
  with `SGBRUN_PROF2=K` for an instruction-sampled profile.
- Equivalence: the NES emulator (`tools/emu`, cynes with MMC5 and frame/pad/RAM hooks) and
  `tools/gb/firstdiff.py` / `compare.py` (NES and GB run in lockstep by frame wait; RAM
  compared at each wait). Lessons from FF1: feed input at the joypad read, not per
  emulator frame (`compare.GB.feed_pads`, and the ROM's test-input mode `TEST_PAD`); VRAM
  is not covered by RAM checks, so compare tiles/maps too.
- FF2 English insertion: `tools/ff2/insert.py`, `script/ff2/*.json`,
  `translations/ff2_*.py`, the MMC5 split `tools/split/build_mmc5.py`, `patches/ff2_en.bps`.
- Windows builder: `tools/builder/ffe_builder.py` and `.github/workflows/ffe-builder.yml`
  (FF2 is listed but disabled; enable it when FF2 builds).

## Working agreements with the FF1 session
- Work on your own branch. Do not rewrite or force-push the FF1 branch.
- Put FF2 code in new files and directories (for example `tools/gb2/`, `tools/gb2/rt/`,
  `docs/ff2-gb-*.md`). Do not edit FF1 files (`tools/gb/rt/*.s`, `tools/gb/build.py`,
  `tools/ff1/*`, `tools/gb/recomp.py`) without the owner's go-ahead. Copy what you need,
  or ask for a shared module.
- Keep your status in `docs/ff2-gb-status.md` (work done, remaining, plan; update it about
  every 5 minutes of work) and add one line to `CLAUDE.md` pointing to it. Commit and push
  often. Never commit ROMs, ROM-derived data, the fetched disassembly or build output.
- Report outcomes faithfully: say what was checked and how (which emulator, which script,
  how many frames), and say when something was not checked.

## Suggested first milestones
1. Set up: verify ROMs (SHA-1), build the English FF2 NES ROM with the existing tools,
   fetch everything8215/ff2 into `build/` and check that it assembles to the Japanese ROM.
2. Plan how the English patch maps onto the disassembly source (text banks, MMC5 changes,
   expanded name tables), and write it up for the owner.
3. Plan the 6502 → SM83 path from source (annotated routines, data vs code known): which
   parts are translated mechanically, which get native GB rewrites (graphics paths, hot
   loops), and how game data still comes from the user's ROM at build time. Get the
   owner's OK before large builds.
4. Boot to the title in PyBoy and Gambatte; then new game, field, battle; equivalence
   against the NES build; then screen re-layouts with mock-ups; then colour (CGB first,
   then DMG shading and SGB); then the Select menu and suspend points; then the builder.
