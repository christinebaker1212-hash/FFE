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

## Known state (2026-11-20; to be re-checked item by item before release)
| Item | FF1 | FF2 | FF3 |
|---|---|---|---|
| Logo, checksums, $FF padding | `make_rom` (tools/gb/asm_sm83.py) writes them; verify with an independent header checker | same writer | same writer |
| Header flags | MBC5+RAM+battery, $80, SGB $03 | verify | MBC5+RAM+battery, $C0; verify RAM size vs real use |
| LCD off only in V-Blank | loads keep the LCD on behind a mask (VLCD); verify every LCDC write | verify | LCD off only at power-on (`runtime.s` boot); verify |
| VRAM / OAM timing | DMA only at LY 144-151; verify all paths (SameBoy dumps) | verify | map / tile DMA in V-Blank, LYC split writes in H-Blank; verify all direct writes |
| SRAM enabled only around access | **fails**: cart RAM stays enabled (NES PRG-RAM lives in it) | likely same | **fails**: enabled once at boot (`runtime.s`), NES PRG-RAM lives in it |
| Save validation + message | verify the games' own save checks; add the message | verify | verify |
| Soft reset A+B+Start+Select | **missing** | **missing** | **missing** |
| Memory / registers cleared at boot | verify (`memclr` covers WRAM?) | verify | verify |
| Cross-hardware | DMG / SGB / CGB tested in emulators; owner's GBC hardware test; GBA, Pocket untested | verify | CGB only |
| Color-only warning screen | n/a | n/a | **missing**: on a DMG the boot just halts (`runtime.s` `.dmg`) |
| Hardware names in text | check the scripts | check | check |
| CGB colour use | NES palettes per tile | verify | NES palettes per tile |
| Undisclosed code | test hooks in the binary: `TEST_PAD` mode ($D83E = $A5), `rst $38` trap / `DBG` record; remove or document. Env test switches (`GB_DLG_TEST`, `GB3_TEST_MINI`, ...) must be off | same | same (`GB3_TEST_MINI`, `FF3_TEST_GOBLIN`) |

Notes for the fixes:
- SRAM: keep the NES work RAM ($6000-$7FFF) in GB WRAM / a RAM area that is not battery-backed
  and touch the battery-backed save area only inside the game's save / load routines (enable,
  copy, disable), or prove each port's PRG-RAM accesses can be bracketed by enable / disable.
- Soft reset: checked in the runtime's joypad read; it must wait for any save write in
  progress to finish, silence the sound registers, and restart through the boot path.
- FF3 on a monochrome system: a static screen (no game graphics) with the message, drawn by
  the runtime before anything else.
