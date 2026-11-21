# Game Boy release requirements (Lot Check standards) — required before any release

Owner's decision (2026-11-20): every Game Boy build of FF1, FF2 and FF3 must meet the
standards below before it counts as released. They follow Nintendo of America's Lot Check
for Game Boy (DMG), Game Boy Color (CGB) and Game Boy Advance titles (Game Boy Programming
Manual, GBA Programming Guidelines; register-level details: Pan Docs, "The Cartridge
Header", and the archived official Game Boy Programming Manual v1.1). Nothing here
changes the rule that nothing is distributed: these are the conditions for calling a local
build a release.

## 1. ROM header and boot integrity ($0100-$014F on GB / GBC)

- Nintendo logo bitmap ($0104-$0133): the exact 48-byte logo. The boot ROM compares it
  byte for byte and locks up on a mismatch.
- Header checksum ($014D, complement checksum over $0134-$014C) and global checksum
  ($014E-$014F, 16-bit sum of the ROM) must match the binary exactly.
- Hardware and memory flags must match the cartridge: cartridge type ($0147: MBC1/2/3/5,
  RTC, rumble, RAM, battery), ROM size ($0148), RAM size ($0149), CGB flag ($0143), SGB
  flag ($0146).
- Unused ROM space padded consistently ($FF or $00), no leftover assembler garbage.

## 2. Hardware and electrical safety

- LCD off (LCDC bit 7 = 0) only during vertical blank. Turning the LCD off mid-frame can
  damage the screen (a burned horizontal line).
- VRAM ($8000-$9FFF) and OAM ($FE00-$FE9F) written only in H-Blank or V-Blank, or with the
  LCD off (switched off during V-Blank). Writes in mode 3 are lost and fail Lot Check.
- Battery-backed SRAM ($A000-$BFFF):
  - RAM access disabled (write $00 to $0000-$1FFF on MBC cartridges) right after every
    read / write, so that voltage drops at power-off cannot corrupt saves.
  - Save data validated at start-up (checksums or magic headers). Corrupt data is never
    silently overwritten or reset: an explicit on-screen message tells the player first,
    then the memory is initialised.

## 3. Software stability and system state

- Soft reset: A + B + Start + Select reinitialises the game cleanly, without stuck sound
  registers or a corrupted SRAM write in progress.
- Uninitialised memory: WRAM, HRAM and SRAM hold random values at power-on; all working
  memory and hardware registers are cleared / set explicitly at initialisation.
- Cross-hardware compatibility:
  - Dual-mode GB / CGB titles ($0143 = $80; FF1, FF2) run without graphical glitches, speed
    differences or soft locks on the original DMG, Game Boy Pocket, Super Game Boy, Game
    Boy Color and Game Boy Advance.
  - CGB-only titles ($0143 = $C0; FF3) show a dedicated error screen on older
    monochrome systems saying the game only works on Game Boy Color.
- (GBA titles: Sleep Mode interrupt without crashing; multiplayer titles survive a Game
  Link Cable being pulled within a few seconds. Not applicable to these GB / GBC builds
  unless link play is added.)

## 4. Terminology, legal and user interface

- Exact hardware names in all in-game text and documentation: "Game Boy™", "Game Boy
  Advance™", "Game Link™ Cable", "Control Pad" (not "D-pad" / "directional pad"), "Game
  Pak" (not "cartridge").
- CGB colour must be meaningfully used (palettes, not a single monochrome tint);
  pre-approval of the colour use was required.
- No undisclosed code: debug menus, cheat codes, sound tests and hidden routines left in
  the binary must be documented in the submission; undocumented code found during Lot
  Check meant rejection.

## Where the builds stand (2026-11-20)

Checker: `tools/gb2/lotcheck.py GB [--run NES FRAMES --random S] [--reset] [--release]`
(header, padding, LCD-off audit of the assembled source, debug-code report; PyBoy runs for
the LCD-off timing and the soft reset). It is written for FF2's runtime (labels `.lcdoff`,
`soft_reset`); FF1 / FF3 need the same runtime changes before it applies to them.

### FF2 (`tools/gb2`, build `python3 tools/gb2/build.py --gb --release` -> `build/ff2_release.gb`)

