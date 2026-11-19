# Game Boy port — handoff (2026-11-19)

Read `CLAUDE.md` first: it holds the owner's binding decisions, the targets, the rules on
what the repo may contain, and a running status. This file is the detailed state of the
work in progress and how to continue it.

## Session setup (cloud container, nothing persists outside git)
```bash
mkdir -p roms   # put the user's ROMs here (never commit): "Final Fantasy I, II (Japan).nes", "Final Fantasy III (Japan).nes"
pip install pyboy
DEBIAN_FRONTEND=noninteractive apt-get install -y libmgba-dev
bash tools/emu/build_emu.sh build/emu                     # patched cynes (NES reference emulator)
gcc -O2 tools/gb/mgba/sgbrun.c -lmgba -o build/sgbrun     # mGBA runner (SGB / DMG / CGB)
python3 tools/split/build_mmc5.py "roms/Final Fantasy I, II (Japan).nes" build
python3 tools/ff1/insert.py build/ff1_mmc5.nes build/ff1_gb.nes --gb     # English NES + GB layout (+ .far)
PYTHONPATH=build/emu python3 tools/gb/covall.py build/ff1_gb.nes build/cov3   # coverage, ~20 min (4 cores)
PYTHONPATH=build/emu python3 tools/gb/build.py --gb --nes build/ff1_gb.nes   # -> build/ff1_gb.gb (+ .sym)
```
`build.py --gb` without `--nes` runs the whole pipeline from `roms/` (split, English,
GB layout) but needs coverage logs made for that exact NES ROM (`build/cov3/rom.sha1`;
build.py warns on a mismatch). Coverage must be regenerated after every change to the
NES-side code (`gb_layout.py`, `insert.py`); runtime-only changes (`tools/gb/rt/`) need
only `build.py`. If the user uploads the ROMs as zips, unzip into `roms/` and check the
SHA-1s in README.

Coverage from an older NES ROM still works for small NES-side changes: covall keeps a copy
(`rom.nes`), and build.py drops the logs of the changed bytes and relies on static flow
there (prints how many). New code reached only by dynamic dispatch can still be missing
(the GB then halts with fault code 1 in `DBG` $D820): regenerate before the final checks.
`covall.py` reads the ROM at the start of each run: give it a copy if you keep rebuilding.

## Checks
- All at once: `PYTHONPATH=build/emu python3 tools/gb/checkall.py build/ff1_gb.nes
  build/ff1_gb.gb [--only NAME,..] [--dmg|--cgb]` (logs in `build/checks/`).
- RAM equivalence (NES RAM at NMI k = GB RAM entering frame wait k), DMG and CGB
  (`GB_CGB=1`): `firstdiff.py build/ff1_gb.nes build/ff1_gb.gb 3700` (new game),
  `... 30000 --random 1`, `... 7100 --battle`, and every `covall.FIELD` script with its
  pokes (`... N --field SCRIPT --poke P`; N = len(fieldseq.frames_for(SCRIPT)) - 1900).
- SGB (mGBA): `sgbshots.py NES GB OUT.png K1,K2,.. [--newgame | --field S | --input MODE]
  [--poke P [--poke-at F]] [--dmg | --cgb]` (screens at NES frames K), `sgbram.py`
  (game state; a few scratch bytes differ when caught mid-frame, in DMG mode too).
- Speed (mGBA): `sgbshots.py ... 7000` prints GB frames for 7000 NES frames of the battle
  script; env `SGBRUN_PROF=1` prints the PC of every frame without a NES frame end
  (SGB builder code in bank 63 is reported under the caller's bank: resolve PCs against
  the `3f:` symbols), `SGBRUN_PEEK=ADDR` prints 16 bytes of WRAM per shot.

## What exists (all FF1)
- **Toolchain** (`tools/gb/`): SM83 assembler (`asm_sm83.py`, jr→jp relaxation, `.sym`),
  code map from coverage (`nescode.py`), 6502→SM83 recompiler (`recomp.py`), runtime
  (`rt/runtime.s` PPU/joypad/MMC5/banking/dispatch, `rt/apu.s` sound, `rt/ff1_hle.s` native
  CHR upload, `rt/dmg_shade.s` plain-GB shading, `rt/sgb.s` SGB palettes/attributes/
  border/screen mask), build (`build.py`). Design: `docs/gb-port.md`.
