# FF3 Game Boy Color adaptation: status

Target (owner, binding; `CLAUDE.md`): **Game Boy Color only** (header CGB flag `$C0`),
MBC5 + battery SRAM, 0% slowdown, base = the everything8215/ff3 disassembly (fetched at
build time, never committed), the English patch ported onto it, SaGa-style 160×144 layouts.
Branch: `claude/vibrant-davinci-lc8boi` (fast-forwarded from the FF1 GB branch
`claude/compassionate-bell-bo3yq2` at `225f022`; FF1 files untouched). FF3 code lives in
`tools/gb3/`. Method follows the FF2 session (`tools/gb2/`, branch
`claude/zealous-hypatia-3sn3fr`).

## Session setup (cloud container: nothing persists outside git)
```bash
mkdir -p roms   # "Final Fantasy III (Japan).nes" (never commit); sha1 c4443fc2... (README.md)
git clone --depth 1 https://github.com/everything8215/ff3 build/src/ff3   # listing (never commit)
python3 tools/ff3_mmc5/build.py "roms/Final Fantasy III (Japan).nes" build/ff3_mmc5.nes
python3 tools/ff3/insert.py build/ff3_mmc5.nes build/ff3_en.nes            # sha1 4a7f1ae4...
python3 tools/gb3/ff3src.py "roms/Final Fantasy III (Japan).nes" build/ff3/src_ja
python3 tools/gb3/ff3src.py "roms/Final Fantasy III (Japan).nes" build/ff3/src_en --english
```

## Done
- 2026-11-19: ROM checked (SHA-1 matches README). The English FF3 NES build with the
  existing tools reproduces the patch result SHA-1 `4a7f1ae4…` (MMC5, 1 MB).
