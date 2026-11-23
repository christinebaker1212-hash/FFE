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
- **Owner's decision (2026-11-18): 0% slowdown on Color and DMG is non-negotiable.** Method
  (owner: "make this work in a way that lets us complete the work and keep 0% slowdowns"):
  keep recompiling the user's ROM (game bytes still come only from the ROM at build time);
  use the community disassemblies as references for annotation data in the builder (routine
  boundaries, code/data, what routines do) and write native GB versions of hot routines,
  above all the graphics paths. FF1: github.com/Entroper/FF1Disassembly (US release: match
  to the Japanese ROM); FF2 / FF3: github.com/everything8215/ff2, /ff3. Never copy game code
  into the repo. Measure with tools/gb/lagcheck.py (Gambatte, hardware-like timing).
- **Owner's decision (2026-11-20), all three ports: game LOGIC recompiled from the user's ROM,
  PRESENTATION native Game Boy code** (picture layer, sprites, music, screen loads), so 0% slowdown
  holds on DMG and CGB. Measure first (lagcheck, sgbrun SGBRUN_PROF2 buckets), reproduce each
  replaced routine's RAM side effects exactly, tiles converted at build time from the user's ROM.
  Write-up: `docs/gb-native-presentation.md`.
- **Owner's mandate (2026-11-20), FF3 (Game Boy Color only): the Game Boy Color must not
  emulate the NES while the game plays.** The recompiled code with an NES-hardware layer was a
  good first solution; from now on replace the NES-hardware layer (PPU register / nametable /
  attribute / CHR shims, MMC5 banking and IRQ, APU, the `$4014` sprite page) with native Game Boy
  Color routines written from the everything8215 disassembly, routine by routine, until the
  translated game code no longer calls it. The NES ROM is only the build's input. Plan and
  worklist: `docs/ff3-native-plan.md` (`tools/gb3/nesmap.py` lists the remaining call sites).
