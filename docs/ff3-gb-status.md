# FF3 Game Boy Color adaptation: status

Target (owner, binding; `CLAUDE.md`): **Game Boy Color only** (header CGB flag `$C0`),
MBC5 + battery SRAM, 0% slowdown, base = the everything8215/ff3 disassembly (fetched at
build time, never committed), the English patch ported onto it, SaGa-style 160×144 layouts.
Branch: `claude/vibrant-davinci-lc8boi` (fast-forwarded from the FF1 GB branch
`claude/compassionate-bell-bo3yq2` at `225f022`; FF1 files untouched). FF3 code lives in
`tools/gb3/`. Method follows the FF2 session (`tools/gb2/`, branch
`claude/zealous-hypatia-3sn3fr`).

## Session setup (cloud container: nothing persists outside git)
```bash
mkdir -p roms   # "Final Fantasy III (Japan).nes" (never commit); sha1 c4443fc2... (README.md)
git clone --depth 1 https://github.com/everything8215/ff3 build/src/ff3   # listing (never commit)
python3 tools/ff3_mmc5/build.py "roms/Final Fantasy III (Japan).nes" build/ff3_mmc5.nes
python3 tools/ff3/insert.py build/ff3_mmc5.nes build/ff3_en.nes            # sha1 4a7f1ae4...
python3 tools/gb3/ff3src.py "roms/Final Fantasy III (Japan).nes" build/ff3/src_ja
python3 tools/gb3/ff3src.py "roms/Final Fantasy III (Japan).nes" build/ff3/src_en --english
```

## Done
- 2026-11-19: ROM checked (SHA-1 matches README). The English FF3 NES build with the
  existing tools reproduces the patch result SHA-1 `4a7f1ae4…` (MMC5, 1 MB).
