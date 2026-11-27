# FF3 Game Boy Color build: architecture and plan (tools/gb3n/)

Status and history: `docs/ff3-gb-status.md`. This file is the map of the code and the plan for
what is left, kept current as the work goes on.

## Build
- `python3 tools/ff3_mmc5/build.py "roms/Final Fantasy III (Japan).nes" build/ff3_mmc5.nes`
- `python3 tools/ff3/insert.py build/ff3_mmc5.nes build/ff3_en.nes` (SHA-1 4a7f1ae4...)
- `python3 tools/gb3n/build.py [--map M[,WORLD[,X,Y]]]` -> `build/ff3n.gbc` (+ .sym). Default start:
  FF3's New Game (map 0, world 0). `--map 255,W,X,Y` starts on world W's map. Env `GB3N_GAPS=bank`
  lists free space in a code bank. The build asserts that RAM sections do not overlap.
- Test: `build/sbsh` + `build/sameboy_libretro.so` (SameBoy ea667ad + `tools/gb/sameboy/
  sameboy-ffe.patch`; rebuild notes in docs/ff3-gb-status.md). `SB_LCHK=1` strict checker; `v`
  = VRAM/OAM violations. Models: "Game Boy Color", "Game Boy", "Game Boy Pocket", "Super Game
  Boy", "Game Boy Advance" (exact names).

## ROM banks (16 KB)
| Bank | Contents |
|---|---|
| 0 | vectors, boot, Color-only notice, interrupts, frame wait, pad, memcpy / far_copy / far_byte, palettes apply / black, map_change (guarded load) |
| 3 B_MAPINFO | map properties (512 x 16), 7 tilesets (1 KB each), trigger tables, window colours, NES colour -> RGB555 |
| 4 B_MAPAUX | general palettes, tilemap / subset ids per map, sprite / character palettes, tilemap stream index, subset index, exit tables, player poses |
| 5 B_EVENTS | NES bank $10 (entrances, treasures, triggers, prices) |
| 6 B_CHARS | map character graphics (64 sets x 16 tiles) |
| 8-11 | tilemap streams (RLE, repacked) |
| 12-16 | graphics subsets (112 tiles each) |
| 17 B_COMMON | menu window / text tiles (144) |
| 18 B_NPCS | npc graphics ids, speeds, poses, init sram tables, npc graphics index, chest contents |
| 19 B_NPCGFX | npc graphics ids $40+ |
| 20 B_OWN | our font / frame tiles, the notice screen, window font, FF3 code -> ASCII |
| 21-27 B_TEXT | text index + English strings (story, system, dialogue 1 / 2, names) |
| 28 B_SCRIPT | NES banks $2C/$2D (npc lists, trigger / npc / event scripts) |
| 29 B_FIELD | field code: maps, walking, people, text, events, world map |
| 32-47 B_WORLD0 | the four world maps unpacked (4 banks each) |
| 48 B_WINFO | world tilesets, palettes, entrance tables |
| 49 B_WGFX | world BG tiles (3 x 256) |
| 50-53 B_SND0 | NES bank $36 (driver tables, songs $2B-$36, sound effects) + song bank $37 / $38 / $39 / $09 |

## RAM
- Work RAM bank 0: $C000 OAM copy, $C100 field variables, $C200 dialogue, $C240 events, $C2B0
  helpers, $C2C0 world, $C300 line buffer, $C380 people variables, $C400 map (32 x 32), $C800-
  $CEFF metatile tables (UL, UR, DL, DR, palette, property 1, property 2), $CF00 stack.
- Work RAM bank 1 (always mapped): $D000 FF3's save page ($6000-$63FF layout), $D400 / $D500 people
  (FF3's $7000 / $7100), $D600 text buffer (1 KB), $DA00 scratch (1 KB), $DD00 sound (FF3's $7F40 page + temporaries), $DE00 people poses,
  $DF00 Color palettes (72), $DF80 player poses.
- VRAM: BG in $8800 mode; bank 0 = map / world tiles (FF3's tile numbers), bank 1 = sprites (party
  0-15, people 16 + 16 * slot), our font at $9000 (tile = ASCII) and FF3's frame at tiles $10-$17.
  BG palettes 0-3 the map's, 7 the windows; OBJ palettes 0-3 FF3's sprite palettes.

## Sound (done: docs/ff3-gb-status.md "Sound")
`src/sound.s` in bank 0 ($1000-), tables `snd_ftab` ($3000, NES period -> GB frequency) and
`snd_ntab` ($2FC0) made by build.py; banks 50-53 `B_SND0`. Game calls: `mus_play` (A = song),
`sfx_play` (A = effect), `M_CTRL` (2 resume, 4 stop, 8 + 4 fade out). Check harness: py65 runs
FF3's driver (MMC5 build: song bank by a `$5115` write) against SameBoy's `$DD00` page.

## Battle (in progress; FF3's rules exactly)
Banks: 54 `B_BAT` battle code ($4000 batcore, $5800 batmagic, $6C00 batinit, $7800 batequip), 55
`B_BDAT` = NES $30/$31 as mapped in a battle, 56 `B_BDAT2` = NES $2E + $01, 57 `B_BDAT3` = NES
$38 + $39. RAM: `BZ` $C400 = FF3's zero page; work RAM bank 2 during a battle: NES $6000-$63FF ->
$D000 (save page copy), NES $7400-$7FFF -> $D400 (records $7575 chars / $7675 monsters, $7400
buffer, $78DA message queue, $7BE3 random table, $7E4F / $7E5F numerals); $C500 our battle
variables, $C600 / $C700 the inventory sort buffers. Macros `%LDZ` / `%STZ` / `%PZ` / `%MOVZ`
(build.py) do FF3's (zp),Y; writes through a pointer into FF3's ROM range go to a dummy.
Tables of FF3's code banks are filled from the ROM after assembling (`ROMDATA` in build.py).
Test: `GB3N_TEST=1 python3 tools/gb3n/build.py --out build/ff3n_test.gbc`, then
`python3 tools/gb3n/test/batdiff.py N [--seed S] [--only init,equip,monact,fight,magic,item,...]`.