- **Owner's decision (2026-11-18): FF1 stays on the current approach (static recompilation of
  the user's ROM + native routines). FF2 and FF3 switch to their disassembly sources
  (everything8215/ff2, /ff3) as the base**, packed into the builder (fetched when the builder
  is made, never committed to this repo); the English patches get ported onto those sources.
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
  - **Battle (owner's decisions):** the party member sprites stay visible in battle; no
    blinking of the acting member, the targets or the enemies (owner, 2026-11-18: the
    cursor is enough; this replaces the earlier "acting member's line and target flash").
    While an enemy target is chosen, the enemy-names window shows. Re-layout is done properly in the NES code
    (reverse-engineer FF1's battle/menu drawing and change it), not by a runtime screen
    compositor that rearranges the NES picture.
- **SGB testing uses mGBA** (owner's decision): `tools/gb/mgba/sgbrun.c`, built against
  `libmgba-dev` (`gcc -O2 tools/gb/mgba/sgbrun.c -lmgba -o build/sgbrun`), runs a ROM
  as SGB with borders, scripted presses, PPM screenshots. PyBoy stays for DMG logic
  checks (it has no SGB).
- Verification: run the NES (`tools/emu`) and GB builds side by side with the same input
  and compare emulated RAM frame by frame (as in `tools/split/equiv.py`), plus
  screenshots of every re-laid-out screen.

## Release requirements (owner's decision, 2026-11-20 — binding, all three ports)
**No GB release (FF1, FF2 or FF3) until every item of `docs/gb-release-checklist.md` passes**:
Nintendo of America Lot Check standards (header / logo / checksums / flags, LCD off only in
V-Blank, VRAM / OAM timing, SRAM enabled only around access, save validation with an on-screen
message, soft reset A+B+Start+Select, no assumed RAM contents, cross-hardware behaviour and the
Color-only warning screen for FF3, Nintendo hardware names in text, meaningful CGB colour, no
undisclosed debug code). Record each item's result in the port's status doc.

## Keeping this file current
Update the status below as work goes on (about every 5 minutes of work): work done,
work remaining, scope and plan. Commit and push it with the work.

# GB port status (last updated 2026-11-23: FF3 native cutscenes, see docs/ff3-native.md)

**Lessons for all ports (FF2/FF3 sessions: read and apply): `docs/gb-lessons.md`.**
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
  Blinking was built and then removed (owner: no blinking at all).
  Message tear-down: an empty target shows the attacker alone (no arrow).
- **GB build of the battle layout works (2026-11-18):** `build.py --gb` -> `build/ff1_gb.gb`
  (18.7k instructions, 5 code banks); `firstdiff.py build/ff1_gb.nes build/ff1_gb.gb 7100
  --battle`: **no RAM difference in 7100 frames** (new game, walk, battle with messages,
  commands, party window); `--random 1`: no difference in 30000 frames. On DMG all BG uses one palette (BGP from NES
  palette 0), so window interiors were grey (owner: "the palettes look terrible").
  Interim: bit 7 of the $5800 camera write selects a fixed DMG battle BGP ($27: colour 0
  black, 1 light grey, 2 dark grey, 3 white; runtime `bgp_fix`). Windows read well, but
  enemies whose colour 3 is dark (red, purple) come out white. Proper fixes: CGB mode
  (NES colours) and, for DMG, shading each BG tile by the brightness of the NES palette it
  is drawn with (runtime CHR shadow + per-tile palette) - to be planned with the owner. Details of the earlier plan: `build.py --gb` (builds
  `build/ff1_gb.nes` with `insert.py --gb`, coverage `build/cov3` from `covrun.py` on that
  ROM, output `build/ff1_gb.gb`), then `firstdiff.py`, PyBoy and mGBA checks. Coverage
  must be regenerated after every change to the NES code (far-code addresses move).
  `firstdiff.py ... --battle [--shots F,.. --out PNG]` checks RAM equivalence through the
  battleshot battle and saves GB screens. `docs/gb-handoff.md` has the current battle design,
  how it is built, and the next steps.
- **CGB mode works (2026-11-18, colour milestone started; owner: "go ahead"):** header CGB
  flag $80 (dual-mode); boot detects a Color (A = $11) -> `is_cgb`; `cgb_palettes` loads
  CGB BG/OBJ palettes 0-3 from the NES palette RAM through `NES_RGB` (2C02 approximation,
  bank 0 $3E00, made by build.py); NES attribute writes (nametable 0) set the palette
  numbers of their 16 cells in VRAM bank 1 (`attr_apply`, queued while the LCD is on:
  `ATTR_Q` $D880, 6 per vblank); sprites carry the NES palette in OAM bits 0-2.
  `GB_CGB=1` makes the test harness (compare.GB) run PyBoy as a Color. Battle in CGB:
  NES colours, RAM identical (firstdiff --battle 7100 frames). Text tiles now use colour 0
  as background (FF1's battle blank tile $FF is colour 0: the "black bar" the owner saw
  under the first message on DMG). New-game script in CGB (`compare.py`, GB_CGB=1): name
  entry, class select and the Coneria field in NES colours, RAM diff 0 at all shots; DMG
  battle check still identical (black windows now). Next in colour: check all screens in CGB, double
  speed, HDMA; SGB (the DMG per-tile shading is done, see below).
- Fixed (owner: "player sprites totally messed up", 2026-11-18): the native CHR upload
  (`rt/ff1_hle.s`) copied a sprite tile to its slot from one byte too late (planes
  swapped, rows shifted) and treated BG tiles as sprite tiles (`cp $B0 / call c`), which
  overwrote resident sprite slots with BG tile data. Both DMG and CGB affected. CGB colours
  now use the cynes 2C02 palette values (our NES reference), so they match the NES shots.
- Column-2 lists push a name down below a wrapped one (VNROW; 7 formations have a name
  > 56 px, only formation 69 lists two names).
- Owner (2026-11-18): show the enemy names while targeting (done: entering the
  enemy-target loop, b12:$9B55 -> stub $AB07, saves the box count and redraws only box 0,
  the names; leaving it, $9B9C -> stub $9D94, redraws all saved boxes). No blinking.
- End of battle (checked with formation 62 and party damage poked to 255, `--poke
  6120=FF,..`): "The monsters were wiped out", "Experience up / 1800P", "Gold / 600 Gil",
  "Level up! / AAAA L2", "Max HP / 60 points", "Strength went up" all fit. The end-of-
  battle code (bank 11, $57 = 11) reuses the attacker/target records: there the target
  marker adds an unindented line instead of the arrow (VTV). Narrow-tile names
  (Tyrannosaurus) are plain text in the GB build. A single word a few pixels too wide
  for its row drops some letter gaps (vbreak squeeze, VSQ) instead of being cut.
- Medicine list ($F919): Potion / Antidote on rows 1-2 (second INC $6AA0 at $F962 dropped),
  cursor table b12:$9FE7 x 0 (hand at the screen edge), y 150/158. Checked with item
  counts poked ($6020-$603F).
- Transition glitch fixed: messages / lists drawn over the left window showed in its
  cells for a few frames (shared tiles) while the panel was copied. The 9-column left
  window now has its own 28 tiles (LPOOL: $F0-$F6, hidden backdrop $01-$11, $7A-$7D);
  vupload takes a tile number per cell (VTID).
- Fiends / Chaos checked (Lich f115, Chaos f123): graphics, names, targeting, messages
  fine; Chaos clears the party sprites. (The first shots were mangled because the test
  tool only patched one read of the formation number; `formations.patched` now patches
  every read of $6A, so the battle graphics match the forced formation.)
- GB build of the finished battle layout (fresh coverage, 18.7k instructions): firstdiff
  --battle 7100 frames identical on DMG and on CGB; CGB shots show the battle in NES
  colours with the fixed sprites (`gbc_battle3.png`).
- Battle animations (owner asked): weapon swings, hit sparkles and a spell cast (Cure:
  caster steps forward, screen flash, sparkles, "HP recovered!") checked on the NES build
  (`battleseq.py --input fire1 --poke` weapons + spells) and on the GB build in CGB mode
  (`firstdiff.py --input fire1 --poke ... --shots`): identical RAM over 7700 frames.
  `battleseq.pad_for(mode, f)` is shared by both tools.
- Battle layout done.
- **Plain Game Boy (DMG/SGB) shading done (2026-11-18, owner chose it next)**
  (`tools/gb/rt/dmg_shade.s`): every NES BG tile is kept in a shadow (cart RAM bank 1
  $B000) and re-coded for the palette it is drawn with. A colour's 2-bit value depends only
  on its brightness level (2C02 row, `LUM_TAB`), the same in every palette: 0 = the
  backdrop's level, the other levels in the four BG palettes grouped into 1/2/3 (darkest
  first; more than three levels split at the two largest gaps). So shared tiles (the font
  in the red name box and the blue letter grid) code alike. BGP over a black backdrop:
  dark grey / light grey / white; fades darken it (one shade per two levels below
  `REF_LMAX`). Maps are recomputed when the palettes have been stable 8 frames (same-colour
  rewrites ignored) or when the LCD goes on. With the LCD off nothing is shaded until it
  goes on: then the maps, one scan of the map (`dmg_scan_all`: palette of each cell's tile,
  tiles used), re-coding of the used tiles; unused marked tiles are parked (`DEFER_BM`)
  until a cell uses them. Tiles are re-coded only if they use a colour index whose value
  changed (`TILE_USE`). With the LCD on, 3 tiles per frame through the VRAM queue.
  Limit: a tile drawn with two palettes whose colours differ in level at the same index
  gets the last writer's coding (not seen yet on the checked screens).
- **Both modes, fixed with it:** attributes of nametable 1 were ignored (the field scrolls
  over both nametables; the CGB field showed grass where the NES has sea). Each GB map
  cell now records which nametable drew it (`OWN`, `own_set`), and an attribute byte only
  colours its own cells (only its changed quadrants); an owner change updates that cell.
  CGB attribute writes go through the VRAM queue (address high + $40 = VRAM bank 1).
  vblank order: OAM DMA, CGB palettes, scroll, then queued VRAM writes while LY is in
  144-152 (`flush_vbl`; the fixed 40 per frame ran past vblank once bank-1 entries were
  added, losing writes). Crash fixed: `rt_mmc_w5800` popped twice (battle start).
- Checks: firstdiff --battle 7100 frames and --random 1 30000 frames identical on DMG and
  CGB; shots `dmg_vs_cgb7.png` (class select, field, battle), name entry clean.
  Speed of the new-game script (compare.py GB frames at the last shot): DMG 4512, CGB 4426,
  before the shading 4178/4202 (the extra is the LCD-on scan and per-write bookkeeping).
  Debug aids: `firstdiff.py` env `STUCK_SAVE=K` saves the PyBoy state at frame wait K;
  ROM `rst $38` trap (`rst38_trap`, DBG+8 = SP, DBG+10 = stack).
- DMG sprites (owner: the cursor's light/dark were swapped): two fixed OBJ palettes
  (OBP0 black/dark/white, OBP1 dark/light/white); each NES sprite palette picks one and its
  tiles are loaded into their slots coded for it (`SPAL_KEY`, `SLOT_KEY`).
- **SGB done (2026-11-18, owner asked)** (`tools/gb/rt/sgb.s`): detection (MLT_REQ) at
  boot; colours: SGB palette p colour v = NES colour of BG palette p with value v (a hue
  preferred over a grey within a value); static screens per 8x8 cell from the NES
  attributes, encoded as ATTR_BLK rectangles (most screens 1 packet; >15 rectangles:
  ATTR_CHR); scrolling screens (field, towns) one palette for the screen from the
  palettes most cells use. Packets go out from the frame wait, one per 4 frames, only
  those that changed (built in cart RAM bank 2). Sprites take their cell's colours (SGB
  hardware). Border drawn by `tools/gb/sgb_border.py` (window frame, blue band, lattice,
  four crystals; no game graphics), sent at boot by VRAM transfer with the screen frozen.
  mGBA tools: `sgbrun` (build: `gcc -O2 tools/gb/mgba/sgbrun.c -lmgba -o build/sgbrun`)
  `--padfile/--nshot/--sram`, `sgbshots.py` (SGB/DMG screenshots with the NES checks'
  input), `sgbram.py` (game state vs NES; matched, apart from scratch bytes caught
  mid-frame). Found with mGBA: a STAT write on the DMG requests a STAT interrupt; it ran
  the LYC split handler at once and broke the scroll on every screen (fixed).
  Possible later: a palette of its own for the battle party column (sprites now take the
  colours of the enemy/window area they stand in).
- **CGB speed-ups done (2026-11-18):** double speed (KEY1 + STOP at boot; LCD-off timer
  and the NES-time delay loops scaled); tile uploads with the LCD on by general-purpose
  HDMA: BG tile bytes into a copy of the BG tiles (CGB WRAM bank 2), sprite slot loads
  into a copy of the slots (bank 3), marked tiles copied in the vblank (copy refreshed
  from VRAM when the LCD goes on). The GB stack moved to NES page 1 ($C100-$C1FF; the
  NES stack runs on the GB stack, deepest seen ~100 bytes) so it is outside the
  switchable WRAM bank; interrupt handlers select WRAM bank 1 and restore it. PyBoy
  does not emulate double speed (KEY1 reads 0); measure speed in mGBA (`sgbrun --cgb`):
  battle script to NES frame 7000 = 7549 GB frames (8485 at normal speed; DMG 9076,
  SGB 10083). Checks: firstdiff --battle and --random 1 (30000) identical on DMG and
  CGB; mGBA CGB/SGB game state = NES at checkpoints (`sgbram.py`).
- **Field dialogue re-laid out (2026-11-18)** (`gb_layout.dialogue`, DLG_SRC): box at the
  top of the GB view (NES cols 6-25, tile rows 6-13: frame, 6 text lines, frame; the
  party at rows 14-15 stays visible), text 18 columns from (7, 7). The box builder $D54B
  is rewritten table-driven (upper/lower tile row of each box metatile row); text
  origin $D520; dialogue text wrapped at 18 by `insert.py --gb` with code $05 between
  pages of 6 lines (up to 13 lines = 3 pages); $05 in the printer dispatch ($DBE8)
  runs far `dlgpage` (wait for A, clear the 6 rows one per frame across both
  nametables, scroll + music each frame). People standing over the box are hidden
  (`dlghide`, OAM upload) when it opens and after each page. Known: on the last page
  the field's own frame loop can show them again. Checked with a test ROM (a 2-page
  string in place of "There's nothing there."): firstdiff identical on DMG and CGB.
  Tools: `fieldseq.py` (field input scripts, NES shots), `firstdiff.py --field`,
  `build.py --nes FILE` (recompile a given English NES ROM).
- Recompiler: far routines are entry points even without coverage (`insert.py --gb`
  writes `<rom>.far`; build.py marks them as executed / RTS targets). Coverage
  (`build/cov3`) must still be regenerated after NES code changes (4 seeds x 80k).
- **Main menu re-laid out (2026-11-18)** (`gb_layout.main_menu`): camera (0, 0) for the
  main menu (b14 $B84D -> `cammenu`; menu screens cleared by $9C02 get the field camera
  6/6 via `camfield`, and the menu exit $AE15 restores it). Party window (0,0,20,10): per
  member two lines: name, L + level, HP current/max; class, or Stone/Poison while
  afflicted (b14 $B995 rewritten: template string with menu codes $10+m, nn). Commands +
  Gil (0,9,12,9): commands one per row (upper-row mode, one-row newlines; menu string 2
  for --gb in `MENU_GB`), Gil below ("{04}Gil", owner: keep "Gil"; 9 of the 10 columns). Orbs window (12,10,8,8), orbs centred
  (owner) at columns 14-17 rows 12-15 (whole attribute quadrants, two bytes: `orbattr`).
  No class sprites ($B648 -> RTS). Cursor tables: commands $B7F4 (x 0), members $B7EC.
  Owner feedback fixed: text out of the window (command window was 10 wide), orbs centred.
- Plain Game Boy (owner, 2026-11-18): menus black like the battle: when the darkest
  brightness group holds only the darkest NES colours ($0x, e.g. the window blue $01) it
  is black, the middle group light grey (the grey unlit orbs show). Brightness groups
  are now formed from the palettes the GB view uses (`PAL_USED`: the visible area at
  each LCD-on scan, plus palettes of cells drawn later; maps recomputed when one is
  new). LCD-on order fixed: scan, then maps, then re-coding. Fixed: tiles parked while
  unused stayed stale when a later screen drawn with the LCD off used them (the scan
  now un-parks them; the name-entry letters B, L, ... were missing).
- Sprite conversion fixed for camera X / Y = 0 (the main menu): sprites at the left /
  top edge were dropped (the menu hand cursor was invisible).
- **Items screen (2026-11-18)** (`gb_layout.item_menu`, camera 0/0): title window (0,0,8,3),
  list window (0,3,20,15) with 13 items per page from column 3 (hand at the screen edge);
  the list turns the page when the cursor passes its end (at most 23 items = 2 pages,
  `pagechk` at b14 $B621) and is redrawn when the cursor moves after a description
  covered it (every description window $B93E sets IDESC). Descriptions / prompts: window
  8 = (0,9,20,9), up to 7 lines of 18 (insert.py --gb rewraps DESC_IDS; "A button...Yes" /
  "B button...No" on two lines). A page turn takes ~35 frames (frame rows 1/frame, text
  rows 2/frame, as FF1's own menu drawing).
- **Magic screen (2026-11-18)** (`gb_layout.magic_menu`): list window 9 = (0,3,20,15), three
  levels per page (a level line "L1  MP 9/9", the three spells below from column 3);
  up/down change the level as on the NES, a level on another page turns the page
  (`gbmagcur` in ExRAM, called each frame from $B829). String 42 is the page of levels
  1-3 (`magic_tpl`); far `magpatch` (run for every menu string from $B957, recognises the
  copy at $6C00 by its first bytes) adds 3*page / 9*page to the level and spell
  parameters. ExRAM is full up to $5F80 (GB menu code there: `exram_source`).
- Coverage: `tools/gb/covall.py ROM build/cov3` regenerates all logs (4 random seeds +
  field scripts dialogue / menu / items / magic, with pokes) in parallel; build.py warns
  when `rom.sha1` does not match the NES ROM. Tools: fieldseq.py / firstdiff.py / covfield.py
  `--poke ADDR=VAL,..` (at frame 3700 on the field).
- **Weapons / Armor screens (2026-11-18)** (`gb_layout.equip_menu`): camera X = 1 (hands at
  NES x 0 cut off at the left edge). Top window (NES 1,0,20,4): title row 1 (titlexy),
  "Equip  Swap  Drop" row 2 (cmdxy; the chosen command red via barhl, moved to $23C0-$23C4:
  its frame segment below turns red too, reads as an underline). Two members per page:
  windows 1/2 = (1,4,20,7)/(1,11,20,7), name on the first text row, four slots below
  ("E" mark + names up to 17 letters; slot drawer $ED84 rewritten, page-filtered). The
  slot cursor on the other page turns the page (slotcur $BEC8). Swap shows both hands at
  once (no blinking). FF1's window drawer leaves $3A = x + 1, $3B = y + 2; lower-row mode
  ({09}) writes at row $3B, default and upper ({05}) modes at $3B / $3B - 1.
- **Status screen (2026-11-18)** (`gb_layout.status_menu`, camera 0/0): top window (0,0,20,8):
  name + Level, class, Experience EP / value, Until next level / value (string 38), class
  sprite right of rows 1-3; window (0,7,20,11): 5 stats (39) and 4 battle values (40), one
  per row, values ending at column 18. Items / magic titles (window 7) fixed: they were
  drawn on the bottom frame (now lower-row mode one row up).
- GB checks of the sub-screens (firstdiff, covall.SCREENS / items / magic scripts with
  pokes, DMG + CGB): all identical to the NES. Found and fixed with them: the magic list
  kept the field camera ($AEB3 -> cammenu); on DMG the red command highlight made letters
  vanish elsewhere (a tile is shaded for one palette only), so the GB build has no colour
  highlight (barhl off) and the chosen command keeps its hand while a slot is picked.
- Bug found by the coverage drop (2026-11-18): the GB menu code appended to ExRAM pushed
  the far-call tables (FARLO/FARHI) past $5F80, the battle text buffer; long battle
  messages overwrote them and the next farjsr jumped into zero page (random play hung in
  its first battle, so coverage lost ~10%). insert.py now asserts the ExRAM image ends
  before $5F80; the GB build drops the unused command-highlight routine (barhl) there
  (761 bytes, ends $5F59). ExRAM is nearly full: new GB code goes elsewhere.
- Coverage now also runs the battle input modes (`covbattle.py`, covall.BATTLE) with
  magic_pokes: the random seeds alone reached ~10% less code after the menu changes.
- **Shops (2026-11-18; owner: "SaGa style is fine, but show the Gil")** (`gb_layout.shop_menu`,
  strings `shop_text`, ExRAM list patch `SHOPLIST_PATCH`): camera X = 1. Speech (NES
  1,0,20,6): up to 4 lines of 18 (upper-row mode); list (1,5,20,12) sharing the speech
  window's bottom border: 5 items x 2 rows (name; price below, right edge GB column 18;
  magic shops "L3 price"); Gil (1,15,11,3) over the list's empty bottom-left corner,
  drawn again after every list draw (`lgold`), text row via `goldwin`; title (1,6,10,5),
  menu / Yes-No / names (11,6,10,6). No scene (10x10 picture `$DCCF` and party sprites
  `$AA0D` off), all attributes window palette, window 3 not erased under the list. The
  price question: line 1 empty, "<price> Gil, see." on line 2 (the price's blank upper
  row would cut the frame on line 1; this also fixes the NES-English bug where the price
  overwrote the line). Party names one per row (string in the menu bank, `SHOP['names']`).
  Checked on the NES: weapons (buy, sell), armour, white / black magic, church, inn, items,
  caravan. GB: covall.SHOPS scripts (buy, sell, magic, inn, items, church) identical to
  the NES on DMG and CGB, with all other checks (random 30000, battle, dialogue, menu and
  sub-screens); coverage 19.96k instructions. Shop facts: EnterShop b14 $A343 ($50 = enter flag, $51 = shop index = type*10 +
  town; open one with `--poke 0050=01,0051=01`), windows $AC53, attributes $AC6F, menu
  cursor $A98A, list cursor $A992. Pokes below $0800 work (battleseq.poke_state).
- Owner feedback fixed (2026-11-18):
  - Gil window's top border was cut: the amount (default mode) wrote a blank upper row over
    it; the amount is now copied into a lower-row string (`goldlow`, $0350) and "Gil"
    (shop string 8) is lower-row too.
  - Dialogue: people / the party appeared over the box after it closed. FF1 shows the box
    from the other nametable by a raster split ($D604/$D6A3) and never touches the map;
    the GB keeps one map for both nametables, so the box cells stayed. `dlgrest` (ExRAM,
    called at $CA1B instead of $D604) redraws the map rows under the box into the visible
    nametable after it closes (FF1's own row routines, as the opening loop $D4B3). ExRAM
    room: the unused English `partynames` / `clr20` dropped for --gb, the magic routines
    `gbmagini` / `gbm957` and tables moved to bank 14 $B7F9.
  - Seam in the dialogue box's left border: the box crosses NES row 240 -> 0, where the GB
    view skips map rows 30-31 with an LYC split; the SCY write landed mid-line. LYC is
    now one line earlier and the write waits for that line's hblank.
  - Checked: the 2-page test dialogue on DMG and CGB (border whole, map and people back
    after closing; firstdiff identical), and all 34 checks (shops, sub-screens, menu,
    dialogue, battle, random 30000; DMG + CGB) identical after fresh coverage (20.0k).
  - Test hook: env `GB_DLG_TEST=text` (insert.py) replaces dialogue 0 ("There's nothing
    there.") with a long text (test builds only; blanks dialogues 100-109 for room).
- **Prologue (2026-11-18)** (`gb_layout.prologue`, strings `prologue_pages`): two pages of
  18-column centred lines (sentences 1-3 from row 8, 4-7 from row 7; camera 6/6), each
  faded in by FF1's band fade; page 1 holds 240 frames, then page 2 (after FF1's own clear
  $A10A); a button skips the rest as on the NES, so the new-game input script keeps its
  timing. Code in b14 $AC6F-$AD12 (the shop's attribute table / picture data, unused by the
  GB shop). The title menu (Continue / Start Over / Message Speed) fits the default view.
- **New-game screens (2026-11-18)** (`gb_layout.new_game`): class select at camera 4/4 with
  four 10x9 boxes (4,4) (14,4) (4,13) (14,13) (member records b14 $A0C7 rewritten; box
  height via `boxh`); name entry at camera 5/2: one window (4,1,23,20) larger than the
  view, the name on the top row (no name box), FF1's letter grid unchanged (two columns /
  two rows apart, GB rows 1-17), all in the window palette; the field camera 6/6 again
  when the party is made (`camend`). The name sits right above the first letter row (the
  grid needs 17 of the 18 rows).
- DMG fix found with the prologue: a palette fade that changes a colour every frame never
  let the maps be recomputed (they wait for 8 stable frames), so the faded-in text kept
  the codings of the dark start (invisible). The maps are now recomputed at the latest
  16 frames after they became due (`maps_wait`), and palettes reached by attribute changes
  count as used (`pal_mark` in dmg_attr). On DMG the prologue background is dark grey
  while it fades (palette 1's grey $00 joins the darkest group).
- All 36 checks identical after fresh coverage (new game, shops, sub-screens, menu,
  dialogue, battle, random 30000; DMG + CGB).
- **Bridge / ending story (2026-11-18)** (`gb_layout.story_gb`): box (3,5,20,11) with 9 rows of
  18 columns (insert.py --gb: upper-row mode), camera (3,5) set on every page (b13 $B8E3
  area), field camera back after the bridge story (fixed $C154 -> `brw` at $EE12). The
  FINAL FANTASY picture shows below the box. Checked on the NES: bridge pages, all ending
  pages, "The End" (test copy with $C154 -> $B803). Bridge story via `--poke 6016=01`
  and a few steps (covall FIELD 'bridge').
- Checks (fresh coverage, 20.0k instructions): 37 of 38 identical; the bridge script on
  CGB differs only in the pad bytes $20/$21 at a page's A press (one frame early / late
  depending on the press timing; DMG identical) - the harness's per-NMI input feed meeting
  the story pages' button poll in double speed, not a layout difference.
- **World map (minimap, 2026-11-18)** (`gb_layout.minimap`): B + Select on the field; its
  nametable is copied from bank 9 $B000. The 16x16-tile map fits the default view (6/6)
  with a margin; the four corner dragons and the title above the map are blanked in that
  data for the GB build (they would only show as slivers at the view's edges).
- **15-puzzle (2026-11-18)** (`gb_layout.puzzle`): on the ship B x55 then A + B ($C26D:
  $25 = 55, $42 = $46 = 4); test with `--poke 0025=36,0042=04,0046=04` and A + B (fieldseq
  key Y; X = B + Select, T = Select). Camera (3,4) while it runs (wrapper `pzw` at $F7FA in
  the dead old battle-magic code; $F7FA-$F88E is free fixed-bank space), field camera after.
- SGB sprites (owner: "player sprites blend in with the background", 2026-11-18): a sprite
  takes the colours of its cell's SGB palette, and both OBPs gave it colour 1 = the
  darkest colour there (the window blue, the field's dark ground). Both OBPs now map the
  sprite values 1/2/3 to colours 0/2/3 (backdrop black outline, mid, bright): class select
  black/grey/white, the field party light with a dark outline. Owner: better in menus,
  worse in battle (the black outline vanished on the black backdrop). Battle now: the party
  column (GB cols 15-18, rows 0-11, backdrop only) gets an SGB palette of its own with the
  party's colours (`spr_col`: per DMG value the best colour of NES sprite palettes 0-1), in a
  slot no BG cell on screen uses, else slot 0 (NES palette 0 is the battle scenery strip,
  above the GB view; in view only empty cells use it); both OBPs then 1/2/3. The runtime
  knows the battle from bit 7 of the $5800 camera write (`in_battle`). The packet builder
  moved to ROM bank 63 (`SGB_BANK`, called through `sgb_build_far`): bank 0 was full.
- Coverage gap found with forced formations: formation 62 hung the GB at the battle start
  (fault 1: no compiled code for a jump-table target $A4E4). covall now also runs one
  battle per formation (128, `covbattle.py --form F`; the patched ROM keeps every code
  offset, so the logs fit the normal ROM).
  Cause found later: the test tool's formation patcher (`formations.patched`) also patched
  bytes inside the operands of STA/DEC $6AA5 ($F6B0/$F6B6); it now patches an explicit
  list of `LDA $6A` sites. With it, f62 and f69 run identical to the NES (firstdiff 7100).
- Fixed: the new-game camera code (`NG_B14B`) was assembled over the end of `camequip`
  (equip screen camera; invisible to RAM checks). It now starts at `EQ_CAM_END`.
- SGB battle party palette checked on f62 / f69 (mGBA): party in its own colours, enemies
  in theirs (`build/shots/sgb_forms.png`).
- Tools: `firstdiff.py --wram F` / env `WATCH=lo-hi` (print work RAM of both),
  `tracediff.py --battle`.
- Prologue fade on DMG / SGB (found with mGBA): FF1's band fade shows waiting lines in
  palette 1 (text = background colour), the fading half band in palette 2 and shown lines
  in palette 3, all with the same font tiles; a DMG/SGB tile has one coding, so letters
  vanished from shown lines and waiting lines showed. Now (`PBAND_SRC` at b14 $A287,
  far `pcopy` / `prow`): the page text is not drawn up front; a half band's rows are
  drawn when its fade starts, with a copy of the font in tiles $00-$7F (unused there),
  and with the font itself once shown (one row per frame in the vblank, from the page
  string's row pointers). NES output unchanged (screens after the prologue identical).
  SGB now clean; DMG: a new line's letters can flash white for a few frames (tile
  re-coding lags the palette while the fade dithers).
- SGB screen changes (found with the new mGBA pokes, `sgbrun --poke`, `sgbshots.py --poke`):
  a new screen (shop, story) showed ~12 frames in the old screen's colours (packets go
  out one per 4 frames). Now the LCD going off blanks the SGB screen (MASK_EN black,
  `sgb_mask`); nothing is built while the LCD is off; once it is on, one fresh build is
  sent and the screen is shown (the game's own fade-in follows). Shop, new game, menu,
  battle start, bridge story checked: clean, and the screens appear as early as before.
  (FF1 itself cycles the field colours when leaving the menu: the SGB follows.)
- Checks after fresh coverage (20.0k instructions): 39 of 40 identical (new game, random
  30000, battle, all field scripts; DMG + CGB); CGB bridge: pad bytes one frame off at a
  D press (harness input feed, as before; identical without the bridge-flag poke).
- **Speed pass (2026-11-18)**, measured in mGBA on the 7000-NES-frame battle script (GB
  frames): SGB 10596 -> 9864, DMG 9336 -> 9279, CGB ~7.5k. SGB builder: palette-only
  changes skip the cell count (`sgb_adirty`: attributes / LCD-on scan / camera), the cell
  count's inner loop inlined, the battle party slot reused while still free (one count
  instead of two), attribute writes while scrolling wait for the 32-frame rebuild, which
  runs only if the view moved. DMG: the LCD-on scan cell inlined. Tools: `sgbrun` env
  `SGBRUN_PROF=1` (PC of each lagging frame), `SGBRUN_PEEK=ADDR`.
- SGB check of all new screens in mGBA (menu, sub-screens, shops, dialogue, bridge story,
  world map, puzzle, new game, battle): fine after the prologue and screen-mask fixes.
- Recompiler and PPU-layer design written up in `docs/gb-port.md` §1-2 (registers X→E,
  Y→C; NES stack on the GB stack; flag liveness; ROM data through a bank-0 helper;
  queued VRAM writes; tile/nametable/scroll mapping).

## FF1 release (2026-11-18, owner: "local build only", FF1 only)
FF1 is complete for this release: all screens re-laid out, dual-mode colour (CGB / DMG /
SGB with border), RAM-identical to the NES in every check. The ROM is built locally
(`build/ff1_gb.gb`, git-ignored, never published). Build steps, checks and known limits:
`docs/gb-handoff.md`.

## After the release: owner feedback (2026-11-18/19)
Fixed: sound (cursor beep length: NES length counters / sweep / linear counter per frame,
`rt/apu_core.s`; noise channel), party reorder -> bridge scene bug, overworld camera
centred (FIELD_CAM_X = 5), transition effects (town / stairs curtain `rt_band`, battle-start
emphasis flash). New tools: `build/gbrun` (Gambatte, hardware-like timing; build with
`gcc -O2 -I/usr/include/libretro-common tools/gb/gambatte/gbrun.c -ldl -o build/gbrun` after
`apt-get install libretro-gambatte retroarch-dev`), `lagcheck.py NES GB UNTIL [--field S]
[--dmg] [--win N]` (GB frames vs NES frames per window = lag), `sgbrun` env
`SGBRUN_PROF2=K` (PC + real bank every K instructions). Builder: `tools/builder/
ffe_builder.py` + `.github/workflows/ffe-builder.yml` (Windows exe, FF2/FF3 shown disabled).

**Speed work (owner: 0% slower on Color and DMG, non-negotiable)** - state 2026-11-19:
- Catch-up pacing (`rt_wait_nmi`, CATCH_UP = 8): a long NES frame leaves GB frames not
  taken; the next waits return at once, so game speed and music keep time (a frame of
  picture is dropped). Not after LCD-off loads. Test harnesses must feed input at the
  joypad read (`compare.GB.feed_pads`): several game frames can run in one PyBoy tick.
- Native routines (bank 62 `rt/ff1_native.s`, trampolines in `rt/ff1_hle.s`, recompiler
  `ext` / idioms): DrawMapRowCol, DrawMapAttributes, CHR page copy, map RLE fill, OAM clear,
  battle swap b12:BF8F, far `vtile` (small-font tile upload; `<rom>.farsym` from insert.py,
  build.py FAR_EXT).
- DMG shading: coding key per tile (CODED; re-coding skipped when unchanged); map cells
  from the map drawer checked in spare time (FRESH bitmap, `fresh_scan`) after their
  attributes arrive (no more double re-coding per step; visible cells always right);
  re-coding by ANF masks in a block, one queue entry per tile (`retile_b`, `q_block`).
- Sprite conversion rewritten (camera offsets precomputed, counters in registers).
- Also native: menu screen clear (b14:9C0F), window rows (fix:E14D/E17F), battle panel row
  (fix:F4EA), battle nametable clear (fix:F2CF) via a bulk `ntfill`; LCD-on DMG map scan
  (`scan_b`/`scan_row`); DMG sprite slot loads and tile re-coding as 16-byte queue blocks;
  small-font tiles coded at once; a full VRAM queue is drained in STAT mode 0/1 instead
  of halting; LCD-off nametable writes take a short path in `rt_ppu_w7`.
- Test runners feed input exactly: ROM test mode (`TEST_PAD` $D83E = $A5, pads in cart RAM
  bank 3 by NMI count; `gbrun`/`sgbrun` set it); `gbrun` dumps NES RAM with each shot.
  PyBoy's CGB picture is not reliable (no double speed): check CGB visuals in mGBA.
- Measured (lagcheck, Gambatte, 2026-11-19): walking and battle keep pace on DMG and CGB
  (catch-up absorbs single heavy frames); new-game + battle script total lag DMG 323
  frames (+4.6%, was 853), CGB 99 (+1.4%), all of it in screen loads (DMG 25-70 frames
  per load, CGB 9-28). Remaining transition cost is spread: map loading code, map draw,
  LCD-on scan, re-coding, CHR uploads.

- **FF1's own bugs fixed (2026-11-19, `gb_layout.bug_fixes`, GB build only; Disch's FF1
  disassembly "BUGGED" notes, matched to the Japanese code):** run chance read the level
  through the battle-stat pointer (b12 A3EF), LOK2 never did anything (BA4E JMP -> BEQ),
  HARM used a player's class as enemy category (B618), weapon crit = weapon index (now the
  weapon's crit byte), weapon element / category never applied (stored in battle-stat bytes
  $03/$04, an HP copy nothing reads; attack setup A4E7/A4EE reads them), enemy group 3
  palette bit (b11 A37F). Far routine `wpnfix`. Checked on the NES build (battle stats per
  weapon). Not fixed (ambiguous or harmless): XFER / enemy weakness ROM vs RAM, CURE on the
  dead outside battle, BB armour absorb, stat-100 report, TMPR, multi-level-up.
