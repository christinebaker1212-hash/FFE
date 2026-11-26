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

## Next (after the decisions)
- Map the listing's routine names onto the ROM (as `tools/gb/ff1dis.py` did for FF1).
- Copy the build skeleton, generic modules and test tools into `tools/gb3n/`; boot screen, font,
  the "Game Boy Color only" screen, one map on screen; strict SameBoy checker at 0.
