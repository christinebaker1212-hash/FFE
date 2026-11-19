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

## Next
1. NES coverage run (cynes, random play) to check every executed instruction start is
   in the source map, including code run from RAM (NMI/IRQ stubs at `$0100`/`$0103`, the
   final boss animation copied to `$7EF5`).
2. Plan for the owner (`docs/ff3-gb-plan.md`): GBC-only runtime, translation of the
   source, raster splits → LYC, MMC5 helpers replaced natively, screen re-layouts with
   mock-ups, Select-menu question (how FF3 opens it).
