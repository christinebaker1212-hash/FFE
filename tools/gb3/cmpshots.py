"""Side-by-side screens: the English NES build (cynes) and the GB build (Gambatte, build/gbrun)
at the same NES frame waits (counted as the GB runtime does: class Waits).

usage: PYTHONPATH=build/emu3 cmpshots.py NES GB OUT.png K1,K2,.. [--input NAME]
  --input: a pad script (pads(): one NES pad byte per frame wait; bit 0 Right .. 7 A), fed
  to the NES by its wait count and to the GB through gbrun --padfile (test mode)
The NES picture is drawn with the GB view (camera 48, 48) outlined."""
import sys, os, subprocess, tempfile
from PIL import Image, ImageDraw
from cynes import NES

A, START = 128, 16
INPUTS = {
    'none': lambda w: 0,
    'newgame': None,                     # (newgame_pad below)
}
RIGHT = 1

def newgame_pad(w):
    """A every 16 waits from 1000 (second narration page, New Game) until name entry
    (~1342); from 1360 four names (FF3 rejects a name equal to an earlier one): A x 7
    (6 letters + confirm), then Right (next letter of the grid) before the next name; then
    A every 16 waits (the opening scene)"""
    if w <= 1000: return 0
    if w < 1360: return A if w % 16 < 4 else 0
    k = (w - 1360) // 16; ph = (w - 1360) % 16
    if ph >= 4: return 0
    per = 8                               # A x 7, then Right
    if k < 4 * per:
        return RIGHT if k % per == per - 1 else A
    return A
INPUTS['newgame'] = newgame_pad

class Waits:
    """NES frames as the GB runtime counts them (NMI_CNT): NMIs that end a synchronous wait
    (RAM vector $0100 = JMP $FF2A) or run the battle / cutscene handler (JMP $FB57); an
    NMI through RTI is nobody's frame. Counted inside the emulator (build/emu3: nmi_count,
    nmi_ram, pad_history count only those NMIs). latch[k]: the pad the NES latched between
    frames k and k + 1 (pad_history[k + 1]), which the GB reads from slot k."""
    def __init__(self, n):
        self.n = n; self.latch = {}; self.count = n.nmi_count
    def update(self, controller=None):
        k = self.n.nmi_count
        if k != self.count:
            ph = self.n.pad_history
            for j in range(self.count + 1, k + 1): self.latch[j - 1] = ph[j & 0xFF]
            self.count = k
        return k

def nes_frames(path, ks, pad):
    n = NES(path); W = Waits(n)
    waits = 0; out = {}; f = 0
    while len(out) < len(ks) and f < 100000:
        n.controller = pad(waits + 1)
        fr = n.step(1); f += 1
        waits = W.update()
        for k in ks:
            if k not in out and waits >= k: out[k] = Image.fromarray(fr.copy())
    return out

def gb_frames(gb, ks, pad):
    d = tempfile.mkdtemp(prefix='ff3cmp_')
    pf = os.path.join(d, 'pads.bin')
    # (gbrun puts pads[k + 1] in slot k; the GB reads slot k after frame k: pad(k), as cynes)
    open(pf, 'wb').write(bytes(pad(w - 1) if w else 0 for w in range(max(ks) + 64)))
    cmd = [os.path.join(os.path.dirname(gb), 'gbrun'), gb, str(max(ks) * 3 + 600), os.path.join(d, 's'), '--padfile', pf]
    for k in ks: cmd += ['--nshot', str(k)]
    subprocess.run(cmd, capture_output=True)
    out = {}
    for k in ks:
        p = os.path.join(d, 's_n%05d.ppm' % k)
        if os.path.exists(p): out[k] = Image.open(p).convert('RGB')
    return out

def main():
    nes, gb, outp, ks = sys.argv[1], sys.argv[2], sys.argv[3], [int(x) for x in sys.argv[4].split(',')]
    pad = INPUTS[sys.argv[sys.argv.index('--input') + 1] if '--input' in sys.argv else 'none']
    a = nes_frames(nes, ks, pad); b = gb_frames(gb, ks, pad)
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
