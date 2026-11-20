"""FF2 GB screen mock-ups (20x18 tiles) for the owner's review before a screen is built.

Same style and font as FF1's mock-ups (tools/gb/mockup.py: Screen, small proportional
letters, 3-px digits). Battle graphics are cropped from an NES frame of the user's own
English build (cynes) when the mock-up is made; the PNGs go to build/ (never committed).
usage: PYTHONPATH=build/emu mockup.py NES.nes OUTDIR"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
sys.path.insert(0, HERE)
import importlib.util
_spec = importlib.util.spec_from_file_location('gb1_mockup', os.path.join(HERE, '..', 'gb', 'mockup.py'))
_m1 = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_m1)
Screen, SHADES, _pt, DIG3, ARROW, _hand, HAND16 = (_m1.Screen, _m1.SHADES, _m1._pt, _m1.DIG3, _m1.ARROW,
                                                 _m1._hand, _m1.HAND16)
from PIL import Image


def dmg(im):
    """NES RGB -> the 4 DMG-like shades by brightness (mock-up only)"""
    out = Image.new('RGB', im.size)
    px = im.load(); po = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y][:3]
            l = 0.3 * r + 0.59 * g + 0.11 * b
            po[x, y] = SHADES[0] if l > 170 else SHADES[1] if l > 100 else SHADES[2] if l > 30 else SHADES[3]
    return out


def nes_battle_frame(nes_path, frame=9630):
    """an NES frame of the opening battle (firstdiff's new-game script + random seed 1)"""
    from cynes import NES
    import firstdiff as fd
    import numpy as np
    steps = fd.script_newgame(frame + 1); fd.add_random(steps, 1)
    n = NES(nes_path)
    for f in range(frame + 1):
        n.controller = steps[f]; fr = n.step(1)
    return Image.fromarray(np.array(fr))


PARTY = [('Firion', 30, 30, 5, ''), ('Maria', 20, 20, 5, ''), ('Guy', 40, 40, 5, ''), ('Leon', 0, 30, 5, 'Dead')]


def battle(nes_path, out):
    """Battle, after FF1's approved layout (mock12 / mock13): enemies in GB rows 0-11 (NES
    enemy area x 8-135, y 40-135, unchanged) at GB x 0-127, party sprites in their own
    column (GB x 128-159, stepping forward 8 px); bottom rows 12-17: enemy names window (cols 0-7, the command
    window opens over it), party window (cols 8-19): name, HP current/max in 3-px digits,
    MP; while a message shows, a full-width window over both, style A (actor > target /
    action / result)."""
    f = nes_battle_frame(nes_path)
    enemies = dmg(f.crop((8, 40, 136, 136)))           # 128 x 96
    sprites = dmg(f.crop((208, 40, 240, 136)))         # party column (back row stands right)

    def base(step=False):
        s = Screen(bg=3)
        s.im.paste(enemies, (0, 0))
        s.im.paste(sprites, (120 if step else 128, 0))
        return s

    def party_win(s):
        s.window(8, 12, 12, 6)
        for i, (n, hp, mx, mp, st) in enumerate(PARTY):
            y = (13 + i) * 8
            _pt(s, 9 * 8 + 1, y, n)
            h = '%d/%s' % (hp, st or mx)
            _pt(s, 140 - s.pwidth(h, DIG3), y, h, DIG3)
            _pt(s, 155 - s.pwidth(str(mp), DIG3), y, str(mp), DIG3)
    shots = []
    s = base(); party_win(s); s.window(0, 12, 8, 6)          # idle: enemy names
    _pt(s, 9, 13 * 8, 'Black Knight'); shots.append(s)
    s = base(step=True); party_win(s); s.window(0, 12, 8, 6)  # commands
    for i, w in enumerate(['Fight', 'Run', 'Magic', 'Gear']): s.ptext(2, 13 + i, w)
    _hand(s, -6, 13 * 8 - 4, HAND16); shots.append(s)
    for rows in (['Black Knight > Leon', '6 hits', '868 damage', 'Critical hit!!'],
                 ['Firion > Black Knight', '1 hit', '3 damage']):
        s = base(); s.window(0, 12, 20, 6)                    # message, style A
        for i, r in enumerate(rows): _pt(s, 9 + (6 if i else 0), (13 + i) * 8, r, ARROW)
        shots.append(s)
    sheet = Image.new('RGB', (168 * len(shots) - 8, 144), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, (k * 168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock1_battle.png'); sheet.save(p); return p


def forced_battle(nes_path, bids):
    """NES frames of the given battle ids (tools/gb2/ff2form.py forcing)"""
    from cynes import NES
    import firstdiff as fd
    import ff2form as F
    import numpy as np
    rom = open(nes_path, 'rb').read()
    steps = fd.script_newgame(F.START + F.SHOT + 1); fd.add_random(steps, 1)
    n = NES(nes_path)
    for f in range(F.START): n.controller = steps[f]; n.step(1)
    st = n.save(); out = []
    tmp = os.path.join(os.path.dirname(nes_path), 'ff2_formtmp.nes')
    for bid in bids:
        open(tmp, 'wb').write(F.patched(rom, bid)); m = NES(tmp); m.load(st)
        for f in range(F.START, F.START + F.SHOT): m.controller = steps[f]; fr = m.step(1)
        out.append(Image.fromarray(np.array(fr)))
    return out


def battle_fit(nes_path, out):
    """Owner (2026-11-19): all 4 members and every formation must be on screen. Survey of
    the 128 formations (tools/gb2/ff2form.py): enemies NES x 16-159, y 48-143 (exactly
    12 rows high; 126 formations within x 16-143, the Emperor x 25-151, formation 90 (three
    48-px monsters across) x 17-159). Owner's choice: enemy area = NES x 20-159 at GB x
    0-139 (formation 90 loses 3 px of an antenna at the left edge), party column GB x
    140-159: front row x 140, back row x 144 (4 px), every sprite whole; members at y 0 /
    24 / 48 / 72 (24-px slots; the NES stands them 27 px apart, y 45-149)."""
    frames = forced_battle(nes_path, [90, 126, 7, 34])
    shots = []
    for f in frames:
        s = Screen(bg=3)
        s.im.paste(dmg(f.crop((20, 48, 160, 144))), (0, 0))           # enemy area: NES x 20-159
        import numpy as np
        a = np.array(f).astype(int)
        for k, y0 in enumerate((45, 72, 99, 126)):                 # NES member slots (24 px tall)
            band = a[y0:y0 + 24, 200:256]
            xs = np.nonzero((band.sum(axis=2) > 40).any(axis=0))[0]
            if not len(xs): continue
            x0 = 200 + xs.min()
            back = x0 >= 220                                       # NES back row: 10-12 px right
            s.im.paste(dmg(f.crop((x0, y0, x0 + 16, y0 + 24))), (144 if back else 140, 24 * k))
        s.window(0, 12, 8, 6); s.window(8, 12, 12, 6)
        for i, (n, hp, mx, mp, st) in enumerate(PARTY):
            y = (13 + i) * 8
            _pt(s, 9 * 8 + 1, y, n); h = '%d/%s' % (hp, st or mx)
            _pt(s, 140 - s.pwidth(h, DIG3), y, h, DIG3); _pt(s, 155 - s.pwidth(str(mp), DIG3), y, str(mp), DIG3)
        shots.append(s)
    sheet = Image.new('RGB', (168 * len(shots) - 8, 144), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, (k * 168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock5_battle_fit.png'); sheet.save(p); return p


def battle_lists(nes_path, out):
    """Battle magic list and Gear window (the NES: 21 x 8 windows; the GB bottom window has
    4 lines). Magic: two columns (pen x 17 / 89, hand at x 0 / 72), three rows a page, the
    MP line ("MP 5/5", "MP Cost 2") on line 4; moving past the last row turns the page.
    Gear: Right Hand + weapon, Left Hand + weapon, Items + item 1, item 2 below it (the
    labels and names as translated, only the line breaks change)."""
    f = nes_battle_frame(nes_path)
    enemies = dmg(f.crop((20, 48, 160, 144)))
    def base():
        s = Screen(bg=3); s.im.paste(enemies, (0, 0))
        a = f.crop((200, 44, 256, 150))
        import numpy as np
        arr = np.array(f).astype(int)
        for k, y0 in enumerate((45, 72, 99, 126)):
            band = arr[y0:y0 + 24, 200:256]
            xs = np.nonzero((band.sum(axis=2) > 40).any(axis=0))[0]
            if len(xs):
                x0 = 200 + xs.min(); s.im.paste(dmg(f.crop((x0, y0, x0 + 16, y0 + 24))), (144 if x0 >= 220 else 140, 24 * k))
        s.window(0, 12, 20, 6)
        return s
    shots = []
    s = base()
    spells = [('Fire', 3), ('Cure', 2), ('Blizzard', 1), ('Thunder', 1), ('Toad', 1), ('Life', 1)]
    for i, (n, lv) in enumerate(spells):
        x = 17 if i % 2 == 0 else 89; y = (13 + i // 2) * 8
        w = _pt(s, 0, y, n, None) if False else None
        s.ptext(0, 13 + i // 2, n, px=x)
        lvx = x + s.pwidth(n) + 4
        _pt(s, lvx, y, str(lv), DIG3)
    _pt(s, 17, 16 * 8, 'MP'); _pt(s, 31, 16 * 8, '5/5', DIG3); _pt(s, 89, 16 * 8, 'MP Cost'); _pt(s, 89 + s.pwidth('MP Cost') + 4, 16 * 8, '2', DIG3)
    _hand(s, -2, 13 * 8 - 4, HAND16); shots.append(s)
    s = base()
    for i, (lab, item) in enumerate([('Right Hand', 'Broadsword'), ('Left Hand', 'Buckler'), ('Items', 'Potion'), ('', 'Diamond Gauntlets')]):
        if lab: s.ptext(0, 13 + i, lab, px=17)
        s.ptext(0, 13 + i, item, px=62)
    _hand(s, -2, 13 * 8 - 4, HAND16); shots.append(s)
    sheet = Image.new('RGB', (168 * len(shots) - 8, 144), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, (k * 168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock6_battle_lists.png'); sheet.save(p); return p


def nes_frame(nes_path, frame):
    from cynes import NES
    import firstdiff as fd
    import numpy as np
    steps = fd.script_newgame(frame + 1); fd.add_random(steps, 1)
    n = NES(nes_path)
    for f in range(frame + 1):
        n.controller = steps[f]; fr = n.step(1)
    return Image.fromarray(np.array(fr))


def wrap(text, width):
    lines = []
    for para in text.split('\n'):
        line = ''
        for w in para.split(' '):
            cand = (line + ' ' + w) if line else w
            if len(cand) <= width: line = cand
            else: lines.append(line); line = w
        lines.append(line)
    return lines


def dialogue(nes_path, out):
    """Field dialogue, after FF1's GB dialogue: box over the top of the view (GB rows 0-7:
    frame, 6 text lines of 18 columns, frame), the party below it stays visible; the same
    text re-wrapped at 18 columns, a new page of 6 lines on A (the NES box has 26 columns
    and 8 rows)."""
    bg = dmg(nes_frame(nes_path, 11600).crop((48, 48, 208, 192)))
    text = ('Minwu: "This magic circle amplifies the life force. Let us leave him in peace."\n'
            'Firion: "I\'m relieved. Now then, let us go to the council. Everyone should be '
            'gathered by now. The Great Battleship the Empire is building in Bafsk! Once it is '
            'completed, the enemy\'s all-out attack will begin. We must do something!"')
    lines = wrap(text, 18)
    shots = []
    for page in range(0, min(len(lines), 18), 6):
        s = Screen(bg=3); s.im.paste(bg, (0, 0))
        s.window(0, 0, 20, 8)
        for i, l in enumerate(lines[page:page + 6]): s.text(1, 1 + i, l, fg=0, bg=3)
        shots.append(s)
    sheet = Image.new('RGB', (168 * len(shots) - 8, 144), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, (k * 168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock2_dialogue.png'); sheet.save(p); return p


def main_menu(out):
    """Main menu: party window (0,0,20,7), one line per member under an HP / MP header:
    name, HP current/max and MP current/max in 3-px digits (FF2 has no levels; up to
    9999 HP / 999 MP); commands window (0,7,9,7), one command per row (Items, Magic,
    Equip, Status, Save); Gil window (0,14,9,3). The NES portraits move to the Status
    screen."""
    party = [('Firion', 30, 30, 5, 5), ('Maria', 20, 20, 5, 5), ('Guy', 40, 40, 5, 5), ('Minwu', 9999, 9999, 999, 999)]
    s = Screen(bg=3)
    s.window(0, 0, 20, 7)
    _pt(s, 96, 8, 'HP'); _pt(s, 138, 8, 'MP')
    for i, (n, hp, mx, mp, mm) in enumerate(party):
        y = (2 + i) * 8
        s.text(1, 2 + i, n, fg=0, bg=3)
        h = '%d/%d' % (hp, mx); m = '%d/%d' % (mp, mm)
        _pt(s, 112 - s.pwidth(h, DIG3), y, h, DIG3)
        _pt(s, 152 - s.pwidth(m, DIG3), y, m, DIG3)
    s.window(0, 7, 9, 7)
    for i, c in enumerate(['Items', 'Magic', 'Equip', 'Status', 'Save']): s.text(2, 8 + i, c, fg=0, bg=3)
    _hand(s, -6, 8 * 8 - 4, HAND16)
    s.window(0, 14, 9, 3)
    s.text(1, 15, '400 Gil', fg=0, bg=3)
    p = os.path.join(out, 'ff2_mock3_menu.png'); s.save(p, scale=2); return p


def portraits(nes_path):
    """the party portraits (32 x 32) from an NES main-menu frame (seed 1 path, frame 17600)"""
    f = nes_frame(nes_path, 17600)
    return [dmg(f.crop((x, y, x + 32, y + 32))) for x, y in ((16, 16), (128, 16), (32, 96))]


def main_menu_portraits(nes_path, out):
    """Owner (2026-11-19): keep the portraits. A: party window over the left 13 columns,
    full height, one 4-row block per member: portrait (4 x 4 tiles), name, HP cur/max, MP
    cur/max (3-px digits), status word; commands (cols 13-19, rows 0-6) and Gil (rows 7-9)
    beside it. B: the approved one-line list, plus a window with the portrait of the member
    the cursor is on (and when no member is chosen, the leader's)."""
    pt = portraits(nes_path)
    party = [('Firion', 30, 30, 5, 5, ''), ('Maria', 20, 20, 5, 5, 'Poison'), ('Guy', 40, 40, 5, 5, ''),
             ('Minwu', 9999, 9999, 999, 999, '')]
    a = Screen(bg=3)
    a.window(0, 0, 13, 18)
    for i, (n, hp, mx, mp, mm, st) in enumerate(party):
        y = 1 + 4 * i
        img = pt[i] if i < 3 else None
        if img: a.im.paste(img, (8, y * 8))
        else: a.block(1, y, 4, 4)
        a.text(5, y, n, fg=0, bg=3)
        _pt(a, 40, (y + 1) * 8, 'HP'); h = '%d/%d' % (hp, mx); _pt(a, 98 - a.pwidth(h, DIG3), (y + 1) * 8, h, DIG3)
        _pt(a, 40, (y + 2) * 8, 'MP'); m = '%d/%d' % (mp, mm); _pt(a, 98 - a.pwidth(m, DIG3), (y + 2) * 8, m, DIG3)
        if st: _pt(a, 40, (y + 3) * 8, st)
    a.window(13, 0, 7, 7)
    for i, c in enumerate(['Items', 'Magic', 'Equip', 'Status', 'Save']): _pt(a, 13 * 8 + 12, (1 + i) * 8, c)
    _hand(a, 13 * 8 - 6, 8 - 4, HAND16)
    a.window(13, 7, 7, 3); _pt(a, 13 * 8 + 6, 8 * 8, '400 Gil')
    b = Screen(bg=3)
    b.window(0, 0, 20, 7)
    _pt(b, 96, 8, 'HP'); _pt(b, 138, 8, 'MP')
    for i, (n, hp, mx, mp, mm, st) in enumerate(party):
        y = (2 + i) * 8
        b.text(1, 2 + i, n, fg=0, bg=3)
        h = '%d/%d' % (hp, mx); m = '%d/%d' % (mp, mm)
        _pt(b, 112 - b.pwidth(h, DIG3), y, h, DIG3); _pt(b, 152 - b.pwidth(m, DIG3), y, m, DIG3)
    b.window(0, 7, 9, 7)
    for i, c in enumerate(['Items', 'Magic', 'Equip', 'Status', 'Save']): b.text(2, 8 + i, c, fg=0, bg=3)
    _hand(b, -6, 8 * 8 - 4, HAND16)
    b.window(0, 14, 9, 3); b.text(1, 15, '400 Gil', fg=0, bg=3)
    b.window(11, 8, 6, 6); b.im.paste(pt[0], (11 * 8 + 8, 8 * 8 + 8))
    sheet = Image.new('RGB', (168 * 2 - 8, 144), (255, 255, 255))
    sheet.paste(a.im, (0, 0)); sheet.paste(b.im, (168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock4_menu_portraits.png'); sheet.save(p); return p


def _fit(s, X, Y, txt, width):
    """proportional text squeezed into width px: condensed letters, then the narrow
    forms (tools/latin_font.py NARROW), then letter gaps dropped from the right"""
    from latin_font import NARROW
    tab = None if s.pwidth(txt) <= width else NARROW
    w = s.pwidth(txt, tab)
    drop = max(0, w - width)
    for k, ch in enumerate(txt):
        if k:
            if drop and k >= len(txt) - drop: pass
            else: X += 1
        if ch == ' ': X += 2; continue
        t = tab if tab is not None and ch in tab else None
        _pt(s, X, Y, ch, t)
        X += s.pwidth(ch, t)


def loot_menu(out):
    """Treasure screen after a battle (NES: loot window, Drop / Done window and a 19 x 28
    inventory window side by side). GB: treasure window (0,0,20,7): "Treasure", Drop and
    Done on line 1, the 8 treasure slots in two columns below; inventory window (0,6,20,12)
    sharing its border: two columns, 10 of the 16 rows, scrolling. Columns 64 px (text at
    x 8 / 88, hands at x -8 / 72); longer names use the narrow letters and drop letter gaps
    (widest: Diamond Breastplate). Up / down move through all rows of both windows, left /
    right between the two columns; A on a slot picks it (a second hand stays on it) and A on
    another slot swaps them, as on the NES."""
    loot = ['Potion', 'Book of Blizzard', 'Diamond Breastplate', '', '', '', '', '']
    inv = ['Potion', 'Antarctic Wind', 'Cottage', 'Sulfuric Acid Bottle', 'Book of Fire', 'Ether',
           'Copper Breastplate', 'Phoenix Tail', 'Leather Cap', 'Mythril Gauntlets', 'Golden Needle',
           'Sword of the Earth', "Maiden's Kiss", 'Eye Drops', 'Garlic', 'Antidote', 'High Potion',
           'Mythril Shield', 'Hermes Shoes', 'Unicorn Horn', 'Elixir', 'Cross'] + [''] * 10 

    def screen(hand, hand2=None, scroll=0):
        s = Screen(bg=3)
        s.window(0, 6, 20, 12)
        s.window(0, 0, 20, 7)
        _pt(s, 8, 8, 'Treasure'); _pt(s, 96, 8, 'Drop'); _pt(s, 132, 8, 'Done')
        for k, n in enumerate(loot):
            if n: _fit(s, 8 + 80 * (k % 2), (2 + k // 2) * 8, n, 64)
        for r in range(10):
            for c in range(2):
                n = inv[2 * (r + scroll) + c]
                if n: _fit(s, 8 + 80 * c, (7 + r) * 8, n, 64)
        for h in [hand] + ([hand2] if hand2 else []):
            _hand(s, h[0], h[1] * 8 - 4, HAND16)
        return s

    shots = [screen((-8, 3)), screen((-8, 11), hand2=(72, 2)), screen((72, 16), scroll=6)]
    sheet = Image.new('RGB', (168 * len(shots) - 8, 144), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, (k * 168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock7_treasure.png'); sheet.save(p); return p


def keyword_windows(nes_path, out):
    """Field keyword menus (NES windows 1-3: Ask / Learn / Items at (2,18), the keyword or item
    list at (8,18) 24 wide, Yes / No at (18,14); NES rows 14-27, below the GB view). GB: the
    dialogue box stays on rows 0-7 and the party on rows 8-9; the menus use rows 10-17:
    Ask / Learn / Items (0,10,8,5), hand at the screen edge; the keyword / item list a
    full-width window (0,10,20,8) over it, one column from column 1 (18 letters: all
    keywords, all but 3 item names), hand cut by the screen edge, 6 of the 16 keywords /
    32 items, scrolling; Yes / No (12,10,8,4). Same NES font as the dialogue."""
    f = nes_frame_layout(nes_path, 13843)
    bg = f.crop((48, 48, 208, 192))
    def base():
        s = Screen(bg=3); s.im.paste(bg, (0, 0)); return s
    shots = []
    s = base(); s.window(0, 10, 8, 5)
    for i, w in enumerate(['Ask', 'Learn', 'Items']): s.text(2, 11 + i, w)
    _hand(s, -6, 12 * 8 - 4, HAND16); shots.append(s)
    s = base(); s.window(0, 10, 20, 8)
    for i, w in enumerate(['Wild Rose', 'Mythril', 'Goddess\'s Bell', 'Sunfire', 'Great Battleship', 'Airship']):
        s.text(1, 11 + i, w)
    _hand(s, -9, 11 * 8 - 4, HAND16); shots.append(s)
    s = base(); s.window(0, 10, 20, 8)
    for i, w in enumerate(['Potion', 'Antidote', 'Cottage', 'Golden Breastplate', 'Phoenix Tail', 'Pass']):
        s.text(1, 11 + i, w)
    _hand(s, -9, 14 * 8 - 4, HAND16); shots.append(s)
    s = base(); s.window(12, 10, 8, 4)
    for i, w in enumerate(['Yes', 'No']): s.text(14, 11 + i, w)
    _hand(s, 12 * 8 - 6, 11 * 8 - 4, HAND16); shots.append(s)
    sheet = Image.new('RGB', (168 * len(shots) - 8, 144), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, (k * 168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock8_keywords.png'); sheet.save(p); return p


def nes_frame_layout(nes_path, frame):
    """NES frame of the GB-layout build (seed 1 path) in DMG-like shades"""
    return dmg(nes_frame(nes_path, frame))


def main_menu_bg(nes_path, out):
    """Main menu, option A as built (portraits as background tiles: a Game Boy shows 40
    sprites, four portraits need 48; NES colours come in 16 x 16 blocks, so each portrait
    sits in its own black 32 x 32 box at the left edge, outside the party window).
    Party window (4,0,8,18): per member name (NES letters), HP and MP in small letters /
    3-px digits, status word on the 4th row; commands (12,0,8,7), one per row, hand over
    the frames between the windows; Gil (12,14,8,4): amount in 3-px digits, "Gil" below."""
    pt = portraits(nes_path)
    party = [('Firion', 30, 30, 5, 5, ''), ('Maria', 20, 20, 5, 5, 'Poison'), ('Guy', 40, 40, 5, 5, ''),
             ('Minwu', 9999, 9999, 999, 999, '')]
    a = Screen(bg=3)
    for i in range(4):
        img = pt[i] if i < 3 else None
        if img: a.im.paste(img.crop((4, 0, 28, 32)), (4, 32 * i))
        else: a.block(0, 4 * i, 4, 4)
    a.window(4, 0, 8, 18)
    for i, (n, hp, mx, mp, mm, st) in enumerate(party):
        y = 1 + 4 * i
        a.text(5, y, n, fg=0, bg=3)
        _pt(a, 40, (y + 1) * 8, 'HP'); h = '%d/%d' % (hp, mx); _pt(a, 87 - a.pwidth(h, DIG3), (y + 1) * 8, h, DIG3)
        _pt(a, 40, (y + 2) * 8, 'MP'); m = '%d/%d' % (mp, mm); _pt(a, 87 - a.pwidth(m, DIG3), (y + 2) * 8, m, DIG3)
        if st: _pt(a, 87 - a.pwidth(st), (y + 3) * 8, st)
    a.window(12, 0, 8, 7)
    for i, c in enumerate(['Items', 'Magic', 'Equip', 'Status', 'Save']): a.text(13, 1 + i, c, fg=0, bg=3)
    _hand(a, 13 * 8 - 16, 8 - 4, HAND16)
    a.window(12, 14, 8, 4)
    g = '9999999'; _pt(a, 150 - a.pwidth(g, DIG3), 15 * 8, g, DIG3); a.text(15, 16, 'Gil', fg=0, bg=3)
    im = a.im.resize((320, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock9_menu_bg.png'); im.save(p); return p


def sub_screens(nes_path, out):
    """Main-menu sub-screens (camera 1 / 1 as the main menu; the NES letters; portraits stay
    sprites: one at a time). Items: title (0,0,8,3), list (0,2,20,16), 14 rows, one column,
    scrolling. Magic / Equip / Status: top window (0,0,20,6) with the portrait and 4 lines,
    a list window (0,5,20,13) with 11 rows. Equip: the 5 slots as label + item rows and the
    Item slot (11 rows, as the NES); the replacement list opens over the lower rows
    (0,12,20,6). Status: page 1 the 6 attributes and 5 battle values, page 2 (Right / Left)
    the weapon skills in two columns."""
    pt = portraits(nes_path)[0]
    def top(s, title, lines):
        s.window(0, 0, 20, 6); s.im.paste(pt.crop((4, 0, 28, 32)), (8, 8))
        for i, l in enumerate([title] + lines): s.text(5, 1 + i, l)
    shots = []
    s = Screen(bg=3); s.window(0, 2, 20, 16); s.window(0, 0, 8, 3); s.text(1, 1, 'Items')
    for i, n in enumerate(['Potion', 'Sulfuric Acid Bottle', 'Diamond Breastplate', 'Golden Breastplate',
                           'Ring of Protection', 'Antidote', 'Cottage', 'Phoenix Tail', "Maiden's Kiss", 'Ether',
                           'Eye Drops', 'Garlic', 'Elixir', 'Cross']):
        if len(n) <= 18: s.text(1, 3 + i, n)
        else: _fit(s, 8, (3 + i) * 8, n, 144)
    _hand(s, -9, 3 * 8 - 4, HAND16); shots.append(s)
    s = Screen(bg=3); top(s, 'Magic', ['AAAAAA', 'HP 30/ 30', 'MP  5/  5'])
    s.window(0, 5, 20, 13)
    for i, (n, l) in enumerate([('Fire', 3), ('Cure', 2), ('Blizzard', 1), ('Thunder', 1), ('Toad', 1), ('Life', 1)]):
        s.text(2, 6 + i, n); s.text(14, 6 + i, 'L%2d' % l)
    _hand(s, -1, 6 * 8 - 4, HAND16); shots.append(s)
    s = Screen(bg=3); top(s, 'Equip', ['AAAAAA', 'Attack .. 10', 'Defense .. 2'])
    s.window(0, 5, 20, 13)
    for i, l in enumerate(['Right Hand', ' Broadsword', 'Head', '', 'Arms', '', 'Left Hand', ' Buckler', 'Body',
                           ' Leather Armor', 'Item']):
        s.text(2, 6 + i, l)
    _hand(s, -1, 6 * 8 - 4, HAND16); shots.append(s)
    s2 = Screen(bg=3); s2.im.paste(s.im, (0, 0)); s2.window(0, 12, 20, 6)
    for i, n in enumerate(['Broadsword', 'Mythril Knife', 'Bronze Shield', 'Dagger']): s2.text(2, 13 + i, n)
    _hand(s2, -1, 13 * 8 - 4, HAND16); shots.append(s2)
    s = Screen(bg=3); top(s, 'AAAAAA', ['HP 30/ 30', 'MP  5/  5', 'Right-handed'])
    s.window(0, 5, 20, 13)
    for i, (l, v) in enumerate([('Strength', '10'), ('Agility', '10'), ('Stamina', '10'), ('Intelligence', '10'),
                                ('Spirit', '10'), ('Magic Power', '10'), ('Attack', ' 10'), ('Hit Rate', ' 70%'),
                                ('Defense', '  2'), ('Evasion', ' 14%'), ('Magic Defense', ' 12%')]):
        s.text(1, 6 + i, l); s.text(14, 6 + i, '..' + v.strip())
    shots.append(s)
    s = Screen(bg=3); top(s, 'AAAAAA', ['HP 30/ 30', 'MP  5/  5', 'Right-handed'])
    s.window(0, 5, 20, 13); s.text(1, 6, 'Skill Level')
    sk = ['Fist', 'Shield', 'Knife', 'Spear', 'Staff', 'Sword', 'Axe', 'Bow']
    for i in range(8):
        r, c = 8 + 2 * (i // 2), 1 + 9 * (i % 2)
        s.block(c, r, 1, 1); s.text(c + 1, r, '1-00%')
    shots.append(s)
    sheet = Image.new('RGB', (168 * 3 - 8, 152 * 2 - 8), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, ((k % 3) * 168, (k // 3) * 152))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock10_subscreens.png'); sheet.save(p); return p


def target_select(nes_path, out):
    """Item / spell use on the field (NES: the four member windows plus a description window
    at the bottom, NES rows 21-28). GB: description window (0,0,20,12): up to 8 lines of 18
    (the longest, the mallet's, has 8); party window (0,12,20,6): one line per member: name,
    HP current/max and MP current/max in 3-px digits; an afflicted member's status word in
    place of MP. Hand at the screen edge on the chosen line."""
    import textwrap
    shots = []
    for txt, party in (("Medicine that restores HP. On whom will you use it?",
                        [('AAAAAA', 30, 30, 5, 5, ''), ('WBBBr-', 12, 20, 5, 5, 'Poison'), ('1jigLK', 40, 40, 5, 5, ''),
                         ('Minwu', 9999, 9999, 999, 999, '')]),
                       ("When someone has forgotten their magic, give their head a jolt with this mallet and it comes back. On whom will you use it?",
                        [('AAAAAA', 30, 30, 5, 5, ''), ('WBBBr-', 20, 20, 5, 5, 'Forgot'), ('1jigLK', 0, 40, 5, 5, 'Dead'),
                         ('', 0, 0, 0, 0, '')])):
        s = Screen(bg=3)
        s.window(0, 0, 20, 12)
        for i, l in enumerate(textwrap.wrap(txt, 18)): s.text(1, 1 + i, l)
        s.window(0, 12, 20, 6)
        for i, (n, hp, mx, mp, mm, st) in enumerate(party):
            if not n: continue
            y = 13 + i
            s.text(1, y, n)
            h = '%d/%d' % (hp, mx); _pt(s, 96 - s.pwidth(h, DIG3), y * 8, h, DIG3)
            if st: s.text(13, y, st[:6].rjust(6)[-6:])
            else: m = '%d/%d' % (mp, mm); _pt(s, 150 - s.pwidth(m, DIG3), y * 8, m, DIG3)
        _hand(s, -9, 14 * 8 - 4, HAND16); shots.append(s)
    sheet = Image.new('RGB', (168 * 2 - 8, 144), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, (k * 168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock11_target.png'); sheet.save(p); return p


def shop(nes_path, out):
    """Shops (NES: the price list inside the dialogue window, beside the prompt; Buy / Sell /
    Exit and Gil windows below). GB: dialogue box rows 0-7 as in the field; Buy / Sell / Exit
    (0,9,8,6) and Gil (8,9,12,4: amount, "Gil" below) under it. Buying: the list in its own
    window over the dialogue box (0,0,20,10): per item the name, the price below it on the
    right (names up to 19 letters). Selling: "What will you sell?" in the box, the item list
    (0,10,20,8) over the menu / Gil windows, as the field's item list."""
    shots = []
    def base(msg):
        s = Screen(bg=3)
        s.window(0, 0, 20, 8)
        for i, l in enumerate(msg): s.text(1, 1 + i, l)
        s.window(0, 9, 8, 6)
        for i, w in enumerate(['Buy', 'Sell', 'Exit']): s.text(2, 10 + i, w)
        s.window(8, 9, 12, 4); s.text(11, 10, '    400'); s.text(16, 11, 'Gil')
        return s
    s = base(['Welcome.', 'How may I help', 'you?']); _hand(s, -6, 10 * 8 - 4, HAND16); shots.append(s)
    s = base(['What may I', 'get for you?'])
    s.window(0, 0, 20, 10)
    for i, (n, p) in enumerate([('Bronze Gauntlets', 400), ('Mythril Gauntlets', 2500), ("Giant's Gauntlets", 6000),
                                ('Diamond Gauntlets', 12000)]):
        s.text(1, 1 + 2 * i, n); t = str(p); s.text(18 - len(t), 2 + 2 * i, t)
    _hand(s, -9, 1 * 8 - 4, HAND16); shots.append(s)
    s = base(['What will you', 'sell me?'])
    s.window(0, 10, 20, 8)
    for i, n in enumerate(['Potion', 'Antidote', 'Cottage', 'Golden Breastplate', 'Phoenix Tail', 'Pass']):
        s.text(1, 11 + i, n)
    _hand(s, -9, 11 * 8 - 4, HAND16); shots.append(s)
    sheet = Image.new('RGB', (168 * 3 - 8, 144), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, (k * 168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock12_shop.png'); sheet.save(p); return p


if __name__ == '__main__':
    os.makedirs(sys.argv[2], exist_ok=True)
    print(battle(sys.argv[1], sys.argv[2]))
    print(dialogue(sys.argv[1], sys.argv[2]))
    print(main_menu(sys.argv[2]))
    print(main_menu_portraits(sys.argv[1], sys.argv[2]))
    print(battle_fit(sys.argv[1], sys.argv[2]))
    print(battle_lists(sys.argv[1], sys.argv[2]))
    print(loot_menu(sys.argv[2]))
    print(keyword_windows(sys.argv[1], sys.argv[2]))
    print(main_menu_bg(sys.argv[1], sys.argv[2]))
    print(sub_screens(sys.argv[1], sys.argv[2]))
    print(target_select(sys.argv[1], sys.argv[2]))
    print(shop(sys.argv[1], sys.argv[2]))


def credits_lines(nes_path):
    """the splash screen's credit lines from the ROM (fix:F692: tile codes, $FE = next line
    two rows down, $FF = end; first line at NES row 8): [(nes_row, nes_col0, codes)]"""
    import layout
    r = open(nes_path, 'rb').read()
    o = layout.HDR + 15 * layout.BANK + 0xF692 - 0xC000
    lines, row, cur = [], 8, []
    while r[o] != 0xFF:
        if r[o] == 0xFE:
            lines.append((row, 2, cur)); cur = []; row += 2
        else: cur.append(r[o])
        o += 1
    lines.append((row, 2, cur))
    return [l for l in lines if any(l[2])]


def gb_credit_lines(codes):
    import layout
    return layout.gb_credit_lines(codes)


def new_game(nes_path, out):
    """Splash / prologue / load menu / name entry (camera at the window, no panning).
    Splash: the ROM's credit lines centred in 18 columns (a line over 18 split after BY).
    Prologue: the same text at 18 columns, one paragraph a page (12 / 11 / 9 lines), shown
    band by band as on the NES; A or B ends it as on the NES. Load menu: four slot windows
    sharing their frames (0,1,20,4) .. (0,10,20,4) with leader name, Speed and HP / MP in
    3-px digits; New Game window (0,14,20,4). Name entry: portrait + name window (0,0,20,6);
    letter grid (0,6,20,12): 9 letters a row (the NES has 10 in two groups of 5, 22 columns),
    two rows apart, 5 of the 9 rows shown, scrolling as on the NES."""
    import json, textwrap
    from cynes import NES
    import numpy as np
    shots = []
    # splash, from a frame of the NES splash screen (glyphs cropped from the NES picture)
    n = NES(nes_path)
    for f in range(1201): n.controller = 0; fr = n.step(1)
    nes = Image.fromarray(np.array(fr))
    s = Screen(bg=3)
    lines = credits_lines(nes_path)
    gb = []
    for row, col0, codes in lines:
        lead = next(i for i, c in enumerate(codes) if c)
        segs = gb_credit_lines(codes)
        pos = col0 + lead
        for sg in segs:
            gb.append((sg, row, pos)); pos += len(sg) + 1
    rows = {0: 3, 1: 6, 2: 9, 3: 11, 4: 12, 5: 14, 6: 15}
    for i, (sg, row, pos) in enumerate(gb):
        x = (20 - len(sg)) // 2
        for k, c in enumerate(sg):
            if c:
                t = nes.crop(((pos + k) * 8, row * 8, (pos + k) * 8 + 8, row * 8 + 8))
                t = t.convert('L').point(lambda v: 255 if v > 128 else 0).convert('1')
                s.im.paste(SHADES[0], ((x + k) * 8, rows.get(i, 16) * 8), t)
    shots.append(s)
    # prologue pages
    t = [e for e in json.load(open(os.path.join(HERE, '..', '..', 'script', 'ff2', 'system.json'))) if e['id'] == 73][0]['en']
    paras = [textwrap.wrap(' '.join(p.split('\n')), 18, break_on_hyphens=False) for p in t.split('\n\n')]
    for k, p in enumerate(paras[:3:2]):
        s = Screen(bg=3)
        y0 = (18 - len(p)) // 2
        shown = len(p) if k else 8
        for i, l in enumerate(p[:shown]): s.text((20 - len(l)) // 2, y0 + i, l, fg=0, bg=3)
        shots.append(s)
    # load menu
    s = Screen(bg=3)
    slots = [('AAAAAA', 6, 30, 30, 5, 5), None, ('Firion', 3, 1250, 1490, 88, 120), None]
    for k, sl in enumerate(slots):
        s.window(0, 1 + 3 * k, 20, 4)
    for k, sl in enumerate(slots):
        y = 2 + 3 * k
        s.text(1, y, str(k + 1))
        if sl:
            nm, sp, hp, mh, mp, mm = sl
            s.text(3, y, nm); s.text(11, y, 'Speed %d' % sp)
            _pt(s, 24, (y + 1) * 8, 'HP'); h = '%d/%d' % (hp, mh); _pt(s, 80 - s.pwidth(h, DIG3), (y + 1) * 8, h, DIG3)
            _pt(s, 96, (y + 1) * 8, 'MP'); m = '%d/%d' % (mp, mm); _pt(s, 140 - s.pwidth(m, DIG3), (y + 1) * 8, m, DIG3)
    s.window(0, 14, 20, 4); s.text(2, 15, 'New Game  Speed 6')
    _hand(s, -9, 2 * 8 - 4, HAND16)
    shots.append(s)
    # name entry
    grid = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,\'-!?&/:()";+% '
    pt = portraits(nes_path)[0]
    for top in (0, 4):
        s = Screen(bg=3)
        s.window(0, 0, 20, 6); s.im.paste(pt.crop((4, 0, 28, 32)), (12, 8))
        s.text(6, 2, 'Fir'); s.block(9, 2, 1, 1)
        s.window(0, 6, 20, 12)
        for r in range(5):
            row = grid[(top + r) * 9:(top + r) * 9 + 9]
            for c, ch in enumerate(row): s.text(2 + 2 * c, 8 + 2 * r, ch)
        _hand(s, 0, (8 + 2 * (2 if top else 0)) * 8 - 4, HAND16)
        shots.append(s)
    sheet = Image.new('RGB', (168 * 3 - 8, 152 * 2 - 8), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, ((k % 3) * 168, (k // 3) * 152))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock13_newgame.png'); sheet.save(p); return p


def loaded_frames(nes_path, presses, frames, ring=True):
    """NES frames after loading a saved game: the party of the seed-1 path at frame 22580 is
    written into SRAM slots 1 and 3 (checksum, $5A mark; ring flag on for the world-map
    overview) at frame 100, the prologue ends at 3300 (A), slot 1 is loaded at 3420 (A);
    presses = {frame: pad}; returns {frame: image}"""
    from cynes import NES
    import firstdiff as fd
    import numpy as np
    steps = fd.script_newgame(22600); fd.add_random(steps, 1)
    n = NES(nes_path)
    for f in range(22580): n.controller = steps[f]; n.step(1)
    d = bytearray(n[0x6000 + i] for i in range(0x300))
    if ring: d[0x1A] |= 2
    d[0x2FE] = 0x5A; d[0x2FF] = (0xFF - sum(d[:0x2FF])) & 0xFF
    n = NES(nes_path); out = {}
    pads = {3300: 128, 3420: 128}; pads.update(presses)
    hold = {}
    for f, p in pads.items():
        for j in range(f, f + 4): hold[j] = p
    for f in range(max(frames) + 1):
        if f == 100:
            for s in (0, 2):
                for i in range(0x300): n[0x6300 + 0x300 * s + i] = d[i]
        n.controller = hold.get(f, 0); fr = n.step(1)
        if f in frames: out[f] = Image.fromarray(np.array(fr))
    return out


def row_menu_map(nes_path, out):
    """Select on the world map. Row menu (camera 6 / 5: its window NES (7,5,18,18) whole in
    the view): portraits as background tiles as in the main menu (four 24 x 32 portraits are
    48 sprites, a Game Boy shows 40; three fit, the guest makes four), front row at GB col
    10, back row 4 columns right (NES: 5; the portraits stay on the 16 x 16 colour grid);
    names and hand as the NES. World-map overview (B + Select with the ring): camera on the
    globe (camera 6 / 9: NES rows 9-26, the globe centred), the FINAL FANTASY II logo above it is left out of the view."""
    fr = loaded_frames(nes_path, {3800: 32, 3900: 4, 4000: 64, 4100: 96}, [3870, 3960, 4300])
    pt = portraits(nes_path)
    shots = []
    nes_rm = fr[3870]
    names = []
    for k in range(3):                          # names cropped from the NES picture (row 9 + 4k)
        names.append(dmg(nes_rm.crop((80, (9 + 4 * k) * 8, 128, (10 + 4 * k) * 8))))
    for back in ((False, False, False, False), (False, True, False, True)):
        s = Screen(bg=3)
        s.window(1, 0, 18, 18)
        for k in range(4):
            img = pt[k] if k < len(pt) else pt[0]
            x = 14 if back[k] else 10
            s.im.paste(img.crop((4, 0, 28, 32)), (x * 8, (1 + 4 * k) * 8))
            if k < 3: s.im.paste(names[k], (4 * 8, (4 + 4 * k) * 8))
            else: s.text(4, 4 + 4 * k, 'Minwu')
        _hand(s, 2 * 8, 4 * 8 - 4 + (32 if back[1] else 0), HAND16)
        shots.append(s)
    s = Screen(bg=3)
    s.im.paste(fr[4300].crop((48, 72, 208, 216)), (0, 0))   # (NES colours: the dark ocean is the
    #   backdrop in the mock-up shades)
    shots.append(s)
    sheet = Image.new('RGB', (168 * 3 - 8, 144), (255, 255, 255))
    for k, s in enumerate(shots): sheet.paste(s.im, (k * 168, 0))
    sheet = sheet.resize((sheet.width * 2, 288), Image.NEAREST)
    p = os.path.join(out, 'ff2_mock14_rows_map.png'); sheet.save(p); return p
