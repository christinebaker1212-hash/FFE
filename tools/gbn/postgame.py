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
GBA_PATH = None                 # the user's Dawn of Souls ROM (build.py --gba; none: no post-game)
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
EARTH_PIECES = dict(floor=FLOOR, void=VOID, roomfl=ROOMFL, wl=WL, wr=WR, wtop=WH, wbot=WH, ctl=C_TL, ctr=C_TR,
                    bt=B_T, bb=B_B, bl=B_L, br=B_R, btl=B_TL, btr=B_TR, bbl=B_BL, bbr=B_BR, door=DOOR,
                    below=BELOW_DOOR, stairs=STAIRS_DN, up=STAIRS_UP, lava=0x3D,
                    chest_room=CHEST_ROOMS, chest_corr=CHEST_CORR)
PG_OBJ0, ORB_GFX = 0xF0, 4      # the boss orbs' object ids (src/pg.s), FF1's orb picture (its fiends')
PG_ENT, PG_ENT_MT = 0x1E, 0x7A  # Earthgift's overworld entrance: its number, our cave mouth metatile
PG_OWX, PG_OWY = 132, 141       #   (FF1's cave mouth $0E copied; the overworld's unused $7A)
OW_CAVE = 0x0E

import shrines, pgevents
# the post-game's maps: every shrine's floors in order (shrines.py), map ids PG_MAP0 and up
PG_FLOORS = [(s, rec, look, role, area) for s, sh in enumerate(shrines.SHRINES)
             for rec, look, role, area in sh['floors']]
