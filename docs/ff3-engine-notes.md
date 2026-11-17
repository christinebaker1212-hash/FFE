# FF3 engine notes (for the English insertion, tools/ff3/insert.py)

Addresses are CPU addresses; "bank n" is the 8KB bank in the 1MB MMC5 ROM made by
tools/ff3_mmc5/build.py (0-63 the game's, 64 the ExRAM image, 65-125 free, 126 = $C000
copy of $3E, 127 = $E000 copy of $3F). The engine is the same family as FF2's
(docs/ff2-engine-notes.md); most routines map one to one.

## Text (fixed bank)
- $EE9A draws string $92 of the table at $94/$95 (bank 18 pointer tables $8000 story,
  $8200 system, $8400/$8600 dialogue, $8800 names; pointer lo, hi: address lo | (hi & $1F
  | $80) << 8, bank (hi >> 5) + $18; $FF03 maps an 8KB pair). The decode is at $EEBB
  (text), $F0D2 (code 18 names, also $F21B via $F0C5) and $D1DA (system string copied to
  $7B00, 8-bit index). English: each table packed from its own even base bank (TBASE).
- $EE65 paged text: $EEC0 (re)draws from ($3E) at the window top, $EEE9/$EEF3 end/full,
  $EE86/$EE90 rows scrolled per line, $EF4C newline (two INC $1F), $F692 flush, $F6AE
  flush body (upper row $0780 then $07A0, tail $F715), $F086 recorded position row.
- Field window table $EDB2 (x) / $EDB7 (y) ...; window 0 (dialogue) 26 x 8 inside.
- Field loop: $76 = message id to show (table $94/$95) -> $EC8B.
- Opening narration: bank 58 $A72A, t8000 ids 0/1 through $C024 (window $25: 28 x 26).

## Battle (banks 52 $8000 / 53 $A000)
- Strings are assembled at $7AD7 (30 bytes in the Japanese) and converted by $966A into
  the window buffer at ($4E) (= $7200 after $9754, which clears $7200-$73FF), rows $18
  wide, the row above holding dakuten. English: $966A copies lists as laid out; the box
  calls use bconvb (tidy + split over the two rows).
- Strings are copied from the text tables by bank 53 $A609 -> $FD60/$FC92/$FD4A: the
  pointer is read as a linear offset from 16KB bank $0C (= 8KB $18); English: base per
  table (TB16). $FD4A now copies the terminating 0.
- Boxes: bank 52 $8D1B opens box A from records at $8E83 (9 bytes: top address, width,
  save buffer, bottom address, bottom-row save pointer); 0 attacker, 1 action, 2 target,
  3 result, 4 message. English: widths 12/15/12/15/28, saves in ExRAM $5E90-$5FFF.
- Windows from coordinates: bank 52 $8B38 ($18 left x, $19 right x, $1A ...), widths in
  $78B8/$78B9 (the part past the nametable edge).
- Command window: bank 52 $9A98 (four commands, table $8C40 = names 544+, each converted
  5 wide; window x 4-10; cursor table $8B00 (y, x) pairs). English: 8 wide from x 1.
- Status window lines: bank 52 $9BC1-$9CCE, line 18 wide: name, current HP, '/' at
  X $0C, then the max HP or a 5-cell slot (X $0D-$11) with the chosen command ($8C40),
  spell ($8990, with its icon at $0C overwritten by '/') or ailment (t8200 $822C).
