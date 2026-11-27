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

## RAM
- Work RAM bank 0: $C000 OAM copy, $C100 field variables, $C200 dialogue, $C240 events, $C2B0
  helpers, $C2C0 world, $C300 line buffer, $C380 people variables, $C400 map (32 x 32), $C800-
  $CEFF metatile tables (UL, UR, DL, DR, palette, property 1, property 2), $CF00 stack.
- Work RAM bank 1 (always mapped): $D000 FF3's save page ($6000-$63FF layout), $D400 / $D500 people
  (FF3's $7000 / $7100), $D600 text buffer (1 KB), $DA00 scratch (1 KB), $DE00 people poses,
  $DF00 Color palettes (72), $DF80 player poses.
- VRAM: BG in $8800 mode; bank 0 = map / world tiles (FF3's tile numbers), bank 1 = sprites (party
  0-15, people 16 + 16 * slot), our font at $9000 (tile = ASCII) and FF3's frame at tiles $10-$17.
  BG palettes 0-3 the map's, 7 the windows; OBJ palettes 0-3 FF3's sprite palettes.

## Next: sound (FF3's driver as native code)
Listing bank $36: update sound $8003 (sound effects $8B9D, music $8925, then the APU writes $8030
/ $80AB from shadows: per channel key-on flag $7F4A+ch, frequency $7F6D / $7F74, volume $7F7B,
duty $7F89, sweep $7F82; triangle $7F7D / $7F6F / $7F76; noise $7F7E / $7F70), channel scripts
$81E6 / $820B (notes < $E0: duration table $8805; $E0 tempo, $E1-$EE volume, $EF-$F4 octave,
$F5-$F7 envelopes + duty, $F8 sweep, $F9 / $FA drum presets, $FB-$FD repeats, $FE jump, $FF end),
envelopes $857D-$86D5, song init $89C3, fades $8AF0 / $8B11. Songs: banks $36 ($2B-$36), $37
($00-$18), $38 ($19-$2A), $39 ($37-$3A), $09 ($3B-$40). Plan: the sequencer and envelopes native
(same shadows), the GB output stage from FF1's snd.s (period -> GB frequency table, volume by
zombie-mode steps, triangle -> wave, noise), music from a timer at the NES rate; verify the
sequencer against FF3's own 6502 code in py65 (RAM for RAM), as FF1 did.

## Then: battle (FF3's rules; layout waits for the owner's mock-up choice)
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
