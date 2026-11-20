# Release requirements: Nintendo Lot Check standards (all GB ports)

**Owner's decision (2026-11-20): absolutely required before any release of FF1, FF2 or
FF3.** A release is not done until every item below is met and checked. The rules are the
ones Nintendo of America's Lot Check applied to Game Boy (DMG), Game Boy Color (CGB) and
Game Boy Advance (GBA) ROMs, as described in the Game Boy Programming Manual and the GBA
Programming Guidelines. Register-level detail: Pan Docs (cartridge header) and the archived
Game Boy Programming Manual v1.1.

GBA-only rules are listed for completeness. Our ROMs are GB/GBC, so they do not apply, but
the ROMs must still run correctly on a GBA (see 3.3).

Each item has a short **state** note. These record what we know today; they are not proof
of compliance. Every item still has to be verified before release.

## 1. ROM header and boot integrity ($0100-$014F)

1.1 **Nintendo logo** ($0104-$0133): the exact 48-byte logo bitmap. The boot ROM compares
it byte for byte and locks the CPU on a mismatch.
State: `asm_sm83.make_rom` writes `NINTENDO_LOGO`. Verify against Pan Docs.

1.2 **Checksums**: the header complement checksum at $014D (over $0134-$014C) and the
16-bit global checksum at $014E-$014F must match the binary exactly.
State: `make_rom` computes both. Since 2026-11-20 `build.check_header` recomputes them
independently on every build and fails the build on a mismatch. It also checks the logo (by
its SHA-1), the flags ($0143 $80, $0146 $03, $0147 $1B, $0149 $05) and the ROM size against
$0148.

1.3 **Hardware and memory flags** must match the real cartridge board:
- cartridge type $0147 (MBC1/2/3/5, RTC, Rumble);
- ROM size $0148;
- RAM size $0149;
- CGB flag $0143 and SGB flag $0146.

State, FF1:
- $0147 = $1B (MBC5+RAM+BATTERY).
- RAM code $05 (64 KB, 8 banks; since 2026-11-20: banks 0-3 runtime and NES work RAM,
  bank 4 the save, see 2.3).
- ROM size from the bank count (2 MB).
- SGB $03, CGB $80.
- Licensee: old code $33, new code "00".

FF3 must use CGB $C0. Check every flag against the board the ROM is meant for.

1.4 **Unused ROM space** is padded consistently ($FF or $00), with no leftover data.
State: `make_rom` fills the image with $FF and the assembler fills gaps between sections
with $FF, so all unused space is $FF. The title is padded with $00, as the header format
requires. The bank-ID bytes at $7FFE-$7FFF of the code/runtime banks are deliberate data
(4.3).

## 2. Hardware and electrical safety

2.1 **LCD off only in V-Blank**: never clear LCDC bit 7 outside V-Blank. Doing so mid-frame
can cause a burn line and can damage the screen.

State: audited 2026-11-20. Every write that clears LCDC bit 7 waits for LY 144-153 first:
- boot;
- `rt_ppu_w1`: SGB, or DMG already in V-Blank;
- `dmg_loff`: the deferred DMG switch-off in the vblank handler;
- the SGB border transfer;
- the save error screen.

CGB masked loads keep the LCD on. All other LCDC writes change only window/sprite bits with
the LCD on.

2.2 **VRAM / OAM access windows**: write VRAM ($8000-$9FFF) and OAM ($FE00-$FE9F) only in
H-Blank or V-Blank, or with the LCD off (switched off in V-Blank). Never write during mode 3.

State:
- The VRAM queue is flushed at LY 144-152; a full queue is drained in STAT mode 0/1.
- CGB HDMA runs at LY 144-151.
- OAM is written by DMA in vblank.

Checker: `build/sgbrun` (rebuild after pulling) with env `SGBRUN_VCHK=1` wraps mGBA's CPU store function and counts
every CPU write to VRAM in mode 3, or to OAM in mode 2/3, with the LCD on. Results
(2026-11-20) over the whole 7650-wait battle script (new game, field, battle): 0 on DMG,
0 on CGB, 0 on SGB (8711 waits).

