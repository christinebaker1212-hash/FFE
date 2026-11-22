# FF2 GB: function-level translation of all game code

Owner's decision (2026-11-22): "Translation from NES functions translated, into native code
... I mean ALL code. Not just dialogue." Chosen approach: **a function-level translator in
the builder** (not hand-written routines in the repo), and **this work comes before** the
open bug reports (battle messages, music, menu flash; the battle walk is already fixed).

## What stays

- Game bytes come only from the user's NES ROM at build time; the repo holds tools only.
  The translator reads the ROM and the everything8215 disassembly (fetched when the builder
  is made) and writes SM83 code into `build/`, never into the repo.
- Game logic, formulas, RNG and events stay exactly as on the Famicom: the translated code
  has the same effect on game RAM as the NES code. `firstdiff` (NES RAM vs GB RAM at every
  frame wait) remains the main check, with lagcheck (0% slowdown) and lotcheck.
- The native hardware routines (`rt/native*.s`, `rt/ff2*.s`, ...) stay; the translator calls
  them where the NES code touched the hardware.

## What changes

Today `tools/gb2/translate.py` recompiles one 6502 instruction at a time: A / X / Y pinned
to A / E / C, the 6502 flags kept (N in HRAM, carry inverted around SBC / CMP), every
indirect or banked access through a runtime helper that maps the NES address at run time.
Counts in the current build (2026-11-22): 33.4k 6502 instructions -> 54.6k SM83 lines;
`rt_izy_rd` 618, `rt_izy_wr` 311, `rt_rd_8` 453, `rt_rd_c` / `rt_rd_e` 59 call sites;
1,379 cross-bank `rst $08` calls; 2,033 `ccf` (carry inversion); 513 writes of the N flag.

The function-level translator works on whole routines:

1. **Routines and their graph.** Routine boundaries, code / data and jump tables from the
   disassembly (as today's code map); each routine lifted into a control-flow graph of
   basic blocks; the call graph across banks. Stack tricks (PLA PLA RTS, RTS dispatch,
   TSX / TXS) recognised per routine as today; a routine that cannot be proven safe keeps
   the current instruction-level translation (mixed mode, always correct).
2. **An IR instead of 6502 state.** Each instruction becomes operations on 8-bit values
   (loads / stores with a memory region, ALU ops, flag values C / Z / N / V defined only
   when something reads them). The 6502 registers become ordinary values.
3. **Analyses across routines.**
   - Per-routine summaries: which of A / X / Y / C / Z / N / V a routine reads on entry
     and which it defines on return, so a call no longer forces the caller to keep or
     rebuild 6502 state it never uses.
   - Constant propagation of the bank register (`fix:FE03` with a known A) and of pointer
     bytes: the region and bank of each indirect access, so `(zp),Y` and banked ROM reads
     become direct GB loads when the target is proven (ROM data bank, work RAM, cart RAM).
   - Ranges of index values (8-bit addressing without carries into the high byte).
4. **Native code generation.** Register allocation over A, B, C, D, E with HL / DE as
   address registers; pointer walks (`LDA (p),Y / INY` loops) as `ld a, [hl+]`; 16-bit
   add / subtract / compare idioms as 16-bit SM83 operations; carry in its SM83 sense
   (no `ccf` unless a 6502 carry is really needed); flags materialised only where read.
5. **Placement.** Routines placed in ROM banks along the call graph, so most calls are
   plain `call` instead of cross-bank `rst $08`.

## Milestones (each checked with firstdiff random 1 DMG + CGB, random 2, the save scenario,
battle formations, lagcheck, lotcheck, screens)

- **M1 IR round trip.** Lifter + IR + a back end that emits exactly today's per-instruction
  code from the IR. Output identical to today's build (byte-for-byte), so the IR is sound.
- **M2 Summaries and liveness.** Interprocedural register / flag summaries; fewer flag and
  register materialisations. Measure SM83 instructions and GB cycles per NES frame.
- **M3 Regions and banks.** `rt_izy_rd` / `rt_izy_wr` / `rt_rd_*` replaced by direct loads
  wherever the region is proven; the rest listed with the reason.
- **M4 Native code.** Register allocation, pointer walks, 16-bit idioms, SM83 carry.
- **M5 Placement.** Call-graph bank placement; cross-bank calls counted before / after.
- **M6 Coverage.** Share of routines (and of executed instructions) in native form; the
  remaining mixed-mode routines listed with the reason, then reduced.

Measures per milestone: helper calls (static and per frame), SM83 instructions per 6502
instruction, GB cycles per NES frame (lagcheck), ROM size; recorded in
`docs/ff2-gb-status.md`.

## Open bug reports (after this work, owner's order)

- Battle messages show fragments of other text and appear late (GB side: message tiles
  reach VRAM after the window row that shows them).
- Music differs from the NES (reference: the uploaded NSF, used only for comparison, never
  committed).
- White flash when opening the field menu.
- Dialogue: native routines with pleasant line breaks and paging (text unchanged).
