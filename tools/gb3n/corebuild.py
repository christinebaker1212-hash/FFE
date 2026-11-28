"""Build the FF3 core rewrite (docs/ff3-gb-rewrite.md): tools/gb3n/core/*.s -> build/ff3c.gbc (4 MB MBC5,
Game Boy Color only). FF3's English PRG (build/ff3_en.nes) is copied into GB banks 64-127 at build time
(NES 8 KB bank n at GB bank 64 + n / 2, $4000 + $2000 (n & 1)); nothing of the game is in the repo.

usage: corebuild.py [--test] [--out FILE]      (--test: the fdiff test loop instead of the game)"""
import os, sys, hashlib
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from asm_sm83 import asm, make_rom

CORE = ['main.s', 'gbv.s', 'b3F.s', 'b3B.s', 'b3E.s']
NES_BASE = 64                     # GB bank of NES banks 0 / 1
ROM_BANKS = 256                   # 4 MB


def expand(src):
    """%X label: a far call (core/main.s xcall); %T a, b, ..: test-table entries (address, bank)"""
    out = []
    import re
    for line in src.split('\n'):
        t = line.split(';')[0].strip()
        m = re.match(r'^([A-Za-z_.][\w.]*:)\s*(%[XT] .*)$', t)
        if m:                                       # (a label before the macro)
            out.append(m.group(1)); t = m.group(2)
        if t.startswith('%X '):
            lab = t[3:].strip()
            out += ['            call xcall', '            dw %s' % lab, '            db bank(%s)' % lab]
        elif t.startswith('%T '):
            for lab in t[3:].split(','):
                lab = lab.strip()
                out += ['            dw %s' % lab, '            db bank(%s)' % lab]
        else:
            out.append(line)
    return '\n'.join(out)


def nes_banks(prg):
    out = {}
    for b16 in range(len(prg) // 0x4000):
        out[NES_BASE + b16] = bytearray(prg[b16 * 0x4000:(b16 + 1) * 0x4000])
    return out


def main():
    a = sys.argv[1:]
    test = '--test' in a
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff3c_test.gbc' if test else 'ff3c.gbc')
    nes = open(os.path.join(ROOT, 'build', 'ff3_en.nes'), 'rb').read()
    prg = nes[16:16 + nes[4] * 0x4000]
    src = open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() + '\n'
    src += ('rSVBK = $FF70\nrVBK = $FF4F\nrKEY1 = $FF4D\nrBCPS = $FF68\nrBCPD = $FF69\nrOCPS = $FF6A\n'
            'rOCPD = $FF6B\nrHDMA1 = $FF51\nrHDMA2 = $FF52\nrHDMA3 = $FF53\nrHDMA4 = $FF54\nrHDMA5 = $FF55\n')
    src += 'CORE_TEST = %d\nNES_BASE = %d\n' % (1 if test else 0, NES_BASE)
    src += 'GB_3E = 1\nGB_3B = 2\nGB_3A = 3\nGB_3C = 4\nGB_3D = 5\n'   # our code banks per FF3 bank
    files = CORE + (['test.s'] if test else [])
    if not test:
        src += 'section bank 0, $3000\nt_table:\n'   # (no test routines in a game build)
    for f in files:
        src += open(os.path.join(HERE, 'core', f)).read() + '\n'
    r = asm(expand(src))
    banks = dict(r.banks)
    for k, v in nes_banks(prg).items():
        assert k not in banks, 'bank %d used twice' % k
        banks[k] = v
    img = make_rom(banks, 'FF3 CORE', cart_type=0x1B, rom_banks=ROM_BANKS, ram_size_code=3, sgb=False, cgb=0xC0)
    open(out, 'wb').write(img)
    open(os.path.splitext(out)[0] + '.sym', 'w').write(r.sym_file())
    print('wrote', os.path.relpath(out, ROOT), '%d KB' % (len(img) // 1024))


if __name__ == '__main__':
    main()
