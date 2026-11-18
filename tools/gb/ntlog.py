"""Log NES nametable writes during the battleshot.py battle, with the code that made them.
Each $2007 write is attributed to the ROM location of the instruction (bNN:addr for
16KB banks, fix:addr, far/c62 8KB banks shown as 8kNN:addr, ram:addr).
usage: PYTHONPATH=build/emu ntlog.py NES FROM TO [--rows R0-R1] [--cols C0-C1] [--raw] [--attr]
Prints, per source instruction, the frames and the nametable cells (col,row) written."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from battleshot import battle_input, pad
from cynes import NES
from collections import defaultdict


def where(i):
    if i >= 0x200000: return 'ram:%04X' % (i - 0x200000)
    bank, off = divmod(i, 0x4000)
    if bank == 31 and off >= 0x2000: return 'fix:%04X' % (0xC000 + off)
    return 'b%02d:%04X/8k%02d:%04X' % (bank, 0x8000 + off, i // 0x2000, 0xC000 + i % 0x2000)


def rng(name, default):
    a = sys.argv
    if name in a:
        lo, hi = a[a.index(name) + 1].split('-'); return int(lo), int(hi)
    return default


nes_path, f0, f1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
rows, cols, raw = rng('--rows', (0, 29)), rng('--cols', (0, 31)), '--raw' in sys.argv
frames = battle_input(); n = NES(nes_path)
latch, addr, ctrl = 0, 0, 0
hits = defaultdict(lambda: [set(), set(), []])
for f in range(f1 + 1):
    if f == f0: n.watch = (0x2000, 0x2007)
    n.controller = pad(frames, f); n.step(1)
    if f < f0: continue
    for idx, a, v in n.watch:
        if a == 0x2000: ctrl = v
        elif a == 0x2006:
            addr = ((v & 0x3F) << 8) | (addr & 0xFF) if latch == 0 else (addr & 0x3F00) | v
            latch ^= 1
        elif a == 0x2005: latch ^= 1
        elif a == 0x2007:
            if '--attr' in sys.argv and 0x23C0 <= addr < 0x2400:
                print(f, where(idx), 'attr %02X = %02X' % (addr - 0x23C0, v))
            if 0x2000 <= addr < 0x2400 and (addr & 0x3FF) < 0x3C0:
                c, r = addr & 31, (addr >> 5) & 31
                if rows[0] <= r <= rows[1] and cols[0] <= c <= cols[1]:
                    h = hits[where(idx)]; h[0].add(f); h[1].add((c, r))
                    if raw: print(f, where(idx), 'col %d row %d = %02X' % (c, r, v))
            addr = (addr + (32 if ctrl & 4 else 1)) & 0x3FFF
for w, (fs, cells, _) in sorted(hits.items()):
    cs = sorted(cells, key=lambda t: (t[1], t[0]))
    print(w, 'frames %d-%d (%d)' % (min(fs), max(fs), len(fs)), 'rows', sorted({r for _, r in cs}),
          'cols', sorted({c for c, _ in cs}))
