"""Render GB screen mock-ups (20x18 tiles) with the project's Latin font, for layout
review before the NES code is changed. Graphics that would come from the ROM (enemies,
backdrops) are drawn as grey placeholder blocks.
usage: mockup.py OUTDIR"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from latin_font import tile, COND, G, NARROW, _glyph_cols
from PIL import Image, ImageDraw

SHADES = [(224, 248, 208), (136, 192, 112), (52, 104, 86), (8, 24, 32)]   # DMG-like


class Screen:
    def __init__(self, bg=3):
        self.im = Image.new('RGB', (160, 144), SHADES[bg])
        self.d = ImageDraw.Draw(self.im)

    def glyph(self, x, y, ch, fg=0, bg=3):
        t = tile(ch, fg=3, bg=0)
        for r in range(8):
            p0, p1 = t[r], t[r + 8]
            for c in range(8):
                v = ((p0 >> (7 - c)) & 1) | (((p1 >> (7 - c)) & 1) << 1)
                self.im.putpixel((x * 8 + c, y * 8 + r), SHADES[fg if v else bg])

    def text(self, x, y, s, fg=0, bg=3):
        for i, ch in enumerate(s):
            if ch != ' ': self.glyph(x + i, y, ch, fg, bg)
            else: self.d.rectangle([(x + i) * 8, y * 8, (x + i) * 8 + 7, y * 8 + 7], fill=SHADES[bg])

    def pwidth(self, s, table=None):
        w = 0
        for k, ch in enumerate(s):
            if k: w += 1
            w += 2 if ch == ' ' else len(_glyph_cols(ch, self._table(ch, table)))
        return w

    @staticmethod
    def _table(ch, table):
        if table is not None and ch in table: return table
        return COND if ch in COND else G

    def ptext(self, x, y, s, fg=0, px=0, table=None, right=None):
        """proportional text in the condensed letters (1-px gaps, 3-px space), from tile
        (x, y) plus px pixels; characters without a condensed form use the regular glyph
        trimmed to its ink. Returns the width in pixels."""
        if right is not None: px = right - x * 8 - self.pwidth(s, table)
        X = x * 8 + px
        for k, ch in enumerate(s):
            if k: X += 1
            if ch == ' ': X += 2; continue
            cols = _glyph_cols(ch, self._table(ch, table))
            for cx, col in enumerate(cols):
                for cy in range(8):
                    if col[cy]: self.im.putpixel((X + cx, y * 8 + cy), SHADES[fg])
            X += len(cols)
        return X - x * 8 - px

    def window(self, x, y, w, h, bg=3):
        x0, y0, x1, y1 = x * 8, y * 8, (x + w) * 8 - 1, (y + h) * 8 - 1
        self.d.rectangle([x0, y0, x1, y1], fill=SHADES[bg])
        self.d.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], outline=SHADES[0])
        self.d.rectangle([x0 + 3, y0 + 3, x1 - 3, y1 - 3], outline=SHADES[1])

    def block(self, x, y, w, h, label=''):
        self.d.rectangle([x * 8 + 1, y * 8 + 1, (x + w) * 8 - 2, (y + h) * 8 - 2], fill=SHADES[2], outline=SHADES[1])

    def cursor(self, x, y):
        self.d.polygon([(x * 8 + 1, y * 8 + 1), (x * 8 + 6, y * 8 + 4), (x * 8 + 1, y * 8 + 7)], fill=SHADES[0])

    def save(self, path, scale=3):
        self.im.resize((160 * scale, 144 * scale), Image.NEAREST).save(path)


def battle(out):
    s = Screen(bg=3)
    s.block(0, 0, 20, 2)                                # backdrop strip (from the ROM)
    for i in range(5): s.block(i * 4, 2, 4, 4)          # 9 small enemies, 5 + 4
    for i in range(4): s.block(2 + i * 4, 6, 4, 4)
    s.window(0, 10, 10, 8)                              # command window, headed by who acts
    s.text(1, 11, 'AAAA')
    for i, w in enumerate(['Fight', 'Magic', 'Medicine', 'Items', 'Run']):
        s.text(1, 12 + i, w)
    s.cursor(0, 12)                                     # cursor sprite over the frame, as on the NES
    s.window(10, 10, 10, 8)                             # party list: name + HP
    for i, (n, hp) in enumerate([('AAAA', 35), ('BBBB', 30), ('CCCC', 33), ('DDDD', 30)]):
        s.text(11, 11 + i, '%s%4d' % (n, hp))
    s.save(os.path.join(out, 'mock_battle_command.png'))

    s = Screen(bg=3)
    s.block(0, 0, 20, 2)
    for i in range(5): s.block(i * 4, 2, 4, 4)
    for i in range(4): s.block(2 + i * 4, 6, 4, 4)
    s.window(0, 10, 10, 8)                              # enemy names (as the NES box)
    for i, w in enumerate(['Goblin', 'Wolf']): s.text(1, 11 + i, w)
    s.window(10, 10, 10, 8)
    for i, (n, hp) in enumerate([('AAAA', 35), ('BBBB', 30), ('CCCC', 33), ('DDDD', 30)]):
        s.text(11, 11 + i, '%s%4d' % (n, hp))
    s.window(0, 12, 20, 6)                              # battle message, full width over both
    s.text(1, 13, 'AAAA')
    s.text(1, 14, 'Goblin')
    s.text(1, 15, '6 hit(s)!  23 DMG')
    s.save(os.path.join(out, 'mock_battle_message.png'))


def battle2(out):
    """Draft 2: party sprites visible (owner's decision)."""
    party = [('AAAA', 35), ('BBBB', 30), ('CCCC', 33), ('DDDD', 30)]

    def top(s):
        for r in range(3):                              # 9 small enemies, NES 3x3 grid
            for c in range(3): s.block(1 + c * 4, r * 4, 4, 4)
        for i, (n, hp) in enumerate(party):             # sprite + name/HP per member
            s.block(14, i * 3, 2, 3)
            s.text(16, i * 3, n)
            s.text(16, i * 3 + 1, '%4d' % hp)
    s = Screen(bg=3); top(s)
    s.window(0, 12, 20, 6)
    for i, w in enumerate(['Goblin', 'Minotaur Zombie']): s.text(1, 13 + i, w)
    s.save(os.path.join(out, 'mock2_battle_idle.png'))
    s = Screen(bg=3); top(s)
    s.window(0, 12, 20, 6)
    for i, w in enumerate(['Goblin', 'Minotaur Zombie']): s.text(1, 13 + i, w)
    s.window(9, 12, 11, 6)
    s.text(10, 13, 'Fight Run'); s.text(10, 14, 'Magic'); s.text(10, 15, 'Medicine'); s.text(10, 16, 'Items')
    s.cursor(9, 13)
    s.d.rectangle([14 * 8, 0, 20 * 8 - 1, 3 * 8 - 1], outline=SHADES[0])   # acting member's line flashes
    s.save(os.path.join(out, 'mock2_battle_command.png'))
    s = Screen(bg=3); top(s)
    s.window(0, 12, 20, 6)
    s.text(1, 13, 'AAAA'); s.text(1, 14, 'Minotaur Zombie'); s.text(1, 15, '6 hit(s)!  23 DMG')
    s.save(os.path.join(out, 'mock2_battle_message.png'))


def battle3(out):
    """Owner's question (2026-11-18): the bottom message window with a smaller font.
    Left of each pair: the current GB layout (8x8 font, 18 cells per row, 4 rows);
    right: the same windows with the condensed proportional letters (about 5 px per
    letter, 28-30 letters per row), drawn on the tile rows."""
    party = [('AAAA', 35), ('BBBB', 30), ('CCCC', 33), ('DDDD', 30)]

    def top(s):
        for r in range(3):
            for c in range(3): s.block(1 + c * 4, r * 4, 4, 4)
        for i, (n, hp) in enumerate(party):
            s.block(14, i * 3, 2, 3)
            s.text(16, i * 3, n); s.text(16, i * 3 + 1, 'HP'); s.text(16, i * 3 + 2, '%4d' % hp)

    pages = [('turn', ['AAAA', '', 'Goblin', '4 damage']),
             ('long', ['Was hurled into a', 'rift in', 'dimensions!']),
             ('long2', ['Became better at', 'dodging attacks'])]
    small = {'turn': ['AAAA', '', 'Goblin', '4 damage'],
             'long': ['Was hurled into a rift in dimensions!'],
             'long2': ['Became better at dodging attacks']}
    for name, rows in pages:
        a = Screen(bg=3); top(a); a.window(0, 12, 20, 6)
        for i, r in enumerate(rows): a.text(1, 13 + i, r)
        b = Screen(bg=3); top(b); b.window(0, 12, 20, 6)
        for i, r in enumerate(small[name]): b.ptext(1, 13 + i, r)
        both = Image.new('RGB', (160 * 2 + 8, 144), (255, 255, 255))
        both.paste(a.im, (0, 0)); both.paste(b.im, (168, 0))
        both.resize((both.width * 3, 144 * 3), Image.NEAREST).save(os.path.join(out, 'mock3_font_%s.png' % name))
    # command window + enemy names, small letters: two columns of names
    a = Screen(bg=3); top(a); a.window(0, 12, 20, 6)
    for i, w in enumerate(['Goblin', 'Minotaur Zombie']): a.text(1, 13 + i, w)
    a.window(9, 12, 11, 6)
    for i, w in enumerate(['Fight Run', 'Magic', 'Medicine', 'Items']): a.text(10, 13 + i, w)
    a.cursor(9, 13)
    b = Screen(bg=3); top(b); b.window(0, 12, 20, 6)
    for i, w in enumerate(['Goblin', 'Minotaur Zombie']): b.ptext(1, 13 + i, w)
    b.window(12, 12, 8, 6)
    for i, w in enumerate(['Fight   Run', 'Magic', 'Medicine', 'Items']): b.ptext(13, 13 + i, w)
    b.cursor(12, 13)
    both = Image.new('RGB', (160 * 2 + 8, 144), (255, 255, 255))
    both.paste(a.im, (0, 0)); both.paste(b.im, (168, 0))
    both.resize((both.width * 3, 144 * 3), Image.NEAREST).save(os.path.join(out, 'mock3_font_command.png'))


def battle4(out):
    """Owner (2026-11-18): the small font also for the name/HP beside each sprite.
    Column = GB cols 16-19 (32 px), the sprite's 3 rows. Left: A = name / HP + number /
    status word (blank when none). Right: B = the NES order (name / HP or status /
    number). Status words that are wider than 32 px in the condensed letters (Darkness,
    Paralysis) use the narrow letters the English build already has for them."""
    party = [('AAAA', 35, ''), ('WWWW', 30, 'Poison'), ('Mm', 0, 'Paralysis'), ('DDDD', 125, 'Darkness')]

    def status(s, row, word):
        if word: s.ptext(16, row, word, table=NARROW if s.pwidth(word) > 32 else None)

    def screen(variant):
        s = Screen(bg=3)
        for r in range(3):
            for c in range(3): s.block(1 + c * 4, r * 4, 4, 4)
        for i, (n, hp, st) in enumerate(party):
            y = i * 3
            s.block(14, y, 2, 3)
            s.ptext(16, y, n)
            if variant == 'A':
                s.ptext(16, y + 1, 'HP'); s.ptext(16, y + 1, str(hp), right=160)
                status(s, y + 2, st)
            else:
                if st: status(s, y + 1, st)
                else: s.ptext(16, y + 1, 'HP')
                s.ptext(16, y + 2, str(hp), right=160)
        s.window(0, 12, 20, 6)
        for i, r in enumerate(['WWWW', 'Fire', 'Goblin', '23 damage']): s.ptext(1, 13 + i, r)
        return s
    both = Image.new('RGB', (160 * 2 + 8, 144), (255, 255, 255))
    both.paste(screen('A').im, (0, 0)); both.paste(screen('B').im, (168, 0))
    both.resize((both.width * 3, 144 * 3), Image.NEAREST).save(os.path.join(out, 'mock4_party_small.png'))


def battle5(out):
    """Owner (2026-11-18): a window frame around the small-font name/HP column, as thick as
    the NES frames (line in px 1-4 of a frame tile), drawn into the same rendered tiles as
    the text. Left: C = frame around the text only (GB cols 16-19; text 22 px wide), open
    at the top screen edge, its sides running into the bottom window. Right: D = frame
    around sprites and text (left side under the sprites' right edge in col 15, text 27 px).
    Lines per member: name / number / status (blank when none)."""
    party = [('AAAA', 35, ''), ('Bob', 30, 'Poison'), ('Mm', 0, 'Sleep'), ('DDDD', 125, 'Stone')]

    def frame_px(s, x0, y0, x1, y1, top=True):
        d = s.d
        d.rectangle([x0, y0, x1, y1], outline=None)
        for off, shade in ((1, 1), (2, 0), (3, 1)):
            if top: d.line([x0 + off, y0 + off, x1 - off, y0 + off], fill=SHADES[shade])
            d.line([x0 + off, y0 + (off if top else 0), x0 + off, y1], fill=SHADES[shade])
            d.line([x1 - off, y0 + (off if top else 0), x1 - off, y1], fill=SHADES[shade])

    def screen(v):
        s = Screen(bg=3)
        for r in range(3):
            for c in range(3): s.block(1 + c * 4, r * 4, 4, 4)
        s.window(0, 12, 20, 6)
        for i, r in enumerate(['Bob', 'Fire', 'Goblin', '23 damage']): s.ptext(1, 13 + i, r)
        if v == 'C': frame_px(s, 16 * 8, 0, 160 - 1, 12 * 8 + 3, top=False)
        else: frame_px(s, 15 * 8 + 3, 0, 160 - 1, 12 * 8 + 3, top=False)
        left = 16 * 8 + 5 if v == 'C' else 16 * 8
        for i, (n, hp, st) in enumerate(party):
            y = i * 3
            s.block(14, y, 2, 3)
            s.ptext(0, y, n, px=left)
            s.ptext(0, y + 1, str(hp), right=160 - 5)
            if st: s.ptext(0, y + 2, st, px=left, table=NARROW)
        return s
    both = Image.new('RGB', (160 * 2 + 8, 144), (255, 255, 255))
    both.paste(screen('C').im, (0, 0)); both.paste(screen('D').im, (168, 0))
    both.resize((both.width * 3, 144 * 3), Image.NEAREST).save(os.path.join(out, 'mock5_party_frame.png'))


# small digits for HP "192/899" (mock-up only): 4 x 7, '1' 3 wide, '/' 3 wide
SMALLDIG = {
 '0': [".##.", "#..#", "#..#", "#..#", "#..#", "#..#", ".##."],
 '1': [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
 '2': [".##.", "#..#", "...#", "..#.", ".#..", "#...", "####"],
 '3': ["###.", "...#", "...#", ".##.", "...#", "...#", "###."],
 '4': ["..#.", ".##.", "#.#.", "#.#.", "####", "..#.", "..#."],
 '5': ["####", "#...", "###.", "...#", "...#", "#..#", ".##."],
 '6': [".##.", "#...", "###.", "#..#", "#..#", "#..#", ".##."],
 '7': ["####", "...#", "..#.", "..#.", ".#..", ".#..", ".#.."],
 '8': [".##.", "#..#", "#..#", ".##.", "#..#", "#..#", ".##."],
 '9': [".##.", "#..#", "#..#", ".###", "...#", "...#", ".##."],
 '/': ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."],
}


def battle6(out):
    """Owner (2026-11-18): closed frame (top and bottom lines too) around the party, at the
    NES frame thickness, and HP as current/max in small digits. The sprites fill 4 x 24 px
    beside the enemies, so the party window runs the full screen height (GB cols 14-19,
    rows 0-17) and the bottom window spans the enemy area only (cols 0-13). Per member:
    name and status beside the sprite, HP current/max under it."""
    party = [('AAAA', '192/899', ''), ('Bob', '30/30', 'Poison'), ('Mm', '0/33', 'Sleep'),
             ('DDDD', '125/999', 'Stone')]

    def screen(page):
        s = Screen(bg=3)
        for r in range(3):
            for c in range(3): s.block(1 + c * 4, r * 4, 4, 4)
        s.window(14, 0, 6, 18)
        for i, (n, hp, st) in enumerate(party):
            y = 6 + i * 33                                   # pixel row of the sprite top
            s.d.rectangle([14 * 8 + 6, y, 14 * 8 + 21, y + 23], fill=SHADES[2], outline=SHADES[1])
            X0 = 14 * 8 + 24
            for line, (txt, tb) in enumerate(((n, None), (st, NARROW))):
                if txt: s.ptext(0, 0, txt, px=X0, table=tb) if False else _pt(s, X0, y + 2 + line * 9, txt, tb)
            _pt(s, 160 - 6 - s.pwidth(hp, SMALLDIG), y + 25, hp, SMALLDIG)
        s.window(0, 12, 14, 6)
        if page == 'msg':
            for i, r in enumerate(['Bob', 'Fire', 'Goblin', '23 damage']): s.ptext(1, 13 + i, r)
        elif page == 'long':
            s.ptext(1, 13, 'Was hurled into a rift in'); s.ptext(1, 14, 'dimensions!')
        else:
            for i, w in enumerate(['Goblin', 'Minotaur Zombie']): s.ptext(1, 13 + i, w)
            s.window(7, 12, 7, 6)
            for i, w in enumerate(['Fight  Run', 'Magic', 'Medicine', 'Items']): s.ptext(8, 13 + i, w)
            s.cursor(7, 13)
        return s
    ims = [screen(p).im for p in ('cmd', 'msg', 'long')]
    out_im = Image.new('RGB', (160 * 3 + 16, 144), (255, 255, 255))
    for k, im in enumerate(ims): out_im.paste(im, (k * 168, 0))
    out_im.resize((out_im.width * 3, 144 * 3), Image.NEAREST).save(os.path.join(out, 'mock6_party_window.png'))


def battle7(out):
    """Owner (2026-11-18): closed full-thickness frame + HP current/max. Party window 8
    columns wide (GB cols 12-19), full height; per member, beside the sprite: name /
    HP current/max / status word (all fit in 34 px). Enemy area 12 columns (cols 0-11),
    bottom window under it. Mixed formations (14 columns on the NES) would need their
    enemy positions changed in the NES code."""
    party = [('WWWW', '192/899', ''), ('Bob', '30/30', 'Poison'), ('Mm', '0/33', 'Paralysis'),
             ('DDDD', '125/999', 'Darkness')]

    def screen(page):
        s = Screen(bg=3)
        for r in range(3):
            for c in range(3): s.block(c * 4, r * 4, 4, 4)
        s.window(12, 0, 8, 18)
        for i, (n, hp, st) in enumerate(party):
            y = 8 + i * 33
            s.d.rectangle([12 * 8 + 6, y, 12 * 8 + 21, y + 23], fill=SHADES[2], outline=SHADES[1])
            X0 = 12 * 8 + 24
            _pt(s, X0, y, n)
            _pt(s, X0, y + 8, hp, SMALLDIG)
            if st: _pt(s, X0, y + 16, st, NARROW)
        s.window(0, 12, 12, 6)
        if page == 'msg':
            for i, r in enumerate(['Bob', 'Fire', 'Goblin', '23 damage']): s.ptext(1, 13 + i, r)
        elif page == 'long':
            s.ptext(1, 13, 'Was hurled into a rift'); s.ptext(1, 14, 'in dimensions!')
        else:
            for i, w in enumerate(['Goblin', 'Minotaur', 'Zombie']): s.ptext(1, 13 + i, w)
            s.window(6, 12, 6, 6)
            for i, w in enumerate(['Fight', 'Magic', 'Medicine', 'Items']): s.ptext(7, 13 + i, w)
            s.cursor(6, 13)
        return s
    ims = [screen(p).im for p in ('cmd', 'msg', 'long')]
    out_im = Image.new('RGB', (160 * 3 + 16, 144), (255, 255, 255))
    for k, im in enumerate(ims): out_im.paste(im, (k * 168, 0))
    out_im.resize((out_im.width * 3, 144 * 3), Image.NEAREST).save(os.path.join(out, 'mock7_party_window_wide.png'))


def battle8(out):
    """Owner's sketch (2026-11-18): enemies top-left, party sprites in GB cols 14-15 (as
    now), a full-height window at cols 16-19 with each member's name / status / HP
    current / max, bottom windows (enemy names, commands) in cols 0-15. Text area of
    the right window: x 133-154 (22 px), 33 px per member = 4 lines."""
    party = [('AAAA', 192, 899, ''), ('Bob', 30, 30, 'Poison'), ('Mm', 0, 33, 'Sleep'),
             ('WWWW', 125, 999, 'Paralysis')]
    X0, X1 = 133, 154

    def screen(page):
        s = Screen(bg=3)
        for r in range(3):
            for c in range(3): s.block(1 + c * 4, r * 4, 4, 4)
        for i in range(4): s.block(14, i * 3, 2, 3)
        s.window(16, 0, 4, 18)
        for i, (n, hp, mx, st) in enumerate(party):
            y = 7 + i * 33
            tb = NARROW if st and s.pwidth(st) > X1 - X0 + 1 else None
            _pt(s, (X0 + X1 + 1 - s.pwidth(n)) // 2, y, n)
            if st: _pt(s, (X0 + X1 + 1 - s.pwidth(st, tb)) // 2, y + 8, st, tb)
            _pt(s, X1 + 1 - s.pwidth(str(hp), SMALLDIG), y + 16, str(hp), SMALLDIG)
            _pt(s, X1 + 1 - s.pwidth('/%d' % mx, SMALLDIG), y + 23, '/%d' % mx, SMALLDIG)
        s.window(0, 12, 16, 6)
        if page == 'msg':
            for i, r in enumerate(['Bob', 'Fire', 'Goblin', '23 damage']): s.ptext(1, 13 + i, r)
        elif page == 'long':
            s.ptext(1, 13, 'Was hurled into a rift in'); s.ptext(1, 14, 'dimensions!')
        else:
            for i, w in enumerate(['Goblin', 'Minotaur', 'Zombie']): s.ptext(1, 13 + i, w)
            s.window(8, 12, 8, 6)
            for i, w in enumerate(['Fight   Run', 'Magic', 'Medicine', 'Items']): s.ptext(9, 13 + i, w)
            s.cursor(8, 13)
        return s
    ims = [screen(p).im for p in ('cmd', 'msg', 'long')]
    out_im = Image.new('RGB', (160 * 3 + 16, 144), (255, 255, 255))
    for k, im in enumerate(ims): out_im.paste(im, (k * 168, 0))
    out_im.resize((out_im.width * 3, 144 * 3), Image.NEAREST).save(os.path.join(out, 'mock8_owner_sketch.png'))


# 3-px digits for HP current/max on one line ("999/999" = 27 px)
DIG3 = {
 '0': ["###", "#.#", "#.#", "#.#", "#.#", "#.#", "###"],
 '1': [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
 '2': ["###", "..#", "..#", "###", "#..", "#..", "###"],
 '3': ["###", "..#", "..#", ".##", "..#", "..#", "###"],
 '4': ["#.#", "#.#", "#.#", "###", "..#", "..#", "..#"],
 '5': ["###", "#..", "#..", "###", "..#", "..#", "###"],
 '6': ["###", "#..", "#..", "###", "#.#", "#.#", "###"],
 '7': ["###", "..#", "..#", ".#.", ".#.", ".#.", ".#."],
 '8': ["###", "#.#", "#.#", "###", "#.#", "#.#", "###"],
 '9': ["###", "#.#", "#.#", "###", "..#", "..#", "###"],
 '/': ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."],
}

ARROW = {'>': ["......", "...#..", "....#.", "######", "....#.", "...#..", "......"]}


def battle9(out):
    """Owner (2026-11-18): better fit/readability on the right, livelier messages.
    Party column spans the full height: sprite i at GB y = 6 + 33 i (cols 14-15), and its
    4 lines (name / status / HP / max) beside it in the right window (cols 16-19, frame
    flush to the screen edge). Enemy area keeps 14 columns; the bottom window is under
    it (cols 0-13). Messages: A = the same words, arranged (actor > target, then action,
    then result); B = sentences (adds English words not in the Japanese)."""
    party = [('AAAA', 192, 899, ''), ('Bob', 30, 30, 'Poison'), ('Mm', 0, 33, 'Sleep'),
             ('WWWW', 125, 999, 'Stone')]
    X0, X1 = 132, 155

    def screen(page):
        s = Screen(bg=3)
        for r in range(3):
            for c in range(3): s.block(1 + c * 4, r * 4, 4, 4)
        # right window, frame flush to the screen edge
        s.d.rectangle([128, 0, 159, 143], fill=SHADES[3])
        for off, shade in ((1, 1), (2, 0), (3, 1)):
            s.d.rectangle([128 + off, off, 159 - off + 1, 143 - off], outline=SHADES[shade])
        for i, (n, hp, mx, st) in enumerate(party):
            y = 6 + i * 33
            s.d.rectangle([14 * 8, y, 14 * 8 + 15, y + 23], fill=SHADES[2], outline=SHADES[1])
            _pt(s, (X0 + X1 + 1 - s.pwidth(n)) // 2, y, n)
            if st:
                tb = NARROW if s.pwidth(st) > X1 - X0 + 1 else None
                _pt(s, (X0 + X1 + 1 - s.pwidth(st, tb)) // 2, y + 8, st, tb)
            _pt(s, X1 - s.pwidth(str(hp), SMALLDIG), y + 16, str(hp), SMALLDIG)
            _pt(s, X1 - s.pwidth('/%d' % mx, SMALLDIG), y + 23, '/%d' % mx, SMALLDIG)
        s.window(0, 12, 14, 6)
        lines = {'cmd': ['Goblin', 'Minotaur', 'Zombie'],
                 'A': ['Bob > Goblin', '  Fire', '  23 damage'],
                 'B': ['Bob casts Fire', 'on Goblin!', 'Goblin takes 23', 'damage.'],
                 'B2': ['Goblin attacks Bob!', '2 hits for 9 damage.'],
                 'B3': ['Mm fell asleep.']}[page]
        for i, r in enumerate(lines): s.ptext(1, 13 + i, r, table=ARROW)
        if page == 'cmd':
            s.window(7, 12, 7, 6)
            for i, w in enumerate(['Fight', 'Magic', 'Medicine', 'Items']): s.ptext(8, 13 + i, w)
            s.ptext(0, 13, 'Run', px=8 * 8 + 30)
            s.cursor(7, 13)
        return s
    for name, pages in (('mock9_layout', ('cmd', 'A')), ('mock9_messages', ('B', 'B2', 'B3'))):
        ims = [screen(p).im for p in pages]
        out_im = Image.new('RGB', (168 * len(ims) - 8, 144), (255, 255, 255))
        for k, im in enumerate(ims): out_im.paste(im, (k * 168, 0))
        out_im.resize((out_im.width * 3, 144 * 3), Image.NEAREST).save(os.path.join(out, name + '.png'))


def battle10(out):
    """Owner (2026-11-18): message style A; HP current/max on one line; members' lines not
    beside their sprites (sprites keep the NES column and step forward/back); shorter
    status words allowed. Right window 5 columns (GB cols 15-19, text 31 px), one block
    per member: name / HP cur/max (3-px digits) / status. Sprites at GB cols 13-14
    (NES x = 120), rows 0-11; the bottom window spans cols 0-14."""
    party = [('AAAA', 192, 899, ''), ('Bob', 30, 30, 'Poison'), ('Mm', 0, 33, 'Numb'),
             ('WWWW', 999, 999, 'Blind')]
    X0, X1 = 125, 155

    def screen(page):
        s = Screen(bg=3)
        for r in range(3):
            for c in range(3): s.block(1 + c * 4, r * 4, 4, 4)
        for i in range(4):
            dx = -8 if (page == 'cmd' and i == 0) else 0           # acting member stepped forward
            s.d.rectangle([13 * 8 + dx, i * 24, 13 * 8 + 15 + dx, i * 24 + 23], fill=SHADES[2], outline=SHADES[1])
        s.d.rectangle([120, 0, 159, 143], fill=SHADES[3])
        for off, shade in ((1, 1), (2, 0), (3, 1)):
            s.d.rectangle([120 + off, off, 159 - off + 1, 143 - off], outline=SHADES[shade])
        for i, (n, hp, mx, st) in enumerate(party):
            y = 8 + i * 34
            c = (X0 + X1 + 1) // 2
            _pt(s, c - s.pwidth(n) // 2, y, n)
            h = '%d/%d' % (hp, mx)
            _pt(s, c - s.pwidth(h, DIG3) // 2, y + 9, h, DIG3)
            if st: _pt(s, c - s.pwidth(st) // 2, y + 18, st)
        s.window(0, 12, 15, 6)
        lines = {'cmd': ['Goblin', 'Minotaur Zombie'],
                 'A': ['Bob > Goblin', '  Fire', '  23 damage'],
                 'A2': ['Goblin > Bob', '  2 hits!', '  9 damage']}[page]
        for i, r in enumerate(lines): s.ptext(1, 13 + i, r, table=ARROW)
        if page == 'cmd':
            s.window(8, 12, 7, 6)
            for i, w in enumerate(['Fight', 'Magic', 'Medicine', 'Items']): s.ptext(9, 13 + i, w)
            s.ptext(0, 13, 'Run', px=9 * 8 + 28)
            s.cursor(8, 13)
        return s
    ims = [screen(p).im for p in ('cmd', 'A', 'A2')]
    out_im = Image.new('RGB', (168 * 3 - 8, 144), (255, 255, 255))
    for k, im in enumerate(ims): out_im.paste(im, (k * 168, 0))
    out_im.resize((out_im.width * 3, 144 * 3), Image.NEAREST).save(os.path.join(out, 'mock10_battle.png'))


def _pt(s, X, Y, txt, table=None):
    """proportional text at pixel (X, Y)"""
    for k, ch in enumerate(txt):
        if k: X += 1
        if ch == ' ': X += 2; continue
        t = table if table is not None and ch in table else (COND if ch in COND else G)
        cols = _glyph_cols(ch, t)
        for cx, col in enumerate(cols):
            for cy in range(8):
                if col[cy]: s.im.putpixel((X + cx, Y + cy), SHADES[0])
        X += len(cols)


def main_menu(out):
    s = Screen(bg=3)
    s.window(0, 0, 20, 10)                              # party list, one line per member
    for i, (n, c, hp, mhp) in enumerate([('AAAA', 'Warrior', 35, 35), ('BBBB', 'Thief', 30, 30),
                                         ('CCCC', 'Monk', 33, 33), ('DDDD', 'Red Magician', 30, 30)]):
        s.text(1, 1 + 2 * i, n)
        s.text(6, 1 + 2 * i, 'L 1')
        s.text(11, 1 + 2 * i, '%3d/%3d' % (hp, mhp))
        s.text(2, 2 + 2 * i, c)
    s.window(0, 10, 10, 4)                              # orbs
    for i in range(4): s.block(1 + i * 2, 11, 2, 2)
    s.window(0, 14, 10, 4)                              # Gil
    s.text(1, 15, '400 Gil')
    s.window(10, 10, 10, 8)                             # commands
    for i, w in enumerate(['Items', 'Magic', 'Weapons', 'Armor', 'Status']):
        s.text(12, 11 + i, w)
    s.cursor(11, 11)
    s.save(os.path.join(out, 'mock_main_menu.png'))


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'build'
    os.makedirs(out, exist_ok=True)
    battle(out); battle2(out); battle3(out); battle4(out); battle5(out); battle6(out); battle7(out); battle8(out); battle9(out); battle10(out); main_menu(out)
    print('written to', out)
