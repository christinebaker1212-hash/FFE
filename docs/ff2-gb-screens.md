# FF2 on the Game Boy: screen layouts (owner's decisions)

Mock-ups: `tools/gb2/mockup.py` (output in build/mock, graphics from the user's NES build).
Re-layouts are done in the NES code (NES side, `tools/gb2/layout.py`, applied after
`insert.py`), so frame-by-frame RAM checks against that NES variant keep working.

## Battle (approved 2026-11-19: `ff2_mock1_battle.png` + `ff2_mock5_battle_fit.png`)
- All 4 members and every formation fully on screen (owner).
- Survey (`tools/gb2/ff2form.py`, all 128 formations forced on the NES): enemies NES x
  16-159, y 48-143 (12 rows exactly); 126 formations within x 16-143, the Emperor (126)
  x 25-151, formation 90 (three 48-px monsters across) x 17-159. NES party: x 212-238
  (front x 212-214, back row 10-12 px right), y 45 / 72 / 99 / 126 (24 px tall, 27 apart).
- GB: battlefield rows 0-11 = NES y 48-143; enemy area = NES x 20-159 at GB x 0-139
  (formation 90 loses 3 px of an antenna at the left edge; owner's choice); party column
  GB x 140-159: front row x 140, back row x 144 (4 px), members at y 0 / 24 / 48 / 72,
  every sprite whole. The acting member steps forward (8 px, as FF1).
- Bottom rows 12-17: enemy names window (cols 0-7; the command window Fight / Run / Magic
  / Gear opens over it), party window (cols 8-19): name, HP current/max (3-px digits; "Dead"
  in place of the maximum as on the NES), MP. Messages: full-width window over both,
  style A (actor > target / action / result lines), small proportional font. No blinking.

## Field dialogue (approved: `ff2_mock2_dialogue.png`)
Box over the top of the view (GB rows 0-7: frame, 6 lines of 18 columns, frame), the party
below stays visible; same text re-wrapped at 18 columns, a new page of 6 lines on A.

## Main menu (approved 2026-11-19: option A of `ff2_mock4_menu_portraits.png`)
Owner: keep the portraits. Party window over the left 13 columns, full height, one 4-row
block per member: portrait (32 x 32), name, HP current/max, MP current/max (3-px digits),
status word. Commands (Items, Magic, Equip, Status, Save; cols 13-19 rows 0-6) and Gil
(rows 7-9) beside it.

## To draft
Items, magic, equipment, status, shops, keyword dialogue (Ask / Learn), save menu, name
entry, prologue, title, ending, world map (B + Select), Select menu (options / formation /
suspend).
