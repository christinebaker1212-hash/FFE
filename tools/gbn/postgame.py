"""FF1 native build: the post-game, Dawn of Souls' Soul of Chaos dungeons (docs/ff1-postgame-design.md),
made at build time from the user's Dawn of Souls ROM (gba.py) and FF1's own tiles (the user's NES ROM).
Nothing from either ROM is in the repository: this file holds the rules that turn a Dawn of Souls floor
into an FF1 map, and the list of floors.

Floors become standard maps with ids PG_MAP0 and up, one ROM bank each (bank = map + 64, above FF1's
128 banks), with the map bank's usual layout (build.py data_banks) plus the post-game's own bytes:
  $5061 the song, $5062 / $5063 the arrival x / y, $5064 the encounter rate, $5068 8 formations
  (the floor's encounter domain), $5070 the boss objects' boss numbers (15 slots)

Conversion (Dawn of Souls draws walls as faces above the floor; FF1 draws one-tile outlines):
- walkable chips -> FF1's corridor floor; blocked chips next to the floor -> FF1's wall pieces; the rest
  the black void;
- rooms (chips with the room bit) -> FF1 rooms: a rectangle of room floor with FF1's room border, the
  door in the corridor wall below the border, black from outside until the door is entered;
- the stairs chip -> FF1's stairs down; chests on the dead ends (Dawn of Souls places them by script).
"""
import os, sys
from collections import deque
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import data, gba

PG_MAP0 = 64                    # post-game map ids from here (FF1's are 0-60)
PG_TS_CAVE = 17                 # ROM bank of the post-game cave tileset (FF1's Earth Cave tiles;
                                #   tileset number 9: FF1's music table by tileset has room there)
SONG_CAVE, SONG_BOSS = 0x0D, 0x0D

# FF1's Earth Cave metatiles (tileset 2)
FLOOR, VOID, ROOMFL = 0x41, 0x38, 0x2E
WL, WR, WH, C_TL, C_TR = 0x32, 0x33, 0x30, 0x34, 0x35
B_TL, B_T, B_TR, B_L, B_R, B_BL, B_B, B_BR = 0x00, 0x01, 0x02, 0x03, 0x05, 0x06, 0x07, 0x08
DOOR, BELOW_DOOR, STAIRS_DN, STAIRS_UP = 0x36, 0x3A, 0x24, 0x18
CHEST_ROOM = 0x47               # a chest inside a room (FF1's: its palette only shows inside)
CHEST_CORR = (0x4B, 0x4C, 0x4D, 0x4E)   # our corridor chests: FF1's chest in the corridor palette
CHEST_ROOMS = (0x47, 0x48, 0x49, 0x4A)
EARTH_MAP = 29                  # Earth Cave B1: the palette of the cave floors
PG_OBJ0, ORB_GFX = 0xF0, 4      # the boss orbs' object ids (src/pg.s), FF1's orb picture (its fiends')
PG_ENT, PG_ENT_MT = 0x1E, 0x7A  # Earthgift's overworld entrance: its number, our cave mouth metatile
PG_OWX, PG_OWY = 132, 141       #   (FF1's cave mouth $0E copied; the overworld's unused $7A)
OW_CAVE = 0x0E

# Earthgift Shrine: (Dawn of Souls map record, look, role)
EARTHGIFT = [(120, 'cave', 'entrance'), (136, 'cave', 'floor'), (137, 'cave', 'floor'),
             (138, 'forest', 'floor'), (139, 'desert', 'floor'), (135, 'cave', 'boss')]
DUNGEONS = ['Earthgift Shrine']
DUNGEON_FLOORS = {'Earthgift Shrine': EARTHGIFT}
PG_END = PG_MAP0 + sum(len(v) for v in DUNGEON_FLOORS.values())


