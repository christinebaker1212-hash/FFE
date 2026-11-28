"""FF3's routines against our translations (docs/ff3-gb-rewrite.md rule 5): FF3's 6502 code from the user's
English ROM in pynes, ours in SameBoy (a core test build), from the same RAM and registers; every mapped
RAM byte, A, X, Y and the carry compared.

  python3 tools/gb3n/corebuild.py --test && python3 tools/gb3n/test/fdiff.py [NAME,..] [--n N] [--seed S]
  (shell: gcc -O2 -I<libretro.h dir> tools/gb3n/test/sbsh3.c -ldl -o build/sbsh3)"""
import os, sys, random, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..', '..')
sys.path.insert(0, HERE)
import pynes

NES_ROM = os.path.join(ROOT, 'build', 'ff3_en.nes')
GB_ROM = os.path.join(ROOT, 'build', 'ff3c_test.gbc')
SENTINEL = 0xFFF0                 # a return address no FF3 routine returns to

# name: (test number in core/test.s, NES address, banks at $8000 / $A000 or None)
ROUTINES = {
    'div16': (1, 0xFC92, None), 'mul8': (2, 0xFCD6, None), 'mul16': (3, 0xFCF5, None),
    'setbit': (4, 0xFD20, None), 'clrbit': (5, 0xFD2C, None), 'chkbit': (6, 0xFD38, None),
    'asl6': (7, 0xFD3C, None), 'lsr6': (8, 0xFD43, None), 'random': (9, 0xFBEF, None),
}
# input constraints: registers / RAM a routine expects (FF3 never calls it otherwise)
CONSTRAIN = {'setbit': {'X': range(8)}, 'clrbit': {'X': range(8)}, 'chkbit': {'X': range(8)},
             'random': {'ram': {0x21: range(3)}}}

# NES RAM <-> GB: (NES start, length, GB bank, GB address)
MAP = [(0x0000, 0x100, 0, 0xC400), (0x0200, 0x600, 0, 0xC600), (0x6000, 0x400, 1, 0xD000),
       (0x7000, 0x400, 0, 0xC000), (0x7400, 0xC00, 1, 0xD400)]


def nes_run(ram, regs, addr, banks):
    n = pynes.Nes(NES_ROM)
    if banks:
        n.map(0, banks[0]); n.map(1, banks[1])
    for a0, ln, _, _ in MAP:
        for k in range(ln):
            n.bus[a0 + k] = ram[a0 + k]
    c = n.cpu
    c.a, c.x, c.y = regs['A'], regs['X'], regs['Y']
    c.p = (c.p & ~1) | regs['C']
    c.sp = 0xFD
    n.bus[0x1FF] = (SENTINEL - 1) >> 8; n.bus[0x1FE] = (SENTINEL - 1) & 0xFF
    c.sp = 0xFD
    c.pc = addr
    k = 0
    while c.pc != SENTINEL:
        n.step(); k += 1
        if k > 2000000:
            raise RuntimeError('NES runaway at %04X' % c.pc)
    out = {a0 + k: n.bus[a0 + k] for a0, ln, _, _ in MAP for k in range(ln)}
    return out, {'A': c.a, 'X': c.x, 'Y': c.y, 'C': c.p & 1}


class GB:
    def __init__(self):
        self.p = subprocess.Popen([os.path.join(ROOT, 'build', 'sbsh3'), GB_ROM, '--model', 'Game Boy Color'],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                  text=True, cwd=ROOT)
        self.cmd('f 400')

    def cmd(self, c):
        self.p.stdin.write(c + '\n'); self.p.stdin.flush()
        return self.p.stdout.readline().strip()

    def run(self, num, ram, regs):
        for a0, ln, bank, ga in MAP:
            for o in range(0, ln, 512):
                n = min(512, ln - o)
                self.cmd('P %X %X %s' % (bank, ga + o, bytes(ram[a0 + o + k] for k in range(n)).hex()))
        mb = bytes([0, regs['A'], regs['X'], regs['Y'], regs['C']])
        self.cmd('P 0 CC00 %s' % mb.hex())
        self.cmd('P 0 CC00 %02X' % num)
        for _ in range(600):
            self.cmd('f 1')
            if self.cmd('R 0 CC00 1') == '00':
                break
        else:
            raise RuntimeError('GB routine did not return')
        out = {}
        for a0, ln, bank, ga in MAP:
            for o in range(0, ln, 512):
                n = min(512, ln - o)
                h = self.cmd('R %X %X %d' % (bank, ga + o, n))
                for k in range(n):
                    out[a0 + o + k] = int(h[2 * k:2 * k + 2], 16)
        r = bytes.fromhex(self.cmd('R 0 CC05 4'))
        return out, {'A': r[0], 'X': r[1], 'Y': r[2], 'C': r[3] & 1}


def state(rng, name):
    ram = {a0 + k: rng.randrange(256) for a0, ln, _, _ in MAP for k in range(ln)}
    regs = {'A': rng.randrange(256), 'X': rng.randrange(256), 'Y': rng.randrange(256), 'C': rng.randrange(2)}
    con = CONSTRAIN.get(name, {})
    for r in ('A', 'X', 'Y'):
        if r in con:
            regs[r] = rng.choice(list(con[r]))
    for a, vals in con.get('ram', {}).items():
        ram[a] = rng.choice(list(vals))
    return ram, regs


def main():
    a = sys.argv[1:]
    n = int(a[a.index('--n') + 1]) if '--n' in a else 20
    seed = int(a[a.index('--seed') + 1]) if '--seed' in a else 1
    names = [x for x in a if not x.startswith('--') and x in ROUTINES] or list(ROUTINES)
    rng = random.Random(seed)
    gb = GB()
    bad = 0
    for name in names:
        num, addr, banks = ROUTINES[name]
        fails = 0
        for i in range(n):
            ram, regs = state(rng, name)
            nr, nregs = nes_run(ram, regs, addr, banks)
            gr, gregs = gb.run(num, ram, regs)
            dr = [k for k in nr if nr[k] != gr[k]]
            dg = [k for k in nregs if nregs[k] != gregs[k]]
            if dr or dg:
                fails += 1
                if fails <= 3:
                    print('%s #%d: regs in %s, NES %s, GB %s; RAM differs at %s' % (
                        name, i, regs, nregs, gregs, ' '.join('%04X:%02X/%02X' % (k, nr[k], gr[k]) for k in dr[:8])))
        print('%-8s %s (%d states)' % (name, 'OK' if not fails else '%d DIFFER' % fails, n))
        bad += fails
    gb.cmd('q')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
