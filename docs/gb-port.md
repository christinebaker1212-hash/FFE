# FF1/FF2 English → Game Boy (SGB), FF3 English → Game Boy Color: port design

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

## Targets (decided by the project owner)
- **FF1 and FF2: Game Boy (DMG) with Super Game Boy support**, on the largest mapper needed
  (MBC5, sized to the game, with battery SRAM). Colour comes from SGB palettes (4 palettes
  assigned per screen area or 8×8 cell through `ATTR_*` packets) plus an SGB border.
  On a plain DMG the game shows 4 greys.
- **FF3: Game Boy Color.**

DMG-specific constraints for FF1/FF2 (compared with the table below):
- **No double speed.** The recompiled code runs on a 4.2 MHz SM83, so the flag-liveness
  optimisation and a hand-tuned runtime are required, not optional. Measure early
  (milestone 2) how much of each frame the field and battle loops use.
- **384 tiles** in VRAM (BG 256 + sprites 256, with 128 shared), against 512 on the NES. CHR
  uploads go through a tile cache that remaps NES tile numbers to free GB tiles.
- **8 KB WRAM.** NES RAM (2 KB) and the VRAM write queues go to WRAM. NES save/work RAM
  `$6000-7FFF` maps directly to an 8 KB cart SRAM bank at `$A000-BFFF`.
- NES palettes → SGB: each NES palette becomes an SGB palette (`PAL01`/`PAL23`), and
  attribute changes are batched into `ATTR_CHR`/`ATTR_BLK` packets. Packets are slow
  (~64 ms each), so they are sent only when a screen's palette layout changes.

The rest of this document was written for a GBC target and still applies to FF3.

## Hardware comparison
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
Input: `build/ff1_en.nes` plus coverage logs from `tools/gb/covrun.py`; code map from
`tools/gb/nescode.py` (code spaces `bNN` / `c62` / `far` / `fix` / `ex`).

**What the analysis showed (FF1 English build)**
- The game is synchronous: `JSR $FE00` enables NMI and spins at `JMP $FEEE`; the NMI
  handler `$FECF` pops the interrupt frame (`PLA ×3`) and `RTS`es to the caller of
  `$FE00`. All PPU work happens in the main thread right after that call returns.
  On GB, `JSR $FE00` → `call wait_frame` (halt until the vblank ISR has run). The NMI
  handler itself is not compiled.
- Bank switching: `$FE1A` writes `$5115` (16KB at `$8000`), `$FE06` writes `$5105`.
  The English patch uses PRG mode 2: `$C000-DFFF` is 8KB bank 62 except during
  `farjsr`, which maps bank 40 there and dispatches by push-address + `RTS`.
