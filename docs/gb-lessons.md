# Game Boy port lessons (FF1 → FF2 / FF3)

Findings from the FF1 port that the FF2 and FF3 ports should apply from the start instead of
rediscovering. Newest first. Each item: what went wrong (or what was slow), why, and what fixed
it in FF1 (file / routine names in this repo).

## Real-hardware findings (owner, EverDrive, 2026-11-19)

- **Garbled letters / tiles on the Color: tile DMA during drawing.** Marked BG tiles go from a
  WRAM copy to VRAM by general-purpose DMA in the vblank. The mark scan called a subroutine
  per tile (~40 cycles), so a 128-tile run spent ~40 scanlines before its DMA started; by
  then LY had wrapped and the DMA ran during drawing, where VRAM writes are dropped (every
  second row pair of a letter lost). Fix (`hdma_bg`): scan the marks a byte (8 tiles) at a
  time, clear marks a byte at a time, start a DMA only while LY is 144-151, and budget 12
  tiles per remaining line (a DMA moves 16 bytes per 32 dots: 14 a line). Check VRAM against
  the tile copy in SameBoy (`GBRUN_VRAM=1`, `SHOTS_KEEP=dir`): it must match at every
  checkpoint. A time check must reject LY < 144 as well as LY > 151.
- **Raster-split effects belong in the window layer.** FF1 builds the dialogue box in the
  other nametable and reveals it with a split growing down to scanline `$1B`; the GB keeps
  one map for both nametables, so the box was drawn over the field row by row and the map
  redrawn after (stilted, slow). Now the box's cells go to the GB window map (`dlg_cell`,
  `$5805` on/off) and the window is switched off at the (scaled) split line each frame. The
  map under the box is never touched. FF2/FF3 use the same kind of box.
- **Check that runtime work-RAM variables do not overlap.** A debug word (ISR_PC) sat inside
  the DMG re-coding masks (RM, 9 bytes): a vblank during a re-coding corrupted that tile.

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
- **Frame wait: take the vblank count on entry**, before any spare-time work the wait does
  (DMG shading checks, tile re-coding). Taken after it, work that ran past line 144 made the
  wait sleep to the *following* vblank and lost a whole frame (the NES NMI comes during its
  wait loop). This alone halved the town-walk lag on DMG.
- **Flag liveness across unknown edges**: treating every flag as live at returns to unknown
  callers made every ADC/SBC compute V (265 + 102 helper calls). FF1 reads V in a handful of
  places; with PHP..PLP pairs (and PHP/PLA/AND/PHA/PLP masks) modelled and static-flow
  "readers" inside executed instructions ignored, V is provably dead at unknown edges and all
  of them compile to plain arithmetic (recomp.py `liveness`, prints its verdict).
- **Frame wait: check and halt with interrupts off** (`di` / check / `halt` / `ei`). A plain
  check-then-`halt` loop loses a whole frame whenever the vblank interrupt lands between the
  check and the `halt` - which happens when another interrupt (here the LCD-off frame timer,
  left running with the LCD on) wakes the wait just before the vblank. It looked like random
  frame-alignment noise ("a faster routine made lag worse"); fixing it gave CGB -2, DMG -3
  frames on the script. Use `SGBRUN_PROF_LY=1` (LY with each sample) to see such a frame.
