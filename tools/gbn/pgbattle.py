"""FF1 native build: the post-game's battles (docs/ff1-postgame-design.md), made at build time.

A dungeon's battles use their own copy of the battle data bank (battle.py's layout) and their own
enemy graphics / silhouette banks; the battle code reads the banks named in HRAM (hbt_db, hbt_cb,
hbt_sb: src/pg.s sets them when a map loads). In the copy, enemy ids, formations, palettes, names, the
fiend pictures and their target hands are the dungeon's; everything else (spells, messages, level-up
tables) is FF1's.

- Monsters: Dawn of Souls' stats (the user's GBA ROM, gba.py), in FF1's 20-byte record. Their pictures:
  Dawn of Souls recolours FF1 monsters (the same tile data, its own palette), so each is FF1's picture of
  that family (the user's NES ROM) with its colours taken over: each NES colour of the family's picture
  is matched to the family's GBA palette entry, and the new monster's entry at that place gives the
  colour (the nearest NES colour).
- Bosses: Dawn of Souls' pictures reduced to FF1's fiend picture (8 x 8 tiles), two palettes of three NES
  colours chosen per 16 x 16 block (FF1's fiends do the same), stats from the GBA record, abilities from
  the FINAL FANTASY wiki's lists given as FF1's own spells / enemy abilities.
- Formations and encounter rates: the wiki's tables per area (rates in 64ths)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import data, battle, gba

PGB_DATA, PGB_CHR, PGB_SIL = 119, 121, 123            # Earthgift's banks (CHR / SIL: 2 banks each)
PGB_SGB = 126                                        # its Super Game Boy bank (sgb.py's, its colours)

# (English name (the official Dawn of Souls name), GBA record)
EG_MONSTERS = [('Black Goblin', 163), ('Wild Nakk', 185), ('Gloom Widow', 166), ('Desertpede', 165),
               ('Skuldier', 191), ('Catoblepas', 181), ('Abyss Worm', 146)]
EG_BOSSES = [('Echidna', 128), ('Cerberus', 129), ('Ahriman', 130), ('Two-Headed Dragon', 131)]
HANGING = {'Echidna'}                                # (hangs from the top: her fiend picture at cell row 0)
# boss AI (FF1's record: magic chance, ability chance, 8 spells, $FF, 4 abilities, $FF): the wiki's
# abilities as FF1's spell numbers (names list 176 + n) / enemy abilities (0-25)
S_CURA, S_DEATH, S_QUAKE, S_FLARE = 16, 45, 46, 60
A_CRACK, A_BLIZZARD, A_BLAZE, A_THUNDER = 6, 10, 11, 17
BOSS_AI = {'Echidna': (0x30, 0x20, [S_FLARE, S_QUAKE, S_DEATH, S_FLARE, S_QUAKE, S_DEATH, S_FLARE, S_QUAKE],
                       [A_CRACK] * 4),
           'Cerberus': (0x00, 0x30, [], [A_THUNDER] * 4),
           'Ahriman': (0x28, 0x40, [S_CURA, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
                       [A_BLAZE, A_CRACK, A_BLIZZARD, A_THUNDER]),
           'Two-Headed Dragon': None}
# encounters per floor kind: (monster, min, max, rate in 64ths)
EG_ENC = {'cave': [('Black Goblin', 1, 5, 27), ('Wild Nakk', 4, 8, 19), ('Gloom Widow', 1, 3, 18)],
          'desert': [('Desertpede', 2, 4, 30), ('Gloom Widow', 1, 3, 15), ('Black Goblin', 1, 5, 12),
                     ('Catoblepas', 1, 3, 6), ('Abyss Worm', 1, 2, 1)],
          'forest': [('Skuldier', 2, 4, 21), ('Black Goblin', 1, 5, 18), ('Gloom Widow', 1, 3, 13),
                     ('Desertpede', 2, 4, 12)]}
ENC_RATE = 10                                        # (a step's chance in 256: FF1's dungeons' rate)


def nes_rgb(c):
    v = data.NES_RGB[c & 0x3F]
    return (v >> 16, (v >> 8) & 0xFF, v & 0xFF)


def gba_rgb(c):
    return ((c & 31) * 255 // 31, (c >> 5 & 31) * 255 // 31, (c >> 10 & 31) * 255 // 31)


NES_CHOICES = [c for c in range(0x40) if (c & 0x0F) not in (0x0D, 0x0E, 0x0F)] + [0x0F]


def nearest_nes(rgb, avoid_black=True):
    best = None
    for c in NES_CHOICES:
        if avoid_black and c == 0x0F: continue
        r, g, b = nes_rgb(c)
        d = (r - rgb[0]) ** 2 * 3 + (g - rgb[1]) ** 2 * 4 + (b - rgb[2]) ** 2 * 2
        if best is None or d < best[0]: best = (d, c)
    return best[1]


def nes_by_hue(rgb):
    """the NES colour of an RGB colour as a pixel artist picks it: its hue's column, its brightness's row
    (greys: the grey column)"""
    import colorsys
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in rgb))
    y = (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255
    row = 0 if y < 0.28 else (1 if y < 0.50 else (2 if y < 0.75 else 3))
    if s < 0.22 or max(rgb) - min(rgb) < 40:
        return [0x00, 0x10, 0x20, 0x30][row] if row else 0x00
    best = None
    for col in range(1, 13):
        r, g, b = nes_rgb(0x20 | col)
        hh = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)[0]
        d = min(abs(hh - h), 1 - abs(hh - h))
        if best is None or d < best[0]: best = (d, col)
    return row << 4 | best[1]


def stats(G, rec):
    """a GBA monster record -> FF1's 20-byte enemy record"""
    o = gba.MONSTERS + 32 * rec
    g = G.d[o:o + 32]
    r = bytearray(g[0:13])
    r += bytes([g[15], g[16], g[18], g[19], g[20], g[22], g[24]])
    return r


