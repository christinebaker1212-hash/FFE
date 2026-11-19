"""FF3 (English MMC5 build) code map for the GB translator, from the generated source.

Same interface as tools/gb2/ff2code.CodeMap (insns, decode, target_space, static_bank),
with the instruction starts from the source base (tools/gb3/ff3src.py --english ->
SRCDIR/map.json: the everything8215 listing + insert.py's modules + static flow).
Coverage logs (tools/gb3/covrun.py, build/emu3) only add their flags.

Code spaces (MMC5 PRG mode 3: 8KB at $8000 by $5114, at $A000 by $5115; $C000 = bank 126
and $E000 = bank 127 never change in FF3):
  pXX   8KB banks XX (at $8000) and XX+1 (at $A000) used as one 16KB space (the game maps
        them together: $2E/$2F, $30/$31, $32/$33, $34/$35, $3A/$3B, $3C/$3D)
  bXX   a single 8KB bank at its own window ($10, $1F, $36, and the English banks)
  fix   $C000-$FFFF: banks 126/127 (the Japanese $3E/$3F)
  ex    ExRAM $5C00-$5FFF (bank 64 $8000-$83FF, copied at reset)
  ram   $7EE3-$7F06: code copied to PRG-RAM from bank $2E $9F6C (sine table read, final
        boss animation call)
(XX in lower-case hex.)

usage: ff3code.py ROM SRCDIR [COV.bin ...]   (report)"""
import os, sys, json, hashlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from dis6502 import OPS
from nescode import Insn, SIZE, COV_RAM, COV_SIZE

HDR = 16
B8 = 0x2000
EXRAM = 128
RAMCODE = (0x7EE3, 0x2E * B8 + 0x1F6C, 0x24)        # (run address, file offset, size)
# fixed-bank routines that map PRG banks: address -> how ('pair8' A = 8KB bank -> $8000 A,
# $A000 A+1; 'w8' / 'wA' one window; 'pair16' A = 16KB unit; or a constant pair)
SWITCH = {0xFF03: 'pair8', 0xFF17: 'pair8', 0xFF06: 'w8', 0xFF0C: 'w8', 0xFF09: 'wA', 0xFF1F: 'wA',
          0xFB87: 'pair16', 0xFB89: 'pair16',
          0xC98A: (0x3C, 0x3D), 0xEB28: (0x3C, 0x3D), 0xF727: (0x3C, 0x3D), 0xEB23: (0x2C, 0x2D)}


def spaces_from_map(m):
    """-> SPACES {name: (base, file offset, size)}, MAPKEY {map bank: (space, base)}"""
    base = {int(b): v for b, v in m['base'].items()}
    sp = {}; key = {}
    cfix, efix = m['fixed']
    for b in sorted(base):
        if b in (cfix, efix, EXRAM) or b in key: continue
        if b % 2 == 0 and base[b] == 0x8000 and base.get(b + 1) == 0xA000:
            n = 'p%02x' % b; sp[n] = (0x8000, b * B8, 0x4000)
            key[b] = (n, 0x8000); key[b + 1] = (n, 0x8000)
        else:
            n = 'b%02x' % b; sp[n] = (base[b], b * B8, B8); key[b] = (n, base[b])
    sp['fix'] = (0xC000, cfix * B8, 0x4000); key[cfix] = ('fix', 0xC000); key[efix] = ('fix', 0xC000)
    if EXRAM in base:
        sp['ex'] = (0x5C00, 64 * B8, 0x400); key[EXRAM] = ('ex', 0x5C00)
    sp['ram'] = (RAMCODE[0], RAMCODE[1], RAMCODE[2])
    return sp, key


# FF3 facts for calls into a window whose bank is set elsewhere (checked in the listing /
# insert.py): (space, address of the JSR/JMP) -> target space
HINT = {('fix', 0xEB1D): 'p3c',                 # check item select npc script (3C/92EE; field)
        ('fix', 0xF81A): 'p34', ('fix', 0xF823): 'p34',   # $F82C maps $34/$35 (equipment)
        ('fix', 0xFF89): 'b40',                 # reset: $5114 = $C0 (bank 64): the ExRAM copier
        ('ex', 0x5D40): 'p3c',                  # English: amounts ($8B78, field menus)
        ('ex', 0x5D55): 'b58',
        # English ExRAM battle text copies: bank 53 ($35) at $A000, battle string copy $A609
        ('ex', 0x5CD6): 'p34', ('ex', 0x5CEE): 'p34', ('ex', 0x5CF5): 'p34', ('ex', 0x5D03): 'p34'}                  # English: job-name helpers (bank 88 at $8000)
