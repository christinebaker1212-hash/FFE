"""FF3's battle algorithms: FF3's own 6502 code (py65, from the user's English NES ROM) against our
native code (SameBoy, a GB3N_TEST=1 build), on the same random battle states, RAM for RAM.

  python3 tools/gb3n/test/batdiff.py [N] [--seed S] [--only NAME,..]
  (build first: GB3N_TEST=1 python3 tools/gb3n/build.py --out build/ff3n_test.gbc)

Memory: NES $6000-$63FF <-> GB $D000-$D3FF, NES $7400-$7EFF <-> GB $D400-$DEFF (work RAM bank 2),
NES zero page <-> GB $C400 (BZ); pointers hold GB addresses on the GB side."""
import os, sys, random, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..', '..')
sys.path.insert(0, os.path.join(HERE, '..'))
import data
from py65.devices.mpu6502 import MPU

NES_ROM = os.path.join(ROOT, 'build', 'ff3_en.nes')
GB_ROM = os.path.join(ROOT, 'build', 'ff3n_test.gbc')
B8 = 0x2000
PTRS = [0x57, 0x59, 0x5B, 0x5D, 0x6E, 0x70]            # zero-page pointers into RAM

# routine: (test number in src/test.s, NES address)
ROUTINES = {'init': (1, 0xA400), 'equip': (2, 0xAA16), 'monact': (3, 0xA732), 'fight': (4, 0x9E8A),
            'magic': (5, 0xAF77), 'item': (6, 0xA65E), 'consol': (7, 0xBEBF), 'confuse': (8, 0xBF17),
            'mtarget': (9, 0xA2E9), 'order': (10, 0x9777), 'exec': (11, 0x9DE4), 'over': (12, 0xA458),
            'cannon': (13, 0xA487), 'poison': (14, 0xBA41), 'victory': (15, 0xBB49), 'stdisp': (16, 0x9D06),
            'turn': (17, 0x81C3), 'act0': (18, 0x8213), 'uses': (19, 0x8271), 'mrows': (20, 0x8295),
            'btype': (21, 0x82CE), 'end': (22, 0x8306), 'inv': (23, 0x8374), 'binit': (24, 0x9CE3),
            'defback': (25, 0x81A0)}
FLOW = ('order', 'exec', 'over', 'cannon', 'poison', 'victory', 'stdisp', 'turn', 'act0', 'uses', 'mrows',
        'btype', 'end', 'inv', 'binit', 'defback')   # FF3's banks $34 / $35 mapped
STUBS = {0x8FF7: 0x34, 0xFA0E: 0x3F, 0x8411: 0x34}       # its message / graphics / animation calls: RTS


class Mem(bytearray):
    def __init__(self, rom, flow=False):
        bytearray.__init__(self, 0x10000)
        self.rom = rom
        for slot, b in enumerate((0x34, 0x35, 0x3E, 0x3F) if flow else (0x30, 0x31, 0x3E, 0x3F)):
            self.map(slot, b)

    def map(self, slot, b):
        bytearray.__setitem__(self, slice(0x8000 + slot * B8, 0xA000 + slot * B8), self.rom.at(b * B8, B8))
        for a, sb in getattr(self, 'stubs', {}).items():
            if sb == b and 0x8000 + slot * B8 <= a < 0xA000 + slot * B8: bytearray.__setitem__(self, a, 0x60)

    def __setitem__(self, a, v):
        if isinstance(a, int):
            if 0x5114 <= a <= 0x5117:
                self.map(a - 0x5114, v & 0x7F); return
            if a >= 0x8000 or 0x2000 <= a < 0x6000: return
        bytearray.__setitem__(self, a, v)


def nes_run(rom, ram6, ram7, zp, addr, flow=False):
    mem = Mem(rom, flow)
    bytearray.__setitem__(mem, slice(0x6000, 0x6400), ram6)
    bytearray.__setitem__(mem, slice(0x7400, 0x7F00), ram7)
    bytearray.__setitem__(mem, slice(0, 0x100), zp)
    if flow:
        mem.stubs = STUBS
        for a in STUBS: bytearray.__setitem__(mem, a, 0x60)          # (banks $34 / $3F mapped now)
    cpu = MPU(memory=mem)
    cpu.memory[0x1FF] = 0xFF; cpu.memory[0x1FE] = 0xEF; cpu.sp = 0xFD; cpu.pc = addr
    n = 0
    while cpu.pc != 0xFFF0:
        cpu.step(); n += 1
        if n > 3000000: raise RuntimeError('NES runaway at %04X' % cpu.pc)
    return bytes(mem[0x6000:0x6400]), bytes(mem[0x7400:0x7F00]), bytes(mem[0:0x100])