def classify(G, rec):
    """a Dawn of Souls floor -> (w, h, grid of classes): '.' floor, 'r' room floor, 'R' room wall,
    '#' blocked, ' ' void, 'D' door, 'S' stairs, 'C' a chest place (special chip)"""
    r = gba.map_record(G, rec)
    fs = gba.field_set(G, r['tileset'])
    w, h = r['w'], r['h']
    cells = [c & 0x3FF for c in r['cells']]
    doors = {(x, y) for x, y, _, _ in r['points']}
    zero = [c for c in cells if fs['attr'][c] == 0]
    void = max(set(zero), key=zero.count) if zero else -1
    g = [[' '] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            c = cells[w * y + x]; a = fs['attr'][c]
            if (x, y) in doors: k = 'D'
            elif a == 0: k = ' ' if c == void else 'S'
            elif a & 0xF000 == 0: k = 'r' if a & 0x100 else ('.' if a & 0xFF else 'C')
            elif a & 0x100: k = 'R'
            else: k = '#'
            g[y][x] = k
    for (x, y) in doors:                            # the opening above a door: the room's border
        if y > 0 and g[y - 1][x] in 'Cr': g[y - 1][x] = 'O'
    return w, h, g, r


def rooms(g, w, h):
    """the rooms: bounding boxes of the room-floor cells (8-connected, overlapping boxes merged)"""
    seen = set(); boxes = []
    for y in range(h):
        for x in range(w):
            if g[y][x] != 'r' or (x, y) in seen: continue
            q = [(x, y)]; seen.add((x, y)); cs = []
            while q:
                a, b = q.pop(); cs.append((a, b))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        p = (a + dx, b + dy)
                        if 0 <= p[0] < w and 0 <= p[1] < h and p not in seen and g[p[1]][p[0]] == 'r':
                            seen.add(p); q.append(p)
            xs = [c[0] for c in cs]; ys = [c[1] for c in cs]
            boxes.append([min(xs), min(ys), max(xs), max(ys)])
    merged = True
    while merged:
        merged = False
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                a, b = boxes[i], boxes[j]
                if a[0] <= b[2] + 1 and b[0] <= a[2] + 1 and a[1] <= b[3] + 1 and b[1] <= a[3] + 1:
                    boxes[i] = [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])]
                    del boxes[j]; merged = True; break
            if merged: break
    return boxes


def bfs(walk, start):
    dist = {start: 0}; q = deque([start])
    while q:
        p = q.popleft()
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (p[0] + d[0], p[1] + d[1])
            if n in walk and n not in dist:
                dist[n] = dist[p] + 1; q.append(n)
    return dist