| Requirement | State | How it is met / checked |
|---|---|---|
| Logo, checksums, flags, sizes | met | `make_rom`; lotcheck: logo, $014D, $014E, CGB $80, SGB $03 + licensee $33, type $1B (MBC5 + RAM + battery), ROM 1 MB = $05, RAM 128 KB = $04 (suspend point in banks 4-12), entry point |
| Padding | met | assembler filler $FF everywhere (gaps and bank ends); lotcheck |
| LCD off only in V-Blank | met | three LCD-off writes, all labelled `.lcdoff`: boot (interrupts off, LY >= 144), `rt_ppu_w1` (wait for LY >= 144 with the V-Blank interrupt run first, then with interrupts off re-check LY 144-151 and write), SGB border transfer (boot). lotcheck: static audit (the other 5 LCDC writes keep bit 7 set) and PyBoy runs (30000 frames DMG and CGB: every LCD-off at LY 144-151) |
| VRAM / OAM only in H-Blank / V-Blank / LCD off | checked | writes with the LCD on go through the V-Blank queue / HDMA, OAM by DMA in the V-Blank. Checked by comparing PyBoy (no VRAM locking) with Gambatte (hardware locking) at 38 points of 30000 frames of random play, DMG and CGB: same screens (one sprite animation frame of timing difference) |
| SRAM disabled after every access | deviation (documented) | the NES work RAM $6000-$7FFF is cart RAM bank 0 and is read / written by the game every frame, and the runtime keeps DMG tile shadows (bank 1) and SGB packets (bank 2) in cart RAM, so RAM cannot be disabled between accesses. Moving NES work RAM to WRAM would need 8 KB of the 32 KB CGB WRAM that the runtime uses for tile copies (and all of a DMG's 8 KB WRAM): not possible on the DMG. Protection instead: the save slots are checked at start-up (next row), and a damaged one is reported |
| Save data validated at start-up, message before init | met | `rt/save.s`: FF2's own slot rule (fix:DAC1: 768 bytes sum to $FF, byte $2FE = $5A); the runtime records the slots the game has saved to (FF2's save copy b14:B27A runs natively and marks the slot) in a header in cart RAM bank 3 (`FF2S`, slots, check byte). At boot a marked slot that fails the rule shows "THE SAVE IN FILE n IS DAMAGED AND CANNOT BE LOADED. IT WILL BE ERASED. PRESS THE A BUTTON." (own font), and only after the A Button is it cleared. No header (first use, older ROM): valid slots are marked, nothing cleared. FF2 itself never initialises the slots. Checked in PyBoy, DMG and CGB (no header / valid / damaged / no A press) |
| Soft reset A + B + Start + Select | met | `read_buttons` -> `soft_reset`: sound off at once, then the boot path (`boot_w`); only from the joypad read, so never during a save copy. Save RAM (NES work RAM) is kept, as after a reset on the NES. lotcheck `--reset`: screen and NES RAM 400 waits after the reset = a fresh power-on (DMG, CGB); mGBA: SGB border kept, CGB double speed kept |
| Memory cleared at boot | met | `boot_w` / `boot_clr`: LCD off in V-Blank, sound off, interrupts and IF cleared, scroll / window / LYC / STAT / timer set, VRAM (CGB: both banks), WRAM (CGB: banks 1-7), OAM, HRAM, the runtime's cart RAM (banks 1, 2, bank 3 from $B000); not the save RAM (bank 0) or the save header |
| DMG / Pocket / SGB / CGB / GBA | checked in emulators; open: real hardware | DMG, SGB, CGB in PyBoy / Gambatte / mGBA; Pocket (mGBA model MGB: same picture as DMG, frame for frame) and GBA (mGBA model AGB: CGB mode, double speed) boot, play the opening and soft-reset correctly. Model runs: `sed 's/const char\* model = .*/const char* model = getenv("GB_MODEL") ? getenv("GB_MODEL") : (dmg == 2 ? "CGB" : dmg ? "DMG" : "SGB");/' tools/gb/mgba/sgbrun.c > build/modelrun.c && gcc -O2 build/modelrun.c -lmgba -o build/modelrun`, then `GB_MODEL=MGB build/modelrun ROM FRAMES OUT --dmg ...` (`AGB` with `--cgb`). The DMG / Pocket prologue fade glitch is fixed (2026-11-21, docs/ff2-gb-status.md). A Super Game Boy hang in the prologue (introduced by the boot memory clear exposing a register clobber in the SGB packet code) was found in mGBA and fixed. Open: real hardware |
| CGB-only error screen | not applicable | FF2 is dual-mode ($80) |
| Hardware names in text | met | the only hardware text, system string 42 "hold down the RESET button while you turn the power off" (Famicom), is "Save complete!" in the GB build; the save message says "A Button"; no other text names hardware |
| CGB colour used | met | NES palettes -> CGB palettes, per-tile attributes |
| No undisclosed code | met in `--release` | the test-runner pad input (TEST_PAD, `;[test]` blocks) is left out of release builds (lotcheck `--release`). Kept and disclosed here: the crash handlers `rt_fault` / `rst38_trap` (record the state in WRAM and stop if execution reaches uncompiled code or $FF filler; never reached in the checks) and the soft reset. `GB_END_TEST` (layout.py, ending test build) is refused by `--release` |

### FF1 (`tools/gb`) and FF3

FF1's runtime does not have these changes yet (boot clear, soft reset, LCD-off re-check,
save check, release build); they port from FF2's runtime (same design) once the owner
allows changes to the FF1 tools. FF3 (CGB only, $C0) needs the "Game Boy Color only"
screen on DMG / SGB; FF3 is not started.
