# FF3 for the Game Boy Color: the native engine

Owner (2026-11-22): **"Using the lessons learned from Final Fantasy I GB's branch, continue native
translation of FF3 until 100% native code is achieved."** As for FF1 (branch
`claude/compassionate-bell-bo3yq2`, `docs/ff1-native.md`): FF3's engine is written by hand as
native Game Boy Color code from what the disassembly (everything8215/ff3; the annotated source
`build/ff3/src_gb`, generated from the listing and the user's ROM, never committed) says each
routine does. Only *data* comes from the user's ROM at build time. The recompiled build
(`tools/gb3`) stays available until the native one reaches parity.

## Rules
- Nothing game-specific in the repo: every byte (maps, tiles, palettes, text, stats, scripts,
  songs) is read from the user's ROM when the build runs (`tools/gb3n/data.py`).
- Game rules exactly as on the Famicom (formulas, RNG use, encounter rates, AI, events).
- Screens as already approved for the recompiled build (`docs/ff3-gb-status.md`), the owner's
  standing requests built in from the start: Select menu (Options / Suspend; B + Select changes
  the walking member), suspend points, menus shown complete with fades (no half-drawn windows,
  no white flashes), condensed names in lists, dialogue paged at sentence / speaker boundaries
  with natural line breaks, music checked against the owner's NSF (never committed).
- Lot Check designed in (`docs/gb-release-checklist.md`): Color only with the warning screen,
  LCD off only in V-Blank, VRAM / OAM in their windows, cart RAM only around save accesses,
  soft reset, memory cleared at boot.
- 0 lag frames: one engine frame per GB frame, the picture written natively.

## Verification
- Data decoders checked against the NES (cynes) RAM / CHR of the same scene
  (`/tmp` scripts in the session; the checks will move into `tools/gb3n/check.py`).
- State checks: the NES and the native build with the same inputs, FF3's game state block
  ($6000-$7FFF layout kept where the save and the checks need it) compared at checkpoints.
- Pictures: SameBoy / mGBA screenshots of every screen; lag: Gambatte lagcheck.

## Milestones
1. Boot, a normal map from the ROM's data, the party walking (passability), camera, sprites.
2. All maps loaded at run time, the world maps, triggers (exits, doors, stairs, treasure),
   NPC objects, the event script interpreter, dialogue.
3. Menus (main, items, magic, equipment, status, jobs, order, save, Select menu / suspend /
   options), shops, inns.
4. Title, prophecy, new game (names), the story scenes and cutscenes.
5. Battle (formations, the approved layout, commands, jobs, magic, summons, items, AI,
   animations, rewards, capacity, levels).
6. Vehicles (Nautilus, Invincible, chocobos, ...), music and sound effects, the ending.
7. Parity checks over the whole game, Lot Check pass, release.

## Data (FF3 formats, as decoded in data.py)
- Map properties: 16 bytes, 02/A000 + 16 id (02/B000 for the second set): byte 0 bits 5-7
  tileset, bits 0-4 start x; byte 1 bits 0-4 start y (bit 5 gil chests 16-31, bits 6-7 water
  animations); byte 2 title; byte 3 fill metatile (outside 0-31); bytes 5-9 palettes (general
  palettes 00/9100, /9200, /9300: BG 0-2, OBJ 2-3); byte 10 song; byte 14 treasure set.
- Layout: id 00/8A00 (00/8B00 from world 2), pointer 11/8000 + 2 id (page low 5 bits | $80,
  bank $11 + top 3 bits), RLE (bit 7: value, then count) into 32 x 32 metatiles.
- Tileset (8): 01/A380 + $200 ts: TL, TR, BL, BR tile ids (128 each); 01/B180 + $80 ts:
  palette per metatile; 01/B500 + $100 ts: 2 property bytes per metatile; metatiles $80-$FF =
  copies through 3A/93C1 (triggers).
- Properties byte 1: bit 7 trigger (byte 2 high nibble = trigger type, fix:E669 table), bit 6
  random battles, bits 0-2: 0 stairs, 1 / 2 floor level, 3 impassable, 4-7 bridge.
- BG tiles: subset id 00/8C00 (00/8D00 from world 2); 00/8E00 + 16 id: 8 block pointers
  (bank 3 + top 3 bits), block lengths fix:DF00; menu window / font 0D/B700 (144 tiles at $70).
- Map character: 0E/8000 + $100 job (16 tiles); its colours 00/9690 + 4 job.

## Progress
- 2026-11-22: milestone 1: `tools/gb3n/data.py` (map properties, layout, tileset, palettes,
  BG / character tiles; checked against the NES RAM and CHR of map 181: layout, metatiles,
  attributes, properties, palettes and tiles identical apart from FF3's run-time trigger ids
  and water frames), `tools/gb3n/src/main.s` (boot on a Color with double speed and cleared
  memory, the map drawn into a 16 x 16 metatile BG ring, d-pad walking one metatile in 16
  frames with FF3's passability rule, the entering line queued and written in V-Blank, the
  character sprite), `tools/gb3n/build.py` (`build/ff3n.gbc`; `--map ID --world W`).
  Next: walking animation and facing, then milestone 2 (all maps, triggers, NPCs, events).
