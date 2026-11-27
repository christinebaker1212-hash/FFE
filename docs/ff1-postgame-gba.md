# Final Fantasy I・II Advance (Japan, Rev 1): what the post-game reads

The FF1 Game Boy post-game (`docs/ff1-postgame-design.md`) takes its dungeons, monsters, items and
text from the user's own Dawn of Souls cartridge at build time (owner, 2026-11-27): `roms/Final
Fantasy I, II Advance (Japan) (Rev 1).gba`, SHA-1 `3d1c580b9b3007f6f910d80f4c7421f5d2e19dbe`. Nothing
from it is committed. The reader is `tools/gbn/gba.py`. Offsets below are file offsets (ROM address
minus $08000000) in that revision; everything was found by searching for values known from FF1.

## Compression and text
- Graphics, maps and tilemaps: the GBA BIOS LZ77 format (type $10). Most unpacked blocks start with an
  8-byte header: u32 kind (1 tiles, 2 tilemap, 3 palette, 0/1 map), u32 count or size.
- Text: Shift-JIS, null-terminated, each string padded to a 4-byte boundary.

## Monsters
- Stats: 32-byte records from $1D5324, one per monster id: 0-127 are FF1's in NES order, 128-144 the
  17 bonus bosses (Echidna, Cerberus, Ahriman, Two-Headed Dragon, Scarmiglione x2, Cagnazzo,
  Barbariccia, Rubicante, Gilgamesh, Omega, Shinryu, Atomos, Typhon, Orthros, Phantom Train, Death Gaze),
  145-194 the 50 new monsters. Bytes 0-12 are the NES record's 0-12 (EXP u16, Gil u16, HP u16, morale,
  AI, evasion, defense, hits, accuracy, attack); 13 agility, 14 intelligence, 15 critical, 16 the NES
  record's byte 14, 18 attack ailment, 19 category, 20 magic defense, 22 weakness, 24 resistance (21 / 23
  the high bytes: the remake's extra elements), 25-28 new fields (not yet decoded).
- Names: 190 Shift-JIS strings from $1D44E0 (deduplicated: Lich's two forms share one name); the bonus
  monsters' names from index 124.

## Maps
- Map table $215EE0: 212 records of 32 bytes: +0 pointer to a list of 4-byte points (x, y, ?, ?), +4 its
  count, +8 the packed map, +12 tileset, +16 area kind (1 dungeon, 2 town, 0 overworld), +20 name.
  Record 0 is the world map, 1-119 FF1's maps, 120-211 the 92 Soul of Chaos floors (name ソウル・オブ・カオス).
- Packed map: 8-byte header (u16 kind, 0, width, height), then width x height u16 cells: the cell's
  low 10 bits are a 16 x 16 tile ("chip") of the map's tileset.
- Field tilesets $2148B4: 36-byte records (index = a map's tileset): +0 tile sheet (LZ77: 8-byte header,
  u8 64, u8 64, then 64 x 64 GBA tilemap entries; chip c is the 2 x 2 entries at (2 (c % 16), 2 (c / 16))),
  +4 the 4bpp tiles (LZ77), +8 / +12 two palettes (raw: u32 3, u32 count, RGB555), +16 per-chip
  properties (u16: bits 12-15 blocked, bit 8 inside a room, low byte the terrain: 3 floor with
  encounters, 0 none), +20 animations.
- Dawn of Souls keeps FF1's dungeon layouts (Earth Cave B1 is FF1's, unwrapped and with margins) but
  draws walls as faces above the floor; floors are converted to FF1 tiles by rule (walkable -> floor,
  blocked next to floor -> FF1's one-tile walls, rooms and doors as FF1's), not by a learned table.

## Battle graphics
- Asset pointer table $2192A8 (975 entries): 0-116 battle backgrounds (tiles, palette, tilemap),
  117-500 FF1's 128 monster pictures (tiles, 16-colour palette, arrangement), 501-551 the 17 bonus
  bosses, 552-701 the 50 new monsters, 702-974 other sprites.

## AI and messages
- Enemy AI: 16-byte records from $2253DC (FF1's format): 0-43 FF1's (some re-balanced), 44 "none", 45-68 new.
  The bonus bosses' records hold $FF there (their scripts are elsewhere).
- Monster pictures: asset triples (tiles, 16-colour palette, arrangement: u32 kind 2, u32 size, w, h, pad,
  u16 entries); a recoloured family shares its tile data pointer with FF1's monster.
- Dialogue: 1,280 Shift-JIS strings from the pointer table at $1F4A98; 640-647 the four shrines' doors (before /
  after their Fiend), 648-651 Earthgift's bosses (Echidna, Cerberus, Ahriman, the Two-Headed Dragon).

## Not decoded yet
Event scripts (warps, NPCs, triggers, chests' places and contents), the dungeons' floor sets and order (taken
from the wiki), encounter tables (from the wiki), items / weapons / armour tables (effects from the wiki).
