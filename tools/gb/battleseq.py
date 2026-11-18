"""GB-view screenshots of a whole battle on the NES: optionally force a formation (as
formations.py), replay the battleshot.py walk, then a battle input pattern, and save the
GB view (camera X/Y in tiles) every STEP frames into one sheet.
usage: PYTHONPATH=build/emu battleseq.py NES OUT [--form F] [--cam X] [--input fight|run]
       [--from N] [--to N] [--step N]"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from battleshot import battle_input
from formations import patched
from compare import RIGHT, A
from cynes import NES
from PIL import Image
import numpy as np


def opt(name, default, cast=int):
    a = sys.argv
    return cast(a[a.index(name) + 1]) if name in a else default


def main():
    nes, out = sys.argv[1], sys.argv[2]
    form, cx, mode = opt('--form', None), opt('--cam', 1), opt('--input', 'fight', str)
    f0, f1, step = opt('--from', 6160), opt('--to', 9000), opt('--step', 60)
    path = nes
    if form is not None:
        path = out + '.tmp.nes'; open(path, 'wb').write(patched(open(nes, 'rb').read(), form))
    frames = battle_input(); n = NES(path); shots = []

    def pad(f):
        if f < 6160: return frames[f]
        k = f % 40
        if mode == 'run': return RIGHT if k < 3 else (A if 20 <= k < 23 else 0)
        return A if k < 3 else 0
    for f in range(f1 + 1):
        n.controller = pad(f); img = n.step(1)
        if f >= f0 and (f - f0) % step == 0:
            shots.append((f, Image.fromarray(np.array(img)).crop((cx * 8, 48, cx * 8 + 160, 192))))
    cols = 6
    sheet = Image.new('RGB', (cols * 164, ((len(shots) + cols - 1) // cols) * 148), 'white')
    for k, (f, im) in enumerate(shots):
        sheet.paste(im, ((k % cols) * 164, (k // cols) * 148))
    sheet.save(out)
    if path != nes: os.remove(path)
    print('saved', out, len(shots), 'shots')


if __name__ == '__main__':
    main()
