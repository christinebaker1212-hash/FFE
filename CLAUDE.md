# Working rules for this repo

- **Do not use subagents** (no Agent/Task delegation, no workflows). The project owner
  wants all analysis and translation done directly in the main session.
- Follow `README.md` (translation rules) and `docs/translation-guide.md`.
- Never commit ROM images. Commit and push work frequently.
- ROMs for work sessions live in `roms/` (git-ignored). Check them against the SHA-1s in
  `README.md` before use.

# Game Boy ports (set by the project owner — binding)

The English translations are being adapted to the Game Boy. Design: `docs/gb-port.md`.

## Targets
| Game | Target | Cartridge |
|---|---|---|
| Final Fantasy I | Game Boy (DMG) with Super Game Boy support (SGB palettes/border) | Largest mapper needed (MBC5, sized to the game) + battery SRAM |
| Final Fantasy II | Game Boy (DMG) with Super Game Boy support | same as FF1 |
| Final Fantasy III | Game Boy Color | MBC5 + battery SRAM |

FF1 comes first, then FF2, then FF3.

## What the repo may and may not contain
- **Tools only.** Do not pack FF's characters, art, music, maps, story or code into the
  repo. Every game-specific byte comes from the user's own NES ROM when the build runs.
- **Nothing is distributed.** No prebuilt GB/GBC ROMs, no ROM-derived data files, and no
  patch that contains game content gets committed or published. The only user is the
  project owner, who builds locally.
- Building a GB ROM **requires the original NES ROM** as input. The pipeline is NES ROM → existing
  MMC5 split + English insert (`tools/split`, `tools/ff1/insert.py`, …) → GB build
  (`tools/gb/`) → GB ROM in `build/` (git-ignored).

## Approach
- **Static recompilation** of each game's own 6502 code to SM83, not a hand-written
  re-implementation. Game logic, formulas, RNG and events stay exactly as on the
  Famicom, and the English patch carries over without changes.
- A runtime layer converts NES PPU/APU/mapper writes to Game Boy hardware: tiles
  (NES planar → GB interleaved), nametables → BG map, attributes/palettes → SGB
  palettes (DMG) or CGB palettes (GBC), OAM, scroll through a camera, APU → GB sound
  (triangle → wave channel).
- The screen is 160×144 instead of 256×240. The field uses a camera centred on the
  party. Dialogue, menus, shops, battle, title and ending get re-laid out for 20×18
  tiles. The translation text stays the same; only wrapping/layout changes. Until a
  screen is re-laid out, the camera pans over it.
- Tools are Python 3, with no outside toolchain (own SM83 assembler, like
  `tools/asm6502.py`). PyBoy (`pip install pyboy`) is used for headless GB testing.
- Verification: run the NES (`tools/emu`) and GB builds side by side with the same input
  and compare emulated RAM frame by frame (as in `tools/split/equiv.py`), plus
  screenshots of every re-laid-out screen.

## Keeping this file current
Update the status below as work goes on (about every 5 minutes of work): work done,
work remaining, scope and plan. Commit and push it with the work.

# GB port status (last updated 2026-11-17)

## Scope and plan
FF1 first (DMG+SGB), then FF2 (same engine family, DMG+SGB), then FF3 (GBC).
Milestones per game (from `docs/gb-port.md`):
1. SM83 assembler + minimal runtime that boots in PyBoy (test pattern, SGB detect).
2. Recompiler on the fixed bank only; title screen shown through the camera (pan mode).
   Measure CPU time per frame on DMG speed.
3. Whole game recompiled; emulated RAM matches the NES across random play.
4. Sound (APU → GB).
5. Screen re-layouts for 160×144: dialogue, then menus/shops, then battle, title, ending.
6. SGB palettes + border, save RAM, timing, accuracy pass.

## Done
- Design notes: `docs/gb-port.md` (targets, memory map, PPU/APU layers, verification).
- ROMs checked (SHA-1 OK) and kept in `roms/` (ignored). The English FF1 NES build
  (`build_mmc5.py` + `tools/ff1/insert.py`) reproduces the patch's result SHA-1
  `76aa4d30…`; this is the GB build's input (`build/ff1_en.nes`).
