"""GB screenshots in Gambatte at given NES frame waits, with firstdiff's input (new-game
script, optional random play), next to the NES frames of the same waits.
usage: PYTHONPATH=build/emu gbshots.py NES GB FRAMES W1,W2,.. OUT.png [--random SEED] [--dmg]
       [--form F] [--press ..] [--poke ADDR=VAL,.. --pokeat F] (as firstdiff.py)"""
import os, sys, subprocess, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb')); sys.path.insert(0, HERE)
from cynes import NES
import firstdiff as fd
from PIL import Image
import numpy as np


def main():
    a = sys.argv[1:]
    dmg = '--dmg' in a
    if dmg: a.remove('--dmg')
    ws, out = [int(x) for x in a[3].split(',')], a[4]
    del a[3:5]
    nes_path, gb_path, steps, pokes, poke_at, limit = fd.scenario(a)   # --random/--form/--press/--poke
    _, pads, frame_of, _, _ = fd.nes_pass(NES(nes_path), steps, limit, (), pokes, poke_at)
    pw = getattr(fd.nes_pass, 'poke_wait', None)
    nes = NES(nes_path); nes_im = {}
    want = {frame_of[w]: w for w in ws if w in frame_of}
    for f in range(max(want) + 1):
        if pokes and f == poke_at:
            for ad, v in pokes: nes[ad] = v
        nes.controller = steps[f]; fr = nes.step(1)
        if f in want: nes_im[want[f]] = Image.fromarray(np.array(fr))
    tmp = tempfile.mkdtemp(); pf = os.path.join(tmp, 'p.bin')
    open(pf, 'wb').write(bytes(pads.get(n + 1, 0) for n in range(max(frame_of) + 2)))
    cmd = [os.path.join(HERE, '..', '..', 'build', 'gbrun'), gb_path, str(limit * 3), os.path.join(tmp, 's'),
           '--padfile', pf] + sum([['--nshot', str(w)] for w in ws], []) + (['--dmg'] if dmg else []) + \
          (['--poke', str(pw + 1), ','.join('%04X=%02X' % kv for kv in pokes)] if pokes and pw is not None else [])
    print(subprocess.run(cmd, capture_output=True, text=True).stdout.strip())
    sheet = Image.new('RGB', (420, 244 * len(ws)), 'white')
    for i, w in enumerate(ws):
        if w in nes_im: sheet.paste(nes_im[w], (0, i * 244))
        p = os.path.join(tmp, 's_n%05d.ppm' % w)
        if os.path.exists(p): sheet.paste(Image.open(p), (260, i * 244 + 48))
    sheet.save(out); print('saved', out)


if __name__ == '__main__':
    main()
