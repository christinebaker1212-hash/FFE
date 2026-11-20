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
- Step 5 (done, 2026-11-19): end of battle. Victory messages ("Won the battle!!", Gil,
  stat gains) already go through the GB message window. **Treasure screen** (owner approved
  mock-up `ff2_mock7`, `mockup.loot_menu`): `layout.loot()` + bank-23 `gb_lootscr` /
  `gb_lootf` / `gb_lootnav`. Drawn after the fade out into nametable 0 with BG table 1
  (`b5:9FCF`), camera (1, 0): treasure window (GB 0,0,20,7: ".. Treasure ..", Drop, Done;
  8 slots in two columns), inventory window (GB 0,6,20,12: two columns, 10 of 16 rows,
  scroll `$73` 0-6). A cell is redrawn when its item id changes (`LSHOW`), so swaps / drops
  redraw only what changed; a one-row scroll re-points the nametable rows (ring of 10
  row blocks of tiles, `LRING`, widths `LWID`; 2 rows a frame, the NES vblank) and draws
  only the new row. Names wider than the 64-px cell: narrow letters
  (latin_font NARROW, glyph codes `$20+`), then letter gaps dropped from the end, then 1-px
  spaces (build-time per item, `loot_data`). Item type icons (`$6E-$75`) come from the ROM
  font (glyph table; the battle Gear window shows them too). Navigation (`b5:A1DE-A285`
  replaced): up / down through Drop-Done, treasure rows and inventory rows, left / right
  between columns; while an item waits for its slot the cursor stays in the other window
  (as on the NES). Cursor table `b5:A416`. Checked: NES variant (swap, scroll, drop) and
  firstdiff with every monster dropping items (test copy of `b5:B800`), inventory poked,
  forced formation 0, monster HP 1 / defence 0 poked after the battle start (`--pokeat
  10300`): no difference in 14227 waits (PyBoy DMG).
- Fixed with it: (1) jump-table entries (runs of 3+ JMP abs) are dynamic targets (the
  monster death `b11:961B` was reached through the fixed-bank dispatcher only); (2) PLA
  pairs that drop return addresses are found without coverage (runs of 2 / 4 PLAs leaving
  by RTS / JMP: the victory exit `b05:A021` and 7 more); (3) after a battle the field
  reloads its tiles (`fix:E512`) with the battle's `$2000` (BG table 1), so the GB sent them
  the wrong way: `fieldcam` writes the field's `$2000` (`$FD`) first (the room after the
  opening battle was garbage on the GB before; now right); (4) back from the magic list /
  Gear window the party window is drawn again before the commands (`LCOV`).
- firstdiff: `--pokeat F` (frame of the pokes), env `WRAM_EVERY`, `HOOKS=label,..`
  (print at GB labels), `SHOT_INFO`. Note: battle scripts need `--random 1` (the plain
  new-game script stays in name entry).
- Checks: GB-layout pair seed 1, 30000 frames: no difference in 29494 waits; treasure run
  with scrolling down / up, swap and drop: 14226 waits; English pair 29406 waits.
  `gbshots.py` takes the same scenario options as firstdiff (`scenario()`; pokes go to
  Gambatte at the matching wait): CGB shots of the treasure screen fine.
- Status words in the battle party window (2026-11-19): `$7BA6 + member` (text id, `$F6`
  none, as `b12:956D`): the English word (script/ff2/system.json 240-253) after the current
  HP in place of the maximum HP and MP (30 px; Paralysis / Confusion in narrow letters with
  fewer gaps). Checked with statuses poked into the battle stats (+$08/+$09): "Stone",
  "Venom", "Dead"; firstdiff 12763 waits identical. (The NES slot is the maximum HP only;
  the GB line has no room for a word there, so MP is hidden while a status shows.)
- Item use in battle (2026-11-19): FF2's Gear cursor is a 2 x 2 grid (hands / items; left /
  right switch the column); on the GB list of four lines up / down now step through all
  four (`gear_updown`: b12:9BA8's down / up handlers, only for a 2 x 2 grid, code in the
  dead parts of `b12:9147` / `b12:930C`); the slot chosen means the same as on the NES.
  Checked: Potion / Antidote poked into the item slots, Down x2 + A + A uses the Potion;
  firstdiff 12388 waits identical; random seed 1 30000 frames: 29494 waits identical.
- DMG: at a battle start the bottom rows and the enemies are mis-shaded for ~55 frames
  (the shading re-codes the battle tiles 3 per frame after the fade-in palettes; NES and
  CGB show black there): for the DMG speed work.
