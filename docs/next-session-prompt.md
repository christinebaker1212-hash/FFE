# Lead-in prompt for the next session (FF1 Game Boy speed work)

Continue the FF1 Game Boy port speed work in this repo (branch `claude/tender-meitner-j5gu01`).
The owner's goal: 0% slowdown against the NES on both the Game Boy Color and the plain Game
Boy (DMG); game logic and pacing must stay exactly as the NES (no catch-up, no speed-ups).

1. Read `CLAUDE.md`, then `docs/gb-handoff.md` (section "Speed work, state 2026-11-19") and
   `docs/gb-lessons.md` (Speed). Set the session up as the handoff says (ROMs in `roms/`, PyBoy,
   cynes emulator in build/emu, Gambatte `build/gbrun`, mGBA `build/sgbrun`, SameBoy core).
2. Build: `python3 tools/gb/build.py --gb` (needs coverage in `build/cov3`; regenerate with
   `tools/gb/covall.py` if the NES side changes). Run all RAM checks
   (`PYTHONPATH=build/emu python3 tools/gb/checkall.py build/ff1_gb.nes build/ff1_gb.gb`);
   they have not been run since the last commits.
3. Measure lag with `tools/gb/lagcheck.py ... 7650 --win 500` (CGB) and `--dmg`. Now: CGB ~33,
   DMG ~200 lag frames.
4. First task: fix `vshow_own` (bank 60, ff1_native.s; disabled): its WRAM bank 4 map buffer
   is wrong at rows 16-29, columns 0/1/4/5 (CGB, wait 3064). Then re-enable it
   (`jp nz, vshow_own` in vshow_b, and drop the maprb_b / repal_b calls from vshow_tramp).
   It should save ~3 frames per field / battle load on the CGB.
5. Then continue down the remaining-lag list in the handoff (DMG screen loads, battle panel
   redraws, prologue bands, boot). Check every runtime change by comparing VRAM with the build
   before it (SameBoy, GBRUN_VRAM; see the handoff tools list) and with `checkall`.
6. Commit and push often; keep CLAUDE.md's status current. No subagents (CLAUDE.md).
