# FF1 on the Game Boy: screen-by-screen layout plan (milestone 5)

The GB shows 20×18 tiles. Until a screen is re-laid out, the runtime shows the centre of
the NES screen (NES tile columns 6-25, rows 6-23; `CAM_X/CAM_Y` in `rt/runtime.s`). This
is a stopgap only.

## Approach
- **Layout stays on the NES side.** A GB variant of the English inserter
  (`tools/ff1/insert.py --gb`, to be written) moves and resizes FF1's windows and re-wraps
  the English text for the GB view. The recompiler then carries the result over like any
  other code, so the frame-exact NES/GB checks (`firstdiff.py`) keep working against
  that NES variant.
- **Camera per screen** (fixed per screen, never panning). The NES code tells the runtime which part of the 256×240 screen to
  show by writing a reserved register (planned: MMC5 `$5130-$5131`, unused by FF1; the runtime
  treats the writes as camera X/Y in tiles). The field keeps the centred camera, and
  a re-laid-out screen can sit anywhere on the NES nametable.
- **The translation text does not change.** Only line breaks (wrap width) and window geometry
  change. Names stay in full (README rule 3): where a name no longer fits on one row,
  it uses the two-row form the English patch already has for long names.

## Style (owner's decision)
Take inspiration from SaGa 3 (Final Fantasy Legend III) and other Game Boy RPGs instead of
shrinking the NES layout: no two-character-panel splits, no panning. Common elements:
- **Party list window**: one line per member (name, HP current/max, status), full width.
  Used in the main menu, shops, inn, item/magic targets and battle.
- **Full-width windows** stacked vertically; command windows open over the party list.
- **Battle**: enemy graphics in the upper part of the screen with the **party sprites
  visible** beside them (owner's decision), each member's name/HP next to their sprite or
  in a party list; the command window and battle messages open over the lower part. No
  blinking (owner, 2026-11-18: the cursor is enough).
- Implementation: FF1's own drawing code is changed (NES side). A runtime compositor that
  rearranges the finished NES picture was considered and rejected.
- Exact layouts get drafted as mock-ups (rendered with the real font) before the NES
  code is changed.

## Screens
| Screen | NES layout (English build) | GB plan | Status |
|---|---|---|---|
| Prologue / story pages | 20×9 text box at (2,?) over the title picture | 18-col wrap, box 20 wide; camera on the box | todo |
| Title menu | boxes at (11,10), (11,15), (8,20) | fits the centre view after moving the third box up | todo |
| Class select | 4 boxes 2×2 across 32 cols | 2×2 boxes of 9 cols (two-row class names) | todo |
| Name entry | 10-col letter grid + name box | fits (grid is 20 cols incl. frame) | check |
| Field | 16×15 metatiles | centred camera (10×9 metatiles) | done |
| Dialogue | 25 cols × 9 lines | 18 cols × 7 lines per page, same text, more pages | todo |
| Main menu | orb, Gil, commands, 4 character boxes | command window + Gil/orbs, party list window (one line per member); details on the Status screen | todo |
| Item / Magic / Equip / Status | full-width lists | one column, pages (items 13, magic 3 levels, equip 2 members), status in two windows | done (NES side) |
| Shops, inn, clinic, church | speech + list + Gil windows | SaGa style (owner): speech on top, full-width list, Gil always shown, no shop scene | done (NES side) |
| Battle | enemies 3×3 grid left, party right, command + message boxes bottom | SaGa-style: enemy graphics on top (up to 5 small per row), party list window at the bottom, commands/messages over it | todo |
| Battle magic/item lists | full-width | one column | todo |
| World map (minimap) | 64×64 px map in a box | fits | check |
| 15-puzzle | 4×4 grid | fits | check |
| Ending / credits | text pages | 18-col wrap | todo |

## SGB colour
Each NES palette (4 BG + 4 sprite) becomes one of the four SGB palettes; the attribute
map is sent as `ATTR_CHR` when a static screen's layout changes. The field uses one
palette set per map (no per-frame attribute updates).