The same over 13 field / menu / shop scripts (covall.FIELD: dialogue, menu, items, magic,
equip, status, shop_buy, shop_inn, minimap, puzzle, cure, lineup, bridge; input files from
lagcheck, `tools/gb/vchkfield.py`): 0 on DMG, CGB and SGB.

Not covered: SameBoy (its libretro core has no write hook). mGBA's PPU mode timing is close
to hardware but not exact, so writes right at a mode boundary could still differ on real
hardware.

2.3 **Battery-backed save RAM protection**:
- Disable cart RAM (write $00 to $0000-$1FFF on MBC carts) right after every read/write, so
  a voltage drop at power-off cannot corrupt the save.
- On start-up, validate the save data (checksum or magic header). Corrupt data must never be
  silently overwritten or reverted: show an explicit on-screen error message before the
  memory is initialised.

State (2026-11-20): partly met, by design.

Done (`rt/lot.s`):
- The committed save lives in its own cart RAM bank (bank 4). It has a 16-bit sum, the sum's
  complement and a magic, written last. The bank is mapped only while the boot checks or
  loads it, and while `save_commit` copies FF1's new save into it right after FF1's own
  save routine (b14:ABCE). The copy goes 32 bytes at a time with interrupts off.
- At boot: a sealed copy whose sum matches is loaded. A damaged one shows "SAVE DATA ERROR
  ... PRESS THE A BUTTON TO ERASE IT." and is erased only after the A Button. With no copy
  yet, a save FF1 left in bank 0 is taken over.
- On a Game Pak with only 32 KB (no separate bank 4) the save stays in bank 0, as before.

Tested in PyBoy: taking over an old save, loading a good one, the damaged case (message
shown, nothing erased before the A Button), and an inn save copied with a valid sum (RAM
still identical to the NES).

Not met, and cannot be on DMG: switching cart RAM off after every access. The runtime
enables cart RAM once at boot (`runtime.s`, `ld a, $0A / ld [$0000], a`) and leaves it on.
Two layouts depend on that:
- bank 0 holds the NES save/work RAM ($6000-$7FFF), which the recompiled game reads and
  writes all the time;
- banks 1-3 hold runtime shadows: BG/sprite tile shadows, OAM conversion state, buffers.

The DMG has only 8 KB of WRAM, so this data cannot move out of cart RAM. The protection is
therefore the separate save bank: a stray write at power-off lands in the bank that is
mapped (normally bank 0), never in the save's bank.

FF2/FF3: design the save the same way from the start.

## 3. Software stability and system state

3.1 **Soft reset**: A + B + Start + Select resets the game cleanly. No sound registers left
stuck, and no save RAM write in progress gets corrupted.

State: done (2026-11-20, `read_buttons` -> `soft_reset` in `rt/lot.s`). It turns interrupts
off, switches sound off (NR52 = 0 clears every sound register), selects cart RAM bank 0 and
switches RAM off, waits until the four buttons are no longer all held, then runs the boot
code again. Boot switches the LCD off only in V-Blank, and skips that wait when the LCD is
already off. On a Color, boot no longer toggles double speed when it is already on. Reset is
never reached during a save copy, because no joypad read happens there.

Tested in PyBoy (DMG, CGB) and in mGBA (DMG, SGB, CGB, AGB with double speed): the frame
counter starts over and the game runs on. Real hardware is still to test.

3.2 **Uninitialised memory**: WRAM, HRAM and save RAM hold random values at cold boot.
Initialisation must clear all working memory and set all hardware registers explicitly.

State (2026-11-20):
- Boot already cleared VRAM, WRAM (not the stack page), OAM and HRAM, so random WRAM cannot
  switch on the test-runner mode (`TEST_PAD` is cleared). Release builds also leave that
  mode out (4.3).
