# Working rules for this repo

- **Do not use subagents** (no Agent/Task delegation, no workflows). The project owner
  wants all analysis and translation done directly in the main session.
- Follow `README.md` (translation rules) and `docs/translation-guide.md`.
- Never commit ROM images. Commit and push work frequently.
- ROMs for work sessions live in `roms/` (git-ignored). Check them against the SHA-1s in
  `README.md` before use.

# Game Boy ports (set by the project owner — binding)

The English translations are being adapted to the Game Boy. Design: `docs/gb-port.md`.

## Targets
| Game | Target | Cartridge |
|---|---|---|
| Final Fantasy I | **Dual-mode ("black cartridge")**: runs on Game Boy (DMG), Super Game Boy (SGB palettes/border) and Game Boy Color (CGB colours matching the NES palettes) | Largest mapper needed (MBC5, sized to the game) + battery SRAM; header CGB flag $80 |
| Final Fantasy II | Dual-mode, as FF1 | same as FF1 |
| Final Fantasy III | Game Boy Color only (the only Color-only cartridge) | MBC5 + battery SRAM; header CGB flag $C0 |

FF1 comes first, then FF2, then FF3.
Dual-mode (owner's decision, 2026-11-18, replaces "DMG + SGB" for FF1/FF2): one ROM; on
a CGB the runtime uses CGB palettes (NES palette RAM -> RGB555, NES attributes -> per-tile
attributes in VRAM bank 1), double speed, HDMA for tile uploads and VRAM bank 1 tiles
where useful; on DMG/SGB it keeps the 4-shade path plus SGB palettes and border. Screen
layouts are the same in both modes. Test the CGB mode in PyBoy and mGBA, SGB in mGBA.

## What the repo may and may not contain
- **Tools only.** Do not pack FF's characters, art, music, maps, story or code into the
  repo. Every game-specific byte comes from the user's own NES ROM when the build runs.
- **Nothing is distributed.** No prebuilt GB/GBC ROMs, no ROM-derived data files, and no
  patch that contains game content gets committed or published. The only user is the
  project owner, who builds locally.
- Building a GB ROM **requires the original NES ROM** as input. The pipeline is NES ROM → existing
  MMC5 split + English insert (`tools/split`, `tools/ff1/insert.py`, …) → GB build
  (`tools/gb/`) → GB ROM in `build/` (git-ignored).

## Approach
- **Static recompilation** of each game's own 6502 code to SM83, not a hand-written
  re-implementation. Game logic, formulas, RNG and events stay exactly as on the
  Famicom, and the English patch carries over without changes.
- A runtime layer converts NES PPU/APU/mapper writes to Game Boy hardware: tiles
  (NES planar → GB interleaved), nametables → BG map, attributes/palettes → SGB
  palettes (DMG/SGB mode) or CGB palettes (CGB mode; FF3 always), OAM, scroll through a camera, APU → GB sound
  (triangle → wave channel).
- The screen is 160×144 instead of 256×240. The field uses a camera centred on the
  party. Dialogue, menus, shops, battle, title and ending get re-laid out for 20×18
  tiles. The translation text stays the same; only wrapping/layout changes. Until a
  screen is re-laid out, the camera pans over it.
- Tools are Python 3, with no outside toolchain (own SM83 assembler, like
  `tools/asm6502.py`). PyBoy (`pip install pyboy`) is used for headless GB testing.
- **Screen layout direction (owner's decision):** take inspiration from SaGa 3 (Final
  Fantasy Legend III) and other Game Boy RPGs. No two-character-panel splits and no
  panning across the NES layout. Party shown as compact one-line-per-member lists
  (name, HP, status), full-width windows, command windows opening over the party
  window, enemy graphics in the upper part of the battle screen.
  - **Battle (owner's decisions):** the party member sprites stay visible in battle; the
    acting member's line and the target flash. Re-layout is done properly in the NES code
    (reverse-engineer FF1's battle/menu drawing and change it), not by a runtime screen
    compositor that rearranges the NES picture.
- **SGB testing uses mGBA** (owner's decision): `tools/gb/mgba/sgbrun.c`, built against
  `libmgba-dev` (`gcc -O2 tools/gb/mgba/sgbrun.c -lmgba -o build/sgbrun`), runs a ROM
  as SGB with borders, scripted presses, PPM screenshots. PyBoy stays for DMG logic
  checks (it has no SGB).
- Verification: run the NES (`tools/emu`) and GB builds side by side with the same input
  and compare emulated RAM frame by frame (as in `tools/split/equiv.py`), plus
  screenshots of every re-laid-out screen.

## Keeping this file current
Update the status below as work goes on (about every 5 minutes of work): work done,
work remaining, scope and plan. Commit and push it with the work.

# GB port status (last updated 2026-11-18)

**Handoff: `docs/gb-handoff.md`** (session setup, current battle-layout work, exact next steps).

## Scope and plan
FF1 first (dual-mode DMG/SGB/CGB), then FF2 (same engine family, dual-mode), then FF3
(GBC only).
Milestones per game (from `docs/gb-port.md`):
1. SM83 assembler + minimal runtime that boots in PyBoy (test pattern, SGB detect).
2. Recompiler on the fixed bank only; title screen shown through the camera (pan mode).
   Measure CPU time per frame on DMG speed.
3. Whole game recompiled; emulated RAM matches the NES across random play.
4. Sound (APU → GB).
5. Screen re-layouts for 160×144: dialogue, then menus/shops, then battle, title, ending.
6. Colour: CGB mode first (NES palettes -> RGB555, attributes -> CGB attribute map, double
   speed, HDMA), then SGB palettes + border; save RAM, timing, accuracy pass.

## Done
- Design notes: `docs/gb-port.md` (targets, memory map, PPU/APU layers, verification).
- ROMs checked (SHA-1 OK) and kept in `roms/` (ignored). The English FF1 NES build
  (`build_mmc5.py` + `tools/ff1/insert.py`) reproduces the patch's result SHA-1
  `76aa4d30…`; this is the GB build's input (`build/ff1_en.nes`).
- PyBoy 2.9 installed for headless GB testing (reinstall each session: `pip install pyboy`).
- `tools/gb/asm_sm83.py`: SM83 assembler (multi-bank, `bank()`/`low()`/`high()`, `.sym`
  output, header/checksum writer `make_rom`). `tools/gb/test_asm.py` checks all 500
  opcodes (encoding + length) against PyBoy's opcode table: 0 bad.
- Milestone 1 (except SGB detection): `tools/gb/boot_test.py` builds
  `tools/gb/rt/boot_test.s` (DMG header + SGB flag, MBC5+RAM+battery) into
  `build/boot_test.gb` and checks it in PyBoy: one vblank IRQ per frame, save RAM write,
  3-shade tile pattern on screen. `tools/gb/rt/hw.s` = hardware register names.

- NES emulator (`tools/emu`) now also logs code coverage: env `COV_LOG=FILE` ORs one
  byte per ROM file offset (bit0 executed, bit1 reached by RTS, bit2 by JMP (ind),
  bit3 by RTI, bit4 interrupt entry); RAM code at file index $200000+addr.
  Findings: vectors NMI `$FECF`, RESET `$FE2E`, IRQ `$FEEE`; the English patch runs
  helper code in MMC5 ExRAM `$5C00-5FFF` (image in bank 18, copied at reset), which the
  recompiler must compile from that image.

- Emulator coverage log extended to 3 planes (code / memory regions per instruction /
  stack tricks via a shadow JSR stack), and it follows MMC5 `$5116` (8KB at `$C000`).
- `tools/gb/covrun.py` (new game + random play under COV_LOG) and `tools/gb/nescode.py`
  (code map: coverage seeds + static flow, code spaces bNN/c62/far/fix/ex, report of
  unresolved targets, stack tricks, indirect accesses).
- FF1 engine facts for the port: the game is synchronous. `JSR $FE00` enables NMI and spins;
  the NMI handler `$FECF` drops the interrupt frame (PLA×3) and RTSes to the caller,
  so on GB this becomes "halt until vblank, return". The English patch uses MMC5 PRG
  mode 2: `$C000-DFFF` is 8KB bank 62 normally, far-code bank 40 during `farjsr` (RTS
  dispatch from ExRAM `$5D0B`). Other stack tricks: `b14:A330` PLA PLA RTS (return to
  caller's caller), TXS resets at `$C024`/`$C0D3`/`$FE6F`. Jump tables: `JMP ($0010)`
  at `c62:CA99` and `b14:B187`. Fixed code JSRs into `$8000-BFFF` (bank from `$5115`).

- Coverage: 4 × 80k frames of random play (`build/cov2/`, regenerate with covrun.py): ~12k
  executed + ~6.6k statically reached instructions in b11-b14, c62, far, fix, ex.
  I/O is only by absolute address (no indirect PPU/APU access). MMC5: only bank, mode,
  RAM-protect and mirroring registers (no multiplier). PHP 8, PLP 9, TSX 1,
  BVC/BVS 5, `LDA $2007` 6 sites. Sprites: up to 28 visible, tiles mostly < 128
  (240-243 too). Both 4KB pattern tables are loaded in full.

- **First recompiled build runs.** `tools/gb/build.py` (NES ROM → English NES → recompile →
  assemble → `build/ff1_en.gb`, 1 MB MBC5, ~1.5 s): 16.6k instructions in 4 code banks,
  runtime in bank 0 (`tools/gb/rt/runtime.s`), NES data banks copied to GB banks 1-32.
  In PyBoy (`tools/gb/run_gb.py ROM FRAMES`) the opening prologue text shows in
  English (centre 160 px of the NES screen, palette untuned).

- New game → name entry → class select → field (Coneria) all run on the GB build.
  `tools/gb/compare.py NES GB OUT` runs both in **lockstep by NES frame** (cynes exposes
  `nmi_count`; the GB counts frame waits at `$D830`) and diffs RAM/SRAM at checkpoints:
  0 bytes at several checkpoints, a few bytes in `$B0-$D5` elsewhere (sound state).
- Speed: steady play runs 1.00× (one GB frame per NES frame). Screen loads lag; CHR
  upload loop `$E9F6` replaced by a native routine (`rt/ff1_hle.s`, recompiler `ext` table).
  `tools/gb/profile_gb.py` reports GB frames per NES frame and PC samples in long loads.

- **Exact equivalence check:** `tools/gb/firstdiff.py NES GB [FRAMES] [--random SEED]`
  runs both builds frame-locked (cynes exposes `nmi_count`, `nmi_ram` = RAM at each NMI,
  `pad_history` = pad latched per NMI, `trace`) and compares NES RAM at NMI k with GB
  RAM on entering frame wait k (PyBoy hook). The new-game script (3662 frames) is
  **byte-identical** on GB. `tools/gb/tracediff.py NES GB K` compares the instruction
  sequence of frame K (NES trace vs GB label hooks) to find the first divergent
  instruction.
- Sprite tile cache (DMG has 384 tiles vs NES 512): 128 GB sprite slots, all 256 NES
  sprite tiles shadowed in cart RAM bank 1, allocated on use by the OAM conversion.

- Recompiler additions: exact PHP/PLP (`rt_get_p`/`rt_set_p`; PHP/PLA and PHA/PLP pairs
  move P to/from A), idiom table (`b14:B0F1` TSX…TXS = drop 3 frames → `rt_unwind3`,
  farcall-aware), static bank resolution for `LDA #n / JSR $FE03 / JSR $8xxx` (17 of 25
  banked calls; reaches b01, b09 and more of b13 statically), `JMP (ind)` through
  non-RAM pointers. Build: 18.5k instructions, 5 code banks.

- Bug fixed by the random runs: `$2007` read clobbered B (B must stay 0: BC = Y).
  Random play now identical for 7208 / 9408 / 15440 frames (seeds 2 / 3 / 1), then a
  pointer `$82/$83` + `$9B` divergence (being traced).
- Sound: `tools/gb/rt/apu.s` (pulse 1/2 → CH1/CH2, triangle → CH3 wave, noise → CH4,
  `$4015` mutes; volume changes retrigger). Tables (2048-entry timer→GB frequency, noise
  NR43) generated by build.py into bank 33 (RT_TABLES); code banks start at 34. FFT of
  the prologue music matches the NES pulse pitches.
- Assembler relaxes out-of-range `jr` to `jp` automatically.

- Vertical wrap: NES nametables wrap at 240 rows, the GB map at 256 → SCY mod 240 plus
  an LYC split (`stat_isr`); towns/field now show the right rows.
- CPU timing loops (DEY/BNE or DEX/BNE to itself, 5 sites) → `rt_delay_c/e`, calibrated
  to NES time.
- Debug tools: `crashfind.py GB SEED STEPS` (GB alone with the profiler's input; traps
  rst $38 / re-boot and prints the stack), `profile_gb.py --random SEED STEPS`.

- Crash fixed: `PLA PLA` (drop a return address) in battle code popped a farcall frame
  when the routine had been entered from another GB bank; drops now go through the
  farcall-aware unwinder (`rt_unwind1`). Seed-2 random replay: no crash in 16k frames.
- Speed over 13.7k NES frames of random play: 1.16× (GB frames per NES frame); the lag
  is in screen transitions (`$2007` shim ~32%, LCD on/off waits, CHR uploads).
- Layout plan: `docs/gb-screens.md`. Dialogue box: built through the map-row buffers
  (`$07C0`, routine `$D54B`), text origin column `(($29+$12)&$1F)*2`, row `$2F*2+3`.

- **Battle re-layout started** (`tools/ff1/gb_layout.py`, applied by
  `insert.py build/ff1_mmc5.nes build/ff1_gb.nes --gb`): per-screen GB camera set by NES
  writes to `$5800`/`$5801` (tiles; runtime `cam_x`/`cam_y`, default 6/6); battle uses
  camera X = 2 so the NES enemy box interior lands in GB cols 0-13 unchanged; enemy/party/HP
  box frames removed; field camera restored by a wrapper around the battle calls
  (`$C1D6`, `$C935`). `tools/gb/battleshot.py NES OUT --cam 2` shows a battle with the GB
  view outlined. Battle panel facts: 25x12 image at `$691E` (stride 32) copied to NES rows
  18-29 by `$F4A2`; box list = 5-byte box records + text records, redrawn by `$F652`;
  message boxes table `$F9E1`, enemy list `$F9DC`, command box `$FA13`.

- Battle step 1 done (2026-11-18): party sprites at NES x = 128 (`b12:9740`; step forward /
  back `$9951`/`$997C` = $78/$80), visible in GB cols 14-15 rows 0-11 beside the enemies.

- Battle step 2 done: name / HP-or-status label / HP number beside each sprite in NES cols
  18-21 rows 6+3i..8+3i (GB cols 16-19; `b12:AA5B` without the two blank dakuten rows,
  row table `$AB21`; palette 3 for those cells in the attribute table `$F3F8`).
- Tools: `tools/gb/ntlog.py` logs nametable/attribute writes in the battleshot battle with
  the code address that made them (find who draws a screen area).
- Battle bottom windows now 6 rows (owner, 2026-11-18: the bottom frame must show): frame
  on GB row 17, 4 text rows. Long messages use record 4 (whole window), so they have
  rows 1-4. GB battle line writer `gb_layout.BOXLINE` (replaces the English boxline in
  the far code with `--gb`): greedy word wrap over up to 4 rows, character row only,
  `$FE` forces a break; `tools/ff1/test_boxline.py` runs it in py65 on all 82 battle
  messages (2 need 3 rows; 0 bad).
- Fixed a crash in the earlier GB panel: the hidden dummy message boxes were 2 rows high,
  and the frame drawer `$F593` draws h-2 middle rows (0 → 255 rows over RAM). Now 3 rows.
- Mock-ups `mockup.py` draft 3 (`mock3_font_*`): the message window in the condensed
  proportional letters (owner asked about a smaller font). **Waiting for the owner's
  decision** before any font change.

## In progress / next
- Mock-up party (owner): DUNE Warrior, SPUD Monk, JOJO Red Magician, LEO Black Magician
  (`tools/gb/mockup.py`). `tools/gb/battleseq.py`: GB-view sheet of a whole battle on the
  NES (optional forced formation, fight/run input).
- **Dual-mode decided (2026-11-18):** after the battle layout, the colour milestone does
  the CGB mode first, then SGB (see Targets).
- (Done, see above) smaller (condensed proportional) font in the battle message
  window (mock-ups `mock3_font_*`, owner: "looks good") and in the name/HP column beside
  the sprites (`mock4_party_small.png`: A = name / HP+number / status word, B = NES order
  name / HP-or-status / number); owner also asked for a window frame around that column,
  as thick as the NES frames (`mock5_party_frame.png`: C = around the text only, 22 px of
  text; D = left side under the sprites' right edge, 27 px; Silence/Darkness/Paralysis
  do not fit C, Darkness/Paralysis do not fit D even in the narrow letters). Owner then:
  closed frame (top and bottom lines too) and HP as current/max ("192/899") in small
  digits. The sprites fill 4 x 24 px beside the enemies, so a closed party window must
  run the full screen height: `mock6_party_window.png` (cols 14-19: only ~20 px of text
  beside the sprite, too narrow) and `mock7_party_window_wide.png` (cols 12-19: name /
  HP cur/max / status beside each sprite all fit; enemy area 12 columns, so mixed
  formations, 14 columns on the NES, need new enemy positions; bottom window under the
  enemies only). Owner rejected mock6/mock7, chose "smaller copy of the NES layout on
  one screen", then sent a sketch: enemies top-left, sprites in GB cols 14-15 as now, a
  full-height framed window at cols 16-19 with name / status / HP current / max per
  member, bottom windows in cols 0-15. Drawn as `mock8_owner_sketch.png`: text area is
  only 22 px wide (Silence/Darkness/Paralysis overflow, HP split over two lines);
  owner: better fit and readability, and livelier messages than "Bob / Fire / Goblin /
  23 damage". `mock9_layout.png`: sprites spread over the full height (y = 6 + 33i),
  each member's name / status / HP / max beside its sprite, right window flush to the
  screen edge (23 px text), bottom window under the enemies (cols 0-13), enemy area
  keeps 14 columns; message style A (same words, actor > target / action / result).
  `mock9_messages.png`: style B, sentences (adds English words not in the Japanese:
  needs the owner to relax translation rule 1 for battle messages). Open: status words
  wider than 23 px (Silence, Darkness, Paralysis).
  **Owner's decisions (2026-11-18):** message style A (same words: "Bob → Goblin" /
  action / result); HP current/max on one line; members' lines NOT beside their sprites
  (sprites keep the NES column and step forward/back); a translation change for the
  status words is fine. Drawn as `mock10_battle.png`: right window 5 columns (GB cols
  15-19, full height, full-thickness frame), one block per member (name / "192/899" in
  3-px digits / status), sprites at GB cols 13-14 (NES x = 120), bottom window cols 0-14;
  status words "Blind" (Darkness) and "Numb" (Paralysis). Mixed formations (14 enemy
  columns) need their right-hand enemies moved one column. Owner: no overlap of sprites
  and formation. The mixed formations fill the whole 14 x 12 enemy area (2 large + 6
  small = 168 tiles), so they cannot be re-laid into fewer columns; `mock11_battle.png`:
  enemies GB cols 0-13, sprites cols 15-16 stepping into 14 (no overlap), party info in a
  bottom-right window (cols 8-19), one line per member (name, HP cur/max, status),
  bottom-left window (cols 0-7) for enemy names / messages / commands (narrow: ~11
  letters per line). **Owner approved** ("probably the best we'll get"), centred as
  `mock12_battle.png`: camera X = 1 (enemy area GB cols 1-14), sprites at NES x = 140
  (GB x = 132, step forward to 124), margins 8 px left / 12 px right. Implementation
  order: (1) measure all formation types (incl. fiends, Chaos) and count free BG tiles in
  battle; (2) small-font tile renderer in the NES code; (3) party window, sprites,
  message style A, status words; (4) GB build + firstdiff + PyBoy/mGBA.
  Formation types (bank 11 `$8400`, 16 bytes each, byte 0 high nibble): 43 × 9-small,
  47 × 4-large, 29 × mixed, 8 fiends (115-122), Chaos (123).
  Owner: long enemy names must fit well in the messages. Widest: monsters 65 px, enemy
  attacks 59, items 75; the bottom-left window has ~54 px. `mock13_msgs_narrow.png`
  (wrapping log: lines scroll off, still overflows) vs `mock13_msgs_wide.png` (full-width
  message window over the party window while a message shows: all on one line).
  **Owner chose the full-width message window** ("let's get cracking").
  Facts for the implementation (2026-11-18):
  - `tools/gb/formations.py` (forces each formation via `$F292`, survey of all 128):
    enemies use NES cols 2-13 (9-small), 2-15 (4-large, mixed, Chaos), 4-11 (fiends),
    rows 6-17. Battle BG tiles: $00/$FF blank, $01-$10 backdrop, $12-$79 enemies,
    $80-$F6 font, $F7-$FE frame; $7A-$7F never shown.
  - Battle start uploads both pattern tables ($000-$1FF); leaving battle (escape tested)
    reloads the whole BG table, so the battle may overwrite the font tiles.
  - Font tiles are ink colour 3 on colour 2 (plane 0 = ink, plane 1 = $FF).
  - GB runtime: CHR writes with the LCD on go through the VRAM queue (40 bytes per GB
    frame), so text redraws must touch few tiles.
  - Free space: far-code bank 40 has ~7 KB free, banks 41-61 empty. RAM never written
    and never addressed by executed code (4 x 80k coverage + battle runs): $0340-$03BF,
    $6DB2-$6EFF ($6F00-$6F0F is used).
  Plan: small-font (VWF) renderer in the far bank: glyph table (codes $7A-$FF: width +
  8 rows, from latin_font COND/G + 3-px digits + arrow), line buffer at $6E00, upload of
  finished tiles in vblank; fixed tile pools: party window 40 tiles, left window +
  full-width message window 72 tiles (font range $80-$F6). Party window stamped into the
  panel image on panel clear ($F618) so the message window (a full-width box) covers it.
  **Implemented (2026-11-18, NES side, checked with battleshot --cam 1):** camera X = 1,
  sprites NES x = 140 (step 132), small-font renderer (`gb_layout.VWF_SRC`, far bank 40:
  `vchar`/`vstr`/`vupload`, glyph table from latin_font + 3-px digits + arrow), party
  window stamped on panel clear (`party_stamp`, hook `$F625`), party lines on HP update
  (`party_line`, hook b12:`AA5B`), `boxline` replaced by VWF text into tiles
  $A8 + 18(row-1) + col-2 with word wrap, message records with marker columns 21
  (target after the attacker) / 22 (next line). Command window and party window, the
  message window and style A messages show correctly on the NES.
  Gotchas: farjsr clobbers A (pass arguments in RAM); far code must not call routines
  that reach bank-62 code at $C000-$DFFF (e.g. $F47D -> JMP $C009 music): use the fixed
  trampoline MUSIC ($F2F1). `tools/ff1/test_vwf.py` runs the renderer in py65.
  Command cursor ($9F75) and party-target cursor ($9F85) moved (`cursors()`). Magic list
  (`gb_layout.MAGPAGE`, cursor $9FBF): two levels per page, two rows each. Text code
  `$FD $80+n` = pen to tile n (bytes < $48 are decoder control codes, $48-$79 get dakuten
  conversion; >= $7A pass). Text records are clamped to their row's 18 tiles.
  `battleseq.py --poke` patches work RAM in the state (e.g. spells at $63C0 + 64m).
  Cursor (owner, 2026-11-18): FF1's large 16-px hand, never over text, may be cut off at
  the left screen edge. Command and names windows are 9 columns (they cover the party
  window's left frame while open); Run = marker column 23 (column 6 + 3-px indent, x 51),
  its hand at x 35; Fight/Magic/Medicine/Items hands at x 0. Magic list: spells at
  columns 2 / 12 (hands x 0 / 80), row 2 = spell 3 + "L<n>  MP <count>"; checked with
  spells poked into all members (`battleseq.py --poke`).
  Item list (`gb_layout.ITEMLIST`): one group per page (weapons / armour, names up to
  75 px), group name at column 15; left/right flips the page (itemmove sets FLIP,
  fixed-bank ITEMFLIP $F633 -> $F300 redraws after farjsr returns); cursor table $9FD7
  x = 1 (itemmove recognises the Item list by x = 1). Page flips show FF1's stepwise
  panel redraw for a few frames (as the magic pages do).
  Blinking: the commanding member's line ($6B7A) blinks (16 frames blank / 16 shown, 10
  nametable writes) in every pad wait (b12:$97C7 -> hook $AAFC -> far `blink`) while the
  party window is visible. While the party-target cursor is up ($6AAC = 124, table from
  $9F85) the targeted member's line ($6AAB) blinks instead. Enemy targets: not yet.
  Message tear-down: an empty target shows the attacker alone (no arrow).
- **GB build of the battle layout works (2026-11-18):** `build.py --gb` -> `build/ff1_gb.gb`
  (18.7k instructions, 5 code banks); `firstdiff.py build/ff1_gb.nes build/ff1_gb.gb 7100
  --battle`: **no RAM difference in 7100 frames** (new game, walk, battle with messages,
  commands, party window, blinking); `--random 1`: no difference in 30000 frames. On DMG all BG uses one palette (BGP from NES
  palette 0), so window interiors are grey and the blink's $FF cells darker: colour
  milestone (CGB/SGB attributes). Details of the earlier plan: `build.py --gb` (builds
  `build/ff1_gb.nes` with `insert.py --gb`, coverage `build/cov3` from `covrun.py` on that
  ROM, output `build/ff1_gb.gb`), then `firstdiff.py`, PyBoy and mGBA checks. Coverage
  must be regenerated after every change to the NES code (far-code addresses move).
  `firstdiff.py ... --battle [--shots F,.. --out PNG]` checks RAM equivalence through the
  battleshot battle and saves GB screens. `docs/gb-handoff.md` has the current battle design,
  how it is built, and the next steps.
- Column-2 lists push a name down below a wrapped one (VNROW; 7 formations have a name
  > 56 px, only formation 69 lists two names).
- **Open design question (ask the owner):** the enemy-names window is never visible on
  the GB: the command window opens over it at once (same position). Options: show the
  names while choosing an enemy target (in place of the command window), or elsewhere.
- Battle still to do: enemy-target flash (ask the owner), end-of-battle messages,
  Medicine list, all formations (fiends, Chaos).
- Then main menu, dialogue (18-column wrap), shops, status, etc. (`docs/gb-screens.md`).
- `build.py` still builds from `build/ff1_en.nes`; switch it to `ff1_gb.nes` once the
  battle layout is usable (coverage logs must then be regenerated for that ROM).
- Recompiler and PPU-layer design written up in `docs/gb-port.md` §1-2 (registers X→E,
  Y→C; NES stack on the GB stack; flag liveness; ROM data through a bank-0 helper;
  queued VRAM writes; tile/nametable/scroll mapping).
- SGB packet sender + detection (MLT_REQ): PyBoy has no SGB, so it gets written with
  the SGB palette work (milestone 6) and is checked in an SGB-capable emulator then.

## Remaining (FF1)
- Milestones 2–6 above. FF2 and FF3 not started.
