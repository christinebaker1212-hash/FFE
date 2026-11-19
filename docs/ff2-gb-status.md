# FF2 Game Boy adaptation: status

Brief: `docs/ff2-gb-brief.md`. Plan for the owner: `docs/ff2-gb-plan.md`.
Branch: `claude/zealous-hypatia-3sn3fr` (started from the FF1 GB branch
`claude/tender-meitner-j5gu01`, fast-forward; FF1 files untouched).

## Session setup (cloud container: nothing persists outside git)
```bash
mkdir -p roms   # the owner's ROMs (never commit); check SHA-1s against README.md
bash tools/emu/build_emu.sh build/emu                          # cynes (NES reference)
git clone --depth 1 https://github.com/everything8215/ff2 build/src/ff2   # listing (never commit)
python3 tools/split/build_mmc5.py "roms/Final Fantasy I, II (Japan).nes" build
python3 tools/ff2/insert.py build/ff2_mmc5.nes build/ff2_en.nes             # sha1 0e76a60d...
python3 tools/gb2/ff2src.py "roms/Final Fantasy I, II (Japan).nes" build/ff2/src_ja
python3 tools/gb2/ff2src.py "roms/Final Fantasy I, II (Japan).nes" build/ff2/src_en --english
```

## Done
- 2026-11-19: ROMs checked (both SHA-1s match README). English FF2 NES build with the
  existing tools reproduces the patch result SHA-1 `0e76a60d…`.
- everything8215/ff2 fetched (commit `8d26190`, 2022-12-05). It is **an annotated listing,
  not an assemblable source**: `ff2j.asm` (33.9k lines, `BB/AAAA: bytes MNEMONIC ; comment`)
  of the standalone FF2 (J) ROM, covering the code (~61.5 KB) and a few tables, plus
  `rom-map.txt`, `ram-map.txt`, event/NPC notes. Graphics, maps, text and music are only
  described in the ROM map.
- Listing vs the owner's ROM (FF2 = second half of FF I・II): every listed byte matches
  except the compilation's own boot glue (reset `$FE48-$FE78` enters through the cart menu
  stub at `$FF00`; title string at `$FFE0`) and 4 stale code fragments the listing marks
  with `--` (missing leading byte).
- `tools/gb2/ff2src.py`: listing + ROM → assemblable 6502 source in `build/` (one file per
  bank, labels for every branch/jump/call target, the listing's titles and comments,
  data from the ROM). **Japanese FF2: all 16 banks reassemble byte-identical**
  (`tools/asm6502.py`). `--english` builds the English MMC5 ROM in a temp dir (build_mmc5 +
  insert.py), records insert.py's code modules (`tools/gb2/ff2en.py`: org, labels,
  instruction starts) and re-decodes the 169 listing instructions the patch/split changed;
  **English FF2 (sha1 `0e76a60d…`): banks 00-0F + ExRAM code reassemble byte-identical.**
- NES coverage driver `tools/gb2/covrun.py` and `tools/gb2/covcheck.py` (executed
  instruction starts vs the source code map).

- Coverage check (cynes, `covrun.py` seeds 1-4 × 60k frames from power-on, random input,
  no crash): 14,464 executed instruction starts, all in the source code map except RAM
  `$0100` (the NMI jump stub).
- Plan for the owner: `docs/ff2-gb-plan.md`.

## Owner's decisions (2026-11-19)
- **Select menu:** Select on the field opens the new menu (OPTIONS / FORMATION / SUSPEND);
  FORMATION is the row screen Select opens on the Famicom; B+Select keeps the minimap.
- **Approach approved** as in `docs/ff2-gb-plan.md` §3: mechanical translation of the
  generated source, native GB routines for graphics / sound / hot paths, re-layouts on
  the NES side (equivalence stays checkable).

