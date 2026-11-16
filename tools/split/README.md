# Splitting the FF I・II cart into two MMC5 ROMs

`build_mmc5.py` turns the Japanese FF I・II cart (MMC1/SUROM) into two standalone
512KB MMC5 ROMs: the game's 16 original banks, 15 free 16KB banks for the English
script, and a patched fixed bank at bank 31.

Patches (identical in both games, see the script for details):
- `$FE06` MMC1 control write → MMC5 `$5105` (vertical mirroring; the only value either game uses)
- `$FE1A` MMC1 PRG write → MMC5 `$5115 = bank*2 | $80` (PRG mode 1)
- both padded to the exact 34-cycle length of the MMC1 routines, returning A>>4 with the same flags
- MMC1 reset/half-select code at reset → MMC5 init (`$5100`=1, `$5102/3` PRG-RAM write enable,
  `$5101`/`$5127` CHR-RAM, `$5113` PRG-RAM bank)
- FF1: game-select menu call (`JSR $AD00`) removed. FF2: reset enters FF2's own start-up (`$FE4B`).

## Verification
`equiv.py` / `equiv2.py` run the MMC5 ROM next to an MMC1 control ROM (the original cart,
menu bypassed) with identical random input and compare every frame, RAM and save RAM.
Results: FF1 48k / 79k / 80k frames and FF2 47k frames identical (party creation, field,
towns, menus, battles). Needs the patched emulator: `tools/emu/build_emu.sh` (adds MMC5).
