"""Build the Game Boy Color FF3 English ROM from the user's own NES ROM.

usage: build.py ["Final Fantasy III (Japan).nes"] [--nes EN.nes] [--cov DIR] [--out ROM]

1. NES ROM -> MMC5 (tools/ff3_mmc5/build.py) -> English (tools/ff3/insert.py)
   = build/ff3_en.nes
2. source base (tools/gb3/ff3src.py --english -> build/ff3/src_en: listing + ROM; needs
   build/src/ff3, the everything8215 listing) -> code map (tools/gb3/ff3code.py)
3. translate (tools/gb3/translate.py) + runtime (tools/gb3/rt/*.s), assemble
4. ROM (2 MB MBC5 + 32 KB battery RAM, CGB only): bank 0 runtime + stubs, banks DATA.. =
   the NES 8KB banks in pairs, RT_TABLES, code banks, the dynamic-target table in bank 127
Nothing game-specific is stored in the repo; everything comes from the NES ROM.
"""
import os, sys, glob, hashlib, subprocess, time, json
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from ff3code import CodeMap
from translate import Recompiler, emit_program, DATA, RT_TABLES, CODE0
from asm_sm83 import asm, make_rom
import build as gb1                       # tools/gb/build.py: shared tables (NES colours)

SHA1_JA = 'c4443fc24625e3c2bb859525eb44b6b3a80e7c35'
RT_FILES = ('hw.s', 'runtime.s')


def nes_english(src, out_dir):
    out = os.path.join(out_dir, 'ff3_en.nes')
    if hashlib.sha1(open(src, 'rb').read()).hexdigest() != SHA1_JA:
        raise SystemExit('not the expected Final Fantasy III (Japan) ROM: ' + src)
    from pyrun import script_cmd
    mmc5 = os.path.join(out_dir, 'ff3_mmc5.nes')
    subprocess.check_call(script_cmd(os.path.join(ROOT, 'tools', 'ff3_mmc5', 'build.py'), src, mmc5), cwd=ROOT)
    subprocess.check_call(script_cmd(os.path.join(ROOT, 'tools', 'ff3', 'insert.py'), mmc5, out), cwd=ROOT)
    return out


def source_base(src, nes, srcdir):
    """build/ff3/src_en from the listing + ROM, unless it is already there for this ROM"""
    mp = os.path.join(srcdir, 'map.json')
    sha = hashlib.sha1(open(nes, 'rb').read()).hexdigest()
    tools = [os.path.join(HERE, f) for f in ('ff3src.py', 'ff3en.py')] + [os.path.join(ROOT, 'tools', 'ff3', 'insert.py')]
    fresh = os.path.exists(mp) and all(os.path.getmtime(t) <= os.path.getmtime(mp) for t in tools)
    if fresh and json.load(open(mp))['rom_sha1'] == sha: return
    listing = os.path.join(ROOT, 'build', 'src', 'ff3', 'ff3j.asm')
    if not os.path.exists(listing):
        raise SystemExit('everything8215 listing missing: git clone --depth 1 '
                         'https://github.com/everything8215/ff3 build/src/ff3')
    from pyrun import script_cmd
    subprocess.check_call(script_cmd(os.path.join(HERE, 'ff3src.py'), src, srcdir, '--english', '--listing', listing), cwd=ROOT)


def main():
    args = sys.argv[1:]
    opt = {'--cov': os.path.join(ROOT, 'build', 'ff3', 'cov'),
           '--out': os.path.join(ROOT, 'build', 'ff3_en.gbc'), '--nes': None}
    pos = []
    while args:
        a = args.pop(0)
        if a in opt: opt[a] = args.pop(0)
        else: pos.append(a)
    src = pos[0] if pos else os.path.join(ROOT, 'roms', 'Final Fantasy III (Japan).nes')
    out_dir = os.path.dirname(os.path.abspath(opt['--out']))
    os.makedirs(out_dir, exist_ok=True)
    nes = opt['--nes'] or nes_english(src, out_dir)
    srcdir = os.path.join(ROOT, 'build', 'ff3', 'src_en')
    source_base(src, nes, srcdir)
    covs = sorted(glob.glob(os.path.join(opt['--cov'], 'c*.bin')))   # optional: stack-trick flags
    t = time.time()
    cm = CodeMap(nes, srcdir, covs).build()
    rc = Recompiler(cm)
    prg = open(nes, 'rb').read()[16:]
    from ff3code import SPACES
    for k, code in list(getattr(rc.g, 'idiom_code', {}).items()):
        base, off, size = SPACES[k[0]]
        o = off + k[1] - base
        if prg[o:o + len(code)] != code or k not in cm.insns:
            print('  idiom %s:%04X: code not found, not used' % k); rc.g.idioms.pop(k, None)
    prog, bank_of, banks = emit_program(rc)
    rt = '\n'.join(open(os.path.join(HERE, 'rt', f)).read() for f in RT_FILES)
    src_all = rt + '\n' + gb1.nes_rgb_src() + '\n' + prog
    open(opt['--out'] + '.s', 'w').write(src_all)
    print('translated: %d instructions, %d code banks (%.1fs), %d dynamic targets'
          % (len(rc.insns), len(banks), time.time() - t, rc.n_dyn))
    t = time.time()
    r = asm(src_all, syms={'DATA': DATA, 'RT_TABLES': RT_TABLES, 'CODE_BANK0': CODE0, 'RESET_NES': rc.g.reset[1]})
    print('assembled (%.1fs)' % (time.time() - t))
    for n in range(64):                                    # NES 8KB banks 2n, 2n+1
        r.banks[DATA + n] = bytearray(prg[2 * n * 0x2000:(2 * n + 2) * 0x2000])
    top = max(r.banks) + 1
    size = 2
    while size < top: size *= 2
    rom = make_rom(r.banks, 'FF3 ENGLISH', cart_type=0x1B, rom_banks=size, ram_size_code=0x03, cgb=0xC0)
    open(opt['--out'], 'wb').write(rom)
    open(os.path.splitext(opt['--out'])[0] + '.sym', 'w').write(r.sym_file())
    print('wrote %s: %d KB, bank 0 used %d bytes' % (opt['--out'], len(rom) // 1024, len(r.banks[0])))
    w = {}
    for x in rc.warn: w.setdefault(x.split(' at ')[0].split(' from ')[0][:40], []).append(x)
    open(opt['--out'] + '.warn', 'w').write('\n'.join(rc.warn) + '\n')
    for k, v in sorted(w.items(), key=lambda kv: -len(kv[1])):
        print('  warn %-42s x%d  e.g. %s' % (k, len(v), v[0][-40:]))


if __name__ == '__main__':
    main()
