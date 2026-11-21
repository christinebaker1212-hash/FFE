# FF2 GB: replacing the NES-hardware layer with native routines

Owner's decision (2026-11-21): "the Game Boy should not be emulating the NES while the game
plays ... replacing more of the NES-hardware layer with native routines written from the
disassembly is how I want to do this."

## What changes and what stays

- **Stays:** the game's own logic, recompiled from the user's ROM (static recompilation,
  owner's decision 2026-11-18): formulas, RNG, events, menus' decisions, battle logic.
  RAM equivalence with the NES (firstdiff) remains the main check.
- **Goes:** the runtime layer that *emulates NES hardware* for that code: the PPU address
  latch and `$2007` data port, nametable / attribute / palette writes interpreted byte by
  byte, CHR uploads through `$2007`, APU register semantics (`$4000-$4017`), the `$4016`
  strobe / serial joypad, OAM DMA through `$4014`, the mapper-style GB camera registers
  (`$58xx`) the layout writes.
- **Replaced by:** native GB routines, one per game routine that does hardware work,
  written from what the everything8215 disassembly says the routine does (never copying
  game code): they write the GB map, tiles, palettes, OAM and sound channels directly.
  The game routine is replaced whole (translator `ext` / layout `NATIVE_EXT`), with the
  same RAM effects as on the NES, so the game logic around it cannot tell.

## Measure

`tools/gb2/hwprof.py NES GB FRAMES --random S`: every call from game code into the layer,
by kind (`rt_ppu_w0..7`, `rt_ppu_r2/r7`, `rt_apu_w`, `rt_io_w4014`, `rt_io_w4016`,
`rt_io_r4016/4017/4015`, `rt_mmc_w58xx`, `rt_mmc_w5115`) and by the calling game routine.
Static sites: `grep -c "call rt_ppu_\|call rt_apu_w\|call rt_io_\|call rt_mmc_" build/ff2_gb.gb.s`.
Done when no game routine calls the layer during play (the entry points remain only as
a fallback that the translator reports, then are removed).

Starting point (2026-11-21, static call sites in the translated code): PPU 579 (`$2006`
187, `$2007` 167, `$2005` 70, `$2001` 61, `$2002` reads 44, `$2000` 38, `$2007` reads 10,
`$2003` 2), APU 150, OAM DMA 43, joypad 9, camera registers ~45, bank register 2.

## Order of work

1. **Joypad**: FF2's joypad read routines (strobe `$4016`, eight serial reads) -> one
   native read of the GB buttons into the same RAM bytes.
2. **Sound**: the music engine's output loop (bank 0D, the per-channel shadow `$6F19..`
   copied to `$4000+` when the update flags `$C0-$C2` say so) -> native channel output
   from that shadow; the sound effect routines (cursor `fix:DB2E` / `DB45`, door `D05F`,
   battle noise in banks 3 / 5 / F) -> native effects on the GB channels.
3. **Sprites**: every `LDA #$02 / STA $4014` -> a direct call of the native OAM
   conversion (it already is native; the register write goes).
4. **PPU, by frequency** (hwprof): palette uploads, window frames and text output, the
   battle screen's drawing, menus, map transitions; each routine natively with the GB map
   / tiles / attributes written directly (the runtime's shadows kept consistent while
   other routines still use them).
5. **Camera / bank registers**: the layout's `$58xx` writes become calls of native
   camera routines (they are our own registers, not the NES's).
6. Remove the layer's entry points that are no longer reached; the translator then
   rejects any remaining NES I/O access at build time.

## Progress

Calls from game code into the layer over the 30000-frame random-1 run (hwprof): about
330k before (2026-11-21 start: `$2007` 164k, `$4016` reads 139k, APU 71k, bank
register 66k, ...), about 130k after the first batch (n6), less after n7.

Done (each checked with firstdiff DMG + CGB, random 2, the save scenario, lagcheck):
- **Joypad** (fix:DBA9 -> `$20`, fix:FC38-FC4F -> `$35`): one read of the GB buttons into
  the same RAM bytes, bit order as the NES serial read (`hle_pad20` / `hle_pad35`,
  rt/selmenu.s). No `$4016` strobe / serial reads remain.
- **Bank register** (fix:FE1A, switch prg bank): `hle_bank` sets the GB data bank directly.
- **Palettes** (fix:DC30 all 32 entries, fix:DCB5 the 16 BG entries): straight into the
  palette shadow / CGB palettes / DMG shading state (`gb_pal`), no `$2006` / `$2007`.
- **Scroll** (fix:FD4B, FD60-FD6B, CDF5): scroll / control state set directly.
- **Sound output** (b13:9C1F, the music engine's per-channel shadow to the APU): native loop
  calling the GB sound driver per register (`hle_apuout_b`); no `$4015` read emulation.
  The other sound writes (sound effects: cursor, door, battle noise) already compile to a
  direct call of the sound driver with the register as a constant (no address decoding),
  which is what a native effect routine would do; they stay as they are.
- **Text output** (fix:F069 copy text to ppu, with the layout's one-row mode): both text
  rows straight into the nametable shadow and the GB map (`hle_txrow_b` + `nt_copy`).
- **Window rows** (layout ntwin, every menu window: one row per frame): the row drawing
  is split out as `ntrow` and native (`hle_ntrow_b`).
- **Prologue / prophecy lines** (layout pframe): line + attribute row native (`pfdraw` ->
  `hle_pdraw_b`).
- **Dialogue window attributes** (fix:D2FE / D308) native (`hle_dlgatt_b`).
- Frame waits (fix:FA2A / FEAD), the native CHR copy and the native nametable clear set
  the PPU state directly instead of calling the `$2002` / `$2006` entries.
- OAM tearing fix: the OAM conversion clears `oam_pending` at its start, so a V-Blank
  DMA never copies a half-built shadow (field sprites missed a frame in catch-up frames).

Building blocks (for the next routines): `nt_copy` (rt/native.s, bank 62: a run of bytes
to a NES nametable address, +1 / +32, optional fill; skips cells that already hold the
byte like the generic path), `gb_pal`, `gb_scroll`. Banked native routines are entered
from translated code in place (translator `ext` names `far:<label>`: `call rt_fcs / db
bank / dw label`, no bank-0 stub; bank 0 is full). `rt_fcs` is a tail call: it returns
to the caller of the routine that contains it.

Next by count: the boot splash glyphs (fix:F59F-F689, once per boot), the remaining layout
screens (b24 portraits / rows, b23 lists), field map / battle CHR paths, `$2000` / `$2001`
/ `$2005` writes in the layout's `scroll` routine, the battle OAM sites (`$2003` + `$4014`).

## Checks for each step

firstdiff random 1 (30000) DMG and CGB with PPU=1 (nametable shadow) while the shadow
exists, random 2, the save scenario, battle formations; screenshots (DMG / CGB / SGB);
lagcheck (0% slowdown rule). Progress and counts in docs/ff2-gb-status.md.
