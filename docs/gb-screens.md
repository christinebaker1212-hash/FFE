# FF1 on the Game Boy: screen-by-screen layout plan (milestone 5)

The GB shows 20×18 tiles. Until a screen is re-laid out, the runtime shows the NES
screen's centre (NES tile columns 6-25, rows 6-23; `CAM_X/CAM_Y` in `rt/runtime.s`).

## Approach
- **Layout stays on the NES side.** A GB variant of the English inserter
  (`tools/ff1/insert.py --gb`, to be written) moves and resizes FF1's windows and re-wraps
  the English text for the GB view. The recompiler then carries the result over like any
  other code, so the frame-exact NES/GB checks (`firstdiff.py`) keep working against
  that NES variant.
- **Camera per screen.** The NES code tells the runtime which part of the 256×240 screen to
  show by writing a reserved register (planned: MMC5 `$5130-$5131`, unused by FF1; the runtime
  treats the writes as camera X/Y in tiles). The field keeps the centred camera, and
  a re-laid-out screen can sit anywhere on the NES nametable.
- **The translation text does not change.** Only line breaks (wrap width) and window geometry
  change. Names stay in full (README rule 3): where a name no longer fits on one row,
  it uses the two-row form the English patch already has for long names.

## Screens
| Screen | NES layout (English build) | GB plan | Status |
|---|---|---|---|
| Prologue / story pages | 20×9 text box at (2,?) over the title picture | 18-col wrap, box 20 wide; camera on the box | todo |
| Title menu | boxes at (11,10), (11,15), (8,20) | fits the centre view after moving the third box up | todo |
| Class select | 4 boxes 2×2 across 32 cols | 2×2 boxes of 9 cols (two-row class names) | todo |
| Name entry | 10-col letter grid + name box | fits (grid is 20 cols incl. frame) | check |
| Field | 16×15 metatiles | centred camera (10×9 metatiles) | done |
| Dialogue | 25 cols × 9 lines | 18 cols × 7 lines per page, same text, more pages | todo |
| Main menu | orb, Gil, commands, 4 character boxes | commands + Gil on top; character boxes 2 per screen with the cursor deciding which pair | todo |
| Item / Magic / Equip / Status | full-width lists | one column, names in full (two-row form) | todo |
| Shops, inn, clinic, church | speech + list + Gil windows | stacked vertically, list one column | todo |
| Battle | enemies 3×3 grid left, party right, command + message boxes bottom | enemy area 12 cols + party 6 cols, 5-row command/message area; messages re-wrapped | todo |
| Battle magic/item lists | full-width | one column | todo |
| World map (minimap) | 64×64 px map in a box | fits | check |
| 15-puzzle | 4×4 grid | fits | check |
| Ending / credits | text pages | 18-col wrap | todo |

## SGB colour
Each NES palette (4 BG + 4 sprite) becomes one of the four SGB palettes; the attribute
map is sent as `ATTR_CHR` when a static screen's layout changes. The field uses one
palette set per map (no per-frame attribute updates).
