"""Side-by-side screens: the English NES build (cynes) and the GB build (Gambatte, build/gbrun)
at the same NES frame waits (synchronous waits: writes of JMP to $0100).

usage: PYTHONPATH=build/emu3 cmpshots.py NES GB OUT.png K1,K2,.. [--press KEY@WAIT,..]
  (no input yet: the same frames with no buttons)
The NES picture is drawn with the GB view (camera 48, 48) outlined."""
import sys, os, subprocess, tempfile
from PIL import Image, ImageDraw
from cynes import NES

def nes_frames(path, ks):
    n = NES(path); n.watch = (0x100, 0x100)
    waits = 0; out = {}; f = 0
    while len(out) < len(ks) and f < 100000:
        fr = n.step(1); f += 1
        waits += sum(1 for i, a, v in n.watch if v == 0x4C)
        for k in ks:
            if k not in out and waits >= k: out[k] = Image.fromarray(fr.copy())
    return out

def gb_frames(gb, ks):
    d = tempfile.mkdtemp(prefix='ff3cmp_')
    cmd = [os.path.join(os.path.dirname(gb), 'gbrun'), gb, str(max(ks) * 3 + 600), os.path.join(d, 's')]
    for k in ks: cmd += ['--nshot', str(k)]
    subprocess.run(cmd, capture_output=True)
    out = {}
    for k in ks:
        p = os.path.join(d, 's_n%05d.ppm' % k)
        if os.path.exists(p): out[k] = Image.open(p).convert('RGB')
    return out

def main():
    nes, gb, outp, ks = sys.argv[1], sys.argv[2], sys.argv[3], [int(x) for x in sys.argv[4].split(',')]
    a = nes_frames(nes, ks); b = gb_frames(gb, ks)
    W = 256 + 8 + 320; H = 240
    sheet = Image.new('RGB', (W, (H + 14) * len(ks)), (40, 40, 40))
    dr = ImageDraw.Draw(sheet)
    for r, k in enumerate(ks):
        y = r * (H + 14)
        dr.text((2, y), 'NES wait %d' % k, fill=(255, 255, 255))
        if k in a:
            im = a[k].copy(); d2 = ImageDraw.Draw(im); d2.rectangle([48, 48, 48 + 159, 48 + 143], outline=(255, 0, 0))
            sheet.paste(im, (0, y + 12))
        if k in b: sheet.paste(b[k].resize((320, 288), Image.NEAREST).crop((0, 0, 320, H)), (264, y + 12))
    sheet.save(outp)
    print('wrote', outp, 'NES', sorted(a), 'GB', sorted(b))

if __name__ == '__main__':
    main()