- **Equivalence**: the GB build of `ff1_gb.nes` is byte-identical in RAM to the NES at
  every frame wait in all checks (see Checks). Debug tools: `tracediff.py`, `watchdiff.py`,
  `crashfind.py`, `profile_gb.py`, `compare.py` (side-by-side shots), `run_gb.py`.
- **Sound** works (APU → DMG channels).
- **mGBA runner** (`build/sgbrun ROM FRAMES OUT [--press KEYS@F+H] [--shot F] [--padfile
  F --nshot K] [--sram F] [--poke K ADDR=VAL,..] [--dmg | --cgb]`), driven by
  `sgbshots.py` / `sgbram.py`.

## The battle screen (done)
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

## Plain Game Boy shading (done 2026-11-18)
`tools/gb/rt/dmg_shade.s` (DMG/SGB only; CGB uses NES colours). BG tiles live in a shadow
(cart RAM bank 1 $B000) and are re-coded per palette: value = brightness group of the
colour, the same in all BG palettes (`dmg_maps`), BGP from the groups (`dmg_bgp`, darkened
during fades). Work happens when the LCD goes on (scan, re-code used tiles) or, with it on,
3 tiles per frame. RAM: TILE_PAL $DB00, DIRTY_BM $DC00, PAL_MAP $DC20, RT_BUF $DC30,
REF_LMAX/NGRP $DC40, LVF/LSL/LVMAP/GLUM $DC50-$DC7F, REF_BM $DC80, DEFER_BM $DCA0,
OWN $DD00 (both modes), TILE_USE $DD80. Both modes track which nametable drew each GB map
cell (`own_set`) so nametable-1 attributes colour only their cells.

## State at the FF1 release (2026-11-18, local build only: nothing published)
All FF1 screens are re-laid out for 160x144 (battle, field dialogue, main menu, items,
magic, weapons/armour, status, shops, prologue, title, class select, name entry, bridge /
ending story, world map, 15-puzzle); colour in CGB mode (NES colours), plain Game Boy
shading and SGB palettes + border. RAM-identical to the NES in all checks (DMG and CGB);
the only reported difference is the CGB bridge script's pad bytes one frame off (harness
input feed). Speed for the 7000-frame battle script in mGBA: CGB ~7.5k GB frames, DMG
9279, SGB 9864 (1.00x in steady play; the extra is screen transitions).

Known limits:
- Scrolling screens on the SGB use one palette for the whole screen (e.g. water near a
  bridge can turn grey for a few seconds).
- DMG prologue: a newly fading line's letters can flash white for a few frames.
- A BG tile drawn with two palettes whose colours differ in brightness at the same index
  is coded for one of them on DMG/SGB (only the prologue fade did this; worked around).

Possible next work: speed of screen transitions on DMG/SGB (nametable-write bookkeeping
`rt_ppu_w7` / `own_set` / `dmg_mark`, the LCD-on scan), then FF2 (dual-mode), then FF3
(GBC only).

## Speed work, state 2026-11-19 (owner: "keep going until DMG and Color are both 0%")

Measure on the 7650-wait new-game + battle script (Gambatte, hardware-like timing):
`PYTHONPATH=build/emu python3 tools/gb/lagcheck.py build/ff1_gb.nes build/ff1_gb.gb 7650 --win 500 [--dmg]`.
`--gbjitter A-B` with `LAG_N=5000` lists every wait whose GB frames differ from the NES's.
To group lag into screen loads, see `docs/gb-lessons.md` (Speed). Profile in mGBA with
`SGBRUN_PROFC=1 SGBRUN_PROF2=800 build/sgbrun ROM 8200 out --dmg|--cgb --padfile P --sram S > prof.txt`.
The output has one sample per 800 timing units: about 175 samples per DMG frame, or per
double-speed CGB frame at PROF2=400. Group the samples per wait by symbol.
Input files for the script are kept by `LAG_KEEP=1 lagcheck.py ...` (it prints the temp dir).

| | session start | now |
|---|---|---|
| Color (CGB) | 126 frames lag (+1.6%) | ~33 (+0.4%) |
| Plain GB (DMG) | 263 (+3.4%) | ~200 (+2.6%) |

Done this session (all checked VRAM-identical in SameBoy against the build before, or
self-consistent with `mapself`; RAM 62/62 at commit 92a3c5f+, later changes are RAM-neutral
runtime work but **checkall has not been re-run since the coverage refresh**: run it first):
- Title-screen corruption on CGB (repal_b left VRAM bank 1 selected) and stale queued map
  cells after a masked load (maprb_b drains the VRAM queue first). Battle message teardown
  in one frame ($5808, NES side; coverage refreshed for it).
