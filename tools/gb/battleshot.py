"""Play into a battle on the NES (seed-10 random walk after the new-game script) and save
screenshots: full NES frame with the GB view outlined, and the GB view itself (NES
cols 6-25, rows 6-23) scaled 2x. usage: PYTHONPATH=build/emu battleshot.py NES OUT [FRAMES...]"""
import sys, random
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from compare import new_game_script, UP, DOWN, LEFT, RIGHT, A
from cynes import NES
from PIL import Image, ImageDraw
import numpy as np

nes_path, out = sys.argv[1], sys.argv[2]
args = sys.argv[3:]
cx = int(args[args.index('--cam') + 1]) if '--cam' in args else 6
args = [a for k, a in enumerate(args) if a != '--cam' and (k == 0 or args[k - 1] != '--cam')]
want = [int(x) for x in args] or [6300, 6400, 6460, 6560]
base = []
for it in new_game_script():
    if it[0] == 'shot': continue
    m, h, a = it; base += [m] * h + [0] * a
r = random.Random(10); frames = list(base)
btns = [DOWN, DOWN, LEFT, RIGHT, DOWN, LEFT, RIGHT, UP, A]
while len(frames) < 20000: frames += [r.choice(btns)] * r.randint(4, 40) + [0] * r.randint(1, 10)
n = NES(nes_path); shots = []
for f in range(max(want) + 1):
    n.controller = frames[f] if f < 6160 else (128 if f % 60 < 3 else 0)
    img = np.array(n.step(1))
    if f in want: shots.append(Image.fromarray(img))
W = 256 + 8 + 320
im = Image.new('RGB', (W * 2, 288 * ((len(shots) + 1) // 2)), 'white')
for i, s in enumerate(shots):
    x0, y0 = (i % 2) * W, (i // 2) * 288
    full = s.copy(); ImageDraw.Draw(full).rectangle([cx * 8 - 1, 47, cx * 8 + 160, 192], outline=(255, 0, 0))
    im.paste(full, (x0, y0)); im.paste(s.crop((cx * 8, 48, cx * 8 + 160, 192)).resize((320, 288), Image.NEAREST), (x0 + 264, y0))
im.save(out)
print('saved', out)