- **Owner feedback 2026-11-19 (menus):**
  - Field magic / item target screen (b14 $B413): FF1's four boxes were outside the GB
    view and garbled in English (also in the plain English NES build); now the main menu's
    party window ($B859) at camera 0/0, hand beside the member, up/down.
  - Battle menus move by position: magic list (MAGMOVE / MAGLR: down slot 0 -> 2 -> next
    level, left/right between the row's two spells, pages turn by themselves); enemy target
    (far `etarget`: nearest living enemy in the pressed direction, up/down cycle the list
    when nothing is that way); command window (Run only beside Fight); party targets
    ignore left/right. Checked on the NES build (cursor RAM per press).
  - Field magic list: down/up step through the spells in list order (the GB lists them one
    per row), right/left jump a level (b14 $B707).
  - Positions shifting (owner: after a shop): FF1 leaves a shop without a screen clear, so
    the shop camera (1, 0) stayed; c62 $C170/$C911 now call the shop through `shopw` (c62
    $DD90, in the unused dakuten tables) which sets the field camera after. FORMATION
    (lineup b14 $9915): box 18 rows high, camera (7, 5) via `camlu`, centred. Checked
    walking, towns, castle, dialogue: the party stays centred.
  - GB checks (Gambatte CGB): Cure from the menu (target window, HP update), shop exit.
  - `tools/gb/checkall.py`: all RAM equivalence checks on DMG + CGB in parallel.
  - Centring (FIELD_CAM_X 5 since the release): title menu one column left; world map at
    camera X 6 while it shows (`mapw`); the c62 stubs (shopw / mapw / camlu) at $DD78.
- **Speed (2026-11-19):** DMG walking and talking in towns lagged up to 75%: the dialogue
  box's raster-split timing loop (c62:D6B8, $1B scanline delays every frame the box shows)
  is now its RAM effects only (`rt_dlgdelay`). CGB loads: the battle nametable clear in
  bulk on CGB too; with the LCD off, owner changes and attribute writes leave the cell
  palettes to one pass at LCD-on (`repal_b`, CGB_RP). Lag over the 7000-wait battle
  script (lagcheck, Gambatte): CGB 97 -> 65 frames (+0.9%, battle start +33 -> +4), DMG
  ~304 (+4.3%, screen loads: field entry +74, name/class screens +17-31). Known: DMG
  prologue band fade runs ~2-4 frames behind per 20 (attribute changes at half-band starts).
- Builder checked end to end on Linux (`ffe_builder.py --cli` with the Japanese ROM):
  split, English, GB layout, coverage (161 runs), recompile -> `Final Fantasy I (English,
  GB).gb`; its NES ROM is byte-identical to `build/ff1_gb.nes`.
- build.py: coverage from an older NES ROM (covall now keeps `rom.nes`) drops the logs
  of changed bytes and relies on static flow there. Fine for small NES changes; new code
  entered only dynamically (RTS dispatch) still needs fresh coverage (seen: boot hung with
  the old cov3 after the Select menu).
- **Owner's hardware test (EverDrive clone on a Game Boy Color, 2026-11-19), fixed:**
  - Lock-up talking to people: jump-table entries never reached in coverage were not
    compiled (99 of 128 talk routines, spells, tile effects, ExRAM text codes). Every entry
    of every static table is now compiled (`recomp.FF1.jump_tables`, `ex:` lines in .far);
    the dynamic-target table moved to bank 61 (buckets). Cart RAM 32 KB (4 banks) with a
    boot check (`rt/ramchk.s`: message if the cart does not bank its RAM).
  - Transitions white on the Color: loads keep the LCD on behind a black mask (VLCD; window
    with palette 7), VRAM writes in STAT mode 0/1, map / palettes rebuilt when shown.
  - Battle music rushing after FF1's own slow frames: APU writes queued per game frame,
    applied once per vblank (`apu.s` APQ).
  - Garbled tiles (letters, map): the native CHR upload's Color path fell into the sprite
    branch; and the tile DMA ran into drawing time (slow per-tile mark scan): `hdma_bg`
    rewritten (byte-wise scan, DMA only at LY 144-151, 12 tiles a line). SameBoy VRAM dumps
    (`GBRUN_VRAM`) match the tile copy at every checkpoint.
  - Intro text flash; name entry window border; dialogue box opened / closed like the NES:
    built in the GB window layer, revealed line by line from FF1's split line `$1B`
    (`dlg_cell`, `$5805`, `rt_dlgdelay`), map under it untouched (`dlgrest` reduced). A
    text of several pages opens the box at its first page break (FF1 prints page 1 before
    its reveal; `$5806` lines shown, `dlg_st` keeps it open through FF1's opening).
  - Checks after fresh coverage: 62 of 62 RAM checks identical (DMG + CGB); SameBoy VRAM =
    tile copy at every checkpoint; 2-page test dialogue (`GB_DLG_TEST`) checked by eye.
  - SameBoy libretro core (owner allowed) for hardware-like checks: `GBRUN_CORE=build/
    sameboy_libretro.so build/gbrun ...` (build notes in `docs/gb-lessons.md`).
  - Lag (Gambatte, battle script 7000 waits): CGB +1.3%, DMG ~+4.5% (screen loads).
  - Owner (2026-11-19, later): message box instant (cursor sound on open and each page, none
    on close); black-and-white patches after a message (box attributes outside the box
    coloured edge cells: other-view cells now stay out of the GB map); cursor sound buzz
    (the sound queue re-sent the swept period every frame). Then: battle speed-ups and
    slow-downs, sound channels, DMG fades / battle palette, names of 6 letters.
  - **Pacing as the NES (owner: no speed-ups):** frame waits end at the next vblank, no
    catch-up (the catch-up bursts were the battle speed-ups). Sound writes go straight to
    the GB again (the per-frame queue is gone). Honest lag now (lagcheck, battle 6000-7650,
    per 500 waits): CGB about +2-3%, DMG about +19% in battle. Speed work done: native
    small-font renderer (vstr/vchar with shift tables, vclear), panel-row skip of unchanged
    cells, native panel clear / battle-text copy / $90 swap (idioms), CGB emphasis colours
    computed (bank 0 space). Remaining: DMG battle frames (panel cells, text tiles, sprites).
  - Sound checked per voice (single-channel test builds, env GB_SND_MASK; NES reference
    rendered from the register writes): pitch and timing of both pulses and the triangle
    match the NES; the triangle was half as loud relative to the pulses: pulses now at 5/8.
  - Color tile DMA: the mark scan was slow enough that the DMA ran during drawing (garbled
    letters): byte-wise scan, DMA only at LY 144-151 (12 tiles a line).

- **Speed, 2026-11-19 (later)** (lagcheck, Gambatte; details in `docs/gb-lessons.md` Speed):
  frame wait takes the vblank count on entry (`VBL_ENT`); V flag dead at unknown edges (no
  `rt_adc_v`/`rt_sbc_v` calls left); batched DrawMapRowCol writer `mdf_row`/`mdf_col` (DMG +
  CGB bank-1 palettes; DMG cells marked in FRESH in bulk, as the per-tile path does); battle
  panel rows `nrf`; sprite conversion `oamconv_b` (bank 62, unrolled scan); box row idiom
  `hle_boxrow` (fix:F56A); small-font glyph rows unrolled, text tile coding in two passes;
  (zp),Y reads/writes inline; DMG BG pattern pages with the LCD off copied whole.
  `GB_MDF=0` builds the old per-tile paths: SameBoy VRAM identical to them on DMG and CGB
  (town walk, battle). A skip added early this session (unmarked tiles not checked) was
  reverted: every changed cell is checked again, as before.
  Results: town walk (420 waits) DMG lag 111 -> 34 frames, CGB 38 -> ~0; battle (1450 waits)
  DMG ~19% -> 3.4%, CGB ~0.1%; overworld walking keeps pace on both (remaining "lag" there is
  the NES's own 2/0-frame jitter). Still slow on DMG: screen loads (battle start ~50 frames,
  field entry ~66, intro/new-game screens 15-45: the LCD-on map scan and tile re-coding).
  Tools: sgbrun SGBRUN_PROFC (cycle sampling), SGBRUN_PROF_SP; lagcheck LAG_KEEP.

- **Speed, 2026-11-19 (late):** lag on the 7650-wait script: CGB 126 -> ~33 frames, DMG 263 -> ~200.
  Details, the WIP (`vshow_own`, disabled, buggy) and the remaining lag by screen:
  `docs/gb-handoff.md` "Speed work". checkall not re-run since the last coverage refresh.

## Remaining
- **Before any release (all ports): `docs/gb-release-checklist.md`** (Lot Check standards;
  tools: `tools/gb/lotcheck.py`, `tools/gb/termcheck.py`, sgbrun `SGBRUN_LOTCHECK=1`. FF3 passes
  every item (2026-11-20) but the GBA check; FF1 / FF2: soft reset, release build and the SRAM
  rule still fail - the SRAM rule needs the owner: a DMG has too little work RAM, options in the
  checklist).
- FF1 (owner's list, 2026-11-19): DMG screen loads (map scan + re-coding); DMG town walk
  (~8% left: step frames); DMG fades: a simple fade (owner) instead of the NES palette
  steps; names up to 6 letters; music voices vs the NSF (sndcmp.py); then the owner's
  play-test.
- FF2: separate session (`docs/ff2-gb-brief.md`). FF3 (GBC only): separate session, status in
  `docs/ff3-gb-status.md` (branch `claude/vibrant-davinci-lc8boi`). FF3 2026-11-20: battle
  re-layout built (`tools/gb3/layout.py`, `build.py --gb`; party column, full-width party and
  message windows, battle cameras in the runtime), RAM-identical to its NES layout ROM.
  Main menu re-laid out (owner's mock N5B; GB menu mode $5808: window layer + SCY steps),
  RAM-identical; Status / Equip / Item / Magic / Job / Save re-laid out (owner's mocks); field
  vertical wrap fixed; Color-only screen added; Lot Check items done (work RAM in Color WRAM,
  cart RAM only around save accesses, soft reset, save check screen, `--release` build).
  Native code in place of the NES layer (owner, 2026-11-20): plan `docs/ff3-native-plan.md`
  (OAM clear done; next native text / windows with the condensed names, music driver, map,
  sprites). Then load menu, prophecy, name entry, shops.
  2026-11-21: prophecy, name entry, title menu, shops, opening credits, ending pages and end
  credits laid out; native sound output; condensed names in menus and shops; GB map lock
  ($580D); Lot Check re-run on the final code (all pass in emulators); release ROM built
  locally and sent to the owner. Owner's hardware test (2026-11-21): chest message (one-row mode,
  18 columns), menus shown complete (picture held while FF3 builds a screen), crystal staff
  credits fixed; native water animation (no NES PPU I/O; fixes the blank water). Open: battle
  lists not condensed, the rest of the native-layer worklist (sprite page, field map / text
  writers), prophecy +3% lag, real-hardware retest.
  2026-11-22: owner: "continue native translation of FF3 until 100% native code is achieved"
  (FF1's approach: a hand-written native engine, data only from the ROM). **FF3 native engine:
  `tools/gb3n`, plan and progress `docs/ff3-native.md`.** Done so far (2026-11-22): all maps and
  world maps from the ROM, walking / passability, triggers (exits, entrances, doors, chests,
  locked doors, trigger events), masked map loads (no white frames), NPCs (movement, switches,
  graphics), dialogue re-paginated for the GB box (owner's request), the event script
  interpreter (talking, NPC scripts, switches, items, gil; the opening plays up to its battle),
  field menus as the owner's mocks: main menu (N6), Item, Magic, Equip (FF3's equipment
  recalculation ported, matching FF3's values), Status, Order, Job (J1, job change with FF3's
  level replay), Save (V1, FF3's file format), the Select menu (Options / Suspend) and B + Select;
  menus open in one frame with no white flash and leave the field's palettes untouched. Menu code
  in its own ROM bank (CODE1) through a far call. Boot screens: suspend resume, prophecy, load
  menu, name entry; Color-only screen and soft reset. Sound: FF3's own driver written for the GB
  (`src/snd.s`), its state identical to the owner's NSF for all 63 songs (`tools/gb3n/sndcmp.py
  state`), each voice's notes and lengths matching the NSF's audio (`sndcmp.py voices`); map /
  world / event / title songs hooked; the NES pulse sweep emulated. Shops (buy 1 / 4 / 10, sell)
  and inns as FF3, GB layout with condensed long item names (2026-11-23). Battle (2026-11-23):
  FF3's battle logic ported (init, AI, target cursor, attack order, Fight, all magic effects,
  action script, poison, victory / level ups, save back); whole battles match the NES
  (`tools/gb3n/btlcmp.py --end`: save block identical); Item / Magic / job commands, bosses, back
  attacks, the battle's end done. Vehicles done (`src/veh.s`: canoe, ship, airships, landing, the
  Invincible's sprite and jump, the Nautilus diving, the floating continent's edge), the fat chocobo,
  chest battles. Cutscenes done (`src/cut.s`, `cut.py`: crystal prologue, epilogue, ending + end
  credits, FF3's timing). Field effects, the guest NPC, people's moves and the special animations
  ($EF, `src/anim.s`) done, with FF3's world map objects. Battle animations (2026-11-23): attacks with
  every weapon type (parity-checked), magic casting / flight / hit frames through an 8 x 16 sprite
  mode (the GB's 40 sprites; `src/btlfx.s`), special spells, job commands, monster flash / death wipe /
  split / toad, walk-in, summons (framework + 19 of 24 attacks, all of FF3's random calls), cannon.
  Next: the 5 visual-only summon attacks, then the
  parity / Lot Check pass on the native build. Also fixed in the
  recompiled build: one-row menu cursors (Item opened Magic), the battle "Miss" sprite in English.
