# Final Fantasy III: MMC3 → MMC5

`build.py` converts the Japanese FF III ROM (MMC3, 512KB) into a 1MB MMC5 ROM. Banks
0-63 stay where they were; banks 65-125 are free for the English script. See the
docstring in `build.py` for the full register mapping.

Points that needed care:
- **Scanline IRQ.** MMC3 counts down and fires around dot 260 of a line; MMC5 compares
  an absolute line and fires at its start. The game only uses two patterns: (1) the NMI
  handler writes latch L + reload + enable during vblank → fires on line L-1; (2) after
  an IRQ on line s, code writes latch V without reload → fires on line s+1+V (chained
  raster effects). Helper routines in ExRAM ($5C00) keep the current target and
  reproduce both. The IRQ entry waits 85 CPU cycles so the game's handler runs at
  the same point of the line as on MMC3.
- **No free space in the fixed banks**, so the helpers live in MMC5 ExRAM (mode 2,
  CPU RAM), copied there by the reset code from bank 64. The MMC3 reset code that set
  up CHR banks and pre-clocked the IRQ counter is replaced by MMC5 init.
- Mirroring writes become JSRs to ExRAM helpers that set `$5105`; A/flags preserved.
- Not reproduced (no visible effect found): MMC3's spurious counter clocks from VRAM
  address changes during forced blank, and a one-line jitter (line 149 instead of 150)
  of the battle-window split in some frames; both lines are black.

## Verification
`tools/split/equiv2.py`-style comparison (original vs converted, identical random input,
every frame compared). Needs the patched emulator (`tools/emu/build_emu.sh`), which
implements the MMC5 scanline IRQ (fires at dot 4 of line N = $5203, N ≥ 1).