- CGB: attribute palettes written straight to VRAM bank 1 (attr_apply, vram_put1); whole
  sprite pages left in ROM (lazy: LZ_BM / LZ_SRC in cart RAM bank 3, `spr_mat` copies a tile
  to the shadow on demand; DMG and CGB); identity-coded CGB slot loads as a plain copy;
  masked load shown with nametable 0 only: map + palettes by general-purpose DMA (vshow_b,
  bank 60); rt_ppu_w7 short path also for CGB masked loads (MAP_RB).
- DMG: battle panel rows with cells owned by nametable 1 on the fast path (nrf NR_O1);
  native `(zp),Y -> $2007` runs (izyrun0: b21:80C5, fix:F24D); ntfill bulk paths for
  attribute bytes and increment-32 columns, 8-byte fills; DrawMapAttributes with the LCD off
  to the shadow only; map decompression literal loop inline + `fillde`; one-pass re-coding
  at LCD on (`rtb_b`, bank 60, replaces dmg_retile_ref / some(0)); colour-use scan by POP
  (`pf2_b`); LCD-on scan with palette bit sets (SC_NP bits; the view pass `scn_rowv` only
  when a tile is drawn with two palettes; PAL_USED from `scn_pu` in the full pass);
  dmg_maps / dmg_target / spr_maps / spr_alloc moved out of bank 0.
- Tried and reverted: deferring the DMG LCD switch-off to the vblank interrupt (slower: the
  bulk LCD-off paths are lost for the rest of that frame).

**Work in progress (not active):** `vshow_own` (bank 60): for masked loads whose cells belong
to both nametables (field, battle), build map + palettes by owner into WRAM bank 4 and DMA
them. It has a bug: the bank-4 buffer itself is wrong for rows 16-29, columns 0/1/4/5 (seen at
wait 3064 on the CGB; the DMA copies the buffer correctly). vshow_b returns before it
(`ret nz` on own1), and vshow_tramp runs maprb_b / repal_b for those loads as before (about 3
frames per field / battle load on CGB). Fix the builder (check the per-cell push / pop
pairing and the HL arithmetic for rows >= 16), then re-enable it with `jp nz, vshow_own`.

Remaining lag, by where it is (DMG / CGB frames on the script):
- Boot wait 1: DMG 11 (all 256 BG tiles coded at LCD on in prologue mode: ~550 M-cycles a
  tile). Defer to the prologue's idle frames only if the intro text never shows uncoded.
- Prologue bands: DMG ~22 in total, 2-4 per band (attribute writes each frame, b14:A2ED).
- New-game screens (waits 719-1610): DMG ~55, CGB ~15. Costs: CHR upload to the shadow
  (hle_chr_pages, ~4 frames per full upload on DMG: BG pages could be left in ROM like the
  sprite pages), menu text printer c62:DED0..DF01 ($2006 / $2007 per letter), window rows,
  the DMG LCD-off wait for vblank in rt_ppu_w1 (~0.5 frame per load, needed on hardware).
- Field entry (2857, 3061-3062): DMG ~27, CGB ~6 (map decompression, DrawMapAttributes,
  scan + re-coding ~1300 samples; CGB: maprb_b / repal_b -> fix vshow_own).
- Battle start (6126-6137): DMG ~26, CGB ~6 (same parts).
- In battle: DMG ~50 (about 44 heavy waits of ~1.6 frames: panel redraws: VWF text,
  hle_cp64 / hle_sw16, farcalls, rt_mmc_w5808, hle_pclr, boxline far code); CGB ~3.
- Bank 0 is full (~70 bytes free): move code to bank 60 (PF_BANK, room up to $7D00) or
  HLE_BANK (full at $5F00) behind a trampoline; equates used before their definition must
  be defined earlier (one-pass labels).

## Gotchas learned
- B and D must stay 0 at all times (BC = Y, DE = X for indexed addressing).
- Compare NES/GB at NMI k vs GB entering frame wait k (cynes `nmi_ram`), feeding the GB the
  pad the NES latched per NMI (`pad_history`); sync NES power-on save RAM into GB cart RAM
  (`compare.sync_sram`) — FF1 reads unwritten save RAM.
- PyBoy hooks on all labels are slow (minutes for 60 frames); background long runs and
  stream output with `python3 -u` without piping through grep.
- Never `rm -rf` with variables/globs (blocked by the safety check); write to new dirs.
