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


def hand_img(nes):
    """FF3's hand cursor, cut from the NES frame of the command window (no input from wait
    2690 of the explore script on)"""
    import cmpshots
    from cmpshots import INPUTS, Waits
    from cynes import NES
    n = NES(nes); cmpshots.CUR_NES = n; W = Waits(n); k = 0; pad = INPUTS['explore']
    w0 = n.ff3_waits                       # (the emulator's wait count is per process)
    while n.ff3_waits - w0 < 2760:
        n.controller = pad(k + 1) if n.ff3_waits - w0 < 2690 else 0
        fr = n.step(1); k = W.update()
    im = Image.fromarray(fr.copy()).convert('RGB')
    # the hand over the command window's frame (GB-layout ROM: x 16-31, y 160-175), with the
    # frame and window behind it (the mock-ups put it at the same place: GB column 0)
    return im.crop((16, 160, 32, 176))


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


FONT = 0x1B000                                   # English font in the NES ROM: tile N = code N


class RomFont:
    """text from the English NES ROM's own font (letters as tools/ff3/insert.py codes them,
    [xx] = a code: the icons)"""
    def __init__(self, nes):
        self.d = open(nes, 'rb').read()
        from importlib import util
        spec = util.spec_from_file_location('ff3insert', os.path.join(HERE, '..', 'ff3', 'insert.py'))
        self.enc = None
        src = open(os.path.join(HERE, '..', 'ff3', 'insert.py')).read()
        ns = {}
        exec(src[src.index('ENC = {'):src.index('NEW_GLYPHS')], ns)
        self.enc = ns['ENC']

    def codes(self, s):
        import re
        out = []; i = 0
        while i < len(s):
            m = re.match(r'\[([0-9A-F]{2})\]', s[i:])
            if m: out.append(int(m.group(1), 16)); i += 4; continue
            out.append(self.enc[s[i]]); i += 1
        return out

    def draw(self, scr, c, r, s, ink, dy=0):
        for k, code in enumerate(self.codes(s)):
            if code == 0xFF: continue
            o = 16 + FONT + code * 16
            for y in range(8):
                p0, p1 = self.d[o + y], self.d[o + 8 + y]
                for x in range(8):
                    v = ((p0 >> (7 - x)) & 1) | (((p1 >> (7 - x)) & 1) << 1)
                    if v == 3 and 0 <= r * 8 + y - dy: scr.im.putpixel(((c + k) * 8 + x, r * 8 + y - dy), ink)


def item_rows(name, count):
    """FF3's English battle item entry (13 wide, two rows): the name and ':nn' on the main row
    when the name fits 9, else part 1 above, part 2 and ':nn' below"""
    import re
    vis = re.sub(r'\[..\]', 'I', name)
    tail = ':%2d' % count
    if len(vis) <= 9: return ['', ' ' + name.ljust(10 + len(name) - len(vis)) + tail]
    words = name.split(' ')
    a = words[0]; b = ' '.join(words[1:])
    return [' ' + a, '  ' + b.ljust(9) + tail]


ITEMS = [('Potion', 5), ('Phoenix Tail', 2), ('[6B]Longsword', 1), ('[61]Leather Armor', 1),
         ('Antidote', 3), ('Eye Drops', 2), ("Maiden's Kiss", 1), ('Echo Herb', 1)]
SPELLS = [('1', ['[75]Fire', '[75]Blizzard', '[75]Sleep'], '9/9'), ('2', ['[75]Thunder', '[75]Poison', '[75]Blind'], '7/7'),
          ('3', ['[75]Fira', '[75]Blizzara', '[75]Thundara'], '5/5'), ('4', ['[75]Break', '[75]Blizzaga', '[75]Shade'], '2/2')]


