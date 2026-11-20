"""FF2 (English MMC5 build) code map for the GB translator, from the generated source.

Same interface as tools/gb/nescode.CodeMap (insns, decode, target_space, static_bank),
but the instruction starts come from the source base (tools/gb2/ff2src.py --english ->
SRCDIR/map.json: the everything8215 listing + insert.py's modules), not from coverage.
Coverage logs (tools/gb2/covrun.py) are accepted for the report (main) only; the build
(tools/gb2/build.py) passes none: nothing in the GB ROM depends on running the NES.

Code spaces:
  bNN  16KB bank NN (0-14) at $8000-$BFFF ($5115)     file NN*$4000
  fix  $C000-$FFFF: bank 31, never switched (MMC5 PRG mode 1)
  ex   ExRAM $5C00-$5FFF, copied at reset from the start of bank 22

usage: ff2code.py ROM SRCDIR [COV.bin ...]   (report)"""
import os, sys, json, hashlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from dis6502 import OPS
from nescode import Insn, fmt_arg, SIZE, COV_RAM, COV_SIZE

HDR = 16
SPACES = {}
for b in list(range(15)) + list(range(23, 31)): SPACES['b%02d' % b] = (0x8000, b * 0x4000, 0x4000)   # 23-30: GB layout code
SPACES['fix'] = (0xC000, 31 * 0x4000, 0x4000)
SPACES['ex'] = (0x5C00, 22 * 0x4000, 0x400)
MAPKEY = {**{str(b): 'b%02d' % b for b in list(range(15)) + list(range(23, 31))}, '15': 'fix', '16': 'ex'}


def index_of(space, addr):
    if space == 'ex': return COV_RAM + addr
    base, off, size = SPACES[space]
    return off + addr - base