def ff1_graphics(rom):
    """FF1 enemy id -> (page, graphic 0-3, NES palette [4]) from the first formation showing it"""
    forms = rom.rd(battle.BANK_DOMAINS, battle.FORMATIONS, 128 * 16)
    out = {}
    for f in range(128):
        fd = forms[16 * f:16 * f + 16]
        ty = fd[0] >> 4
        if ty >= 3: continue
        for g in range(4):
            e = fd[2 + g]
            q = fd[6 + g] | (fd[14 + g] if g < 2 else 0)
            if e >= 128 or e in out or q == 0: continue
            gr = (fd[1] >> (2 * g)) & 3
            pb = (fd[13] >> (7 - g)) & 1
            pal = list(rom.rd(battle.BANK_BTLC, battle.BTL_PALS + 4 * fd[10 + pb], 4))
            out[e] = (fd[0] & 15, gr, pal)
    return out


SLOT_T0 = (0x12, 0x32, 0x22, 0x56)                  # graphic 0-3 (bt_egp bits 7-6: second, large)
SLOT_N = (16, 36, 16, 36)


def recolour(nes_pal, fam_cols, new_cols):
    out = [0x0F]
    for c in nes_pal[1:]:
        rgb = nes_rgb(c)
        k = min(range(1, 16), key=lambda i: sum((a - b) ** 2 for a, b in zip(gba_rgb(fam_cols[i]), rgb)))
        out.append(nearest_nes(gba_rgb(new_cols[k])))
    return out


