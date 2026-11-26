# What made FF1 fully native, and how FF2 / FF3 can reuse it

FF1 for Game Boy is now 100% native code (`tools/gbn/`, ~45,000 lines of our own SM83 and
Python): no NES CPU, PPU, APU or mapper is emulated. This file sorts what we built into what
FF2 and FF3 can take as it is, what they can take with their own data, and what is FF1's alone.
It also records the method, because that is the part most likely to carry over.

FF1, FF2 and FF3 were all programmed by Nasir Gebelli on the same family of engines. Our notes on
FF2 and FF3 (`docs/ff2-engine-notes.md`, `docs/ff3-engine-notes.md`) already show FF3's routines
mapping one to one onto FF2's, and FF2's field and text code is a descendant of FF1's. So much of
what FF1 needed is likely to recur, but **every "same as FF1" below is an expectation to check
against the game's own disassembly before relying on it.**

Related reading: `docs/ff1-native.md` (the FF1 plan and the item-by-item log),
`docs/gb-lessons.md` (traps and how we found them), `docs/gb-video-improvements.md` (the
WonderSwan-inspired additions and how to rebuild each), `docs/gb-release-checks.md` (Lot Check).

## 1. The method (carries over unchanged)

1. **Read the disassembly for meaning, never copy code.** Each FF1 routine was rewritten from
   what the disassembly says it does (Entroper/FF1Disassembly in `build/ref/`, matched to the
   Japanese ROM). FF2 / FF3 have everything8215/ff2 and /ff3.
2. **Data only from the user's ROM, at build time.** `data.py`, `battle.py`, `ui.py`,
   `talkconst.py`, `minimap.py`, `sound.py` know *where* the ROM keeps each table and *how* to
   convert it; they hold no game bytes. Even constants inside game code (talk routines' object
   ids, item addresses) are read from the ROM's own operands (`talkconst.py`).
3. **Convert at build time, not run time.** Tiles to GB format, DMG shading per map, maps
   decompressed, pictures' extents, water animation frames, reflection masks, hand positions:
   all computed by the build, so the engine only copies. This is what makes 0 lag possible on
   the plain Game Boy.
4. **Audit the data** against the disassembly (`audit.py`): every table the build reads,
   compared with a trusted source, mismatches explained.
5. **Test like the hardware is strict.** The SameBoy core with our patch
   (`tools/gb/sameboy/sameboy-ffe.patch`, `SB_LCHK=1`) reports every VRAM / OAM / palette access
   outside its window. Keep it at 0 on DMG, CGB and SGB after every change.
6. **Look at the picture, frame by frame, on every system.** Most bugs this project found were
   seen, not computed (`docs/gb-lessons.md`, "Native rewrite").

## 2. Build tooling (reuse as is)

| Piece | What it does | For FF2 / FF3 |
|---|---|---|
| `tools/gb/asm_sm83.py` | Our SM83 assembler: banks, sections at fixed origins, overlap errors, `.sym` / `.lab`, header and checksums, `jr` relaxed to `jp` | As is |
| `tools/gbn/build.py` skeleton | NES ROM -> data banks -> sources assembled -> 2 MB MBC5 ROM; `GBN_GAPS` lists free space per bank; test options `--start`, `--battle`, `--shop`, `--init`, `--enc 0`, `--release` | Copy the skeleton; the data functions are per game |
| `tools/gbn/rammap.py` | WRAM/HRAM map from the sources, overlaps and free gaps | As is |
| `tools/gbn/xbank.py` | Finds calls into another ROM bank that would crash | As is |
| `tools/gbn/sndref.py` | NES reference audio from the register writes, to compare songs | Per engine; method as is |
| `build/sbsh` + SameBoy core | Scriptable emulator driver: frames, keys, pokes, RAM reads, shots, VCHK | As is |
| SameBoy strict checker | Lot Check access rules on every frame | As is |
| Gambatte runner (`build/gbrun`) | Hardware-like timing for lag measurement | As is |

## 3. Engine modules: generic (lift with little change)

These know nothing about FF1's rules; they are the Game Boy side of an RPG.

