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


def boss_picture(G, rec):
    """a boss's GBA picture -> 64 x 64 indices 0-3 per pixel, palette per 16 x 16 block (0 / 1),
    two NES palettes [0x0F, c1, c2, c3] (colours sorted dark to bright)"""
    from PIL import Image
    tp, w, h, px, cols = gba.monster_picture(G, rec)
    W, H = 8 * w, 8 * h
    ys = [y for y in range(H) for x in range(W) if px[y][x]]
    top, bot = min(ys), max(ys)
    for c in range(1, 16):                          # the ground shadow (a colour only in the
        cy = [y for y in range(H) for x in range(W) if px[y][x] == c]   #   picture's lowest
        if cy and min(cy) > bot - (bot - top) // 6:                      #   sixth): dropped
            px = [[0 if v == c else v for v in row] for row in px]
    xs = [x for y in range(H) for x in range(W) if px[y][x]]
    ys = [y for y in range(H) for x in range(W) if px[y][x]]
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    im = Image.new('RGBA', (x1 - x0, y1 - y0), (0, 0, 0, 0))
    for y in range(y0, y1):
        for x in range(x0, x1):
            if px[y][x]: im.putpixel((x - x0, y - y0), gba_rgb(cols[px[y][x]]) + (255,))
    s = min(64 / im.width, 64 / im.height, 1.0)
    nw, nh = max(1, round(im.width * s)), max(1, round(im.height * s))
    im = im.resize((nw, nh), Image.LANCZOS)
    can = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    can.paste(im, ((64 - nw) // 2, 64 - nh))
    pix = [[can.getpixel((x, y)) for x in range(64)] for y in range(64)]
    solid = [(x, y) for y in range(64) for x in range(64) if pix[y][x][3] >= 128 and sum(pix[y][x][:3]) > 60]
    pts = [pix[y][x][:3] for x, y in solid]
    pa = kmeans(pts, 3)
    err = lambda p, cs: min(sum((a - b) ** 2 for a, b in zip(p, c)) for c in cs)
    worst = sorted(pts, key=lambda p: -err(p, pa))[:max(3, len(pts) // 3)]
    pb = kmeans(worst, 3)
    pals = []
    for cs in (pa, pb):
        ns = []
        for c in sorted(cs, key=sum):
            n = nearest_nes(c)
            ns.append(n)
        pals.append([0x0F] + ns)
    prgb = [[nes_rgb(c) for c in p] for p in pals]
    out = [[0] * 64 for _ in range(64)]
    blk = [[0] * 4 for _ in range(4)]
    for by in range(4):
        for bx in range(4):
            best = None
            for k in (0, 1):
                e = 0
                for y in range(16 * by, 16 * by + 16):
                    for x in range(16 * bx, 16 * bx + 16):
                        p = pix[y][x]
                        if p[3] < 128 or sum(p[:3]) <= 60: continue
                        e += min(sum((a - b) ** 2 for a, b in zip(p[:3], prgb[k][i])) for i in (1, 2, 3))
                if best is None or e < best[0]: best = (e, k)
            blk[by][bx] = best[1]
            k = best[1]
            for y in range(16 * by, 16 * by + 16):
                for x in range(16 * bx, 16 * bx + 16):
                    p = pix[y][x]
                    if p[3] < 128 or sum(p[:3]) <= 60: continue
                    out[y][x] = min((1, 2, 3), key=lambda i: sum((a - b) ** 2 for a, b in zip(p[:3], prgb[k][i])))
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


def build(rom, G=None):
    """Earthgift's battle set: {bank: bytes} for its data, graphics and silhouette banks; the domains
    (formation lists of 8) per floor kind; the formation of each boss"""
    G = G or gba.Gba()
    base = bytearray(battle.data_bank(rom))
    ff1chr = battle.chr_banks(rom)
    def ff1_page(p):
        b = ff1chr[battle.ENEMY_CHR + (p >> 3)]
        return b[0x800 * (p & 7):0x800 * (p & 7) + 0x800]
    fam_of = {}
    for e in range(128):
        fam_of.setdefault(gba.monster_picture(G, e)[0], e)
    fg = ff1_graphics(rom)
    pages = [bytearray(0x800) for _ in range(16)]
    pals = []                                       # the set's palettes (BTL_PALS)
    enemies = []                                    # (name, record bytes)
    mon = {}                                        # name -> (enemy id, page, graphic, palette index, large)
    small_slots = [(p, g) for p in range(3) for g in (0, 2)]
    large_slots = [(p, g) for p in range(3) for g in (1, 3)]
    for name, rec in EG_MONSTERS:
        tp, w, h, px, cols = gba.monster_picture(G, rec)
        fam = fam_of[tp]
        fpage, fgr, fpal = fg[fam]
        large = fgr & 1
        p, g = (large_slots if large else small_slots).pop(0)
        src = ff1_page(fpage)
        t0, n = SLOT_T0[fgr], SLOT_N[fgr]
        pages[p][16 * SLOT_T0[g]:16 * (SLOT_T0[g] + n)] = src[16 * t0:16 * (t0 + n)]
        famcols = gba.monster_picture(G, fam)[4]
        pals.append(recolour(fpal, famcols, cols))
        mon[name] = (len(enemies), p, g, len(pals) - 1, large)
        enemies.append((name, stats(G, rec)))
    bosses = []
    for k, (name, rec) in enumerate(EG_BOSSES):
        pic, blk, bp = boss_picture(G, rec)
        p = 3 + k
        tsa = bytearray(64); t = 0x12
        for cy in range(8):
            for cx in range(8):
                rows = [pic[8 * cy + y][8 * cx:8 * cx + 8] for y in range(8)]
                if not any(any(r) for r in rows): continue
                pages[p][16 * t:16 * t + 16] = gb_tile_px(rows)
                tsa[8 * cy + cx] = t; t += 1
        attr = bytearray(16)                         # FF1's attribute grid (4 x 4 bytes over the
        for by in range(4):                          #   fiend's 16 x 16 blocks: the fiend's first
            for bx in range(4):                      #   cell is NES column 4, row 8)
                v = 1 + blk[by][bx]                  # (BG palette 1 = palette A, 2 = palette B)
                X, Y = 4 + 2 * bx, 8 + 2 * by        # NES tile column / row of the block
                ai = (Y // 4 - 1) * 4 + X // 4
                sh = (Y & 2) * 2 + (X & 2)
                attr[ai] |= v << sh
        r = stats(G, rec)
        ai_rec = BOSS_AI[name]
        r[6] = 0xFF
        r[7] = (44 + k) if ai_rec else 0xFF
        enemies.append((name, r))
        pals += bp
        bosses.append((name, len(enemies) - 1, p, k, len(pals) - 2, tsa + attr, pic))
    # formations: the monsters', then the bosses'
    forms = []
    fid = {}
    for name, (e, p, g, pi, large) in mon.items():
        fd = bytearray(16)
        fd[0] = (0x10 if large else 0x00) | p
        fd[1] = g
        fd[2:6] = bytes([e, 0, 0, 0])
        fd[10] = fd[11] = pi
        fd[12] = 4
        fid[name] = len(forms)
        forms.append(fd)
    for name, e, p, k, pi, _, _ in bosses:
        fd = bytearray(16)
        fd[0] = 0x30 | p
        fd[1] = k
        fd[2:6] = bytes([e, 0, 0, 0])
        fd[6] = 0x11
        fd[10], fd[11] = pi, pi + 1
        fd[13] = 1                                   # (no running)
        fid[name] = len(forms)
        forms.append(fd)
    for kind, lst in EG_ENC.items():                 # quantities set per formation (one each)
        for name, lo, hi, rate in lst:
            fd = forms[fid[name]]
            if fd[6] == 0: fd[6] = lo << 4 | hi; fd[14] = fd[6]
    # the domains: 8 slots weighted by FF1's lut_FormationWeight (bank's $7F00, 64 entries)
    wt = base[0x3F00:0x3F40]
    share = [sum(1 for x in wt if x == s) for s in range(8)]
    domains = {}
    for kind, lst in EG_ENC.items():
        slots = [None] * 8
        want = {name: rate for name, lo, hi, rate in lst}
        got = {name: 0 for name in want}
        for s in sorted(range(8), key=lambda s: -share[s]):
            name = max(want, key=lambda n: want[n] - got[n])
            slots[s] = fid[name]; got[name] += share[s]
        domains[kind] = bytes(slots)
    # the data bank
    def put(a, d): base[a - 0x4000:a - 0x4000 + len(d)] = d
    put(0x4000, b''.join(bytes(f) for f in forms).ljust(128 * 16, b'\0'))
    put(0x4C00, b''.join(bytes(r) for _, r in enemies).ljust(128 * 20, b'\0'))
    ai = bytearray(base[0x1600:0x1600 + 48 * 16])
    for name, e, p, k, pi, _, _ in bosses:
        a = BOSS_AI[name]
        if not a: continue
        mc, ac, sp, ab = a
        rec = bytes([mc, ac]) + bytes((sp + [0xFF] * 8)[:8]) + b'\xff' + bytes((ab + [0xFF] * 4)[:4]) + b'\xff'
        ai[16 * (44 + k):16 * (45 + k)] = rec
    put(0x5600, bytes(ai))
    assert len(pals) <= 64
    put(0x5C80, b''.join(bytes(p) for p in pals).ljust(256, b'\0'))
    sh = bytearray()                                 # DMG shades per formation (battle.dmg_shades)
    for fd in forms:
        pa, pb = pals[fd[10]], pals[fd[11]]
        msh = data.map_shades([[0x0F, 0x00, 0x0F, 0x30], pa, pb, [0x0F, 0x00, 0x0F, 0x30]])
        sa = [msh[c] for c in pa]; sb = [msh[c] for c in pb]
        sa[0] = sb[0] = 3
        sh += bytes(sa) + bytes(sb)
    put(0x5E00, bytes(sh).ljust(128 * 8, b'\0'))
    names = [battle.enc(n) for n, _ in enemies] + [b''] * (128 - len(enemies))
    nt = battle.strtab(0x6200, names)
    assert len(nt) <= 0x600
    put(0x6200, nt)
    hands = bytearray(10)
    for name, e, p, k, pi, tsa, pic in bosses:
        put(0x6A00 + 0x50 * k, tsa)
        pts = [(x, y) for y in range(64) for x in range(64) if pic[y][x]]
        ys = [y for _, y in pts]; mid = (min(ys) + max(ys)) // 2
        left = min(x for x, y in pts if mid - 6 <= y <= mid + 6)
        hands[2 * k:2 * k + 2] = bytes([left, mid])
    hands[8:10] = base[0x3FE8:0x3FEA]
    put(0x7FE0, bytes(hands))
    chr0 = b''.join(bytes(pg) for pg in pages[:8]); chr1 = b''.join(bytes(pg) for pg in pages[8:])
    sil0 = b''.join(sil_page(bytes(pg)) for pg in pages[:8]); sil1 = b''.join(sil_page(bytes(pg)) for pg in pages[8:])
    banks = {PGB_DATA: bytes(base), PGB_CHR: chr0, PGB_CHR + 1: chr1, PGB_SIL: sil0, PGB_SIL + 1: sil1}
    import sgb                                       # (the Super Game Boy's battle colours: a copy of
    banks[PGB_SGB] = sgb.bank(rom, [(pals[fd[10]], pals[fd[11]]) for fd in forms])   #   its bank)
    return dict(banks=banks, domains=domains, boss_forms=[fid[n] for n, *_ in bosses],
                forms=fid, names=[n for n, _ in enemies])
