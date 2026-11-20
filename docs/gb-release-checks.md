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
State: `make_rom` computes both. Add an independent check of the final ROM in the build.

1.3 **Hardware and memory flags** must match the real cartridge board:
- cartridge type $0147 (MBC1/2/3/5, RTC, Rumble);
- ROM size $0148;
- RAM size $0149;
- CGB flag $0143 and SGB flag $0146.

State, FF1:
- $0147 = $1B (MBC5+RAM+BATTERY).
- RAM code $03 (32 KB, 4 banks).
- ROM size from the bank count (2 MB).
- SGB $03, CGB $80.
- Licensee: old code $33, new code "00".

FF3 must use CGB $C0. Check every flag against the board the ROM is meant for.

1.4 **Unused ROM space** is padded consistently ($FF or $00), with no leftover data.
State: `make_rom` fills the image with $FF before the banks go in. Two things need checking:
- the tail of each partly used bank;
- the bank-ID bytes at $7FFE-$7FFF of the code/runtime banks. These are deliberate and must
  be documented (4.3).

## 2. Hardware and electrical safety

2.1 **LCD off only in V-Blank**: never clear LCDC bit 7 outside V-Blank. Doing so mid-frame
can cause a burn line and can damage the screen.

State:
- DMG deferred switch-off turns the LCD off in the vblank handler (`dmg_loff`).
- SGB waits for vblank in `rt_ppu_w1`.
- CGB masked loads keep the LCD on.

Still to audit: every write to LCDC in the runtime (boot, RAM-check screen, SGB border VRAM
transfer, test paths).

2.2 **VRAM / OAM access windows**: write VRAM ($8000-$9FFF) and OAM ($FE00-$FE9F) only in
H-Blank or V-Blank, or with the LCD off (switched off in V-Blank). Never write during mode 3.

State:
- The VRAM queue is flushed at LY 144-152; a full queue is drained in STAT mode 0/1.
- CGB HDMA runs at LY 144-151.
- OAM is written by DMA in vblank.

To do: audit every direct VRAM/OAM write, then run the game under an emulator that reports
inaccessible VRAM/OAM writes (e.g. a debugger with access breakpoints) through all
checkall/lagcheck scripts on DMG and CGB, with zero reports.

2.3 **Battery-backed save RAM protection**:
- Disable cart RAM (write $00 to $0000-$1FFF on MBC carts) right after every read/write, so
  a voltage drop at power-off cannot corrupt the save.
- On start-up, validate the save data (checksum or magic header). Corrupt data must never be
  silently overwritten or reverted: show an explicit on-screen error message before the
  memory is initialised.

State: not met. The runtime enables cart RAM once at boot (`runtime.s`, `ld a, $0A /
ld [$0000], a`) and leaves it on. Two layouts depend on that:
- bank 0 holds the NES save/work RAM ($6000-$7FFF), which the recompiled game reads and
  writes all the time;
- banks 1-3 hold runtime shadows: BG/sprite tile shadows, OAM conversion state, buffers.

Meeting this rule needs a design change. Options:
- move the working areas that are not save data out of cart RAM;
- keep the save data in a separate area that is enabled only around FF1's own save/load.

The same applies to FF2/FF3. FF1's own save checksum check falls back to "no save"
silently; the GB build must add the error message.

## 3. Software stability and system state

3.1 **Soft reset**: A + B + Start + Select resets the game cleanly. No sound registers left
stuck, and no save RAM write in progress gets corrupted.
State: not implemented.

3.2 **Uninitialised memory**: WRAM, HRAM and save RAM hold random values at cold boot.
Initialisation must clear all working memory and set all hardware registers explicitly.

State: to audit. One concrete risk: the test-runner input mode is switched on by the value
$A5 at `TEST_PAD` ($D83E). Random WRAM at power-on could switch it on by chance. Clear it at
boot, or remove the mode from release builds.

3.3 **Cross-hardware compatibility**:
- Dual-mode titles (FF1, FF2: $0143 = $80) must run with no graphical glitches, speed
  differences or soft-locks on all of: DMG, Game Boy Pocket, Super Game Boy, Game Boy Color
  and GBA.
- CGB-only titles (FF3: $0143 = $C0) must show a dedicated screen on older monochrome
  systems, saying the game only works on Game Boy Color.

Test matrix before release: SameBoy and Gambatte (DMG, CGB) plus mGBA (SGB, CGB, GBA mode);
real hardware where the owner can.

3.4 (GBA only) Sleep Mode and Game Link Cable disconnect handling: not applicable to our GB
ROMs.

## 4. Terminology, legal and UI standards

4.1 **Exact hardware names** in all in-game text and manuals: "Game Boy", "Game Boy
Advance", "Game Link Cable", "Control Pad" (not "D-pad" or "directional pad"), "Game Pak"
(not "cartridge").
State: the boot RAM-check screen (`build.ramchk_src`) says "CARTRIDGE RAM ERROR" and
"THIS CART ..." and must say "Game Pak". Check all other runtime/builder text the player can
see.

4.2 **CGB colour use**: Game Boy Color modes must use colour meaningfully, not a single
monochrome tint.
State: FF1 CGB mode uses the NES palettes (`cgb_palettes`, per-tile attributes). Keep it that
way for FF2/FF3.

4.3 **No undisclosed code**: any debug menu, cheat code, sound test or hidden routine left in
the final binary must be fully documented. Undocumented code means automatic rejection.

Known items in the FF1 ROM to remove from release builds or document:
- the test-runner pad mode (`TEST_PAD`, pads read from cart RAM bank 3);
- the `rst $38` trap (`rst38_trap`) and its fault dump at `DBG`;
- the bank-ID bytes at $7FFE;
- the `GB_DLG_TEST` / `GB_SND_MASK` build options (must be off).

## Release gate

Before any release, record in `CLAUDE.md` / `docs/gb-handoff.md` that each item above was
checked: what was done, how it was tested, and the result.