- **Batch, don't go per cell**: DrawMapRowCol (64 tiles), the battle panel rows (25 cells)
  and the sprite conversion (64 entries) were 150-250 cycles per item through the generic
  nametable path. Batched writers (`mdf_row/col`, `nrf`, `oamconv_b`) do the shadow in runs,
  owner bits 8 at a time, VRAM two cells per STAT poll. Check preconditions exactly (an
  "own1 == 0" shortcut never held in battle: test the run's own owner bits).
- **The GB has ~59% of the NES's cycles per frame on DMG** (17,556 M-cycles vs 29,780):
  native routines must be well under the 6502 cost, and runtime overhead per frame (sprite
  conversion, OAM clear, indirect reads) is the budget everything else shares.
- Profile by cycles, not instructions (`sgbrun` SGBRUN_PROFC=1 SGBRUN_PROF2=N); profile only
  the waits that lag (SGBRUN_LAG + a list of waits); and remember a helper's [SP] is not the
  caller when it pushes first (use a PyBoy hook at its entry instead).
- **Prove every speed change on the picture**: build the old path behind a switch
  (`GB_MDF=0`) and compare SameBoy VRAM, shadows and owner bits at many points
  (scratch `vramcmp.py` approach). It caught a fast path that wrote the STAT value instead of
  the tile (the poll reuses A) - RAM checks cannot see that.

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

- RAM checks do not see the picture, and the input scripts skip the prologue with a button.
  Two picture bugs went unnoticed for days because of that (found by the release matrix,
  2026-11-21): the SGB prologue text was invisible (a DMG-only shortcut also skipped the SGB
  attribute packets), and on the CGB the prologue's second page stayed black (the vblank
  spent itself on palettes every frame of the fade, so a masked load's tile copy was always
  late and the mask never lifted). Before a release, boot each model with no input and look
  at every screen in each mode, including the ones the scripts skip.
- Run the full checkall before every commit, not a subset: six DMG menu checks differed for
  ten commits (a text-code read through the ROM read-ahead) and only the full run showed it.

## Layout / camera

