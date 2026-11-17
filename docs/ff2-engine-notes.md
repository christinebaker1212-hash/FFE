# FF2 engine notes (for the English insertion, tools/ff2/insert.py)

Addresses are CPU addresses; "bank n" is the 16KB bank in the FF2 MMC5 ROM
(tools/split/build_mmc5.py: banks 0-14 the game's, 15 the old fixed bank (free),
16-30 free, 31 the fixed bank at $C000).

## Text drawer (fixed bank)
- $EA54 paged text (window full -> wait, scroll a line at a time by redrawing from the
  next line, $E7D4/$EAAC); $EA8C single draw; $EAAC (re)draw from ($3E) at the window top
  ($38,$39), width $3C, rows $3D; $EAE6 character loop.
- Line buffers $0780 (dakuten row) / $07A0 (main row), column $90; $F053/$F069 flush both
  rows to the screen, $3B += 2.
- Codes: 01 newline; 02-07 one byte (02/03/04 money/item via bank 14, 07 name at $6276);
  08-0E unused by the game; 0F bin; 10-13 xx character 0-3 field xx (00 name, 01 class,
  ...); 14 xx column; 15/16/17 xx column + record a cursor position (tables $78/$79/$7A,
  4 bytes each: x, y, next two string bytes; count at $7xF1, index at $7xF0); 18 xx name
  (table bank 10 $8200/$8300); 19 xx; 1A xx item in slot xx ($6060); 1B xx key word in
  slot xx ($6080).
- English: one tile row per line when ONE (ExRAM) is set: text banks 16-20, system
  strings flagged in SYSONE (bitmap by id), or a line starting with code 08.

## Text tables
- dialogue: bank 14 $9614 (id in A, bank by map $A0 < $60 -> dialogue_b, else
  dialogue_a; table $8000). English: banks 16/17 and 18/19, split by id.
- events: fixed $E8AA (id $76, bank 13 table $BF00). English: bank 20, table $8000.
- system: bank 10 table $8400 (callers bank 14 $95F2/$9603/$B3DF/$B3F0 and fixed
  $CB4B); $B3CD copies a system string to $7B00 first ($DAF1; English: ExRAM copystr,
  16-bit, also stores the id in $92).
- names: bank 10 tables $8200/$8300.
- ending: bank 14 $BAAF draws bank 4 $BC00 (English: bank 20).

## Menus (bank 14 window table $B48C x / $B4A5 y / $B4BE w / $B4D7 h; field windows fixed
$E9AA/$E9AE/$E9B2/$E9B6)
- cursor movement $96C5 ($78), $96F9 ($79), $972D ($7A, scrolls the list window by
  redrawing; state saved by $94EB, restored by $9523). Step in A = 4 x columns.
- item menu $AEC5 (English: ExRAM itemmenu, one scrolling column), equipment $B04B..,
  magic around $AF60, status $B36F, shop $8ED0 (NPC type; < $DC shop by map, DC-DF
  others), buy list template $9115 built by $90FD into $7B20 (English: ExRAM shoptpl).

## Battle (banks 5 and 12)
- $FD8C fetches string $64 of table ($62,$63) in bank X into $7D47+$AA (max 17 bytes).
  Callers (bank, table set by immediates): monsters bank 12 $BEF9 (bank 5 $AC44);
  messages bank 5 $A51A/$A7AB, bank 12 $ACED (bank 5 $B295); names bank 5 $A14B (bank 10
  $8200); status words bank 12 $9AB6 (bank 10 $8400, ids 240-255, 4-cell slot).
- boxes are drawn from the tile buffer $7600 (bank 5 $AB25: width $52, rows $53).
- free RAM after $7D47: up to $7D5D.

## English battle additions (insert.py)
- Battle text tables (bank 5 $AC44 monsters, $B0BB magic, $B295 messages) are read from bank 21
  (ExRAM fdbank in $FD8C); text buffer BUF $5E40 (ExRAM, 63 bytes); box save stack $5E80.
- Boxes (bank 5 $AC02): attacker/target 14 wide, action/result 15, message 28; text widths set
  at the conversion calls (BOX_W). The converter (bank 12 $95E7) splits a box text over the
  box's two rows at the most even space (btidy).
- Enemy list (bank 12 $9683, 8 columns): names with a word wider than 8 have compact tiles
  (bank 21 CNTAB); enname (fixed $F750) streams them into battle-only free tile slots (SLOTS:
  $4C-$4F never loaded in battle, unused kana) one per vertical blank, as the game streams
  monster tiles (bank 11 $9DA2).
- Free fixed-bank space used: $F750-$F7FF, $F850-$F8FF, $FF30-$FFAF.