Bank 58 `B_BAT2`: battle flow (`batflow.s`); bank 0 $0450: shared helpers (`batlib.s`, `alg_call`).
Test routines 10-13 (order, exec, over, cannon) run with NES banks $34/$35 mapped.

## Battle screen facts (from the listing; for our presentation)
- Text: names8800 (our TB_NAMES) holds item names (id), spell names ($C8 + id), monster names
  ($120 + id), battle messages and command names ($220 + n); status messages are t8200 ($0C + n,
  middle right $78D9) and t8200 (n - $46) for top-right ids $52-$7F. Top right $78D7: $00 Miss,
  $01-$20 n hits (message $13 after the number), $21-$38 summon names (monster names $E7 + ..),
  $39-$51 battle messages (n - $39), $52-$7F status, $80+ spell names (n - $80); $72 set: an item
  name. Middle left $78D8: target ($FF none, $80+ monster slot -> $7ECD -> $7D6B id, $88 "all"
  = message $16, else a character). Top left $78D6: attacker.
- Action scripts 34/950D (by $78D5): 0 fight, 1 magic/command, 2 message, 3 cannon, 4 level/skill
  up, 5 poison; commands 34/954D: close windows, show attacker / attack / target / status /
  battle message (queue $78DA + [$78EE]; variable types 34/9575, a nybble each: 0 none, 1 text
  + wait A, 2 hp (peep: $78E4 values), 3 number ($78E4) + wait A, 4 item name + wait A), wait,
  animation (34/8411: by $7EC2 through 34/83F8), damage numerals ($7E4F targets / $7E5F
  attackers, bit 15 green, $40 in the high byte = miss), death animation.
- State changes inside FF3's animations (ours must do them): a monster death (2F/BB0A): for each
  dying slot $7DD3[type] += 1 (experience), $7DA7[slot] = $FF, then 2F/B909 recount ($7DCE-$7DD1
  per type, $7DD2 total); monster summon (2F/B959): living slots' $7DA7 from $7DAF, recount;
  dead monsters = $7EC4 bit 7 (34/84C7).
- Commands: 34/9B21 four command ids per job (ROM); names $220 + id; left / right twice: row
  change (front / back; swapped in a back attack). Handlers 34/9A16: 2/3 rows, 4 attack (targets),
  5 defend, 6 run, 7 escape, 8 jump (a monster), $0B terrain, $0C peep, $0D scan, $0E steal,
  $0F buildup, $10 sing, $11 scare, $12 cheer, $14 item (35/ADAF), $15 magic (35/B646). Records:
  +$2E action, +$2F targets, +$30 target flags ($80 monsters, $40 all), $7AC3 + i the command
  slot, $78CF + i the command id, $7AC7 + i the spell level, +$3E / +$3F an item in use.
- Battle setup 2E/9E8E: $7CED battle id (+ $7CEE boss), $7CEF bg, $7ED8 flags; monster set
  2E/8000 + 2 id -> set 2E/8400 + 6 n (2 palettes, 4 monster ids -> $7D6B), counts 2E/8A00 + 4 n
  randomized (2F/A0C8: low / high nibble, rng 0); tilemap id $7D7B (2E/9FAA); slots $7DA7 / $7DAF
  by 2F/A4DA; positions 2F/A5E6 (x, y, size per slot); RNG table 3F/FC27.

## Battle: still to write
- Main loop bookkeeping: 34/81C3, 8213, 8271 (command use counts), 8295 (monster rows), 8306,
  8374 (inventory / run flag), 874D / 87AA / 87BE, 9474 (near fatal), 9CE3 (init), 88A4 (rows).
- Poison 35/BA41, victory 35/BB49 (+ level-up stats BF7C, give item BFB3).
- Commands (34/986C: ours, writing the same records), messages / numerals / animations (ours,
  reading FF3's message queue $78D5-$78EE, $7E4F / $7E5F, $7E99 / $7E9B), battle init 2E/9E8E
  (formation, monster counts 2F/A0C8, graphics), random encounters 3D/BC5B.

Formations: 2E/8000 battle -> (set, count id); 2E/8400 set: 2 palettes, 4 monsters; 2E/8A00
counts (min / max nibbles, $2F $A0C8 rolled with FF3's RNG); graphics by 2E/8B00 size class
($2F $A4B4 / $A4CC; bosses size 6-7: boss tilemaps 2A/8000); palettes 2E/8C00 (3 colours).
Algorithms bank $30 / $31: fight effect $30 $9E8A, init properties $31 $A400 / $A482 / $A4F6,
monster actions $31 $A732, hits $BB28, damage $BB44, status, rewards bank $35 ($BB8D). Monster
properties 30/8000, stats 30/9000, attack scripts 30/9200, weapons 30/9400, armour 30/96C0,
attacks 30/98C0, gil 30/9C58, exp 10/9C80 / 9D80. Command input bank $34.

## After: menus (mock-ups sent), title / New Game names, saves + suspend (Lot Check: cart RAM
enabled only around access, checksums, error screens), random encounters ($3D $BC5B), vehicles,
inns / shops, jobs.
