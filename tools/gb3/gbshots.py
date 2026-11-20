"""NES / GBC screens side by side at the same waited-for frames, the GB in mGBA (build/sgbrun,
CGB double speed) with its input clock set to the NES's at each waited-for frame (as
lagcheck.py --resync), so state-dependent input scripts (explore) stay on the NES's path.

usage: PYTHONPATH=build/emu3 gbshots.py NES GB OUT.png W1,W2,.. [--input NAME] [--scale N]
                                         [--freeze W]

Left: the NES frame; right: the GB screen (160x144), both at the same pixel scale.
Output in build/ only (it shows game graphics).
"""
import sys, os, argparse, subprocess, tempfile, shutil, struct
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
from cmpshots import INPUTS, Waits
from PIL import Image, ImageDraw


def ppm(path):
    return Image.open(path).convert('RGB')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('nes'); ap.add_argument('gb'); ap.add_argument('out'); ap.add_argument('waits')
    ap.add_argument('--input', default='explore'); ap.add_argument('--scale', type=int, default=2)
    ap.add_argument('--freeze', type=int, default=0, help='no input from this waited-for frame on')
    ap.add_argument('--press', default='', help='W:PAD:N,.. : pad PAD for N waited-for frames from W (after --freeze)')
    ap.add_argument('--poke', default='', help='W:ADDR=VAL,.. : write NES RAM / PRG-RAM at waited-for frame W (both sides)')
    ap.add_argument('--pressf', default='', help='F:PAD:N,.. : pad PAD for N NES frames from frame F after the poke (for loops that poll without waiting)')
    ap.add_argument('--dump', help='directory: also the GB memory at each shot (sgbrun SGBRUN_DUMP)')
    a = ap.parse_args()
    ws = [int(x) for x in a.waits.split(',')]
    presses = [tuple(int(v, 0) for v in p.split(':')) for p in a.press.split(',') if p]
    poke = (int(a.poke.split(':')[0]), a.poke.split(':', 1)[1]) if a.poke else None
    poke_k = None; fpk = 0
    pressf = [tuple(int(v, 0) for v in p.split(':')) for p in a.pressf.split(',') if p]
    from cynes import NES
    import cmpshots
    pad = INPUTS[a.input]
    n = NES(a.nes); cmpshots.CUR_NES = n; W = Waits(n); k = 0; clock = {}; frames = {}
    top = max(ws)
    while n.ff3_waits <= top:
        n.controller = pad(k + 1) if not a.freeze or n.ff3_waits < a.freeze else 0
        for pw, pv, pn in presses:
            if pw <= n.ff3_waits < pw + pn: n.controller = pv
        if poke_k is not None:
            fpk += 1
            for pf, pv, pn in pressf:
                if pf <= fpk < pf + pn: n.controller = pv
        if poke and poke_k is None and n.ff3_waits >= poke[0]:
            import numpy as np
            st = bytearray(n.save())
            for av in poke[1].split(','):
                ad, v = (int(x, 16) for x in av.split('='))
                st[(0x500A + ad) if ad < 0x800 else (0x23E2 + ad - 0x6000)] = v   # (cynes state offsets)
            n.load(np.array(st, dtype=np.uint8)); poke_k = k
        fr = n.step(1); k = W.update()
        clock.setdefault(n.ff3_waits, k)
        for w in ws:
            if w not in frames and n.ff3_waits >= w:
                frames[w] = Image.fromarray(fr.copy()).convert('RGB'); clock.setdefault(-w, k)
    tmp = tempfile.mkdtemp(prefix='gbshots')
    try:
        pads = os.path.join(tmp, 'pads.bin')
        open(pads, 'wb').write(bytes(W.latch.get(j - 1, W.latch.get(j - 2, 0)) for j in range(k + 200)))
        cf = os.path.join(tmp, 'clock.bin')
        open(cf, 'wb').write(b''.join(struct.pack('<H', clock[w] & 0xFFFF if w in clock else 0xFFFF)
                                      for w in range(max(clock) + 1)))   # (keys < 0: shot frames)
        cmd = [os.path.join(ROOT, 'build', 'sgbrun'), a.gb, str(int(k * 1.3) + 600), os.path.join(tmp, 'q'),
               '--cgb', '--padfile', pads]
        for w in ws: cmd += ['--nshot', str(clock[-w])]
        if poke: cmd += ['--poke', str(poke_k + 1), poke[1]]
        env = dict(os.environ, SGBRUN_CLOCK=cf)
        if a.dump: env['SGBRUN_DUMP'] = '1'
        res = subprocess.run(cmd, env=env, capture_output=True, text=True)
        if os.environ.get('GBSHOTS_LOG'):
            open(os.environ['GBSHOTS_LOG'], 'w').write(res.stdout + res.stderr)
        s = a.scale
        sheet = Image.new('RGB', ((256 + 8 + 160) * s, 244 * s * len(ws)), (40, 40, 40))
        d = ImageDraw.Draw(sheet)
        for i, w in enumerate(ws):
            y = 244 * s * i
            sheet.paste(frames[w].resize((256 * s, 240 * s), Image.NEAREST), (0, y))
            p = os.path.join(tmp, 'q_n%05d.ppm' % clock[-w])
            if os.path.exists(p):
                sheet.paste(ppm(p).resize((160 * s, 144 * s), Image.NEAREST), ((256 + 8) * s, y))
            d.text((2, y + 2), 'wait %d' % w, fill=(255, 255, 0))
            if a.dump and os.path.exists(p[:-4] + '.mem'):
                os.makedirs(a.dump, exist_ok=True)
                shutil.copy(p[:-4] + '.mem', os.path.join(a.dump, 'w%05d.mem' % w))
                frames[w].save(os.path.join(a.dump, 'w%05d_nes.png' % w))
        sheet.save(a.out)
        print('wrote', a.out)
    finally:
        if os.environ.get('GBSHOTS_KEEP'): print('kept', tmp)
        else: shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
