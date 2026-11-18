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
Owner's design (decided step by step on 2026-11-18, mock-ups `tools/gb/mockup.py`,
approved layout = `mock12_battle.png` + full-width messages `mock13_msgs_wide.png`):
- camera (1, 6): enemy area GB cols 1-14 rows 0-11 (NES enemy box interior, unchanged,
  all formations fit), party sprites in their own column (NES x 140, step to 132),
- bottom (GB rows 12-17): left window (enemy names / commands, 9 columns), party window
  (cols 8-19, one line per member: name, HP current/max in 3-px digits, status word),
  full-width message window over both while a message shows,
- all window text in a small proportional font (rendered into tiles by NES code),
- messages "style A": `attacker → target`, then action / result lines indented,
- FF1's large hand cursor, never over text, may be cut off at the left screen edge,
- no blinking (owner: the cursor is enough); enemy names show while targeting; status words "Blind" (Darkness), "Numb"
  (Paralysis), "Mute" (Silence) where needed (translation change approved),
- dual-mode target for colour (CGB first), see CLAUDE.md.

### How it is built (`tools/ff1/gb_layout.py`, applied by `insert.py --gb`)
- Space: ExRAM ($5C60-$5F7F; $5F80-$5FFF is the battle text buffer, insert.py asserts the
  image ends before it) is nearly full. Bank 14 free bytes used by the menu screens: the
  old member-window code $BA14-$BA7F, old item cursor table / equip cursor table, the old
  window-table entries 3-9 of the equip screen, the dead highlight code $BF0D-$BF40; fixed
  bank $EFA7-$F05A (items) and $ED84-$EE20 (equip slots). Far bank 40 has KBs free but
  cannot call $C000-$DFFF code (text drawer $DEB6 lives there).
- Menu RAM ($0340-$034F, never used by the NES game): IPAGE/IROW/IDESC $0340-$0342 (items),
  MPAGE/MLAST/MD1/MD3 $0349/$034A/$034C/$034D (magic), EPAGE/EROW $034E/$034F (equip);
  battle: VNROW $0343, VBOX $0344, VTV $0345, VSQ $0346, VTID $0350+; dialogue DGN/DGT
  $0347/$0348.
- Far-code bank 40 (via ExRAM `farjsr`; farjsr clobbers A, so routines read their
  arguments from RAM): small-font renderer `VWF_SRC` (`vchar`, `vstr`, `vupload`; glyph
  table generated from `tools/latin_font.py`), `party_stamp` (party window into the panel
  image on every panel clear, hook `$F625`), `party_line` (hook b12:`$AA5B`), `boxline`
  replacement (panel text into tiles `$A8 + 18(row-1) + col-2`, word wrap; marker
  columns 21 = target after the attacker, 22 = next message line, 23 = Run), `MAGPAGE`,
  `ITEMLIST` (+ `ITEMMOVE_PATCH`); enemy targeting shows the names window (stubs
  b12:`$AB07` / `$9D94` around the target loop `$9B55`).
- Far code must not reach bank-62 code at `$C000-$DFFF` (`$F47D` ends in `JMP $C009`,
  the music driver): use the fixed trampoline `MUSIC` (`$F2F1`).
- Text code `$FD $80+n` moves the pen to tile n of the row (the decoder treats bytes
  < `$48` as control codes and converts `$48-$79`).
- Tiles: party lines `$80-$A7`, panel text `$A8-$EF` (font tiles, free in battle: the
  field reloads the BG pattern table after a battle). RAM: `$6E00-$6EFF` (renderer),
  `$0343-$0344` (list row, saved box count); both never touched by the game in 320k frames of coverage.
- Tools: `battleshot.py --cam 1`, `battleseq.py` (sheet of a battle; `--form F` forces a
  formation, `--input fight|run|magic4|items4`, `--poke ADDR=VAL` patches work RAM, e.g.
  spells `$6300+64m`, equipment `$6118+64m`), `formations.py` (survey), `ntlog.py`,
  `test_vwf.py` (renderer in py65), `mockup.py`.

### Next steps (battle)
1. GB build: `build.py --gb` (coverage `build/cov3` from `covrun.py build/ff1_gb.nes`),
   `firstdiff.py build/ff1_gb.nes build/ff1_gb.gb`, look at it in PyBoy and mGBA (SGB).
   The VRAM queue (40 bytes per GB frame) makes text slower on GB: measure, and later use
   HDMA in CGB mode.
3. Enemy names window: long names wrap into the next name's row (rare: names > 56 px);
   end-of-battle messages (gold, experience, level up); "Medicine" list; all formations
   (fiends, Chaos); messages that need three rows.
4. Then the colour milestone (CGB mode first), then the other screens.

## Plain Game Boy shading (done 2026-11-18)
`tools/gb/rt/dmg_shade.s` (DMG/SGB only; CGB uses NES colours). BG tiles live in a shadow
(cart RAM bank 1 $B000) and are re-coded per palette: value = brightness group of the
colour, the same in all BG palettes (`dmg_maps`), BGP from the groups (`dmg_bgp`, darkened
during fades). Work happens when the LCD goes on (scan, re-code used tiles) or, with it on,
3 tiles per frame. RAM: TILE_PAL $DB00, DIRTY_BM $DC00, PAL_MAP $DC20, RT_BUF $DC30,
REF_LMAX/NGRP $DC40, LVF/LSL/LVMAP/GLUM $DC50-$DC7F, REF_BM $DC80, DEFER_BM $DCA0,
OWN $DD00 (both modes), TILE_USE $DD80. Both modes track which nametable drew each GB map
cell (`own_set`) so nametable-1 attributes colour only their cells.

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
