"""FF1 (English MMC5 build) code map for the GB recompiler.

Code spaces (where an NES routine lives and the CPU address it runs at):
  bNN  16KB bank NN at $8000-$BFFF ($5115)          file NN*$4000
  c62  8KB bank 62 at $C000-$DFFF (fixed-bank low half, the default $5116 mapping)
  far  8KB bank 40 at $C000-$DFFF (English patch far code, mapped by `farjsr`)
  fix  $E000-$FFFF (second half of bank 31, never switched)
  ex   MMC5 ExRAM $5C00-$5FFF, copied at reset from the first 1KB of bank 18

Coverage (tools/emu, COV_LOG) gives the executed instructions; static flow from them
adds branch paths not taken during the runs. usage: nescode.py ROM COV.bin [COV2.bin ...]
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from dis6502 import OPS

HDR = 16
COV_RAM = 0x200000
COV_SIZE = COV_RAM + 0x8000
FAR8 = 40
SIZE = {'imp': 1, 'acc': 1, 'imm': 2, 'zp': 2, 'zpx': 2, 'zpy': 2, 'izx': 2, 'izy': 2, 'rel': 2,
        'abs': 3, 'abx': 3, 'aby': 3, 'ind': 3}
SPACES = {}                                    # name -> (cpu_base, file_offset, size)
for b in range(31): SPACES['b%02d' % b] = (0x8000, b * 0x4000, 0x4000)
SPACES['c62'] = (0xC000, 62 * 0x2000, 0x2000)
SPACES['far'] = (0xC000, FAR8 * 0x2000, 0x2000)
SPACES['fix'] = (0xE000, 31 * 0x4000 + 0x2000, 0x2000)
SPACES['ex'] = (0x5C00, 18 * 0x4000, 0x400)


def space_of_index(i):
    """coverage index -> (space, cpu address)"""
    if i >= COV_RAM:
        a = i - COV_RAM
        return ('ex', a) if 0x5C00 <= a < 0x6000 else ('ram', a)
    if 31 * 0x4000 + 0x2000 <= i < 32 * 0x4000: return 'fix', 0xE000 + i - (31 * 0x4000 + 0x2000)
    if 62 * 0x2000 <= i < 63 * 0x2000: return 'c62', 0xC000 + i - 62 * 0x2000
    if FAR8 * 0x2000 <= i < (FAR8 + 1) * 0x2000: return 'far', 0xC000 + i - FAR8 * 0x2000
    return 'b%02d' % (i >> 14), 0x8000 + (i & 0x3FFF)


def index_of(space, addr):
    if space == 'ex': return COV_RAM + addr
    base, off, size = SPACES[space]
    return off + addr - base


class Insn:
    __slots__ = ('space', 'addr', 'op', 'mn', 'mode', 'arg', 'size', 'executed', 'cov', 'mem', 'stk')

    def __repr__(self):
        return '%s:%04X %s %s' % (self.space, self.addr, self.mn, fmt_arg(self))


FMT = {'imp': '', 'acc': 'A', 'imm': '#$%02X', 'zp': '$%02X', 'zpx': '$%02X,X', 'zpy': '$%02X,Y',
       'izx': '($%02X,X)', 'izy': '($%02X),Y', 'rel': '$%04X', 'abs': '$%04X', 'abx': '$%04X,X',
       'aby': '$%04X,Y', 'ind': '($%04X)'}


def fmt_arg(i):
    return FMT[i.mode] % i.arg if '%' in FMT[i.mode] else FMT[i.mode]


class CodeMap:
    def __init__(self, rom_path, cov_paths, entries=()):
        self.rom = open(rom_path, 'rb').read()[HDR:]
        self.cov = bytearray(3 * COV_SIZE)
        for sp, a in entries:                             # entry points known without coverage
            self.cov[index_of(sp, a)] |= 3                #   (executed, reached by RTS)
        for p in cov_paths:
            d = open(p, 'rb').read()
            for k in range(0, len(d), 1 << 20):            # OR in chunks (fast enough)
                a = int.from_bytes(self.cov[k:k + (1 << 20)], 'little') | int.from_bytes(d[k:k + (1 << 20)], 'little')
                n = min(1 << 20, len(d) - k)
                self.cov[k:k + n] = a.to_bytes(n, 'little')
        self.insns = {}                                   # (space, addr) -> Insn
        self.unresolved = []                              # (from insn, reason)

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
        """Space a static jump/call to addr from `space` lands in (None: depends on $5115)."""
        base, off, size = SPACES[space]
        if base <= addr < base + size: return space
        if addr >= 0xE000: return 'fix'
        if addr >= 0xC000: return 'c62'                  # far code never calls the fixed low half
        if 0x5C00 <= addr < 0x6000: return 'ex'
        return None

    def static_bank(self, space, addr):
        """Bank of a JSR/JMP into $8000-$BFFF at `addr` when it directly follows
        LDA #n / JSR $FE03 (or $FE1A), the game's bank switch: 'bNN' or None."""
        try:
            sw = self.decode(space, addr - 3); ld = self.decode(space, addr - 5)
        except IndexError:
            return None
        if (sw is not None and sw.mn == 'JSR' and sw.arg in (0xFE03, 0xFE1A) and
                ld is not None and ld.mn == 'LDA' and ld.mode == 'imm' and ld.arg < 31):
            return 'b%02d' % ld.arg
        return None

    def build(self):
        work = []
        for ci in range(COV_SIZE):
            if self.cov[ci] & 1:
                sp, a = space_of_index(ci)
                if sp == 'ram':
                    self.unresolved.append((None, 'code in RAM at $%04X' % a)); continue
                work.append((sp, a))
        seen = set()
        while work:
            sp, a = work.pop()
            if (sp, a) in seen: continue
            seen.add((sp, a))
            try:
                i = self.decode(sp, a)
            except IndexError as e:
                self.unresolved.append((None, str(e))); continue
            if i is None:
                self.unresolved.append((None, 'bad opcode at %s:%04X' % (sp, a))); continue
            nxt = []
            if i.mn in ('RTS', 'RTI', 'BRK'): pass
            elif i.mn == 'JMP':
                if i.mode == 'abs': nxt.append(i.arg)
                else: self.unresolved.append((i, 'JMP (ind)'))
            else:
                nxt.append(a + i.size)
                if i.mode == 'rel': nxt.append(i.arg)
                if i.mn == 'JSR': nxt.append(i.arg)
            for t in nxt:
                ts = self.target_space(sp, t)
                if ts is None and t == i.arg and i.mn in ('JSR', 'JMP'):
                    ts = self.static_bank(sp, a)
                if ts is None:
                    self.unresolved.append((i, 'banked target $%04X' % t)); continue
                if ts != sp and t != i.arg and not (sp == 'c62' and ts == 'fix'):   # c62 runs on into fix
                    self.unresolved.append((i, 'runs off space')); continue
                work.append((ts, t))
        return self


