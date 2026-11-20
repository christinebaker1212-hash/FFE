# FF3 on the Game Boy Color: plan (approved by the owner 2026-11-19)

Status and setup: `docs/ff3-gb-status.md`. Targets and rules: `CLAUDE.md` (FF3: Game Boy
Color only, CGB flag `$C0`, MBC5 + battery SRAM, 0% slowdown, disassembly base, nothing
distributed). Method: the same as the FF2 session's approved plan (`docs/ff2-gb-plan.md` on
branch `claude/zealous-hypatia-3sn3fr`), adapted to FF3 and to a Color-only cartridge.

## 1. The disassembly base, and what was checked
everything8215/ff3 is, like ff2, **an annotated listing, not a buildable source**
(`ff3j.asm`: `bank/address: bytes  mnemonic  ; comment`, 8 KB banks; ~94.6 KB of 6502 in
banks `$10` (part), `$1F`, `$2E`-`$36`, `$3A`-`$3F`), plus a ROM map, field / battle RAM maps
and event / text dumps. So the source gets **generated at build time** from the listing and
the user's ROM (`tools/gb3/ff3src.py`); nothing from either is committed.

| Check | Result |
|---|---|
| Japanese FF3: generated source → reassembled (`tools/asm6502.py`) | **byte-identical, all 17 code banks** |
| English FF3 (MMC5 build, sha1 `4a7f1ae4…`): generated source → reassembled | **byte-identical**: 21 banks + the ExRAM code |
| Coverage: 4 × 60k frames of random play on the English NES build (cynes) | 21,367 executed instruction starts; all in the source map except 2 instructions that straddle a bank pair (known) and RAM code: the NMI/IRQ stubs at `$0100`/`$0103` (replaced by the runtime) and a sine helper copied to `$7EE3` (documented in the listing) |

The English patch needs no hand-porting: `tools/gb3/ff3en.py` runs `tools/ff3/insert.py`
unchanged and records its 8 code modules (ExRAM text engine, battle text converter, field
menu helpers, enemy / slot word tables, ...); the 193 game instructions changed by the
hooks and by the MMC3 → MMC5 conversion are re-decoded from the new bytes. Translation fixes
made later in `insert.py` or `script/ff3/` carry over to the GB build automatically.

## 2. Why Color-only makes FF3 simpler than FF1/FF2
No DMG shading, no SGB packets, no 384-tile squeeze. The GBC has everything the NES has
except screen size:

| | NES (FF3) | GBC (double speed) |
|---|---|---|
| CPU per frame | 29,780 cycles | 35,112 M-cycles |
| Pattern tiles | 8 KB CHR-RAM: 2 tables × 256 | 2 VRAM banks × 384 |
| BG palettes / grain | 4 × 4 colours, 16×16 px | 8 × 4 (RGB555), 8×8 px |
| Sprite palettes | 4 × 3 (8×8 sprites, 64, 8 per line) | 8 × 3 (40, 10 per line) |
| Work RAM | 2 KB + 8 KB PRG-RAM | 32 KB + cart SRAM |

**Tile mapping without a cache**: NES pattern table 0 → VRAM bank 0 `$8000-$8FFF`, table 1
→ VRAM bank 1 `$8000-$8FFF` (unsigned tile addressing for BG and sprites). Each BG map cell
and each sprite picks its table with the CGB bank bit, so FF3's battle split (BG from table
1 above the split, table 0 for the windows below, `$2000` = `$98` / `$88`) is just per-cell
attributes, no mid-frame switching. (With unsigned addressing the BG and window can only
use `$8000-$8FFF`, so GB-only text goes into NES tiles from the NES side, as FF1 does; the
mask while NES rendering is off is black palettes, not a window.)

## 3. 6502 → SM83
**Mechanical translation of the generated source** (`tools/gb3/translate.py`, copied from
FF2's `tools/gb2/translate.py` / FF1's `recomp.py`, not editing them): same register
mapping (A→A, X→E, Y→C, B=D=0), backward flag liveness, listing labels in the `.sym`. This
carries all game logic over unchanged: battle formulas / AI (`$2E`-`$35`), field, events and
NPC scripts (`$3A`-`$3F`), menus and jobs (`$3C`/`$3D`), the sound driver's sequencing
(`$36`).

**FF3 specifics the translator handles:**
- MMC5 PRG mode 3 (8 KB at `$8000`, `$A000`, `$C000`; `$E000` fixed): bank switches through
  `$FF03` / `$FF06` / `$FB87` resolve statically where the value is constant, otherwise
  dispatch on the mapped bank (673 cross-window calls).
- Bank pairs `$2E/$2F`, `$30/$31`, `$32/$33`, `$34/$35` are one 16 KB space (code runs across
  `$9FFF/$A000`).
- Code run from RAM: NMI / IRQ jump stubs at `$0100` / `$0103` (replaced by the runtime), the
  final boss animation copied to `$7EF5` (translated from its ROM image at its run address).

**Native GB routines** (each replaces one labelled routine, checked by RAM equivalence):