class CodeMap:
    def __init__(self, rom_path, srcdir, cov_paths=()):
        self.rom = open(rom_path, 'rb').read()
        m = json.load(open(os.path.join(srcdir, 'map.json')))
        if m['rom_sha1'] != hashlib.sha1(self.rom).hexdigest():
            raise SystemExit('source map %s is for another ROM (%s); rerun ff2src.py --english' % (srcdir, m['rom_sha1']))
        self.rom = self.rom[HDR:]
        self.starts = [(MAPKEY[b], SPACES[MAPKEY[b]][0] + o) for b, offs in m['code'].items() for o in offs]
        self.labels = {(MAPKEY[b], SPACES[MAPKEY[b]][0] + int(o)): n for b, d in m['labels'].items() for o, n in d.items()}
        self.cov = bytearray(3 * COV_SIZE)
        for p in cov_paths:
            d = open(p, 'rb').read()
            for k in range(0, len(d), 1 << 20):
                a = int.from_bytes(self.cov[k:k + (1 << 20)], 'little') | int.from_bytes(d[k:k + (1 << 20)], 'little')
                n = min(1 << 20, len(d) - k)
                self.cov[k:k + n] = a.to_bytes(n, 'little')
        self.insns = {}
        self.unresolved = []

    def byte(self, space, addr):
        base, off, size = SPACES[space]
        if not base <= addr < base + size: raise IndexError('%s:%04X outside space' % (space, addr))
        return self.rom[off + addr - base]

    def decode(self, space, addr):
        key = (space, addr)
        if key in self.insns: return self.insns[key]
        op = self.byte(space, addr)
        if op not in OPS: return None
        mn, mode = OPS[op]
        i = Insn(); i.space, i.addr, i.op, i.mn, i.mode, i.size = space, addr, op, mn, mode, SIZE[mode]
        if i.size == 2:
            v = self.byte(space, addr + 1)
            i.arg = (addr + 2 + (v - 256 if v >= 128 else v)) & 0xFFFF if mode == 'rel' else v
        elif i.size == 3:
            i.arg = self.byte(space, addr + 1) | self.byte(space, addr + 2) << 8
        else:
            i.arg = None
        ci = index_of(space, addr)
        i.cov, i.mem, i.stk = self.cov[ci], self.cov[COV_SIZE + ci], self.cov[2 * COV_SIZE + ci]
        i.executed = bool(i.cov & 1)
        self.insns[key] = i
        return i

    def target_space(self, space, addr):
        """space a static jump/call to addr from `space` lands in (None: depends on $5115)"""
        base, off, size = SPACES[space]
        if base <= addr < base + size: return space
        if addr >= 0xC000: return 'fix'
        if 0x5C00 <= addr < 0x6000: return 'ex'
        return None

    def static_bank(self, space, addr):
        """bank of a JSR/JMP into $8000-$BFFF at addr right after LDA #n / JSR $FE03 (or
        $FE1A, or $FA7F which also records it in $3E), the game's bank switch: 'bNN' or None"""
        sw = self.insns.get((space, addr - 3)); ld = self.insns.get((space, addr - 5))
        if (sw is not None and sw.mn == 'JSR' and sw.arg in (0xFE03, 0xFE1A, 0xFA7F) and
                ld is not None and ld.mn == 'LDA' and ld.mode == 'imm' and 'b%02d' % ld.arg in SPACES):
            return 'b%02d' % ld.arg
        return None

    def build(self):
        for sp, a in self.starts:
            i = self.decode(sp, a)
            if i is None: self.unresolved.append((None, 'bad opcode at %s:%04X' % (sp, a)))
        # coverage-executed starts outside the map would be a map gap
        for ci in range(COV_SIZE):
            if self.cov[ci] & 1:
                if ci >= COV_RAM:
                    a = ci - COV_RAM
                    if not 0x5C00 <= a < 0x6000:
                        self.unresolved.append((None, 'code in RAM at $%04X' % a)); continue
                    k = ('ex', a)
                else:
                    b, o = divmod(ci, 0x4000)
                    k = ('fix', 0xC000 + o) if b == 31 else ('b%02d' % b, 0x8000 + o) if 'b%02d' % b in SPACES else None
                if k is None or k not in self.insns:
                    self.unresolved.append((None, 'executed outside the map: %r' % (k,)))
        for k, i in list(self.insns.items()):
            if i.mn == 'JMP' and i.mode == 'ind': self.unresolved.append((i, 'JMP (ind)'))
            if i.mn in ('JSR', 'JMP') and i.mode == 'abs':
                ts = self.target_space(i.space, i.arg) or self.static_bank(i.space, i.addr)
                if ts is None: self.unresolved.append((i, 'banked target $%04X' % i.arg))
                elif (ts, i.arg) not in self.insns: self.unresolved.append((i, 'target not code $%04X' % i.arg))
        return self


def main():
    cm = CodeMap(sys.argv[1], sys.argv[2], sys.argv[3:]).build()
    from collections import Counter, defaultdict
    per = Counter(); ex = Counter()
    for (sp, a), i in cm.insns.items():
        per[sp] += 1; ex[sp] += i.executed
    print('instructions per space (executed / total):')
    for sp in sorted(per): print('  %-4s %6d / %6d' % (sp, ex[sp], per[sp]))
    kinds = defaultdict(list)
    for i, why in cm.unresolved: kinds[why.split(' $')[0] if i is not None else why].append(i)
    print('unresolved:')
    for k, v in sorted(kinds.items(), key=lambda kv: -len(kv[1])):
        print('  %-28s %4d  %s' % (k, len(v), ', '.join(repr(x) for x in v[:8] if x is not None)))
    stk = [i for i in cm.insns.values() if i.stk & 0x0F]
    print('stack tricks (coverage):', len(stk))
    for i in sorted(stk, key=lambda i: (i.space, i.addr)):
        print('  %-28r stk=%02X' % (i, i.stk))
    for mn in ('PHP', 'PLP', 'TSX', 'TXS', 'RTI', 'BVC', 'BVS'):
        s = [i for i in cm.insns.values() if i.mn == mn]
        print('%s: %d  %s' % (mn, len(s), ', '.join(repr(x) for x in s[:10])))


if __name__ == '__main__':
    main()