PG_END = PG_MAP0 + len(PG_FLOORS)
assert PG_END <= 192                            # (map m in ROM bank m + 64)
def map_of(s, rec):
    return PG_MAP0 + PG_FLOORS.index(next(f for f in PG_FLOORS if f[0] == s and f[1] == rec))


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
            elif a & 0xF000 == 0 and a & 0xFF == 0x13: k = 'L'        # (lava: FF1's damage floor)
            elif a & 0xF000 == 0: k = 'r' if a & 0x100 else ('.' if a & 0xFF else 'C')
            elif a & 0x100: k = 'R'
            else: k = '#'
            g[y][x] = k
    zc = {}                                         # (stairs: a rare attribute-0 chip next to the floor;
    for y in range(h):                              #   other attribute-0 chips are scenery: void)
        for x in range(w):
            if g[y][x] == 'S': zc.setdefault(cells[w * y + x], []).append((x, y))
    for c, ps in zc.items():
        near = [p_ for p_ in ps if any(0 <= p_[0] + a < w and 0 <= p_[1] + b < h and g[p_[1] + b][p_[0] + a] in '.L'
                                       for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        if len(ps) > 2 and len(near) * 2 > len(ps):   # (a common one along the corridors: floor, e.g. the
            for x, y in ps: g[y][x] = '.'                   #   Western Keep's carpet)
        elif len(ps) > 2 or not near:
            for x, y in ps: g[y][x] = ' '
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


def window(g, w, h, walkable, keep=(), size=60):
    """a floor larger than FF1's 64 x 64 maps: the size x size part with the most walkable cells (Dawn of
    Souls' wide floors cut, as its desert was; owner, 2026-11-27), holding the cells in keep if it can ->
    (x0, y0, x1, y1)"""
    cs = [(x, y) for y in range(h) for x in range(w) if g[y][x] in walkable]
    bx0, bx1 = max(0, min(c[0] for c in cs) - 2), min(w, max(c[0] for c in cs) + 3)
    by0, by1 = max(0, min(c[1] for c in cs) - 2), min(h, max(c[1] for c in cs) + 3)
    if bx1 - bx0 <= size and by1 - by0 <= size: return bx0, by0, bx1, by1
    sw, sh = min(size, bx1 - bx0), min(size, by1 - by0)
    S = [[0] * (w + 1) for _ in range(h + 1)]       # (a summed-area table of the walkable cells)
    for y in range(h):
        for x in range(w):
            S[y + 1][x + 1] = S[y][x + 1] + S[y + 1][x] - S[y][x] + (g[y][x] in walkable)
    best = None
    for y0 in range(by0, by1 - sh + 1):
        for x0 in range(bx0, bx1 - sw + 1):
            n = S[y0 + sh][x0 + sw] - S[y0][x0 + sw] - S[y0 + sh][x0] + S[y0][x0]
            n += 10000 * sum(1 for kx, ky in keep if x0 + 2 <= kx < x0 + sw - 2 and y0 + 2 <= ky < y0 + sh - 2)
            if best is None or n > best[0]: best = (n, x0, y0)
    _, x0, y0 = best
    return x0, y0, x0 + sw, y0 + sh


def cave_floor(G, rec, role, n_chests, pc=None, floor_chips=(), stairs_out=True, fixed=False):
    """a cave floor -> dict(map (64 x 64 bytes), start (x, y), chests [(x, y, kind)], bosses [(x, y)]);
    role: entrance (FF1's stairs up the way out, the stairs down in its top room), floor, boss (the orbs in
    its rooms, a way out (stairs up) by the start, the stairs down if stairs_out)"""
    pc = pc or EARTH_PIECES
    w, h, g, r = classify(G, rec)
    if floor_chips:                                 # (chips walked over in Dawn of Souls by other means:
        cells = [c & 0x3FF for c in r['cells']]     #   the flooded village's canoe water)
        for y in range(h):
            for x in range(w):
                if cells[w * y + x] in floor_chips: g[y][x] = '.'
    if w > 62 or h > 62:                            # (larger floors: cut to their walkable part, 2 around)
        keep = [(x, y) for y in range(h) for x in range(w) if g[y][x] in 'SD']
        x0, y0, x1, y1 = window(g, w, h, '.DSLrO', keep)
        g = [row[x0:x1] for row in g[y0:y1]]
        w, h = x1 - x0, y1 - y0
        for y in range(h):                          # (the cut edges: walls)
            for x in range(w):
                if (x in (0, w - 1) or y in (0, h - 1)) and g[y][x] != ' ': g[y][x] = '#'
    W = 64
    ox, oy = (W - w) // 2, (W - h) // 2
    assert ox >= 1 and oy >= 1, 'floor %d too big' % rec
    out = [[pc['void']] * W for _ in range(W)]
    boxes = []                                      # (a room only with a door below it: Dawn of Souls also
    for b in rooms(g, w, h):                        #   marks whole halls; those are floor and walls)
        x0_, y0_, x1_, y1_ = b
        area = (x1_ - x0_ + 1) * (y1_ - y0_ + 1)
        inner = sum(1 for y in range(y0_, y1_ + 1) for x in range(x0_, x1_ + 1) if g[y][x] == 'r')
        if any(0 <= y1_ + 2 < h and g[y1_ + 2][x] == 'D' for x in range(x0_, x1_ + 1)) and \
           area <= 140 and inner * 2 >= area:        # (a small room; a hall keeps its maze)
            boxes.append(b)
        else:
            for y in range(max(0, y0_ - 1), min(h, y1_ + 2)):
                for x in range(max(0, x0_ - 1), min(w, x1_ + 2)):
                    if g[y][x] in 'rO': g[y][x] = '.'
                    elif g[y][x] == 'R': g[y][x] = '#'
    inroom = set()
    for x0, y0, x1, y1 in boxes:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): inroom.add((x, y))
    walk = {(x, y) for y in range(h) for x in range(w) if g[y][x] in '.DSCL' and (x, y) not in inroom}
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
                if dn: v = pc['bt']
                elif up: v = pc['bb']
                elif rt: v = pc['bl']
                elif lf: v = pc['br']
                elif (x + 1, y + 1) in inroom: v = pc['btl']
                elif (x - 1, y + 1) in inroom: v = pc['btr']
                elif (x + 1, y - 1) in inroom: v = pc['bbl']
                else: v = pc['bbr']
                border[(x, y)] = v
    chests, bosses, stairs, rchest = [], [], [], set()
    for y in range(-oy, W - oy):
        for x in range(-ox, W - ox):
            if (x, y) in inroom:
                put(x, y, pc['roomfl']); continue
            if (x, y) in border:
                put(x, y, border[(x, y)]); continue
            k = g[y][x] if 0 <= x < w and 0 <= y < h else ' '
            if (x, y) in walk:
                if k == 'D':
                    put(x, y, pc['door'])
                elif k == 'S':
                    put(x, y, pc['stairs']); stairs.append((x, y))
                else:
                    put(x, y, pc['below'] if 0 <= y - 1 < h and g[y - 1][x] == 'D' else (pc['lava'] if k == 'L' else pc['floor']))
                continue
            W_ = lambda a, b: (a, b) in walk
            if W_(x + 1, y): v = pc['wl']
            elif W_(x - 1, y): v = pc['wr']
            elif W_(x, y - 1) or W_(x, y + 1): v = pc['wtop']
            elif W_(x + 1, y + 1): v = pc['ctl']
            elif W_(x - 1, y + 1): v = pc['ctr']
            elif W_(x + 1, y - 1) or W_(x - 1, y - 1): v = pc['wtop']
            else: v = pc['void']
            put(x, y, v)
    floor = {p for p in walk if g[p[1]][p[0]] in '.C' or p in walk and g[p[1]][p[0]] not in 'DS'}
    # rooms: the boss altars (boss floors) and the special chips in rooms (fixed chests)
    for x0, y0, x1, y1 in boxes:
        doors = [(x, y1 + 2) for x in range(x0, x1 + 1) if 0 <= y1 + 2 < h and g[y1 + 2][x] == 'D']
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                if g[y][x] == 'C':
                    put(x, y, pc['chest_room'][len(chests) % 4]); chests.append((x + ox, y + oy, 'room'))
                    rchest.add((x, y))
        if role == 'boss' and doors:
            bosses.append((doors[0][0] + ox, y0 + 1 + oy))
    # the start: the entrance floor's corridor end (FF1's stairs up there: the way out), else the
    # walkable cell farthest from the stairs (boss floor: the lowest, with the way out below it)
    comp, seen = None, set()                        # (the start in the largest connected part: Dawn of Souls
    for c0 in walk:                                 #   joins some parts by events we do not have)
        if c0 in seen: continue
        cc = bfs(walk | inroom, c0); seen |= set(cc)
        if comp is None or len(cc) > len(comp): comp = cc
    cand = sorted((q for q in walk if q in comp), key=lambda p: (-p[1], p[0]))
    exit_ = None
    if role in ('entrance', 'boss'):
        ex = next((q for q in cand if (q[0], q[1] - 1) in walk and q not in stairs), cand[0])
        start = (ex[0], ex[1] - 1)
        if role == 'entrance':
            put(ex[0], ex[1], pc['up'])
            walk.discard(ex)
        else:                                       # (a boss floor: the light out appears there, pg.s)
            exit_ = (ex[0] + ox, ex[1] + oy)
    if role == 'entrance':
        top = min(boxes, key=lambda b: b[1]) if boxes else None
        if top:                                     # the way down: in the top room, its middle
            sx, sy = (top[0] + top[2]) // 2, top[1] + 1
            out[sy + oy][sx + ox] = pc['stairs']; stairs = [(sx, sy)]
    elif role == 'boss':
        for sx, sy in stairs:
            put(sx, sy, pc['floor'] if (sx, sy) in walk else pc['void'])
        stairs = []
    elif not stairs:
        start = cand[0]
    else:
        d = bfs(walk, stairs[0])
        if len(d) * 3 < len([q for q in comp if q in walk]):   # (the stairs in a pocket, which Dawn of Souls
            old = stairs[0]                                     #   joins to the rest by events: the stairs
            put(old[0], old[1], pc['floor'])                    #   moved into the floor's largest part)
            new = min((q for q in comp if q in walk and g[q[1]][q[0]] == '.' and q not in rchest),
                      key=lambda q: abs(q[0] - old[0]) + abs(q[1] - old[1]))
            put(new[0], new[1], pc['stairs']); stairs = [new]
            d = bfs(walk, new)
        start = max(d, key=lambda p: (d[p], -p[1]))
    reach = bfs(walk | inroom, start)
    for c in list(chests):                          # (a room's chest the party cannot reach: none)
        if c[2] == 'room' and not any((c[0] - ox + a, c[1] - oy + b) in reach for a, b in ((0, 1), (0, -1), (1, 0), (-1, 0))):
            chests.remove(c); put(c[0] - ox, c[1] - oy, pc['roomfl'])
    if role == 'floor' or (role == 'boss' and stairs_out):
        stairs = [s for s in stairs if s in reach][:1]
        if not stairs:                              # (no stairs down reachable after the cut: the
            far = max((q for q in reach if q in walk and g[q[1]][q[0]] == '.' and q != start),   # farthest
                      key=lambda q: reach[q])       #   floor cell)
            put(far[0], far[1], pc['stairs']); stairs = [far]
    if role == 'boss':                              # (no boss rooms: the orbs on the farthest cells)
        bosses = [(x, y, 0xC0) for x, y in bosses if (x - ox, y - oy) in reach]   # (rooms the party reaches)
        far = sorted((q for q in reach if q in walk and g[q[1]][q[0]] == '.' and q != start and q not in stairs),
                     key=lambda q: -reach[q])
        n_walk = len(bfs(walk, start))
        for q in far[1 if fixed and not chests else 0:]:   # (the fixed chest's cell kept: far[0])
            if len(bosses) >= 4: break
            orbs = {(b[0] - ox, b[1] - oy) for b in bosses} | {q}
            if len(bfs(walk - orbs, start)) < n_walk - len(orbs):   # (an orb never walls in the rest)
                continue
            if all(abs(q[0] + ox - b[0]) + abs(q[1] + oy - b[1]) > 6 for b in bosses):
                bosses.append((q[0] + ox, q[1] + oy, 0x40))
        if fixed and not chests:                    # (the boss floor's own chest: beyond the boss)
            q = far[0]
            put(q[0], q[1], pc['chest_corr'][0]); chests.append((q[0] + ox, q[1] + oy, 'room'))
    # chests on dead ends, far from the start and each other
    if n_chests:
        d0 = reach
        ok = lambda p: p in d0 and p != start and p not in stairs and g[p[1]][p[0]] in '.C' and \
            any((p[0] + a, p[1] + b) in walk and (p[0] + a, p[1] + b) not in stairs
                for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))       # (not reached by the stairs alone)
        dead = [p for p in walk if ok(p) and
                sum((p[0] + a, p[1] + b) in walk for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) == 1]
        corner = [p for p in walk if ok(p) and g[p[1]][p[0]] == '.' and
                  sum((p[0] + a, p[1] + b) in walk for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) == 2]
        pool = dead + corner
        picked = []
        n_reach = len(bfs(walk, start))
        while len(picked) < n_chests and pool:
            def score(p):
                ds = [abs(p[0] - q[0]) + abs(p[1] - q[1]) for q in picked + [start] + stairs]
                return (min(ds), d0.get(p, 0))
            p = max(pool, key=lambda p: (p in dead,) + score(p) if len(dead) > len(picked) else score(p))
            pool.remove(p)
            if len(bfs(walk - set(picked) - {p}, start)) < n_reach - len(picked) - 1: continue   # (never across the way)
            picked.append(p)
        for i, p in enumerate(picked):
            put(p[0], p[1], pc['chest_corr'][0]); chests.append((p[0] + ox, p[1] + oy, 'corr'))
    reach = bfs(walk | inroom, start)
    return dict(map=bytes(v for row in out for v in row), start=(start[0] + ox, start[1] + oy),
                chests=chests, bosses=bosses, stairs=[(x + ox, y + oy) for x, y in stairs], exit=exit_,
                w=w, h=h, ox=ox, oy=oy, walk={(x + ox, y + oy) for x, y in walk if (x, y) not in stairs},
                rooms={(x + ox, y + oy) for x, y in inroom},
                reach={(x + ox, y + oy): d for (x, y), d in reach.items()})


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


