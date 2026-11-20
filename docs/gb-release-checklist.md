# Game Boy ports: required checks before any release (owner, 2026-11-20, binding)

**Every item below must pass before a release of FF1, FF2 or FF3 for the Game Boy** (local
builds included: a "release" is any build handed to the owner as finished). The bar is
Nintendo of America's Lot Check as documented in Nintendo's *Game Boy Programming Manual*
(v1.1) and the Pan Docs cartridge-header specification. Work through this file at the end of
each port, record the result of every item (pass / fail / how checked) in the port's status
doc, and fix every failure first.

The owner's requirement text (summarised item by item; nothing left out):

## 1. ROM header and boot integrity ($0100-$014F)
Checked with automated tools (as Nintendo's KENSA / Lot Check suites did):
- [ ] **Nintendo logo** $0104-$0133: the exact 48-byte logo (the boot ROM compares it byte for
      byte; a mismatch locks the CPU).
- [ ] **Header checksum** $014D (complement sum over $0134-$014C) and **global checksum**
      $014E-$014F (16-bit sum of the whole ROM) match the binary exactly.
- [ ] **Hardware / memory flags** match the real cartridge: cartridge type $0147 (MBC5 +
      RAM + battery), ROM size $0148, RAM size $0149, CGB flag $0143 (FF1 / FF2 $80, FF3 $C0),
      SGB flag $0146 (FF1 / FF2 $03, FF3 $00).
- [ ] **Unused ROM space** padded consistently ($FF), no leftover garbage.

## 2. Hardware and electrical safety
- [ ] **LCD off only in V-Blank**: LCDC bit 7 is never cleared outside V-Blank (doing so can
      burn a line into the screen and damage it).
- [ ] **VRAM ($8000-$9FFF) and OAM ($FE00-$FE9F) written only in H-Blank / V-Blank or with
      the LCD off** (never in mode 3; on mode 2 for OAM). Includes every HDMA / GDMA.
- [ ] **Battery SRAM protection**: cart RAM ($A000-$BFFF) enabled only around each access
      and disabled again ($00 to $0000-$1FFF) right after, so power-off cannot corrupt saves.
- [ ] **Save validation at start-up**: save data checked by checksum / magic header; corrupt
      data is never silently overwritten or reverted: an on-screen message tells the player
      before the memory is initialised.

## 3. Software stability and system state
- [ ] **Soft reset**: A + B + Start + Select reinitialises the game cleanly (no stuck sound
      registers, no SRAM write cut in half).
- [ ] **No assumed memory contents**: all WRAM, HRAM, the used SRAM work areas and the
      hardware registers are explicitly initialised at boot (cold-boot RAM is random).
- [ ] **Cross-hardware**:
      - Dual-mode FF1 / FF2 ($0143 = $80): no graphical glitches, speed differences or
        soft-locks on DMG, Game Boy Pocket, Super Game Boy, Game Boy Color and Game Boy
        Advance.
      - Color-only FF3 ($0143 = $C0): on an older monochrome system a dedicated screen tells
        the player the game works only on Game Boy Color.
      - On Game Boy Advance hardware (GB / GBC mode): runs as on a Game Boy Color. (GBA sleep
        mode and Game Link Cable disconnection rules apply to GBA software / link play: the
        ports use neither; record them as not applicable.)

## 4. Terminology, legal and UI
- [ ] **Exact hardware names** in all in-game text and any manual: "Game Boy™", "Game Boy
      Color™", "Game Boy Advance™", "Game Link™ Cable", "Control Pad" (not "D-pad" /
      "directional pad"), "Game Pak" (not "cartridge").
- [ ] **CGB colour used meaningfully** (not a single tint over the monochrome picture).
- [ ] **No undisclosed code**: no debug menus, cheat codes, sound tests or hidden routines in
      the release binary unless documented in the release notes; anything found and not
      documented fails.

