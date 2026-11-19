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


if __name__ == '__main__':
    os.makedirs(sys.argv[2], exist_ok=True)
    print(battle(sys.argv[1], sys.argv[2]))
    print(dialogue(sys.argv[1], sys.argv[2]))
    print(main_menu(sys.argv[2]))
    print(main_menu_portraits(sys.argv[1], sys.argv[2]))
    print(battle_fit(sys.argv[1], sys.argv[2]))
