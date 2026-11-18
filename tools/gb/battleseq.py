"""GB-view screenshots of a whole battle on the NES: optionally force a formation (as
formations.py), replay the battleshot.py walk, then a battle input pattern, and save the
GB view (camera X/Y in tiles) every STEP frames into one sheet.
usage: PYTHONPATH=build/emu battleseq.py NES OUT [--form F] [--cam X] [--input fight|run|magic4|items4|cure4|med1|fire1]
       [--from N] [--to N] [--step N]
       [--poke 63C0=01,63E0=02,...]  (work RAM, hex, patched into the state at frame 6100)"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from battleshot import battle_input
from formations import patched
from compare import RIGHT, DOWN, A
from cynes import NES
from PIL import Image
import numpy as np


SRAM_STATE = 0x23E2           # offset of NES $6000 in a cynes save state (this ROM/mapper)


def pad_for(mode, f):
    """pad value at frame f for an input mode (the walk into the battle, then the mode)"""
    frames = _frames()
    if f < 6160: return frames[f]
    k = f % 40
    if mode == 'run': return RIGHT if k < 3 else (A if 20 <= k < 23 else 0)
    if mode == 'magic':
        k = f % 90
        return DOWN if k < 3 else (A if 30 <= k < 33 else 0)
    if mode == 'fire1':                       # member 1: Magic > Fire (slot 1) > enemy
        seq = [0, 0, DOWN, A, DOWN, A, 0, A]
        k, r = divmod(f - 6400, 30)
        if k >= len(seq): return A if f % 40 < 3 else 0      # the others: Fight
        return seq[k] if 0 <= k and r < 3 else 0
    if mode == 'med1':                        # member 1: Medicine
        seq = [DOWN, DOWN, A]
        k, r = divmod(f - 6400, 30)
        return seq[k] if 0 <= k < len(seq) and r < 3 else 0
    if mode == 'cure4':                       # Fight x3, then Magic > Cure > party target
        seq = [A, A, A, A, A, A, DOWN, A, 0, A]
        k, r = divmod(f - 6400, 30)
        return seq[k] if 0 <= k < len(seq) and r < 3 else 0
    if mode in ('magic4', 'items4'):          # Fight x3, then Magic / Items for member 4
        seq = [A, A, A, A, A, A, DOWN, A] if mode == 'magic4' else [A, A, A, A, A, A, DOWN, DOWN, DOWN, A, 0, 0, 0, RIGHT]
        k, r = divmod(f - 6400, 30)
        return seq[k] if 0 <= k < len(seq) and r < 3 else 0
    if mode == 'items':
        k = f % 90
        return DOWN if k < 3 or 10 <= k < 13 or 20 <= k < 23 else (A if 40 <= k < 43 else 0)
    return A if k < 3 else 0


_FR = []


def _frames():
    if not _FR: _FR.extend(battle_input())
    return _FR


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

    pokes = [tuple(int(x, 16) for x in kv.split('=')) for kv in opt('--poke', '', str).split(',') if kv]
    for f in range(f1 + 1):
        if f == 6100 and pokes:                 # work RAM $6000-$7FFF in the cynes state
            st = n.save()
            for a, v in pokes: st[SRAM_STATE + a - 0x6000] = v
            n.load(st)
        n.controller = pad_for(mode, f); img = n.step(1)
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
