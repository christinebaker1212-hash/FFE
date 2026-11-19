"""NES screenshots of a (forced) battle on the given NES build, from firstdiff's seed-1 path.
usage: PYTHONPATH=build/emu nesbattle.py NES OUT.png [--form ID] [--frames F1,F2,..] (after START)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb')); sys.path.insert(0, HERE)
from cynes import NES
import firstdiff as fd, ff2form as F
from PIL import Image
import numpy as np

a = sys.argv[1:]
form = None
if '--form' in a: k = a.index('--form'); form = int(a[k + 1]); del a[k:k + 2]
frames = [120, 200, 300, 400, 600, 900]
if '--frames' in a: k = a.index('--frames'); frames = [int(x) for x in a[k + 1].split(',')]; del a[k:k + 2]
nes_path, out = a[0], a[1]
if form is not None:
    p = out + '.nes'; open(p, 'wb').write(F.patched(open(nes_path, 'rb').read(), form)); nes_path = p
steps = fd.script_newgame(F.START + max(frames) + 1); fd.add_random(steps, 1)
n = NES(nes_path); shots = []
for f in range(F.START + max(frames) + 1):
    n.controller = steps[f]; fr = n.step(1)
    if f - F.START in frames: shots.append(Image.fromarray(np.array(fr)))
sh = Image.new('RGB', (260 * len(shots), 240), 'white')
for i, s in enumerate(shots): sh.paste(s, (i * 260, 0))
sh.save(out)
if form is not None: os.remove(nes_path)
print('saved', out)