def cave_floor(G, rec, role, n_chests):
    """a cave floor -> dict(map (64 x 64 bytes), start (x, y), chests [(x, y)], bosses [(x, y)])"""
    w, h, g, r = classify(G, rec)
    W = 64
    ox, oy = (W - w) // 2, (W - h) // 2
    assert ox >= 1 and oy >= 1, 'floor %d too big' % rec
    out = [[VOID] * W for _ in range(W)]
    boxes = rooms(g, w, h)
    inroom = set()
    for x0, y0, x1, y1 in boxes:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): inroom.add((x, y))
    walk = {(x, y) for y in range(h) for x in range(w) if g[y][x] in '.DSC' and (x, y) not in inroom}
    # small blocked clusters inside the floor (Dawn of Souls' boulders): floor, as FF1's corridors
    for _ in range(3):
        add = set()
        for y in range(h):
            for x in range(w):
                if g[y][x] not in '#R' or (x, y) in inroom: continue
                if ((x - 1, y) in walk and (x + 1, y) in walk) or ((x, y - 1) in walk and (x, y + 1) in walk):
                    run_h = sum(1 for d in (-1, 1) if 0 <= x + d < w and g[y][x + d] in '#R')
                    run_v = sum(1 for d in (-1, 1) if 0 <= y + d < h and g[y + d][x] in '#R')
                    if run_h <= 1 and run_v <= 1: add.add((x, y))
        walk |= add
    def put(x, y, v): out[y + oy][x + ox] = v
    border = {}
    for x0, y0, x1, y1 in boxes:
        for y in range(y0 - 1, y1 + 2):
            for x in range(x0 - 1, x1 + 2):
                if (x, y) in inroom: continue
                up, dn = (x, y - 1) in inroom, (x, y + 1) in inroom
                lf, rt = (x - 1, y) in inroom, (x + 1, y) in inroom
                if dn: v = B_T
                elif up: v = B_B
                elif rt: v = B_L
                elif lf: v = B_R
                elif (x + 1, y + 1) in inroom: v = B_TL
                elif (x - 1, y + 1) in inroom: v = B_TR
                elif (x + 1, y - 1) in inroom: v = B_BL
                else: v = B_BR
                border[(x, y)] = v
    chests, bosses, stairs = [], [], []
    for y in range(-oy, W - oy):
        for x in range(-ox, W - ox):
            if (x, y) in inroom:
                put(x, y, ROOMFL); continue
            if (x, y) in border:
                put(x, y, border[(x, y)]); continue
            k = g[y][x] if 0 <= x < w and 0 <= y < h else ' '
            if (x, y) in walk:
                if k == 'D':
                    put(x, y, DOOR)
                elif k == 'S':
                    put(x, y, STAIRS_DN); stairs.append((x, y))
                else:
                    put(x, y, BELOW_DOOR if 0 <= y - 1 < h and g[y - 1][x] == 'D' else FLOOR)
                continue
            W_ = lambda a, b: (a, b) in walk
            if W_(x + 1, y): v = WL
            elif W_(x - 1, y): v = WR
            elif W_(x, y - 1) or W_(x, y + 1): v = WH
            elif W_(x + 1, y + 1): v = C_TL
            elif W_(x - 1, y + 1): v = C_TR
            elif W_(x + 1, y - 1) or W_(x - 1, y - 1): v = WH
            else: v = VOID
            put(x, y, v)
    floor = {p for p in walk if g[p[1]][p[0]] in '.C' or p in walk and g[p[1]][p[0]] not in 'DS'}
    # rooms: the boss altars (boss floors) and the special chips in rooms (fixed chests)
    for x0, y0, x1, y1 in boxes:
        doors = [(x, y1 + 2) for x in range(x0, x1 + 1) if 0 <= y1 + 2 < h and g[y1 + 2][x] == 'D']
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                if g[y][x] == 'C':
                    put(x, y, CHEST_ROOMS[len(chests) % 4]); chests.append((x + ox, y + oy, 'room'))
        if role == 'boss' and doors:
            bosses.append((doors[0][0] + ox, y0 + 1 + oy))
    # the start: the entrance floor's corridor end (FF1's stairs up there: the way out), else the
    # walkable cell farthest from the stairs (boss floor: the lowest)
    cand = sorted(walk, key=lambda p: (-p[1], p[0]))
    if role == 'entrance':
        ex = cand[0]
        put(ex[0], ex[1], STAIRS_UP)
        start = (ex[0], ex[1] - 1)
        top = min(boxes, key=lambda b: b[1]) if boxes else None
        if top:                                     # the way down: in the top room, its middle
            sx, sy = (top[0] + top[2]) // 2, top[1] + 1
            out[sy + oy][sx + ox] = STAIRS_DN; stairs.append((sx, sy))
    elif role == 'boss' or not stairs:
        start = cand[0]
    else:
        d = bfs(walk, stairs[0])
        start = max(d, key=lambda p: (d[p], -p[1]))
    # chests on dead ends, far from the start and each other
    if n_chests:
        d0 = bfs(walk, start)
        dead = [p for p in walk if g[p[1]][p[0]] in '.C' and p != start and p not in stairs and
                sum((p[0] + a, p[1] + b) in walk for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) == 1]
        corner = [p for p in walk if g[p[1]][p[0]] == '.' and p != start and p not in stairs and
                  sum((p[0] + a, p[1] + b) in walk for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) == 2]
        pool = dead + corner
        picked = []
        while len(picked) < n_chests and pool:
            def score(p):
                ds = [abs(p[0] - q[0]) + abs(p[1] - q[1]) for q in picked + [start] + stairs]
                return (min(ds), d0.get(p, 0))
            p = max(pool, key=lambda p: (p in dead,) + score(p) if len(dead) > len(picked) else score(p))
            pool.remove(p); picked.append(p)
        for i, p in enumerate(picked):
            put(p[0], p[1], CHEST_CORR[i]); chests.append((p[0] + ox, p[1] + oy, 'corr'))
    return dict(map=bytes(v for row in out for v in row), start=(start[0] + ox, start[1] + oy),
                chests=chests, bosses=bosses, w=w, h=h, ox=ox, oy=oy)


def cave_tileset(rom):
    """FF1's Earth Cave tileset (2) with the post-game's properties: stairs down = teleport 0,
    stairs up = warp (the entrance floor's way out), chests = chest slots 0-3 (room) and 0-3
    (corridor: FF1's chest in the corridor palette), every floor with random encounters"""
    t = data.tileset_pack(rom, 2)
    prop = bytearray(t['prop']); pal = bytearray(t['mt_pal']); tsa = bytearray(t['tsa'])
    prop[2 * STAIRS_DN:2 * STAIRS_DN + 2] = bytes([0x80, 0x00])
    for i, mt in enumerate(CHEST_ROOMS):
        prop[2 * mt:2 * mt + 2] = bytes([0x09, 0x04 + i])     # (FF1: $09 + the chest number)
    for i, mt in enumerate(CHEST_CORR):
        prop[2 * mt:2 * mt + 2] = bytes([0x09, i])
        pal[mt] = 2
        for k in range(4): tsa[128 * k + mt] = tsa[128 * k + CHEST_ROOM]
    return dict(prop=bytes(prop), tsa=bytes(tsa), mt_pal=bytes(pal), cgb_tiles=t['cgb_tiles'])