- Big knock-back (`b11:B11B`, x to 240 and back: off the GB view) goes to x 164 instead
  (reached in 4-px steps from both base x; at most 4 px past the edge for a few frames).
  The small shake (`b11:B131`, +4) puts the back row 4 px past the edge briefly (kept).
  Random seed 1, 30000 frames: 29534 waits identical.
- Battle-entry speed (2026-11-19): native `hle_fill` for `b11:9D68` (fill ppu: whole
  pattern-table tiles in one go, marked as `hle_ppucopy` marks them; nametable runs with
  the LCD off in bulk: map, shadow, owner bits a byte at a time, CGB palettes of the run
  if an owner changed; else the generic path). **lagcheck fixed**: it stopped its windows
  at the first wait the GB passed inside one frame, so earlier DMG totals were partial
  (the "+22 DMG battle entry" above was wrong). Now, seed 1 to wait 9800, Gambatte:
  CGB total +0.9%, battle entry (wait 9506) +110 -> +58 frames; DMG total +5.8%, battle
  entry +219 -> +93, plus +94 at wait 3356 and +90 at wait 1531 (screen loads before the
  battle). RAM identical (DMG and CGB, 10592 waits).
- Native CHR copies `fix:E50E` (pages from ($80)) and `fix:E51E` (bytes from ($80),Y),
  through `copy_core` (whole tiles from ROM in one go, else byte by byte): screen loads at
  waits 1531 / 3356: CGB +40 / +39 -> +11 / +11, DMG +94 / +90 -> +24 / +20. Totals (seed 1
  to wait 9800): CGB +0.3%, DMG +4.4%. RAM identical (DMG and CGB).
- Native multiply / multiply (16-bit) / divide (16-bit) (`fix:FC79` / `FC98` / `FCC3`):
  the same steps in registers / NES RAM (results, side effects on $00-$07, A and flags as
  the NES leaves them), in bank HLE_BANK (`rt/ff2_banked.s`) behind bank-0 stubs; the
  native-routine table takes the flags a routine reads (these read the incoming carry).
  Cross-bank stubs now start at `$2500` (bank 0 runtime grew). Multiply-16 runs FF2's
  steps in registers; divide-16 is a register restoring division with the NES's final
  state ($00 = 0, $01 = $80 if the entry carry was set, A = $07, C = 0; checked against a
  model of the 6502 routine on 200000 random cases). Battle entry: CGB +46, DMG +70
  frames; totals CGB +0.2%, DMG +4.1%; random seed 1, 30000 frames: 29534 waits identical
  on DMG and CGB.
- Native `b11:97D5` (init rng: the battle's 256-entry RNG table through 256 multiply +
  divide calls): closed form x = k * x mod 1024, folded above 512, with the NES's end state
  (zero page, A / X / Y, flags; checked against a model of the 6502 routine on 300 random
  zero pages). The 16-bit multiply's end state also has a closed form (checked on 200000
  cases: $02 = entry carry, $03 = 0, A = (product >> (bit length of the multiplier + 7)),
  C = 0), kept for later. Battle entry (wait 9506): CGB +34, DMG +46 frames (from +110 /
  +219); totals CGB +0.1%, DMG +3.9%.
- Next: the remaining battle-entry time (attribute writes `attr_apply`, tile marks, the
  battle's own setup code), DMG boot (+45 at wait 2), GB tile upload latency.
- Meanwhile: speed of screen loads (DMG +7%), the Warp idiom, more equivalence runs
  (other seeds, scripted field / shop / battle input).

## Field dialogue (in progress, owner-approved layout `ff2_mock2`, 2026-11-19)
- `layout.dialogue()`: text window 0 (`fix:E9AA` table) at NES screen (6, 6), 20 x 8 tiles
  = GB rows 0-7 with the field camera 6 / 6 (18 columns x 6 lines inside; FF2's engine
  pages from the window height); dialogue (banks 16-19) and events (bank 20) re-packed
  wrapped at 18 columns with insert.py's paragraphs / flow and insert.py's bank split
  (`gb_wrap`: 3 lines with one long name lose their indent / move a trailing "..." to its
  own line); the ending block placed after the events again (bank 14 `$BAD2/$BAD6`);
  the sprites-behind-window region of window 0 (`fix:E892`) set to the GB box (NPCs no
  longer over the text). Checked: Gambatte CGB shots of the scenes after the opening
  battle; random seed 1, 30000 frames: 29534 waits identical.
- Field messages of the system table shown in window 0 (`SYS_FIELD`: chest, nothing
  there, lock, ship / airship talk, keywords, save, warp, prayer, magic) re-wrapped at 18
  into bank 10's free space (insert.py's allocations replayed on a scratch copy give the
  free list). Item names ({02}) are counted as 18 columns: **open point for the owner**:
  three item names are longer than the 18-column box (Sulfuric Acid Bottle 20, Diamond
  Breastplate 19, icon + Sword of the Earth 19) and would run into the frame when a chest
  gives one. Random seed 1, 30000 frames: 29534 waits identical.
