# Final Fantasy III Game Boy Color port: brief for the FF3 session

You are taking over the **Final Fantasy III** Game Boy Color port in the FFE repository
(`christinebaker1212-hash/FFE`). FF1's Game Boy port is finished. The owner played it through
to the ending and it ran on real hardware (2026-11-26). An FF2 session may be working in
the same repository at the same time. You own FF3. The owner (the project owner, who builds
everything locally) decides scope and design.

Work directly in your own session: **do not use subagents, Task delegation or workflows**
(owner's rule, `CLAUDE.md`).

## Read first, in this order
1. `CLAUDE.md`: the binding rules for the whole repo (targets, what may be committed, the
   approach, the release requirements). Its long FF1 status log is reference only. It shows
   how problems you will meet again were solved.
2. `README.md`: the translation rules and the ROM SHA-1s. The rules are binding:
   authenticity, no censorship, full-length names, an identical experience.
3. `docs/translation-guide.md`, `docs/glossary-ff3.md`.
4. `docs/gb-native-reuse.md`: what made FF1 100% native and which parts carry over.
   This is your main plan input.
5. `docs/gb-lessons.md`: hard-won hardware and tooling lessons from FF1. Read all of it;
   every rule there cost a bug.
6. `docs/ff1-native.md`: the FF1 native build (architecture, rules, the owner's feedback
   items 1-65), and `docs/gb-video-improvements.md`. Together they are the catalogue of
   what the owner liked and asked for.
7. `docs/gb-release-checks.md`: the Lot Check standards and how FF1 met and checked them
   (strict SameBoy checker).
8. `docs/ff3-engine-notes.md`, `docs/ff3-text-engine.md`: what is known about FF3's engine
   and text, and how the English insertion works (`tools/ff3/`, the 1 MB MMC5 split in
   `tools/ff3_mmc5/`).

## The target (owner's decisions: binding)
- **Game Boy Color only.** FF3 is the only Color-only cartridge.
  - Header CGB flag `$C0`, MBC5 sized to the game, battery SRAM.
  - On a DMG, Pocket or Super Game Boy the game must show a "Game Boy Color only" screen
    (a Lot Check requirement), worded with Nintendo's hardware names.
  - Check it on the GBA too.
- **0% slowdown and 0 lag frames are non-negotiable.** The game never runs slower than the
  Famicom, and the music and sound effects never hitch.
- **Every Lot Check standard** in `docs/gb-release-checks.md` must be met and checked before
  any release:
  - header and boot;
  - LCD off only in V-Blank;
  - VRAM / OAM access windows;
  - cart RAM disabled after each access;
  - save validation with an error message;
  - soft reset (A+B+Start+Select);
  - memory cleared at boot;
  - the compatibility matrix;
  - hardware names;
  - meaningful Color use;
  - no undocumented debug code.

  FF1 keeps the strict SameBoy checker at 0 on every build. Do the same from the first
  bootable ROM.
- **Base: settle this with the owner before building anything.** `CLAUDE.md` still says
  FF2 / FF3 start from the everything8215/ff3 disassembly (fetched when the builder is made,
  never committed). That rule predates FF1's switch to a **100% hand-written native
  rewrite**. The rewrite reached 0 lag on the DMG and literal Lot Check compliance, which
  FF1's earlier recompiled build never did.
  - Recommend the native rewrite: our own SM83 code, written from what the disassembly says
    each routine does, with all data read from the user's ROM at build time.
  - Ask for the owner's decision first.
- **Nothing is distributed.**
  - The repo holds tools only. No game code, graphics, maps, music, text or ROM-derived data
    files; no prebuilt ROMs; no patches containing game content.
  - Every game byte comes from the user's NES ROM when the build runs (`roms/`, git-ignored;
    check its SHA-1 against `README.md`).
  - Build output goes to `build/` (git-ignored).
- **Screens in SaGa / Final Fantasy Legend style** for 160×144 (20×18 tiles), as in FF1:
  - party shown as one-line-per-member lists;
  - full-width windows; command windows open over the party window;
  - enemies in the upper part of the battle screen, party sprites visible in battle;
  - no blinking of actors or targets (the cursor is enough);
  - no two-character-panel splits and no panning across the NES layout.

  Re-layouts are done properly in the game code. The translation text stays the same; only
  wrapping and layout change. Show the owner mock-ups (PNG) before building a screen.