def lists(nes, outd, base, cmd, hand):
    """battle Item / Magic list mock-ups: (1) the list in a tall window (GB rows 8-17; the
    battlefield's NES rows 6-13 above), (2) in the 6-row window (GB rows 12-17)"""
    F = RomFont(nes); T = Tiles(cmd); outs = []
    def field(rows):
        s = Screen(T); battlefield(base, s)
        s.im.paste((0, 0, 0), (0, rows * 8, 160, 144))
        return s
    def item_page(s, top, n):
        s.window(0, top, 15, 2 * n + 2)
        s.window(15, top, 15, 2 * n + 2)         # (the next column, cut by the screen edge)
        for i, (nm, ct) in enumerate(ITEMS[:n]):
            for j, line in enumerate(item_rows(nm, ct)):
                F.draw(s, 1, top + 1 + 2 * i + j, line, T.ink)
        for i, (nm, ct) in enumerate(ITEMS[4:4 + n]):
            F.draw(s, 16, top + 2 + 2 * i, ' ' + nm[:3], T.ink)
    def magic_page(s, top, n):
        s.window(0, top, 20, 2 * n + 2)
        for i, (lv, sp, mp) in enumerate(SPELLS[:n]):
            r = top + 1 + 2 * i
            F.draw(s, 1, r, sp[0], T.ink); F.draw(s, 10, r, sp[1], T.ink)
            F.draw(s, 1, r + 1, sp[2], T.ink); F.draw(s, 11, r + 1, 'L' + lv + ' ' + mp, T.ink)
    s = field(8); item_page(s, 8, 4); s.save(os.path.join(outd, 'L1_items_tall.png')); outs.append('L1_items_tall.png')
    s = field(12); item_page(s, 12, 2); s.save(os.path.join(outd, 'L2_items_short.png')); outs.append('L2_items_short.png')
    s = field(8); magic_page(s, 8, 4); s.save(os.path.join(outd, 'L3_magic_tall.png')); outs.append('L3_magic_tall.png')
    s = field(12); magic_page(s, 12, 2); s.save(os.path.join(outd, 'L4_magic_short.png')); outs.append('L4_magic_short.png')
    ims = [Image.open(os.path.join(outd, o)) for o in outs]
    sheet = Image.new('RGB', (480 * 2 + 16, 432 * 2 + 16), (40, 40, 40))
    for i, im in enumerate(ims):
        sheet.paste(im, ((i % 2) * 496, (i // 2) * 448))
    sheet.save(os.path.join(outd, 'lists_sheet.png'))
    print('wrote', outd, outs)


def magic_options(nes, outd, base, cmd):
    """clearer battle magic list layouts (owner: the two-row mix is confusing): A = a level line
    then the spells (2 rows), 3 levels in a tall window of 9 rows; B = a level line then one spell
    per row, 2 levels; D = two rows per level with labelled level / MP on row 2"""
    F = RomFont(nes); T = Tiles(cmd); outs = []
    def field(rows):
        s = Screen(T); battlefield(base, s)
        s.im.paste((0, 0, 0), (0, rows * 8, 160, 144))
        return s
    sp = SPELLS[::-1]                                  # (highest level first, as FF3)
    s = field(7); s.window(0, 7, 20, 11)
    for i, (lv, names, mp) in enumerate(sp[:3]):
        r = 8 + 3 * i
        F.draw(s, 1, r, 'Lv' + lv, T.ink); F.draw(s, 11, r, 'MP ' + mp, T.ink)
        F.draw(s, 1, r + 1, names[0], T.ink); F.draw(s, 10, r + 1, names[1], T.ink)
        F.draw(s, 1, r + 2, names[2], T.ink)
    s.save(os.path.join(outd, 'MA_level_line.png')); outs.append('MA_level_line.png')
    s = field(8); s.window(0, 8, 20, 10)
    for i, (lv, names, mp) in enumerate(sp[:2]):
        r = 9 + 4 * i
        F.draw(s, 1, r, 'Lv' + lv, T.ink); F.draw(s, 11, r, 'MP ' + mp, T.ink)
        for j in range(3): F.draw(s, 1, r + 1 + j, names[j], T.ink)
    s.save(os.path.join(outd, 'MB_one_per_row.png')); outs.append('MB_one_per_row.png')
    s = field(8); s.window(0, 8, 20, 10)
    for i, (lv, names, mp) in enumerate(sp[:4]):
        r = 9 + 2 * i
        F.draw(s, 1, r, names[0], T.ink); F.draw(s, 10, r, names[1], T.ink)
        F.draw(s, 1, r + 1, names[2], T.ink); F.draw(s, 10, r + 1, 'Lv' + lv + ' MP' + mp, T.ink)
    s.save(os.path.join(outd, 'MD_labelled.png')); outs.append('MD_labelled.png')
    ims = [Image.open(os.path.join(outd, o)) for o in outs]
    sheet = Image.new('RGB', (480 * 3 + 32, 432), (40, 40, 40))
    for i, im in enumerate(ims): sheet.paste(im, (i * 496, 0))
    sheet.save(os.path.join(outd, 'magic_options.png'))
    print('wrote', outd, outs)


DIG3 = {
    '0': ["###", "#.#", "#.#", "#.#", "#.#", "#.#", "###"], '1': [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    '2': ["###", "..#", "..#", "###", "#..", "#..", "###"], '3': ["###", "..#", "..#", ".##", "..#", "..#", "###"],
    '4': ["#.#", "#.#", "#.#", "###", "..#", "..#", "..#"], '5': ["###", "#..", "#..", "###", "..#", "..#", "###"],
    '6': ["###", "#..", "#..", "###", "#.#", "#.#", "###"], '7': ["###", "..#", "..#", ".#.", ".#.", ".#.", ".#."],
    '8': ["###", "#.#", "#.#", "###", "#.#", "#.#", "###"], '9': ["###", "#.#", "#.#", "###", "..#", "..#", "###"],
    '/': ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."]}


def mp_tiles(scr, c, r, digits, ink):
    """the MP of the 8 spell levels in 3-px digits: each tile = digit + '/' (8 tiles)"""
    x = c * 8
    for k, d in enumerate(digits):
        for part in (d, '/') if k < len(digits) - 1 else (d,):
            for yy, row in enumerate(DIG3[part]):
                for xx, v in enumerate(row):
                    if v == '#': scr.im.putpixel((x + xx, r * 8 + yy), ink)
            x += 4


def small_text(scr, x, y, s, ink):
    """3-px digits / '/' / 'L' at pixel x, y (4 px per character)"""
    extra = {'L': ["#..", "#..", "#..", "#..", "#..", "#..", "###"], 'C': ["###", "#..", "#..", "#..", "#..", "#..", "###"],
             'G': ["###", "#..", "#..", "#.#", "#.#", "#.#", "###"], ' ': ["..."] * 7}
    for ch in s:
        g = DIG3.get(ch) or extra[ch]
        for yy, row in enumerate(g):
            for xx, v in enumerate(row):
                if v == '#': scr.im.putpixel((x + xx, y + yy), ink)
        x += 4
    return x


def condensed(scr, c, r, word, ink, ntiles=9, dy=0):
    from latin_font import packed_label, COND, TIGHT
    t = packed_label(word, ntiles, COND, fg=3, bg=0) or packed_label(word, ntiles, TIGHT, fg=3, bg=0)
    for k, tl in enumerate(t):
        for y in range(8):
            for x in range(8):
                v = ((tl[y] >> (7 - x)) & 1) | (((tl[8 + y] >> (7 - x)) & 1) << 1)
                if v: scr.im.putpixel(((c + k) * 8 + x, r * 8 + y - dy), ink)


def menu_all_fit(nes, outd, cmd):
    """owner: job names and HP compressed so all fits, HP coloured as FF3 (green): party window
    cols 0-11 (4 lines per member: name + level / job / HP / MP), commands at the top right,
    Gil and Capacity below them, the guest's window at the bottom right"""
    F = RomFont(nes); T = Tiles(cmd)
    green = (128, 208, 16)
    party = [('AAAAAA', 'Onion Knight', 28, 32, 1), ('AAAAAB', 'Black Mage', 291, 999, 12),
             ('BBBBBC', 'White Mage', 1234, 9999, 99), ('CCCCCD', 'Magic Knight', 32, 32, 1)]
    s = Screen(T)
    s.window(0, 0, 12, 18)
    for i, (nm, job, hp, mx, lv) in enumerate(party):
        r = 1 + 4 * i
        F.draw(s, 1, r, nm, T.ink); small_text(s, 8 * 8 + 2, r * 8, 'L%d' % lv, T.ink)
        condensed(s, 1, r + 1, job, T.ink, 10)
        F.draw(s, 1, r + 2, '[77][79]', green); small_text(s, 3 * 8 + 2, (r + 2) * 8, '%d/%d' % (hp, mx), green)
        F.draw(s, 1, r + 3, '[78][79]', T.ink); mp_tiles(s, 3, r + 3, '99970000', T.ink)
    s.window(12, 0, 8, 9)
    for i, c in enumerate(['Item', 'Magic', 'Equip', 'Status', 'Order', 'Job', 'Save']):
        F.draw(s, 13, 1 + i, c, T.ink)
    s.window(12, 9, 8, 4)
    small_text(s, 13 * 8 + 4, 10 * 8, '9999999G', T.ink); small_text(s, 13 * 8 + 4, 11 * 8, '    255C', T.ink)
    s.window(12, 13, 8, 5)
    F.draw(s, 13, 14, 'Sara', T.ink)
    s.save(os.path.join(outd, 'N3_all_fit.png'))
    print('wrote', os.path.join(outd, 'N3_all_fit.png'))
    # owner: our font for HP / MP, and some separation between members: party window cols
    # 0-12, the member's lines 2-4 drawn 1 / 2 / 3 px higher (shifted copies of the tiles)
    s = Screen(T)
    s.window(0, 0, 13, 18)
    party2 = [('AAAAAA', 'OnionKn', 28, 32, 1, '9997', '0000'), ('AAAAAB', 'BlkMage', 291, 999, 12, '9997', '0000'),
              ('BBBBBC', 'WhtMage', 1234, 9999, 99, '9997', '0000'), ('CCCCCD', 'MagicKn', 32, 32, 1, '9997', '0000')]
    jobs = ['Onion Knight', 'Black Mage', 'White Mage', 'Magic Knight']
    for i, (nm, _, hp, mx, lv, m1, m2) in enumerate(party2):
        r = 1 + 4 * i
        F.draw(s, 1, r, nm, T.ink); F.draw(s, 8, r, 'Lv%2d' % lv, T.ink)
        condensed(s, 1, r + 1, jobs[i], T.ink, 11, dy=1)
        F.draw(s, 1, r + 2, '[77][79]', green, dy=2); F.draw(s, 3, r + 2, ('%4d/%-4d' % (hp, mx)).replace(' ', ' '), green, dy=2)
        F.draw(s, 1, r + 3, '[78][79]', T.ink, dy=3); F.draw(s, 3, r + 3, m1 + ' ' + m2, T.ink, dy=3)
    s.window(13, 0, 7, 9)
    for i, c in enumerate(['Item', 'Magic', 'Equip', None, 'Order', 'Job', 'Save']):
        if c: F.draw(s, 14, 1 + i, c, T.ink)
        else: condensed(s, 14, 1 + i, 'Status', T.ink, 5)
    s.window(13, 9, 7, 4)
    small_text(s, 14 * 8 + 2, 10 * 8, '9999999G', T.ink); small_text(s, 14 * 8 + 2, 11 * 8, '    255C', T.ink)
    s.window(13, 13, 7, 5)
    F.draw(s, 14, 14, 'Sara', T.ink)
    s.save(os.path.join(outd, 'N4_our_font.png'))
    print('wrote', os.path.join(outd, 'N4_our_font.png'))
    # owner: "the HP and MP font is off alignment with the other fonts": FF3's HP / MP label
    # glyphs sit 1 px lower than the letters and digits (rows 1-7, the font rows 0-6), and the
    # 1 / 2 / 3 px shifts ran the lines into each other. N5: labels raised 1 px onto the digits'
    # rows; A = every line on the 8-px grid (rows line up with the command window), members
    # parted by a thin rule in the MP line's free bottom pixel row; B = the member's lines
    # drawn 0 / 1 / 1 / 2 px higher (one even step), 3 px between members, no rule
    grey = (120, 120, 120)
    for tag, shifts, rule in (('A', (0, 0, 0, 0), True), ('B', (0, 1, 1, 2), False)):
        s = Screen(T)
        s.window(0, 0, 13, 18)
        for i, (nm, _, hp, mx, lv, m1, m2) in enumerate(party2):
            r = 1 + 4 * i
            F.draw(s, 1, r, nm, T.ink, dy=shifts[0]); F.draw(s, 8, r, 'Lv%2d' % lv, T.ink, dy=shifts[0])
            condensed(s, 1, r + 1, jobs[i], T.ink, 11, dy=shifts[1])
            F.draw(s, 1, r + 2, '[77][79]', green, dy=shifts[2] + 1)
            F.draw(s, 3, r + 2, '%4d/%-4d' % (hp, mx), green, dy=shifts[2])
            F.draw(s, 1, r + 3, '[78][79]', T.ink, dy=shifts[3] + 1)
            F.draw(s, 3, r + 3, m1 + ' ' + m2, T.ink, dy=shifts[3])
            if rule and i < 3:
                for x in range(10, 12 * 8 - 2, 2): s.im.putpixel((x, (r + 4) * 8 - 1), grey)
        s.window(13, 0, 7, 9)
        for i, c in enumerate(['Item', 'Magic', 'Equip', None, 'Order', 'Job', 'Save']):
            if c: F.draw(s, 14, 1 + i, c, T.ink)
            else: condensed(s, 14, 1 + i, 'Status', T.ink, 5)
        s.window(13, 9, 7, 4)
        small_text(s, 14 * 8 + 2, 10 * 8, '9999999G', T.ink); small_text(s, 14 * 8 + 2, 11 * 8, '    255C', T.ink)
        s.window(13, 13, 7, 5)
        F.draw(s, 14, 14, 'Sara', T.ink)
        s.save(os.path.join(outd, 'N5%s_aligned.png' % tag))
        print('wrote', os.path.join(outd, 'N5%s_aligned.png' % tag))
    # owner (after N5B was built): "I did like the small font and the slashes": N6 = N5B with
    # HP current/max and the 8 levels' MP in the 3-px digits with slashes (as N3)
    def dig_at(x, y, ch):
        for yy, row in enumerate(DIG3[ch]):
            for xx, v in enumerate(row):
                if v == '#': s.im.putpixel((x + xx, y + yy), ink_now[0])
    ink_now = [T.ink]
    s = Screen(T)
    s.window(0, 0, 13, 18)
    sh = (0, 1, 1, 2)
    mps = ['99970000', '99975300', '99999999', '30000000']
    for i, (nm, _, hp, mx, lv, m1, m2) in enumerate(party2):
        r = 1 + 4 * i
        F.draw(s, 1, r, nm, T.ink, dy=sh[0]); F.draw(s, 8, r, 'Lv%2d' % lv, T.ink, dy=sh[0])
        condensed(s, 1, r + 1, jobs[i], T.ink, 11, dy=sh[1])
        F.draw(s, 1, r + 2, '[77][79]', green, dy=sh[2] + 1)
        ink_now[0] = green
        x = 3 * 8 + 1
        for ch in '%d/%d' % (hp, mx): dig_at(x, (r + 2) * 8 - sh[2], ch); x += 4
        F.draw(s, 1, r + 3, '[78][79]', T.ink, dy=sh[3] + 1)
        ink_now[0] = T.ink
        x = 3 * 8 + 1
        for k, d in enumerate(mps[i]):
            dig_at(x, (r + 3) * 8 - sh[3], d); x += 4
            if k < 7: dig_at(x, (r + 3) * 8 - sh[3], '/'); x += 4
    s.window(13, 0, 7, 9)
    for i, c in enumerate(['Item', 'Magic', 'Equip', None, 'Order', 'Job', 'Save']):
        if c: F.draw(s, 14, 1 + i, c, T.ink)
        else: condensed(s, 14, 1 + i, 'Status', T.ink, 5)
    s.window(13, 9, 7, 4)
    small_text(s, 14 * 8 + 6, 10 * 8, '9999999G', T.ink); small_text(s, 14 * 8 + 6, 11 * 8, '    255C', T.ink)
    s.window(13, 13, 7, 5)
    F.draw(s, 14, 14, 'Sara', T.ink)
    s.save(os.path.join(outd, 'N6_small_digits.png'))
    print('wrote', os.path.join(outd, 'N6_small_digits.png'))


def menu_options(nes, outd, cmd):
    """field main menu mock-ups (160 x 144): per member name + HP / job + level / MP of the 8
    spell levels on 3 lines; commands opening over the party window (A: right, rows 0-8;
    B: bottom right); Gil and Capacity below"""
    F = RomFont(nes); T = Tiles(cmd); outs = []
    party = [('AAAAAA', 'Onion Knight', 28), ('AAAAAB', 'Black Mage', 29), ('BBBBBC', 'White Mage', 32),
             ('CCCCCD', 'Red Mage', 32)]
    cmds = ['Item', 'Magic', 'Equip', 'Status', 'Order', 'Job', 'Save']
    def base():
        s = Screen(T)
        s.window(0, 0, 20, 14)
        for i, (nm, job, hp) in enumerate(party):
            r = 1 + 3 * i
            F.draw(s, 1, r, nm, T.ink); F.draw(s, 11, r, '%3d/%3d' % (hp, 32), T.ink)
            F.draw(s, 1, r + 1, ' ' + job, T.ink); F.draw(s, 15, r + 1, 'Lv 1', T.ink)
            F.draw(s, 2, r + 2, 'MP', T.ink); mp_tiles(s, 5, r + 2, '99970000', T.ink)
        s.window(0, 14, 20, 4)
        F.draw(s, 1, 15, 'Gil', T.ink); F.draw(s, 12, 15, '%6dG' % 9, T.ink)
        F.draw(s, 1, 16, 'Capacity', T.ink); F.draw(s, 12, 16, '%6dC' % 1, T.ink)
        return s
    s = base(); s.save(os.path.join(outd, 'N0_party.png')); outs.append('N0_party.png')
    s = base(); s.window(11, 0, 9, 9)
    for i, c in enumerate(cmds): F.draw(s, 13, 1 + i, c, T.ink)
    s.save(os.path.join(outd, 'N1_commands_right.png')); outs.append('N1_commands_right.png')
    s = base(); s.window(11, 9, 9, 9)
    for i, c in enumerate(cmds): F.draw(s, 13, 10 + i, c, T.ink)
    s.save(os.path.join(outd, 'N2_commands_bottom.png')); outs.append('N2_commands_bottom.png')
    ims = [Image.open(os.path.join(outd, o)) for o in outs]
    sheet = Image.new('RGB', (480 * 3 + 32, 432), (40, 40, 40))
    for i, im in enumerate(ims): sheet.paste(im, (i * 496, 0))
    sheet.save(os.path.join(outd, 'menu_options.png'))
    print('wrote', outd, outs)


def sub_menus(nes, outd, cmd):
    """field sub-menus for the GB (owner: SaGa-style full-width windows; the main menu's look):
    S1 item list, S2 item target, S3 magic, S4 equip, S5 status"""
    F = RomFont(nes); T = Tiles(cmd)
    green = (128, 208, 16)
    outs = []
    def dig(sc, x, y, txt, ink):
        for ch in txt:
            if ch != ' ':
                for yy, row in enumerate(DIG3[ch]):
                    for xx, v in enumerate(row):
                        if v == '#': sc.im.putpixel((x + xx, y + yy), ink)
            x += 4
    def mp_row(sc, c, r, mps, ink):
        x = c * 8
        for k, d in enumerate(mps):
            dig(sc, x, r * 8, d, ink); x += 4
            if k < 7: dig(sc, x, r * 8, '/', ink); x += 4
    items = [(' Potion', 5), (' High Potion', 2), (' Phoenix Tail', 3), (' Elixir', 1), (' Eye Drops', 4),
             (' Antidote', 6), (' Echo Herb', 2), (" Maiden's Kiss", 1), ('[6E]Fire Arrows', 20),
             ('[69]Mythril Knife', 1), ('[62]Leather Cap', 2), ('[61]Leather Armor', 1), (" Lilith's Kiss", 1)]
    def item_screen():
        sc = Screen(T)
        sc.window(0, 0, 20, 3); F.draw(sc, 1, 1, 'Item', T.ink)
        sc.window(0, 2, 20, 16)
        for i, (nm, n) in enumerate(items[:14]):
            F.draw(sc, 2, 3 + i, nm, T.ink); F.draw(sc, 16, 3 + i, ':%2d' % n, T.ink)
        return sc
    sc = item_screen(); sc.save(os.path.join(outd, 'S1_items.png')); outs.append('S1_items.png')
    sc = item_screen()
    sc.window(0, 11, 20, 7)
    party = [('AAAAAA', 28, 32), ('AAAAAB', 291, 999), ('BBBBBC', 1234, 9999), ('CCCCCD', 32, 32)]
    for i, (nm, hp, mx) in enumerate(party):
        F.draw(sc, 1, 12 + i, nm, T.ink); F.draw(sc, 8, 12 + i, '[77][79]', green, dy=1)
        F.draw(sc, 10, 12 + i, '%4d/%-4d' % (hp, mx), green)
    sc.save(os.path.join(outd, 'S2_item_target.png')); outs.append('S2_item_target.png')
    # magic: header (name, commands), list: level line + one spell per row, 3 levels a page
    sc = Screen(T)
    sc.window(0, 0, 20, 4); F.draw(sc, 1, 1, 'AAAAAA', T.ink)
    for c, w in ((2, 'Use'), (8, 'Swap'), (14, 'Item')): F.draw(sc, c, 2, w, T.ink)
    sc.window(0, 3, 20, 15)
    lv = [(1, '9/9', ['[74]Cure', '[74]Poisona', '[74]Sightro']), (2, '7/9', ['[75]Fire', '[75]Blizzard', '[75]Sleep']),
          (3, '3/5', ['[74]Aero', '[74]Toad', '[74]Minimum'])]
    for i, (l, m, sp) in enumerate(lv):
        r = 4 + 4 * i
        F.draw(sc, 1, r, 'Lv%d' % l, T.ink); F.draw(sc, 9, r, 'MP', T.ink); F.draw(sc, 13, r, m, T.ink)
        for k, nm in enumerate(sp): F.draw(sc, 3, r + 1 + k, nm, T.ink)
    sc.save(os.path.join(outd, 'S3_magic.png')); outs.append('S3_magic.png')
    # equip: name, attack, defense; the five slots and "Remove Equipment"
    sc = Screen(T)
    sc.window(0, 0, 20, 5); F.draw(sc, 1, 1, 'AAAAAA', T.ink)
    F.draw(sc, 2, 2, 'Attack[C3]', T.ink); F.draw(sc, 15, 2, '%3d' % 7, T.ink)
    F.draw(sc, 2, 3, 'Defense[C3]', T.ink); F.draw(sc, 15, 3, '%3d' % 4, T.ink)
    sc.window(0, 4, 20, 8)
    for i, nm in enumerate(['[69]Knife', '   Left Hand', '[62]Leather Cap', '[61]Clothes', '   Arms', 'Remove Equipment']):
        F.draw(sc, 2, 5 + i, nm, T.ink)
    F.draw(sc, 16, 5, ': 1', T.ink)
    sc.window(0, 11, 20, 7)
    for i, (nm, n) in enumerate([('[69]Mythril Knife', 1), ('[69]Air Knife', 1), ('[68]Thunder Spear', 1)]):
        F.draw(sc, 2, 12 + i, nm, T.ink); F.draw(sc, 16, 12 + i, ':%2d' % n, T.ink)
    sc.save(os.path.join(outd, 'S4_equip.png')); outs.append('S4_equip.png')
    # status: one window; stats and battle values in two columns of condensed words
    sc = Screen(T)
    sc.window(0, 0, 20, 18)
    F.draw(sc, 1, 1, 'AAAAAA', T.ink); condensed(sc, 8, 1, 'Onion Knight', T.ink, 7)
    F.draw(sc, 1, 2, 'Lv 1', T.ink); condensed(sc, 8, 2, 'Proficiency', T.ink, 6); F.draw(sc, 16, 2, '%3d' % 1, T.ink)
    F.draw(sc, 1, 3, 'EXP', T.ink); F.draw(sc, 11, 3, '%7d' % 12, T.ink)
    F.draw(sc, 1, 4, 'To next level', T.ink); F.draw(sc, 14, 4, '%4d' % 4, T.ink)
    F.draw(sc, 1, 5, '[77][79]', green, dy=1); F.draw(sc, 4, 5, '%4d/%-4d' % (28, 32), green)
    F.draw(sc, 1, 6, '[78][79]', T.ink, dy=1); mp_row(sc, 3, 6, '00000000', T.ink)
    stats = [('Strength', '5'), ('Agility', '5'), ('Stamina', '5'), ('Intelligence', '5'), ('Spirit', '5')]
    for i, (w, v) in enumerate(stats):
        c, r = (1, 7 + i // 2) if i % 2 == 0 else (10, 7 + i // 2)
        condensed(sc, c, r, w, T.ink, 6); F.draw(sc, c + 6, r, '%2s' % v, T.ink)
    vals = [('Attack  1x', '7'), ('Hit rate', '86%'), ('Defense 0x', '4'), ('Evasion rate', '2%'),
            ('Magic defense', '1'), ('Magic evasion', '5%')]
    for i, (w, v) in enumerate(vals):
        F.draw(sc, 1, 11 + i, w, T.ink); F.draw(sc, 15, 11 + i, '%3s' % v, T.ink)
    sc.save(os.path.join(outd, 'S5_status.png')); outs.append('S5_status.png')
    ims = [Image.open(os.path.join(outd, o)) for o in outs]
    sheet = Image.new('RGB', (480 * 3 + 32, 432 * 2 + 16), (40, 40, 40))
    for i, im in enumerate(ims): sheet.paste(im, ((i % 3) * 496, (i // 3) * 448))
    sheet.save(os.path.join(outd, 'sub_menus.png'))
    print('wrote', os.path.join(outd, 'sub_menus.png'))


def job_save(nes, outd, cmd):
    """job and save screens for the GB: J1 one job per row (2 pages), J2 two columns (name +
    level; the chosen job's CP cost in the header), V1 save: file list + the chosen file's party"""
    F = RomFont(nes); T = Tiles(cmd)
    green = (128, 208, 16)
    jobs = ['Onion Knight', 'Warrior', 'Monk', 'White Wizard', 'Black Wizard', 'Red Wizard', 'Hunter',
            'Knight', 'Thief', 'Scholar', 'Geomancer', 'Dragon Knight', 'Viking', 'Karateka',
            'Magic Knight', 'Illusionist', 'Bard', 'Warlock', 'Guru', 'Summoner', 'Sage', 'Ninja']
    lv = [12, 1, 3, 5, 1, 2, 1, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    cp = [0, 8, 8, 8, 8, 8, 12, 12, 12, 12, 16, 16, 16, 16, 20, 20, 20, 24, 24, 28, 32, 32]
    def jname(sc, c, r, j, n=7):
        from latin_font import packed_label, COND, TIGHT
        if len(jobs[j]) <= 7 and len(jobs[j]) <= n: F.draw(sc, c, r, jobs[j], T.ink); return
        for k in range(n, 9):
            if packed_label(jobs[j], k, COND, fg=3, bg=0) or packed_label(jobs[j], k, TIGHT, fg=3, bg=0):
                condensed(sc, c, r, jobs[j], T.ink, k); return
    def header(sc, extra=None):
        sc.window(0, 0, 20, 4)
        F.draw(sc, 1, 1, 'AAAAAA', T.ink); jname(sc, 8, 1, 0)
        F.draw(sc, 1, 2, 'Capacity', T.ink); F.draw(sc, 15, 2, '%3d' % 15, T.ink)
        if extra: extra(sc)
    outs = []
    # J1: one job a row: name, Lv, CP cost; 13 a page
    sc = Screen(T); header(sc)
    sc.window(0, 3, 20, 15)
    F.draw(sc, 9, 4, 'Lv', T.ink); F.draw(sc, 15, 4, 'CP', T.ink)
    for i in range(12):
        jname(sc, 2, 5 + i, i); F.draw(sc, 9, 5 + i, '%2d' % lv[i], T.ink); F.draw(sc, 14, 5 + i, '%3d' % cp[i], T.ink)
    sc.save(os.path.join(outd, 'J1_jobs_rows.png')); outs.append('J1_jobs_rows.png')
    # J2: two columns of name + level (all 22 on one page); the chosen job's cost in the header
    sc = Screen(T)
    sc.window(0, 0, 20, 4)
    F.draw(sc, 1, 1, 'AAAAAA', T.ink); jname(sc, 8, 1, 0)
    F.draw(sc, 1, 2, 'CP', T.ink); F.draw(sc, 4, 2, '%3d' % 15, T.ink)
    condensed(sc, 9, 2, 'Needs', T.ink, 3); F.draw(sc, 13, 2, '%3d' % cp[3], T.ink)
    sc.window(0, 3, 20, 15)
    for i in range(22):
        c, r = (1 + 9 * (i % 2), 4 + i // 2)
        jname(sc, c, r, i, 6); dig_x = (c + 6) * 8 + 2
        x = dig_x
        for ch in '%2d' % lv[i]:
            if ch != ' ':
                for yy, row in enumerate(DIG3[ch]):
                    for xx, v in enumerate(row):
                        if v == '#': sc.im.putpixel((x + xx, r * 8 + yy), T.ink)
            x += 4
    sc.save(os.path.join(outd, 'J2_jobs_columns.png')); outs.append('J2_jobs_columns.png')
    # V1: save: label + prompt, the three files one line each, the chosen file's party below
    sc = Screen(T)
    sc.window(0, 0, 20, 4); F.draw(sc, 1, 1, 'Please choose the', T.ink); F.draw(sc, 1, 2, 'file to save to.', T.ink)
    sc.window(0, 3, 20, 5)
    for i, t in enumerate(['1  AAAAAA  Lv 12', '2  -', '3  -']): F.draw(sc, 2, 4 + i, t, T.ink)
    sc.window(0, 7, 20, 11)
    party = [('AAAAAA', 12, 128, 140), ('AAAAAB', 11, 97, 120), ('BBBBBC', 11, 88, 102), ('CCCCCD', 10, 75, 99)]
    F.draw(sc, 17, 8, '%2d' % 3, T.ink)            # (the save count, as FF3's slot shows it)
    for i, (nm, l, hp, mx) in enumerate(party):
        r = 10 + 2 * i
        F.draw(sc, 1, r, nm, T.ink); F.draw(sc, 8, r, 'Lv%2d' % l, T.ink)
        small_text(sc, 13 * 8 + 1, r * 8, '%d/%d' % (hp, mx), green)

    sc.save(os.path.join(outd, 'V1_save.png')); outs.append('V1_save.png')
    ims = [Image.open(os.path.join(outd, o)) for o in outs]
    sheet = Image.new('RGB', (480 * 3 + 32, 432), (40, 40, 40))
    for i, im in enumerate(ims): sheet.paste(im, (i * 496, 0))
    sheet.save(os.path.join(outd, 'job_save.png'))
    print('wrote', os.path.join(outd, 'job_save.png'))


def main():
    nes, outd = sys.argv[1], sys.argv[2]
    if len(sys.argv) > 3 and sys.argv[3] == 'jobsave':
        os.makedirs(outd, exist_ok=True)
        fr = capture(nes, [9000])
        job_save(nes, outd, fr[9000])
        return
    if len(sys.argv) > 3 and sys.argv[3] == 'sub':
        os.makedirs(outd, exist_ok=True)
        fr = capture(nes, [9000])
        sub_menus(nes, outd, fr[9000])
        return
    if len(sys.argv) > 3 and sys.argv[3] == 'menu':
        os.makedirs(outd, exist_ok=True)
        fr = capture(nes, [9000])
        menu_options(nes, outd, fr[9000])
        menu_all_fit(nes, outd, fr[9000])
        return
    if len(sys.argv) > 3 and sys.argv[3] == 'magic':
        os.makedirs(outd, exist_ok=True)
        fr = capture(nes, [8950, 9000])
        magic_options(nes, outd, fr[8950], fr[9000])
        return
    if len(sys.argv) > 3 and sys.argv[3] == 'lists':
        os.makedirs(outd, exist_ok=True)
        fr = capture(nes, [8950, 9000])
        hand = None                        # (the cursor: as in the command window, not drawn)
        lists(nes, outd, fr[8950], fr[9000], hand)
        return
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