## Tools (2026-11-20)
- `tools/gb/lotcheck.py ROM --game ff1|ff2|ff3 [--release]`: section 1 from the file alone (logo,
  both checksums, cartridge / ROM / RAM / CGB / SGB flags, licensee, entry point, $FF padding of
  unused banks) and, with `--release`, no test hook (the test-pad read, test / trap symbols).
- `tools/gb/termcheck.py [game]`: section 4 terminology in the text sources, after the GB
  build's own substitutions (`GB_SUBST`, `GB_REPLACED`).
- `build/sgbrun` (tools/gb/mgba/sgbrun.c) env `SGBRUN_LOTCHECK=1`: section 2 at run time; every
  instruction decoded before it runs: LCD off outside the vblank, VRAM writes in mode 3, OAM
  writes in modes 2 / 3, OAM DMA and general-purpose HDMA outside the vblank, cart RAM on at a
  frame end, cart RAM accessed while off (counts + the first cases with PC / LY / mode).
  `SGBRUN_SVBK=LO-HI` (FF3): translated code running with a WRAM bank other than 1;
  `SGBRUN_WWATCH=ADDR:BANK`: writes to a WRAM address. `GB_CNT=CD80` / `GB_PRG=ff3` for FF3.
  `tools/gb3/lagcheck.py` passes these through (prints the `lotcheck:` line). `--agb`: the
  Game Boy Advance model (a GBA running a Color game).
- Release builds: `tools/gb3/build.py --gb --release` (FF3): the test-pad input mode and the
  fault / `rst $38` records are left out (`;@test{ .. ;@test}` blocks in the runtime), faults
  restart the game instead (`;@rel` lines), cart RAM 8 KB in the header; refuses to build with a
  test switch (`GB3_TEST_MINI`, `FF3_TEST_GOBLIN`) set.

