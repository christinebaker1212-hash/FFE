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

## Architecture
- **Code**: `tools/gb3n/core/bBB.s`, one file per FF3 bank (`b3F.s` holds f3F_xxxx ...), placed in our
  own GB code banks. The old engine (`tools/gb3n/src`) stays buildable until the new core reaches parity
  (as FF1's `tools/gb` did for `tools/gbn`); then it goes, except the kept battle rules and sound.
- **FF3's ROM on the GB**: the whole English PRG (1 MB, 128 NES 8 KB banks) is copied at build time
  into GB ROM banks 64-127 (NES bank n at GB bank 64 + n / 2, $4000 + $2000 (n & 1)); the GB ROM is
  4 MB (MBC5). Our code never runs from there; it reads FF3's data through bank-0 helpers.
- **FF3's bank switching**: FF3 maps 8 KB banks at $8000 / $A000 (3F/FF0C, FF1F, FF17; the English
  build writes MMC5 $5114 / $5115, nothing in RAM). Ours keep the two NES bank numbers in HRAM
  (`nb8`, `nbA`; $C000 / $E000 are always NES banks 126 / 127, the English fixed banks); a JSR into
  $8000-$BFFF becomes a far call to our translation of that routine.
- **Pointers stay NES addresses** (so RAM is byte-for-byte FF3's). `(zp),Y` and absolute reads of ROM go
  through `n_rd` (bank 0): NES address -> RAM map (above) or the NES bank mapped at that window ->
  the GB bank / address, read, our code bank back.
- **PPU**: FF3's own logic around the PPU (its row / column / attribute buffers at $0300 / $0780-$07FF,
  window buffers, palette copies, the OAM page $0200) is translated as is, RAM for RAM. Only the
  instructions that touch the PPU (`STA $2006 / $2007`, `$2000 / $2001 / $2005`, `$4014`) become calls
  into the GB port (`core/ppu.s`): `ppu_ad` (the address), `ppu_wr` (a byte: pattern tables -> GB tiles
  byte by byte, NES plane rows to GB interleaved; nametables -> the 32 x 32 GB BG map, NES row r -> GB row r,
  column c of the two horizontal nametables -> c mod 32; attribute bytes -> CGB attributes (VRAM bank 1)
  of their 4 x 4 cells; $3F00 -> the CGB palette shadow), the scroll / control writes -> SCX / SCY / LCDC
  shadows set in V-Blank, $4014 -> the OAM page converted (x / y - the camera) and DMA'd. The NES's
  30-row nametable wraps at 240 px, the GB map at 256: where the picture crosses NES row 30 an LYC split
  adds 16 to SCY for the rest of the frame. The GB view is a 160 x 144 window of FF3's 256 x 240 picture
  (the camera: the field 40 / 48 px in, so the party is centred; menus and windows: their FF3 tables
  re-laid for 20 x 18). The GB view lies inside the NES view with 48 px to spare at each side, so
  FF3's rows / columns drawn at its edges are never seen half-drawn, and the 64 -> 32 column fold
  only ever overwrites columns out of view.
- **APU**: the kept sound driver (`sound.s`, FF3's $7F40 page moved to $DF40).
- **Interrupts**: FF3's NMI work (OAM DMA, palette copy, scroll, the sound) and its waits (3F/FF36
  "wait for vblank" etc.) map onto our V-Blank handler; the frame structure stays FF3's.

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
- Tools: `inventory.py` (730 field / menu routines in banks 3A-3F, ~19.6k instructions; 43 routines of
  the whole game differ in the English ROM), `test/pynes.py` (FF3 from reset in py65 + MMC5: RAM
  identical to cynes after 600 frames; New Game to the first map with `test/ff3drive.py`),
  `test/sbsh3.c` (the shell with work RAM banks), `corebuild.py` (core ROM, FF3's PRG in banks 64-127),
  `test/fdiff.py`. Build: `python3 tools/gb3n/corebuild.py --test`, then
  `python3 tools/gb3n/test/fdiff.py --n 60`.
- First translations, checked (60 random states each, RAM / A / X / Y / carry identical): 3F/FC92
  divide, FCD6 multiply, FCF5 multiply 16, FD20 / FD2C / FD38 bits, FD3C / FD43 shifts, FBEF random.
  Lesson kept in the code: SM83 OR / AND / XOR clear the carry, the 6502's do not; FF3's math feeds
  the caller's carry into its first rotate (kept with LD A, 0 / push af).
