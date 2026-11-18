# Game Boy port — handoff (2026-11-18)

Read `CLAUDE.md` first: it holds the owner's binding decisions, the targets, the rules on
what the repo may contain, and a running status. This file is the detailed state of the
work in progress and how to continue it.

## Session setup (cloud container, nothing persists outside git)
```bash
mkdir -p roms   # put the user's ROMs here (never commit): "Final Fantasy I, II (Japan).nes", "Final Fantasy III (Japan).nes"
pip install pyboy
DEBIAN_FRONTEND=noninteractive apt-get install -y libmgba-dev
bash tools/emu/build_emu.sh build/emu                     # patched cynes (NES reference emulator)
gcc -O2 tools/gb/mgba/sgbrun.c -lmgba -o build/sgbrun     # mGBA SGB runner
python3 tools/split/build_mmc5.py "roms/Final Fantasy I, II (Japan).nes" build
python3 tools/ff1/insert.py build/ff1_mmc5.nes build/ff1_en.nes          # English NES (reference)
python3 tools/ff1/insert.py build/ff1_mmc5.nes build/ff1_gb.nes --gb     # English NES + GB layout
for s in 1 2 3 4; do COV_LOG=build/cov2/s$s.bin PYTHONPATH=build/emu python3 tools/gb/covrun.py build/ff1_en.nes $s 80000; done
python3 tools/gb/build.py                                   # -> build/ff1_en.gb (+ .sym, .gb.s, .warn)
```
The coverage runs take ~10-15 minutes (run them in the background, one file per seed).
If the user uploads the ROMs as zips, unzip into `roms/` and check the SHA-1s in README.

## What exists (all FF1)
- **Toolchain** (`tools/gb/`): SM83 assembler (`asm_sm83.py`, jr→jp relaxation, `.sym`),
  code map from coverage (`nescode.py`), 6502→SM83 recompiler (`recomp.py`), runtime
  (`rt/runtime.s` PPU/joypad/MMC5/banking/dispatch, `rt/apu.s` sound, `rt/ff1_hle.s` native
  CHR upload), build (`build.py`). Design: `docs/gb-port.md`.
- **Equivalence**: the GB build of `ff1_en.nes` is byte-identical in RAM to the NES at
  every frame wait over the new-game script and 3 × 40k frames of random play
  (`firstdiff.py`). Debug tools: `tracediff.py`, `watchdiff.py`, `crashfind.py`,
  `profile_gb.py`, `compare.py` (side-by-side shots), `run_gb.py`.
- **Sound** works (APU → DMG channels). **Speed**: 1.00× in play, ~1.16× overall
  (screen transitions).
- **mGBA SGB runner** (`build/sgbrun ROM FRAMES OUT [--press KEYS@F+H] [--shot F]`):
  the ROM runs as SGB; no SGB packets/palettes/border are sent yet.

## Layout work in progress: the battle screen
Owner's design (CLAUDE.md, `docs/gb-screens.md`, mock-up renderer `tools/gb/mockup.py`,
draft 2 = `mock2_*`): enemies top-left, party sprites visible in a column on the right
with each member's name/HP beside the sprite, a full-width window at the bottom (enemy
names; command window over its right half; battle messages as lines of one window), the
acting member's line and the target flash. Re-layout is done in FF1's NES code
(`tools/ff1/gb_layout.py`, applied by `insert.py --gb`), not by a runtime compositor.

### Mechanism
- GB camera per screen: NES writes to `$5800` (X tiles) / `$5801` (Y tiles) → runtime
  `cam_x`/`cam_y` (pixels). Default 6/6 (NES cols 6-25, rows 6-23). Battle sets X = 2
  at `$F2DC`; a wrapper at `$F2E4` around the battle calls (`$C1D6` overworld, `$C935`
  dungeon) restores X = 6 afterwards. **Other screens must set their own camera** when
  they are re-laid out (menus currently show with whatever camera is active).
- Check on the NES: `PYTHONPATH=build/emu python3 tools/gb/battleshot.py build/ff1_gb.nes OUT.png --cam 2 [frames]`
  (seed-10 walk into a Goblin battle; full frame with the GB view outlined + the GB view).

### Done (in `gb_layout.py`)
- Battle setup `$F2DC-$F30B`: enemy/party/HP box frames skipped (freed bytes hold the
  camera code + wrapper).
