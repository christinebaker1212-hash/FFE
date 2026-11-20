"""FF3 GBC screen mock-ups (160x144) for layout review before the NES code is changed.

usage: PYTHONPATH=build/emu3 mockup.py NES OUTDIR

Built from the user's own ROM at run time (nothing game-specific is stored here): the English
NES build is run (cynes) with the explore script to battle frames; the enemy area, the party
column and the window frame tiles are cut from those frames, and text is drawn with the
English patch's font (tools/latin_font.py, the same glyphs insert.py puts in the ROM).
Output: PNG mock-ups (x3) in OUTDIR (build/ only: they contain game graphics).
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..'))
from PIL import Image
from latin_font import tile

# NES battle geometry (FF3, measured from the monster position tables and frames):
ENEMY = (2 * 8, 6 * 8, 20 * 8, 18 * 8)          # NES cols 2-19, rows 6-17: every formation
PARTY_X = 208                                    # party column: 16 px wide sprites
WIN = (8, 152, 88, 232)                          # a battle window (frame tiles cut from it)


def capture(nes, waits, script='explore'):
    import cmpshots
    from cmpshots import INPUTS, Waits
    from cynes import NES
    n = NES(nes); cmpshots.CUR_NES = n; W = Waits(n); k = 0; out = {}
    pad = INPUTS[script]
    while len(out) < len(waits):
        n.controller = pad(k + 1); fr = n.step(1); k = W.update()
        for w in waits:
            if w not in out and n.ff3_waits >= w: out[w] = Image.fromarray(fr.copy()).convert('RGB')
    return out


class Tiles:
    """window tiles cut from an NES battle frame"""
    def __init__(self, fr):
        x0, y0, x1, y1 = WIN
        c = lambda x, y: fr.crop((x, y, x + 8, y + 8))
        self.tl, self.tr = c(x0, y0), c(x1 - 8, y0)
        self.bl, self.br = c(x0, y1 - 8), c(x1 - 8, y1 - 8)
        self.t, self.b = c(x0 + 8, y0), c(x0 + 8, y1 - 8)
        self.l, self.r = c(x0, y0 + 8), c(x1 - 8, y0 + 8)
        self.fill = fr.getpixel((x0 + 20, y0 + 12))
        self.ink = (255, 255, 255)
        # the brightest pixel inside the window: the text colour
        best = self.fill
        for y in range(y0 + 8, y1 - 8):
            for x in range(x0 + 8, x1 - 8):
                p = fr.getpixel((x, y))
                if sum(p) > sum(best): best = p
        self.ink = best


class Screen:
    def __init__(self, tiles):
        self.im = Image.new('RGB', (160, 144), (0, 0, 0)); self.T = tiles

    def paste(self, img, x, y): self.im.paste(img, (x, y))

    def window(self, c, r, w, h):
        """tile coords: frame from (c, r), w x h tiles"""
        T = self.T
        for j in range(h):
            for i in range(w):
                x, y = (c + i) * 8, (r + j) * 8
                if j == 0: t = T.tl if i == 0 else T.tr if i == w - 1 else T.t
                elif j == h - 1: t = T.bl if i == 0 else T.br if i == w - 1 else T.b
                else: t = T.l if i == 0 else T.r if i == w - 1 else None
                if t is None: self.im.paste(T.fill, (x, y, x + 8, y + 8))
                else: self.im.paste(t, (x, y))

    def text(self, c, r, s, ink=None):
        ink = ink or self.T.ink
        for k, ch in enumerate(s):
            if ch == ' ': continue
            if ch == '>':                        # (an arrow: not in the font yet)
                rows = ['........', '...#....', '...##...', '#######.', '#######.', '...##...',
                        '...#....', '........']
                for y, row in enumerate(rows):
                    for x, v in enumerate(row):
                        if v == '#': self.im.putpixel(((c + k) * 8 + x, r * 8 + y), ink)
                continue
            t = tile(ch, fg=3, bg=0)
            for y in range(8):
                p0, p1 = t[y], t[y + 8]
                for x in range(8):
                    if ((p0 >> (7 - x)) & 1) | ((p1 >> (7 - x)) & 1):
                        self.im.putpixel(((c + k) * 8 + x, r * 8 + y), ink)

    def hand(self, x, y, img):
        if img is not None:
            m = img.convert('RGB')
            for yy in range(m.height):
                for xx in range(m.width):
                    p = m.getpixel((xx, yy))
                    if p != (0, 0, 0) and 0 <= x + xx < 160 and 0 <= y + yy < 144:
                        self.im.putpixel((x + xx, y + yy), p)

    def save(self, path, scale=3):
        self.im.resize((160 * scale, 144 * scale), Image.NEAREST).save(path)


def battlefield(fr, s, party_col=18):
    """enemy area (NES cols 2-19, rows 6-17) -> GB cols 0-17, rows 0-11; party column at
    GB col party_col"""
    s.paste(fr.crop(ENEMY), 0, 0)
    # party: NES members at y 45 + 28i (23 px tall): on the GB 24 px apart (owner: all four
    # fully visible), from y 0
    for i in range(4):
        y0 = 45 + 28 * i
        xs = [x for x in range(176, 240) for y in range(y0, y0 + 23) if sum(fr.getpixel((x, y))) > 60]
        x0 = min(xs) if xs else PARTY_X           # (a member stepped forward: crop where it is)
        s.paste(fr.crop((x0, y0, x0 + 16, y0 + 24)), party_col * 8, 24 * i)


PARTY = [('AAAAAA', 32, 32), ('AAAAAB', 26, 32), ('BBBBBC', 32, 32), ('CCCCCD', 32, 32)]


def main():
    nes, outd = sys.argv[1], sys.argv[2]
    os.makedirs(outd, exist_ok=True)
    fr = capture(nes, [8950, 9000])
    base, cmd = fr[8950], fr[9000]
    T = Tiles(cmd)
    outs = []

    # A: full-width party window; the command window opens over its left part
    s = Screen(T); battlefield(base, s)
    s.window(0, 12, 20, 6)
    for i, (nm, hp, mx) in enumerate(PARTY):
        s.text(1, 13 + i, '%-6s %4d/%4d' % (nm, hp, mx))
    s.save(os.path.join(outd, 'A1_party.png')); outs.append('A1_party.png')
    s = Screen(T); battlefield(base, s)
    s.window(0, 12, 20, 6)
    for i, (nm, hp, mx) in enumerate(PARTY):
        s.text(1, 13 + i, '%-6s %4d/%4d' % (nm, hp, mx))
    s.window(0, 12, 9, 6)
    for i, c in enumerate(('Fight', 'Defend', 'Run', 'Item')):
        s.text(2, 13 + i, c)
    s.save(os.path.join(outd, 'A2_command.png')); outs.append('A2_command.png')

    # B: commands / names / messages left (9 columns), party right (11 columns: name + HP)
    s = Screen(T); battlefield(base, s)
    s.window(0, 12, 9, 6)
    for i, c in enumerate(('Fight', 'Defend', 'Run', 'Item')):
        s.text(2, 13 + i, c)
    s.window(9, 12, 11, 6)
    for i, (nm, hp, mx) in enumerate(PARTY):
        s.text(10, 13 + i, '%-6s%3d' % (nm, hp))
    s.save(os.path.join(outd, 'B1_command.png')); outs.append('B1_command.png')

    # messages: full-width window over the party window (FF1's approved style)
    s = Screen(T); battlefield(base, s)
    s.window(0, 12, 20, 6)
    s.text(1, 13, 'BBBBBC > Goblin')
    s.text(1, 14, '1 hits')
    s.text(1, 16, 'Defeated the enemy!')
    s.save(os.path.join(outd, 'M1_message.png')); outs.append('M1_message.png')

    # enemy names while targeting (left window), party right
    s = Screen(T); battlefield(base, s)
    s.window(0, 12, 9, 6)
    s.text(1, 13, 'Goblin')
    s.window(9, 12, 11, 6)
    for i, (nm, hp, mx) in enumerate(PARTY):
        s.text(10, 13 + i, '%-6s%3d' % (nm, hp))
    s.save(os.path.join(outd, 'T1_target.png')); outs.append('T1_target.png')

    # A-style targeting: enemy names over the party window's left part
    s = Screen(T); battlefield(base, s)
    s.window(0, 12, 20, 6)
    for i, (nm, hp, mx) in enumerate(PARTY):
        s.text(1, 13 + i, '%-6s %4d/%4d' % (nm, hp, mx))
    s.window(0, 12, 9, 6)
    s.text(1, 13, 'Goblin')
    s.save(os.path.join(outd, 'A3_target.png')); outs.append('A3_target.png')
    outs = ['A1_party.png', 'A2_command.png', 'A3_target.png', 'M1_message.png']

    # sheet: the NES frame and the mock-ups side by side (x2)
    ims = [Image.open(os.path.join(outd, o)).resize((320, 288), Image.NEAREST) for o in outs]
    nes2 = cmd.resize((512, 480), Image.NEAREST)
    sheet = Image.new('RGB', (512 + 8 + 320 * 3 + 16, max(480, 288 * 2 + 8)), (40, 40, 40))
    sheet.paste(nes2, (0, 0))
    for i, im in enumerate(ims):
        sheet.paste(im, (520 + (i % 3) * 328, (i // 3) * 296))
    sheet.save(os.path.join(outd, 'battle_sheet.png'))
    print('wrote', outd, outs)


if __name__ == '__main__':
    main()