# English battle code (banks 86 / 87 at $A000 and the ExRAM battle routines) runs with
# battle banks $34 at $8000 / $35 at $A000
HINT_SPACE = {'b56': {0x8000: 'p34'}, 'b57': {0x8000: 'p34'}}
SPACES = {}


def index_of(space, addr):
    if space in ('ex', 'ram'): return COV_RAM + addr
    base, off, size = SPACES[space]
    return off + addr - base


def space_of_bank(bank, window):
    """space holding 8KB bank `bank` mapped at `window` ($8000 / $A000), or None"""
    for n, (base, off, size) in SPACES.items():
        if n in ('fix', 'ex', 'ram'): continue
        if off <= bank * B8 < off + size and base + bank * B8 - off == window:
            return n
    return None


class CodeMap:
    def __init__(self, rom_path, srcdir, cov_paths=()):
        self.rom = open(rom_path, 'rb').read()
        m = json.load(open(os.path.join(srcdir, 'map.json')))
        if m['rom_sha1'] != hashlib.sha1(self.rom).hexdigest():
            raise SystemExit('source map %s is for another ROM (%s); rerun ff3src.py --english' % (srcdir, m['rom_sha1']))
        self.rom = self.rom[HDR:]
        sp, key = spaces_from_map(m)
        SPACES.clear(); SPACES.update(sp)
        self.starts = []; self.labels = {}
        for b, offs in m['code'].items():
            n, base = key[int(b)]
            boff = int(m['base'][b]) - base        # the bank's place in its space
            for o in offs: self.starts.append((n, base + boff + o))
            for o, nm in m['labels'].get(b, {}).items(): self.labels[(n, base + boff + int(o))] = nm
        for b, o in m.get('cross', []):            # instructions running on into the
            n, base = key[b]                         #   pair's second bank
            self.starts.append((n, base + int(m['base'][str(b)]) - base + o))
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
        """space a static jump/call to addr from `space` lands in (None: depends on the
        banks mapped at run time)"""
        base, off, size = SPACES[space]
        if space != 'ram' and base <= addr < base + size: return space
        if addr >= 0xC000: return 'fix'
        if 0x5C00 <= addr < 0x6000: return 'ex'
        r = SPACES['ram']
        if r[0] <= addr < r[0] + r[2]: return 'ram'
        return None

    def mapping_before(self, space, addr, look=16):
        """banks mapped by the nearest bank switch (JSR to a SWITCH routine) in the straight
        line before addr: {window: bank}, or {}"""
        a = addr; n = 0
        while n < look:
            # step back over instructions: try sizes 3, 2, 1
            prev = None
            for s in (3, 2, 1):
                j = self.insns.get((space, a - s))
                if j is not None and j.size == s: prev = j; break
            if prev is None: return {}
            a = prev.addr; n += 1
            if prev.mn in ('RTS', 'RTI', 'JMP') or prev.mode == 'rel': return {}
            if prev.mn == 'JSR' and prev.arg in SWITCH:
                how = SWITCH[prev.arg]
                if isinstance(how, tuple): return {0x8000: how[0], 0xA000: how[1]}
                ld = None; q = a                     # the LDA #n setting A (stores and
                for _ in range(4):                    #   X / Y loads between keep A)
                    pj = None
                    for s2 in (3, 2, 1):
                        j = self.insns.get((space, q - s2))
                        if j is not None and j.size == s2: pj = j; break
                    if pj is None: break
                    q = pj.addr
                    if pj.mn == 'LDA' and pj.mode == 'imm': ld = pj; break
                    if pj.mn not in ('STA', 'STX', 'STY', 'PHA', 'LDX', 'LDY'): break
                if ld is None: return {}
                v = ld.arg & 0x7F
                if how == 'pair8': return {0x8000: v, 0xA000: v + 1}
                if how == 'pair16': return {0x8000: 2 * v, 0xA000: 2 * v + 1}
                if how == 'w8': return {0x8000: v}
                if how == 'wA': return {0xA000: v}
            if prev.mn == 'STA' and prev.mode == 'abs' and prev.arg in (0x5114, 0x5115):
                ld = self.insns.get((space, a - 2))     # LDA #n / STA $5114 or $5115
                if ld is not None and ld.mn == 'LDA' and ld.mode == 'imm':
                    return {0x8000 if prev.arg == 0x5114 else 0xA000: ld.arg & 0x7F}
                return {}
            if prev.mn == 'JSR': continue              # (other calls keep the mapping)
        return {}

    def resolve(self, i):
        """space of a JSR / JMP abs target: a bank switch just before it, an FF3 hint,
        else the static space (None: decided at run time)"""
        if i.arg is not None and 0x8000 <= i.arg < 0xC000:
            ts = self.static_bank(i.space, i.addr) or HINT.get((i.space, i.addr))
            if ts is None and i.space in HINT_SPACE: ts = HINT_SPACE[i.space].get(0x8000 if i.arg < 0xA000 else 0xA000)
            if ts: return ts
        return self.target_space(i.space, i.arg)

    def static_bank(self, space, addr):
        """space of the JSR/JMP target at addr ($8000-$BFFF) from a bank switch just before
        it in the same straight line, or None"""
        i = self.insns.get((space, addr))
        if i is None or i.arg is None or not 0x8000 <= i.arg < 0xC000: return None
        w = 0x8000 if i.arg < 0xA000 else 0xA000
        mp = self.mapping_before(space, addr)
        if w not in mp: return None
        ts = space_of_bank(mp[w], w)
        if ts is None: return None
        b0, o0, sz = SPACES[ts]
        return ts if b0 <= i.arg < b0 + sz else None

    def build(self):
        for sp, a in self.starts:
            i = self.decode(sp, a)
            if i is None: self.unresolved.append((None, 'bad opcode at %s:%04X' % (sp, a)))
        a = SPACES['ram'][0]                          # the RAM code (straight line)
        end = SPACES['ram'][0] + SPACES['ram'][2]
        while a < end:
            op = self.byte('ram', a)
            if op not in OPS or a + SIZE[OPS[op][1]] > end: break   # (copied tail bytes)
            i = self.decode('ram', a)
            if i is None: break
            a += i.size
        for ci in range(COV_SIZE):
            if self.cov[ci] & 1:
                if ci >= COV_RAM:
                    a = ci - COV_RAM
                    k = ('ex', a) if 0x5C00 <= a < 0x6000 else ('ram', a) if SPACES['ram'][0] <= a < SPACES['ram'][0] + SPACES['ram'][2] else None
                    if k is None:
                        if a not in range(0x100, 0x106): self.unresolved.append((None, 'code in RAM at $%04X' % a))
                        continue
                else:
                    k = None
                    for n, (base, off, size) in SPACES.items():
                        if n not in ('ex', 'ram') and off <= ci < off + size: k = (n, base + ci - off)
                if k is None or k not in self.insns:
                    self.unresolved.append((None, 'executed outside the map: %r' % (k,)))
        for k, i in list(self.insns.items()):
            if i.mn == 'JMP' and i.mode == 'ind': self.unresolved.append((i, 'JMP (ind)'))
            if i.mn in ('JSR', 'JMP') and i.mode == 'abs':
                ts = self.resolve(i)
                if ts is None: self.unresolved.append((i, 'banked target $%04X' % i.arg))
                elif (ts, i.arg) not in self.insns: self.unresolved.append((i, 'target not code %s:$%04X' % (ts, i.arg)))
        return self