## Known state (2026-11-20; to be re-checked item by item before release)
| Item | FF1 | FF2 | FF3 |
|---|---|---|---|
| Logo, checksums, flags, $FF padding | to run `lotcheck.py --game ff1` on the release build | verify | **pass** (`lotcheck.py --game ff3 --release`: 13 / 13 on `build/ff3_gb_release.gbc`) |
| LCD off only in V-Blank | loads keep the LCD on behind a mask (VLCD); run `SGBRUN_LOTCHECK` | verify | **pass**: LCD off only at power-on / soft reset after waiting for LY >= 144 (`runtime.s` boot, `dmg_msg`, `save_check`); `SGBRUN_LOTCHECK` over the explore script (2000-12000, 86 M instructions), the save, menu screens: 0 |
| VRAM / OAM timing | DMA only at LY 144-151; run `SGBRUN_LOTCHECK` (DMG / SGB / CGB) | verify | **pass** (same runs: 0 VRAM writes in mode 3, 0 OAM writes in modes 2 / 3, 0 OAM DMA / GDMA outside the vblank) |
| SRAM enabled only around access | **fails**: cart RAM stays enabled (NES PRG-RAM and the runtime's shadows live in it; DMG has 8 KB WRAM: see the FF1 note below) | likely same | **pass**: the NES work RAM moved to Color WRAM (game state $6000-$63FF at $C800, work area $7000-$7FFF in WRAM bank 1); only the save slots ($6400-$6FFF) and the save count ($7F38-$7F3A) stay in cart RAM, reached through `sram_rd` / `sram_wr`, which switch it on for the one byte and off again; `SGBRUN_LOTCHECK`: 0 frames ending with cart RAM on, 0 accesses while off |
| Save validation + message | verify the game's own checks; add the message | verify | **pass**: boot `save_check` (`build.py`): each slot marked used ($5A) must pass FF3's own sum test; damaged slots are listed on a screen ("Save data error / File n is damaged. / Damaged save files will be erased. / Press the A Button."), cleared only after the A Button (checked in mGBA and PyBoy with a crafted save: damaged slot cleared, valid slot kept) |
| Soft reset A+B+Start+Select | **missing** | **missing** | **pass**: polled in the vblank interrupt (`runtime.s`), held off for 30 frames after any save-RAM write; sound and cart RAM off, then the boot path (memory and registers set up again; checked in mGBA in the prologue and on the name screen) |
| Memory / registers cleared at boot | verify (`memclr` covers WRAM?) | verify | **pass**: VRAM banks 0 / 1, WRAM $C000-$CEFF and banks 1-7, OAM, HRAM cleared; sound off, cart RAM off, SCX / SCY / WX / WY / STAT / LYC / VBK set; the game's PRG-RAM areas start from zero (the NES game initialises what it reads, apart from tiles read back from the PPU: see FF3 status) |
| Cross-hardware | DMG / SGB / CGB tested in emulators; owner's GBC hardware test; GBA, Pocket untested | verify | CGB in mGBA / PyBoy / Gambatte; Game Boy Advance as mGBA's AGB model (`sgbrun --agb`): the same run as on the Color (same frame and instruction counts over 3200 frames, no `SGBRUN_LOTCHECK` violation), colours darker as on a GBA screen (optional later: brighter palettes when boot register B bit 0 says GBA); real GBA hardware untested |
| Color-only warning screen | n/a | n/a | **pass**: "This Game Pak is designed only for use with the Game Boy Color(TM) system." (TM glyph added), LCD off in V-Blank, then halt; seen in PyBoy DMG, mGBA DMG and SGB |
| Hardware names in text | **pass** in the GB build after `enc()` writes "A Button" / "B Button" (`termcheck.py ff1`) | **fails**: "RESET" in the save message (`termcheck.py ff2`) | **pass** (`termcheck.py ff3`: "A Button" / "B Button" in the GB dialogue, the NES "Hold RESET" message replaced by "You can turn the power off now.") |
| CGB colour use | NES palettes per tile | verify | NES palettes per tile |
| Undisclosed code | test hooks in the binary: `TEST_PAD` mode ($D83E = $A5), `rst $38` trap / `DBG` record; needs a `--release` build as FF3's | same | **pass** with `--release` (no test-pad mode, no trap records; an internal fault restarts the game: to be listed in the release notes) |

FF1 / FF2 SRAM (open, blocking): a plain Game Boy has 8 KB of work RAM; the NES game needs its
2 KB RAM plus about 7 KB of PRG-RAM work areas ($6000-$63FF, $6800-$6FFF battle, $7000-$7FFF
maps) plus the runtime's own state and shadows. FF3's fix (work RAM in Color WRAM banks) works in
the CGB mode only. Options for the dual-mode carts: (a) per-access enable / disable in the
recompiled code (cost on every PRG-RAM access: against the 0%-slowdown rule on DMG); (b) work
areas in cart RAM banks 1-3 and the save copy in bank 0, selected only inside the save code
(protects the save in practice, but cart RAM stays enabled: not the letter of the rule);
(c) CGB-only carts (the FF3 design; replaces the owner's dual-mode decision). Needs the owner.

FF1 / FF2 next steps (sessions with those ROMs; the FF3 session had only the FF3 ROM, so the
FF1 / FF2 runtimes were not changed blind): port FF3's soft reset (vblank poll + `sram_busy`),
boot clears / LCD-off wait, `;@test` / `;@rel` release blocks and `build.py --release`; run
`lotcheck.py --game ff1|ff2 --release`, `termcheck.py`, and `SGBRUN_LOTCHECK=1` in DMG, SGB,
CGB and `--agb` modes (FF1's counters: default `GB_CNT`); settle the SRAM option with the owner.

Notes for the fixes:
- SRAM: keep the NES work RAM ($6000-$7FFF) in GB WRAM / a RAM area that is not battery-backed
  and touch the battery-backed save area only inside the game's save / load routines (enable,
  copy, disable), or prove each port's PRG-RAM accesses can be bracketed by enable / disable.
- Soft reset: checked in the runtime's joypad read; it must wait for any save write in
  progress to finish, silence the sound registers, and restart through the boot path.
- FF3 on a monochrome system: a static screen (no game graphics) with the message, drawn by
  the runtime before anything else.
