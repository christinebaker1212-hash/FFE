"""Screens the GB build shows under random play (mGBA, CGB): a contact sheet of screenshots every
N GB frames, to find screens not yet laid out for 160 x 144. The input is covrun.py's random
driver (seeded), fed through the ROM's test-pad mode (sgbrun --padfile, frames by NES wait).

usage: survey.py ROM.gbc OUT.png [--seed S] [--frames F] [--every N] [--cols C]"""
import sys, os, random, subprocess, tempfile, shutil, argparse
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
RIGHT, LEFT, DOWN, UP, START, SEL, B, A = 1, 2, 4, 8, 16, 32, 64, 128


def pads(seed, n):
    rng = random.Random(seed)
    btns = [UP, DOWN, LEFT, RIGHT, A, A, A, B, START, UP, DOWN, LEFT, RIGHT, A, SEL, A | B]
    out = bytearray()
    while len(out) < n:
        out += bytes([rng.choice(btns)]) * rng.randint(2, 40)
        out += bytes(rng.randint(0, 20) + 1)
    return bytes(out[:n])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('gb'); ap.add_argument('out')
    ap.add_argument('--seed', type=int, default=1); ap.add_argument('--frames', type=int, default=20000)
    ap.add_argument('--every', type=int, default=400); ap.add_argument('--cols', type=int, default=8)
    a = ap.parse_args()
    tmp = tempfile.mkdtemp(prefix='survey')
    try:
        pf = os.path.join(tmp, 'pads.bin')
        open(pf, 'wb').write(bytes(1000) + pads(a.seed, a.frames + 2000))   # (title first: no input)
        cmd = [os.path.join(ROOT, 'build', 'sgbrun'), a.gb, str(a.frames), os.path.join(tmp, 's'), '--cgb',
               '--padfile', pf]
        shots = list(range(a.every, a.frames + 1, a.every))
        for f in shots: cmd += ['--shot', str(f)]
        subprocess.run(cmd, env=dict(os.environ, GB_CNT='CD80', GB_PRG='ff3'), capture_output=True)
        ims = [(f, os.path.join(tmp, 's_f%05d.ppm' % f)) for f in shots]
        ims = [(f, Image.open(p)) for f, p in ims if os.path.exists(p)]
        rows = (len(ims) + a.cols - 1) // a.cols
        sheet = Image.new('RGB', (a.cols * 164, rows * 148), (40, 40, 40))
        for k, (f, im) in enumerate(ims):
            sheet.paste(im, ((k % a.cols) * 164 + 2, (k // a.cols) * 148 + 2))
        sheet.save(a.out)
        print('wrote %s: %d shots' % (a.out, len(ims)))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
