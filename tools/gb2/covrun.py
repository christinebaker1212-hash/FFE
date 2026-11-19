"""NES code coverage of an FF2 build under random play (checks the source code map).
usage: COV_LOG=OUT.bin PYTHONPATH=build/emu covrun.py ROM SEED FRAMES
From power-on: random buttons (A weighted up, so the title, name entry, dialogue,
menus and battles all get pressed through), with held/released spans."""
import sys, random
from cynes import NES
RIGHT, LEFT, DOWN, UP, START, SEL, B, A = 1, 2, 4, 8, 16, 32, 64, 128
rom, seed, frames = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
n = NES(rom); n.step(300)
rng = random.Random(seed)
btns = [UP, DOWN, LEFT, RIGHT, A, A, A, B, START, UP, DOWN, LEFT, RIGHT, A, SEL, A | B]
done = 0
while done < frames and not n.has_crashed:
    n.controller = rng.choice(btns); h = rng.randint(2, 40); n.step(h)
    n.controller = 0; g = rng.randint(0, 20) + 1; n.step(g); done += h + g
print('seed', seed, 'frames', done, 'crashed', n.has_crashed)
