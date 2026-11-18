"""Render GB screen mock-ups (20x18 tiles) with the project's Latin font, for layout
review before the NES code is changed. Graphics that would come from the ROM (enemies,
backdrops) are drawn as grey placeholder blocks.
usage: mockup.py OUTDIR"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from latin_font import tile, COND, G, _glyph_cols
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

    def ptext(self, x, y, s, fg=0, px=0):
        """proportional text in the condensed letters (1-px gaps, 3-px space), from tile
        (x, y) plus px pixels; characters without a condensed form use the regular glyph
        trimmed to its ink. Returns the width in pixels."""
        X = x * 8 + px
        for k, ch in enumerate(s):
            if k: X += 1
            if ch == ' ': X += 2; continue
            cols = _glyph_cols(ch, COND if ch in COND else G)
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
    battle(out); battle2(out); battle3(out); main_menu(out)
    print('written to', out)