- everything8215/ff3 fetched (commit `1acef81`, 2022-05-28). Like FF2's, it is **an
  annotated listing, not an assemblable source**: `ff3j.asm` (56k lines,
  `BB/AAAA: bytes MNEMONIC ; comment`, BB = 8 KB bank) covering the code in banks `$10`
  (part: final boss animation), `$1F`, `$2E`-`$36`, `$3A`-`$3F` and some tables, plus
  `rom-map.txt`, `field-ram.txt`, `battle-ram.txt`, event/text dumps. (`ff3u-text.txt` is
  another translation's text: not used, README rule.) Two typos in data-line addresses
  (`1F/5ADF`, `4C/955F`) do not matter (data comes from the ROM).
- `tools/gb3/ff3src.py` (+ `tools/gb3/ff3en.py`, which records `insert.py`'s asm modules):
  listing + ROM → assemblable 6502 source in `build/` (one file per 8 KB bank with code,
  labels for every branch / jump / call target, the listing's titles and comments, data
  from the ROM; static flow for code the listing lacks; jump targets realign re-decoded
  patch code).
  - **Japanese FF3: all 17 code banks reassemble byte-identical** (94.6 KB code,
    `tools/asm6502.py`).
  - **English FF3 (sha1 `4a7f1ae4…`): 21 banks + ExRAM reassemble byte-identical** (96.5 KB
    code): the listing's `$3E/$3F` are banks 126/127; 193 listed instructions changed by
    the MMC5 conversion / English patch re-decoded; insert.py's 8 modules (ExRAM text
    engine, banks 52/53/64/86/87/88/126) as code; the MMC5 converter's ExRAM helpers
    (`irq_entry`, `enable`, `fx2f`, `mir_h/v`) and the rebuilt reset by static flow.
  - Facts: bank pairs `$2E/$2F`, `$30/$31`, `$32/$33`, `$34/$35` are mapped together
    (4 instructions straddle `$9FFF/$A000`; kept as data in the per-bank files, the
    translator must treat each pair as one 16 KB space). 673 jumps / calls go into the
    other bank window (bank known only at run time: resolved by the bank-switch analysis
    in the translator).

- Coverage check (`tools/gb3/build_emu.sh` → `build/emu3`: cynes with the shared patch
  plus an FF3 coverage index by 8 KB bank, MMC5 PRG mode 3, `$E000` = bank 127;
  `tools/gb3/covrun.py` seeds 1-4 × 60k frames from power-on, random input, no crash;
  `tools/gb3/covcheck.py`): **21,367 executed instruction starts, all in the source map**
  except the two known bank-straddling instructions (`30/9FFE`, `32/9FFF`, pairs above)
  and code run from RAM: the NMI / IRQ jump stubs `$0100` / `$0103` (replaced by the
  runtime) and the sine helper copied from `2E/9F6C` to PRG-RAM `$7EE3-$7EF4` (the
  listing documents it, as it does the final boss code copied to `$7EF5`).
  ```bash
  bash tools/gb3/build_emu.sh build/emu3
  mkdir -p build/ff3/cov && cd build/ff3/cov
  COV_LOG=c1.bin PYTHONPATH=../../emu3 python3 ../../../tools/gb3/covrun.py ../../ff3_en.nes 1 60000
  python3 ../../../tools/gb3/covcheck.py ../src_en c1.bin
  ```
- Engine facts for the plan: 8×8 sprites (`$2000` values `$80/$88/$98/$00/$04`); no DPCM
  samples (only `$4011` level writes); Select on the field only changes the walking party
  member (`$F72C`); the minimap comes from Sight / Dwarven Bread; the main menu's Order
  (ならびかえ) is the formation screen.
- Plan: `docs/ff3-gb-plan.md`, **approved by the owner (2026-11-19)**.

## Owner's decisions (2026-11-19)
- **Select menu:** Select on the field opens OPTIONS / SUSPEND (no FORMATION: the main
  menu has Order). **B + Select** changes the walking party member (Famicom: Select).
- **Approach:** as in the plan (§3): mechanical translation of the generated source,
  native routines for graphics, raster splits, sound and hot paths, re-layouts on the NES
  side.

## Step 1-2 of the plan (2026-11-19): first GBC build, equivalence
- **Translator** `tools/gb3/translate.py` (copied from FF2's, adapted): code map
  `tools/gb3/ff3code.py` (spaces: bank pairs `p2e p30 p32 p34 p3a p3c` as 16 KB, single
  banks `b10 b1f b36 b40 b56 b57 b58`, `fix` = banks 126/127, `ex` = ExRAM, `ram` = the
  sine helper copied to `$7EE3`); calls into the other bank window resolved from the game's
  bank switches before them (`$FF03/$FF06/$FF09/$FB87/$FB89`, `$C98A/$EB28/$F727/$EB23`,
  `STA $5114/$5115`) plus a few hints: **all resolved** but an unused `JMP $0000`. Flag facts
  checked for FF3 (V only from BIT; C only after PLP). 46,310 instructions -> 11 code banks
  (~148 KB SM83), 531 dynamic targets, 508 bank-0 stubs.
- **Runtime** `tools/gb3/rt/runtime.s` (CGB only, ~1.4k lines; CPU helpers from FF2):
  double speed; NES pattern table 0/1 = VRAM bank 0/1 `$8000` (unsigned addressing, bank bit
  per map cell / sprite: no tile cache); nametables -> map `$9800` (horizontal mirroring:
  second nametable from row 30, mod 32); attributes -> VRAM bank 1 (only changed quadrants,
  two cells per access window; whole map re-banked by DMA when `$2000` switches the BG
  table); NES palettes -> CGB palettes 0-3 / 0-3 (NES_RGB), black while NES rendering is
  off (the LCD stays on); OAM conversion with the camera (48, 48 for now); joypad (+ test
  mode); MMC5 `$5114/$5115` (8 KB banks: GB bank DATA + n/2, odd banks at `$6000`),
  `$5105`, `$5203/$5204`; frame waits: `$FF36` native, `$FB80` / `$FB79` idioms,
  `$F809` delay loop removed; **asynchronous NMI / IRQ** (battle, cutscenes: `$0100 = JMP
  $FB57`, `$0103 = JMP $5C03`): the vblank counts NMIs due, the handler runs at the next
  safe point (ROM data reads, joypad reads, cross-bank returns, the wait idioms), the IRQ it
  armed at the following one (its `$2000/$2005` writes are recorded as the split's values,
  not applied yet). GB stack at `$CD00-$CFFF` (FF3 keeps data in `$0110-$0161`).
- **Build** `tools/gb3/build.py` -> `build/ff3_en.gbc` (2 MB MBC5, 32 KB RAM, CGB flag $C0;
  NES 8 KB banks copied in pairs from the user's ROM; code banks from 66; dynamic table in
  bank 127). ~4 s.
- **Checks** (tools): `run_gb.py` (PyBoy), `cmpshots.py` (NES next to Gambatte at the same
  frames, input scripts `none` / `newgame`), `firstdiff.py` (RAM equivalence, PyBoy hooks),
  `profsum.py` (mGBA `SGBRUN_PROF2` samples by routine), `build_emu.sh` (cynes for FF3:
  8 KB coverage index; `nmi_count` / `pad_history` count FF3's frames, `ff3_waits` /
  `nmi_ram` the frames the game waits for).
- **Results:**
  - Screens (Gambatte vs NES, inside the camera): opening narration, the second page,
    New Game menu, name entry, the first field scene with its dialogue: as the NES.
  - RAM (`firstdiff.py ... --input newgame --ignore 00C9-00CA,00D0-00DF,0014-0014`: the
    sound driver's bytes and the joypad repeat counter, which depend on how often the IRQ /
    the poll loop runs): **identical through waited-for frame 4,661** (power-on, narration,
    menu, name entry, the opening field scene and dialogue, the whole opening battle and
    the scene after it). The battle rng table matches too (`--sram 7BE3-7CE2`).
- Facts: the battle input loop polls the joypad ~130 times a frame (the repeat counter
  `$14` steps per poll, so it depends on CPU speed even on the NES); a cynes step can hold
  two NMIs; `$05` is also used as scratch outside the wait.

## Speed pass (2026-11-19)
Measured in mGBA (CGB double speed) with the `newgame` input: real frames between waited-for
frames (GB `VBL_CNT`, NES emulator frames): `tools/gb3/lagcheck.py NES GB FROM TO [--step
N]` (per-waited-frame lead and total); mGBA cycle profiles (`SGBRUN_PROF2=300
SGBRUN_PROFC=1`, `profnes.py` groups samples by NES routine; ~470 samples = one frame of CPU).
- **Result: the opening battle keeps pace overall**: from waited-for 2400 (field) to 4332 (end
  of the battle) the GB takes 2002 frames, the NES 2001. Battle start: the GB builds the rng
  table at once (the NES spends 25 frames) but loads the battle graphics in ~30 frames (NES
  11); the fade-in keeps pace. In the battle, the first round's animations still lose ~9
  frames over ~190 waited frames (frames that need ~1.1 frames of CPU: HP window redraw +
  sprite animation), and the GB gains them back later where the NES has lag frames.
- Done: bulk `$2007` paths (map-row runs with step 1 and 32, `rt_ppu_copy` pieces, CHR runs
  inside a tile, `(zp),Y` upload idiom `rt_ppu_izy`, whole attribute tables `attr_put64`);
  attribute writes ~10x faster (one address computation per quadrant pair); fill idiom 24
  cycles per byte; 64-entry dynamic-target cache; natives: hex-to-decimal `p34:95E1`,
  divide rewritten, `F8EA` / `F8E0` / `F8C5`, `nat_9111` in three passes; JSR / JMP to a
  native calls bank 0 directly (no cross-bank call).
- Fixed on the way: the vblank handler incremented `VBL_CNT` (`$D832`) in whatever WRAM bank
  was selected, corrupting byte 2 of tile `$83` in the CHR staging copy; the test tools
  write the runtime's counters in WRAM bank 1 explicitly (PyBoy writes the selected bank).
- Remaining hot spots in battle frames: indirect reads `(zp),Y` of ROM data (~100 cycles
  each), OAM conversion (~5k cycles a frame), banked ROM reads, cross-bank calls (~400
  cycles each), the HP window redraw (text buffer through `STA (zp),Y`).

## Known open items
- Battle screen: the windows below the split (BG table 1 vs the battlefield's table, the
  IRQ's `$2000/$2005` values) are not shown yet; the party sprites are outside the centre
  camera. Both belong to the battle re-layout (step 4) and the split support in the runtime.
- Warp (`p3c:9B5F` TSX / TXS arithmetic) and the inn's `TXS` from a saved X (`p3c:9039`) use
  FF2's approximate helpers: need a semantic version (as FF2's open item).
- Sound: APU writes ignored for now.
- Field dialogue box: drawn into the map (the NES shows it from the other nametable by a
  raster split); belongs in the window layer (FF1 lesson).

## Next
1. Speed: the first battle round (above); then other battles (bosses, magic animations), the
   field, menus.
2. Raster split in the runtime (LYC, window layer), sound (APU -> GB, FF1/FF2 model).
3. Mock-ups for the owner (battle, dialogue, main menu), then the re-layouts.
