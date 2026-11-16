# Final Fantasy III: MMC3 → MMC5

`build.py` converts the Japanese FF III ROM (MMC3, 512KB) into a 1MB MMC5 ROM. Banks
0-63 stay where they were; banks 65-125 are free for the English script. The
register mapping is in the docstring of `build.py`.

## Scanline IRQ
MMC3 counts scanlines down and raises its IRQ around dot 260 of a line; MMC5 compares
an absolute line number and raises it at the start of the line. FF III uses the MMC3
counter in three ways, each reproduced:

1. **NMI-armed split** (every frame in the field and in battle): latch L + reload in
   vblank → IRQ on line L-1. MMC5: `$5203 = L-1`; the IRQ entry waits so that the
   game's handler starts on the same dot as with MMC3 (calibrated against the MMC3
   handler's `$E000` write in the emulator).
2. **Chained single splits** (banks $10, $1F, $32): right after an IRQ on line s the
   game writes latch V and re-enables → next IRQ on line s+1+V. MMC5: a helper sets
   `$5203 = s+1+V` and enables. (The helper costs ~24 CPU cycles more than the two
   MMC3 register writes; see "Open points".)
3. **Battle raster effect** (bank $2F, an IRQ every 2 lines for 108 lines, rewriting
   `$2000` twice per pair). Its timing relies on MMC3 raising the IRQ mid-line while
   the game already waits, which MMC5 cannot do, so the loop is replaced by an
   equivalent MMC5 routine: table value k is written at the start of line 40+k by
   polling MMC5's pending flag, which gives the same picture (value k shows on line 41+k).

The helpers live in MMC5 ExRAM ($5C00, mode 2), copied there by the reset code from
bank 64: the fixed banks have no free space. The MMC3 reset code (CHR bank setup,
IRQ counter pre-clocking) is replaced by MMC5 init; the reset path is padded so the
game starts on exactly the same CPU cycle as the original.

## Verification (patched emulator, `tools/emu/build_emu.sh`)
- `equiv_test.py`: original and converted ROM side by side with identical random input;
  every frame, RAM and save RAM compared.
- `inject_test.py`: forces a routine to run in both ROMs (via the NMI trampoline) and
  compares the frames; used for the bank $2F battle effect (all 130 frames identical).

## Open points
- The chained single splits in banks $10, $1F and $32 are not yet verified in game
  (their scenes are not reached by random play), and the helper adds ~24 CPU cycles
  before the game's following mid-frame register writes at those sites.
- Not reproduced (no visible effect found): MMC3 counter clocks caused by VRAM address
  changes during forced blank, and the occasional one-line jitter (149 instead of 150)
  of the battle window split; both lines are black.