- everything8215/ff3 fetched (commit `1acef81`, 2022-05-28). Like FF2's, it is **an
  annotated listing, not an assemblable source**: `ff3j.asm` (56k lines,
  `BB/AAAA: bytes MNEMONIC ; comment`, BB = 8 KB bank) covering the code in banks `$10`
  (part: final boss animation), `$1F`, `$2E`-`$36`, `$3A`-`$3F` and some tables, plus
  `rom-map.txt`, `field-ram.txt`, `battle-ram.txt`, event/text dumps. (`ff3u-text.txt` is
  another translation's text: not used, README rule.) Two typos in data-line addresses
  (`1F/5ADF`, `4C/955F`) do not matter (data comes from the ROM).
- `tools/gb3/ff3src.py` (+ `tools/gb3/ff3en.py`, which records `insert.py`'s asm modules):
  listing + ROM → assemblable 6502 source in `build/` (one file per 8 KB bank with code,
  labels for every branch / jump / call target, the listing's titles and comments, data
  from the ROM; static flow for code the listing lacks; jump targets realign re-decoded
  patch code).
  - **Japanese FF3: all 17 code banks reassemble byte-identical** (94.6 KB code,
    `tools/asm6502.py`).
  - **English FF3 (sha1 `4a7f1ae4…`): 21 banks + ExRAM reassemble byte-identical** (96.5 KB
    code): the listing's `$3E/$3F` are banks 126/127; 193 listed instructions changed by
    the MMC5 conversion / English patch re-decoded; insert.py's 8 modules (ExRAM text
    engine, banks 52/53/64/86/87/88/126) as code; the MMC5 converter's ExRAM helpers
    (`irq_entry`, `enable`, `fx2f`, `mir_h/v`) and the rebuilt reset by static flow.
  - Facts: bank pairs `$2E/$2F`, `$30/$31`, `$32/$33`, `$34/$35` are mapped together
    (4 instructions straddle `$9FFF/$A000`; kept as data in the per-bank files, the
    translator must treat each pair as one 16 KB space). 673 jumps / calls go into the
    other bank window (bank known only at run time: resolved by the bank-switch analysis
    in the translator).

- Coverage check (`tools/gb3/build_emu.sh` → `build/emu3`: cynes with the shared patch
  plus an FF3 coverage index by 8 KB bank, MMC5 PRG mode 3, `$E000` = bank 127;
  `tools/gb3/covrun.py` seeds 1-4 × 60k frames from power-on, random input, no crash;
  `tools/gb3/covcheck.py`): **21,367 executed instruction starts, all in the source map**
  except the two known bank-straddling instructions (`30/9FFE`, `32/9FFF`, pairs above)
  and code run from RAM: the NMI / IRQ jump stubs `$0100` / `$0103` (replaced by the
  runtime) and the sine helper copied from `2E/9F6C` to PRG-RAM `$7EE3-$7EF4` (the
  listing documents it, as it does the final boss code copied to `$7EF5`).
  ```bash
  bash tools/gb3/build_emu.sh build/emu3
  mkdir -p build/ff3/cov && cd build/ff3/cov
  COV_LOG=c1.bin PYTHONPATH=../../emu3 python3 ../../../tools/gb3/covrun.py ../../ff3_en.nes 1 60000
  python3 ../../../tools/gb3/covcheck.py ../src_en c1.bin
  ```
- Engine facts for the plan: 8×8 sprites (`$2000` values `$80/$88/$98/$00/$04`); no DPCM
  samples (only `$4011` level writes); Select on the field only changes the walking party
  member (`$F72C`); the minimap comes from Sight / Dwarven Bread; the main menu's Order
  (ならびかえ) is the formation screen.
- Plan: `docs/ff3-gb-plan.md`, **approved by the owner (2026-11-19)**.

## Owner's decisions (2026-11-19)
- **Select menu:** Select on the field opens OPTIONS / SUSPEND (no FORMATION: the main
  menu has Order). **B + Select** changes the walking party member (Famicom: Select).
- **Approach:** as in the plan (§3): mechanical translation of the generated source,
  native routines for graphics, raster splits, sound and hot paths, re-layouts on the NES
  side.

## Step 1-2 of the plan (2026-11-19): first GBC build, equivalence
- **Translator** `tools/gb3/translate.py` (copied from FF2's, adapted): code map
  `tools/gb3/ff3code.py` (spaces: bank pairs `p2e p30 p32 p34 p3a p3c` as 16 KB, single
  banks `b10 b1f b36 b40 b56 b57 b58`, `fix` = banks 126/127, `ex` = ExRAM, `ram` = the
  sine helper copied to `$7EE3`); calls into the other bank window resolved from the game's
  bank switches before them (`$FF03/$FF06/$FF09/$FB87/$FB89`, `$C98A/$EB28/$F727/$EB23`,
  `STA $5114/$5115`) plus a few hints: **all resolved** but an unused `JMP $0000`. Flag facts
  checked for FF3 (V only from BIT; C only after PLP). 46,310 instructions -> 11 code banks
  (~148 KB SM83), 531 dynamic targets, 508 bank-0 stubs.
- **Runtime** `tools/gb3/rt/runtime.s` (CGB only, ~1.4k lines; CPU helpers from FF2):
  double speed; NES pattern table 0/1 = VRAM bank 0/1 `$8000` (unsigned addressing, bank bit
  per map cell / sprite: no tile cache); nametables -> map `$9800` (horizontal mirroring:
  second nametable from row 30, mod 32); attributes -> VRAM bank 1 (only changed quadrants,
  two cells per access window; whole map re-banked by DMA when `$2000` switches the BG
  table); NES palettes -> CGB palettes 0-3 / 0-3 (NES_RGB), black while NES rendering is
  off (the LCD stays on); OAM conversion with the camera (48, 48 for now); joypad (+ test
  mode); MMC5 `$5114/$5115` (8 KB banks: GB bank DATA + n/2, odd banks at `$6000`),
  `$5105`, `$5203/$5204`; frame waits: `$FF36` native, `$FB80` / `$FB79` idioms,
  `$F809` delay loop removed; **asynchronous NMI / IRQ** (battle, cutscenes: `$0100 = JMP
  $FB57`, `$0103 = JMP $5C03`): the vblank counts NMIs due, the handler runs at the next
  safe point (ROM data reads, joypad reads, cross-bank returns, the wait idioms), the IRQ it
  armed at the following one (its `$2000/$2005` writes are recorded as the split's values,
  not applied yet). GB stack at `$CD00-$CFFF` (FF3 keeps data in `$0110-$0161`).
- **Build** `tools/gb3/build.py` -> `build/ff3_en.gbc` (2 MB MBC5, 32 KB RAM, CGB flag $C0;
  NES 8 KB banks copied in pairs from the user's ROM; code banks from 66; dynamic table in
  bank 127). ~4 s.
- **Checks** (tools): `run_gb.py` (PyBoy), `cmpshots.py` (NES next to Gambatte at the same
  frames, input scripts `none` / `newgame`), `firstdiff.py` (RAM equivalence, PyBoy hooks),
  `profsum.py` (mGBA `SGBRUN_PROF2` samples by routine), `build_emu.sh` (cynes for FF3:
  8 KB coverage index; `nmi_count` / `pad_history` count FF3's frames, `ff3_waits` /
  `nmi_ram` the frames the game waits for).
- **Results:**
  - Screens (Gambatte vs NES, inside the camera): opening narration, the second page,
    New Game menu, name entry, the first field scene with its dialogue: as the NES.
  - RAM (`firstdiff.py ... --input newgame --ignore 00C9-00CA,00D0-00DF,0014-0014`: the
    sound driver's bytes and the joypad repeat counter, which depend on how often the IRQ /
    the poll loop runs): **identical through waited-for frame 4,661** (power-on, narration,
    menu, name entry, the opening field scene and dialogue, the whole opening battle and
    the scene after it). The battle rng table matches too (`--sram 7BE3-7CE2`).
- Facts: the battle input loop polls the joypad ~130 times a frame (the repeat counter
  `$14` steps per poll, so it depends on CPU speed even on the NES); a cynes step can hold
  two NMIs; `$05` is also used as scratch outside the wait.

## Speed pass (2026-11-19)
Measured in mGBA (CGB double speed) with the `newgame` input: real frames between waited-for
frames (GB `VBL_CNT`, NES emulator frames): `tools/gb3/lagcheck.py NES GB FROM TO [--step
N]` (per-waited-frame lead and total); mGBA cycle profiles (`SGBRUN_PROF2=300
SGBRUN_PROFC=1`, `profnes.py` groups samples by NES routine; ~470 samples = one frame of CPU).
- **Result (2026-11-20): every measured battle keeps pace.** Opening battle (`newgame` script)
  and ten battles in the cave (`explore` script: walk, A in battle; RAM identical to the NES
  through waited-for frame 29,626): the GB is level with or ahead of the NES at every point
  of each battle's gradual course, and ends each battle 14-96 frames ahead (the NES has lag
  frames the GB does not). Whole run (waited 2400-35841): GB 33,646 frames, NES 34,250
  (-1.8%). First-round drift of the opening battle fixed (it came from single frames needing
  just over one frame of CPU: HP window redraw, attack-order sort, status sprites).
- Open: a few single steps where the GB takes 17-25 frames more (the map load after the
  opening battle: GB ~23 frames vs NES 9; the start of battle 2; one step in battle 3; one
  field step); the map loader (tilemap decompression through `(zp),Y` from ROM, map
  properties, background updates) is the next target. Bank 0 has ~800 bytes left.
- Measuring with state-dependent scripts needs `lagcheck.py --resync` (sgbrun
  `SGBRUN_CLOCK`: the GB input clock set to the NES's at the instruction where a waited-for
  frame ends, as firstdiff.py does), else the GB's input drifts onto another game path.
- Natives / idioms added for that (2026-11-20): `p34:8F57` sort, `FBEF` random (closed form),
  `p34:966A` English text line copy, `p32:9FE4` status sprites, `b40:9F00` ExRAM text-engine
  reload, `p2e:A697` / `A78D` monster attribute tables, `F9DA` / `DEEA` tile copies, small
  fixed-bank helpers (`FD20`-`FD47`, `F8AA`, `F8CB`, `F8F2`, `F8FE`, `FB80`, `FBAA`), inline
  PRG-RAM `(zp),Y` loads / stores, `(zp),Y` copy and 256-byte PPU block idioms, CHR tiles of
  `rt_ppu_copy` into the staging copy, the write cache set up at `$2006`, BPL/BMI peephole,
  cheaper cross-bank stubs (placed after the runtime in bank 0).
- Done: bulk `$2007` paths (map-row runs with step 1 and 32, `rt_ppu_copy` pieces, CHR runs
  inside a tile, `(zp),Y` upload idiom `rt_ppu_izy`, whole attribute tables `attr_put64`);
  attribute writes ~10x faster (one address computation per quadrant pair); fill idiom 24
  cycles per byte; 64-entry dynamic-target cache; natives: hex-to-decimal `p34:95E1`,
  divide rewritten, `F8EA` / `F8E0` / `F8C5`, `nat_9111` in three passes; JSR / JMP to a
  native calls bank 0 directly (no cross-bank call).
- Fixed on the way: the vblank handler incremented `VBL_CNT` (`$D832`) in whatever WRAM bank
  was selected, corrupting byte 2 of tile `$83` in the CHR staging copy; the test tools
  write the runtime's counters in WRAM bank 1 explicitly (PyBoy writes the selected bank).
- Remaining hot spots in battle frames: indirect reads `(zp),Y` of ROM data (~100 cycles
  each), OAM conversion (~5k cycles a frame), banked ROM reads, cross-bank calls (~400
  cycles each), the HP window redraw (text buffer through `STA (zp),Y`).

## Battle re-layout (2026-11-20)
- `tools/gb3/layout.py EN.nes OUT.nes` (also `layout.apply()`): the NES-side layout, patches
  checked against the original bytes, new code as asm6502 modules. `ff3src.py --english --gb`
  makes the source base of the layout ROM (`build/ff3/src_gb`), `build.py --gb` builds
  `build/ff3_gb.nes` + `build/ff3_gb.gbc`.
- Battle: party column (x 160/164, 24 px apart, step 8/12 px), windows from row 19 with one
  row per text line (party window cols 2-21, command / names cols 2-11), command / list
  cursors one row per line, the command hand over the frame at the screen edge; battle
  messages in one full-width window (FF3's open / close message routines rewritten in place,
  bank 52 $8D1B, helpers in ExRAM $5F30, state in the old box save buffer $5E90; arrow glyph
  in the unused font code $CA). Camera on / off through `$5806` (ExRAM trampolines at $5E7F
  around the battle's "reset ppu control" calls).
- Runtime: `$5806` = battle cameras: battlefield NES (20, 48) at GB (0, 0); from GB line 96 a
  LYC interrupt sets SCX = 16 + the split's X, SCY + 8 (window camera col 2 / row 7); map rows
  18+ carry the BG table of the IRQ's `$2000` (`spl_bank`, `rebank_spl`); sprites below the
  split use the window camera, NES row 18 hidden.
- Fixed: the native "clear VRAM" (`nat_9f98`) never cleared sprite table 1 (SVBK reads with
  bits 3-7 set): a stray tile on every party member's head. Native bconv in GB-layout mode
  started lines at offset 1.
- Checks: `firstdiff.py build/ff3_gb.nes build/ff3_gb.gbc 12000 --input explore --ignore
  00C9-00CA,00D0-00DF,0014-0014`: identical through waited frame 11,881 (opening battle and
  the cave battles with messages). Screens: `gbshots.py` (NES / mGBA CGB side by side, input
  resync; `--freeze W`, `--dump DIR`): battlefield, party, command window + hand, messages as
  the NES. Lag (`lagcheck.py ... 2000 12000 --input explore --resync --step 10`): +0.1% in
  total; steps of +16 / +22 / +73 frames at screen loads (3854, 8544, 9877).
- Enemy-names window while choosing targets (attack, jump, magic: hook before the battle
  graphics' "choose targets"), as wide as the longest name shown (8-18 columns; a 19-letter
  name on two rows; 4 long-named types can push the 4th out).
- Item / Magic lists: FF3's item list scrolls sideways (2 columns of 4 visible, 9 columns),
  the magic list has 3 spells per level over 28 columns: neither fits; mock-ups for the owner
  (`mockup.py NES OUT lists`: tall window GB rows 8-17 vs the 6-row window; items one column
  per page, magic rows as FF1: spells 1-2 / spell 3 + level and MP).
- Field camera (owner: centre the player): the default camera is now (40, 45), the party
  (NES x 112-127, y 109-124) at the GB screen's centre; the overworld draws the walking
  party at the same place (x $70, y $6C; ships y $6F, airships $5F). Minimap (the Sight spell
  on the overworld): its own camera (48, 64) set at its last screen setup (bank 58 $8C3F ->
  ExRAM `minicam`, runtime `$5802`/`$5803` = screen camera until the screen goes off after
  it); checked with a test build (`GB3_TEST_MINI=1`: Select on the field opens it; gbshots
  `--press W:PAD:N`): the map box centred (GB x 14-145, y 14-130).
- **Item / Magic lists (owner's choice: tall window, item pages, magic rows as FF1):** `$1A`
  bit 7 marks a list window for FF3's window routine ($8BC3 -> `winh`: 8 rows instead of 4,
  and `$5807` = the GB's tall list camera: NES rows 19-28 from GB row 8, split at line 64,
  SCY +40, sprites in the hidden band dropped). Items: the cursor column on the left (cols
  2-16), the next column at cols 17-31 (its edge shows), left/right turn whole pages (page
  routines in place of FF3's sideways scroll, `ITEMPG_SRC` at bank 53 $B2A7); the hands'
  labels "R.Hand" / "L.Hand" (FF3 wrote Japanese codes the English font shows as "fGS" /
  "aPnS", also in the plain English NES build). Magic (owner, after a first two-row version was "too visually confusing"): cols 2-21, per
  level a line "Lv<n>  MP cur/max" and one spell per row (4 rows, 2 levels per page): rows from
  `MGROW_SRC` (bank 87, through the English converter's far entry $A009); input through
  `MAGIN_SRC` (bank 53 $B370, in place of the generic list input $899E): up / down step through
  the spells in list order (into the next level after the third), left / right jump a level,
  the hand placed from the menu's own state ($25 level row, $26 spell). The unusable-spell
  mark ('X') sits in the cell before the spell's icon.
- Runtime fixes on the way: the LYC handler did not keep HL (hung PyBoy at a battle start);
  bank 0 was full: the clear-VRAM and rng-init natives moved to the RT_TABLES bank behind
  stubs; sprite conversion: a rejected last sprite left its Y in the next slot (stale sprite),
  and in the tall list window the low rows were dropped before the split moved them up.
- Tools: `gbshots.py --press W:PAD:N` and `--poke W:ADDR=VAL,..` (NES and GB alike), e.g.
  member 1 as a Black Mage with spells: `--poke 2560:6100=04,6130=09,6131=09,6207=07`.
- **Field dialogue (as FF1's approved layout):** the field text windows (bank 127 $EDB2) placed
  inside the GB view (screen cols 5-24, rows 6-23 of the field camera): dialogue box cols 5-24,
  rows 6-11 (4 lines of 18 above the centred party; even rows / heights so the box shares no
  attribute quadrant with the map), yes/no (17,14,8,8), item select (5,12,20,10), gil
  (13,18,12,4), map title (5,6,20,4); the English dialogue re-wrapped at 18 columns (insert.py's
  table builder run again from layout.py; a word longer than 18 breaks after a hyphen); the
  window attributes one quadrant wider (the windows start at the odd col 5: helper in the
  unreferenced code at bank 127 $F435); the map redrawn on closing for the new rows ($C9B9 /
  $C9C4: count, start = bottom metatile row + 1). FF3 scrolls longer texts page-wise. Checked:
  the opening "Ow ow ow" dialogue on NES and GB (mGBA). Not yet seen: yes/no, item select, gil,
  map title windows (no input script reaches them).
- RAM checks: `--ignore 00C9-00CA,00D0-00DF,0013-0014` from now on: $13 (buttons pressed last
  frame) depends on the battle input loop's polls per frame, as $14 does.
- Open in battle: back attacks, bosses / large formations.

## Main menu (2026-11-20, owner's choice: mock-up N5B)
- Mock-ups (`mockup.py NES OUT menu`, N0-N5): owner chose the party window on the left with
  one block per member (name + level / job condensed / HP green / MP of the 8 levels), "Lv"
  and the HP / MP labels on the English font's rows (FF3's label glyphs sit 1 px lower: the
  owner saw the misalignment), the member's lines pulled up 0 / 1 / 1 / 2 px with 3 px
  between members (B over A = grid + rule), commands top right, Gil / Capacity in 4-px digits,
  the guest's name at the bottom right.
- NES side (`layout.main_menu`): camera (24, 0); windows (3,0,13,22) party, (16,0,7,9)
  commands, (16,9,7,4) Gil + CP, (16,13,7,5) guest (window 4 no longer opened); strings
  $0130-$0133 for the GB in one-row mode ({0E}): per member name / job / HP / MP rows and a
  blank row (map rows 1-4 + 5i, 5 + 5i); the MP of a level is a 2-cell field, written right
  to left so the blanks fall under the previous digit; the guest names "Sara" / "Cid" /
  "Alus" (5 columns; only code 07 uses them). Gil and CP: `SMALLNUM_SRC` in bank 88 (free
  space after the English job names, through the JOBF dispatch: Y = 12 with A = $FF) draws
  6 tiles ($7B-$7F, $CA: unused in the field menus) in the vblank. HP colour: $95B2 rewritten
  to send each member's palette (0 green, 1 orange, 2 pink) to the GB register $5809 and
  switch the GB menu mode on ($5808); close menu ($A685) switches it off. Label glyphs
  L V E H M P one row up in the font block; the level as "Lv" (English letters, $F2AC).
  No class / guest sprites in the main menu loops; the character-select hand at each name.
- GB runtime: `$5808` menu mode: camera (24, 0); the right windows (NES cols 16-22 = map
  cols 16-31) copied by `map_flush` into the window map $9C00 (one DMA block per row,
  rows 0-17), shown on the window layer from GB col 13 (WX 111, LCDC bits 5-6 in the
  vblank); the party window's pixel offsets by SCY steps from the LYC interrupt (`mnu_isr`,
  table `MNU_EV`: 12 steps, 3 per member: the job / HP lines up 1 px, the MP line 2 px, the
  blank row's first 2 px as the gap, the bottom frame from line 136). `$5809` writes the
  member's HP row palette per tile into the attribute shadow; menu mode off rebuilds those
  rows from the NES attributes. The map flush starts a vblank byte earlier in menu mode
  (window rows: 3 DMA blocks per row; a DMA after the vblank loses its writes).
- Crash found with a guest (pre-existing): the guest name's text path pushes at fix:F2FC,
  jumps to ExRAM `sname` and pops at fix:F0D5; the recompiler's cross-bank jump stub
  (call + ret) sat in between. Fixed-bank and ExRAM code are now one component (same GB
  bank, plain jumps).
- Checks: `firstdiff.py ... --freeze 4500 --press 4520:16:3,4640:128:2,4720:64:2,4800:64:2,
  4880:16:2` (open, Item, back, close, reopen): identical; explore 12000: identical after the
  bank change; screens (mGBA CGB): menu, guest, Gil 9876543, CP 255, dead / poisoned
  members (pink / orange HP, "Death" / "Poison" in place of Lv), character select.
- Tools: `firstdiff.py --freeze/--press/--poke`, sgbrun `SGBRUN_TRAP=ADDR` (last 64 PCs when
  PC reaches ADDR; needs `SGBRUN_PROF2` for the per-instruction loop), gbshots
  `GBSHOTS_LOG=FILE`, `GBSHOTS_KEEP=1`.
- Owner after seeing it built: "I did like the small font and the slashes" / "I like the big
  numbers for HP": the MP row in 3-px digits with slashes (mock N6 tried both; HP keeps the
  English font). 20 static tiles ("0/".."9/", "0".."9", `mp_tiles()`) drawn by SMALLNUM over
  the word tiles the main menu never shows (Leviathan, Catastrophe, Text Speed: $E5-$F6,
  plus $C9 / $CF), 5 tiles per vblank, then the MP cells (NES rows 4 + 5m, cols 6-13) from
  $6130 + $40m + 2l; closing the menu ($A685 -> `mnuoff` -> bank 88 `restore`) copies those
  20 glyphs back from a build-time copy of the ROM font (RT1/RT2). `RST` ($5FFE, ExRAM image
  byte $FF) = $A5 while the MP tiles are in place (no upload when the menu is redrawn
  without closing). Checked: Item menu shows the restored tiles, the main menu after it
  the MP digits again; firstdiff menu sequence identical.
- Closing the menu: the restore and the GB menu mode off now come after FF3's screen clear
  (`mnuoff` in place of $A693 JMP $F465), so the clear shows the menu as it was (before:
  word-tile letters in the MP cells and the camera jumping for a few frames).
- Sub-menu mock-ups (`mockup.py NES OUT sub`, S1-S5: item list, item target, magic, equip,
  status) sent to the owner.
- **Sub-menus (owner approved mocks S1-S5, status stats condensed on one page):**
  - Status: window $1D (1,1,20,18), camera (8,8) (`stcam` in place of $956F at $A841), no
    label window / class sprite; string $0147 for the GB (name + job, Lv + EXP, values right-
    aligned); the condensed words (Proficiency, To next level, the 5 stats: 34 tiles,
    `STATUS_WORDS`) and the MP digits drawn by bank 88 `status` on job-name tiles the member's
    job does not use (`wslots`, job tile ranges `job_tiles()` as insert.py), restored from
    JDATA on close (`WST` $5FFD); HP row green via the new row-palette register.
  - Equip: windows 4 (1,1,20,11) and $1C (1,12,20,7) (free since the main menu / status no
    longer open them; $0A / $0B stay for the shops), message window $1E (1,12,20,4), strings
    $013E / $012F one row per line (count at column 15), messages re-wrapped at 18.
  - Item: label 5 (1,1,20,3) "Item", list 6 (1,3,20,16) one item a row; the party window 7
    (1,12,20,7, one line per member, green HP) drawn only when an item is used (`stuse` before
    the target selection), prompt window $15 (1,9,20,4) above it (prompts re-wrapped at 18);
    after the choice FF3's redraw ($AA8E) now opens the list window with its frame and undoes
    the party window's palettes (`stcl`). Select-character hand table $A74F per line.
  - GB runtime: row palettes `$580A` row / `$580B` column / `$580C` count * 4 + palette;
    rows recorded (`OVR_ROWS`) and rebuilt from the NES attributes on `$5808` = 0.
  - Checks: firstdiff status / equip / item sequences and explore 12000 identical.
  - Magic: header $24 (1,1,20,4) name / Use Swap Item, list window 8 (1,4,20,15) (unused id;
    item keeps 6): per level "Lv<n>  MP cur/max" and its 3 spells one per row, 3 levels a page
    ($013C for the GB = page 1; `mpage` after FF3's copy to $7B01 calls bank 88 `mgpage`, which
    moves the level digit / MP codes by 3p and the spell codes by 9p and ends the text past
    level 8); the spell cursor moves one spell a step and `mmove` turns pages on left / right
    (bank 88 `mgkey`, page in ExRAM $5FFF, reset when the menu closes). The party window for
    item and magic targets is drawn by select character itself ($A717 -> `stsel`); the magic
    list redraw opens window 8 with its frame and undoes the party window's palettes (`stmr`,
    in the unused delete-spell routine); `stcl` moved into equip's dead class-sprite routine.
  - Checks: magic (pokes: a Black Mage with MP; page turns), item, equip, status sequences and
    explore 12000: identical.
- Open: the sub-menus Job, Save (need a save with crystals / the world map) still use the NES
  layout through the field camera (mock-ups next).

## Known open items
- Field: the top screen row can show stale map rows (GB map rows 30-31) at the vertical wrap
  (NES 240 lines, GB map 256): FF1 solved it with an LYC split (pre-existing; seen as a black
  band or old menu cells at the top after a menu).
- Warp (`p3c:9B5F` TSX / TXS arithmetic) and the inn's `TXS` from a saved X (`p3c:9039`) use
  FF2's approximate helpers: need a semantic version (as FF2's open item).
- Sound: APU writes ignored for now.
- Field dialogue box: drawn into the map (the NES shows it from the other nametable by a
  raster split); belongs in the window layer (FF1 lesson).

## Next
1. Sub-menus (Item, Magic, Equip, Status, Order, Job, Save: mock-ups to the owner first),
   the field's vertical wrap, battle details (back attacks, bosses).
2. Native presentation (owner's decision 2026-11-20, `docs/gb-native-presentation.md`):
   profile the lagging screen loads (post-battle map load, doors / stairs) and replace their
   drawing with native GB routines; native music driver and sprites later.
3. Sound (APU -> GB, FF1/FF2 model) until the native music driver exists.