class GB:
    def __init__(self):
        self.p = subprocess.Popen([os.path.join(ROOT, 'build', 'sbsh'), GB_ROM, '--model', 'Game Boy Color'],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                  text=True, cwd=ROOT)
        self.cmd('f 400')

    def cmd(self, c):
        self.p.stdin.write(c + '\n'); self.p.stdin.flush()
        return self.p.stdout.readline().strip()

    def poke(self, base, data):
        self.p.stdin.write(''.join('p %04X %02X\n' % (base + i, b) for i, b in enumerate(data)))
        self.p.stdin.flush()
        for _ in data: self.p.stdout.readline()

    def read(self, base, n):
        return bytes.fromhex(self.cmd('r %04X %d' % (base, n)))

    def run(self, ram6, ram7, zp, num):
        self.poke(0xD000, ram6); self.poke(0xD400, ram7); self.poke(0xC400, zp)
        self.cmd('p C5F0 %02X' % num)
        for _ in range(600):
            self.cmd('f 1')
            if self.read(0xC5F0, 1)[0] == 0: break
        else: raise RuntimeError('GB routine did not return')
        return self.read(0xD000, 0x400), self.read(0xD400, 0xB00), self.read(0xC400, 0x100)

    def close(self):
        self.cmd('q')


def gb_ptr(a):
    """an NES RAM address -> its GB address"""
    return 0xD000 | (a & 0xFFF) if 0x6000 <= a < 0x8000 else a


def state(rnd, kind):
    """a random battle state: (ram6 $6000-$63FF, ram7 $7400-$7EFF, zp)"""
    ram6 = bytearray(rnd.getrandbits(8) for _ in range(0x400))
    ram7 = bytearray(rnd.getrandbits(8) for _ in range(0xB00))
    zp = bytearray(rnd.getrandbits(8) for _ in range(0x100))
    for i in range(4):                                   # the characters (save page)
        c = 0x100 + 0x40 * i
        ram6[c] = rnd.randrange(22)                       # job
        ram6[c + 1] = rnd.randrange(1, 100)               # level
        ram6[c + 2] = rnd.choice([0, 0, 0, 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02])
        hpmax = rnd.randrange(1, 9999); ram6[c + 0x0E:c + 0x10] = hpmax.to_bytes(2, 'little')
        ram6[c + 0x0C:c + 0x0E] = rnd.randrange(0, hpmax + 1).to_bytes(2, 'little')
        ram6[c + 0x10] = rnd.randrange(100)
        for k in range(5): ram6[c + 0x12 + k] = rnd.randrange(1, 100)
        e = 0x200 + 0x40 * i                               # equipment: helmet, armour, gloves, R, R qty, L
        for k in range(3): ram6[e + k] = rnd.choice([0, rnd.randrange(0x58, 0x98)])
        ram6[e + 3] = rnd.choice([0, rnd.randrange(1, 0x98)])
        ram6[e + 4] = rnd.randrange(100)
        ram6[e + 5] = rnd.choice([0, rnd.randrange(1, 0x98)])
        ram6[e + 0x0F] &= 1                               # row
    for k in range(0x20):                                 # inventory: items $01-$C7
        ram6[0xC0 + 2 * k] = rnd.choice([0, rnd.randrange(1, 0xC8)])
        ram6[0xC1 + 2 * k] = rnd.randrange(1, 100)
    r7 = lambda a: a - 0x7400
    for k in range(8):                                    # monster slots: 4 types
        ram7[r7(0x7DA7) + k] = rnd.choice([0xFF, rnd.randrange(4)])
    for k in range(4):
        ram7[r7(0x7D6B) + k] = rnd.randrange(0xE0)
    ram7[r7(0x7ED8)] = rnd.choice([0, 0, 0, 0x80, 0x01, 0x10])
    for k in range(10): ram7[r7(0x78DA) + k] = 0xFF       # the message queue empty
    ram7[r7(0x78EE)] = 0
    ram7[r7(0x7EC1)] = 0
    for k in range(0x10): ram7[r7(0x7E4F) + k] = 0xFF
    for k in range(0x10): ram7[r7(0x7E5F) + k] = 0xFF
    ram7[r7(0x7CE4):r7(0x7CE4) + 4] = bytes(rnd.choice([0, 0, 1]) for _ in range(4))
    zp[0x15:0x18] = bytes(rnd.getrandbits(8) for _ in range(3))
    zp[0x52] = rnd.randrange(4)
    zp[0x5F] = (zp[0x52] * 0x40) & 0xFF
    zp[0x74] = rnd.choice([0, 0, 1])
    zp[0xCC] = rnd.choice([0, 0, 0, 1])
    return ram6, ram7, zp