def kmeans(pts, k, it=12):
    import random
    rnd = random.Random(1)
    if len(pts) <= k: return [tuple(p) for p in pts] + [pts[0]] * (k - len(pts))
    cs = sorted(set(pts), key=lambda p: sum(p))
    cs = [cs[int(i * (len(cs) - 1) / (k - 1))] for i in range(k)]
    for _ in range(it):
        acc = [[0, 0, 0, 0] for _ in range(k)]
        for p in pts:
            j = min(range(k), key=lambda j: sum((a - b) ** 2 for a, b in zip(p, cs[j])))
            a = acc[j]; a[0] += p[0]; a[1] += p[1]; a[2] += p[2]; a[3] += 1
        cs = [(a[0] // a[3], a[1] // a[3], a[2] // a[3]) if a[3] else cs[j] for j, a in enumerate(acc)]
    return cs


def nes_column(rgbs):
    """an NES hue column (1-12, or 0: greys) for weighted RGB colours"""
    import colorsys
    sx = sy = sw = 0.0; sat = 0.0
    for (r, g, b), w in rgbs:
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        import math
        sx += math.cos(2 * math.pi * h) * s * w; sy += math.sin(2 * math.pi * h) * s * w; sw += w; sat += s * w
    if sw == 0 or sat / sw < 0.18: return 0
    import math
    hue = (math.atan2(sy, sx) / (2 * math.pi)) % 1.0
    best = None
    for col in range(1, 13):                        # the column's hue: its $2x colour
        r, g, b = nes_rgb(0x20 | col)
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        d = min(abs(h - hue), 1 - abs(h - hue))
        if best is None or d < best[0]: best = (d, col)
    return best[1]


def boss_picture(G, rec, top=False):
    """a boss's GBA picture -> FF1's fiend picture: 64 x 64 of colour 0-3, a palette (0 / 1) per 16 x 16 block,
    two NES palettes, made as FF1's own fiends are: black behind, then a dark, a mid and a near-white colour
    (Lich: $16 $14 $30, Kary: $30 $28 $04). Both palettes share the dark and the light colour and differ only
    in the mid one (the boss's two main hues), so a block's palette changes one colour, not three. Each GBA
    colour goes to dark / mid / light by its brightness rank (thirds of the pixels); Dawn of Souls' black
    outlines stay black (colour 0, as FF1's fiends are outlined by the black behind them); reduced by each
    box's commonest shade, the outlines kept."""
    import colorsys, math
    tp, w, h, px, cols = gba.monster_picture(G, rec)
    W, H = 8 * w, 8 * h
    ys = [y for y in range(H) for x in range(W) if px[y][x]]
    top_y, bot = min(ys), max(ys)
    for c in range(1, 16):                          # the ground shadow (only in the lowest sixth): dropped
        cy = [y for y in range(H) for x in range(W) if px[y][x] == c]
        if cy and min(cy) > bot - (bot - top_y) // 6:
            px = [[0 if v == c else v for v in row] for row in px]
    xs = [x for y in range(H) for x in range(W) if px[y][x]]
    ys = [y for y in range(H) for x in range(W) if px[y][x]]
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    cnt = [0] * 16
    for y in range(y0, y1):
        for x in range(x0, x1): cnt[px[y][x]] += 1
    used = [c for c in range(1, 16) if cnt[c]]
    rgb = {c: gba_rgb(cols[c]) for c in used}
    lum = {c: (0.299 * rgb[c][0] + 0.587 * rgb[c][1] + 0.114 * rgb[c][2]) / 255 for c in used}
    hls = {c: colorsys.rgb_to_hls(*(v / 255 for v in rgb[c])) for c in used}
    black = {c for c in used if lum[c] < 0.10}      # (the outlines: black, colour 0)
    body = sorted((c for c in used if c not in black), key=lambda c: lum[c])
    tot = sum(cnt[c] for c in body); acc = 0; level = {}
    for c in body:                                  # brightness thirds of the pixels: 1 dark, 2 mid, 3 light
        acc += cnt[c] - cnt[c] / 2
        level[c] = 1 if acc < tot / 3 else (2 if acc < tot * 2 / 3 else 3)
        acc += cnt[c] / 2
    for c in black: level[c] = 0
    def mean_rgb(cs):
        n = sum(cnt[c] for c in cs) or 1
        return tuple(sum(rgb[c][i] * cnt[c] for c in cs) / n for i in range(3))
    dark = nes_by_hue(mean_rgb([c for c in body if level[c] == 1] or body))
    def hvec(c):
        hh, ll, ss = hls[c]
        return (math.cos(2 * math.pi * hh) * ss, math.sin(2 * math.pi * hh) * ss)
    sat_body = [c for c in body if level[c] >= 2] or body
    a = max(sat_body, key=lambda c: cnt[c])           # the two main hues (mid and light colours)
    b = max(sat_body, key=lambda c: cnt[c] * sum((u - v) ** 2 for u, v in zip(hvec(c), hvec(a))))
    fam = {c: (0 if sum((u - v) ** 2 for u, v in zip(hvec(c), hvec(a))) <=
                   sum((u - v) ** 2 for u, v in zip(hvec(c), hvec(b))) else 1) for c in body}
    mid, light = [], []
    for k in (0, 1):                                # each hue: its own mid and light (the dark shared)
        ms = [c for c in body if fam[c] == k and level[c] == 2] or [c for c in body if level[c] == 2] or body
        ls = [c for c in body if fam[c] == k and level[c] == 3] or [c for c in body if level[c] == 3] or body
        m_, l_ = nes_by_hue(mean_rgb(ms)), nes_by_hue(mean_rgb(ls))
        if l_ == m_: l_ = min(0x30 | (m_ & 0x0F), 0x3C) if (m_ & 0x0F) not in (0, 0x0D) else 0x30
        if m_ == dark: m_ = (m_ + 0x10) & 0x3F
        mid.append(m_); light.append(l_)
    pals = [[0x0F, dark, mid[0], light[0]], [0x0F, dark, mid[1], light[1]]]
    s = min(64 / (x1 - x0), 64 / (y1 - y0), 1.0)
    nw, nh = max(1, round((x1 - x0) * s)), max(1, round((y1 - y0) * s))
    ox, oy = (64 - nw) // 2, (0 if top else 64 - nh)
    out = [[0] * 64 for _ in range(64)]
    fpx = [[None] * 64 for _ in range(64)]
    for Y in range(nh):
        for X in range(nw):
            sx0, sx1 = x0 + int(X / s), x0 + max(int(X / s) + 1, int((X + 1) / s))
            sy0, sy1 = y0 + int(Y / s), y0 + max(int(Y / s) + 1, int((Y + 1) / s))
            box = [px[yy][xx] for yy in range(sy0, min(sy1, y1)) for xx in range(sx0, min(sx1, x1))]
            solid = [v for v in box if v]
            if len(solid) * 2 < len(box): continue
            lv = {}
            for v in solid: lv[level[v]] = lv.get(level[v], 0) + 1
            L = 0 if lv.get(0, 0) * 3 >= len(solid) else max((k for k in lv if k), key=lambda k: lv[k])
            out[oy + Y][ox + X] = L
            mc = [v for v in solid if level.get(v, 0) >= 2]
            if mc: fpx[oy + Y][ox + X] = fam[max(set(mc), key=mc.count)]
    blk = [[0] * 4 for _ in range(4)]
    for by in range(4):
        for bx in range(4):
            votes = [fpx[y][x] for y in range(16 * by, 16 * by + 16) for x in range(16 * bx, 16 * bx + 16)
                     if fpx[y][x] is not None]
            blk[by][bx] = max((0, 1), key=votes.count) if votes else 0
    return out, blk, pals


def gb_tile_px(rows):
    """8 rows of 8 colour indices -> GB 2bpp"""
    b = bytearray()
    for r in rows:
        lo = hi = 0
        for v in r:
            lo = lo << 1 | (v & 1); hi = hi << 1 | (v >> 1)
        b += bytes([lo, hi])
    return bytes(b)


def tile_px(t):
    return [[(t[2 * y] >> (7 - x) & 1) | (t[2 * y + 1] >> (7 - x) & 1) << 1 for x in range(8)] for y in range(8)]


def sil_page(page):
    """silhouettes of a page's four graphics (battle.sil_banks' rule, from GB tiles)"""
    out = bytearray(page)
    for t0, n in ((0x12, 4), (0x22, 4), (0x32, 6), (0x56, 6)):
        W = 8 * n
        m = [[0] * W for _ in range(W)]
        for r in range(n):
            for c in range(n):
                t = t0 + r * n + c
                p = tile_px(page[16 * t:16 * t + 16])
                for y in range(8):
                    for x in range(8): m[8 * r + y][8 * c + x] = 1 if p[y][x] else 0
        o = [[0] * W for _ in range(W)]
        for y in range(W):
            for x in range(W):
                if not m[y][x]:
                    o[y][x] = int(any(0 <= y + dy < W and 0 <= x + dx < W and m[y + dy][x + dx]
                                      for dy in (-1, 0, 1) for dx in (-1, 0, 1)))
        for r in range(n):
            for c in range(n):
                t = t0 + r * n + c
                rows = [[(o[8 * r + y][8 * c + x]) | (m[8 * r + y][8 * c + x] << 1) for x in range(8)] for y in range(8)]
                out[16 * t:16 * t + 16] = gb_tile_px(rows)
    return bytes(out)


# Dawn of Souls' monsters by their English names (the official Dawn of Souls names): the 50 new ones
# (GBA records 145-194), the 17 bonus bosses (128-144) and FF1's met in the shrines
NEW_MONSTERS = ['Devil Wizard', 'Abyss Worm', 'Elm Gigas', 'Flare Gigas', 'Unicorn', 'Yellow Ogre', 'Mad Ogre',
                'Mage Chimera', 'Yellow Dragon', 'Holy Dragon', 'Mythril Golem', 'Killer Shark', 'Death Manticore',
                'Blood Tiger', 'Dark Eye', 'Bloody Eye', 'Flood Gigas', 'Poison Eagle', 'Black Goblin', 'Knocker',
                'Desertpede', 'Gloom Widow', 'Duel Knight', 'Squidraken', 'Pharaoh', 'Bonesnatch', 'Silver Dragon',
                'Black Dragon', 'Blue Troll', 'Earth Troll', 'Poison Naga', 'Earth Plant', 'Yamatano Orochi',
                'Dark Elemental', 'Devil Hound', 'Sekhret', 'Catoblepas', 'Hundlegs', 'Undergrounder',
                'Death Elemental', 'Wild Nakk', 'Dark Wolf', 'Rock Gargoyle', 'Sahagin Queen', 'Reaper', 'Python',
                'Skuldier', 'Red Flan', 'Prototype', 'Revenant']
BOSSES = ['Echidna', 'Cerberus', 'Ahriman', 'Two-Headed Dragon', 'Scarmiglione', 'Scarmiglione ', 'Cagnazzo',
          'Barbariccia', 'Rubicante', 'Gilgamesh', 'Omega', 'Shinryu', 'Atomos', 'Typhon', 'Orthros',
          'Phantom Train', 'Death Gaze']
MON_REC = dict({n: 145 + i for i, n in enumerate(NEW_MONSTERS)}, **{n: 128 + i for i, n in enumerate(BOSSES)},
               **{'White Dragon': 66, 'Red Dragon': 67, 'Dragon Zombie': 68, 'Green Dragon': 106,
                  'Blue Dragon': 107})
SECOND_FORM = {'Scarmiglione': 'Scarmiglione '}       # (fought right after the first)
L_SPELL = lambda lv, k: 8 * (lv - 1) + k                # FF1's spell number: level, slot (0-3 white, 4-7 black)
S_LIT3, S_RUB, S_ICE3, S_FIR3, S_BANE, S_STUN = 44, 45, 52, 36, 37, 47
S_LIT2, S_ICE2, S_FIR2, S_SLO2, S_FAST, S_STOP, S_ZAP, S_XXXX = 22, 31, 20, 39, 29, 61, 62, 63
A_POISON, A_TOXIC, A_INFERNO, A_CREMATE, A_TORNADO, A_SWIRL, A_NUCLEAR, A_INK, A_STINGER, A_SNORT, A_GAZE, \
    A_FLASH = 16, 18, 12, 13, 25, 24, 20, 21, 22, 19, 3, 4
# the bonus bosses' attacks: their Dawn of Souls abilities (FINAL FANTASY wiki) as FF1's nearest spell / enemy
# ability (the remake's own scripts are not FF1 records)
BOSS_AI.update({
    'Scarmiglione': (0x30, 0x30, [S_LIT3, S_BANE, S_LIT2, S_ICE2] * 2, [A_POISON] * 4),
    'Scarmiglione ': (0x30, 0x40, [S_LIT3, S_BANE, S_STUN, S_LIT3] * 2, [A_TOXIC, A_POISON] * 2),
    'Cagnazzo': (0x40, 0x30, [S_ICE3, S_ICE2, S_ICE3, S_SLO2] * 2, [A_BLIZZARD, A_INK] * 2),
    'Barbariccia': (0x40, 0x40, [S_LIT3, S_ZAP, S_LIT3, S_LIT2] * 2, [A_TORNADO, A_SWIRL] * 2),
    'Rubicante': (0x40, 0x40, [S_FIR3, S_FIR3, S_FIR2, S_FIR3] * 2, [A_INFERNO, A_CREMATE] * 2),
    'Gilgamesh': (0x20, 0x20, [S_FAST, S_FAST, S_FIR2, S_ICE2] * 2, [A_CRACK] * 4),
    'Atomos': (0x40, 0x30, [S_QUAKE, S_SLO2, S_STOP, S_QUAKE] * 2, [A_SWIRL] * 4),
    'Omega': (0x40, 0x40, [S_FLARE, S_LIT3, S_ICE3, S_FIR3] * 2, [A_NUCLEAR, A_FLASH] * 2),
    'Shinryu': (0x50, 0x40, [S_FLARE, S_ICE3, S_FIR3, S_LIT3] * 2, [A_TORNADO, A_BLIZZARD, A_INFERNO, A_THUNDER]),
    'Typhon': (0x00, 0x50, [], [A_SNORT, A_TORNADO] * 2),
    'Orthros': (0x30, 0x40, [S_ICE2, S_ICE3] * 4, [A_INK, A_STINGER] * 2),
    'Phantom Train': (0x30, 0x40, [S_RUB, S_BANE, S_RUB, S_STUN] * 2, [A_TOXIC, A_POISON] * 2),
    'Death Gaze': (0x40, 0x40, [S_RUB, S_XXXX, S_ICE3, S_LIT3] * 2, [A_GAZE, A_TORNADO] * 2)})
PG_BANKS = {'EG': (119, 121, 123, 126)}             # (data, graphics (2), silhouettes (2), Super Game Boy)


def gba_spell(s):
    """a Dawn of Souls spell number (white 1-32, black 33-64: level by level, four each) -> FF1's (or None)"""
    if 1 <= s <= 0x20: return L_SPELL((s - 1) // 4 + 1, (s - 1) % 4)
    if 0x21 <= s <= 0x40: return L_SPELL((s - 0x21) // 4 + 1, 4 + (s - 0x21) % 4)
    return None


def gba_ai(G, k):
    """Dawn of Souls' enemy AI record k (FF1's 16-byte format) in FF1's numbers: its spells mapped, abilities past
    FF1's 26 dropped"""
    g = G.d[0x2253DC + 16 * k:0x2253DC + 16 * k + 16]
    sp = [gba_spell(x) for x in g[2:10] if x != 0xFF]
    sp = [x for x in sp if x is not None]
    ab = [x for x in g[11:15] if x != 0xFF and x < 26]
    mc = g[0] if sp else 0
    ac = g[1] if ab else 0
    return bytes([mc, ac]) + bytes((sp + [0xFF] * 8)[:8]) + b'\xff' + bytes((ab + [0xFF] * 4)[:4]) + b'\xff'


def plan_formations(s, bands=(0, 1, 2, 3)):
    """the shrine's formations (one per distinct monster group in its tables) and domains: (forms [groups],
    domains {(area index, band): 8 formation numbers}, areas [names])"""
    import shrines
    sh = shrines.SHRINES[s]
    enc = shrines.ENCOUNTERS[sh['key']]
    areas = sorted({a for _, _, _, a in sh['floors'] if a})
    forms, fid = [], {}
    tabs = {}
    for ai, a in enumerate(areas):
        bands_ = enc.get(a) or [[(1, [(n, 1, 1)]) for n in b] for b in enc[a + ' (fixed)']]
        for bi, lst in enumerate(bands_):
            if bi not in bands: continue
            out = []
            for rate, grp in lst:
                key = tuple(grp)
                if key not in fid:
                    fid[key] = len(forms); forms.append(list(grp))
                out.append((fid[key], rate))
            tabs[(ai, bi)] = out
    return forms, tabs, areas


def alloc_pages(forms, size, n_pages):
    """pages (2 small + 2 large graphics each) so that each formation's monsters share one: [page sets], the
    page of each formation"""
    pages = []                                      # [{'s': [names], 'l': [names]}]
    fpage = []
    for f in sorted(range(len(forms)), key=lambda f: -len({n for n, _, _ in forms[f]})):
        need = {n for n, _, _ in forms[f]}
        ns = [n for n in need if not size[n]]; nl = [n for n in need if size[n]]
        best = None
        for pi, p in enumerate(pages):
            ms = [n for n in ns if n not in p['s']]; ml = [n for n in nl if n not in p['l']]
            if len(p['s']) + len(ms) <= 2 and len(p['l']) + len(ml) <= 2:
                cost = len(ms) + len(ml)
                if best is None or cost < best[0]: best = (cost, pi)
        if best is None:
            pages.append({'s': [], 'l': []}); best = (0, len(pages) - 1)
        p = pages[best[1]]
        for n in ns:
            if n not in p['s']: p['s'].append(n)
        for n in nl:
            if n not in p['l']: p['l'].append(n)
        fpage.append((f, best[1]))
    assert len(pages) <= n_pages, 'monster pages: %d > %d' % (len(pages), n_pages)
    return pages, dict(fpage)


def build(rom, s=0, G=None, banks=None, part=0):
    """shrine s's battle set: {bank: bytes} for its data, graphics, silhouette and Super Game Boy banks; the
    domains (formation lists of 8) by (area index, band); the formation of each boss"""
    import postgame, shrines
    sh = shrines.SHRINES[s]
    G = G or gba.Gba(postgame.GBA_PATH)
    PGB_DATA, PGB_CHR, PGB_SIL, PGB_SGB = banks or PG_BANKS[sh['key']]
    base = bytearray(battle.data_bank(rom))
    ff1chr = battle.chr_banks(rom)
    def ff1_page(p):
        b = ff1chr[battle.ENEMY_CHR + (p >> 3)]
        return b[0x800 * (p & 7):0x800 * (p & 7) + 0x800]
    fam_of = {}
    for e in range(128):
        fam_of.setdefault(gba.monster_picture(G, e)[0], e)
    fg = ff1_graphics(rom)
    set_bands, set_bosses = sh['sets'][part]
    forms_g, tabs, areas = plan_formations(s, set_bands)
    names = sorted({n for f in forms_g for n, _, _ in f}, key=lambda n: (MON_REC[n], n))
    size, src = {}, {}
    for n in names:                                 # each monster: FF1's family picture (its own for FF1's)
        rec = MON_REC[n]
        tp, w, h, px, cols = gba.monster_picture(G, rec)
        fam = rec if rec < 128 else fam_of[tp]
        fpage, fgr, fpal = fg[fam]
        size[n] = fgr & 1
        pal = fpal if rec < 128 else recolour(fpal, gba.monster_picture(G, fam)[4], cols)
        src[n] = (fpage, fgr, pal)
    bosses_n = [b for k, (b, _) in enumerate(sh['bosses']) if k in set_bosses]
    bosses_n += [SECOND_FORM[b] for b in bosses_n if b in SECOND_FORM]
    def trim(grp):                                  # (FF1: two small and two large pictures a page)
        out, ns, nl = [], 0, 0
        for e in grp:
            if size[e[0]]:
                if nl < 2 or e[0] in [x[0] for x in out]: out.append(e); nl += e[0] not in [x[0] for x in out[:-1]]
            elif ns < 2 or e[0] in [x[0] for x in out]: out.append(e); ns += e[0] not in [x[0] for x in out[:-1]]
        return out
    forms_g = [trim(f) for f in forms_g]
    pages_m, fpage = alloc_pages(forms_g, size, 16 - len(bosses_n))
    pages = [bytearray(0x800) for _ in range(16)]
    pals, enemies, eid, pal_of, slot_of = [], [], {}, {}, {}
    used_ai = set()
    for n in names:
        eid[n] = len(enemies)
        r = stats(G, MON_REC[n])
        enemies.append([n, r])
        pal_of[n] = len(pals); pals.append(src[n][2])
        if MON_REC[n] < 128: used_ai.add(r[7])
    for pi, p in enumerate(pages_m):                # the pages: each monster's FF1 picture in its slot
        for kind, lst in (('s', p['s']), ('l', p['l'])):
            for j, n in enumerate(lst):
                g = (0, 2)[j] if kind == 's' else (1, 3)[j]
                fpage_, fgr, _ = src[n]
                t0, cnt = SLOT_T0[fgr], SLOT_N[fgr]
                pages[pi][16 * SLOT_T0[g]:16 * (SLOT_T0[g] + cnt)] = ff1_page(fpage_)[16 * t0:16 * (t0 + cnt)]
                slot_of[(pi, n)] = g
    ai = bytearray(base[0x1600:0x1600 + 48 * 16])   # (AI: FF1's records in use kept; Dawn of Souls' new ones
    free_ai = [k for k in range(44) if k not in used_ai]   #   in the slots no monster here uses)
    ai_map = {}
    for e in enemies:
        if MON_REC[e[0]] >= 128 and e[1][7] != 0xFF:
            k = e[1][7]
            if k >= 44:
                if k not in ai_map:
                    ai_map[k] = free_ai.pop(0)
                    ai[16 * ai_map[k]:16 * ai_map[k] + 16] = gba_ai(G, k)
                e[1][7] = ai_map[k]
            elif k not in used_ai and k not in ai_map:
                ai_map[k] = k; used_ai.add(k)
    first_boss_page = len(pages_m)
    bosses = []
    for k, name in enumerate(bosses_n):
        rec = MON_REC[name]
        pic, blk, bp = boss_picture(G, rec, top=name in HANGING)
        p = first_boss_page + k
        tsa = bytearray(64); t = 0x12
        for cy in range(8):
            for cx in range(8):
                rows = [pic[8 * cy + y][8 * cx:8 * cx + 8] for y in range(8)]
                if not any(any(r) for r in rows): continue
                pages[p][16 * t:16 * t + 16] = gb_tile_px(rows)
                tsa[8 * cy + cx] = t; t += 1
        attr = bytearray(16)
        r0 = 0 if name in HANGING else 2
        for by in range(4):
            for bx in range(4):
                v = 1 + blk[by][bx]
                X, Y = 4 + 2 * bx, 6 + r0 + 2 * by
                ai_ = (Y // 4 - 1) * 4 + X // 4
                sh_ = (Y & 2) * 2 + (X & 2)
                attr[ai_] |= v << sh_
        r = stats(G, rec)
        r[6] = 0xFF
        r[7] = (44 + k) if BOSS_AI.get(name) and k < 4 else 0xFF
        if k >= 4 and BOSS_AI.get(name):            # (a fifth picture: the second form; its AI in a free slot)
            slot = free_ai.pop(0); r[7] = slot
            mc, ac, sp, ab = BOSS_AI[name]
            ai[16 * slot:16 * slot + 16] = (bytes([mc, ac]) + bytes((sp + [0xFF] * 8)[:8]) + b'\xff' +
                                            bytes((ab + [0xFF] * 4)[:4]) + b'\xff')
        enemies.append([name.strip(), r])
        pals += bp
        bosses.append((name, len(enemies) - 1, p, k, len(pals) - 2, tsa + attr, pic))
    forms, fid = [], {}
    for f, grp in enumerate(forms_g):
        pi = fpage[f]
        fd = bytearray(16)
        smalls = [n for n, _, _ in grp if not size[n]]; larges = [n for n, _, _ in grp if size[n]]
        ty = 2 if smalls and larges else (1 if larges else 0)
        fd[0] = ty << 4 | pi
        pl = []
        for gi, (n, lo, hi) in enumerate(grp[:4]):
            fd[1] |= slot_of[(pi, n)] << (2 * gi)
            fd[2 + gi] = eid[n]
            fd[6 + gi] = min(lo, 15) << 4 | min(hi, 15)
            pn = pal_of[n]
            if pn not in pl and len(pl) < 2: pl.append(pn)
            if pn in pl: b = pl.index(pn)
            else:                                   # (a third colour set: the nearer of the two)
                b = min((0, 1), key=lambda j: sum(abs(data.lum(x) - data.lum(y)) for x, y in
                                                  zip(pals[pn][1:], pals[pl[j]][1:])))
            fd[13] |= b << (7 - gi)
        fd[10] = pl[0]; fd[11] = pl[1] if len(pl) > 1 else pl[0]
        fd[12] = 4
        fd[14], fd[15] = fd[6], fd[7]
        fid[f] = len(forms)
        forms.append(fd)
    boss_form0 = len(forms)
    for name, e, p, k, pi, _, _ in bosses:
        fd = bytearray(16)
        fd[0] = 0x30 | p
        fd[1] = k
        fd[2:6] = bytes([e, 0, 0, 0])
        fd[6] = 0x11
        fd[10], fd[11] = pi, pi + 1
        fd[13] = 1                                   # (no running)
        forms.append(fd)
    assert len(forms) <= 128 and len(enemies) <= 51, (len(forms), len(enemies))
    wt = base[0x3F00:0x3F40]                         # the domains: 8 slots weighted by FF1's lut_FormationWeight
    share = [sum(1 for x in wt if x == q) for q in range(8)]
    domains = {}
    for key, lst in tabs.items():
        slots = [None] * 8
        want = {}
        for f, rate in lst: want[f] = want.get(f, 0) + rate
        got = {f: 0 for f in want}
        for q in sorted(range(8), key=lambda q: -share[q]):
            f = max(want, key=lambda f: want[f] - got[f])
            slots[q] = fid[f]; got[f] += share[q]
        domains[key] = bytes(slots)
    def put(a, d): base[a - 0x4000:a - 0x4000 + len(d)] = d
    put(0x4000, b''.join(bytes(f) for f in forms).ljust(128 * 16, b'\0'))
    put(0x4C00, b''.join(bytes(r) for _, r in enemies).ljust(51 * 20, b'\0'))
    for name, e, p, k, pi, _, _ in bosses:
        a = BOSS_AI.get(name)
        if not a or k >= 4: continue
        mc, ac, sp, ab = a
        ai[16 * (44 + k):16 * (45 + k)] = (bytes([mc, ac]) + bytes((sp + [0xFF] * 8)[:8]) + b'\xff' +
                                           bytes((ab + [0xFF] * 4)[:4]) + b'\xff')
    put(0x5600, bytes(ai))
    assert len(pals) <= 64, len(pals)
    put(0x5C80, b''.join(bytes(p) for p in pals).ljust(256, b'\0'))
    shd = bytearray()                                # DMG shades per formation (battle.dmg_shades)
    for fd in forms:
        pa, pb = pals[fd[10]], pals[fd[11]]
        msh = data.map_shades([[0x0F, 0x00, 0x0F, 0x30], pa, pb, [0x0F, 0x00, 0x0F, 0x30]])
        sa = [msh[c] for c in pa]; sb = [msh[c] for c in pb]
        sa[0] = sb[0] = 3
        shd += bytes(sa) + bytes(sb)
    put(0x5E00, bytes(shd).ljust(128 * 8, b'\0'))
    nms = [battle.enc(n) for n, _ in enemies] + [b''] * (128 - len(enemies))
    nt = battle.strtab(0x6200, nms)
    assert len(nt) <= 0x600
    put(0x6200, nt)
    hands = bytearray(10)
    for name, e, p, k, pi, tsa, pic in bosses:
        if k >= 4:                                   # (the second form: its first form's picture slot)
            continue
        put(0x6A00 + 0x50 * k, tsa)
        pts = [(x, y) for y in range(64) for x in range(64) if pic[y][x]]
        ys = [y for _, y in pts]; mid = (min(ys) + max(ys)) // 2
        left = min(x for x, y in pts if mid - 6 <= y <= mid + 6)
        hands[2 * k:2 * k + 2] = bytes([left, mid - (16 if name in HANGING else 0)])
    hands[8:10] = base[0x3FE8:0x3FEA]
    put(0x7FE0, bytes(hands))
    for kd, dom in domains.items():                  # the domains: $5000 + 32 area + 8 band (pg.s pg_dom)
        put(0x5000 + 32 * kd[0] + 8 * kd[1], dom)
    chr0 = b''.join(bytes(pg) for pg in pages[:8]); chr1 = b''.join(bytes(pg) for pg in pages[8:])
    sil0 = b''.join(sil_page(bytes(pg)) for pg in pages[:8]); sil1 = b''.join(sil_page(bytes(pg)) for pg in pages[8:])
    out = {PGB_DATA: bytes(base), PGB_CHR: chr0, PGB_CHR + 1: chr1, PGB_SIL: sil0, PGB_SIL + 1: sil1}
    import sgb
    out[PGB_SGB] = sgb.bank(rom, [(pals[fd[10]], pals[fd[11]]) for fd in forms])
    return dict(banks=out, domains=domains, areas=areas, boss_form0=boss_form0, boss_names=bosses_n,
                names=[n for n, _ in enemies], hanging=[n in HANGING for n in bosses_n])
