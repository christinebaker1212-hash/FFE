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


# ---- screen mock-ups for the owner (2026-11-27): field dialogue, battle, main menu, name entry.
# They use our font, FF3's window frame cropped from an NES picture of the English build, and
# crops of NES pictures for enemies / people (all passed in at run time; nothing kept here).
from latin_font import COND


NAMES = ['DUNE', 'SPUD', 'JOJO', 'LEO']                # (the owner's FF1 mock-up party)


FRAME_PNG = [None]                                      # the NES frame with a window at (8, 152)
DIG3 = {'0': ['###', '#.#', '#.#', '#.#', '###'], '1': ['.#.', '##.', '.#.', '.#.', '###'],
        '2': ['###', '..#', '###', '#..', '###'], '3': ['###', '..#', '.##', '..#', '###'],
        '4': ['#.#', '#.#', '###', '..#', '..#'], '5': ['###', '#..', '###', '..#', '###'],
        '6': ['###', '#..', '###', '#.#', '###'], '7': ['###', '..#', '.#.', '.#.', '.#.'],
        '8': ['###', '#.#', '###', '#.#', '###'], '9': ['###', '#.#', '###', '..#', '###'],
        '/': ['..#', '..#', '.#.', '#..', '#..']}


class Canvas:
    def __init__(s, frame_png, bg=(0, 0, 0)):
        s.im = Image.new('RGB', (W, H), bg)
        f = Image.open(FRAME_PNG[0] or frame_png).convert('RGB')          # an NES battle frame: a window at (8, 152)
        s.fill = f.getpixel((50, 165))
        tl = f.crop((8, 152, 16, 160)); t = f.crop((16, 152, 24, 160)); l = f.crop((8, 160, 16, 168))
        fl = Image.FLIP_LEFT_RIGHT; ft = Image.FLIP_TOP_BOTTOM
        s.tiles = {'TL': tl, 'T': t, 'L': l, 'TR': tl.transpose(fl), 'R': l.transpose(fl),
                   'BL': tl.transpose(ft), 'B': t.transpose(ft), 'BR': tl.transpose(fl).transpose(ft)}

    def window(s, x, y, w, h):
        d = ImageDraw.Draw(s.im)
        d.rectangle([8 * x, 8 * y, 8 * (x + w) - 1, 8 * (y + h) - 1], fill=s.fill)
        for k in range(x + 1, x + w - 1):
            s.im.paste(s.tiles['T'], (8 * k, 8 * y)); s.im.paste(s.tiles['B'], (8 * k, 8 * (y + h - 1)))
        for k in range(y + 1, y + h - 1):
            s.im.paste(s.tiles['L'], (8 * x, 8 * k)); s.im.paste(s.tiles['R'], (8 * (x + w - 1), 8 * k))
        for n, (cx, cy) in (('TL', (x, y)), ('TR', (x + w - 1, y)), ('BL', (x, y + h - 1)),
                            ('BR', (x + w - 1, y + h - 1))):
            s.im.paste(s.tiles[n], (8 * cx, 8 * cy))

    def text(s, col, row, txt, c=(255, 255, 255), px=0):
        p = s.im.load()
        for i, ch in enumerate(txt):
            g = G.get(ch)
            if not g: continue
            dy = 1 if ch in DESC else 0
            for r, rowp in enumerate(g):
                for k, v in enumerate(rowp):
                    if v == '#': p[8 * col + px + 8 * i + k, 8 * row + r + dy] = c

    def small(s, x, y, txt, c=(255, 255, 255)):
        """narrow letters (latin_font COND) and 3-pixel digits, 1-pixel gaps, at pixel (x, y)"""
        p = s.im.load()
        for ch in txt:
            if ch in DIG3:
                for r, rowp in enumerate(DIG3[ch]):
                    for k, v in enumerate(rowp):
                        if v == '#': p[x + k, y + 2 + r] = c
                x += 4; continue
            g = COND.get(ch) or G.get(ch)
            if ch == ' ':
                x += 3; continue
            w = len(g[0]); dy = 1 if ch in DESC else 0
            for r, rowp in enumerate(g):
                for k, v in enumerate(rowp):
                    if v == '#': p[x + k, y + r + dy] = c
            used = [k for k in range(w) if any(rr[k] == '#' for rr in g)]
            x += (max(used) + 2) if used else 3
        return x

    def hand(s, x, y):
        """a pointing hand (placeholder drawn here; the game uses FF3's own cursor)"""
        d = ImageDraw.Draw(s.im)
        d.rectangle([x, y + 2, x + 9, y + 5], fill=(255, 255, 255))
        d.rectangle([x + 2, y + 1, x + 6, y + 7], fill=(230, 230, 230))
        d.point([(x + 10, y + 3), (x + 10, y + 4)], fill=(255, 255, 255))


def wrap(text, width):
    out = []
    for para in text.split('\n'):
        line = ''
        for w in para.split(' '):
            if line and len(line) + 1 + len(w) > width:
                out.append(line); line = w
            else:
                line = (line + ' ' + w) if line else w
        out.append(line)
    return out