def nes_ptrs(zp):
    for p, v in ((0x57, 0x6100), (0x59, 0x6200), (0x5B, 0x7575), (0x5D, 0x7675)):
        zp[p], zp[p + 1] = v & 0xFF, v >> 8


def battle_records(rom, ram6, ram7, zp):
    """the records as FF3's init leaves them (to test routines that start from a battle in progress)"""
    nes_ptrs(zp)
    a, b, z = nes_run(rom, ram6, ram7, zp, 0xA400)
    for i in range(4):
        z2 = bytearray(z); z2[0x52] = i; z2[0x5F] = i * 0x40; nes_ptrs(z2)
        a, b, z = nes_run(rom, a, b, z2, 0xAA16)
    return bytearray(a), bytearray(b), bytearray(z)


def setup(rom, rnd, name):
    ram6, ram7, zp = state(rnd, name)
    nes_ptrs(zp)
    if name in ('fight', 'magic', 'item', 'monact', 'confuse', 'mtarget') + FLOW:
        ram6, ram7, zp = battle_records(rom, ram6, ram7, zp)
        for k in range(0x10): ram7[0x7E4F - 0x7400 + k] = 0xFF
        for k in range(0x10): ram7[0x7E5F - 0x7400 + k] = 0xFF
        for k in range(10): ram7[0x78DA - 0x7400 + k] = 0xFF
        ram7[0x78EE - 0x7400] = 0
        zp[0x15:0x18] = bytes(rnd.getrandbits(8) for _ in range(3))
    if name == 'fight':                                    # an attacker and a target record
        a = rnd.choice([0x7575 + 0x40 * rnd.randrange(4), 0x7675 + 0x40 * rnd.randrange(8)])
        t = rnd.choice([0x7575 + 0x40 * rnd.randrange(4), 0x7675 + 0x40 * rnd.randrange(8)])
        zp[0x6E], zp[0x6F], zp[0x70], zp[0x71] = a & 0xFF, a >> 8, t & 0xFF, t >> 8
        ram7[a - 0x7400 + 0x2E] = 4
        ram7[a - 0x7400 + 0x30] = rnd.choice([0, 0x80])
        zp[0x74] = rnd.choice([0, 0, 1])
    if name in ('magic', 'item'):
        a = rnd.choice([0x7575 + 0x40 * rnd.randrange(4), 0x7675 + 0x40 * rnd.randrange(8)])
        zp[0x6E], zp[0x6F] = a & 0xFF, a >> 8
        ram7[a - 0x7400 + 0x30] = rnd.choice([0, 0x80, 0xC0])
        ram7[a - 0x7400 + 0x2C] = (ram7[a - 0x7400 + 0x2C] & 0x87) | rnd.choice([0, 0x10, 0x08])
        ram7[0x7E99 - 0x7400] = rnd.choice([0x80, 0x40, 0xF0, 0xFF, rnd.getrandbits(8)])
        ram7[0x7E9A - 0x7400] = rnd.choice([0, 0x40, 0x80, 0xC0])
        ram7[0x7E9B - 0x7400] = ram7[0x7E99 - 0x7400]
        ram7[0x7EC1 - 0x7400] = 0
        zp[0xCC] = rnd.choice([0, 0, 0, 1])
        if zp[0xCC]: ram7[a - 0x7400 + 0x2C] |= 0x10        # (the "ineffective" flag comes with a raw id)
        if name == 'magic':                                # (a raw attack id with the magic flag, else
            f = ram7[a - 0x7400 + 0x2C]                     #   a spell as an item id $C8+)
            zp[0x1A] = rnd.randrange(0x78) if f & 0x18 else 0xC8 + rnd.randrange(0x38)
        else:
            inv = [ram6[0xC0 + 2 * k] for k in range(0x20) if ram6[0xC0 + 2 * k]]
            zp[0x1A] = rnd.choice(inv) if inv else 0x98
    if name in FLOW:
        r7 = lambda a: a - 0x7400
        ram7[r7(0x78D9)] = 0xFF
        ram7[r7(0x7E9A)] = 0
        ram7[r7(0x7EDF)] = 0
        ram7[r7(0x78D3)] = rnd.choice([0, 0, 0, 2])
        ram7[r7(0x7DD2)] = rnd.choice([0, 1, 3])
        ram7[r7(0x7CEC)] = rnd.getrandbits(8) & 0x0F
        ram7[r7(0x7CED)] = rnd.choice([rnd.randrange(0x100), 0x55, 0x79, 0x90])
        ram7[r7(0x7CE3)] = rnd.randrange(0x14)
        ram7[r7(0x74C8)] = rnd.randrange(0x100)
        ram7[r7(0x78BA)] = rnd.choice([0, 0, 1, 8])
        for k in range(4): ram7[r7(0x7AC7) + k] = rnd.randrange(8)
        for k in range(4): ram7[r7(0x7CE4) + k] = 0
    if name == 'victory':
        r7 = lambda a: a - 0x7400
        for k in range(4): ram7[r7(0x7DD3) + k] = rnd.choice([0, 0, 1, 2, 3, 4])
        for k in range(16): ram7[r7(0x78F0) + k] = rnd.randrange(6)
        for i in range(4): ram6[0x100 + 0x40 * i + 3:0x100 + 0x40 * i + 6] = bytes([rnd.getrandbits(8), rnd.getrandbits(8), rnd.randrange(0x99)])
    if name in ('turn', 'uses'):
        for k in range(4): ram7[0x7AC3 - 0x7400 + k] = rnd.choice([0xFF, rnd.randrange(4)])
    if name == 'mrows':
        ram7[0x7D7B - 0x7400] = rnd.randrange(10); zp[0x7E] = rnd.getrandbits(8)
    if name == 'btype':
        ram7[0x78BA - 0x7400] = rnd.choice([0, 1, 8, 0x80, 0x88, 9])
    if name == 'inv':
        for i in range(4):
            rec = 0x7575 + 0x40 * i - 0x7400
            ram7[rec + 0x3F] = rnd.choice([0, 0, 0x98 + rnd.randrange(0x30)])
            ram7[rec + 0x3E] = rnd.choice([0, 0, 1])
            ram7[rec + 0x2E] = rnd.choice([4, 6, 7, 5])
    if name == 'binit':
        ram7[0x7ED8 - 0x7400] = rnd.choice([0, 0, 2, 0x80, 0x20, 0x41])
        ram7[0x74C6 - 0x7400] = rnd.choice([0, 7])
        ram7[0x7CEE - 0x7400] = rnd.choice([0, 1])
    if name == 'poison':
        for i in range(12):
            rec = 0x7575 + 0x40 * i - 0x7400
            if rnd.random() < 0.5: ram7[rec + 1] = (ram7[rec + 1] & ~0xC2) | 2
    if name == 'exec':
        r7 = lambda a: a - 0x7400
        ram7[r7(0x7AC2)] = 0
        who = rnd.choice([rnd.randrange(4), 0x80 | rnd.randrange(8)])
        ram7[r7(0x7ACB)] = who
        rec = 0x7575 + 0x40 * (who & 0x7F) + (0x100 if who & 0x80 else 0)
        f = ram7[r7(rec) + 0x2C] & 0x87
        kind = rnd.choice(['cmd', 'cmd', 'cmd', 'magic', 'item', 'spell'])
        if who & 0x80 and kind in ('item', 'spell'): kind = 'cmd'
        if kind == 'cmd':
            c = rnd.choice([0, 1, 2, 3, 4, 4, 4, 5, 6, 7, 8, 9, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12])
        elif kind == 'magic':
            f |= 0x10; c = rnd.randrange(0x78)
        elif kind == 'item':
            f |= 0x08
            inv = [ram6[0xC0 + 2 * k] for k in range(0x20) if 0x98 <= ram6[0xC0 + 2 * k] < 0xC8]
            c = rnd.choice(inv) if inv else 0x98
        else:
            c = 0xC8 + rnd.randrange(0x38)
        ram7[r7(rec) + 0x2C] = f
        ram7[r7(rec) + 0x2E] = c
        if rnd.random() < 0.5:                          # a character target
            ram7[r7(rec) + 0x2F] = rnd.choice([0x80, 0x40, 0x20, 0x10, 0xF0])
            ram7[r7(rec) + 0x30] = rnd.choice([0, 0x40])
        else:
            ram7[r7(rec) + 0x2F] = rnd.choice([0x80 >> rnd.randrange(8), 0xFF])
            ram7[r7(rec) + 0x30] = rnd.choice([0x80, 0xC0])
    return ram6, ram7, zp