def floors(rom, G=None):
    """the post-game's maps: [(map id, map_pack overrides, extra bytes)]"""
    G = G or gba.Gba()
    t = cave_tileset(rom)
    pal = rom.rd(data.BANK_SMINFO, data.SM_PAL + 0x30 * EARTH_MAP, 0x30)
    chr_ = rom.rd(data.BANK_TILESETCHR, 0x8000 + 0x800 * 2, 0x800)
    to, ochr, opal = outdoor_tileset(rom)
    out = []
    for i, (rec, look, role) in enumerate(EARTHGIFT):
        if look == 'cave':
            f = cave_floor(G, rec, role, 0 if role != 'floor' else 3)
            ov = dict(ts=PG_TS_CAVE - 8, t=t, map=f['map'], pal=pal, chr=chr_)
        else:
            f = outdoor_floor(G, rec, 'grass' if look == 'forest' else 'sand', 4)
            ov = dict(ts=PG_TS_OUT - 8, t=to, map=f['map'], pal=opal, chr=ochr)
        objs = bytearray(45)
        for k, (bx, by) in enumerate(f['bosses']):  # the boss floor: an orb for each boss
            objs[3 * k:3 * k + 3] = bytes([PG_OBJ0 + k, 0xC0 | bx, by])   # (in a room, still)
        ov['objs'] = bytes(objs)
        ov['obj_gfx'] = {PG_OBJ0 + k: ORB_GFX for k in range(4)}
        out.append((PG_MAP0 + i, f, ov))
    return out


PG_TS_OUT = 18                  # ROM bank of the outdoor tileset (FF1's overworld tiles; number 10)
# outdoor metatiles: (name, source, metatile there, property bytes)
O_GRASS, O_FOREST, O_SAND, O_WATER, O_STAIRS, O_CHEST = 0, 1, 10, 11, 20, 21
OUT_MTS = ([('grass', 'ow', 0x00, (0x0A, 0x80))] +
           [('forest', 'ow', m, (0x01, 0)) for m in (0x03, 0x04, 0x05, 0x13, 0x14, 0x15, 0x23, 0x24, 0x25)] +
           [('sand', 'ow', 0x36, (0x0A, 0x80))] +
           [('water', 'ow', m, (0x01, 0)) for m in (0x17, 0x06, 0x07, 0x08, 0x16, 0x18, 0x26, 0x27, 0x28)] +
           [('stairs', 'ow', 0x0E, (0x80, 0))] +
           [('chest', 'cave', CHEST_ROOM, (0x09, k)) for k in range(4)])
# a 3 x 3 edge set (forest, water) by which neighbours are open: (row, column) -> index in the set
EDGE = {('T', 'L'): 1, ('T', 'C'): 2, ('T', 'R'): 3, ('M', 'L'): 4, ('M', 'C'): 0, ('M', 'R'): 5,
        ('B', 'L'): 6, ('B', 'C'): 7, ('B', 'R'): 8}
FOREST_SET = [O_FOREST + 4, O_FOREST + 0, O_FOREST + 1, O_FOREST + 2, O_FOREST + 3, O_FOREST + 5,
              O_FOREST + 6, O_FOREST + 7, O_FOREST + 8]     # centre, TL, T, TR, L, R, BL, B, BR
WATER_SET = [O_WATER + k for k in range(9)]                    # centre, TL, T, TR, L, R, BL, B, BR


def outdoor_tileset(rom):
    """our outdoor tileset: FF1's overworld grass, forest, sand, water and cave mouth, FF1's chest;
    the overworld's colours"""
    blk = rom.rd(data.BANK_SMINFO, data.OW_INFO, 0x400)
    otsa, oattr, opal = blk[256:768], blk[768:896], blk[0x380:0x3B0]
    ochr = rom.rd(data.BANK_MAPCHR, data.OW_CHR, 0x1000)
    ct = data.tileset_pack(rom, 2)
    cchr = rom.rd(data.BANK_TILESETCHR, 0x8000 + 0x800 * 2, 0x800)
    bg = [[opal[0]] + list(opal[4 * p + 1:4 * p + 4]) for p in range(4)]
    chest_pal = min(range(4), key=lambda p: sum(abs(data.lum(a) - data.lum(b)) for a, b in
                                                zip(bg[p][1:], (0x10, 0x17, 0x27))))
    tiles = {}; chr_ = bytearray(0x800)
    tsa = bytearray(512); pal = bytearray(128); prop = bytearray(256)
    for i, (name, src, mt, pr) in enumerate(OUT_MTS):
        for k in range(4):
            if src == 'ow':
                key = ('ow', otsa[128 * k + mt]); raw = ochr
            else:
                key = ('cave', ct['tsa'][128 * k + mt]); raw = cchr
            if key not in tiles:
                n = len(tiles); assert n < 128
                tiles[key] = n
                chr_[16 * n:16 * n + 16] = raw[16 * key[1]:16 * key[1] + 16]
            tsa[128 * k + i] = tiles[key]
        pal[i] = (oattr[mt] & 3) if src == 'ow' else chest_pal
        prop[2 * i:2 * i + 2] = bytes(pr)
    t = dict(prop=bytes(prop), tsa=bytes(tsa), mt_pal=bytes(pal),
             cgb_tiles=b''.join(data.gb_tile(chr_[16 * x:16 * x + 16]) for x in range(128)))
    return t, bytes(chr_), bytes(opal[:0x20]) + bytes(opal[:0x10])


