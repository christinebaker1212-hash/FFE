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

## Where the current builds stand (notes to check, 2026-11-20; not yet verified)

Points known from the code that need work or an audit before a release:

- Header: `tools/gb/asm_sm83.py` `make_rom` writes the header and both checksums; verify
  the logo, the checksums, $0147-$0149 against the cartridge (MBC5 + RAM + battery; FF2
  uses 4 cart RAM banks = 32 KB) and the padding of unused space in each built ROM. Test
  copies made by `tools/gb2/ff2form.py` zero the global checksum: never a release ROM.
- LCD off: the runtimes wait for LY >= 144 before clearing LCDC bit 7 (`rt_ppu_w1`); every
  other LCD-off site (boot, SGB border transfer, test code) needs the same audit.
- VRAM / OAM: writes with the LCD on go through the VRAM queue (flushed in V-Blank;
  `q_drain1` waits for H-Blank / V-Blank), OAM by DMA in V-Blank; every native routine that
  writes VRAM directly must be checked to do so only with the LCD off. PyBoy does not
  model VRAM locking: check in Gambatte / mGBA.
- SRAM: the runtimes keep cart RAM enabled at all times, because the NES work RAM at
  $6000-$7FFF is mapped to cart RAM bank 0 (and bank 1 holds the DMG tile shadows, bank 3
  the FF2 test-runner pads and the DMG scan's table). The "disable RAM after every access"
  rule needs a design decision with the owner (e.g. NES work RAM in WRAM where it fits,
  battery-backed RAM only for the save slots, enabled only while saving / loading).
- Saves: the games' own save checksums (FF2 fix:DAD4) detect corrupt slots; a corrupt
  slot must produce an explicit message before anything is initialised.
- Soft reset (A + B + Start + Select): not implemented in the GB runtimes yet.
- Memory clear at boot: the runtimes clear memory at boot (`memclr`); verify WRAM, HRAM,
  SRAM handling and all hardware registers.
- Hardware coverage: tested so far in PyBoy, Gambatte and mGBA (DMG, SGB, CGB); still
  needed: Game Boy Pocket, GBA, and real hardware where possible.
- FF3 (CGB only, $C0): the "Game Boy Color only" error screen on DMG / SGB.
- Terminology: check every translated string (and any builder / manual text) for the exact
  hardware names.
- Undisclosed code: test-only paths in the runtimes (FF2 `TEST_PAD` $A5 test-runner pad
  input, the `rst $38` debug trap, `GB_END_TEST` / `GB_DLG_TEST` test builds, debug hooks)
  must be removed from release builds or documented.
