# FF3 GBC: from "the NES running on a Game Boy" to native Game Boy code

**Mandate (owner, 2026-11-20): the Game Boy Color must not emulate the NES while the game
plays.** Goal: no translated routine calls the NES-hardware layer (`rt_ppu_*`, `rt_io_w4014`,
`rt_mmc_*` banking / IRQ, `rt_apu_w`); every drawing, sprite, bank and sound routine of FF3 that
touches NES hardware gets a native Game Boy Color version written from the disassembly. Progress
is measured by `tools/gb3/nesmap.py` (static call sites left, and their share of GB time).

Owner (2026-11-20): use the FF3 disassembly (everything8215/ff3, fetched to `build/src/ff3`,
never committed) to reduce, and where possible eliminate, the need for the NES to run on the
Game Boy; the NES ROM should only be the input of the build. This refines the native-presentation
decision (`docs/gb-native-presentation.md`) for FF3 and keeps every rule there: game bytes come
from the user's ROM at build time, nothing game-specific in the repo, the RAM check against the
NES (`tools/gb3/firstdiff.py`) guards every replaced routine.

## What still "runs the NES" (measured)
`tools/gb3/nesmap.py ROM [PROFILE]`: the translated code's calls into the NES-hardware layer and
the 6502 glue, by disassembly routine, and the share of GB time per routine (profile:
`LAG_OUT=FILE SGBRUN_PROF2=2000 SGBRUN_PROFC=1 SGBRUN_PROF_SP=1 lagcheck.py ... --resync`).

Explore script, waits 2000-12000, mGBA CGB (2026-11-20, before / after the native OAM clear):
| Class | share of busy GB time |
|---|---|
| translated game code | 40% -> 32% (the OAM clear loop was 11%) |
| PPU layer (`$4014` sprite page conversion 10%, `$2007` 7.5%, `$2006`, tile DMA, map flush) | 20-22% |
| 6502 glue (indirect / banked reads, flags, farcalls, dynamic-target lookup, `jp hl`) | ~20% |
| natives (already GB code) | 5-8% |
| NES sound engine (bank $36: channel scripts, envelopes; its APU writes are dropped) | ~12% |
| MMC5 banking / IRQ shims | ~2% |
Idle time is ~2%: the CGB runs near its limit, so every replaced layer is speed headroom too.

Static: 673 PPU call sites, 58 APU, 25 MMC5, 1763 glue calls in the translated code.

## Order of work
1. **OAM clear** (fix:C486, every frame): native `nat_c486` (done 2026-11-20, -9% busy time).
2. **Text and windows** (menus first; 2026-11-20: the one-row line flush is native, `nat_h1`,
   with the condensed names; windows / screen init next): the line printer (fix:F692 "draw one line of text"), the
   window frame drawer (3D:AAF1 / fix:F44B), the menu screen init (fix:F7BB): native routines
   that write the GB map (and the attribute cells) directly from the text buffer $0780 / $07A0,
   with the NES's RAM results kept (buffer, $1F / $90 counters, nametable shadow only where the
   game reads it back). The condensed names (owner's request) are made here: names in lists and
   menus packed into condensed tiles as the line is written.
3. **Native music driver** (2026-11-21: the output stage is native, `snd_*`; the script /
   envelope logic is still translated): plays FF3's own song and sound-effect scripts (format: bank $36
   routines "execute sound command", "update volume / pitch envelope", "init song") on the GB
   channels (pulse 1 / 2, wave for the triangle, noise), interface kept: $7F40-$7F49 (song id,
   flags, sound effect id, "playing" bit) as the game reads and writes them. Removes ~12% and
   gives FF3 sound (none today).
4. **Water animation** (done 2026-11-21): 3A:858F update / 3A:866E init are native (`far_858f`,
   `far_866e`): the two CHR bytes per step go straight into the GB tile store (`chr_put`), the
   buffers are built from it (`chr_get`) - no `$2006` / `$2007`; this also fixed the blank water
   (the NES layer's CHR read-back returned 0). Address tables from the user's ROM at build time
   (`build.py water_src` -> WATER_T). RAM: firstdiff explore 12000 identical; map 6 (water) via
   `--poke 5305:0048=06,0050=01`: identical, PRG-RAM $7300-$7FFF identical but two sound flags.
   Bank 0 headroom for it: the boot set-up (`far_boot`) and two RAM-only natives (`far_966a`,
   `far_bd2a`) moved to the runtime tables bank (~300 bytes free). Natives must leave B = D = 0.
5. **Field map drawing** (fix:E1DC map main, fix:CA79 update map background, door / chest tile
   updates fix:E715): native row / column writer into the GB map (as FF1's DrawMapRowCol).
6. **Sprites**: object / character sprites (fix:DA3A draw object sprite, 3C:8198 draw sprite,
   32:9FE4 battle status sprites) straight into GB OAM; the `$4014` page conversion only where
   the game's own OAM page stays.
7. **Battle graphics and screen loads**: monster tilemaps (2E:9FAA), summon / fight effects, the
   prophecy / cutscenes: tiles converted at build time, copied with HDMA.
8. **Glue**: translator reads ROM data directly (banked pointers), same-bank placement of hot
   code and data, fewer farcalls; the dynamic-target lookup for the remaining indirect jumps.
Each step: measure (nesmap profile), replace, firstdiff (explore 12000 + the menu / save / job /
magic sequences), lot-check monitor (`SGBRUN_LOTCHECK`), screenshots.

Profile 2026-11-21 (explore 2000-12000, mGBA CGB): busy time by runtime routine - `rt_ppu_w7`
($2007 writes) 9.5%, `rt_io_w4014` (sprite page conversion) 8.7%, `rt_jp_hl` 5.3%, `rt_lda_nes`
2.8%, `hd_flush` 2.7%, `lookup` 2.7%; translated game code 29%, PPU layer 22%, glue 10%. Next:
the sprite page (step 6) and the field map / text writers that feed `rt_ppu_w7` (steps 2, 5).

## What stays NES-like for now
- Game logic (battle formulas, events, RNG, menus' logic): recompiled from the user's ROM (the
  owner's decision); the RAM check needs it.
- The NES emulator (cynes) remains a development-time reference for the RAM check only; nothing
  in the build or on the Game Boy depends on it.
