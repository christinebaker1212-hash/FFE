# Game Boy port lessons (FF1 → FF2 / FF3)

Findings from the FF1 port that the FF2 and FF3 ports should apply from the start instead of
rediscovering. Newest first. Each item: what went wrong (or what was slow), why, and what fixed
it in FF1 (file / routine names in this repo).

## Real-hardware findings (owner, EverDrive, 2026-11-19)

- **Lock-ups from dispatch targets that testing never reached.** FF1 picks talk routines,
  tile effects, shop types, spell effects and text control codes through jump tables
  (`JMP (ind)` and push-push-RTS). The recompiler only compiled table entries that the
  coverage runs had executed: 99 of 128 map-object (talk) routines, 15 of 19 spell effects,
  15 of 16 tile effects and 4 of 11 ExRAM text control codes were missing, so the GB halted
  on the first person / spell / code nobody had used in testing. Fix: every entry of every
  static jump table is compiled and registered (`recomp.FF1.jump_tables`, `CodeMap(tables=)`;
  ExRAM RTS-dispatch targets listed by `insert.py` in `<rom>.far` as `ex:` lines).
  **FF2/FF3 with disassembly sources:** make sure every routine a table points to is
  translated and reachable, and never let an unknown target halt silently.
- **LCD off shows white on a real GBC** (and blank on DMG). Screen loads that switch the LCD
  off flash white between screens; the NES shows black. (Being fixed: keep the LCD on and
  black during loads.)
- **Battle music briefly sped up on damage.** The NES game itself lags (2 NES frames per
  game frame) on heavy battle frames; the GB reproduced that, then its catch-up pacing ran
  the next game frames back to back, and the music driver (called once per game frame)
  rushed. Only cycle-accurate emulators (Gambatte, SameBoy) show it; mGBA does not. Fix:
  the driver's APU writes go into a per-frame snapshot, queued at each frame wait, and at
  most one queued frame is applied per vblank (`apu.s` APQ, `apq_apply_b`). Sound now runs
  at a steady 60 Hz whatever the game-frame pacing. Use this from the start.
- **A missing `jr` in the native CHR upload** (Color, LCD on) wrote BG tiles over the sprite
  shadow and left WRAM bank 2 selected (hangs, sprite corruption). Check every bank switch
  (`$FF70`, `$4000`, `$2000`) is undone on every path; test the LCD-on paths explicitly.
- **Cart RAM**: use at most 32 KB (4 banks, as retail MBC5 games); clones / old flash carts
  may not bank more. Check at boot that the banks are separate and say so on screen.
- **LCD off is white on a real GBC.** Keep the LCD on during loads behind a black mask (window
  layer, a black palette); write VRAM only in STAT mode 0/1; let bulk fills update shadows
  and rebuild the map / attributes in one pass when the screen is shown (`maprb_b`,
  `repal_b`). Cost here: CGB loads +0.4% of play time.

## Speed

- **Raster-timing busy loops are pure waste on the GB.** FF1 waits out scanlines every frame
  a dialogue box shows (c62:D6B8, a split timed by delay calls), so towns ran up to 75%
  slower on DMG. Replace such loops by their RAM side effects only (`rt_dlgdelay`, as
  `rt_band` for the map-transition band).
- **CGB loads**: with the LCD off, don't recompute cell palettes on every nametable write or
  attribute write; mark them stale and do one pass when the LCD goes on (`repal_b`).
  Whole-nametable clears in bulk on both DMG and CGB (`ntclr_b`, `nf_whole`).
- Measure with Gambatte (`tools/gb/lagcheck.py`) on DMG *and* CGB, in battle, field, towns
  with dialogue, menus and the intro. "Walking keeps pace" on the overworld said nothing
  about towns.
- The dynamic-target lookup must not be a linear search in bank 0 (it overflowed and was
  slow): buckets by low byte in its own bank (`dyn_buckets`, DYN_BANK 61).

## Testing

- **Emulators**: Gambatte (libretro, `build/gbrun`) and mGBA (`build/sgbrun`, SGB) are good;
  **SameBoy** is the closest to hardware: build its libretro core (needs RGBDS:
  `git clone --branch v0.9.1 https://github.com/gbdev/rgbds`, `make rgbasm rgblink rgbfix
  rgbgfx`; SameBoy `make bootroms` first, then `make libretro`; a tiny `hexdump` stand-in if
  missing) and run it with `GBRUN_CORE=build/sameboy_libretro.so build/gbrun ...`
  (`sameboy_model` option set by gbrun; WRAM zeroed after load since SameBoy runs a boot ROM).
- RAM equivalence (`firstdiff.py`, `checkall.py`) proves logic, not the picture: compare
  GB frames with NES frames too (scratch `cmpframes.py` approach: same input, NES picture
  cropped to the camera, CGB colours equal the NES palette).
- Random play does not talk to people or cast rare spells: dispatch tables need explicit
  coverage (see above), not luck.

## Layout / camera

- When the field camera changes, re-check every screen laid out for the old one (title menu,
  world map, FORMATION). Screens that set their own camera must restore the field camera on
  every exit path (FF1's shop returned without a screen clear: `shopw` stub).
