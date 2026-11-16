# Final Fantasy I (FF I・II cart, J) — text engine notes

Cart: MMC1 SUROM, 512KB PRG (FF1 = first 256KB, FF2 = second 256KB), 8KB CHR-RAM.
FF1 fixed bank: file `0x3C000` at `$C000`. Offsets are file offsets without header.

## Encoding (font tiles at `0x24000`; tile = code for `7A`–`FF`)
| Codes | Meaning |
|---|---|
| `00` | end; `01` newline; `02` insert name from item table (index in `$61`); `03` insert number from `$6102` |
| `04`–`47` | used by menu routines as their own control codes (e.g. `04` = gold amount) |
| `48`–`79` | が…ど, ば…ぼ, ガ…ド, バ…ボ, ぱ…ぽ, パ…ポ (base table `0x3DD47`, mark table `0x3DD79`) |
| `7A`–`7F` | / を っ ゃ ゅ ょ |
| `80`–`89` | 0–9; `8A`–`B6` あ…ん; `B7`–`BF` small ァィ。ェォッャュョ (`B9` = 。) |
| `C0`/`C1` | ゛/゜ tiles; `C2`–`C5` ー ‥ ! ?; `C6`–`C9` L E H P; `CA`–`F6` ア…ン; `FF` space |

Dialogue routine: `$DB58` (A = string ID). Swaps in 16KB bank `0x0A`, table at `$8000`.
Pointers are plain CPU addresses (`$8000`–`$BFFF`) in the same bank.

## Tables (see `tools/ff1/extract.py`)
| Name | Table | Strings |
|---|---|---|
| dialogue | `0x28000` (256) | `0x28200`– |
| items (items, weapons, armor, magic, classes, statuses; fixed-width) | `0x2B700` (256) | `0x2B900`– |
| enemy_attacks | `0x2B600` (26) | `0x2B638`– |
| battle_msgs | `0x2CF50` (78) | `0x2CC40`– |
| monsters | `0x2D4E0` (128) | `0x2D5E0`– |
| story (opening bridge text + ending) | `0x36800` (25) | `0x36832`– |
| shop | `0x38000` (38) | `0x3804C`– |
| menu | `0x38500` (64) | `0x38580`– |
| prologue / title_menu / battle_cmds | addressed by code | `0x37F20` / `0x3A26C` / `0x3FA31` |
