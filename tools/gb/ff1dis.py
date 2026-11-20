"""Map FF1 disassembly routine names (github.com/Entroper/FF1Disassembly, US release; cloned
into build/ref/ at work time, never committed) onto the code of the user's ROM as the GB
build uses it (Japanese ROM, MMC5 split, English patch, GB layout).

Each global label of bank_*.asm with code under it becomes an instruction pattern: mnemonic,
addressing-mode class and immediate operands of its first instructions (other operands
differ between the releases). The ROM is decoded at every offset and indexed by the pattern
of its first K instructions; a routine matches where its first K agree, and the longest
agreement (up to the routine's length) decides between candidates.

usage: python3 tools/gb/ff1dis.py NES [--dis DIR] [--out FILE]
  writes FILE (default build/ff1dis.map): 'space:addr name length matched' per routine found
  (space as the recompiler names it: bNN $8000-$BFFF, c62 / far $C000-$DFFF, fix $E000-$FFFF,
  ex ExRAM $5C00); prints a summary.
"""
import os, re, sys, glob, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nescode import OPS

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
LEN = {'imm': 2, 'zp': 2, 'zpx': 2, 'zpy': 2, 'abs': 3, 'abx': 3, 'aby': 3, 'ind': 3, 'izx': 2,
       'izy': 2, 'rel': 2, 'imp': 1, 'acc': 1}
CLASS = {'imm': 'i', 'zp': 'm', 'abs': 'm', 'zpx': 'x', 'abx': 'x', 'zpy': 'y', 'aby': 'y',
         'ind': 'n', 'izx': 'X', 'izy': 'Y', 'rel': 'r', 'imp': '', 'acc': ''}
K = 6                                            # instructions in the index key
MNEM = {v[0] for v in OPS.values()}


def parse_dis(d):
    """{name: [(mnemonic, class, imm or None)]} for the global labels with code"""
    routines = {}
    for f in sorted(glob.glob(os.path.join(d, 'bank_*.asm'))):
        cur = None
        for line in open(f, encoding='latin-1'):
            line = line.split(';', 1)[0].rstrip()
            if not line.strip(): continue
            m = re.match(r'^([A-Za-z_]\w*):(.*)$', line)
            if m:
                cur = m.group(1); routines.setdefault(cur, []); line = ' ' + m.group(2)
                if not line.strip(): continue
            if cur is None: continue
            m = re.match(r'^\s*(?:@\w+:\s*)?([A-Za-z]{3})\b\s*(.*)$', line)
            if not m: continue
            mn = m.group(1).upper(); op = m.group(2).strip()
            if mn not in MNEM: continue                   # (.byte, .word, macros)
            if op.upper() == 'A': op = ''
            if not op: cls, imm = '', None
            elif op.startswith('#'):
                cls = 'i'; v = op[1:].strip(); imm = None
                if re.fullmatch(r'\$[0-9A-Fa-f]+', v): imm = int(v[1:], 16) & 0xFF
                elif re.fullmatch(r'%[01]+', v): imm = int(v[1:], 2) & 0xFF
                elif re.fullmatch(r'\d+', v): imm = int(v) & 0xFF
            elif re.search(r'\),\s*Y$', op, re.I): cls, imm = 'Y', None
            elif re.search(r',\s*X\)$', op, re.I): cls, imm = 'X', None
            elif op.startswith('('): cls, imm = 'n', None
            elif re.search(r',\s*X$', op, re.I): cls, imm = 'x', None
            elif re.search(r',\s*Y$', op, re.I): cls, imm = 'y', None
            elif mn in ('BCC', 'BCS', 'BEQ', 'BNE', 'BMI', 'BPL', 'BVC', 'BVS'): cls, imm = 'r', None
            else: cls, imm = 'm', None
            routines[cur].append((mn, cls, imm))
    return {k: v for k, v in routines.items() if len(v) >= 3}


def spaces(prg):
    """(space, base address, bytes) of the code spaces of the GB build's NES ROM"""
    out = [('b%02d' % b, 0x8000, prg[b * 0x4000:(b + 1) * 0x4000]) for b in range(31)]
    out.append(('c62', 0xC000, prg[62 * 0x2000:63 * 0x2000]))
    out.append(('far', 0xC000, prg[40 * 0x2000:41 * 0x2000]))
    out.append(('fix', 0xE000, prg[len(prg) - 0x2000:]))
    out.append(('ex', 0x5C00, prg[18 * 0x4000:18 * 0x4000 + 0x400]))
    return out


def decode(blk, i, n):
    out = []
    while len(out) < n and i < len(blk):
        op = blk[i]
        if op not in OPS: return None
        mn, md = OPS[op]; l = LEN[md]
        if i + l > len(blk): return None
        imm = blk[i + 1] if md == 'imm' else None
        out.append((mn, CLASS[md], imm)); i += l
    return out


def same(a, b):
    return a[0] == b[0] and a[1] == b[1] and (a[2] is None or b[2] is None or a[2] == b[2])


def main():
    a = sys.argv[1:]
    dis = a[a.index('--dis') + 1] if '--dis' in a else os.path.join(ROOT, 'build', 'ref', 'FF1Disassembly', 'Final Fantasy Disassembly')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff1dis.map')
    prg = open(a[0], 'rb').read()[16:]
    rts = parse_dis(dis)
    index = collections.defaultdict(list)            # key (mnemonics + classes of K insns) -> sites
    for sp, base, blk in spaces(prg):
        for i in range(len(blk)):
            d = decode(blk, i, K)
            if d and len(d) == K: index[tuple((m, c) for m, c, _ in d)].append((sp, base, blk, i))
    found = []
    for name, seq in rts.items():
        if len(seq) < K: continue
        best = []
        for sp, base, blk, i in index.get(tuple((m, c) for m, c, _ in seq[:K]), ()):
            d = decode(blk, i, len(seq)) or []
            n = 0
            while n < min(len(d), len(seq)) and same(d[n], seq[n]): n += 1
            if n >= K: best.append((n, sp, base + i))
        if not best: continue
        best.sort(reverse=True)
        top = best[0][0]
        winners = [b for b in best if b[0] == top]
        if len(winners) > 2: continue                   # (too common a pattern)
        for n, sp, ad in winners:
            found.append((sp, ad, name, len(seq), n))
    found.sort()
    with open(out, 'w') as f:
        for sp, ad, name, ln, n in found: f.write('%s:%04X %s %d %d\n' % (sp, ad, name, ln, n))
    full = sum(1 for x in found if x[4] == x[3])
    print('%d routines in the disassembly (%d with >= %d instructions); %d placed (%d matching to the end) -> %s'
          % (len(rts), sum(1 for v in rts.values() if len(v) >= K), K, len(found), full, out))


if __name__ == '__main__':
    main()