| Module | What it gives | Notes for reuse |
|---|---|---|
| `src/pal.s` | One palette system for every scene: WRAM shadows of all 16 Color palettes, V-Blank upload, fades that never read the screen back, DMG BGP / OBP shades | As is. FF3 (Color only) drops the DMG half |
| `src/cc.s` | LCD colour correction (Default / GBC / GBA) applied where palettes are written | As is |
| `src/sgb.s`, `src/sgbx.s`, `sgb.py` | Super Game Boy: detection, packets, per-screen palettes, border by region, SNES sound effects | FF2 as is (with its own border / regions); FF3 has no SGB |
| `src/text.s` + `text.py` | Our Latin font (VRAM bank 1 on the Color; per-map free tiles on DMG), window frames from the ROM, dialogue box with typewriter text, page breaks, word wrap at build time | Font and box as is; the text decoder's control codes are per game (FF2/FF3 codes are listed in their engine notes) |
| `src/screens.s` | Screen framework: `scr_open` / `scr_win` / pen / `scr_show` / `scr_upd`, rows uploaded in V-Blank, hand cursor rule, fades between screens, masked Color loads | As is: every menu in FF1 is built on it |
| `src/ul.s` | Rounded black outlines under party pictures on menus | As is |
| `src/packs.s` (`yn_ask`) | Yes / No asked in place over any screen | As is |
| `src/loc.s` (parts) | Place-name banner, play time, Config pages, three save files, suspend point, Lot Check save checks | Framework as is; option list per game |
| `src/extras.s` | Sound test, bestiary (records kept across saves) | Framework as is; data per game |
| `src/refl.s`, `src/wanim.s` | Reflections cut to water pixel by pixel; animated sea / rivers / town water; masks and frames made at build time | Algorithms as is; the water metatiles come from each game's tileset |
| `src/air.s` | Airship's perspective view (raster SCY per line, sky band) | As is if the game has an airship view (FF2, FF3 both fly) |
| `src/fx.s` | Raster spell effects on the enemy area (ripple, shiver, tear, quake, wave by element) | As is; element mapping per game |
| Lot Check pieces | Soft reset in every state, checksummed saves with error screens, cart RAM enabled only around access, boot clears memory | As is |

## 4. Engine modules: same idea, game's own logic (rewrite from the disassembly, reuse the shape)

| FF1 module | FF2 / FF3 expectation |
|---|---|
| `src/main.s`: boot, maps 64 x 64, overworld 256 x 256 rows, metatiles, teleports, doors / rooms, walking, vehicles | FF2's field engine descends from FF1's (to verify: map sizes, metatile format, teleport tables). Our map loader, metatile queue and V-Blank drawing should carry over; the data readers change. |
| `src/objects.s`: 15 object slots, movement, facing the party | Likely close in FF2; check slot count and movement rules. |
| `src/talk.s` + `talkconst.py`: talk routine kinds, constants read from the ROM's operands | The technique (read constants from the ROM's code) carries over; FF2's keyword system (Ask / Learn) is new logic. |
| `src/snd.s` + `sound.py`: FF1's music engine as native code, song data from the ROM, output straight to GB channels, timer at 60.0988 Hz, DMG volume-step and wave-RAM workarounds | The GB output side and all the hardware workarounds carry over unchanged. The sequencer must be checked against FF2's / FF3's own sound driver (to verify how close it is to FF1's). |
| `src/menu.s`, `src/shop.s`, `src/pgen.s`: menus, shops, party creation | Layouts and the screen framework carry over; contents are per game (FF2 has no jobs; FF3's job menu replaces the class picker). |
| Battle (`btl*.s`, `battle.py`) | The **presentation** carries over: the approved layout, small-font message renderer, damage numbers, CRITICAL!, flinches, enemy flashes, deaths, target hands (now from pictures' real edges, worked out at build time), names window, top window for spell names. The **rules** are each game's own (FF2's skill growth, FF3's jobs and multiple formations). |

## 5. FF1-only (do not carry over)

FF1's class / job rules, its spell list and charge system (and our Modern MP option, which is
Dawn of Souls data for FF1), the 15-puzzle, FF1's story scenes and ending sequence, the Packs
screen (FF1's per-member inventories; FF2 / FF3 use a shared bag), and FF1's own bug fixes.

## 6. Hard-won rules worth repeating

All of these cost real time on FF1; details are in `docs/gb-lessons.md`.
- VRAM writes only in lines 144-151 with interrupts off from the line test to the end of the
  copy; a 16-byte block started at line 152 crosses into the next frame.
- On DMG, LY reads 0 during line 153: never treat 0 as "early in the V-Blank".
- Never let a wait depend on a V-Blank window that may never come (DMG results softlock).
- A RAM table that runs past a page end wraps its low byte (the reflection garbage and
  world-map slowdown).
- Any per-frame rewrite of LCDC (line handlers, `ly_base`, `lcdc_on`) undoes a direct LCDC
  change: change the copies too.
- Build-time tables must be computed after every setting they depend on (the town reflection
  table was built from a default font, which left Onrac without tiles).
- Bank 0 fills up first: keep helpers small and put bodies in banked code behind `bank_call`.
- After any fix, look at the picture again on every system.

## 7. Suggested start for FF2

1. Reading list as in `docs/ff2-gb-brief.md`, then this file.
2. Owner's decision first: native rewrite (as FF1) or the disassembly source as the base (the
   current binding decision for FF2 / FF3 in `CLAUDE.md`). FF1's experience: the native
   rewrite reached 0 lag on DMG and literal Lot Check 2.3 compliance, which the recompiled
   build could not.
3. Copy the build skeleton, the generic modules (section 3) and the test tools; get a boot
   screen, the font and one map on screen in all three modes.
4. Field (maps, walking, objects, text) next, then menus on the screen framework, then battle
   presentation with FF2's rules, then music.
5. Keep the strict checker at 0 and run the random-play monkey on every system from the first
   playable build.