def scale(im, k=3):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def sheet_of(pairs, out):
    pad = 24
    ims = [(n, scale(im)) for n, im in pairs]
    sh = Image.new('RGB', (sum(im.width + pad for _, im in ims) + pad, H * 3 + 2 * pad), (60, 60, 60))
    d = ImageDraw.Draw(sh); x = pad
    for n, im in ims:
        sh.paste(im, (x, pad)); d.text((x, 6), n, fill=(255, 255, 255)); x += im.width + pad
    sh.save(out)


def mock_battle(nes_png, field_png, outdir):
    nes = Image.open(nes_png).convert('RGB')
    members = [nes.crop((204, 44 + 27 * i, 228, 68 + 27 * i)) for i in range(4)]
    enemies = nes.crop((24, 56, 120, 150))
    strip = nes.crop((0, 24, 256, 40))
    names = NAMES
    def base(with_strip):
        c = Canvas(nes_png)
        if with_strip:
            c.im.paste(strip.crop((0, 0, 160, 16)), (0, 0))
            c.im.paste(enemies.crop((0, 0, 96, 80)), (8, 16))
        else:
            c.im.paste(enemies.crop((0, 0, 96, 94)), (8, 2))
        for i, m in enumerate(members):
            c.im.paste(m, (128, i * 24))
        c.window(0, 12, 8, 6)
        c.small(8, 104, 'Goblin  3')
        c.window(7, 12, 13, 6)
        for i, n in enumerate(names):
            c.text(8, 13 + i, n)
            c.small(116, 104 + 8 * i, '%3d/%3d' % ([32, 26, 32, 32][i], 32))
        return c
    a = base(False)
    a.window(7, 12, 9, 6)                                   # commands over the party window
    for i, t in enumerate(['Fight', 'Defend', 'Run', 'Item']):
        a.text(9, 13 + i, t)
    a.hand(58, 104)
    b = base(True)
    b.window(0, 0, 20, 3)                                   # top window: who / what
    b.text(1, 1, NAMES[0])
    b.small(64, 9, '>  Goblin')
    b.small(116, 9, '2 hits')
    c = base(False)
    c.window(0, 12, 20, 6)                                  # a message over both windows
    c.text(1, 14, 'Defeated the enemy!')
    sheet_of([('A: commands (no backdrop)', a.im), ('B: an attack (FF3 backdrop strip)', b.im),
              ('C: a message', c.im)], os.path.join(outdir, 'battle.png'))


def mock_dialogue(field_png, nes_png, text, outdir):
    c = Canvas(nes_png)
    c.im.paste(Image.open(field_png).convert('RGB'), (0, 0))
    c.window(0, 0, 20, 8)
    for i, line in enumerate(wrap(text, 18)[:6]):
        c.text(1, 1 + i, line)
    d = Canvas(nes_png)
    d.im.paste(Image.open(field_png).convert('RGB'), (0, 0))
    d.window(0, 10, 20, 8)
    for i, line in enumerate(wrap(text, 18)[:6]):
        d.text(1, 11 + i, line)
    sheet_of([('A: box at the top', c.im), ('B: box at the bottom', d.im)], os.path.join(outdir, 'dialogue.png'))


def mock_menu(nes_png, outdir):
    nes = Image.open(nes_png).convert('RGB')
    members = [nes.crop((204, 44 + 27 * i, 228, 68 + 27 * i)) for i in range(4)]
    c = Canvas(nes_png)
    c.window(0, 0, 20, 14)
    for i, (n, hp) in enumerate(zip(NAMES, [32, 26, 32, 32])):
        y0 = 8 + 24 * i
        c.im.paste(members[i].crop((4, 0, 20, 24)), (8, y0))
        c.text(4, 1 + 3 * i, n)
        c.small(32, y0 + 8, 'Onion Knight')
        c.small(32, y0 + 16, 'L1  HP %d/%d' % (hp, 32))
    c.window(11, 0, 9, 13)
    for i, t in enumerate(['Item', 'Magic', 'Equip', 'Status', 'Order', 'Job', 'Config', 'Save', 'Suspend']):
        c.small(108, 8 + 10 * i + 1, t)
    c.hand(92, 8)
    c.window(0, 14, 20, 4)
    c.text(1, 15, 'Gil')
    c.text(5, 15, '     400')
    c.text(1, 16, 'CP')
    c.text(5, 16, '      10')
    c.small(110, 121, 'Ur')
    c.small(110, 129, '0:12')
    sheet_of([('Main menu (Start)', c.im)], os.path.join(outdir, 'menu.png'))


def mock_names(nes_png, outdir):
    nes = Image.open(nes_png).convert('RGB')
    m = nes.crop((204, 44, 228, 68))
    c = Canvas(nes_png)
    c.window(0, 0, 20, 4)
    c.im.paste(m.crop((4, 0, 20, 24)), (8, 4))
    c.text(4, 1, NAMES[0])
    c.small(32, 17, 'Onion Knight')
    c.window(0, 4, 20, 14)
    rows = ['A B C D E F G H I', 'J K L M N O P Q R', 'S T U V W X Y Z',
            "0 1 2 3 4 5 6 7 8", "9 . , ' - ! ? & /"]
    for i, r in enumerate(rows):
        c.text(2, 5 + 2 * i, r)
    c.small(12, 129, 'Select abc   B Delete   Start Done')
    c.hand(2, 40)
    sheet_of([('New Game: names', c.im)], os.path.join(outdir, 'names.png'))