- Bottom panel (25×12 image at `$691E`, stride 32, copied to NES rows 18-29 by `$F4A2`;
  box list of 5-byte box records + text records, redrawn by `$F652`): windows are 7 rows
  tall so their bottom frame falls on hidden panel row 6 → 5 visible text rows.
  Names box `$F9DC` (2,0,20,7), names single-spaced (`$F6D2`, `$F6D7` NOPed); command box
  records `$FA13` (11,0,11,7) Fight/Magic/Medicine/Items at x=12 rows 1-4, Run at (18,1);
  message records `$F9E1` (5 × 8 bytes): attacker box = whole window, action/target/result
  are dummy boxes in hidden rows 8-9 with text at rows 2/3/4; long message record 4 =
  whole window; item window `$FA0E` (2,0,20,7); panel-clear edge row (`$F625`) removed.
- English patch's `boxline` (far code, label `boxline.o1`): one-row lines are written on
  the text record's own row (dakuten row skipped), so lines can be single-spaced; split
  lines still use two rows.

### Next steps (battle)
1. **Party sprites → NES x = 128** (`$80`): `b12:9740 LDA #$B0` (records `$6AD3/$6AD7/$6ADB/$6ADF`;
   y already 48/72/96/120 = GB rows 0-11, 3 rows each). Party-relative effect constants
   `b12:9951 LDA #$A8` → `$78`, `b12:997C LDA #$B0` → `$80`. (`b12:A68F LDA #$A8` is a
   temp, not a coordinate — leave it.) Everything else reads `$6AD3` (relative).
2. **Name/HP beside each sprite**: drawn by bank 12 around `$AB0E` into the old HP boxes
   (NES cols 26-29, rows 4-26). Move to NES cols 18-21: name on row 6+3i, HP number on
   row 7+3i (4 columns; status words already exist as 4-tile narrow labels `$D3-$EA`).
3. **Command cursor**: NES positions x = 96 (left column) / 144 (Run), y = 158/174/190/206
   (double spacing). New text rows are NES rows 19-22 (y 152-176): cursor x = 80 / 128,
   y = 147/155/163/171. The cursor is drawn by `b12:97E9` from `$68AF`(x)/`$68B1`(y), copied
   from `$6AE3/$6AE4`, which come from RAM table `$6AAC` (filled at `b12:9AF4`, `9B1E`, `A109`).
   `$9F95`/`$9FA7` are the enemy-target grids (no change needed); `$9FBF` is the
   magic/item list cursor (x = 40, y = $9E..: will need the new list window rows).
4. Party-target cursor (cures, items on allies): follows `$6AD3` (check it lands left of
   the sprite in GB col 13).
5. **Flashing** of the acting member's line (name/HP beside the sprite) and the target:
   new code (find "whose turn" / "target" in battle RAM; blink by redrawing the line blank
   / restoring every few frames, or via sprite/palette).
6. Magic/item lists in battle (`magpage`, `itemlist` far code in insert.py) into the 20×5 window.
7. Check formations: 9 small, 4 large, mixed, the fiends/Chaos (big graphics), and
   messages longer than 18 chars (23 of them split onto two rows: result line uses rows 4-5).
8. Switch `build.py` to `build/ff1_gb.nes` (regenerate coverage for that ROM: covrun on
   ff1_gb.nes), then run `firstdiff.py build/ff1_gb.nes build/ff1_en.gb` (equivalence
   against the GB-layout NES ROM), look at the GB result in PyBoy and mGBA.

## After the battle
Main menu (party list, commands, Gil/orbs), dialogue (wrap 18 columns: `W` in insert.py,
window via the map-row box builder `$D54B`, text origin `$D520-$D536`), item/magic/equip/
status, shops, title/prologue/class select/name entry, ending. Then SGB palettes + border
(test in mGBA), speed of screen transitions (`$2007` shim), then FF2, then FF3 (GBC).

## Gotchas learned
- B and D must stay 0 at all times (BC = Y, DE = X for indexed addressing).
- Compare NES/GB at NMI k vs GB entering frame wait k (cynes `nmi_ram`), feeding the GB the
  pad the NES latched per NMI (`pad_history`); sync NES power-on save RAM into GB cart RAM
  (`compare.sync_sram`) — FF1 reads unwritten save RAM.
- PyBoy hooks on all labels are slow (minutes for 60 frames); background long runs and
  stream output with `python3 -u` without piping through grep.
- Never `rm -rf` with variables/globs (blocked by the safety check); write to new dirs.
