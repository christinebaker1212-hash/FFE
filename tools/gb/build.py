"""Build the Game Boy (dual-mode DMG / SGB / CGB) FF1 English ROM from the user's own NES ROM.

usage: build.py ["Final Fantasy I, II (Japan).nes"] [--gb] [--cov DIR] [--out ROM]
  --gb: the GB layout (insert.py --gb -> build/ff1_gb.nes; default coverage build/cov3,
        output build/ff1_gb.gb); without it: build/ff1_en.nes, build/cov2, build/ff1_en.gb

1. NES ROM -> MMC5 split (tools/split/build_mmc5.py) -> English (tools/ff1/insert.py)
   = build/ff1_en.nes
2. code map from coverage logs (DIR/*.bin, made by tools/gb/covrun.py)
3. recompile (tools/gb/recomp.py) + runtime (tools/gb/rt/runtime.s), assemble
4. ROM: bank 0 runtime, banks DATA.. = the NES banks' data, then code banks
Nothing game-specific is stored in the repo; everything comes from the NES ROM.
"""
import os, sys, glob, hashlib, subprocess, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
from nescode import CodeMap
from recomp import Recompiler, emit_program, DATA, RT_TABLES
from asm_sm83 import asm, make_rom

SHA1_FF12 = '4b22c2c88fc71eacf270ea51ef218944bb4c536a'


def shade(c):
    """NES palette index -> DMG shade (0 white .. 3 black), by brightness row."""
    lo, hi = c & 0x0F, c >> 4
    if lo >= 0x0D: return 3
    if lo == 0: return [2, 1, 0, 0][hi]
    return [3, 2, 1, 0][hi]


# NES 2C02 palette (the values of the cynes emulator, our NES reference, no emphasis) ->
# CGB RGB555. Hardware data, not game content: the CGB mode shows the NES palette RAM
# through it.
NES_RGB = [
    0x545454, 0x001E74, 0x081090, 0x300088, 0x440064, 0x5C0030, 0x540400, 0x3C1800,
    0x202A00, 0x083A00, 0x004000, 0x003C00, 0x00323C, 0x000000, 0x000000, 0x000000,
    0x989698, 0x084CC4, 0x3032EC, 0x5C1EE4, 0x8814B0, 0xA01464, 0x982220, 0x783C00,
    0x545A00, 0x287200, 0x087C00, 0x007628, 0x006678, 0x000000, 0x000000, 0x000000,
    0xECEEEC, 0x4C9AEC, 0x787CEC, 0xB062EC, 0xE454EC, 0xEC58B4, 0xEC6A64, 0xD48820,
    0xA0AA00, 0x74C400, 0x4CD020, 0x38CC6C, 0x38B4CC, 0x3C3C3C, 0x000000, 0x000000,
    0xECEEEC, 0xA8CCEC, 0xBCBCEC, 0xD4B2EC, 0xECAEEC, 0xECAED4, 0xECB4B0, 0xE4C490,
    0xCCD278, 0xB4DE78, 0xA8E290, 0x98E2B4, 0xA0D6E4, 0xA0A2A0, 0x000000, 0x000000]


def nes_rgb_src():
    out = 'section bank 0, $3E00\nNES_RGB:\n'
    for k in range(0, 64, 8):
        vals = []
        for c in NES_RGB[k:k + 8]:
            r, g, b = c >> 16, (c >> 8) & 255, c & 255
            vals.append(str((r >> 3) | (g >> 3) << 5 | (b >> 3) << 10))
        out += '    dw %s\n' % ', '.join(vals)
    return out


def apu_tables():
    """NES APU -> GB: frequency value for each 11-bit pulse/triangle timer (both:
    2048 - x = 131072 * 16 * (t + 1) / 1789773), and NR43 for each NES noise period."""
    import math
    freq = []
    for t in range(2048):
        x = round(2048 - 131072 * 16 * (t + 1) / 1789773)
        freq.append(max(0, min(2047, x)))
    periods = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
    noise = []
    for p in periods:
        f = 1789773 / p
        best = None
        for sh in range(14):
            for r in range(8):
                g = 262144 / ((r or 0.5) * (1 << sh))
                e = abs(math.log(g / f))
                if best is None or e < best[0]: best = (e, sh << 4 | r)
        noise.append(best[1])
    src = 'section bank %d, $4000\napu_freq:\n' % RT_TABLES
    for k in range(0, 2048, 16):
        src += '    dw %s\n' % ', '.join(str(v) for v in freq[k:k + 16])
    src += 'apu_noise:\n    db %s\n' % ', '.join(str(v) for v in noise)
    return src


