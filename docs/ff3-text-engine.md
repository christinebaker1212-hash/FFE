# Final Fantasy III (J) — text engine notes

ROM: mapper 4 (MMC3), 512KB PRG, CHR-RAM, battery. Offsets below are file
offsets **without** the 16-byte iNES header. 8KB bank N lives at `N*0x2000`.

## Font
Background font tiles are at `0x1B000` (256 tiles, 2bpp). Tile number = character code.

| Codes | Meaning |
|---|---|
| `00` | end of string |
| `01` | newline (each line uses 2 tile rows: the upper row holds ゛/゜) |
| `02`–`0F` | control codes without parameter (item name, numbers, party names …) |
| `10`–`27` | control codes with one parameter byte (`14 xx` = set column to xx; `18 xx` = insert name-table string xx) |
| `29`–`41` | hiragana が…ぽ (base tile + mark) |
| `42` | ヴ |
| `43`–`5B` | katakana ガ…ポ |
| `5C`–`75` | icons (weapon/armor/magic-type icons, etc.) |
| `76`–`7A` | E H M P X (Latin letters used in "HP", "MP", "EXP") |
| `7B`–`7F` | を っ ゃ ゅ ょ |
| `80`–`89` | 0–9 |
| `8A`–`B6` | hiragana あ…ん |
| `B7`–`BF` | small ァィゥェォッャュョ (shared by hiragana and katakana) |
| `C0`–`C9` | 、(also ゛) 。(also ゜) ー ‥ ! ? % / : 『 |
| `CA`–`F6` | katakana ア…ン (ヘ shares the hiragana へ tile; `E6` is 「) |
| `FF` | space |

Dakuten base table: `0x7F4E1` (indexed by code−0x28); mark table: `0x7F515`.
A copy of both is at `0x75F90`.

## Text routine
`$EE9A` (fixed bank, file `0x7EE9A`): string ID in `$92`, pointer table in
`$94/$95`. Each pointer is 2 bytes: `lo`, `hi`; address = `lo | ((hi & 0x1F) | 0x80) << 8`,
8KB bank = `(hi >> 5) + 0x18`. So all text is in banks `0x18`–`0x1F` (file
`0x30000`–`0x3FFFF`). The character loop is at `$EEFA`.

## Pointer tables (all in bank 0x18)
| File offset | CPU | Contents |
|---|---|---|
| `0x30000` | `$8000` | story narration / event dialogue (table A) |
| `0x30200` | `$8200` | system messages, shops, chests, NPC names (table B) |
| `0x30600` | `$8600` | event dialogue (table C) |
| `0x30800` | `$8800` | name table: items, magic … (used by control code `18 xx`) |
