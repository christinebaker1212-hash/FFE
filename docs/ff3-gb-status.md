# FF3 Game Boy Color port: status

Brief: `docs/ff3-gb-brief.md`. Target: Game Boy Color only (header CGB flag `$C0`, MBC5 + battery
SRAM), a "Game Boy Color only" screen on DMG / Pocket / Super Game Boy, 0 lag frames, every Lot
Check standard. Code will go in `tools/gb3n/`, docs in `docs/ff3-gb-*.md`.

## Done (2026-11-26)
- ROM checked: `roms/Final Fantasy III (Japan).nes`, SHA-1 `c4443fc24625e3c2bb859525eb44b6b3a80e7c35`
  (matches `README.md`; `roms/` is git-ignored).
- English FF3 NES ROM built with the existing tools:
  `python3 tools/ff3_mmc5/build.py "roms/Final Fantasy III (Japan).nes" build/ff3_mmc5.nes`, then
  `python3 tools/ff3/insert.py build/ff3_mmc5.nes build/ff3_en.nes`. Result SHA-1
  `4a7f1ae4c89305cf161aa3d78fd4416548663f99` = the expected result in `patches/README.md`.
- everything8215/ff3 cloned into `build/ref/ff3` (git-ignored, never committed). What it is:
  an **annotated listing** (`ff3j.asm`: `BB/AAAA: bytes  MNEMONIC ; comment`, 1623 named
  routines), not assembler source, plus `rom-map.txt`, `field-ram.txt`, `battle-ram.txt`,
  event and text dumps. Its bytes match the Japanese ROM: 47,593 listing lines identical, 10
  differences (comment / data-word lines the check misparses). Coverage: 106 KB of code in 8 KB
  banks $10, $1F, $2E-$36, $3A-$3F.
- Facts for the owner's decisions:
  - FF3's field buttons (bank $3E $C1F6-$C2B7): **Start opens the main menu** (Item / Magic /
    Equip / Status / Order / Job / Save; Save only on the world map), **Select shows the next
    living party member as the walking sprite** ($F72C), B makes the Invincible take off, A
    talks / acts. The world map is shown only by the Sight spell and Dwarf Bread ($A525).

## Owner's decisions (2026-11-26)
1. Base: **native rewrite** (as FF1).
2. Select menu: **in the Start menu** (Config and Suspend added; FF3's Order = Formation; Select on
   the map keeps showing the next member).
3. Conveniences: **all four groups** (text / screens, battle, menus / Config / saves, extras). FF3
   already has some: judge each in battle against FF3's own, keep FF3's where better, adapt ours
   to FF3's style where equal or ours has the edge (`docs/ff3-gb-battle-compare.md`).

## Battle comparison (2026-11-26)
`docs/ff3-gb-battle-compare.md`: FF3's own numbers, flash, step-forward, auto-retarget, spell names,
deaths and speed setting stay; ours (adapted, FF3 wording) for the hit label, critical label, cursor
memory, hold-A, enemy counts, low-HP colours, results window. Checked on the NES English build
(cynes, one Altar Cave round) and in the listing; spells / healing / targeting / transition still
to be seen on screen. NES driver for tests: scratch (New Game, names typed by RAM state; FF3 needs
6 letters + A and rejects duplicate names).

## First bootable ROM (2026-11-27)
- Owner chose screen **B** for older systems (title above a framed window, white on black).
- `tools/gb3n/build.py` -> `build/ff3n.gbc` (2 MB MBC5 + battery, 32 KB cart RAM, header CGB $C0,
  SGB flag 0); `tools/gb3n/src/main.s` (boot: work RAM / high RAM / VRAM / OAM cleared, the LCD off
  only in V-Blank, double speed, frame wait with the check and halt race-free, pad with opposite
  directions cancelled, soft reset A+B+Select+Start); `tools/gb3n/tiles.py` (our font and frame
  tiles, the screens; no game data). Color / GBA: a placeholder screen (to be replaced by the
  title). DMG / Pocket / SGB: the notice, with DMG registers only.
- Checked in SameBoy (`build/sbsh`, core built with `tools/gb/sameboy/sameboy-ffe.patch`,
  `SB_LCHK=1`), 710 frames with a soft-reset press, on Game Boy Color, Game Boy, Game Boy Pocket,
  Super Game Boy, Game Boy Advance: strict checker 0, VRAM / OAM checker 0, pictures as expected
  (the SGB shows the notice in its own default palette, as for any Color-only Game Pak).
- Test harness rebuild notes (this session): SameBoy at ea667ad + the patch; RGBDS v0.9.1; the
  `hexdump` stand-in must take the file as its last argument; `sbsh` built with
  `-I<SameBoy>/libretro` when libretro-common is not installed.

## Next (after the decisions)
- Map the listing's routine names onto the ROM (as `tools/gb/ff1dis.py` did for FF1).
- One FF3 map on screen: map properties (bank 2), tileset / metatiles / attributes / tile
  properties (bank 1), the map's graphics subset, its compressed background tilemap ($7400 RAM,
  bank $11+), palettes (listing: $3A $915E init map, $9267 load map properties).