- When the field camera changes, re-check every screen laid out for the old one (title menu,
  world map, FORMATION). Screens that set their own camera must restore the field camera on
  every exit path (FF1's shop returned without a screen clear: `shopw` stub).

## Release requirements (all ports)
Every port must meet the Nintendo Lot Check standards in `docs/gb-release-checks.md` before
any release (owner, 2026-11-20). Design for them from the start in FF2/FF3: keep save data
apart from working buffers (cart RAM disabled after each save access), clear memory at boot,
soft reset, LCD/VRAM/OAM timing, no debug code in release builds, and for FF3 a "Game Boy
Color only" screen on older systems.



## Native rewrite (2026-11-21)
- Test from power-on the way a player does (title, New Game, every screen in order) before
  handing over a ROM: test builds that start on the field (`--start`, `--battle`) skipped the
  party creation, where the first native ROM had wrong job pictures, misplaced names and the
  wrong default party. Compare each screen with the NES (cynes shots) for layout, colours and
  animation, not only for "it runs".
- Masked loads on the Color (native engine): with code that writes VRAM directly all over a
  load, a mode-2 STAT interrupt that spins until mode 0 makes every write safe without
  touching that code (the CPU only runs in mode 0 / V-Blank). Costs: ~half the CPU during the
  load (fine at double speed, far too slow on a DMG: a town entry took 73 frames instead of
  13, so DMG / SGB keep the LCD off); pause the guard around long RAM-only work and wait for
  mode 0 / 1 when resuming. Palette RAM ignores writes in mode 3: start the 64-byte palette
  read-back / restore early in the V-Blank (LY 144-147), not after a long V-Blank handler.
  Restore the scroll registers with the palettes, or the first frame shows the old scroll.
  Measure load times against the NES itself (cynes, frame by frame) before and after.
- Check every new screen against the NES picture (tools/gb/formations.py / battleshot.py give
  NES reference shots) on both CGB and DMG before calling it done. The fiend / Chaos battle
  shipped with swapped cell nibbles and an off-by-one attribute row because only one mode was
  looked at, and only at a glance.
- Keep the V-Blank interrupt short: VRAM uploads that wait for lines 144-151 starve if the
  handler does other work there (the music engine in V-Blank froze DMG battles). Non-VRAM work
  (music) runs from the line-64 STAT interrupt.
- Look at several frames after an input, not one: a window that "looks fine" at one frame can
  still take 40 frames to settle or never settle.
- PyBoy runs a dual-mode cart (header $80) as a Game Boy Color unless `cgb=False` is passed:
  a "DMG" check in PyBoy without it tests the CGB path.
- A "fix" isn't done until the picture that showed the bug has been looked at again: the DMG
  white boxes behind large enemies survived a first fix aimed at the wrong cause (the real one:
  a row counter overflowing at 36 tiles).

## Music: check the engine and the sound hardware separately (2026-11-22)
- **Engine first, exactly:** run the game's own music code (6502, from the ROM) in py65 from the
  GB engine's RAM state at a frame and compare the next frames' channel RAM and register values
  (FF1: every song, fresh and after the town theme: identical). Audio comparisons cannot prove
  this: pitch detectors pick harmonics, envelopes repeat every note so alignment slips by one.
- **Measure audio robustly:** downsample very high-rate recordings first (SameBoy writes 2 MHz:
  FFT bins of 64 Hz), cut frames at each machine's own rate (NES 60.10, GB 59.73 per second),
  align by the pitch sequence, take levels from percentiles (a DC step inside a frame doubles a
  peak-to-peak value), and run parallel jobs with separate output names.
- **"Zombie mode" (NRx2 = $08 adds 1 to the playing volume) is right on hardware, SameBoy and
  Gambatte, but mGBA 0.10 ignores it in Game Boy Color mode:** every volume change inside a note
  is lost there (garbled envelopes, sustained decays). The native FF1 build tests it at boot on a
  Color (a silent note, PCM12 read before and after one $08 write: 1 -> 2 works, 1 -> 1 not,
  anything else = PCM12 unreadable, keep zombie mode) and otherwise changes volume by a restart
  with the new level (mGBA's restart keeps the duty position and timer: no pitch loss there; on
  hardware a restart reloads the timer: ~10-20 cents flat at FF1's change rate, so not used).
- The hardware ignores a zombie write until the envelope clock's first tick after a restart
  (1/64 s): a test must wait. Some Color revisions read PCM12 wrongly in double speed.
- mGBA's sound output has no high-pass filter: volume steps show as low-frequency content in
  any measurement (Game Boy mode too); compare like with like.

## Banked code: cross-bank calls and bank-switching helpers (2026-11-22)
- The assembler does not know banks: a `call` into another switchable bank assembles and then
  runs whatever that address holds in the mapped bank. Moving FF1's Options to bank 99 left
  the title calling `opt_save` from bank 2: New Game broke only after a soft reset.
  `tools/gbn/xbank.py SYM` lists every call / jp / jr into another bank; after moving code,
  the only entries left should be bank-0 code calling a bank that is mapped at that moment.
- A bank-0 routine that switches the ROM bank and does not restore it (`text_pals` used to
  select the common bank) is safe only from bank 0; called from a banked module it returns
  into the wrong bank (a white screen at boot). Keep such helpers bank-neutral (data in RAM)
  or restore the bank.
- Functions that answer with a flag need it set at every exit: a loop that falls through
  `cp N / jr c` leaves carry clear (FF1 `sv_any` said "a save exists" with none).
- Find free space by runs of $FF in the built ROM per bank, not by the last label: bank 0 had
  ~1.7 KB free after the screen framework.
- Video study for new features (docs/gb-video-improvements.md): sample every frame at 2 fps,
  then 60 fps around the moments that matter (an attack, a death, a transition), and measure
  timings in frames before writing code.

## Shared work RAM (2026-11-22)
- Reusing another module's RAM is safe only for variables that module sets before every use.
  The gradient's event lists first went into the battle's RAM; one byte there (`vw_spr`, "draw
  text as sprites") is never reset by the battle, so every battle message turned grey. List
  each region's variables and their initialisation before sharing it.
- Sum the `ds` sizes per `section wram` and check the sections for overlaps after adding
  variables: a new buffer at $CDE3 overlapped the last byte of the screen module's section (the
  name entry's letter case).
- Palette writes on the Color are ignored in mode 3: a per-line effect writes in the H-Blank of
  the line before (LYC one line early, then wait for mode 0); whole-palette fades rewrite every
  colour, so pause per-line palette effects during a fade.

## Memory corruption: find the writer, do not guess (2026-11-23)
- **A callee that uses a loop counter register as scratch turns the loop into a RAM walker.**
  `obj_anim` (the map objects' step) used B as scratch; `obj_frame` loops over the 15 slots with
  B. A finished step set B to the object's y, so the loop ran on through RAM in 16-byte
  "objects", copying bytes +2/+3 to +4/+5 and clearing +8/+9/+13 wherever byte 0 was non-zero:
  the dialogue / banner text buffer and font table ($CB00-$CCFF, broken message window and place
  name), game flags, and with y = 0 (B wraps to 255) the party records at $D100: names
  "Todd -> ToTo", "Rienne -> RiRine", weapons erased (the Warrior's record starts with class 0,
  so the loop skipped it). It depended on townspeople's timing, so scripted runs missed it for
  days while the owner saw it every session, and it looked like a shop / save / transition bug.
  Save every register a loop keeps across a call, in the callee or at the call.
- **Find the writer with a write watchpoint.** `build/sameboy_watch.so`: the SameBoy libretro core
  with a write callback (scratch SameBoy tree, libretro.c patched): `SBSH_CORE=build/
  sameboy_watch.so SB_WATCH=CC14-CC18 build/sbsh ROM` prints every write to the range with PC,
  ROM bank, SP and the stack's top return addresses. Dump the suspect RAM (sbsh `r`), diff it
  against a clean run, watch the changed bytes, map the PCs with the .sym file. The offsets of
  the damaged bytes (here: +2..+11 of 16-byte records) often name the structure doing it.
- **Variables that other screens read must not share the map's metatile queue** ($C100-$C8FF,
  unioned with battle / shop / menu RAM): walking writes queue entries over them. The battle's
  name-window flags (`ban_on`, `ban_attr`) lived there and the field's window code read them:
  sprites hidden under the window and a junk window palette in towns. List, for every shared
  region, which files read each variable (a script over the .lab and the sources does it).

## Moving code breaks fall-throughs and registers (2026-11-23, later)
- **A routine that ends by falling into the next one breaks when either moves.** `bt_lvchk` ended
  with `ret c` and fell into `bt_levelup`; moving `bt_levelup` for room made it fall into
  `bt_rf`, which returns: no level ups at all, for a whole release. End every routine with an
  explicit `jp`/`ret`; before moving code, search for labels that nothing calls (a script over
  the .sym and the sources lists them: here `bt_levelup` had no callers).
- **A call inserted at a routine's top can clobber its argument.** `call bt_ban_off` at the top
  of `bt_erase_enemy` overwrote A (the enemy's slot), so the dissolve and the erase hit other
  cells and the dead enemy came back with the next row refresh. Save the arguments first.
- **`push bc ... pop af` loses a counter:** F keeps only bits 4-7, so a count in C became 0
  (the battle reward loop). Pop into the register you pushed.
- **Records left uninitialised for unused slots** share RAM with the map queue; any loop over all
  slots must not read them. Clear unused slots where the mode starts.
- **Test like a player, from New Game, without pokes:** the owner found these by playing; the
  test builds that start in a battle or a town with a poked save page hid them (levels never
  checked past a test party's fixed level, the reward loop never compared with FF1's sums).
  `scratchpad pt/grind2.py`: New Game, the field, battles fought with Fight, rewards checked
  against FF1's sums from the ROM's enemy data, rests at the inn.

## Hardware traps found by the owner on real units (2026-11-23)
- **Never retrigger channel 3 while it plays on a DMG / Pocket:** a trigger that meets the
  channel's wave RAM read corrupts the first bytes of wave RAM, permanently, so every later
  song's wave channel sounds wrong. Change the frequency without the trigger bit while the note
  sounds; restart only a stopped channel, with the DAC off (NR30 = 0) and the wave RAM written
  again. The Color does not corrupt; SameBoy shows it in DMG mode (read $FF30-$FF3F raw).
- **WX 167 does not hide an enabled window:** with the window enabled and WX parked at 167 the
  window covered the whole frame. Keep the window off (LCDC bit 5) when nothing should show.
- **Test in SameBoy (and Gambatte), not PyBoy** (owner: PyBoy is inaccurate). `tools/gb/sameboy/
  sbsh.c` drives the SameBoy libretro core with the mgsh protocol (frames with keys, bus reads,
  PPM shots, 48 kHz WAV, save states, any model: DMG, Pocket, Color 0-E, GBA).
- **Battle black on the DMG is colour 3**, not 0: effects that blank pixels must use the blank
  tile's own value (read tile 0).
- **Uninitialised WRAM flags bite later:** a "work out silently" flag left at its power-on value
  skipped messages until the first attack set it. Clear new flags where the mode starts.
- **Reset every sound register an effect touches.** FF1's map-change wipe sound turns on square
  1's hardware sweep (NR10 = $1A); the wipe silenced the channel but left the sweep on, and the
  music engine never writes NR10, so every later square-1 note slid down in pitch: "Cornelia
  breaks every song after it" (owner, real Game Boy Color and Chromatic). Found only when the
  owner pointed at the transition sound; my earlier before/after recordings compared two broken
  runs. Now the wipe clears NR10 when it ends and the music clears it at every square-1 note.
  Check: read $FF10-$FF26 raw before and after each effect; compare against a run that never
  plays the effect, not against another run that does.

## Raster lists and guards (2026-11-23, night)
- **A line-interrupt chain loses events on adjacent lines.** Each handler waits for its line's
  H-Blank, then sets the next LYC. When it runs late, the next LYC lands on a line that has already
  begun, and that interrupt never comes: one gradient record was lost every frame (a window's top
  showed the window above's colour). After writing LYC, compare it with LY and handle a reached
  event at once, clearing the STAT request so it is not handled twice.
- **A STAT guard that holds the CPU through modes 2 / 3 halves the main code's speed.** The Color
  masked loads guard VRAM writes that way; a RAM-only computation run during a load (the gradient
  build: 15 frames) should pause the guard (`gd_off`) and resume it after (`gd_resume`).
- **Sound checks across builds or options: compare the sound registers at each V-Blank, not the
  audio samples.** A music tick on another line shifts every sample, while the registers per frame
  must match exactly (the gradient run: equal apart from a cursor beep starting a frame apart).
- **Per-line colour checks:** map each palette value written by the list to the screen colour
  seen; one value showing as two colours means a lost or late record. Take each pixel's palette
  from the attribute map (a shared window border follows its cell's palette, not the window
  drawn last) and the most common colour per line (sprites over windows).
- **Long work inside a line handler (the music) delays the next line events.** Let line events
  interrupt it (IE = STAT only, `ei`; V-Blank must wait when its handler restores a ROM bank the
  long work does not record), and never start it late in the frame: it runs into V-Blank and
  every V-Blank wait behind it (fades, uploads) misses a frame. Do not give it a record of its own
  on the line before another event: attach it to that event, after its writes.

## Timer music, KEY1, wiki data, options that change game data (2026-11-24)
- Music at the NES's rate: drive it from the timer (TAC, TMA with a fractional reload), not from
  V-Blank. A tick that falls near V-Blank must not run there (it held up the V-Blank uploads and
  showed as garbage tiles on the DMG): defer it (`mus_pend`) to a STAT event mid-frame.
- KEY1 ($FF4D) reads $FF on a DMG: test `is_cgb` before reading it (the timer ran at half rate).
- `bank_call` passes only HL (the routine) and A (the bank) and clobbers B: pass arguments in WRAM
  and save BC around it when the caller needs them. A table in another bank is read with
  `far_byte`, never by address from the code bank that happens to be mapped.
- Small fixed tables from outside sources (the wiki's Dawn of Souls MP data) go into the
  repository as tool data (owner, 2026-11-24): never make the builder download anything.
- An option that changes how game data is read (Modern MP) keeps a per-member "mode" byte in the
  save page: a file saved in one mode and loaded with the option set the other way is converted
  on first use (battle start, Magic / Status screens, Options). Options are global, files are not.
- Test scripts: the RAM-backed "in battle" test (ROM bank 6 mapped) is false during bank-switched
  animations: confirm over several checks before deciding a battle ended.