def main():
    cm = CodeMap(sys.argv[1], sys.argv[2:]).build()
    from collections import Counter, defaultdict
    per = Counter(); ex = Counter()
    for (sp, a), i in cm.insns.items():
        per[sp] += 1; ex[sp] += i.executed
    print('instructions per space (executed / total incl. static flow):')
    for sp in sorted(per): print('  %-4s %6d / %6d' % (sp, ex[sp], per[sp]))
    kinds = defaultdict(list)
    for i, why in cm.unresolved: kinds[why.split(' $')[0] if i is not None else why].append(i)
    print('unresolved:')
    for k, v in sorted(kinds.items(), key=lambda kv: -len(kv[1])):
        print('  %-24s %4d  %s' % (k, len(v), ', '.join(repr(x) for x in v[:6] if x is not None)))
    stk = [i for i in cm.insns.values() if i.stk & 0x0F]
    print('stack tricks:', len(stk))
    for i in sorted(stk, key=lambda i: (i.space, i.addr)):
        print('  %-24r stk=%02X' % (i, i.stk))
    ind = sorted({(i.space, i.addr) for i in cm.insns.values() if i.mode in ('izy', 'izx')})
    regions = Counter()
    for k in ind:
        regions[cm.insns[k].mem] += 1
    print('indirect (zp),Y / (zp,X) instructions:', len(ind), ' by region mask:',
          ', '.join('%02X:%d' % kv for kv in sorted(regions.items())))


if __name__ == '__main__':
    main()