def nes_english(src, out_dir, gb=False):
    out = os.path.join(out_dir, 'ff1_gb.nes' if gb else 'ff1_en.nes')
    if os.path.exists(out) and not gb: return out
    if hashlib.sha1(open(src, 'rb').read()).hexdigest() != SHA1_FF12:
        raise SystemExit('not the expected Final Fantasy I・II (Japan) ROM: ' + src)
    subprocess.check_call([sys.executable, os.path.join(ROOT, 'tools', 'split', 'build_mmc5.py'), src, out_dir])
    subprocess.check_call([sys.executable, os.path.join(ROOT, 'tools', 'ff1', 'insert.py'),
                           os.path.join(out_dir, 'ff1_mmc5.nes'), out] + (['--gb'] if gb else []))
    return out


def main():
    args = sys.argv[1:]
    gb = '--gb' in args
    if gb: args.remove('--gb')
    name = 'ff1_gb' if gb else 'ff1_en'
    opt = {'--cov': os.path.join(ROOT, 'build', 'cov3' if gb else 'cov2'),
           '--out': os.path.join(ROOT, 'build', name + '.gb')}
    pos = []
    while args:
        a = args.pop(0)
        if a in opt: opt[a] = args.pop(0)
        else: pos.append(a)
    src = pos[0] if pos else os.path.join(ROOT, 'roms', 'Final Fantasy I, II (Japan).nes')
    out_dir = os.path.dirname(os.path.abspath(opt['--out']))
    os.makedirs(out_dir, exist_ok=True)
    nes = nes_english(src, out_dir, gb)
    covs = sorted(glob.glob(os.path.join(opt['--cov'], '*.bin')))
    if not covs: raise SystemExit('no coverage logs in %s (run tools/gb/covrun.py)' % opt['--cov'])
    t = time.time()
    cm = CodeMap(nes, covs).build()
    rc = Recompiler(cm)
    prog, bank_of, banks = emit_program(rc)
    rt = '\n'.join(open(os.path.join(HERE, 'rt', f)).read() for f in ('runtime.s', 'apu.s', 'ff1_hle.s'))
    rt += '\n' + apu_tables()
    shade_src = 'section bank 0, $3F00\nshade_tab:\n' + ''.join(
        '    db %s\n' % ', '.join(str(shade(c)) for c in range(r, r + 16)) for r in range(0, 64, 16))
    src_all = rt + '\n' + shade_src + '\n' + nes_rgb_src() + '\n' + prog
    open(opt['--out'] + '.s', 'w').write(src_all)
    print('recompiled: %d instructions, %d code banks (%.1fs)' % (len(rc.insns), len(banks), time.time() - t))
    t = time.time()
    r = asm(src_all, syms={'DATA': DATA, 'RT_TABLES': RT_TABLES})
    print('assembled (%.1fs)' % (time.time() - t))
    rom_nes = open(nes, 'rb').read()[16:]
    for n in range(32):
        r.banks[DATA + n] = bytearray(rom_nes[n * 0x4000:(n + 1) * 0x4000])
    top = max(r.banks) + 1
    size = 2
    while size < top: size *= 2
    rom = make_rom(r.banks, 'FF1 ENGLISH', cart_type=0x1B, rom_banks=size, ram_size_code=0x03, sgb=True,
                   cgb=0x80)                          # dual-mode: DMG / SGB / CGB
    open(opt['--out'], 'wb').write(rom)
    open(opt['--out'][:-3] + '.sym', 'w').write(r.sym_file())
    used0 = len(r.banks[0])
    print('wrote %s: %d KB, bank 0 used %d bytes' % (opt['--out'], len(rom) // 1024, used0))
    w = {}
    for x in rc.warn: w.setdefault(x.split(' at ')[0].split(' from ')[0][:40], []).append(x)
    open(opt['--out'] + '.warn', 'w').write('\n'.join(rc.warn) + '\n')
    for k, v in sorted(w.items(), key=lambda kv: -len(kv[1])):
        print('  warn %-42s x%d  e.g. %s' % (k, len(v), v[0][-40:]))


if __name__ == '__main__':
    main()