def edge_piece(is_set, x, y, pieces):
    row = 'T' if not is_set(x, y - 1) else ('B' if not is_set(x, y + 1) else 'M')
    col = 'L' if not is_set(x - 1, y) else ('R' if not is_set(x + 1, y) else 'C')
    return pieces[EDGE[(row, col)]]


def outdoor_floor(G, rec, base, n_chests):
    """a forest / desert floor -> as cave_floor: 64 x 64 (wrapping, as FF1's maps do), cut around
    the stairs; terrain by the chips' properties and colours"""
    r = gba.map_record(G, rec)
    fs = gba.field_set(G, r['tileset'])
    w, h = r['w'], r['h']
    cells = [c & 0x3FF for c in r['cells']]
    cnt = {}
    for c in cells: cnt[c] = cnt.get(c, 0) + 1
    avg = {}
    for c in cnt:
        px = list(gba.chip_image(fs, c).convert('RGB').getdata())
        avg[c] = tuple(sum(p[i] for p in px) // len(px) for i in range(3))
    base_col = avg[max(cnt, key=cnt.get)]
    zero = [c for c in cnt if fs['attr'][c] == 0]               # the stairs: the odd one out
    stairs_c = max(zero, key=lambda c: sum(abs(u - v) for u, v in zip(avg[c], base_col)))
    kind = {}
    for c in cnt:
        a = fs['attr'][c]; R, Gc, B = avg[c]
        near = sum(abs(u - v) for u, v in zip(avg[c], base_col)) < 40
        if a == 0: k = 'S' if c == stairs_c else '.'
        elif a & 0xF000 == 0xF000:
            if B > R + 20 and B > Gc - 10 and not near: k = 'W'
            elif base == 'sand' and near: k = '.'
            else: k = 'T'
        elif a == 0x0100 and base == 'grass': k = 'C'
        elif base == 'sand' and c == 0x12: k = 'T'                 # (the palms that point the way)
        elif base == 'sand' and Gc > R + 15 and not near: k = 'g'
        else: k = '.'
        kind[c] = k
    g = [[kind[cells[w * y + x]] for x in range(w)] for y in range(h)]
    st = [(x, y) for y in range(h) for x in range(w) if g[y][x] == 'S']
    sx, sy = st[0]
    if base == 'sand': ox, oy = 32 - sx, 32 - sy    # the desert: the stairs in the middle (it loops)
    else: ox, oy = (64 - w) // 2, (64 - h) // 2      # the forest: the whole floor, its edges trimmed
    W = 64
    def at(x, y):                                   # the map's cell at our (x, y), wrapping
        X, Y = x - ox, y - oy
        if base == 'sand': X, Y = X % w, Y % h      # (Dawn of Souls' desert loops too)
        return g[Y][X] if 0 <= X < w and 0 <= Y < h else 'T'
    G2 = [[at(x, y) for x in range(W)] for y in range(W)]
    out = [[0] * W for _ in range(W)]
    tree = lambda x, y: G2[y % W][x % W] == 'T'
    water = lambda x, y: G2[y % W][x % W] == 'W'
    walk = set()
    for y in range(W):
        for x in range(W):
            k = G2[y][x]
            if k == 'T':
                v = O_FOREST + 4 if base == 'sand' and not any(
                    tree(x + a, y + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) else \
                    edge_piece(tree, x, y, FOREST_SET)
            elif k == 'W': v = edge_piece(water, x, y, WATER_SET)
            elif k == 'S': v = O_STAIRS; walk.add((x, y))
            else:
                v = O_SAND if base == 'sand' and k != 'g' else O_GRASS
                walk.add((x, y))
            out[y][x] = v
    stairs = (sx + ox, sy + oy)
    def bfs_w(s):
        dist = {s: 0}; q = deque([s])
        while q:
            p = q.popleft()
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = ((p[0] + d[0]) % W, (p[1] + d[1]) % W)
                if n in walk and n not in dist:
                    dist[n] = dist[p] + 1; q.append(n)
        return dist
    d = bfs_w(stairs)                               # the start: far from the stairs, by the path and
    tor = lambda p, q: min(abs(p[0] - q[0]), W - abs(p[0] - q[0])) + min(abs(p[1] - q[1]), W - abs(p[1] - q[1]))
    start = max(d, key=lambda p: (d[p] * tor(p, stairs), -p[1]))   # as the crow flies
    chests = []
    if n_chests:
        d0 = bfs_w(start)
        cand = [p for p in d if p != start and p != stairs and G2[p[1]][p[0]] in '.gC']
        dead = [p for p in cand if sum(((p[0] + a) % W, (p[1] + b) % W) in walk
                                       for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) == 1]
        pool = dead if len(dead) >= n_chests else cand
        picked = []
        while len(picked) < n_chests and pool:
            def score(p):
                return min(min(abs(p[0] - q[0]), W - abs(p[0] - q[0])) + min(abs(p[1] - q[1]), W - abs(p[1] - q[1]))
                           for q in picked + [start, stairs])
            p = max(pool, key=lambda p: (score(p), d0.get(p, 0))); pool.remove(p); picked.append(p)
        for i, p in enumerate(picked):
            out[p[1]][p[0]] = O_CHEST + i; chests.append((p[0], p[1], 'out'))
    return dict(map=bytes(v for row in out for v in row), start=start, chests=chests, bosses=[],
                w=W, h=W, ox=0, oy=0)


# Earthgift's treasure (Dawn of Souls; the FINAL FANTASY wiki's lists per depth): B1-B4, then the
# boss floor's own chest (after Ahriman)
EG_TREASURE = [['Hi-Potion', "Spider's Silk", 'White Curtain', 'Remedy'],
               ['Vampire Fang', 'Blue Curtain', 'White Fang', 'Kenpogi'],
               ['Potion', 'Speed Drink', 'Protect Drink', 'Black Cowl'],
               ['Red Fang', 'Ether', 'Silver Apple', 'Elven Cloak']]
EG_FIXED = ['Megalixir']


def pg_source(bank):
    """the run's data in the post-game code bank: the treasure per depth, the fixed chests"""
    db = lambda xs: '            db ' + ', '.join('$%02X' % x for x in xs) + '\n'
    return ('section bank %d, $7F00\npg_treas:\n' % bank +
            ''.join(db([item_code(n) for n in row]) for row in EG_TREASURE) +
            'pg_fixed:\n' + db([item_code(n) for n in EG_FIXED] + [0] * 7))


def overworld_patch():
    """the shrine's door on the overworld: a cave mouth with its own entrance number"""
    data.OW_MT_PATCH[PG_ENT_MT] = (OW_CAVE, (0x0E, 0x80 | PG_ENT))
    data.OW_ROW_PATCH.append((PG_OWX, PG_OWY, PG_ENT_MT))


# Dawn of Souls' words (its message table, retranslated in the project's style; the official English
# a guide): 640 at the shrine's door, 648-651 the bosses (Echidna, Cerberus, Ahriman, the Two-Headed
# Dragon: matched by the official quotes)
T_SEALED = ("This is the Earthgift Shrine. Long ago, they say, one could enter, but since the earth "
            "began to rot, no one has been able to get in.")
T_BOSS = ["You did well to come this far... but this is where your journey ends!",
          "I'll grant you this much for making it so far... but here you die!",
          "There is nothing anywhere that can stop me! You, too, will die here by my hand!",
          "Fwahahaha... Let everything vanish! Die, Warriors of Light!"]
PGT_BANK = 125


def text_source():
    import text
    def db(b): return ''.join('            db ' + ', '.join('$%02X' % x for x in b[i:i + 16]) + '\n'
                              for i in range(0, len(b), 16))
    out = 'section bank 116, $7E00\npg_t_boss:  dw pg_tb0, pg_tb1, pg_tb2, pg_tb3\n'   # (read in pg.s's bank)
    out += 'section bank %d, $4000\npg_t_sealed:\n' % PGT_BANK + db(text.encode_dialogue(T_SEALED))
    for k, t in enumerate(T_BOSS):
        out += 'pg_tb%d:\n' % k + db(text.encode_dialogue(t))
    return out


# Dawn of Souls' new items (Earthgift's; effects from the FINAL FANTASY wiki: Hi-Potion 150 HP, Remedy
# every ailment but KO / stone, Ether MP (Classic: one charge for every level, as the Pixel Remaster),
# Megalixir all HP / MP of everyone, Silver Apple +5 maximum HP for good; the Fangs, Curtains, Drinks
# and Spider's Silk cast FF1's own spell). Each takes the name code of an FF1 gold amount no chest
# gives (names / prices replaced); consumable k counts at save page $B0 + k (FF1 leaves it unused).
# (name, name code, battle magic (FF1 spell number or our entries $5C-$5F), field use)
NEW_ITEMS = [('Hi-Potion', 113, 0x5C, 'hp'), ('Remedy', 114, 0x5D, 'cure'), ('Ether', 116, 0x5E, 'ether'),
             ('Megalixir', 120, 0x5F, 'mega'), ('Silver Apple', 121, None, 'apple'),
             ('Red Fang', 122, 20, None), ('White Fang', 124, 31, None), ('Vampire Fang', 125, 21, None),
             ("Spider's Silk", 127, 15, None), ('White Curtain', 158, 26, None),
             ('Blue Curtain', 165, 10, None), ('Speed Drink', 166, 29, None), ('Protect Drink', 167, 2, None)]
NEW_PRICE = {'Hi-Potion': 150, 'Remedy': 1000, 'Ether': 1500, 'Megalixir': 50000, 'Silver Apple': 5000,
             'Red Fang': 500, 'White Fang': 500, 'Vampire Fang': 500, "Spider's Silk": 500,
             'White Curtain': 1000, 'Blue Curtain': 1000, 'Speed Drink': 1000, 'Protect Drink': 1000}
NEWIT = 0xB0                     # (save page offset of consumable 0's count)
# armour (FF1's 4-byte record: weight, defence, resisted elements, spell; permission word: a set bit is a
# class that cannot wear it, Fighter bit 11 .. Black Wizard bit 0; type 0 armour, 1 shield, 2 helmet):
# armour ids whose name code ($43 + id) is an FF1 gold amount no chest gives
NEW_ARMOUR = [('Kenpogi', 43, (1, 28, 0, 0), 0x0DF7, 0, 'armour', 16000),      # Monk / Master
              ('Black Cowl', 44, (1, 8, 0x01, 0), 0x0BEF, 2, 'helmet', 12000),  # Thief / Ninja; sleep
              ('Elven Cloak', 45, (1, 9, 0, 0), 0x0208, 1, 'shield', 12000)]    # all but Monk / Master
N_ARMOUR = 45


def item_code(name):
    """a Dawn of Souls item -> the native build's item code (FF1's where it has one)"""
    ff1 = {'Potion': 0x19, 'Antidote': 0x1A, 'Gold Needle': 0x1B, 'Tent': 0x16, 'Cabin': 0x17,
           'Cottage': 0x18}
    if name in ff1: return ff1[name]
    for n, code, _, _ in NEW_ITEMS:
        if n == name: return code
    for n, aid, *_ in NEW_ARMOUR:
        if n == name: return 0x43 + aid
    raise KeyError(name)


def names_patch():
    """the new items' and armour's names in the names bank (names.py), their prices"""
    import names
    for n, code, _, _ in NEW_ITEMS:
        names.OVERRIDE[code] = ('item', n)
        names.PRICE[code] = NEW_PRICE[n]
    for n, aid, _, _, _, icon, price in NEW_ARMOUR:
        names.OVERRIDE[0x43 + aid] = (icon, n)
        names.PRICE[0x43 + aid] = price
        names.ARMOUR_EXTRA[aid] = [x for x in NEW_ARMOUR if x[1] == aid][0]


def items_source():
    """the item tables the engine reads (src/pg.s): the new consumables' codes (it_newc, bank 0),
    the Items screen's orders (Use / after Sort), the battle Medicine list (md_tab, bank 104)"""
    db = lambda xs: '            db ' + ', '.join('$%02X' % x for x in xs) + '\n'
    codes = [c for _, c, _, _ in NEW_ITEMS]
    out = 'section bank 0, $3574\nit_newc:\n' + db(codes + [0])
    ord0 = [0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B] + codes
    heal = [0x19, 0x1A, 0x1B] + [c for n, c, _, u in NEW_ITEMS if u in ('hp', 'cure', 'mega', 'ether')]
    ord1 = heal + [c for c in ord0 if c not in heal]
    use = {None: 0, 'hp': 1, 'cure': 2, 'ether': 3, 'mega': 4, 'apple': 5}
    out += ('section bank 2, $7D7D\nit_ord0:\n' + db(ord0) + 'it_ord1:\n' + db(ord1) +
            'it_utab:\n' + db([use[u] for _, _, _, u in NEW_ITEMS]))
    out += 'N_ARMOUR = %d\n' % N_ARMOUR
    out += 'IT_NORD = %d\nN_NEWIT = %d\nNEWIT = unsram + $%02X\n' % (len(ord0), len(NEW_ITEMS), NEWIT)
    # Medicine: count's address (low byte, page $D0), name (battle attack names), magic; Potion, Antidote first
    md = [(0x20 + 0x19, 0x40, 0x40), (0x20 + 0x1A, 0x41, 0x41)]
    for k, (n, c, mg, _) in enumerate(NEW_ITEMS):
        if mg is not None:
            md.append((NEWIT + k, 0x5C + len(md) - 2, mg))
    out += 'section bank 104, $7C00\nmd_tab:\n' + ''.join(db(list(e) + [0]) for e in md)
    out += 'MD_N = %d\n' % len(md)
    return out


def battle_names():
    """the Medicine entries' names after FF1's attack names (battle.py: $5C on)"""
    return [n for n, c, mg, _ in NEW_ITEMS if mg is not None]


ST_TILE = 0x70                  # the statue's sprite tiles on the overworld ($70-$7F, after the vehicles')


def statue(rom):
    """the statue before Earthgift's sealed door: FF1's own Lich (fiend picture 0, the user's ROM) as grey
    stone, 32 x 32: (CGB tiles, DMG tiles, the OBJ palette 0-3 it uses on the Color)"""
    import battle
    forms = rom.rd(battle.BANK_DOMAINS, battle.FORMATIONS, 128 * 16)
    f = next(k for k in range(128) if forms[16 * k] >> 4 == 3 and forms[16 * k + 1] == 0)
    page = forms[16 * f] & 15
    chr_ = rom.rd(battle.BANK_BATTLECHR + (page >> 3), 0x8000 + 0x800 * (page & 7), 0x800)
    tsa = rom.rd(battle.BANK_DOMAINS, 0x92E0, 64)
    pal = list(rom.rd(battle.BANK_BTLC, battle.BTL_PALS + 4 * forms[16 * f + 10], 4))
    lum = [0] + [data.lum(c) for c in pal[1:]]
    px = [[None] * 64 for _ in range(64)]
    for r in range(8):
        for c in range(8):
            t = tsa[8 * r + c]
            if t < 0x12: continue
            for y in range(8):
                for x in range(8):
                    v = (chr_[16 * t + y] >> (7 - x) & 1) | (chr_[16 * t + 8 + y] >> (7 - x) & 1) << 1
                    if v: px[8 * r + y][8 * c + x] = lum[v]
    out = [[0] * 32 for _ in range(32)]
    mean = {}
    for y in range(32):
        for x in range(32):
            vs = [px[2 * y + j][2 * x + i] for j in (0, 1) for i in (0, 1)]
            vs = [v for v in vs if v is not None]
            if len(vs) >= 2: mean[(x, y)] = sum(vs) / len(vs)
    ranked = sorted(mean.values())                                    # stone: the brightest 45% light,
    t2, t1 = ranked[int(len(ranked) * 0.20)], ranked[int(len(ranked) * 0.55)]   # the next mid, the darkest
    for (x, y), m in mean.items():                                    # fifth the dark (1 / 2 / 3)
        out[y][x] = 1 if m >= t1 else (2 if m >= t2 else 3)
    for y in range(32):                                               # a dark outline round the stone
        for x in range(32):
            if out[y][x] == 0 and any(0 <= y + b < 32 and 0 <= x + a < 32 and out[y + b][x + a] in (1, 2)
                                      for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = 3
    def tile(r, c, remap):
        b = bytearray()
        for y in range(8):
            lo = hi = 0
            for x in range(8):
                v = remap[out[8 * r + y][8 * c + x]]
                lo = lo << 1 | (v & 1); hi = hi << 1 | (v >> 1)
            b += bytes([lo, hi])
        return bytes(b)
    blk = rom.rd(data.BANK_SMINFO, data.OW_INFO, 0x400)
    sp = [[blk[0x390]] + list(blk[0x390 + 4 * p + 1:0x390 + 4 * p + 4]) for p in range(4)]
    def greyness(p):                                                 # (the most stone-like palette: greys
        cs = sp[p][1:]                                               #   ($x0, $xD), then a spread of levels)
        greys = sum(1 for c in cs if (c & 0x0F) in (0x00, 0x0D, 0x0F))
        return -greys * 2 + sum(abs(data.lum(c) - k) for c, k in
                                zip(sorted(cs, key=data.lum, reverse=True), (0.85, 0.55, 0.15)))
    p = 7                                                            # (its own: pg.s pg_rpal)
    cgb_map = [0, 1, 2, 3]
    dmg_map = [0, 1, 2, 3]                                           # (OBP0: 1 white .. 3 black: DMG_OBP)
    cgb = b''.join(tile(r, c, cgb_map) for r in range(4) for c in range(4))
    dmg = b''.join(tile(r, c, dmg_map) for r in range(4) for c in range(4))
    return cgb, dmg, p
