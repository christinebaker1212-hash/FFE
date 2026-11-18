"""Which NES code draws which part of a screen: run the NES build with PPU_LOG between two
frames and report, per nametable region, the writing instructions.
usage: PPU_LOG=1 PYTHONPATH=build/emu ppumap.py NES SEED FROM TO 2> log; then ppumap.py --report log"""
import sys, random
sys.path.insert(0, __file__.rsplit('/', 1)[0])
if sys.argv[1] == '--report':
    from collections import defaultdict
    grid = defaultdict(set); started = False
    for l in open(sys.argv[2]):
        if l.startswith('MARK'): started = not started; continue
        if not started or not l.startswith('P '): continue
        p = l.split(); a = int(p[1], 16)
        if 0x2000 <= a < 0x3F00:
            a &= 0x0FFF; nt = (a >> 10) & 1; o = a & 0x3FF
            if o < 0x3C0:
                grid[(p[3][3:], p[4][2:])].add((nt, o >> 5, o & 31))
    for (pc, b), cells in sorted(grid.items(), key=lambda kv: -len(kv[1])):
        ys = [y for _, y, _ in cells]; xs = [x for _, _, x in cells]; nts = {n for n, _, _ in cells}
        print('pc %s bank %s: %4d cells, NT %s, rows %d-%d, cols %d-%d' % (pc, b, len(cells), sorted(nts), min(ys), max(ys), min(xs), max(xs)))
    sys.exit(0)
from compare import new_game_script, UP, DOWN, LEFT, RIGHT, A
from cynes import NES
base = []
for it in new_game_script():
    if it[0] == 'shot': continue
    m, h, a = it; base += [m] * h + [0] * a
r = random.Random(int(sys.argv[2])); frames = list(base)
btns = [DOWN, DOWN, LEFT, RIGHT, DOWN, LEFT, RIGHT, UP, A]
while len(frames) < 20000: frames += [r.choice(btns)] * r.randint(4, 40) + [0] * r.randint(1, 10)
lo, hi = int(sys.argv[3]), int(sys.argv[4])
n = NES(sys.argv[1])
for f, m in enumerate(frames[:hi]):
    if f == lo or f == hi - 1: sys.stderr.write('MARK\n'); sys.stderr.flush()
    n.controller = m if f < 6160 else (128 if f % 40 < 3 else 0)
    n.step(1)