- PyBoy 2.9 installed for headless GB testing (reinstall each session: `pip install pyboy`).
- `tools/gb/asm_sm83.py`: SM83 assembler (multi-bank, `bank()`/`low()`/`high()`, `.sym`
  output, header/checksum writer `make_rom`). `tools/gb/test_asm.py` checks all 500
  opcodes (encoding + length) against PyBoy's opcode table: 0 bad.
- Milestone 1 (except SGB detection): `tools/gb/boot_test.py` builds
  `tools/gb/rt/boot_test.s` (DMG header + SGB flag, MBC5+RAM+battery) into
  `build/boot_test.gb` and checks it in PyBoy: one vblank IRQ per frame, save RAM write,
  3-shade tile pattern on screen. `tools/gb/rt/hw.s` = hardware register names.

- NES emulator (`tools/emu`) now also logs code coverage: env `COV_LOG=FILE` ORs one
  byte per ROM file offset (bit0 executed, bit1 reached by RTS, bit2 by JMP (ind),
  bit3 by RTI, bit4 interrupt entry); RAM code at file index $200000+addr.
  Findings: vectors NMI `$FECF`, RESET `$FE2E`, IRQ `$FEEE`; the English patch runs
  helper code in MMC5 ExRAM `$5C00-5FFF` (image in bank 18, copied at reset), which the
  recompiler must compile from that image.

- Emulator coverage log extended to 3 planes (code / memory regions per instruction /
  stack tricks via a shadow JSR stack), and it follows MMC5 `$5116` (8KB at `$C000`).
- `tools/gb/covrun.py` (new game + random play under COV_LOG) and `tools/gb/nescode.py`
  (code map: coverage seeds + static flow, code spaces bNN/c62/far/fix/ex, report of
  unresolved targets, stack tricks, indirect accesses).
