"""PNG mock-ups of FF3 GB screens for the owner (no game data: our own font and text only).

usage: mockup.py OUTDIR   (writes cgbonly.png)"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from latin_font import G, DESC
from PIL import Image, ImageDraw

W, H, S = 160, 144, 3
DMG = [(255, 255, 255), (170, 170, 170), (85, 85, 85), (0, 0, 0)]      # shades 0-3

def text(px, x, y, s, c):
    for i, ch in enumerate(s):
        g = G[ch]; dy = 1 if ch in DESC else 0
        for r, row in enumerate(g):
            for k, p in enumerate(row):
                if p == '#': px[x + 8 * i + k, y + r + dy] = c

def centred(px, row, s, c, cols=20):
    text(px, 8 * ((cols - len(s)) // 2), 8 * row, s, c)

def frame(px, x0, y0, w, h, edge, fill):
    for y in range(8 * y0, 8 * (y0 + h)):
        for x in range(8 * x0, 8 * (x0 + w)):
            px[x, y] = fill
    d = ImageDraw.Draw(px._img)
    for i, c in ((1, edge), (2, DMG[1])):
        d.rectangle([8 * x0 + i, 8 * y0 + i, 8 * (x0 + w) - 1 - i, 8 * (y0 + h) - 1 - i], outline=c)

class PX:
    def __init__(s, img): s._img = img; s._p = img.load()
    def __setitem__(s, k, v): s._p[k] = v

LINES = ["This Game Pak is", "designed only", "for use on the", "Game Boy Color."]

def variant_a():
    im = Image.new('RGB', (W, H), DMG[0]); px = PX(im)
    for i, s in enumerate(LINES): centred(px, 5 + 2 * i, s, DMG[3])
    return im

def variant_b():
    im = Image.new('RGB', (W, H), DMG[3]); px = PX(im)
    centred(px, 2, "FINAL FANTASY III", DMG[0])
    frame(px, 1, 5, 18, 11, DMG[0], DMG[3])
    for i, s in enumerate(LINES): centred(px, 7 + 2 * i, s, DMG[0])
    return im

def sheet(out):
    ims = [("A", variant_a()), ("B", variant_b())]
    pad = 24; sh = Image.new('RGB', (len(ims) * (W * S + pad) + pad, H * S + 2 * pad), (60, 60, 60))
    d = ImageDraw.Draw(sh)
    for i, (name, im) in enumerate(ims):
        x = pad + i * (W * S + pad)
        sh.paste(im.resize((W * S, H * S), Image.NEAREST), (x, pad))
        d.text((x, 6), name, fill=(255, 255, 255))
    sh.save(out)

if __name__ == '__main__':
    os.makedirs(sys.argv[1], exist_ok=True)
    sheet(os.path.join(sys.argv[1], 'cgbonly.png'))
