"""Run the FF3 GBC build headless in PyBoy (CGB mode) and save screenshots / fault info.

usage: run_gb.py ROM FRAMES [--shots F1,F2,..] [--out DIR] [--press KEY@FRAME[+HOLD],..]
Prints the runtime's fault record (DBG) and the NES frame-wait count at the end.
Note: PyBoy does not emulate CGB double speed (timing is not representative)."""
import sys, os, argparse
from pyboy import PyBoy

def sym(path):
    s = {}
    for l in open(path):
        if l.startswith(';') or ':' not in l: continue
        a, n = l.split()
        b, o = a.split(':'); s[n] = (int(b, 16), int(o, 16))
    return s

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rom'); ap.add_argument('frames', type=int)
    ap.add_argument('--shots', default=''); ap.add_argument('--out', default='build/ff3/shots')
    ap.add_argument('--press', default='')
    a = ap.parse_args()
    S = sym(os.path.splitext(a.rom)[0] + '.sym')
    pb = PyBoy(a.rom, window='null', cgb=True)
    shots = {int(x) for x in a.shots.split(',') if x}
    press = {}
    for p in [x for x in a.press.split(',') if x]:
        k, f = p.split('@'); h = 6
        if '+' in f: f, h = f.split('+')
        press.setdefault(int(f), []).append((k, int(h)))
    os.makedirs(a.out, exist_ok=True)
    rel = {}
    for f in range(a.frames):
        for k, h in press.get(f, []):
            pb.button_press(k); rel.setdefault(f + h, []).append(k)
        for k in rel.pop(f, []): pb.button_release(k)
        pb.tick(1, f in shots)
        if f in shots:
            pb.screen.image.save(os.path.join(a.out, 'f%05d.png' % f))
    dbg = 0xCD80
    m = pb.memory
    d = [m[dbg + i] for i in range(16)]
    nmi = m[0xCD90] | m[0xCD91] << 8; vbl = m[0xCD92] | m[0xCD93] << 8
    print('frames %d: GB vblanks %d, NES frame waits %d' % (a.frames, vbl, nmi))
    print('DBG: code %02X HL %02X%02X SP %02X%02X ret %02X%02X bank %02X' % (d[0], d[2], d[1], d[4], d[3], d[6], d[5], d[7]))
    pb.stop(save=False)

if __name__ == '__main__':
    main()
