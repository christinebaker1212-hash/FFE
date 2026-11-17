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

## In progress / next
- Long coverage runs (4 seeds × 80k frames, `build/cov2/`), then the recompiler
  (`tools/gb/recomp.py`).
- Recompiler and PPU-layer design written up in `docs/gb-port.md` §1-2 (registers X→E,
  Y→C; NES stack on the GB stack; flag liveness; ROM data through a bank-0 helper;
  queued VRAM writes; tile/nametable/scroll mapping).
- SGB packet sender + detection (MLT_REQ): PyBoy has no SGB, so it gets written with
  the SGB palette work (milestone 6) and is checked in an SGB-capable emulator then.

## Remaining (FF1)
- Milestones 2–6 above. FF2 and FF3 not started.