def to_gb(ram6, ram7, zp):
    z = bytearray(zp)
    for p in PTRS + ([0x24] if 0x6000 <= zp[0x24] | zp[0x25] << 8 < 0x8000 else []):
        a = gb_ptr(zp[p] | zp[p + 1] << 8)
        z[p], z[p + 1] = a & 0xFF, a >> 8
    r7 = bytearray(ram7)
    for p in (0x78B5,):
        a = gb_ptr(ram7[p - 0x7400] | ram7[p - 0x7400 + 1] << 8)
        r7[p - 0x7400], r7[p - 0x7400 + 1] = a & 0xFF, a >> 8
    return bytes(ram6), bytes(r7), bytes(z)


# zero page bytes compared (results the battle code reads later; not the helpers' scratch $18-$2F)
ZP_CMP = [a for a in range(0x30, 0x100) if a not in
          set(PTRS + [p + 1 for p in PTRS] + [0x46, 0x47, 0x4A, 0x4B, 0x4C, 0x4D, 0xA9, 0xAB, 0x22, 0x23, 0x20, 0x21])]
RAM7_SKIP = {0x78B5, 0x78B6}


SKIP = {'consol': (0x7400, 0x7480)}                    # FF3's scratch buffers kept elsewhere on the GB


def compare(name, nes, gb):
    out = []
    sk = SKIP.get(name, (0, 0))
    for (lo, hi, a, b, label) in ((0x6000, 0x6400, nes[0], gb[0], ''), (0x7400, 0x7F00, nes[1], gb[1], '')):
        for i in range(hi - lo):
            if lo + i in RAM7_SKIP or sk[0] <= lo + i < sk[1]: continue
            if a[i] != b[i]: out.append('%04X nes %02X gb %02X' % (lo + i, a[i], b[i]))
    for z in ZP_CMP:
        if nes[2][z] != gb[2][z]: out.append('zp %02X nes %02X gb %02X' % (z, nes[2][z], gb[2][z]))
    return out