- FF1 engine facts for the port: the game is synchronous. `JSR $FE00` enables NMI and spins;
  the NMI handler `$FECF` drops the interrupt frame (PLA×3) and RTSes to the caller,
  so on GB this becomes "halt until vblank, return". The English patch uses MMC5 PRG
  mode 2: `$C000-DFFF` is 8KB bank 62 normally, far-code bank 40 during `farjsr` (RTS
  dispatch from ExRAM `$5D0B`). Other stack tricks: `b14:A330` PLA PLA RTS (return to
  caller's caller), TXS resets at `$C024`/`$C0D3`/`$FE6F`. Jump tables: `JMP ($0010)`
  at `c62:CA99` and `b14:B187`. Fixed code JSRs into `$8000-BFFF` (bank from `$5115`).

- Coverage: 4 × 80k frames of random play (`build/cov2/`, regenerate with covrun.py): ~12k
  executed + ~6.6k statically reached instructions in b11-b14, c62, far, fix, ex.
  I/O is only by absolute address (no indirect PPU/APU access). MMC5: only bank, mode,
  RAM-protect and mirroring registers (no multiplier). PHP 8, PLP 9, TSX 1,
  BVC/BVS 5, `LDA $2007` 6 sites. Sprites: up to 28 visible, tiles mostly < 128
  (240-243 too). Both 4KB pattern tables are loaded in full.

- **First recompiled build runs.** `tools/gb/build.py` (NES ROM → English NES → recompile →
  assemble → `build/ff1_en.gb`, 1 MB MBC5, ~1.5 s): 16.6k instructions in 4 code banks,
  runtime in bank 0 (`tools/gb/rt/runtime.s`), NES data banks copied to GB banks 1-32.
  In PyBoy (`tools/gb/run_gb.py ROM FRAMES`) the opening prologue text shows in
  English (centre 160 px of the NES screen, palette untuned).

- New game → name entry → class select → field (Coneria) all run on the GB build.
  `tools/gb/compare.py NES GB OUT` runs both in **lockstep by NES frame** (cynes exposes
  `nmi_count`; the GB counts frame waits at `$D830`) and diffs RAM/SRAM at checkpoints:
  0 bytes at several checkpoints, a few bytes in `$B0-$D5` elsewhere (sound state).
- Speed: steady play runs 1.00× (one GB frame per NES frame). Screen loads lag; CHR
  upload loop `$E9F6` replaced by a native routine (`rt/ff1_hle.s`, recompiler `ext` table).
  `tools/gb/profile_gb.py` reports GB frames per NES frame and PC samples in long loads.

- **Exact equivalence check:** `tools/gb/firstdiff.py NES GB [FRAMES] [--random SEED]`
  runs both builds frame-locked (cynes exposes `nmi_count`, `nmi_ram` = RAM at each NMI,
  `pad_history` = pad latched per NMI, `trace`) and compares NES RAM at NMI k with GB
  RAM on entering frame wait k (PyBoy hook). The new-game script (3662 frames) is
  **byte-identical** on GB. `tools/gb/tracediff.py NES GB K` compares the instruction
  sequence of frame K (NES trace vs GB label hooks) to find the first divergent
  instruction.
- Sprite tile cache (DMG has 384 tiles vs NES 512): 128 GB sprite slots, all 256 NES
  sprite tiles shadowed in cart RAM bank 1, allocated on use by the OAM conversion.

- Recompiler additions: exact PHP/PLP (`rt_get_p`/`rt_set_p`; PHP/PLA and PHA/PLP pairs
  move P to/from A), idiom table (`b14:B0F1` TSX…TXS = drop 3 frames → `rt_unwind3`,
  farcall-aware), static bank resolution for `LDA #n / JSR $FE03 / JSR $8xxx` (17 of 25
  banked calls; reaches b01, b09 and more of b13 statically), `JMP (ind)` through
  non-RAM pointers. Build: 18.5k instructions, 5 code banks.

- Bug fixed by the random runs: `$2007` read clobbered B (B must stay 0: BC = Y).
  Random play now identical for 7208 / 9408 / 15440 frames (seeds 2 / 3 / 1), then a
  pointer `$82/$83` + `$9B` divergence (being traced).
- Sound: `tools/gb/rt/apu.s` (pulse 1/2 → CH1/CH2, triangle → CH3 wave, noise → CH4,
  `$4015` mutes; volume changes retrigger). Tables (2048-entry timer→GB frequency, noise
  NR43) generated by build.py into bank 33 (RT_TABLES); code banks start at 34. FFT of
  the prologue music matches the NES pulse pitches.
- Assembler relaxes out-of-range `jr` to `jp` automatically.

- Vertical wrap: NES nametables wrap at 240 rows, the GB map at 256 → SCY mod 240 plus
  an LYC split (`stat_isr`); towns/field now show the right rows.
- CPU timing loops (DEY/BNE or DEX/BNE to itself, 5 sites) → `rt_delay_c/e`, calibrated
  to NES time.
- Debug tools: `crashfind.py GB SEED STEPS` (GB alone with the profiler's input; traps
  rst $38 / re-boot and prints the stack), `profile_gb.py --random SEED STEPS`.

- Crash fixed: `PLA PLA` (drop a return address) in battle code popped a farcall frame
  when the routine had been entered from another GB bank; drops now go through the
  farcall-aware unwinder (`rt_unwind1`). Seed-2 random replay: no crash in 16k frames.
- Speed over 13.7k NES frames of random play: 1.16× (GB frames per NES frame); the lag
  is in screen transitions (`$2007` shim ~32%, LCD on/off waits, CHR uploads).
- Layout plan: `docs/gb-screens.md`. Dialogue box: built through the map-row buffers
  (`$07C0`, routine `$D54B`), text origin column `(($29+$12)&$1F)*2`, row `$2F*2+3`.

## In progress / next
- Random-play equivalence after the crash fix (`build/eq5/`), fix what it finds.
- Screen layout (milestone 5), starting with the dialogue box; per-screen camera register.
- Speed: faster `$2007` nametable path; SGB palettes/border (needs an SGB-capable test
  emulator; PyBoy has none).
- Recompiler and PPU-layer design written up in `docs/gb-port.md` §1-2 (registers X→E,
  Y→C; NES stack on the GB stack; flag liveness; ROM data through a bank-0 helper;
  queued VRAM writes; tile/nametable/scroll mapping).
- SGB packet sender + detection (MLT_REQ): PyBoy has no SGB, so it gets written with
  the SGB palette work (milestone 6) and is checked in an SGB-capable emulator then.

## Remaining (FF1)
- Milestones 2–6 above. FF2 and FF3 not started.