- Boot now also clears the runtime's cart RAM banks 1-3 (`save_boot`).
- Bank 0 (NES $6000-$7FFF) is battery-backed on the NES as well, and FF1 manages it itself,
  so it is left alone.

Clearing bank 2 exposed a real bug: the SGB packet compare (`pk_diff`) overwrote the caller's
loop counter, so the loop's length depended on leftover bank-2 bytes. With bank 2 cleared,
the SGB game slowed to a crawl at the class select. Fixed (pk_diff keeps DE). The zero-count
cases of the attribute packet loops are guarded too.

3.3 **Cross-hardware compatibility**:
- Dual-mode titles (FF1, FF2: $0143 = $80) must run with no graphical glitches, speed
  differences or soft-locks on all of: DMG, Game Boy Pocket, Super Game Boy, Game Boy Color
  and GBA.
- CGB-only titles (FF3: $0143 = $C0) must show a dedicated screen on older monochrome
  systems, saying the game only works on Game Boy Color.

Test matrix before release: SameBoy and Gambatte (DMG, CGB) plus mGBA (SGB, CGB, GBA mode);
real hardware where the owner can.

State (2026-11-20, `sgbrun --model MGB|SGB2|AGB`): the battle script ran to frame wait 7300
on Game Boy Pocket (MGB), SGB2 and Game Boy Advance (AGB: Color mode, double speed), with no
VRAM/OAM violations and correct pictures (field, battle). DMG, CGB and SGB are covered by
the regular checks. On a GBA, Color games show darker; FF1 does not brighten its palettes on
a GBA (possible later). Soft reset was tested on DMG, SGB, CGB and AGB in mGBA: the frame
counter starts over, and double speed stays on, on CGB/AGB.

3.4 (GBA only) Sleep Mode and Game Link Cable disconnect handling: not applicable to our GB
ROMs.

## 4. Terminology, legal and UI standards

4.1 **Exact hardware names** in all in-game text and manuals: "Game Boy", "Game Boy
Advance", "Game Link Cable", "Control Pad" (not "D-pad" or "directional pad"), "Game Pak"
(not "cartridge").
State: the boot RAM-check screen now says "GAME PAK RAM ERROR" / "THIS GAME PAK DOES NOT
BANK ITS RAM." (2026-11-20), and the save error says "PRESS THE A BUTTON". The game's own
text is FF1's translation and names no hardware. Still to check: the builder's messages.

4.2 **CGB colour use**: Game Boy Color modes must use colour meaningfully, not a single
monochrome tint.
State: FF1 CGB mode uses the NES palettes (`cgb_palettes`, per-tile attributes). Keep it that
way for FF2/FF3.

4.3 **No undisclosed code**: any debug menu, cheat code, sound test or hidden routine left in
the final binary must be fully documented. Undocumented code means automatic rejection.

Known items in the FF1 ROM, and how each is handled:
- **Test-runner pad mode** (`TEST_PAD` = $A5: pads read from cart RAM bank 3): left out of
  release builds (`build.py --release`; the builder passes it).
- **`rst $38` trap** (`rst38_trap`): if execution runs into $FF bytes it records the stack at
  `DBG` ($D820) and stops. This is a crash handler, documented here; it is never reached in
  normal play.
- **Bank-ID bytes** ($A5, bank number) at $7FFE of every code/runtime bank: data, read by
  `bg_mat` to come back to the mapped bank.
- **`GB_DLG_TEST` / `GB_SND_MASK` / `GB_MDF` / `GB_MUS` / `GB_MAPPRE` / `GB_DYNB` /
  `GB_CLONE`**: build-time options for tests and comparisons. Release builds use the
  defaults; `GB_DLG_TEST` and `GB_SND_MASK` must not be set.
- **Soft reset and the save error screen**: documented in 3.1 and 2.3.

## Release gate

Before any release, record in `CLAUDE.md` / `docs/gb-handoff.md` that each item above was
checked: what was done, how it was tested, and the result.
