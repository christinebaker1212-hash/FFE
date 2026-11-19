"""FF2 battle formations on the NES: force each battle id (a test copy of the user's
English build: fix:FA9E STA $7B48 -> JSR to LDA #id / STA $7B48 / RTS at free $F82B),
start from a state saved just before the opening battle (firstdiff's new-game script +
random seed 1), and measure where enemies and party sprites are drawn (pixel bounds of
non-backdrop pixels in the battlefield above the windows; sprites from OAM).
usage: PYTHONPATH=build/emu ff2form.py NES OUTDIR [IDS e.g. 0-127]   -> sheet + bounds"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb')); sys.path.insert(0, HERE)
from cynes import NES
import firstdiff as fd
from PIL import Image
import numpy as np

SPOT = 0xF82B
START = 9500           # NES frame before the opening battle's id is set (9512, seed 1 path)
SHOT = 120             # frames after START for the measured picture


def patched(rom, bid):
    r = bytearray(rom); base = 16 + 31 * 0x4000 - 0xC000
    assert r[base + 0xFA9E:base + 0xFAA1] == bytes([0x8D, 0x48, 0x7B])
    r[base + 0xFA9E:base + 0xFAA1] = bytes([0x20, SPOT & 0xFF, SPOT >> 8])
    r[base + SPOT:base + SPOT + 6] = bytes([0xA9, bid, 0x8D, 0x48, 0x7B, 0x60])
    return bytes(r)


def main():
    nes_path, out = sys.argv[1], sys.argv[2]
    lo, hi = (0, 127) if len(sys.argv) < 4 else map(int, sys.argv[3].split('-'))
    os.makedirs(out, exist_ok=True)
    rom = open(nes_path, 'rb').read()
    steps = fd.script_newgame(START + SHOT + 1); fd.add_random(steps, 1)
    n = NES(nes_path)
    for f in range(START): n.controller = steps[f]; n.step(1)
    st = n.save()
    shots = []; res = []
    for bid in range(lo, hi + 1):
        p = os.path.join(out, 'f.nes'); open(p, 'wb').write(patched(rom, bid))
        m = NES(p); m.load(st)
        for f in range(START, START + SHOT): m.controller = steps[f]; fr = m.step(1)
        a = np.array(fr).astype(int)
        reg = a[40:148]                                  # battlefield: below the strip (ends y 40), above the windows
        flat = reg.reshape(-1, 3)
        vals, cnt = np.unique(flat, axis=0, return_counts=True)
        bgc = vals[cnt.argmax()]                         # backdrop colour
        diff = np.abs(reg - bgc).sum(axis=2) > 30
        ys, xs = np.nonzero(diff[:, :196])
        py, px = np.nonzero(diff[:, 196:])
        e = (xs.min(), xs.max(), ys.min() + 40, ys.max() + 40) if len(xs) else None
        q = (px.min() + 196, px.max() + 196, py.min() + 40, py.max() + 40) if len(px) else None
        res.append((bid, e, q)); shots.append(Image.fromarray(np.array(fr)))
        print(bid, 'enemies x %s y %s' % ((e[0], e[1]), (e[2], e[3])) if e else '-', '| party', q, flush=True)
    cols = 8
    sheet = Image.new('RGB', (130 * cols, 122 * ((len(shots) + cols - 1) // cols)), 'white')
    for i, s in enumerate(shots): sheet.paste(s.resize((128, 120)), ((i % cols) * 130, (i // cols) * 122))
    sheet.save(os.path.join(out, 'formations_%d_%d.png' % (lo, hi)))
    ex = [r[1] for r in res if r[1]]
    if ex:
        print('enemy bounds over all: x %d-%d y %d-%d' % (min(e[0] for e in ex), max(e[1] for e in ex),
                                                       min(e[2] for e in ex), max(e[3] for e in ex)))


if __name__ == '__main__':
    main()