| NES | GBC |
|---|---|
| frame wait (`$FF00` / `$F8B0` / `$FB80`: NMI stub rewritten in RAM) | halt until vblank; the NMI's work (OAM DMA, palettes, scroll) in the vblank ISR |
| raster splits (MMC3 IRQ → MMC5 helpers in ExRAM: field window split, battle window split at line ~150, chained splits in `$10`/`$1F`/`$32`) | window layer + LYC interrupt (FF1 lesson: raster splits belong in the window layer) |
| battle wave effect (`$2F`, `$2000` rewritten every 2 lines for 108 lines) | STAT/LYC per line pair, or pre-shifted map rows |
| busy waits (e.g. `$F809`, 5400 cycles of NOPs "until the battle bg is drawn") | removed, RAM effects kept (frees battle time) |
| PPU copies, CHR / map / attribute / palette uploads, text row flush (`$F6AA`) | direct VRAM / HDMA in vblank, VRAM bank 1 attributes |
| OAM `$0200` + `$4014` | GB OAM conversion (40 sprites, culled to the view) |
| APU writes in the sound driver | GB channels (FF1's `apu.s` model, queued per frame so music never hitches) |
| joypad, MMC5 registers, multiply / divide helpers | GB joypad, MBC5, SM83 routines with identical results |

**Game data** comes only from the user's ROM: the English NES ROM's 8 KB banks are copied
into MBC5 banks; tables are read through a bank-0 helper, hot tables copied next to the code
that reads them.

| NES | GB |
|---|---|
| RAM `$0000-07FF`, ExRAM `$5C00-5FFF` | WRAM bank 0 |
| PRG-RAM `$6000-7FFF` (saves + work buffers `$7200`, `$7400`, `$7B00`, `$7E00`, ...) | cart SRAM bank 0 (`$A000-$BFFF`) |
| GB-only state (VRAM queues, tile shadows, suspend point) | WRAM banks 1-7, cart SRAM banks 1-3 (32 KB total, the FF1 lesson) |

Size estimate: ~30k instructions → ~250 KB SM83, plus 1 MB of NES data → **2 MB MBC5**.

**Speed (0% slowdown).** The GBC gives ~18% more cycles per frame than the NES, and
FF3's own NES version lags in heavy battles; the translation alone will not be enough
everywhere. From the start: native graphics paths, no busy waits, sound queued per frame,
and `lagcheck.py`-style measurement (Gambatte, hardware-like timing) at every milestone on
the field, towns with dialogue, menus, battle and the intro. CGB-only means one timing
model to tune, not two.

## 4. Screens (SaGa / Final Fantasy Legend style, 160×144)
Re-layouts are done in the game code, on the NES side (`tools/gb3/layout.py` after
`insert.py`, as FF1 / FF2), so the GB build can still be checked frame by frame against an
NES "GB-layout" ROM. Mock-ups (PNG, real font and graphics from the user's ROM, output in
`build/` only) go to the owner before each screen is built:
- battle: enemies in the upper part, the four party sprites in their own column, names /
  commands window and a one-line-per-member party window below, full-width messages; no
  blinking; enemy names while targeting;
- field: centred camera; dialogue in the window layer (full width);
- main menu, items, magic, equipment, status, jobs, shops: one-line party lists, one
  column, full names (README rule 3);
- title, prologue, ending: re-wrapped text, same words.

## 5. Order of work
1. Boot to the title (Gambatte CGB, PyBoy).
2. New game, field, battle, with RAM equivalence against the English NES build in cynes.
3. Speed pass (native routines where measurement shows lag).
4. Mock-ups, then screen re-layouts (battle, dialogue, menus, ...).
5. Colour polish (NES palettes → RGB555), sound check against the NES.
6. Select menu and suspend points.
7. The builder (`tools/builder/ffe_builder.py`: enable FF3).

## 6. Owner's decisions (2026-11-19)
1. **Select menu:** Select on the field opens the new menu with **OPTIONS** and **SUSPEND**
   (no FORMATION entry: FF3's main menu already has Order). **B + Select** changes the
   walking party member (the Famicom's Select action, `$F72C`).
2. **Approach:** approved as in §3 ("go ahead with the plan").
3. **Battle layout (2026-11-20, from the mock-ups `tools/gb3/mockup.py`):** the enemy area
   unchanged in the top 12 rows (NES cols 2-19, rows 6-17: every formation fits); the party
   column at the right edge, **all four members fully visible** (24 px apart instead of 28);
   **layout A**: a full-width party window (name, HP current/max per line) in the bottom 6
   rows, the command window and the enemy names (while targeting) opening over its left part
   (9 columns); **messages in one full-width window** over the party window ("attacker →
   target", hits, results). Rows and step as FF1 / FF2 (owner: "take a look at what FF1
   and FF2 do"): enemy area NES x 20-159 at GB x 0-139, party column GB x 140-159 (front row
   NES x 160, back row 164), members 24 px apart from NES y 47, the acting member steps
   forward 8 px (back row 12); a battlefield camera (pixels) and a tile-aligned window
   camera, split at GB line 96.
   Built (2026-11-20, `tools/gb3/layout.py`): windows on FF3's rows 19-24 (NES row 18 is
   written by the enemy death animations, so it stays hidden: window camera col 2 / row 7),
   one tile row per text line, party window cols 2-21, command / names windows cols 2-11,
   command hand over the window frame at the screen edge (FF1). Messages: one window, lines
   filled in order (attacker -> target on line 1 when it fits, the action, the result
   word-wrapped at 18; a longer result covers the last lines).
   **Item / Magic lists (owner, 2026-11-20, mock-ups `mockup.py NES OUT lists`):** a tall
   list window while choosing (GB rows 8-17, the battlefield's NES rows 6-13 above; back to
   the normal layout afterwards): items 4 per page in FF3's own 2-row entries, left/right
   turns whole pages (one column, the next column's edge showing at the right; no scroll
   animation); magic 4 levels per page, row 1 = spells 1-2, row 2 = spell 3 + level / MP
   (as FF1's battle magic list), the cursor moving between the spells by position.
4. **Native presentation (owner, 2026-11-20, all three ports):** game logic recompiled from
   the user's ROM, presentation (picture, sprites, music, screen loads) native GB code;
   measure first (lagcheck, sgbrun profile buckets), reproduce each replaced routine's RAM
   side effects exactly. `docs/gb-native-presentation.md`.

