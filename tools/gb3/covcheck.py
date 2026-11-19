"""Compare NES coverage logs (tools/gb3/covrun.py, COV_LOG, build/emu3) with the FF3 source
code map (tools/gb3/ff3src.py --english OUT -> OUT/map.json): every executed instruction
start must be a code start in the map. Code run from RAM is listed separately.
usage: covcheck.py SRCDIR COV.bin [COV.bin ...]"""
import sys, json, collections
COV_RAM = 0x200000; COV_SIZE = COV_RAM + 0x8000; B8 = 0x2000; EXRAM = 128
m = json.load(open(sys.argv[1] + '/map.json'))
base = {int(b): v for b, v in m['base'].items()}
def idx(b, o): return COV_RAM + 0x5C00 + o if b == EXRAM else b * B8 + o
starts = {idx(int(b), o) for b, offs in m['code'].items() for o in offs}
ex = bytearray(COV_SIZE)
for f in sys.argv[2:]:
    d = open(f, 'rb').read()[:COV_SIZE]
    for i, v in enumerate(d):
        if v & 1: ex[i] = 1
hit = [i for i in range(COV_SIZE) if ex[i]]
def name(i):
    if i >= COV_RAM:
        a = i - COV_RAM
        return ('X' if 0x5C00 <= a < 0x6000 else 'PRG-RAM' if a >= 0x6000 else 'RAM') + ':%04X' % a
    b, o = divmod(i, B8)
    return '%02X/%04X' % (b, o + base.get(b, 0x8000 if b % 2 == 0 else 0xA000))
ram = [i for i in hit if COV_RAM <= i < COV_RAM + 0x5C00 or i >= COV_RAM + 0x6000]
miss = [i for i in hit if i not in starts and i not in ram]
print('executed instruction starts: %d, in the code map: %d, outside: %d, in RAM (not in the map): %d'
      % (len(hit), len(hit) - len(miss) - len(ram), len(miss), len(ram)))
def runs(lst):
    out = []
    for i in lst:
        if out and i - out[-1][1] <= 3: out[-1][1] = i
        else: out.append([i, i])
    return out
for a, b in runs(miss): print('  outside map: %s - %s' % (name(a), name(b)))
for a, b in runs(ram): print('  RAM code: %s - %s' % (name(a), name(b)))
per = collections.Counter(i // B8 for i in hit if i < COV_RAM)
per[EXRAM] = sum(1 for i in hit if i >= COV_RAM + 0x5C00 and i < COV_RAM + 0x6000)
tot = collections.Counter(int(b) for b, offs in m['code'].items() for o in offs)
print('per bank (executed / code-map instruction starts):',
      ', '.join('%s %d/%d' % ('X' if b == EXRAM else '%02X' % b, per[b], tot[b]) for b in sorted(tot)))
