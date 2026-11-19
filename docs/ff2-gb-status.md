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

- Owner's decisions on the mock-ups (2026-11-19): battle, dialogue, main menu approved with
  changes; details in `docs/ff2-gb-screens.md` (all 4 members and every formation on screen:
  enemy area NES x 20-159, party column x 140-159, back row 4 px; main menu with portraits).
  Formation survey tool `tools/gb2/ff2form.py`.

## Battle re-layout (in progress, owner: "go ahead", 2026-11-19)
- Pipeline: `tools/gb2/layout.py` (NES side, after insert.py) -> `build/ff2_gb.nes`;
  `ff2src.py --gb` / `ff2en.record(gb_out=)` record its modules; `build.py --gb` ->
  `build/ff2_gb.gb`. Checked: firstdiff on the GB-layout pair, random seed 1, 11000
  frames: no difference in 10475 waits (through the opening battle).
- Runtime: FF2 camera registers `$5802` (fine X), `$5803` (split line), `$5804/$5805`
  (second camera, tiles); raster event kind 3 sets SCX/SCY at the split; sprites below the
  split take the second camera's offsets (`spr_cam2`).
- Done in layout.py: battle cameras (battlefield NES x 20 / y 48 above line 96, windows
  below), field camera back on return (`fix:FA0F`), party y = slot * 24 + 48 (`b11:9B68`),
  base x 156 / 160 (`b11:A102`).
- Facts: the battle menu scrolls horizontally over two nametables ($38, $3A bit 0) to slide
  between the names+stats pane and the stats+commands pane (windows: names (0,19)-(9,30),
  stats (10,19)-(31,30), commands (32,19)-(39,30), `b12:9126/9143/9183`); FF2 switches the
  BG pattern table at the split (battlefield table 1, menu table 0): a DMG cannot hold both
  plus sprites, so the GB windows will draw with free table-1 tiles (small-font renderer,
  as FF1). Tile survey `tools/gb2/ff2tiles.py` (cynes PPU_LOG per forced formation).
- Step 2 (done): bank-23 window system in layout.py: per-battle tile pool (free table-1
  tiles from the monster slots `$7B62/$7B72/$7B82/$7B8A` + first tiles `b11:9FA5`, bosses
  from a build-time bitmap of their tilemaps), frame tiles from the ROM font (`$F7-$FE`),
  blank fill of NES rows 18-23, small-font renderer (latin_font condensed letters, 3-px
  digits at codes $10-$1A), CHR upload after the game's waits (6 tiles per frame, then the
  battle scroll), entries through the fixed-bank dispatcher `gbf` (`$F800`, index + return
  bank, `$FA7F`). Party window (replaces `b12:912A`): name, HP cur/max (battle stats +$0A /
  +$0E), MP (+$0C), redrawn on HP changes. Old NES window / message-box nametable output
  off (`b12:930C` RTS, bank-5 box STA $2007 -> BIT, `b12:9B3E` menu clear), menu area on
  table 1 and nametable 0 (`fix:FD63`, `b12:904A`), no menu scroll (`b12:9AC6`).
- Source base / translator know the layout banks 23-30; `$FA7F` bank switches resolve
  statically. Runtime: CHR writes go to BG or sprites by `$2000` bit 4 (battle: BG table 1).
- Checked: NES variant (cynes shots) and GB (Gambatte CGB / DMG shots) through the opening
  battle: enemies, party sprites, party window correct; firstdiff on the GB-layout pair
  (seed 1, 11000 frames): no difference in 10520 waits.
- Step 3 (done): enemy names window (`b12:910D`; long names wrap at a space, one-word
  names or >4 lines squeezed without letter gaps; names from the English bank-21 table),
  command window over it (`b12:982C`; names back at `b12:981D`; cursor table `b12:BFC5`:
  hand at the screen edge), message window (bank 5 `AA57`/`AB4F`; style A from the English
  buffer BUF per box: attacker > target, action / result indented, messages on the next
  line; names + party redrawn when the last box closes). Checked on the NES variant
  (formations 0, 46, 55, 90, 126 forced) and on GB (Gambatte CGB); firstdiff GB-layout pair
  seed 1, 11000 frames: no difference in 10627 waits.
- Source base: a patched JMP that cuts into the next listed instruction ends the re-decode
  (the rest is dead code); build.py regenerates the source map when its tools changed.
- Step 4 (done): battle magic list (owner-approved; `b12:9DE3` open, `b12:9EF5` display part
  `9F3E-9F59` -> page turn + MP line, cursor table `b12:BFD5`; names only, as the NES list)
  and Gear window (`b12:A058`, cursor table `b12:BFCD`). Entries are 5 bytes (index; return
  bank from a table in bank 23), at `$FFD0` and `$FEEC`. firstdiff: `--form F` (forced
  formation, data patch in both ROMs), `--press`, `--poke`; forced formation 0 with spells
  poked, magic list opened and paged: no difference in 10227 waits (PyBoy DMG).
- Message close blanks the bottom window before the names / party come back (no stale
  message tiles). firstdiff GB-layout pair seed 1, 11000 frames: no difference in 10592 waits.
- Speed of the GB-layout battle (lagcheck, Gambatte, seed 1 to the end of the opening
  battle): CGB keeps pace in battle (the async NMI phases even take fewer frames than the
  NES), battle entry +149 frames; **DMG battle entry +349 frames** (the battle graphics
  through the DMG shading path): to fix (speed pass).
- Speed work: translator no longer computes V for ADC/SBC (FF2's BVC/BVS all follow a BIT,
  no V test after a PLP: V not assumed live at unknown successors nor by PHP); native
  `fix:FD6F` copy-to-PPU (`hle_ppucopy`, rt/ff2.s; whole tiles into the shadows / CGB tile
  copy); stubs from `$2400`. DMG battle entry +328 -> +22 frames; DMG total over the seed-1
  run to the end of the opening battle +6.3% (boot +45, menu load +26, prologue small
  ones). Checks: GB-layout pair 10592 waits and English pair 29406 waits RAM-identical.
- CGB pacing (same run): -0.8% overall, steady screens exact; battle entry +110 frames
  (profile, mGBA CGB, waits 9505-9512: nametable writes `rt_ppu_w7` / `own_set` /
  `ppu_inc` / `attr_apply` from b11 "fill ppu" `9D58-9D6C` and the battlefield tilemap
  setup, FF2's multiply / divide `fix:FC79-FD00`): native versions next.
- Next: victory / loot windows (bank 5; a forced formation 0 did not end: monster HP poke at
  battle stats +$0A had no effect, to look into), status words in the party window ("Dead"
  etc.), clear the bottom rows at battle start, hit knock-back past the right edge, item use
  in battle (Gear -> item), DMG battle-entry speed, GB tile upload latency.
- Meanwhile: speed of screen loads (DMG +7%), the Warp idiom, more equivalence runs
  (other seeds, scripted field / shop / battle input).

## Remaining (brief's milestones)
1. ~~Setup~~ (done, see above).
2. ~~English patch → source mapping~~ (plan §2, approved).
3. ~~6502 → SM83 path~~ (plan §3, approved).
4. Boot to title (PyBoy, Gambatte), new game, field, battle; equivalence vs NES;
   re-layouts with mock-ups; colour (CGB, DMG shading, SGB); Select menu + suspend
   points; builder.
