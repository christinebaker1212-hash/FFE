# FF3 GB core rewrite: FF3's own program, routine by routine

Owner's decision (2026-11-28, binding; see `CLAUDE.md`): the first native build's engine was our own
design with FF3's data ("plays like a pre-alpha", "like a weird RPG Maker project"). The core is
rewritten as a translation of FF3's program from the everything8215/ff3 listing
(`build/ref/ff3/ff3j.asm`, never committed). Kept: the battle rules (`bat{init,loop,setup,magic,core,
flow,equip,vict,lib}.s`, already such a translation, checked against FF3's code in py65) and the sound
driver (`sound.s`, checked frame by frame). Extras (Config, Suspend, conveniences, the owner's screen
choices) go into the rewritten code as each part is done.

## Rules
1. **One routine of ours per FF3 routine**, named by its address: `f3F_E1DC` (bank $3F, $E1DC), local
   labels inside. Same call graph: FF3's JSR / JMP targets are ours. A routine may be split or merged
   only where the hardware layer forces it (and the comment says so).
2. **Same RAM, same meaning.** Every NES RAM byte FF3 uses lives at a fixed GB address (map below); a
   routine leaves exactly the RAM FF3's routine leaves. Inputs / outputs in A, X, Y and carry are kept
   (X -> E, Y -> C when they cross a call; 6502 borrow = inverted SM83 carry, written out where used).
3. **Same control flow and data.** Tables, scripts, formulas, RNG, event commands, menus' logic: as FF3.
   Every game byte comes from the user's ROM at build time (ROMDATA / copied banks), never from the repo.
4. **Only the NES hardware layer is replaced**: FF3's routines that write the PPU (pattern tables,
   nametables, attributes, palettes, OAM DMA, scroll, IRQ splits), the APU and the MMC3 become Game Boy
   routines with the same inputs. 160x144 layouts: FF3's window positions / sizes and screen
   coordinates are changed (tables / constants), not its logic.
5. **Checked against FF3's 6502 code**: `tools/gb3n/test/fdiff.py` runs FF3's routine from the user's
   English ROM (`build/ff3_en.nes`: the MMC5 conversion plus the English patch; py65, its banks as the
   code maps them) and ours (SameBoy, a GB3N_TEST build) on the same random RAM
   states and compares all mapped RAM. A routine is done when it matches (hardware-layer routines: by
   the picture / sound they produce instead).

6. **The listing is the Japanese MMC3 game; we play the English MMC5 build.** Where the conversion or
   the English patch changed a routine (bank switching, text, windows), ours follows the English ROM's
   code: compare the bytes at the listing's address before translating (`inventory.py` marks routines
   whose bytes differ), and fdiff always runs the English ROM.

## RAM map (NES -> GB; WRAM bank 1 stays mapped for the whole game)
| NES | GB | |
|---|---|---|
| $0000-$00FF zero page | $C400-$C4FF (`BZ`) | as the battle rules already use |
| $0100-$01FF stack page | not mapped | FF3's stack is the GB stack; data FF3 keeps there: per routine |
| $0200-$07FF | $C600-$CBFF | ($0200 = FF3's OAM page, NES format; ours converts it) |
| $6000-$63FF save page | $D000-$D3FF | |
| $6400-$6FFF save slots | cart RAM (`sr_on` / `sr_off` around each access, Lot Check 2.3) | |
| $7000-$73FF | $C000-$C3FF | people, trigger scripts' buffers ... |
| $7400-$7FFF | $D400-$DFFF | battle RAM; $7F40 the sound page (`MUS` = $DF40) |
GB-only RAM: $C500-$C5FF (the battle rules' temporaries), $CC00-$CEFF, the stack $CF00-$CFFF, HRAM,
WRAM banks 2-7 (BG map / tile shadows, decompressed maps, our extras).

## Order (each step playable and checked before the next)
1. Tools: routine inventory from the listing (`tools/gb3n/inventory.py` -> `build/ff3_routines.txt`,
   with status), the shell with WRAM bank access, `fdiff.py`.
2. Hardware layer: FF3's PPU / OAM / palette / scroll routines (bank $3F's fixed code) on the GB.
3. Field: map main (3F/E1DC) and its frame loop, map loading (3F/E803, 3E/CBA4), movement and
   collision, people (3B / 3E), triggers, treasures, doors, the event runner (3E/D219, 3B/A12B) and
   its commands, text (3F text engine), shops / inns.
4. World map, vehicles, airship.
5. Menus (3C / 3D): main menu, items, magic, equip, status, jobs, order, save; Config / Suspend.
6. Battle input and screen (34/986C, 2F, 32, 33), around the kept rules.
7. Title, prologue, cutscenes, ending (1F, 3A ...).
Old files are removed as their FF3 routines replace them.

## Progress
(updated as routines are translated and checked; per-routine status in `build/ff3_routines.txt`)
- 2026-11-28: decision recorded, plan written.