- Stack tricks found by the shadow-stack log: NMI return (above), `b14:A330` `PLA PLA RTS`
  (return to the caller's caller), the `farjsr` RTS dispatch (`ex:5D0B`), `TXS`
  resets (`$C024`, `$C0D3`, reset). Jump tables: `JMP ($0010)` at `c62:CA99`, `b14:B187`.

**Registers.** A → A. X → E with D = 0, Y → C with B = 0, so `abs,X` is
`ld hl,base / add hl,de` and `abs,Y` is `ld hl,base / add hl,bc`. HL is the only
scratch pair; HRAM holds the other temporaries.

**Stack.** NES pushes go on the GB stack: `PHA` = `push af`, `PLA` = `pop hl / ld a,h`,
`JSR` = `call`, `RTS` = `ret`. Each NES 2-byte return address is one 2-byte GB frame, so
balanced code behaves the same. Known tricks get their own translation: `PLA PLA` that
drops a return address → `pop hl` (one GB frame); push-address + `RTS` and `JMP (ind)`
→ `jp dispatch` (sorted table of NES address → GB bank:address, filled from the
coverage log and the tables that feed them); `TXS` → `ld sp, STACK_TOP`. NES `$0100-01FF`
stays plain RAM (FF1 keeps variables there).

**Flags.** Backward liveness over the whole program (call/return edges included) says
which of N, Z, C and V each instruction must produce.
- C is the GB carry. Its polarity is tracked inside a basic block (`CMP`/`SBC` leave it
  inverted) and normalised with `ccf` only where C is live at a block exit.
- Z is the GB Z flag. After loads (`LDA`/`TAX`/`PLA`, which don't set GB flags)
  `inc r / dec r` sets Z without touching C.
- N: `bit 7,r` at the branch when the value is still in a register. Otherwise the
  producer stores the value to HRAM `nzv` and the branch tests it.
- V (`ADC`/`SBC`/`BIT` → `BVC`/`BVS`) is only computed where it is live (HRAM `vfl`).
- Runtime helpers that clobber GB flags are wrapped in `push af`/`pop af` where a
  flag is live across them.

**Memory.** Static addresses are classified at compile time:

| NES | GB |
|---|---|
| `$0000-07FF` RAM (and mirrors) | WRAM `$C000-C7FF` (direct `ld`) |
| `$2000-3FFF` PPU, `$4000-4017` APU/IO | calls into the PPU/APU layer |
| `$5100-5BFF` MMC5 registers | bank bookkeeping (`$5115`/`$5116`), mirroring; others ignored |
| `$5C00-5FFF` ExRAM | WRAM `$C800-CBFF` (direct) |
| `$6000-7FFF` save RAM | cart SRAM `$A000-BFFF`, enabled at boot (direct) |
| `$8000-FFFF` ROM | data read helper in bank 0 (see below) |

Indirect `(zp),Y` / `(zp,X)` accesses translate the pointer at run time by region. Where the
coverage log shows a single region for an instruction, a fast path for that region is
compiled, with a fallback to the general helper.

**ROM data vs code.** The GB has one switchable 16KB window, and it holds the
recompiled code. NES ROM data is copied verbatim into its own GB banks (`DATA + n` for
NES 16KB bank n), and reads go through a bank-0 helper: map the data bank, read, map
the code bank back (~30 cycles). If profiling shows hot tables, those tables get
copied into the code bank that reads them.

**Code layout.** Each NES space is compiled into GB banks. Bank 0 holds the runtime and
the most-called fixed-bank routines (frame wait, bank switch, sound, PPU helpers).
Calls between GB banks go through bank-0 stubs (`farcall`: save A in HRAM, switch,
`call`, switch back; flags preserved). Banked NES code at `$8000` called from fixed
code dispatches on the current `$5115` value.

**Output.** SM83 assembly for `tools/gb/asm_sm83.py`, with labels `L_<space>_<addr>`
so the `.sym` file maps every GB address back to the NES instruction.

## 2. PPU layer (`tools/gb/rt/ppu.s`)
DMG has no VRAM DMA, and VRAM is only writable in vblank/hblank, so:
- **Rendering off** (`$2001` = 0, used for full-screen loads): wait for vblank, LCD off,
  and `$2006/$2007` write straight to VRAM (SGB: `MASK_EN` freezes the picture meanwhile).
- **Rendering on**: `$2007` writes go to a queue, flushed by the vblank ISR. A frame's
  writes show one frame later.
- CHR (`$0000-1FFF`): NES byte k of a tile (plane 0 rows 0-7, then plane 1) goes to GB
  tile byte 2k / 2(k-8)+1. NES has 512 tiles and DMG VRAM has 384 (sprites $8000-8FFF,
  BG $8800-97FF, 128 shared). Tile usage gets measured with `PPU_LOG` before the
  allocator is designed (fixed mapping if FF1's real usage fits, else a remapping cache).
- Nametables: NES tile (x, y) → GB BG map ($9800) column x mod 32, row y. The field
  writes at most 32 consecutive columns per row update, so mod 32 never puts two
  NES columns in view at once. NES vertical wrap is 30 rows and the GB map has 32,
  so an LYC interrupt changes SCY where the view crosses NES row 30.
- Scroll: camera = NES scroll + (48, 48) (centre of 256×240), per-screen overrides
  later (milestone 5).
- OAM (`$4014`): 64 NES sprites → up to 40 GB sprites, culled to the camera view,
  converted during the frame, DMA'd in vblank.
- Palettes: DMG uses one BGP (NES index → shade). SGB maps NES palettes 0-3 to SGB
  palettes 0-3 (`PAL01`/`PAL23`). Attributes become `ATTR_CHR` packets, sent only when a
  static screen's layout changes (the field keeps one palette set).

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
MBC5 + battery SRAM. FF1/FF2: DMG header with the SGB flag (`$0146 = $03`, old licensee `$33`). FF3: CGB-only flag. Banks: 0 = runtime + fixed-bank code,
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