- **Select-button menu:** OPTIONS, FORMATION, SUSPEND, with the suspend-point wording and
  flow described in `docs/ff2-gb-brief.md`. Ask the owner how FF3 should open it.
- **Game logic, formulas, RNG and events stay exactly as on the Famicom** unless the owner
  says otherwise. FF1 also fixed the original game's known bugs, but only after the owner
  agreed to each fix.
- **FF1's conveniences and polish.** Ask the owner which carry over to FF3:
  - typewriter text, fades on every screen change, the hand-cursor rule;
  - damage numbers, remembered commands / targets;
  - Options pages, Color gradient windows, three save files;
  - town reflections, animated water, the Bestiary / Sound Test.

  FF3 has its own weapon / armour / magic icons; FF1 borrowed them from FF3.

## What carries over from FF1 (`tools/gbn/`, about 45,000 lines)
- **Build tooling:**
  - `tools/gbn/build.py` (data readers from the ROM, `place()` with an overlap check);
  - `tools/gb/asm_sm83.py`;
  - `tools/gbn/rammap.py` (RAM overlaps and free gaps);
  - `tools/gbn/xbank.py` (calls into another bank).
- **Generic engine modules** listed in `docs/gb-native-reuse.md` §3:
  - the screen / window framework;
  - palettes and fades (`src/pal.s`, Color paths);
  - sound output with the DMG / Color hardware workarounds;
  - save / suspend with checksums;
  - the Lot Check pieces.
- **Test tools:**
  - SameBoy harness `tools/gb/sameboy/sbsh.c` plus the patch `tools/gb/sameboy/sameboy-ffe.patch`.
    It gives the strict checker (`SB_LCHK`), PC logging, write watchpoints and screenshots;
    build steps are in `docs/gb-lessons.md`.
  - `tools/gb/lagcheck.py`.

  The owner tests in SameBoy, not PyBoy. Write your own random-play driver and run it on
  every build. FF1's was scratch-only: New Game, then random input for 20,000+ frames under
  the strict checker.
- **Written fresh from FF3's disassembly**, reusing FF1's shape:
  - the field (FF3's maps, vehicles, the floating continent, mini / toad);
  - the job system and its menus;
  - battle (FF3's rules, summons, multi-hit, rows);
  - FF3's sound driver as native code (check it against FF3's own driver; output side reused).

## Working agreements
- Work on your own branch. Do not rewrite or force-push other branches.
- Put FF3 code in new directories, for example `tools/gb3n/` and `docs/ff3-gb-*.md`.
  - Do not edit FF1's files (`tools/gbn/`, `tools/gb/`, `tools/ff1/`) without the owner's
    go-ahead.
  - Copy what you need, or propose a shared module.
  - The same goes for the FF2 session's files.
- Keep your status in `docs/ff3-gb-status.md` (work done, remaining, plan; update it about
  every 5 minutes of work) and keep one pointer line to it in `CLAUDE.md`.
- Commit and push often. Never commit ROMs, ROM-derived data, the fetched disassembly or
  build output.
- Report outcomes faithfully: say what was checked and how (which emulator, which script,
  how many frames), and say when something was not checked.

## Suggested first milestones
1. Set up:
   - verify the ROMs (SHA-1);
   - build the English FF3 NES ROM with the existing tools;
   - clone everything8215/ff3 into `build/ref/` (never committed) and map its routines onto
     the Japanese ROM.
2. Get the owner's decisions:
   - the base (native rewrite recommended);
   - the Select menu button;
   - which FF1 conveniences carry over.
3. Copy the build skeleton, the generic modules and the test tools. Get a boot screen, the
   font, the "Game Boy Color only" screen on DMG / SGB and one map on screen. Strict checker
   at 0.
4. Field next: maps, walking, objects, text, vehicles.
5. Then menus on the screen framework (mock-ups first), then battle with FF3's rules, then
   music.
6. Then a natural playthrough, then the owner's hardware tests.