- **English patch bug fixed (tools/ff2/insert.py, also the NES English build):** the npc
  dialogue path (`b14:9145` -> `fix:E8CA`, the first line of a conversation with the Ask /
  Learn menu) and text-only npcs ($60-$BF, `fix:CBEE`) read the dialogue from the bank
  "check npc script" (`b14:9794`) set: 6 / 10, the Japanese tables, so those lines showed
  garbage ("??", "vern Egg") in the English build. Both now go through `dlgbank` (ExRAM
  stubs `npcdlg` / `npctxt`, as `b14:962F`). Checked on the NES English build (proper
  lines); English pair 29415 waits and GB-layout pair 29534 waits identical (seed 1).
- **Keyword menus (owner approved `ff2_mock8`, 2026-11-19)** (`layout.keyword_menus`):
  windows 1 (Ask / Learn / Items) and 2 (keyword / item list) at NES screen (6, 16) =
  GB rows 10-17 (window 1 8 x 6, one row per line: SYSONE bit for system 26; window 2
  20 x 8, 6 rows, scrolling), sprite regions moved; lists 65 / 66 from column 0 (18
  columns); the list covers window 1, so window 1's hand is hidden while a list is open
  (`b14:955B/9567` -> `kwopen`) and the list is closed (`fix:D16F`) before the menu opens
  again (`b14:91A5/91AF/91B5` -> `kwback`; code in bank 14's unused `$87C0`). Long item
  names (owner: condensed letters): Diamond Breast|plate, Sulfuric Acid |Bottle, (icon)
  Sword of the |Earth get their last word in condensed letters on font tiles $7B-$7F /
  $F0-$F6 (unused kana) so they fit 18 columns (names table bank 10; the battle / treasure
  screens keep their own copies). Checked on the NES variant and Gambatte CGB (item list
  with the three names, keyword list, back to the menu); firstdiff with keywords and items
  poked: 14563 waits identical; random seed 1, 30000 frames: 29534 waits identical.
  firstdiff tolerates stack-like values in `$04` (FF2 saves S there, `b14:919A`; the GB's
  S is exact only as a round trip).
- Window 3 (money) and the shop windows: done with the shops (see Main menu section).

## Main menu (2026-11-19, owner approved `ff2_mock9` with the portraits inside the frame)
- `layout.main_menu` + bank-23 `gb_menu` (one entry, `gbm` at `$F8F0`: A = sub-command
  0 init / 1 party window / 2 Gil amount / 3 window palette / 4 field camera; hooks in bank
  14's unused `$87D0`: `ACE3`, `AD0A`, `ADB3`, `B380`, `AD8C`, `B1D7`). Camera (1, 1). Portraits
  as background tiles (four portraits = 48 sprites, a Game Boy shows 40): copied at menu
  start from portrait data put into bank 23 at build time, into the menu's unused BG tiles
  $01-$30; each box (NES cols 2-5, rows 2+4k..) covers whole attribute quads with the
  member's portrait palette in BG palette 0-2 (`$03C0` shadow; menu windows use palette 3).
  Party window (NES 1,1,12,18): name (NES letters), HP / MP cur/max (small letters, 3-px
  digits, tiles $31-$60), status word (fix:ED04's choice, bank-10 words copied at build
  time). Commands (13,1,8,8) one per row (string 27), Gil (13,15,8,4): amount in small
  digits (tiles $61-$66), "Gil" below (string 28, one-row). `b14:8800` (sprite portraits)
  off; character select hand at the left screen edge (`b14:AEAA`). Sub-menus get the
  window palette back (`B380`, save `B1D7`) and the field camera returns on exit.
  The bank-23 renderer gained `TBLHI` (pattern table of its tiles) and `MSCR` (menu scroll
  + music update after its waits).
- Checked: NES variant and Gambatte CGB shots (portraits, text, cursors); random seed 1,
  30000 frames: 29452 waits identical.
- Portrait box = the portrait's width (owner: yes to the proposal): **GB-only palette
  override** (rt/ff2.s, registers `$5806-$580A`: a rectangle of nametable-0 cells drawn
  with one palette, finer than the NES's 16 x 16 blocks). Every per-cell palette lookup goes
  through `ovr_*`: `cell_pal`, the DMG scan (`dmg_shade.s`), `cell_fast` (native.s), the SGB
  attribute map (sgb.s), CGB `attr_apply` (post-pass `ovr_blk`); a register write redoes
  the rectangle's cells (CGB VRAM bank 1, DMG tile check / LCD-on scan, SGB rebuild). The
  menu sets column 5, rows 2-17 to the window palette; sub-menus and the exit clear it.
  Checked: Gambatte CGB and DMG shots (box 24 px, no black column); random seed 1, 30000
  frames: 29452 waits identical; mGBA SGB shot: box at the portrait's width too. Stubs from
  `$2560` (bank 0 runtime grew; they end near `$38E0`, colour tables at `$3A00`).
- Main-menu code moved to its own bank 24 (`bank24()`: MENU_SRC + the renderer core of
  B23_SRC + glyph tables + menu data; bank 23 was full). Entry `gbm` at `$F8F0` switches to
  bank 24 itself and returns to bank 14.
- **Items screen** (owner approved `ff2_mock10`): menu windows 6 (title, one row) and 7
  (list NES (1,3,20,16): 14 rows), the list string 37 from column 0 (18 letters).
- **Item / spell target** (owner approved `ff2_mock11`): description window 16 at NES
  (1,1,20,12), system strings 43-62 re-wrapped at 18, one row per line; party lines
  (`gm_tparty`, NES (1,13,20,6): name, HP cur/max (small digits, tiles $31+9k), MP cur/max
  ($36+9k) or the status word) instead of the member windows (`b14:A909/A8E5/AC60`); the
  member cursor table `b14:AEAA` now holds the target lines, the main menu's character
  select gets its own table (`mm_sel` at `b14:AD3C/AD4B/AD5A`); the list's hand hidden while
  choosing. Hooks in `b14:AEC8` (the original item menu body, dead since insert.py's).
  Checked (NES variant, Gambatte): Potion on a member (5/30 -> 30/30); firstdiff with
  items poked: 16506 waits identical; random seed 1, 30000 frames: 29452 waits identical.
- **Magic / Equip / Status** (owner approved `ff2_mock10`): top window 8 / 15 at NES
  (1,1,20,6), the portrait box (9 / 14) and the values (10) drawn inside it without frames
  (`b14:B451` instead of `B486` at `AF6B/AF75/B039/B043/B378`); titles / values strings
  32-35 and 39 at column 4 beside the box (one row per line); magic / equip portrait sprite
  centred in its black box (`b14:8838` x $14). Lists: windows 11 / 12 at NES (1,6,20,13)
  (11 rows). Equip: the replacement list (window 13, NES (1,13,20,6)) is drawn first and
  its text state saved, then covered by the slots; it opens when a slot is chosen
  (`eq_open`, the slot's hand hidden), closes on B (`eq_close`), and is redrawn after a
  change (`eq_upd`). Status: page 1 (string 80) attributes, Attack, Hit Rate, Defense,
  Evasion; page 2 (string 81) Magic Defense (19 wide: two rows) and the weapon skills in
  two columns; Left / Right switch (`st_keys` at `b14:B1CB`). Hooks in `b14:AEC8`,
  `b14:B396` (old member windows) and `b14:8801` (old main-menu portrait body).
  Checked (NES variant, Gambatte): firstdiff equip / status / magic scenarios 16706 /
  16699 / 16699 waits identical; random seed 1, 30000 frames: 29461 waits identical.
- **Save menu** (same layout as the target screen): message window 16 on top (strings
  40-42: 40 / 41 each line wrapped at 18 with the cursor spots kept, 42 flowed), party lines
  below (`gm_tparty` at the start `mm_save` and for the slot previews `b14:B226/B25E/B2C0`,
  which still called the old member windows at `B396`, now reused); back in the main menu
  the party window is drawn again (`sv_back` at `b14:AD82`), and `gm_party` blacks the gap
  between the commands and Gil windows. Checked (NES variant): save to an empty slot,
  overwrite confirmation; firstdiff save scenario (SRAM written) 16706 waits identical;
  random seed 1, 30000 frames: 29470 waits identical.
- firstdiff `--press`: key `N` (no button) to end the random input at a given frame.
- **Shops** (owner approved `ff2_mock12`, `layout.shop_layout`): the shopkeeper's text in the
  dialogue box (strings 12, 21, 23, 24 and the inn / airship texts re-wrapped at 18; 12 =
  "I'll buy it for / <price> Gil. / Is that all right? / Yes  No"; 21 = airship
  destinations at 18 columns); Buy / Sell / Pass in window 1, Gil in window 3 at NES
  (14,16,12,4) (string 82: amount on one row, "Gil" below, right-aligned); the buy / sell
  list over the dialogue box: the item name, its price right-aligned on the row below
  (`b14:90DB` `shop_list`, `b14:90FD` -> bank 24 `gm_shoptext`, sub-command 6). The close
  routine `fix:D164` restores 6 metatile rows (X = 8, $66 = 6). The sprites behind the list
  (region 4 plus the player's sprites 0-3, which FF2's regions leave out) are hidden while
  it shows; the field draws them again on closing. Checked (NES variant, Gambatte):
  buy, sell, confirmation, Gil update; firstdiff shop scenario 23190 waits identical;
  random seed 1, 30000 frames: 29470 waits identical.
- **New-game screens** (owner approved `ff2_mock13_newgame`, `layout.new_game`; camera 6 / 6
  = the boot camera, screens laid out in NES cols 6-25, rows 6-23; the load menu resets the
  camera at `b14:B656`, as a reset can come from a battle):
  - Credits (`layout.credits`): the ROM's credit lines (fix:F692) centred in 18 columns, a
    longer line split after BY; the typewriter's new line goes one row down from NES column 6
    (fix:F593/F595/F504: every typed character, spaces too, takes its own tile $01-$7F, so the
    centring cannot use leading spaces from column 2: 146 > 127 tiles).
  - Prologue (bank 24 `gm_prophecy`, sub-command 9, in place of `b14:B8DD-B8FC`): one
    paragraph a page (12 / 11 / 9 lines at 18 columns), each half attribute row faded in as
    `b14:B965` does (palette 2 colour 3 in four steps, attribute $5A / $AF), the band's lines
    drawn when its fade starts with a copy of the letter tiles in tiles $01-$50 (uploaded
    while the screen is off) and redrawn with the font once shown, so the plain Game Boy's
    one coding per tile never mixes a fading and a shown line. Pages 1-2 hold 240 frames,
    page 3 waits; A / B ends it at any point (as the NES).
  - Load menu: slot windows drawn by bank 24 `gm_slot` (sub-command 7, `b14:B7EC`): window
    NES (6, 7 + 3k, 20, 4) sharing frames, number, leader name, Speed n (8-px letters), HP /
    MP cur/max in 3-px digits (tiles $31 + 12k); New Game window 21 (6,20,20,4), one row;
    cursor spots `b14:B7CE` (hand at NES column 5).
  - Name entry: windows 22 (6,6,20,6) and 23 (6,12,20,12); name at column 12 (string 69
    `{14:05}`), portrait x/y `b14:8848/884C`, name cursor `b14:B628/B63D`; string 70 with 9
    letters a row (all 80 entries in order), cursor step 36 (`b14:B566`); the window scrolls
    as on the NES (5 of 9 rows).
  Checked: NES variant shots of all four (with save slots poked into SRAM), Gambatte CGB and
  DMG shots.
- **Fixed: world-map water** (found by loading a save; it was there before): the water
  animation `fix:C2F3` reads its tiles back through `$2007` and rotates them, and the
  runtime's `$2007` read returned 0 for the pattern tables, so the water went flat. `rt_ppu_r7`
  now reads pattern data back (BG tiles from the DMG shadow / the CGB tile copy with the LCD
  on / VRAM with it off; sprite tiles from their shadow). Bank 0 grew: stubs from `$25C0`.
  Checked: load a saved game (SRAM slots poked at frame 100; the new-game script's A presses
  load slot 1), CGB / DMG shots; firstdiff load scenario 7982 waits, random 30000 (29142
  waits) and the shop scenario (22862 waits) identical. Tools: firstdiff env `GB_SAVE=K`
  (PyBoy state at wait K to build/gb2.state).
- **World-map overview** (B + Select with the ring; owner approved `ff2_mock14`): camera 6 / 9
  around `09/BA00` (stub in bank 9's stale data `$BE20`, called from `fix:C19F`), the globe
  centred, the logo above it out of view; field camera 6 / 6 after.
- **Row menu** (Select; `ff2_mock14`): camera 6 / 5 (window NES (7,5,18,18) whole); portraits as
  background tiles (bank 24 `gm_rowinit` at `fix:F110`: the main menu's portrait tiles and
  palettes; `gm_rowdraw` at `fix:F182` in place of the sprite portraits `fix:F212`: a member
  whose x changed is moved, a row a frame, its quads re-coloured; gap column tile 0); back
  row x $A0 (`fix:F2B8/F2BC`, NES $A8); camera 6 / 6 again on leaving (`fix:F196` -> gm_exit).
  Stubs in bank 14 `$B845` (the load menu's old slot drawer). On a CGB the portraits sit in
  black boxes as in the main menu (the window interior is black here, so they do not show).
- **Fixed (CGB): sprite tiles and BG tiles not copied on busy screens.** The overview changes
  one colour a frame; the palette rebuild wrote all 32 CGB colours and two DMG palette bytes
  each time and used up the vblank, so the HDMA tile copies never ran (the overview's
  markers showed stale slot graphics, parts of the globe were missing). Now `rt_ppu_w7`
  marks the changed entries (`PAL_DM`) and `cgb_palettes` (rt/ff2_pal.s, bank 0 `$39E0`)
  writes only those (all after an emphasis change); on a CGB `make_palettes` stops after
  them (BGP / OBP have no effect). Also: sprite-slot copies are flushed before BG tiles,
  and a slot loaded with the LCD off updates the WRAM copy too (a mark still pending would
  have copied a stale slot back). Found and checked with mGBA (`sgbrun --cgb`,
  `SGBRUN_PEEK`); PyBoy has no double speed or VRAM locking and did not show it.
  Checks: random 30000 on DMG and CGB, overview / load scenario on DMG and CGB, shop
  scenario: identical.
- **Ending** (owner approved `ff2_mock15`): epilogue window (b14:BAAF) at NES (6, 9), 20
  columns (`layout.EPI`); the translation's lines balanced at 20 and padded to the width;
  two pages of 11 rows: page 1 is ending text 0 (event bank), page 2 a string of its own
  (its address in bank 24 at `$BFF0`, outside the code module so the source map still
  matches); `fix:F399` (the 4-wait hold `fix:F3B0`) -> bank 24 `gm_epage`: 2 waits, page 2,
  2 waits (its own wait loop with `fix:C74F`: `F3BC`'s `C746` leaves the music bank in
  place). Credits 3 columns left (`b14:BB2B` $224A -> $2247). Test builds: env
  `GB_END_TEST=1` (layout.py: Select on the field starts the ending, `JMP $F34D` at fix:F0E2).
  Checked: NES variant and Gambatte CGB shots of both pages, credits, THE END.
- **Fixed (DMG): credits background dark grey**, the crystal ball fading into it. The credits
  draw black with colour indices 2-3 over a blue backdrop ($12); the backdrop takes value 0
  and black value 1, whose shade came from its group's brightest level (a grey shares the
  group). With a non-black backdrop, value 1 (the darkest group) is now shaded by its
  darkest level (`dmg_shade.s` `.lum`, `LSL[0]`). Checked: DMG credits black with the ball
  visible; 12 DMG shots along the new-game / random path identical before and after.
- **Speed check (2026-11-20, lagcheck, Gambatte, random seed 1, 30000 frames):** CGB -0.9%
  (keeps pace, catch-up); DMG +10.6%, the same as before this session's runtime changes
  (measured on the commit before them, window by window), so nothing here slowed DMG. The
  earlier "+3.9%" was on a different path (the prologue / name entry changes moved the
  random path). DMG lags in long field stretches (castle, dialogue: waits 17000-19000,
  21300-22900, +20-30 frames per 60 waits) and at screen loads (+90-230 per window).
  Profile (mGBA, PC every 200 instructions, waits 17000-19000): rt_ppu_w7 11%, OAM
  conversion 6%, the OAM clear loop fix:C46E 7% (translated), delay loops 4%, DMG cell /
  attribute bookkeeping ~10% together, music engine (bank 13) a few %.
  First step: fix:C46E native (`hle_oamclr`, rt/ff2_pal.s): DMG +9.4%. Second: a nametable
  write of the tile the cell already has (nametable 0, no cell owned by nametable 1) stops
  after the shadow compare (no owner / shading / VRAM queue work; FF2's text printer
  rewrites whole rows): DMG +9.1%, CGB -0.9%. Random 30000 on DMG and CGB identical.
  (Screenshots of the dialogue scenes show the NES's own transitional states, e.g. a line
  twice while the text scrolls, a few frames late on the GB: the lag, not a drawing fault.)
- **Owner's decision (2026-11-20): keep DMG and make the presentation native** (not GBC-only):
  approach in `docs/gb-native-presentation.md` (game logic recompiled, picture / music /
  sprites native, DMG shading at build time). Profile buckets of the slow DMG stretch:
  picture 39%, glue 21%, game code 16%, OAM clear 7% (now native), music 7%, sprites 6%,
  timing loops 4%.
- **Step 1, first part (2026-11-20): tile palettes fixed by the field tileset (DMG / SGB).**
  When a normal map is (re)loaded ("init map" fix:D09A calls "load map palette" at fix:D0B4
  through a bank-0 stub at $83CA that writes the GB-only register $580B first), the runtime
  derives each tile's palette from the tileset in NES RAM ($0500-$06FF tiles, $0700 palette
  per metatile) at the next LCD-on (`tset_fix_b`, rt/ff2_banked.s): a tile drawn with one
  palette gets `TILE_PAL` bit 7 and skips the cell lookups in `dmg_cell` / `dmg_attr` / the
  scan; a new pattern (`dmg_markw`) clears the bit. `dmg_maps` moved to the HLE bank (bank 0
  was full). RAM identical (random 30000, DMG and CGB); DMG shots match.
  **No speed gain yet** (DMG +9.2%): in the slow stretches the work is the dialogue window
  (its attribute writes fix:D2FE every few frames and its text tiles fix:F069: font / frame
  tiles >= $80, not in the tileset) and the map tiles used with two palettes (30 of 101 in
  the measured map). Profile after the change: rt_ppu_w7 13%, dmg_attr 11%, own_set 7%,
  quad_chk 6%, cell_pal 4%, dmg_cell 4%.
  (Debug note: `GB_SAVE=K` needs a frame limit beyond wait K, else an old build/gb2.state is
  read.)
- **Step 1, second part (2026-11-20): native "update map background" (fix:D21B, once per
  step: D66A's 64 / 30 tiles + D2FE's 16 / 15 attribute bytes)** (`hle_mapupd`,
  rt/ff2_banked.s; translator ext): the same writes into the nametable shadow and the GB map,
  NES RAM ($80-$82, $32), registers and flags as the NES; on a DMG / SGB each tile is shaded
  with its metatile's palette from the scroll buffer ($07C0) with no cell lookups (fixed
  tiles skipped, others re-coded only on a palette change), the attribute bytes only go to
  the shadow; CGB writes through rt_ppu_w7. Before, a step cost ~64 000 DMG cycles (~800 per
  write) and a step comes every 8 frames. Result (lagcheck, random 30000): DMG +9.2% ->
  +8.1%; the walking windows measured before 17041 / 17101: +21 / +25 -> +10 / +8 frames per
  60. RAM identical (random 30000, DMG and CGB); shots of the walking scenes match the NES.
- OAM clear (fix:C46E) unrolled in the HLE bank (`hle_oamclr_b`): DMG +8.1% -> +7.8%. RAM
  identical (random 30000, DMG and CGB). Throne-room stretch profile (waits 21400-22100):
  sprite conversion (rt_io_w4014) 16%, OAM clear 7% (before unrolling), memory-read glue
  (nes_rd / rt_rd_8 / rt_izy_rd: a bank switch per ROM byte) ~16%.
- **Player centred on the field (owner, 2026-11-20):** field camera x 5 tiles (was 6): the
  player sprite (NES x 112-127, y 109-124) at GB x 72-87, centred; y stays 6 tiles (3 px
  above centre: a 45-px camera would put the 8-px window grid 5 px off the screen's).
  `layout.FIELD_CAM`; set by stubs at normal-map init (b0:$83CA, with the tileset flag) and
  world-map init (b0:9C03 -> wmcam), by gm_exit (menus) and after the world-map overview; the
  return from battle reloads the map (fieldcam only clears fine X / the split). Field
  windows one column left (dialogue, keyword, shop list: left 5; Gil 13). Windows on an odd
  column: fix:D13D / D157 count the metatiles from the window's first to its last column
  (`wattr` in the GB fixed-bank code), else their last column kept the map's palette.
  Checked: shots of dialogue, walking, throne room, world map, shop (CGB, DMG); RAM identical
  (random 30000 DMG / CGB, shop scenario, load + world map scenario).
- **Native small-font tile upload (2026-11-20):** the GB renderer's per-tile loop (banks 23 /
  24) is a subroutine `vtile` (16 bytes: plane 0 from VBUF, plane 1 $FF); the translator
  replaces it with `hle_vtile` (rt/ff2_banked.s): the tile straight into the DMG shadow with
  one re-coding mark (CGB: the tile copy + HDMA mark, or VRAM with the LCD off) instead of 16
  write-handler calls and 16 marks. layout.py records such replacements of its own routines
  in `<rom>.ext.json` (`NATIVE_EXT`), build.py adds them to the translator's table. Battle
  on DMG was ~25% tile writes. Result (lagcheck DMG, random 30000): +7.8% -> +5.5%; the
  opening battle's windows from +10..+32 to -4..+7 per 60 (parity). RAM identical (random
  30000, DMG and CGB); DMG battle shots correct.
- Owner (2026-11-20): battles, overworld and dialogue must never slow down; aim for parity.
- Font / window tiles fixed to the window palette: `tset_fix_b` gives tiles $80-$FF the field
  tileset does not use palette 3 (the field always draws its windows with attribute $FF,
  fix:E92A), so dialogue text and window attribute writes skip the cell lookups. DMG +5.5% ->
  +5.1%; dialogue windows 17041-17221: +11 / +8 / +13 -> +5 / +0 / +3. RAM identical; DMG
  dialogue shots correct.
- **Native "draw object sprite" (b03:A902, NPCs every frame)** (`hle_objspr`): its 8 table
  bytes in one banked copy (`rd8_bank`, bank 0 $3A6C) instead of 8 indirect reads with two
  bank switches each (the field's "glue" cost: ~45 of the ~54 indirect ROM reads per frame
  in the throne room). DMG +5.1% -> +4.3%; throne room +13 / +15 -> +2 / -1 / +5 / +6. RAM
  identical (DMG / CGB); NPC shots correct.
- **Overworld travel measured and native water animation (2026-11-20)**: `lagcheck.py` takes
  firstdiff's scenario options (`--press`, `--poke`, `--pokeat`, `--form`). Save slot 1 loaded
  by SRAM pokes at frame 100, then 40-frame holds R R D D L L U U on the world map: CGB kept
  pace, DMG +2..+6 per 40 waits (~10%). Profile (mGBA): a quarter of the DMG time re-coded two
  whole BG tiles every frame - the world map's water animation (fix:C2F3) reads one bit-plane
  row of two tiles back through $2007, rotates it a pixel and writes it again, and every
  pattern write marked its tile for a full re-coding. Native `hle_water` (ext fix:C2F3, HLE
  bank): the same NES state ($6D, $80, $81, X, A, N Z C V, PPU address / buffer / latch); the
  bytes through `chr_w1`, which on DMG re-codes only the written row of a coded, not-waiting
  tile whose row adds no colour index (else rt_ppu_w7). Walking DMG: -2..+2 per 40 waits
  (parity, the catch-up evens it out); RAM identical (walk scenario DMG / CGB, random 1 30000
  DMG / CGB); DMG water shots correct. Random path unchanged (+4.3%, it hardly visits the
  world map); its worst single waits are map loads (+85..+102) and the battle entry.
- **Map transitions (2026-11-20)**: `lagcheck.py --detail W0-W1` prints NES / GB frames per
  wait. Around every door the DMG took 2-3 GB frames per wait for ~70 waits: FF2's curtain
  (fix:D8C9 opening / D8EE closing, per frame D935: BG off, ($84) lines, BG on, ($85) lines,
  BG off, each line a delay call fix:D962) ran its delay loops in NES time. Idiom fix:D93B ->
  `rt_band` (FF2 version: the band as the GB raster mask, NES rows $84 - 10 to $84 + $85 - 11
  measured on the NES picture; $82 counted as the delay calls do, X = Y = 0, A = $10, carry
  kept): 1 GB frame per wait. The load itself: idiom fix:E69E (LDA ($80),Y / STA $2007 / INY /
  BNE, the map graphics pages) -> `hle_chrpg`, through the tile copier of `hle_ppucopy`
  (now `cp_core`, pointer address as a parameter). Door load DMG 100 -> 57 GB frames, CGB
  58 -> 37 (NES 10). Random 1, 30000: DMG +4.3% -> +2.4%, CGB -0.8% -> -1.6%; RAM identical.
- Next (step 1, third part): the remaining field costs (dialogue window: text printer
  fix:F069 and its window drawing; the throne-room stretch 21300-22900 still +16-23);
  then screen loads, music, sprites. Earlier plan text:
  native field drawing that knows each metatile's palette
  (fix:D5BA builds the row / column buffer $0780-$07CF with the metatile attributes at
  $07C0): draw the buffer natively into the GB map with tiles pre-shaded per palette (a
  second GB tile for the tiles used with two palettes, in free BG slots), and the dialogue
  window's tiles fixed to the window palette, so neither path needs per-write cell lookups;
  then the text printer. Select menu with suspend (design with the owner).

## Remaining (brief's milestones)
1. ~~Setup~~ (done, see above).
2. ~~English patch → source mapping~~ (plan §2, approved).
3. ~~6502 → SM83 path~~ (plan §3, approved).
4. Boot to title (PyBoy, Gambatte), new game, field, battle; equivalence vs NES;
   re-layouts with mock-ups; colour (CGB, DMG shading, SGB); Select menu + suspend
   points; builder.