FLOOD_WATER = {161: (0xF1,)}                    # (the flooded village: its canoe water walked over)
PALMAP_OUT = None


_FLOORS = {}


def ts_banks(rom):
    """the looks' tilesets: {tkey: ROM bank}, a bank each after the maps; and {tileset number: FF1 tileset}"""
    fl = floors(rom)
    tsb, nb = {}, PG_END + 64
    for e in fl:
        if e['tkey'] not in tsb:
            tsb[e['tkey']] = nb; nb += 1
    assert nb <= PG_BATTLE0, 'post-game banks: maps and tilesets end at %d' % nb
    return tsb, {(b - 8) & 0xFF: (k[0] if isinstance(k, tuple) else 2) for k, b in tsb.items()}


def floors(rom, G=None):
    """the post-game's maps: [dict(map, shrine, rec, role, area, f (the floor), ov (map_pack overrides),
    tkey (its tileset: one bank per distinct tileset))]"""
    if 'all' in _FLOORS: return _FLOORS['all']
    _FLOORS['all'] = _floors(rom, G)
    return _FLOORS['all']


def _floors(rom, G=None):
    G = G or gba.Gba(GBA_PATH)
    to, ochr, opal = outdoor_tileset(rom)
    looks = {}
    out = []
    for i, (s, rec, look, role, area) in enumerate(PG_FLOORS):
        sh = shrines.SHRINES[s]
        n = sh['chests'] if role in ('floor', 'castle') else 0
        if role == 'castle': n += 5
        if isinstance(look, str):
            f = outdoor_floor(G, rec, look.split(':')[1], n)
            ov = dict(t=to, map=f['map'], pal=opal, chr=ochr)
            tkey = 'out'
        else:
            ts, maps, palmap = LOOKS[look]
            if look not in looks:
                pc = pieces_for(rom, ts, maps)
                looks[look] = (pc, look_tileset(rom, ts, pc))
            pc, t = looks[look]
            last = rec == sh['boss_maps'][-1]
            f = cave_floor(G, rec, role if role != 'castle' else 'floor', n, pc,
                           floor_chips=FLOOD_WATER.get(rec, ()), stairs_out=not last,
                           fixed=rec in sh.get('fixed', {}) or sh['key'] == 'EG' and role == 'boss')
            pal = rom.rd(data.BANK_SMINFO, data.SM_PAL + 0x30 * palmap, 0x30)
            chr_ = rom.rd(data.BANK_TILESETCHR, 0x8000 + 0x800 * ts, 0x800)
            ov = dict(t=t, map=f['map'], pal=pal, chr=chr_)
            tkey = (ts, t['prop'], t['tsa'], t['mt_pal'])
        objs = bytearray(45)
        k = 0
        for bk, (bname, bmap) in enumerate(sh['bosses']):    # the boss floor: an orb for each of its bosses
            if bmap != rec: continue
            bx, by, fl = f['bosses'][k]
            objs[3 * k:3 * k + 3] = bytes([PG_OBJ0 + bk, fl | bx, by])   # (in a room or not, still)
            k += 1
        if f.get('exit'):                           # (the light out: hidden until a boss is beaten)
            objs[3 * k:3 * k + 3] = bytes([PG_OBJ0 + 4, 0x40 | f['exit'][0], f['exit'][1]])
        ov['obj_gfx'] = {PG_OBJ0 + k: ORB_GFX for k in range(5)}
        ev = pgevents.build(rom).get(rec)
        if ev and role != 'boss':                   # (the floor's people: pgevents.py)
            assert len(ev['people']) <= 15, rec
            pl = pgevents.place(rec, f, ev['people'], f['walk'], f['reach'], ov['t']['prop'])
            assert not ev.get('gate') or None not in pl, 'floor %d: a gate\'s people must all be placed' % rec
            for n, at in enumerate(pl):
                if at is None: continue
                x, y, fl_ = at
                objs[3 * n:3 * n + 3] = bytes([pgevents.PG_NPC0 + n, fl_ | x, y])
                ov['obj_gfx'][pgevents.PG_NPC0 + n] = ev['people'][n]['gfx']
        ov['objs'] = bytes(objs)
        out.append(dict(map=PG_MAP0 + i, shrine=s, rec=rec, role=role, area=area, f=f, ov=ov, tkey=tkey))
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
    stairs_c = max(zero, key=lambda c: sum(abs(u - v) for u, v in zip(avg[c], base_col))) if zero else -1
    if cnt.get(stairs_c, 0) > 2: stairs_c = -1                  # (no stairs chip there: placed below)
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
    if base != 'sand' and (w > 60 or h > 60):      # (a large floor: its best 60 x 60, as cave_floor)
        x0, y0, x1, y1 = window(g, w, h, '.SgC', st)
        g = [row[x0:x1] for row in g[y0:y1]]
        w, h = x1 - x0, y1 - y0
        st = [(x, y) for y in range(h) for x in range(w) if g[y][x] == 'S']
    if not st:                                      # (no stairs chip: the walkable cell farthest from
        cs = [(x, y) for y in range(h) for x in range(w) if g[y][x] in '.gC']   # the bottom middle)
        c0 = min(cs, key=lambda q: abs(q[0] - w // 2) + abs(q[1] - (h - 1)))
        dd = bfs(set(cs), c0)
        fx, fy = max(dd, key=dd.get)
        g[fy][fx] = 'S'; st = [(fx, fy)]
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
    if len(d) * 3 < len(walk):                      # (the stairs in a pocket: moved into the largest part,
        parts, seen = [], set()                     #   as cave_floor)
        for c0 in walk:
            if c0 in seen: continue
            cc = bfs_w(c0); seen |= set(cc); parts.append(cc)
        big = max(parts, key=len)
        torus = lambda p, q: min(abs(p[0] - q[0]), W - abs(p[0] - q[0])) + min(abs(p[1] - q[1]), W - abs(p[1] - q[1]))
        new = min((q for q in big if G2[q[1]][q[0]] in '.g'), key=lambda q: torus(q, stairs))
        out[stairs[1]][stairs[0]] = O_SAND if base == 'sand' else O_GRASS
        out[new[1]][new[0]] = O_STAIRS
        stairs = new
        d = bfs_w(stairs)
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
        n_reach = len(d0)
        while len(picked) < n_chests and pool:
            def score(p):
                return min(min(abs(p[0] - q[0]), W - abs(p[0] - q[0])) + min(abs(p[1] - q[1]), W - abs(p[1] - q[1]))
                           for q in picked + [start, stairs])
            p = max(pool, key=lambda p: (score(p), d0.get(p, 0))); pool.remove(p)
            w0 = walk; walk = w0 - set(picked) - {p}             # (never across the way)
            cut = len(bfs_w(start)) < n_reach - len(picked) - 1
            walk = w0
            if not cut: picked.append(p)
        for i, p in enumerate(picked):
            out[p[1]][p[0]] = O_CHEST; chests.append((p[0], p[1], 'out'))
    return dict(map=bytes(v for row in out for v in row), start=start, chests=chests, bosses=[],
                stairs=[stairs], w=W, h=W, ox=0, oy=0, walk=walk - {stairs}, reach=bfs_w(start))


_BATTLES = {}


def battles(rom):
    """every shrine's battle sets (pgbattle.build, once): [(shrine, part, banks, result)]; banks after the maps
    and the looks' tilesets (PG_FREE on), Earthgift's where it has always been"""
    import pgbattle
    if 'all' in _BATTLES: return _BATTLES['all']
    G = gba.Gba(GBA_PATH)
    out = []
    nb = PG_BATTLE0
    for s, sh in enumerate(shrines.SHRINES):
        for part in range(len(sh['sets'])):
            if sh['key'] == 'EG': bk = pgbattle.PG_BANKS['EG']
            else:
                bk = (nb, nb + 1, nb + 3, nb + 5); nb += 6
            out.append((s, part, bk, pgbattle.build(rom, s, G, bk, part)))
    assert nb <= 256, nb
    _BATTLES['all'] = out
    return out


PG_BATTLE0 = 232                 # (the new shrines' battle banks: 232-249; build.py checks the maps and
                                 #   looks end below)


def gold_code(rom, n):
    """an amount of gil -> the FF1 gold chest code nearest to it (FF1's chest amounts)"""
    pr = rom.rd(0x0D, 0xBC00, 0x200)
    used = set(rom.rd(0x00, 0xB100, 0x100))
    best = min((c for c in range(0x6C, 0xB0) if c in used),
               key=lambda c: abs((pr[2 * c] | pr[2 * c + 1] << 8) - n))
    return best


def gift(rom, name):
    """a Dawn of Souls treasure -> the gift word pg.s gives (kind << 8 | value: 0 an FF1 code, 1 consumable,
    2 weapon id, 3 armour id; gold: FF1's nearest gold amount)"""
    import re
    m = re.match(r'(\d+) gil', name)
    if m: return gold_code(rom, int(m.group(1)))
    k, v = item_code(name)
    return k << 8 | v


T_HELD = "A mysterious power holds you back. Defeat what dwells on this floor first."


def pg_source(rom, bank=116):
    """the shrines' data in the post-game code bank (pg.s): boss depths and floors, pools, entrances, doors,
    orbs, boss formations / second forms / floors / picture rows, treasure lists per depth, fixed chests"""
    import pgbattle
    db = lambda xs: '            db ' + ', '.join('$%02X' % x for x in xs) + '\n'
    dw = lambda xs: '            dw ' + ', '.join(xs) + '\n'
    bt = battles(rom)
    S = shrines.SHRINES
    out = 'section bank %d, $5000\n' % bank
    bdep, bdmap, bform, b2, bfl, fy = [], [], [], [], [], []
    for s, sh in enumerate(S):
        deps = sorted(sh['boss_depths'])
        bdep += deps + [0] * (4 - len(deps))
        bdmap += [map_of(s, m) for m in sh['boss_maps']] + [0] * (4 - len(sh['boss_maps']))
        for k, (name, bmap) in enumerate(sh['bosses']):
            part = next(i for i, (_, bs) in enumerate(sh['sets']) if k in bs)
            r = next(r for (s_, p_, _, r) in bt if s_ == s and p_ == part)
            j = r['boss_names'].index(name)
            bform.append(r['boss_form0'] + j)
            sf = pgbattle.SECOND_FORM.get(name)
            b2.append(r['boss_form0'] + r['boss_names'].index(sf) if sf else 0)
            bfl.append(sh['boss_maps'].index(bmap))
            fy.append(0x03 if name in pgbattle.HANGING else 0x23)
    out += 'pg_bdep:\n' + db(bdep) + 'pg_bdmap:\n' + db(bdmap)
    out += 'pg_bform:\n' + db(bform) + 'pg_b2:\n' + db(b2) + 'pg_bfl:\n' + db(bfl) + 'pg_fy:\n' + db(fy)
    out += 'pg_npool:\n' + db([len(sh['pool']) for sh in S])
    out += 'pg_ent:\n' + db([map_of(s, sh['floors'][0][0]) for s, sh in enumerate(S)])
    out += 'pg_door:\n' + db([v for sh in S for v in sh['door']])
    out += 'pg_orb:\n' + ''.join('            db low(ORBS + %d)\n' % sh['orb'] for sh in S)
    out += 'pg_pool:\n' + dw(['pg_pool%d' % s for s in range(4)])
    for s, sh in enumerate(S):
        out += 'pg_pool%d:\n' % s + ''.join(db([map_of(s, g[0]), len(g)]) for g in sh['pool'])
    fixed = []                                      # (the fixed chests, all shrines: their gifts)
    out += 'pg_tl:\n' + dw(['pg_tl%d' % s for s in range(4)])
    for s, sh in enumerate(S):
        tr = shrines.TREASURE[sh['key']]
        rows = []
        for d in range(sh['depths'] + 1):
            a_, b_ = tr.get(d, ([], []))
            if d in sh['boss_depths']: a_, b_ = [], []
            labs = []
            for j, lst in enumerate((a_, b_)):
                g = [x for x in (gift(rom, n) for n in lst) if x is not None]
                if g:
                    labs.append('pg_tr%d_%d_%d' % (s, d, j))
                    rows.append('pg_tr%d_%d_%d:\n' % (s, d, j) + db([len(g)]) +
                                dw(['$%04X' % x for x in g]))
                else: labs.append('0')
            out_line = labs
            out += ('pg_tl%d:\n' % s if d == 0 else '') + dw(out_line)
        out += ''.join(rows)
        for m, name in sh.get('fixed', {}).items():
            fixed.append(gift(rom, name) or 0)
        if sh['key'] == 'EG': fixed.append(gift(rom, 'Megalixir'))
    out += 'pg_fixed:\n' + dw(['$%04X' % x for x in fixed + [0] * (8 - len(fixed))])
    return out


def fixed_index(s, rec):
    """the fixed chest number of shrine s's boss floor rec (pg_fixed's order)"""
    k = 0
    for s_, sh in enumerate(shrines.SHRINES):
        for m in sh.get('fixed', {}):
            if (s_, m) == (s, rec): return k
            k += 1
        if sh['key'] == 'EG':
            if s_ == s: return k
            k += 1
    return None


OW_CARDIA = 0x67                 # (FF1's Cardia cave mouth: Hellfire's door looks like it)
PG_ENT_MT2 = 0x7C


def overworld_patch():
    """the shrines' doors on the overworld: cave mouths with the post-game's entrance number"""
    data.OW_MT_PATCH[PG_ENT_MT] = (OW_CAVE, (0x0E, 0x80 | PG_ENT))
    data.OW_MT_PATCH[PG_ENT_MT2] = (OW_CARDIA, (0x0E, 0x80 | PG_ENT))
    for sh in shrines.SHRINES:
        x, y = sh['door']
        data.OW_ROW_PATCH.append((x, y, PG_ENT_MT2 if sh['key'] == 'HF' else PG_ENT_MT))


# Dawn of Souls' words (its message table, retranslated in the project's style; the official English
# a guide): 640 / 642 / 644 / 646 at the shrines' doors, 648-664 the bosses (652 / 653 Scarmiglione's two
# forms)
T_SEALED = ["This is the Earthgift Shrine. Long ago, they say, one could enter, but since the earth "
            "began to rot, no one has been able to get in.",
            "This is the Hellfire Chasm. Long ago, we elves proved our worth to be king by bringing back the "
            "treasure kept here. Now someone seems to have sealed it...",
            "Eek! A human! ... Huh? You won't hurt me? Then I'll tell you. This is the Lifespring Grotto. "
            "Long ago, they say, a human and a mermaid who fell in love lived here in secret.",
            "This is the Whisperwind Cove, where our ancestors laid their treasure to rest. But it has been "
            "sealed for a very long time."]
T_BOSS = {'Echidna': "You did well to come this far... but this is where your journey ends!",
          'Cerberus': "I'll grant you this much for making it so far... but here you die!",
          'Ahriman': "There is nothing anywhere that can stop me! You, too, will die here by my hand!",
          'Two-Headed Dragon': "Fwahahaha... Let everything vanish! Die, Warriors of Light!",
          'Scarmiglione': "Fshurrr... How happy... how happy I am... to bury you all... I am Scarmiglione of "
                          "Earth...! Now... it's feeding time!",
          'Cagnazzo': "Kukakakaka... Just the playmates I wanted. I get lonely, you see! Stay and play with me!",
          'Barbariccia': "Ohohoho... It seems I underestimated you, coming this far! I, Barbariccia of the "
                         "Wind, will kill you myself!",
          'Rubicante': "I am Rubicante of Fire... Let me see whether you are worthy warriors...",
          'Gilgamesh': "Where? Where in the world is the legendary sword? ...!! Is that it, what you've got "
                       "there!?",
          'Omega': "Intruders... Eliminate...",
          'Atomos': "Challengers, after a thousand years... Show me your strength... and defeat me...",
          'Shinryu': "...I am the one who hunts Omega...",
          'Typhon': "Fungah!",
          'Orthros': "Whaaat? You made it this far? I may be just a lowly octopus, but I won't lose to the "
                     "likes of you! Let's fight!!",
          'Phantom Train': "...You will come with us...",
          'Death Gaze': "...Giiiii..."}
T_BOSS2 = {'Scarmiglione': "You did well to kill me! Now tremble before Scarmiglione of Earth, more fearsome "
                           "still in death!"}
PGT_BANK = 125


def text_source():
    import text
    def db(b): return ''.join('            db ' + ', '.join('$%02X' % x for x in b[i:i + 16]) + '\n'
                              for i in range(0, len(b), 16))
    S = shrines.SHRINES
    out = 'section bank 116, $4E00\n'               # (the tables: read in pg.s's bank)
    out += 'pg_t_sealed:\n            dw ' + ', '.join('pg_ts%d' % s for s in range(4)) + '\n'
    names = [b for sh in S for b, _ in sh['bosses']]
    out += 'pg_t_boss:\n' + ''.join('            dw pg_tb%d\n' % k for k in range(16))
    out += 'pg_t_b2:\n' + ''.join('            dw %s\n' % ('pg_tc%d' % k if names[k] in T_BOSS2 else '0')
                                 for k in range(16))
    out += 'section bank %d, $4000\npg_t_held:\n' % PGT_BANK + db(text.encode_dialogue(T_HELD))
    for s in range(4):
        out += 'pg_ts%d:\n' % s + db(text.encode_dialogue(T_SEALED[s]))
    for k, n in enumerate(names):
        out += 'pg_tb%d:\n' % k + db(text.encode_dialogue(T_BOSS[n]))
        if n in T_BOSS2: out += 'pg_tc%d:\n' % k + db(text.encode_dialogue(T_BOSS2[n]))
    return out


# Dawn of Souls' new items. Consumables: Items-screen code $C0 + k, count at save page NEWIT + k, name at index
# 256 + k (names bank). Weapons / armour past FF1's 40: ids 41 on, their stats, classes and prices from the user's
# Dawn of Souls ROM (gba.weapon / gba.armour), names at name codes $6C on (weapons) / $84 on (armour): codes of
# FF1's gold amounts, whose names move to 256 + code (the chest message knows which: text.s). Names: the official
# Dawn of Souls English. Effects of the consumables (FINAL FANTASY wiki) as FF1's spells or our routines:
# (name, Dawn of Souls item number, battle magic (FF1 spell or our $5C-$5F; None: not in battle), MP effect in
# battle (md_mp: 1 a charge a level, 2 two, 3 all, 4 everyone's all, 5 all and HP), field use)
NEW_CONS = [('Hi-Potion', 1, 0x5C, 0, 'hp'), ('X-Potion', 2, 48, 0, 'hpfull'), ('Ether', 3, 0x5E, 1, 'ether'),
            ('Turbo Ether', 4, 0x5E, 2, 'ether2'), ('Dry Ether', 5, 0x5E, 3, 'etherx'),
            ('Elixir', 6, 48, 5, 'elixir'), ('Megalixir', 7, 0x5F, 4, 'mega'), ('Phoenix Down', 8, 33, 0, 'life'),
            ('Remedy', 9, 0x5D, 0, 'cure'), ('Eye Drops', 12, 8, 0, None), ('Echo Grass', 13, 27, 0, None),
            ('Emergency Exit', 14, None, 0, 'exit'), ("Spider's Silk", 18, 15, 0, None),
            ('White Fang', 19, 31, 0, None), ('Red Fang', 20, 20, 0, None), ('Blue Fang', 21, 22, 0, None),
            ('Light Curtain', 22, 58, 0, None), ('Red Curtain', 23, 18, 0, None),
            ('White Curtain', 24, 26, 0, None), ('Blue Curtain', 25, 10, 0, None),
            ('Lunar Curtain', 26, 11, 0, None), ("Hermes' Shoes", 27, 29, 0, None),
            ('Vampire Fang', 28, 21, 0, None), ('Cockatrice Claw', 29, 53, 0, None),
            ("Giant's Tonic", 30, 54, 0, None), ('Faerie Tonic', 31, 42, 0, None),
            ('Strength Tonic', 32, 14, 0, None), ('Protect Drink', 33, 2, 0, None), ('Speed Drink', 34, 29, 0, None),
            ('Golden Apple', 35, None, 0, 'apple10'), ('Silver Apple', 36, None, 0, 'apple5'),
            ('Soma Drop', 37, None, 0, 'soma'), ('Power Plus', 38, None, 0, 'str'),
            ('Stamina Plus', 39, None, 0, 'vit'), ('Mind Plus', 40, None, 0, 'int'), ('Speed Plus', 41, None, 0, 'agi'),
            ('Luck Plus', 42, None, 0, 'luck')]
NEW_PRICE = {'Hi-Potion': 150, 'X-Potion': 3000, 'Ether': 1500, 'Turbo Ether': 3000, 'Dry Ether': 5000,
             'Elixir': 30000, 'Megalixir': 50000, 'Phoenix Down': 500, 'Remedy': 1000, 'Eye Drops': 50,
             'Echo Grass': 50, 'Emergency Exit': 1000}
NEWIT = 0xB0                     # (save page offset of consumable 0's count)
C_CONS = 0xC0                    # (consumable k's Items-screen code)
WEAPON_NAMES = ['Ultima Weapon', 'Ragnarok', 'Murasame', 'Lightbringer', 'Rune Staff', 'Judgment Staff',
                'Dark Claymore', 'Duel Rapier', 'Braveheart', 'Deathbringer', 'Enhancer', 'Gigantaxe', 'Viking Axe',
                'Rune Axe', 'Ogrekiller', 'Kikuichimonji', 'Asura', 'Kotetsu', 'War Hammer', 'Assassin Dagger',
                'Orichalcum', 'Mage Masher', 'Gladius', "Sage's Staff"]           # (Dawn of Souls items 83-106)
ARMOUR_GBA = list(range(123, 134)) + list(range(143, 148)) + list(range(155, 164)) + list(range(172, 177))
ARMOUR_NAMES = ['Crystal Mail', "Thief's Armlet", 'Black Garb', 'Kenpogi', 'Power Vest', 'Red Jacket',
                "Sage's Surplice", 'Light Robe', 'Gaia Gear', "Bard's Tunic", 'Genji Armor', 'Genji Shield',
                'Crystal Shield', "Hero's Shield", 'Zephyr Cape', 'Elven Cloak', 'Genji Helm', 'Crystal Helm',
                'Black Cowl', 'Twist Headband', 'Tiger Mask', 'Feathered Cap', 'Red Cap', "Wizard's Hat",
                "Sage's Mitre", 'Crystal Gloves', "Thief's Gloves", 'Crystal Ring', "Angel's Ring", 'Genji Gloves']
N_WEAPON = 40 + len(WEAPON_NAMES)
N_ARMOUR = 40 + len(ARMOUR_NAMES)


def weapon_code(n): return n + 27 if n <= 40 else n + 67      # (weapon id n -> name code)
def armour_code(n): return n + 67 if n <= 40 else n + 91


def item_code(name):
    """a Dawn of Souls item -> (kind, value): 0 an FF1 code, 1 consumable k, 2 weapon id, 3 armour id"""
    ff1 = {'Potion': 0x19, 'Antidote': 0x1A, 'Gold Needle': 0x1B, 'Tent': 0x17, 'Cottage': 0x18}
    if name in ff1: return 0, ff1[name]
    for k, c in enumerate(NEW_CONS):
        if c[0] == name: return 1, k
    if name in WEAPON_NAMES: return 2, 41 + WEAPON_NAMES.index(name)
    if name in ARMOUR_NAMES: return 3, 41 + ARMOUR_NAMES.index(name)
    import sys
    sys.path.insert(0, os.path.join(HERE, '..', '..', 'translations'))
    import ff1_items                                 # (FF1's own: by the project's names)
    alias = {'Crystal Helm': None}
    for c in range(0x1C, 0x6C):
        if ff1_items.T.get(c) == name: return 0, c
    raise KeyError(name)


_ICON_GBA = {0x40: 'sword', 0x41: 'sword', 0x42: 'knife', 0x43: 'claw', 0x44: 'axe', 0x45: 'hammer', 0x46: 'staff'}


def names_patch(rom):
    """the new items in the names bank (names.py): names, prices, the gear's stats (from the user's GBA ROM)"""
    import names
    names.EXTRA = {256 + k: ('item', c[0]) for k, c in enumerate(NEW_CONS)}
    if not GBA_PATH: return
    G = gba.Gba(GBA_PATH)
    inames = gba.item_names(G)
    e0 = names.equip_tables(rom)
    for i, n in enumerate(WEAPON_NAMES):            # weapons: Dawn of Souls' record in FF1's 8 bytes; the
        wid = 41 + i                                #   battle picture of FF1's best weapon of its kind
        w = gba.weapon(G, 40 + i)
        icon = _ICON_GBA.get(inames[83 + i][0] & 0xFF, 'sword')
        best = max((k for k in range(40) if names.WPN_GFX.get(e0['wstat'][8 * k + 6] & 0xFC, 'sword') == icon),
                   key=lambda k: e0['wstat'][8 * k + 1], default=39)
        sp = pgbattle_spell(w['spell'])
        crit = w['crit'] if 0 < w['crit'] <= 50 else 10
        st = bytes([w['hit'], w['dmg'], crit, sp, w['element'], w['category']]) + e0['wstat'][8 * best + 6:8 * best + 8]
        names.WEAPON_EXTRA[wid] = (st, w['perm'])
        names.OVERRIDE[weapon_code(wid)] = (icon, n)
        names.PRICE[weapon_code(wid)] = min(w['price'] or 60000, 65000)   # (FF1's prices: 16 bits)
    for i, n in enumerate(ARMOUR_NAMES):
        aid = 41 + i
        g = ARMOUR_GBA[i]
        a = gba.armour(G, g - 107)
        ty = next(t for lo, hi, t in gba.ARMOUR_TYPES if lo <= g < hi)
        icon = ['armour', 'shield', 'helmet', 'gloves'][ty]
        if 'Ring' in n or 'Armlet' in n: icon = 'bracelet'
        if n in ("Sage's Surplice", 'Light Robe', 'Black Garb', 'Kenpogi', 'Red Jacket', "Bard's Tunic", 'Gaia Gear',
                 'Power Vest'): icon = 'robe'
        names.ARMOUR_EXTRA[aid] = (bytes([a['weight'], a['defence'], a['element'], 0]), a['perm'], ty)
        names.OVERRIDE[armour_code(aid)] = (icon, n)
        names.PRICE[armour_code(aid)] = min(a['price'], 65000) if a['price'] > 2 else 45000


def pgbattle_spell(s):
    """a Dawn of Souls weapon / armour spell byte -> FF1's (spell number + 1; 0 none)"""
    import pgbattle
    f = pgbattle.gba_spell(s) if s else None
    return f + 1 if f is not None else 0


USES = [None, 'hp', 'cure', 'ether', 'mega', 'apple5', 'hpfull', 'ether2', 'etherx', 'elixir', 'life', 'exit',
        'apple10', 'soma', 'str', 'vit', 'int', 'agi', 'luck']


def items_source():
    """the item tables the engine reads (src/pg.s): the Items screen's orders (Use / after Sort), the new
    consumables' uses, the battle Medicine list (md_tab, bank 104)"""
    db = lambda xs: '            db ' + ', '.join('$%02X' % x for x in xs) + '\n'
    codes = [C_CONS + k for k in range(len(NEW_CONS))]
    ord0 = [0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B] + codes
    heal = [0x19, 0x1A, 0x1B] + [C_CONS + k for k, c in enumerate(NEW_CONS)
                                 if c[4] in ('hp', 'hpfull', 'cure', 'mega', 'ether', 'ether2', 'etherx', 'elixir', 'life')]
    ord1 = heal + [c for c in ord0 if c not in heal]
    out = ('section bank 2, $5EFE\nit_ord0:\n' + db(ord0) + 'it_ord1:\n' + db(ord1) +
           'it_utab:\n' + db([USES.index(c[4]) for c in NEW_CONS]))
    out += 'N_ARMOUR = %d\nN_WEAPON = %d\nC_CONS = $%02X\n' % (N_ARMOUR, N_WEAPON, C_CONS)
    out += 'IT_NORD = %d\nN_NEWIT = %d\nNEWIT = unsram + $%02X\n' % (len(ord0), len(NEW_CONS), NEWIT)
    # Medicine: count's address (low byte, page $D0), name (battle attack names), magic, MP effect; Potion,
    # Antidote first
    md = [(0x20 + 0x19, 0x40, 0x40, 0), (0x20 + 0x1A, 0x41, 0x41, 0)]
    for k, (n, gi, mg, mp, _) in enumerate(NEW_CONS):
        if mg is not None:
            md.append((NEWIT + k, 0x5C + len(md) - 2, mg, mp))
    out += 'section bank 104, $7C00\nmd_tab:\n' + ''.join(db(list(e)) for e in md)
    out += 'MD_N = %d\n' % len(md)
    return out


def battle_names():
    """the Medicine entries' names after FF1's attack names (battle.py: $5C on)"""
    return [c[0] for c in NEW_CONS if c[2] is not None]


STATUE_BANK = 127               # the statues' tiles (CGB $4000, DMG $4400: 256 bytes each)
ST_TILE = 0x70                  # the statue's sprite tiles on the overworld ($70-$7F, after the vehicles')


def statue(rom, k=0):
    """the statue before a sealed shrine's door: FF1's own Fiend k (Lich 0, Kary 1, Kraken 2, Tiamat 3: fiend picture k,
    the user's ROM) as grey stone, 32 x 32: (CGB tiles, DMG tiles, the OBJ palette 0-3 it uses on the Color)"""
    import battle
    forms = rom.rd(battle.BANK_DOMAINS, battle.FORMATIONS, 128 * 16)
    f = next(j for j in range(128) if forms[16 * j] >> 4 == 3 and forms[16 * j + 1] == k)
    page = forms[16 * f] & 15
    chr_ = rom.rd(battle.BANK_BATTLECHR + (page >> 3), 0x8000 + 0x800 * (page & 7), 0x800)
    tsa = rom.rd(battle.BANK_DOMAINS, 0x92E0 + 0x50 * k, 64)
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
    ys = [y for y in range(64) for x in range(64) if px[y][x] is not None]   # (the picture's bottom on the
    sh = 64 - 1 - max(ys)                                                    #   statue's: standing on its tile)
    if sh > 0: px = [[None] * 64] * sh + px[:64 - sh]
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


def learn_pieces(rom, ts, only=None):
    """an FF1 tileset's floor-building pieces, learnt from FF1's own maps that use it: the corridor floor (the
    commonest walkable floor outside the room palette), the void (the commonest piece with nothing walkable
    round it), the wall piece for each side the corridor is on (right / left / above / below, then the corners
    by a diagonal), the stairs down (teleport) and up (warp). Rooms (00-08), doors (36 / 37 / 3A) are FF1's own
    numbers in every tileset."""
    import collections
    t = data.tileset_pack(rom, ts)
    P = lambda mt: t['prop'][2 * mt]
    rpal = t['mt_pal'][0x01]
    walk = lambda mt: (not (P(mt) & 1)) or (P(mt) & 0x1E) in (2, 4, 6)
    tsof = [rom.rd(data.BANK_SMINFO, data.TILESETS + m) for m in range(data.N_MAPS)]
    maps = [m for m in range(data.N_MAPS) if tsof[m] == ts and (only is None or m in only)]
    fl, void, st, up = collections.Counter(), collections.Counter(), collections.Counter(), collections.Counter()
    for m in maps:
        mp = data.std_map(rom, m)
        for v in mp:
            if (P(v) & 0x1E) == 0x0A and t['mt_pal'][v] != rpal: fl[v] += 1      # (random battles: a floor)
            if (P(v) & 0xC0) == 0x80: st[v] += 1
            if (P(v) & 0xC0) == 0x40: up[v] += 1
    floor = fl.most_common(1)[0][0]
    pat = collections.defaultdict(collections.Counter)
    for m in maps:
        mp = data.std_map(rom, m)
        at = lambda x, y: mp[64 * (y & 63) + (x & 63)]
        for y in range(64):
            for x in range(64):
                v = at(x, y)
                if v == floor: continue
                n4 = tuple(at(x + a, y + b) == floor for a, b in ((1, 0), (-1, 0), (0, -1), (0, 1)))
                d4 = tuple(at(x + a, y + b) == floor for a, b in ((1, 1), (-1, 1), (1, -1), (-1, -1)))
                if not any(n4) and not any(d4):
                    if (P(v) & 0xC0) == 0 and t['mt_pal'][v] != rpal: void[v] += 1
                    continue
                if walk(v): continue
                pat[(n4, d4 if not any(n4) else None)][v] += 1
    def best(key, dflt):
        c = pat.get(key)
        return c.most_common(1)[0][0] if c else dflt
    F, T = False, True
    wh = best(((F, F, T, F), None), None) or best(((F, F, F, T), None), floor)
    return dict(floor=floor, void=void.most_common(1)[0][0] if void else 0,
                wl=best(((T, F, F, F), None), wh), wr=best(((F, T, F, F), None), wh),
                wtop=best(((F, F, F, T), None), wh), wbot=best(((F, F, T, F), None), wh),
                ctl=best(((F, F, F, F), (T, F, F, F)), wh), ctr=best(((F, F, F, F), (F, T, F, F)), wh),
                stairs=st.most_common(1)[0][0] if st else None, up=up.most_common(1)[0][0] if up else None)


def pieces_for(rom, ts, only=None):
    """everything cave_floor needs for a floor in FF1's tileset ts (learn_pieces, then the room floor, the tile
    below a door, the chests: four of FF1's for rooms and four free metatiles for corridor chests)"""
    import collections
    pc = dict(EARTH_PIECES) if ts == 2 else {}
    try:
        lp = learn_pieces(rom, ts, only)
    except IndexError:                              # (no battle floor there: the whole tileset's)
        lp = learn_pieces(rom, ts)
    if only is not None and (lp['stairs'] is None or lp['up'] is None):   # (a one-floor place: the tileset's)
        whole = learn_pieces(rom, ts)
        lp['stairs'] = lp['stairs'] if lp['stairs'] is not None else whole['stairs']
        lp['up'] = lp['up'] if lp['up'] is not None else whole['up']
    t = data.tileset_pack(rom, ts)
    P = lambda mt: t['prop'][2 * mt]
    rpal = t['mt_pal'][0x01]
    tsof = [rom.rd(data.BANK_SMINFO, data.TILESETS + m) for m in range(data.N_MAPS)]
    used, roomfl, below = collections.Counter(), collections.Counter(), collections.Counter()
    for m in range(data.N_MAPS):
        if tsof[m] != ts: continue
        mp = data.std_map(rom, m)
        for v in mp: used[v] += 1                   # (free metatiles: unused in all of the tileset's maps)
        if only is not None and m not in only: continue
        for i, v in enumerate(mp):
            if t['mt_pal'][v] == rpal and not (P(v) & 1) and (P(v) & 0xC0) == 0 and v not in range(9): roomfl[v] += 1
            if v == DOOR and i + 64 < 4096: below[mp[i + 64]] += 1
    chests = [mt for mt in range(128) if (P(mt) & 0x1E) == 0x08]
    mine = {v for v in lp.values() if isinstance(v, int)}
    free = [mt for mt in range(9, 128) if not used[mt] and mt not in chests and mt not in DOOR_MTS_ALL and mt not in mine]
    if ts != 2:
        pc.update(lp)
        pc.update(roomfl=roomfl.most_common(1)[0][0] if roomfl else lp['floor'],
                  bt=B_T, bb=B_B, bl=B_L, br=B_R, btl=B_TL, btr=B_TR, bbl=B_BL, bbr=B_BR, door=DOOR,
                  below=below.most_common(1)[0][0] if below else lp['floor'], lava=lp['floor'],
                  chest_room=tuple(chests[:4]), chest_corr=tuple(free[-4:]))
    return pc


DOOR_MTS_ALL = (0x36, 0x37, 0x3A, 0x3B)


def look_tileset(rom, ts, pc):
    """FF1's tileset ts with the post-game's properties (cave_tileset, any tileset): stairs down = teleport 0,
    the chest slots, the corridor chests as FF1's chest in the floor's palette"""
    t = data.tileset_pack(rom, ts)
    prop = bytearray(t['prop']); pal = bytearray(t['mt_pal']); tsa = bytearray(t['tsa'])
    prop[2 * pc['stairs']:2 * pc['stairs'] + 2] = bytes([0x80, 0x00])
    for i, mt in enumerate(pc['chest_room']):
        prop[2 * mt:2 * mt + 2] = bytes([0x09, 0x04 + i])
    src = pc['chest_room'][0]
    for i, mt in enumerate(pc['chest_corr']):
        prop[2 * mt:2 * mt + 2] = bytes([0x09, i])
        pal[mt] = pal[pc['floor']]
        for k in range(4): tsa[128 * k + mt] = tsa[128 * k + src]
    return dict(prop=bytes(prop), tsa=bytes(tsa), mt_pal=bytes(pal), cgb_tiles=t['cgb_tiles'])


# Dawn of Souls' floor tilesets -> the FF1 look they imitate: (FF1 tileset, FF1 maps to learn its pieces from,
# the FF1 map whose palette the floor takes)
LOOKS = {0x01: (2, (29, 30, 31, 32), 29), 0x0C: (2, (60,), 60), 0x0D: (2, (33, 34, 35, 36), 33),
         0x09: (5, (42, 43, 44, 45, 46), 42), 0x21: (6, (47, 48, 49, 50, 51), 47), 0x0B: (7, tuple(range(52, 60)), 52),
         0x16: (3, (15, 37, 38), 15), 0x1C: (3, (18,), 18), 0x1D: (3, (17, 39), 17), 0x20: (4, (22, 27, 28), 22)}
