# FF2 on the Game Boy: plan (for the owner's OK)

Status and setup: `docs/ff2-gb-status.md`. Targets and rules: `docs/ff2-gb-brief.md`.

## 1. What the "disassembly base" is, and what was checked
everything8215/ff2 is **not a buildable disassembly**. It is an annotated listing
(`ff2j.asm`, 33.9k lines: `bank/address: bytes  mnemonic  ; comment`) of the standalone
FF2 (J) ROM, plus a ROM map and a RAM map. It lists the code (~61.5 KB of 6502) and a few
tables. Graphics, maps, text and music are only named in the ROM map.

So the source base gets **generated at build time** from the listing and the user's ROM
(`tools/gb2/ff2src.py`). Nothing from either is committed:
- the listing gives the instruction starts, routine titles and comments;
- the instructions are re-decoded from the ROM bytes, and everything else is data taken
  from the ROM;
- every branch, jump and call target gets a label.

Checks done (2026-11-19; `tools/asm6502.py` for reassembly, cynes for coverage):

| Check | Result |
|---|---|
| Listing bytes vs the owner's ROM (FF2 half of FF I・II) | identical, except the compilation's boot glue (reset enters through the cart-menu stub) and 4 stale fragments |
| Japanese FF2: generated source → reassembled | **byte-identical, all 16 banks** |
| English FF2 (MMC5 build, sha1 `0e76a60d…`): generated source → reassembled | **byte-identical**: banks 00-0F, fixed bank and the ExRAM code |
| Coverage: 4 × 60k frames of random play on the English NES build | 14,464 executed instruction starts; all are in the source code map except RAM `$0100` (FF2's NMI jump stub, which the runtime replaces anyway) |

So the code/data split is complete for everything that ran, without guessing from
coverage as FF1 had to.

## 2. How the English patch sits on that source
The English patch has two parts, and neither has to be hand-ported:
- **Text and font** (names, system strings, dialogue, events, battle text, ending; new
  glyphs). This is data. `tools/ff2/insert.py` keeps building it from `script/ff2/*.json`
  into the same banks (10, 16-21).
- **Engine changes.**
  - Code modules written as 6502 source inside `insert.py`: ExRAM code at `$5C00`, the
    fixed-bank modules at `$F750`, `$F850` and `$FF30`, the bank 12 converter, init.
  - Hooks: `JSR` / `JMP` and operand changes in the game's code.

`tools/gb2/ff2en.py` runs `insert.py` unchanged and records each module's origin, labels
and instruction starts. `ff2src.py --english` then treats them as labelled code, and
re-decodes the 169 listing instructions that the hooks and the MMC5 split changed.
Translation fixes made later in `insert.py` or the script carry over to the GB build
without any extra step.

**GB screen re-layouts** would go in the same form, as a new
`tools/gb2/layout.py`:
- 6502 modules and hooks applied after `insert.py`, as FF1 did with `gb_layout.py`;
- this gives an NES "GB-layout" ROM that runs in cynes, so every frame of the GB build
  can still be checked against it.

## 3. 6502 → SM83
**Mechanical translation of the generated source** (`tools/gb2/translate.py`, adapted from
FF1's `tools/gb/recomp.py` by copying, not by editing it):
- Each listed routine is translated instruction by instruction, with the same register
  mapping as FF1 (A→A, X→E, Y→C, B=D=0) and backward flag liveness.
- Labels come from the listing (`Lbb_aaaa`, `Fxxxx`, insert.py names), so the GB `.sym`
  file names every routine.
- This covers all game logic, unchanged: battle formulas and AI (banks 0B/0C), menus
  (0E), field, events and NPC scripts (0F, 03), stats and equipment (00), and the music
  and SFX drivers' sequencing (0D, 05).

**Native GB routines**, each replacing one labelled routine (`tools/gb2/native/*.s`, keyed
by the listing label, checked by RAM equivalence like the rest). These are the graphics
paths and hot loops:

| NES routine(s) | GB replacement |
|---|---|
| frame wait `$FA2A` / `$FEAD` and the RAM NMI stub at `$0100` (FF2 points NMI at a `JMP`/`RTI` it rewrites in RAM) | halt until the vblank ISR has run; per mode, the work the NMI did |
| battle NMI (`0C/9A79`, `05/A9A2`): **asynchronous**, busy-waits on sprite 0 (`$FD46` / `$FD5B`) to split battlefield and menu | LYC interrupt switching tile data / scroll at the split line: no busy-wait, so battle gets *more* CPU than on the NES |
| PPU copies (`$FD6F` and others), CHR/graphics loaders, field row/column nametable updates, attribute and palette uploads | direct GB VRAM writes or the vblank queue; CGB: HDMA and VRAM bank 1; DMG: FF1's tile cache and `dmg_shade` |
| OAM page `$0200` + `$4014` | GB OAM conversion (40 sprites; culled to the view) |
| APU register writes inside the sound drivers | GB channels (FF1's `apu.s` model: pulse → CH1/2, triangle → wave, noise → CH4) |
| joypad, MMC1/MMC5 bank switches (`$FE03` / `$FE1A` / `$FE06`) | GB joypad, MBC5 bank select |
| multiply/divide helpers (e.g. `$FC79`), CPU delay loops | SM83 routines with identical results; delays calibrated to NES time |

**Game data** still comes only from the user's ROM. The GB build copies the English NES
ROM's 16 KB banks into MBC5 banks. Translated code reads tables through a bank-0 helper,
and hot tables get copied into the code bank that reads them (FF1's method).

Memory map:

| NES | GB |
|---|---|
| RAM `$0000-07FF`, ExRAM `$5C00-5FFF` | WRAM |
| `$6000-7FFF` (save data plus FF2's work buffers `$7600`, `$7B00`, `$7D47`…) | cart SRAM bank |

Estimate: ~26k instructions → ~150-200 KB of SM83; 1 MB MBC5; 32 KB SRAM (NES SRAM, tile
shadows, saves, suspend point).

**Speed (0% slowdown).**
- FF1 reached 1.00× in steady play on DMG with the same kind of translation.
- FF2's battle loses its sprite-0 busy-waits on the GB, which frees most of each battle
  frame.
- The field (4-way scrolling) and the screen loads get native routines from the start.
- Measured with `lagcheck.py` on Gambatte and mGBA (DMG, SGB, CGB) at each milestone.

**Order:**
1. Boot to the title (PyBoy, Gambatte).
2. New game, field, battle, with RAM equivalence against the English NES build in cynes
   (`firstdiff`-style).
3. Mock-ups and then screen re-layouts.
4. CGB colour, then DMG shading and SGB.
5. Select menu and suspend points.
6. The builder.

## 4. Questions for the owner
1. **Select menu.** On FF2's field, Select alone opens the row (formation) screen, and
   B+Select opens the world minimap once the party has the key item. Proposal:
   - Select opens the new menu: OPTIONS / FORMATION (that same row screen) / SUSPEND;
   - B+Select keeps the minimap.
2. **Approach.** OK to go ahead as in §3? That is: mechanical translation of the
   generated source, native routines for the graphics, sound and hot paths, and
   re-layouts on the NES side so equivalence stays checkable.
