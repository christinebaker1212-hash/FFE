"""Field input scripts (after the new-game script) for screens reached by walking: talk to
people, open the menu, shops. NES screenshots (full frame, GB view outlined) of a script.
usage: PYTHONPATH=build/emu fieldseq.py NES OUT.png SCRIPT [--shots F1,F2,...] [--cam X,Y]
SCRIPT: a name from SCRIPTS or moves 'U40,A3,_20,...' (button letter + frames; _ = none)
--poke ADDR=VAL,... [--poke-at F]: work RAM patches at NES frame F (default 3700, on the field)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare import new_game_script, UP, DOWN, LEFT, RIGHT, A, B, START
from PIL import Image, ImageDraw
import numpy as np

KEYS = {'U': UP, 'D': DOWN, 'L': LEFT, 'R': RIGHT, 'A': A, 'B': B, 'S': START, '_': 0}
SCRIPTS = {}


def moves(spec):
    out = []
    for tok in spec.split(','):
        tok = tok.strip()
        if tok: out += [KEYS[tok[0]]] * int(tok[1:])
    return out


def frames_for(script):
    base = []
    for it in new_game_script():
        if it[0] == 'shot': continue
        m, h, a = it; base += [m] * h + [0] * a
    return base + moves(SCRIPTS.get(script, script)) + [0] * 2000


def pad_for(script, f, _cache={}):
    if script not in _cache: _cache[script] = frames_for(script)
    fr = _cache[script]
    return fr[f] if f < len(fr) else 0


if __name__ == '__main__':
    from cynes import NES
    nes_path, out, script = sys.argv[1:4]
    args = sys.argv[4:]
    shots = [int(x) for x in args[args.index('--shots') + 1].split(',')] if '--shots' in args else []
    cx, cy = (int(v) for v in args[args.index('--cam') + 1].split(',')) if '--cam' in args else (6, 6)
    pokes = [tuple(int(x, 16) for x in kv.split('=')) for kv in args[args.index('--poke') + 1].split(',') if kv] if '--poke' in args else []
    poke_at = int(args[args.index('--poke-at') + 1]) if '--poke-at' in args else 3700
    fr = frames_for(script)
    if not shots: shots = list(range(len(fr) - 2000 - 600, len(fr) - 1800, 100))
    n = NES(nes_path); ims = []
    for f in range(max(shots) + 1):
        if f == poke_at and pokes:
            import battleseq
            st = n.save()
            for a, v in pokes: battleseq.poke_state(st, a, v)
            n.load(st)
        n.controller = fr[f] if f < len(fr) else 0
        img = np.array(n.step(1))
        if f in shots:
            im = Image.fromarray(img); d = ImageDraw.Draw(im)
            d.rectangle([cx * 8 - 1, cy * 8 - 1, cx * 8 + 160, cy * 8 + 144], outline=(255, 0, 0))
            d.text((2, 2), str(f), fill=(255, 255, 0)); ims.append(im)
    cols = 4; rows = (len(ims) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * 260, rows * 244), 'white')
    for i, im in enumerate(ims): sheet.paste(im, ((i % cols) * 260, (i // cols) * 244))
    sheet.save(out); print('saved', out, len(ims))
