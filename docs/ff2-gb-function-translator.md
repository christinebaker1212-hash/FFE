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

## Progress

- **M1 done (2026-11-22):** `tools/gb2/ftrans.py`: 1,560 routines, 11,521 blocks, call graph,
  IR per instruction; the build goes through it, ROM byte-identical to the previous build.
  1,491 routines (nearly all of the 33.4k instructions) have no stack tricks or dynamic control.
- **M3 started:** whole-program range analysis (A / X / Y / C and the zero-page pointer bytes;
  ROM operands read from the user's ROM; callers' states flow into routines reached only by
  static calls; per-routine zero-page write sets, natives counted with the NES code's effects,
  the NMI handlers' writes at every call). Annotation from the disassembly: the music
  engine's zp,X stores stay in $B0-$CF. Result: 36 of 938 (zp),Y sites with a known pointer
  range; 4 made direct (work / cart RAM). Most pointers are shared between RAM and ROM data by
  one routine (text printers): per-call-site versions needed (later).
- **Home placement:** the hot ROM-data readers run from bank 0 with their data bank mapped
  at $4000 (translate.py `HOME_*`, ftrans `HOME_CANDIDATES`): the music engine (bank 13 data)
  and the field sprite drawing around fix:E102 (fixed-bank sprite tables), 945 instructions.
  Calls into them map the data bank (inline far call with the data bank, as for any bank);
  inside, table reads from that bank are plain loads and pointer reads take a mapped fast
  path (`rt_izy_rd8m` / `rt_izy_rdem`). Per frame (random 1): full pointer-helper reads
  8.9 -> 2.4; cross-bank calls up 9.6 -> 13.4 (the sprite component's callees stay in the
  code banks: placement along the call graph is M5). lagcheck DMG -1.7%, CGB -3.9%.

- **M4 (2026-11-22):** carry polarity tracked instead of emulated (CMP / CPX / CPY / SBC
  leave the GB carry inverted; BCC / BCS test the matching condition; a CCF only where
  6502 polarity is needed: ADC, rotates, calls, returns, natives, joins of differing paths;
  forward fixpoint per routine with normalisation at the ends of paths into forced blocks);
  BMI / BPL test bit 7 of the register that produced N (same block, register unchanged,
  N and Z dead after) instead of an N byte in HRAM; `LDA zp / abs` as `ld a, [nn]`.
- **M5 (2026-11-22):** calls to native replacements go straight to the native (no detour
  through the replaced routine's label in a code bank); calls through JMP stubs are threaded
  to their target (fix:FE00 -> the frame wait, FE03 -> the bank switch, ...); home placement
  per instruction (the whole music engine incl. its entry); the per-frame natives (joypad,
  scroll, palette uploads, sound output) moved to bank 0, called without a bank switch.
  Cross-bank calls per frame (random 1): 12.5 -> 7.2.
- **M6 coverage (2026-11-22, build n19):** 1,491 of 1,560 routines (95.6%) clean;
  26,902 of 33,379 instructions (80.6%) in the polarity-tracked set (the rest: code shared
  by several routines, routines with stack tricks / dynamic control). Output 50.9k SM83
  lines (1.53 per 6502 instruction; was ~2.0); CCF 2,036 -> 1,587; N byte 1,086 -> 649
  references; V-flag helpers 0; remaining helpers: pointer reads 585 / writes 311 sites
  (2.4 / 1.2 per frame), banked table reads 446 + 58 sites (4.0 per frame).
  Open items for later passes: per-call-site versions of routines that take RAM and ROM
  pointers (text printers), carry convention across calls, shared code in the tracked set,
  banked table reads of hot routines (data next to code).

## Bug reports (after this work, owner's order): fixed 2026-11-23
All four are fixed (details in `docs/ff2-gb-status.md`, "Owner bug reports on the
native-layer build"): battle messages (DMG text tile coding), music (the update now runs
once per GB frame; the register stream already matched the NSF reference), the white
flash (masked screen instead of LCD off), dialogue pages (sentence-aware 6-line pages and
line breaks, text unchanged).