def main():
    a = sys.argv[1:]
    n = int(a[0]) if a and a[0].isdigit() else 20
    seed = int(a[a.index('--seed') + 1]) if '--seed' in a else 1
    only = a[a.index('--only') + 1].split(',') if '--only' in a else list(ROUTINES)
    rom = data.Rom(NES_ROM)
    rnd = random.Random(seed)
    gb = GB()
    bad = 0
    for name in only:
        num, addr = ROUTINES[name]
        fails = 0
        for k in range(n):
            ram6, ram7, zp = setup(rom, rnd, name)
            try:
                res_n = nes_run(rom, ram6, ram7, zp, addr, name in FLOW)
            except RuntimeError as e:
                print('%s #%d: NES %s (state skipped)' % (name, k, e)); continue
            try:
                res_g = gb.run(*to_gb(ram6, ram7, zp), num)
            except RuntimeError as e:
                info = ''
                if name == 'exec':
                    w = ram7[0x7ACB - 0x7400]; rec = 0x7575 + 0x40 * (w & 0x7F) + (0x100 if w & 0x80 else 0) - 0x7400
                    info = ' (who %02X flags %02X cmd %02X)' % (w, ram7[rec + 0x2C], ram7[rec + 0x2E])
                print("%s #%d: GB %s%s" % (name, k, e, info)); fails += 1; gb.close(); gb = GB(); continue
            d = compare(name, res_n, res_g)
            if d:
                fails += 1
                if fails <= 3: print('%s #%d: %d differences: %s' % (name, k, len(d), '; '.join(d[:10])))
        print('%-8s %d of %d states differ' % (name, fails, n))
        bad += fails
    gb.close()
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