- **First GB build boots (2026-11-19).** `tools/gb2/build.py` (NES ROM → English NES →
  source base → translate → assemble → `build/ff2_en.gb`, 1 MB MBC5, dual-mode header):
  29.8k instructions in 8 code banks, runtime copied from FF1 into `tools/gb2/rt/` (FF2
  frame waits / far-jump idiom / TSX-TXS in `rt/ff2.s`, hashed dynamic-target table in
  bank 61, compact bank-0 stubs). Checked in PyBoy (DMG mode, centre-camera view, no
  re-layout yet): splash screen → prologue → (Start) save menu → New Game → name entry,
  matching the NES build's screens at the same input (cynes shots).
  - `tools/gb2/translate.py` (copy of FF1's recompiler adapted): code map from the source
    base, FF2 game facts (waits `$FA2A`/`$FEAD` native, NMI return stubs skipped, `$FA91`
    jump-(long) idiom), dynamic targets from data words / immediate pointer pairs that
    start a routine (487 entries).
  - Gotchas: PyBoy runs its own boot ROM for ~70 frames before `$0100` (hooks fire after
    that); runtime files without a `section` continue the previous file's section.

- Gambatte (`build/gbrun`, CGB and `--dmg`, pad file fed at the joypad read): same screens
  as PyBoy up to name entry; CGB shows the NES colours. Raw speed over 4000 NES frames
  (splash, prologue, menus): CGB 4120 GB frames, DMG 4350 (the extra is in screen loads;
  per-window lag not measured yet).
- **RAM equivalence** `tools/gb2/firstdiff.py NES GB [FRAMES] [--random SEED]`: FF2's NMI
  fires every frame, so only *wait NMIs* (taken while `$0100` holds a wait's `JMP` stub)
  are compared with the GB entering frame wait w. One cynes step can take two NMIs, so NES
  RAM is rebuilt from the write log (`watch`) and taken at the stub's `RTI` write; the pad
  is what the game read (8th `ROL $20` at `fix:DBBC`). Work RAM `$6000-$7FFF` every 50
  waits. Result: **identical for 4992 waits** (power-on to name entry, new-game script);
  random play (seed 1) found a translation bug at wait ~9550 (zero-page indexed addressing
  must wrap: `LDA $FF,X`; fixed with `res 0, h`), then stopped at the first battle.
- Battle support: sprite-0 polling loops (`fix:FD46`, `fix:FD5B`, `b11:A073`) are idioms
  without waiting (V as the loops leave it); the battle NMI handlers (`b12:9A79`,
  `b05:A9A2`, installed in `$0100` during monster actions / actions) are requested by the
  vblank ISR and run at the next safe point (ROM data reads, cross-bank returns, the three
  `$AC` handshake loops = idiom `rt_ac_wait`), context saved, `RTI` = `ret`.

- Random play seed 1, 30000 NES frames (name entry, the scripted opening battle against the
  Black Knights incl. its asynchronous NMI phases, the castle, field, main menu, equipment):
  **no RAM / work-RAM difference in 29406 frame waits** (PyBoy DMG; sound-driver RAM
  masked: `$B0-$EF`, `$6F00-$6F24`, saved song state `$6F26-$6F5D`; `--strict` compares it).
  Found and fixed on the way: zero-page index wrap, the farcall return clobbering flags
  around the NMI poll, the harness missing the second joypad routine (`fix:FC3E`).
- Speed, Gambatte, new-game script 5000 frames (`tools/gb2/lagcheck.py`): CGB +1.9% (steady
  screens exact; lag in two screen loads: +46, +36 frames), DMG +7.1% (screen loads, and
  +3 frames at several prologue waits).
- Mock-up tool `tools/gb2/mockup.py` (FF1's renderer + real graphics cropped from an NES
  frame of the user's build, output in build/ only). Drafts sent to the owner
  (2026-11-19), **waiting for review**: `ff2_mock1_battle.png` (FF1's approved battle
  pattern: enemies GB x 0-127 rows 0-11, party column x 128-159, names / commands window
  cols 0-7 + party window cols 8-19 with name, HP cur/max, MP; full-width style-A
  messages), `ff2_mock2_dialogue.png` (box GB rows 0-7, 18 columns x 6 lines per page),
  `ff2_mock3_menu.png` (party one line per member with HP / MP, commands, Gil).
- `tools/gb2/gbshots.py`: Gambatte screens at given waits next to the NES frames.

## Known open items
- DMG shading: the castle floor (dark `$0x` colours) turns black on DMG (FF1's rule: the
  darkest group of only `$0x` colours is black); correct on CGB. For the colour phase.
- `b14:ABEA` (Warp: drops the menu frames + one 5-byte frame per map level by arithmetic
  on S): needs a semantic GB version (GB stack pointer per map level); TSX/TXS elsewhere
  are approximated (`rt_tsx`/`rt_txs`, exact round trip).
- Battle screen split (battlefield / menu pattern tables, sprite 0) not shown correctly
  yet: part of the battle re-layout.

## Next
- Owner's review of the mock-ups, then the re-layouts (NES side, `tools/gb2/layout.py`).
- Meanwhile: speed of screen loads (DMG +7%), the Warp idiom, more equivalence runs
  (other seeds, scripted field / shop / battle input).

## Remaining (brief's milestones)
1. ~~Setup~~ (done, see above).
2. ~~English patch → source mapping~~ (plan §2, approved).
3. ~~6502 → SM83 path~~ (plan §3, approved).
4. Boot to title (PyBoy, Gambatte), new game, field, battle; equivalence vs NES;
   re-layouts with mock-ups; colour (CGB, DMG shading, SGB); Select menu + suspend
   points; builder.