def main():
    cm = CodeMap(sys.argv[1], sys.argv[2], sys.argv[3:]).build()
    from collections import Counter, defaultdict
    per = Counter(); ex = Counter()
    for (sp, a), i in cm.insns.items():
        per[sp] += 1; ex[sp] += i.executed
    print('spaces:', ', '.join('%s=%04X+%X@%X' % (n, *v) for n, v in SPACES.items()))
    print('instructions per space (executed / total):')
    for sp in sorted(per): print('  %-4s %6d / %6d' % (sp, ex[sp], per[sp]))
    kinds = defaultdict(list)
    for i, why in cm.unresolved: kinds[why.split(' $')[0].split(' p')[0] if i is not None else why].append((i, why))
    print('unresolved:')
    for k, v in sorted(kinds.items(), key=lambda kv: -len(kv[1])):
        print('  %-28s %4d  %s' % (k, len(v), ', '.join('%r' % (x[0],) for x in v[:6] if x[0] is not None)))
    stk = [i for i in cm.insns.values() if i.stk & 0x0F]
    print('stack tricks (coverage):', len(stk))
    for i in sorted(stk, key=lambda i: (i.space, i.addr))[:40]:
        print('  %-28r stk=%02X' % (i, i.stk))
    for mn in ('PHP', 'PLP', 'TSX', 'TXS', 'RTI', 'BVC', 'BVS', 'BRK'):
        s = [i for i in cm.insns.values() if i.mn == mn]
        print('%s: %d  %s' % (mn, len(s), ', '.join(repr(x) for x in s[:10])))


if __name__ == '__main__':
    main()
