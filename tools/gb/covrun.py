"""Collect NES code coverage for the recompiler: new game (party creation, scripted
like tools/split/equiv.py), then random play.
usage: COV_LOG=OUT.bin PYTHONPATH=build/emu covrun.py ROM SEED FRAMES"""
import os, sys, random
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'split'))
from drive import run, UP, DOWN, LEFT, RIGHT, A, B, START

rom, seed, frames = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
s = [(0, 1, 600), (START, 5, 120), (A, 5, 60)]
for c in range(4): s += [(A, 5, 40), (A, 5, 30), (A, 5, 30), (A, 5, 30), (A, 5, 60), (0, 1, 0)]
s += [(START, 5, 200), (0, 1, 0), (A, 5, 300), (0, 1, 0), (A, 5, 300), (0, 1, 0)]
for k in range(6): s += [(A, 5, 200), (0, 1, 0)]
n = run(rom, s, 'x')
rng = random.Random(seed)
btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT, A | B]
done = 0
while done < frames:
    n.controller = rng.choice(btns); h = rng.randint(2, 40); n.step(h)
    n.controller = 0; g = rng.randint(0, 20) + 1; n.step(g); done += h + g
print('seed', seed, 'frames', done, 'crashed', n.has_crashed)
