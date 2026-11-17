# FF1 English → Game Boy Color: port design

Status: design only. Nothing is built yet.

## Ground rules
- The repo holds **tools only**: no FF1 code, graphics, music, maps or text from the
  ROM, and no prebuilt GB ROM. Everything game-specific is read from the user's own
  ROM when the build runs. The pipeline:

  ```
  Final Fantasy I, II (Japan).nes  ──tools/split/build_mmc5.py──►  ff1_mmc5.nes
        ──tools/ff1/insert.py──►  ff1_en.nes (MMC5, English)
        ──tools/gb/build.py──►    ff1_en.gbc   (local only, never committed)
  ```
- The game logic is FF1's own 6502 code, **statically recompiled** to SM83. It is
  not rewritten by hand. Battle formulas, RNG, events and menus behave exactly as on
  the Famicom, and the English patch carries over without changes.
- Graphics, palettes and sound go through a hardware layer that turns the NES PPU and APU
  register writes into GBC equivalents.

## Why Game Boy Color (CGB-only), not the original DMG
| | NES | GBC | DMG |
|---|---|---|---|
| CPU | 6502 1.79 MHz | SM83 8.4 MHz (double speed) | SM83 4.2 MHz |
| BG palettes | 4 × 4 colours | 8 × 4 (RGB555) | 1 × 4 greys |
| Sprite palettes | 4 × 3 | 8 × 3 | 2 × 3 greys |
| Attribute grain | 16×16 px | 8×8 px | n/a |
| Tile memory | 8 KB CHR-RAM (512 tiles) | 2 VRAM banks (768 tiles) | 384 tiles |
| Work RAM | 2 KB + 8 KB SRAM | 32 KB + cart SRAM | 8 KB + cart SRAM |
| Screen | 256×240 | 160×144 | 160×144 |

Everything in the GBC column is the same size as the NES or larger, except the screen. The
recompiled code runs several GB instructions for each 6502 instruction, so it needs
double speed to be playable. FF1 is turn-based and spends most of each frame waiting for
NMI, so this should be enough.

## 1. Recompiler (`tools/gb/recomp.py`)
- **Code discovery:** trace from the reset, NMI and IRQ vectors and every `JSR`/`JMP`/branch
  target, bank by bank (FF1 calls across banks through its fixed-bank swap routine at
  `$FE1A`). Jump tables (`JMP (ind)`, push-address + `RTS`) are found by
  recording targets in the emulator (`tools/emu`) during play, plus tables listed by hand.
  Anything left unresolved goes through a runtime NES-address → GB-address lookup.
- **Registers:** A→A, X→B, Y→C, NES SP→a byte in HRAM (the 6502 stack page is emulated
  in WRAM so `TSX`/stack tricks keep working), C flag→carry (inverted for subtraction,
  as 6502 SBC/CMP borrow is the opposite of SM83). N, Z and V are computed only where
  liveness analysis shows a later branch reads them.
- **Memory map:** NES `$0000-07FF` → WRAM; `$6000-7FFF` (save RAM) → cart SRAM; zero
  page → a fixed WRAM page so `(zp),Y` becomes `ld hl` + `add`. ROM data reads in
  `$8000-BFFF` become reads from the matching MBC5 bank at `$4000-7FFF`. MMC5 bank
  writes become MBC5 writes.
- **Output:** SM83 assembly, assembled by a small Python assembler (`tools/gb/asm_sm83.py`),
  in the same spirit as `tools/asm6502.py`. No outside toolchain is needed.

## 2. PPU layer (`tools/gb/rt/ppu.s`)
- `$2006/$2007` writes go to a WRAM shadow of the nametables, attribute tables and
  CHR-RAM. At GB vblank the changed parts are sent with GDMA. Tiles change
  format on the way: the NES stores 8 bytes of plane 0 then 8 of plane 1, the GB
  interleaves them row by row (a 256-byte lookup table).
- The NES nametable is 32 tiles wide and the GB BG map is 32×32, so the BG maps
  one-to-one. Attributes (2 bits per 16×16) are expanded into the CGB attribute map
  (VRAM bank 1).
- Palette writes (`$3F00-3F1F`) go through a 64-entry NES-colour → RGB555 table to the
  CGB palette RAM.
- OAM DMA (`$4014`) converts NES OAM (Y, tile, attr, X) to GB OAM (Y+16, X+8, tile,
  attr). The GB shows 40 sprites (10 per line); the NES shows 64 (8 per line).
- Scroll (`$2005`/`$2000`) sets SCX/SCY through a *camera* (see 3).

## 3. The screen: 256×240 → 160×144 (the real work)
A camera alone handles the field: the party stays centred and the view shows
10×9 metatiles instead of 16×15. Every other screen was laid out for 32 columns
and has to be **re-laid out** for 20×18 tiles, with the same kind of 6502 patching
already done in `tools/ff1/insert.py`:
- Dialogue window: 25 columns now, about 18 on GB. The text is rewrapped by
  the existing inserter at a new width (the translation stays the same; only the line breaks change).
- Main menu, item/magic/equip/status screens, shops, inn, save, class selection, name entry.
- Battle: monsters, party sprites, the command window and the message boxes have to share
  160 px. This screen needs its own design pass.
- Opening bridge text, title, ending and credits.

Each screen gets an entry in `docs/gb-screens.md` with its NES layout, GB layout and the
patch sites. Until a screen is re-laid out, the camera can pan over the 256×240 picture
so the game can still be played and tested.

## 4. Sound (`tools/gb/rt/apu.s`)
FF1's own sound driver is recompiled like the rest of the code. Only its APU
register writes are converted:
pulse 1/2 → GB CH1/CH2 (NES 11-bit period → GB frequency through a table; duty values
map directly; volume/envelope → NRx2), triangle → CH3 wave channel (triangle waveform
in wave RAM), noise → CH4 (NES noise periods → nearest NR43 values). FF1 does not use
the DMC.

## 5. Cartridge
MBC5 + 32 KB battery SRAM, CGB-only header flag. Banks: 0 = runtime + fixed-bank code,
1-n = recompiled bank code, followed by ROM data banks copied from `ff1_en.nes`.
Expected size: 1-2 MB.

## 6. Verification
- Run `tools/emu` (NES) and PyBoy (GBC) side by side with the same inputs, comparing
  NES RAM with the GB's emulated RAM frame by frame. This is the same method as
  `tools/split/equiv.py`. Matching RAM shows the recompiled code is correct.
- Screenshots of every re-laid-out screen, checked for text that runs past the edge
  (based on `tools/emu/bordercheck.py`).

## Milestones
1. SM83 assembler and a minimal runtime that boots in PyBoy (test pattern).
2. Recompiler on the fixed bank only; title screen shows with the camera (pan mode).
3. Whole game recompiled; RAM matches the NES across random play (field, battle, menus).
4. Sound.
5. Screen re-layouts, one by one (dialogue first, then menus, then battle).
6. Save RAM, timing polish, pass on real hardware or an accurate emulator.
