# FF1 native build: data tables against trusted sources (2026-11-24)

Owner: "Compare current data tables for all data against trusted sources."

Tool: `tools/gbn/audit.py` runs the native build with every read of the user's ROM logged (bank,
address, length, calling function; `Rom.rd` and the ROM's bytes, so tables found by searching the
code count too), merges the reads into ranges and compares each with the FF1 disassembly
(Entroper/FF1Disassembly, US release, cloned into `build/ref/` at work time, never committed): its
whole data banks, its table binaries and the literal tables in its source (`.BYTE` / `.WORD` /
`.FARADDR` after an address marker or a bank's start). A range that differs from the US data is
then compared with the original Japanese ROM. Nothing from the disassembly or the ROMs is kept in
the repository.

## Result

| Ranges | Result |
|---|---|
| 427 | identical to the disassembly at the address the build reads (layout and data agree) |
| 8 | partly covered by the disassembly's files: 0 bytes differ where covered (overworld rows, maps, weapons / armour / magic, music) |
| 146 | differ from the US data, identical to the original Japanese ROM: Japanese data or code layout (below) |
| 5 | changed from the Japanese ROM by the English pipeline: all expected (below) |
| 9 | in the English pipeline's own banks (text, font): nothing to compare in the disassembly |

No table is read from a wrong address, and no data the game uses was found damaged.

## Japanese data that differs from the US release (the build keeps the Japanese values)

- Level-up data (bank 0B $9094): 1 byte of 1100: the Red Magician's level 21 gains a level-5
  spell charge in the US release only.
- Encounter domains 68-73 (whole entries) and 115 (2 bytes), and enemy ids / counts in about seven
  battle formations (bank 0B): the US release changed these encounters.
- Tileset graphics (bank 3, 370 of 16384 bytes) and one map bank (bank 6, 504 of 708 bytes).
- Story and intro texts (bank 0D): Japanese text in the Japanese ROM.
- Code operands in banks 0E / 0F: the two releases' code is laid out differently; the build finds
  its operands by searching the code, so the positions differ but the values it takes are the same.

## Changed by the English pipeline (expected)

- The font (bank 9) and the menu / shop texts (bank 0E): the translation.
- Code in banks 0E / 0F changed by the English patch and the MMC5 conversion. Checked: the
  operands the native build takes from them are identical to the Japanese ROM's (all
  out-of-battle spells; the items, apart from one operand after the Soft routine that the
  build does not use; the shop tables).

## Also checked against the original Japanese ROM

Music score data (bank 0D $8000, 7584 bytes): identical in the user's ROM, the Japanese ROM and the
US release. Shop data, credits, The End drawing data and the 15-puzzle graphics: identical in all
three.

## Dawn of Souls data for "Modern MP" (owner's option)

The FINAL FANTASY wiki (finalfantasy.fandom.com, through its public API; the page itself sits
behind a browser check) gives the Dawn of Souls MP rules: a level's MP gain floor(INT / 4) + 1,
plus 10-12 on the job's guaranteed "strong" levels (the Final Fantasy stats page's table), and each
spell's MP cost (the Magic (Final Fantasy) page). Its guaranteed-growth table is Dawn of Souls
data and differs from the NES level-up table (268 of 294 entries): the NES game keeps its own; the
wiki's table is used only for Modern MP.
