# Final Fantasy II (FF I・II cart, J) — text engine notes

FF2 occupies the second 256KB of the cart (file `0x40000`–`0x7FFFF`). "Bank" below =
16KB bank counted from `0x40000`; switchable banks map at `$8000`, the fixed bank
(file `0x7C000`) at `$C000`. Pointers are full CPU addresses.

## Encoding (runtime font: tile N at `0x64320 + N*16`)
| Codes | Meaning |
|---|---|
| `00` end, `01` newline (2 tile rows per line, upper row = ゛/゜) |
| `02`–`0F` | no-parameter controls (`02` item name, `03`/`04` numbers, `07` …) |
| `10`–`3A` | one-parameter controls (`14 xx` column; `18 xx` insert entry xx of the name table) |
| `3B` | blank; `3C`–`6D` が…ど ば…ぼ ガ…ド バ…ボ ぱ…ぽ パ…ポ (base `0x7EEE2`, mark `0x7EF15`) |
| `6E`–`77` | weapon/item icons; `78`–`7F` [ ] / を っ ゃ ゅ ょ |
| `80`–`89` | 0–9; `8A`–`B6` あ…ん; `B7`–`BF` ァ ィ 「 ェ ォ ッ ャ ュ ョ |
| `C0`–`C9` | 、 。 ー ‥ ! ? % M H P; `CA`–`F6` ア…ン; `FF` space |

Text routine `$EA8C`/`$EAE6` (fixed bank): `$93` = bank, `$94/$95` = table, `$92` = ID.

## Tables (see `tools/ff2/extract.py`)
| Name | Table | Bank |
|---|---|---|
| dialogue_a | `0x68000` | 0x0A |
| names (items, magic, key words; code `18 xx`) | `0x68200` | 0x0A |
| system (messages, menus, prologue, title, status names) | `0x68400` | 0x0A |
| dialogue_b | `0x58000` | 0x06 |
| events (cutscenes) | `0x77F00` | 0x0D |
| monsters | `0x56C44` | 0x05 |
| battle_magic (spells/items/enemy attacks as named in battle) | `0x570BB` | 0x05 |
| battle_msgs (commands, battle messages) | `0x57295` | 0x05 |
| ending | `0x53C00` (code-addressed) | 0x04 |
| guest_names | `0x41102` + 0x80·n (character templates) | 0x00 |

Name-entry kana grid: around `0x78487`–`0x78600` (to be replaced by a Latin grid).
