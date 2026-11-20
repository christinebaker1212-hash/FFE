"""Compare NES coverage logs (tools/gb2/covrun.py, COV_LOG) with the source code map
(tools/gb2/ff2src.py --english OUT -> OUT/map.json): every executed instruction start
must be a code start in the map. (Test tool only: the build does not use coverage.)
usage: covcheck.py SRCDIR COV.bin [COV.bin ...]"""
import sys, json, collections
COV_RAM = 0x200000; COV_SIZE = COV_RAM + 0x8000; BANK = 0x4000
m = json.load(open(sys.argv[1] + '/map.json'))
starts = set()
def idx(b, o):
    b = int(b)
    if b == 16: return COV_RAM + 0x5C00 + o
    return (31 if b == 15 else b) * BANK + o
for b, offs in m['code'].items():
    for o in offs: starts.add(idx(b, o))
ex = bytearray(COV_SIZE)
for f in sys.argv[2:]:
    d = open(f, 'rb').read()[:COV_SIZE]
    for i, v in enumerate(d):
        if v & 1: ex[i] = 1
hit = [i for i in range(COV_SIZE) if ex[i]]
miss = [i for i in hit if i not in starts]
def name(i):
    if i >= COV_RAM: return 'RAM:%04X' % (i - COV_RAM)
    b, o = divmod(i, BANK)
    return '%02X/%04X' % (15 if b == 31 else b, o + (0xC000 if b == 31 else 0x8000))
print('executed instruction starts: %d, in the code map: %d, outside: %d' % (len(hit), len(hit) - len(miss), len(miss)))
runs = []
for i in miss:
    if runs and i - runs[-1][1] <= 3: runs[-1][1] = i
    else: runs.append([i, i])
for a, b in runs: print('  outside map: %s - %s' % (name(a), name(b)))
per = collections.Counter(15 if i // BANK == 31 else i // BANK for i in hit if i < COV_RAM)
tot = collections.Counter(int(b) for b, offs in m['code'].items() for o in offs)
print('per bank (executed / code-map instruction starts):', ', '.join('%02X %d/%d' % (b, per[b], tot[b]) for b in sorted(tot)))
