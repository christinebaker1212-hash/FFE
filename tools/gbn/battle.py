"""FF1 native build: battle data, read from the user's ROM at build time (the tables FF1's
battle code reads, at the addresses the disassembly names; the Japanese ROM keeps them in
the same places, checked by their contents' shape), plus the project's English names and
messages. Our own layout of the data banks:

bank BTL_DATA:
  $4000 formations (128 x 16)          $4800 encounter domains (64 x 8)
  $4A00 encounter rates (by map)        $4C00 enemy stats (128 x 20)
  $5600 enemy AI (44 x 16)              $5900 magic data ($5C x 8)
  $5C00 magic battle messages ($5C)     $5C80 battle palettes (64 x 4)
  $5E00 DMG shades per formation (128 x 8: palette A, palette B -> shade per colour index)
  $6200 enemy names: 128 pointers, strings     $6C00 battle messages: 80 pointers, strings
  $4B00 the damage numbers' glyphs (our own pixel art, not game data: 0-9, M, I, S, !; GB tiles,
  ink colour 1 with a colour 3 outline)
banks ENEMY_CHR, +1: enemy graphics pages 0-7 / 8-15 at $4000 + $800 page (tile t at
  + 16 t, t = $12-$7F; GB 2bpp, colour indices as on the NES)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'translations'))
import data

BTL_DATA, ENEMY_CHR = 92, 93
BANK_DOMAINS, FORMATIONS, DOMAINS = 0x0B, 0x8400, 0x8000
BANK_BTLC, ENEMY_STATS, ENEMY_AI, MAGIC_DATA, MAGIC_MSGS, BTL_PALS = 0x0C, 0x8520, 0x9020, 0x81E0, 0x84C0, 0x8F20
BANK_BATTLECHR = 0x07


def enc(s):
    import text
    return bytes(text.code_of(ch) for ch in s)


def battle_rates(rom):
    """FF1 lut_BattleRates (bank 0B): found after the formations' end by the disassembly's
    order (lut_BattleFormations then lut_BattleRates, one byte per map)"""
    return rom.rd(BANK_DOMAINS, FORMATIONS + 0x800, 64)


def dmg_shades(rom):
    """per formation: the DMG shade of each colour index of its two enemy palettes, by the
    brightness grouping of the field (data.map_shades) over both palettes and the window"""
    out = bytearray()
    for f in range(128):
        fd = rom.rd(BANK_DOMAINS, FORMATIONS + 16 * f, 16)
        pa = list(rom.rd(BANK_BTLC, BTL_PALS + 4 * fd[10], 4))
        pb = list(rom.rd(BANK_BTLC, BTL_PALS + 4 * fd[11], 4))
        win = [0x0F, 0x00, 0x0F, 0x30]
        msh = data.map_shades([win, pa, pb, win])
        sa = [msh[c] for c in pa]; sb = [msh[c] for c in pb]
        sa[0] = sb[0] = 3                          # colour 0: the black battlefield
        out += bytes(sa) + bytes(sb)
    return bytes(out)


def strtab(base, strings):
    ptrs = bytearray(); body = bytearray()
    a0 = base + 2 * len(strings)
    for s in strings:
        ptrs += (a0 + len(body)).to_bytes(2, 'little'); body += s + b'\0'
    return bytes(ptrs) + bytes(body)


# the damage numbers (owner, 2026-11-22: pop and drop as in FF3, nicer to look at): bold 6 x 6
# glyphs, drawn here (no game data), with a 1-pixel outline all round, as 8 x 8 sprite tiles
DN_GLYPHS = [
    ['.####.', '##..##', '##..##', '##..##', '##..##', '.####.'],    # 0
    ['..##..', '.###..', '..##..', '..##..', '..##..', '.####.'],    # 1
    ['.####.', '##..##', '...##.', '..##..', '.##...', '######'],    # 2
    ['#####.', '....##', '..###.', '....##', '....##', '#####.'],    # 3
    ['..###.', '.####.', '##.##.', '######', '...##.', '...##.'],    # 4
    ['######', '##....', '#####.', '....##', '##..##', '.####.'],    # 5
    ['.####.', '##....', '#####.', '##..##', '##..##', '.####.'],    # 6
    ['######', '....##', '...##.', '..##..', '..##..', '..##..'],    # 7
    ['.####.', '##..##', '.####.', '##..##', '##..##', '.####.'],    # 8
    ['.####.', '##..##', '##..##', '.#####', '....##', '.####.'],    # 9
    ['#....#', '##..##', '######', '##..##', '##..##', '##..##'],    # M
    ['.####.', '..##..', '..##..', '..##..', '..##..', '.####.'],    # I
    ['.#####', '##....', '.####.', '....##', '....##', '#####.'],    # S
    ['..##..', '..##..', '..##..', '..##..', '......', '..##..'],    # !
]


def dn_tiles():
    out = bytearray()
    for g in DN_GLYPHS:
        ink = [[0] * 8 for _ in range(8)]
        for y, row in enumerate(g):
            for x, c in enumerate(row):
                if c == '#': ink[y + 1][x + 1] = 1
        lo = []; hi = []
        for y in range(8):
            a = b = 0
            for x in range(8):
                o = not ink[y][x] and any(0 <= y + dy < 8 and 0 <= x + dx < 8 and ink[y + dy][x + dx]
                                          for dy in (-1, 0, 1) for dx in (-1, 0, 1))
                a = a << 1 | (1 if ink[y][x] or o else 0)          # colour 1 ink, 3 outline
                b = b << 1 | (1 if o else 0)
            lo.append(a); hi.append(b)
        for y in range(8): out += bytes([lo[y], hi[y]])
    return bytes(out)


def data_bank(rom):
    import ff1_monsters, ff1_battle
    b = bytearray(b'\xff' * 0x4000)
    def put(a, d): b[a - 0x4000:a - 0x4000 + len(d)] = d
    put(0x4000, rom.rd(BANK_DOMAINS, FORMATIONS, 128 * 16))
    put(0x4800, rom.rd(BANK_DOMAINS, DOMAINS, 64 * 8))
    put(0x4A00, battle_rates(rom))
    put(0x4B00, dn_tiles())
    put(0x4C00, rom.rd(BANK_BTLC, ENEMY_STATS, 128 * 20))
    put(0x5600, rom.rd(BANK_BTLC, ENEMY_AI, 44 * 16))
    put(0x5900, rom.rd(BANK_BTLC, MAGIC_DATA, 0x5C * 8))
    put(0x5C00, rom.rd(BANK_BTLC, MAGIC_MSGS, 0x5C))
    put(0x5C80, rom.rd(BANK_BTLC, BTL_PALS, 64 * 4))
    put(0x5E00, dmg_shades(rom))
    names = strtab(0x6200, [enc(n) for n in ff1_monsters.M[:128]])
    assert len(names) <= 0x600
    put(0x6200, names)
    put(0x6800, bestiary_tab(rom))                                   # the bestiary (extras.s)
    put(0x6A00, rom.rd(BANK_DOMAINS, 0x92E0, 0x140))                 # data_FiendTSA (4 x $50)
    put(0x6B40, rom.rd(BANK_DOMAINS, 0x9420, 0xC0))                  # data_ChaosTSA
    msgs = strtab(0x6C00, [enc(ff1_battle.B.get(k, '')) for k in range(80)])
    assert len(msgs) <= 0x1100
    put(0x6C00, msgs)
    import names, ff1_items
    an = [names.name_codes(rom, 176 + k) for k in range(64)]          # spell / potion / attack names
    an += [enc(ff1_items.T.get(25, '')), enc(ff1_items.T.get(26, ''))]
    an += [enc(r['en']) for r in ff1_monsters.rows[:26]]
    at = strtab(0x7400, an)
    assert len(at) <= 0x600
    put(0x7400, at)
    put(0x7A00, rom.rd(BANK_DOMAINS, 0x9094, 6 * 49 * 2))           # data_LevelUpData_Raw
    b11 = rom.prg[11 * 0x4000:12 * 0x4000]                           # level-up hit / magic
    i = b11.find(bytes([3, 2, 3, 2, 1, 1, 3, 2, 3, 2, 1, 1]))       #   defence bonuses
    assert i >= 0
    put(0x7C80, b11[i:i + 24])
    fix = rom.prg[15 * 0x4000:16 * 0x4000]
    put(0x7D00, fix[0xF100 - 0xC000:0xF100 - 0xC000 + 256])         # lut_RNG
    put(0x7E00, fix[rng_table(fix) - 0xC000:][:256])                 # BattleRNG's table
    i = fix.find(bytes([0] * 12 + [1] * 12 + [2] * 12))             # lut_FormationWeight
    assert i >= 0
    put(0x7F00, fix[i:i + 64])
    import re                                                       # lut_RespondDelay (found
    b11 = rom.prg[11 * 0x4000:12 * 0x4000]                          #   by its use: LDY rate /
    m = re.search(rb'(?:\xAC\xFA\x00|\xA4\xFA)\xB9(..)\x8D', b11, re.S)  #   LDA lut,Y / STA)
    assert m, 'respond delay table not found'
    a = int.from_bytes(m.group(1), 'little') - 0x8000
    assert len(b11[a:a + 8]) == 8
    put(0x7FF0, bytes([52, 44, 36, 30, 24, 16, 8, 1]))             # (owner, 2026-11-23: the
                                                                    #   remake's timing, 52
                                                                    #   frames at speed 1;
                                                                    #   FF1: 120 .. 1)
    return bytes(b)


def bestiary_tab(rom):
    """per enemy id: a formation that shows it (pure 9-small / 4-large first, then mixed,
    fiend, Chaos), its graphic | palette bit as bt_egp, the battle type, 0; $FF: in none"""
    t = [None] * 128
    for pref in ((0, 1), (2,), (3, 4)):
        for f in range(128):
            fd = rom.rd(BANK_DOMAINS, FORMATIONS + 16 * f, 16)
            ty = fd[0] >> 4
            if ty not in pref:
                continue
            for g in range(1 if ty >= 3 else 4):
                e = fd[2 + g]
                q = fd[6 + g] | (fd[14 + g] if g < 2 else 0)
                if e >= 128 or t[e] is not None or (ty < 3 and q == 0):
                    continue
                gr = (fd[1] >> (2 * g)) & 3
                egp = (gr << 6) | ((fd[13] >> (7 - g)) & 1)
                t[e] = bytes([f, egp if ty < 3 else 0, ty, 0])
    return b''.join(x or b'\xff\xff\xff\x00' for x in t)


def rng_table(fix):
    """BattleRNG (LDX state / INC state / LDA table,X / RTS) in the fixed bank: its table"""
    for i in range(3, len(fix) - 7):
        if fix[i] == 0xEE and fix[i - 3] == 0xAE and fix[i - 2:i] == fix[i + 1:i + 3] and \
           fix[i + 3] == 0xBD and fix[i + 6] == 0x60:
            return fix[i + 4] | fix[i + 5] << 8
    raise AssertionError('BattleRNG not found')


def chr_banks(rom):
    """the 16 enemy graphics pages as GB tiles (colour indices)"""
    out = {}
    for half in range(2):
        blob = bytearray(b'\xff' * 0x4000)
        for p in range(8):
            page = rom.rd(BANK_BATTLECHR + half, 0x8000 + 0x800 * p, 0x800)
            for t in range(0x12, 0x80):
                blob[0x800 * p + 16 * t:0x800 * p + 16 * t + 16] = data.gb_tile(page[16 * t:16 * t + 16])
        out[ENEMY_CHR + half] = bytes(blob)
    return out


ESIL_BANK, HITL_BANK = 100, 102


def sil_banks(rom):
    """silhouettes of the enemy graphics (an acting enemy flashes, owner 2026-11-22, as in the
    WonderSwan Color remake): for each page, each of FF1's four graphics (small 4 x 4 at $12 /
    $22, large 6 x 6 at $32 / $56) as one picture: its pixels colour 2, a one-pixel outline
    round it (inside the graphic's box) colour 1; same layout as ENEMY_CHR"""
    out = {}
    for half in range(2):
        blob = bytearray(b'\xff' * 0x4000)
        for p in range(8):
            page = rom.rd(BANK_BATTLECHR + half, 0x8000 + 0x800 * p, 0x800)
            for t0, n in ((0x12, 4), (0x22, 4), (0x32, 6), (0x56, 6)):
                W = 8 * n
                m = [[0] * W for _ in range(W)]
                for r in range(n):
                    for c in range(n):
                        t = t0 + r * n + c
                        for y in range(8):
                            bits = page[16 * t + y] | page[16 * t + 8 + y]
                            for x in range(8):
                                m[8 * r + y][8 * c + x] = bits >> (7 - x) & 1
                o = [[0] * W for _ in range(W)]
                for y in range(W):
                    for x in range(W):
                        if not m[y][x]:
                            o[y][x] = int(any(0 <= y + dy < W and 0 <= x + dx < W and m[y + dy][x + dx]
                                              for dy in (-1, 0, 1) for dx in (-1, 0, 1)))
                for r in range(n):
                    for c in range(n):
                        t = t0 + r * n + c
                        a = 0x800 * p + 16 * t
                        for y in range(8):
                            lo = hi = 0
                            for x in range(8):
                                yy, xx = 8 * r + y, 8 * c + x
                                lo = lo << 1 | o[yy][xx]
                                hi = hi << 1 | m[yy][xx]
                            blob[a + 2 * y] = lo
                            blob[a + 2 * y + 1] = hi
        out[ESIL_BANK + half] = bytes(blob)
    return out


# the hit count over the attacker ("2 HITS", as the WonderSwan Color remake shows it): our own
# small letters (no game data), three 8 x 8 sprite tiles per count 1-39, ink colour 1 with a
# colour 3 outline, right-aligned so it ends next to the attacker's side
HL_DIG = {'0': ['###', '#.#', '#.#', '#.#', '#.#', '###'], '1': ['.#.', '##.', '.#.', '.#.', '.#.', '###'],
          '2': ['###', '..#', '###', '#..', '#..', '###'], '3': ['###', '..#', '.##', '..#', '..#', '###'],
          '4': ['#.#', '#.#', '#.#', '###', '..#', '..#'], '5': ['###', '#..', '###', '..#', '..#', '###'],
          '6': ['###', '#..', '###', '#.#', '#.#', '###'], '7': ['###', '..#', '..#', '.#.', '.#.', '.#.'],
          '8': ['###', '#.#', '###', '#.#', '#.#', '###'], '9': ['###', '#.#', '###', '..#', '..#', '###']}
HL_LET = {'H': ['#.#', '#.#', '###', '#.#', '#.#'], 'I': ['#', '#', '#', '#', '#'],
          'T': ['###', '.#.', '.#.', '.#.', '.#.'], 'S': ['.##', '#..', '.#.', '..#', '##.']}


def hit_tiles():
    out = bytearray()
    for n in range(1, 40):
        word = 'HIT' if n == 1 else 'HITS'
        cols = []                                   # columns of 6 rows (letters bottom-aligned)
        def put(g, top):
            for x in range(len(g[0])):
                col = [0] * 6
                for y, row in enumerate(g):
                    col[top + y] = int(row[x] == '#')
                cols.append(col)
            cols.append([0] * 6)
        for d in str(n): put(HL_DIG[d], 0)
        cols.append([0] * 6)
        for ch in word: put(HL_LET[ch], 1)
        cols.pop()
        assert len(cols) <= 22, n
        ink = [[0] * 24 for _ in range(8)]
        x0 = 23 - len(cols)                         # right-aligned, outline column 23
        for x, col in enumerate(cols):
            for y in range(6):
                ink[1 + y][x0 + x] = col[y]
        for t in range(3):
            for y in range(8):
                lo = hi = 0
                for x in range(8):
                    X = 8 * t + x
                    i = ink[y][X]
                    o = not i and any(0 <= y + dy < 8 and 0 <= X + dx < 24 and ink[y + dy][X + dx]
                                      for dy in (-1, 0, 1) for dx in (-1, 0, 1))
                    lo = lo << 1 | (1 if i or o else 0)
                    hi = hi << 1 | (1 if o else 0)
                out += bytes([lo, hi])
    return bytes(out)


def vwf_source():
    """the small font for battle windows (our own glyphs, tools/latin_font.py: condensed where
    there is one) as assembler data: per code $21-$8B a width and 8 row bytes (left-aligned);
    $80-$89 small digits, $8A small slash, $8B an arrow"""
    sys.path.insert(0, os.path.join(HERE, '..'))
    import latin_font as L
    dig3 = {
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
        '/': ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."]}
    arrow = ["......", "...#..", "....#.", "######", "....#.", "...#..", "......"]
    out = []
    for code in range(0x21, 0x8C):
        rows = None
        if 0x80 <= code <= 0x89: rows = dig3[str(code - 0x80)]
        elif code == 0x8A: rows = dig3['/']
        elif code == 0x8B: rows = arrow
        if rows is not None:
            cols = [[1 if y < 7 and rows[y][x] == '#' else 0 for y in range(8)] for x in range(len(rows[0]))]
        else:
            ch = '…' if code == 0x7F else chr(code)
            if ch in L.COND: cols = L._glyph_cols(ch, L.COND)
            elif ch in L.G: cols = L._glyph_cols(ch, L.G)
            else: cols = []
        out.append(len(cols))
        for y in range(8):
            out.append(sum(cols[x][y] << (7 - x) for x in range(len(cols))))
    return 'vwf_glyphs:\n' + ''.join('            db ' + ', '.join(str(v) for v in out[k:k + 18]) + '\n'
                                    for k in range(0, len(out), 18))


BOBJ_BANK = 96


def obj_bank(rom):
    """bank BOBJ_BANK: FF1's battle object graphics (lut_BatObjCHR, sprite tiles $80-$FF: weapon
    swings $80-$AF, spells $B0-$EF, cursor, explosions $F4-$FF) for DMG ($4000, ranked: weapons
    and explosions by FF1's weapon palette c / c - $10 / c - $20, spells by its magic palette
    c / c - $10 / white) and CGB ($4800, raw); $5000 FF1's pose TSA (8 x 4) and weapon swing
    TSA (2 x 8), found through DrawCharacter's operand"""
    import re
    import ui
    blob = bytearray(b'\xff' * 0x4000)
    src = rom.rd(ui.BANK_BTLCHR, ui.BAT_OBJ, 0x800)
    for t in range(128):
        t16 = src[16 * t:16 * t + 16]
        pal = [0x0F, 0x10, 0x00, 0x30] if 0x30 <= t < 0x70 else [0x0F, 0x30, 0x10, 0x00]
        blob[16 * t:16 * t + 16] = data.spr_rank_tile(t16, pal)
        blob[0x800 + 16 * t:0x800 + 16 * t + 16] = data.gb_tile(t16)
    b12 = rom.prg[12 * 0x4000:13 * 0x4000]
    m = [m for m in re.finditer(rb'\xB9..\x18\x7D(..)\x8D', b12, re.S) if m.group(1)[1] >= 0x80]
    assert len(m) == 1, 'pose table not found'
    a = int.from_bytes(m[0].group(1), 'little') - 0x8000
    blob[0x1000:0x1030] = b12[a:a + 0x30]
    return bytes(blob)


TRANS_BANK = 103
TR_FLASH, TR_SWIRL, TR_FADE = 8, 24, 16       # frames: 48 in all (loc.s TR_FR)


def trans_tables():
    """the encounter transition (owner, 2026-11-22: from the WonderSwan Color remake; made lovelier
    2026-11-24): per frame 144 SCX offsets, then 144 SCY offsets (map line - screen line). 8 frames: two white flashes over the still map; 24: a swirl, a rolling ripple growing
    (eased) with the map drawn in towards the party's line; 16: the lines part, every other one
    left / right, while the picture folds onto the party's line and fades to white.
    $7600: the fade to white, 8 levels x 32 values (c + (31 - c) f / 8); $7700: each frame's
    colour level (0 as before, 1 the map's own colours, 2-9 the fade's levels 1-8)."""
    import math
    def ease(u): return u * u * (3 - 2 * u)                         # smoothstep
    out = bytearray(); lv = bytearray(); cy = 72
    def frame(dx, sy):                                              # 144 SCX, then 144 SCY
        out.extend(int(round(dx[y])) & 255 for y in range(144))
        out.extend((int(round(sy[y])) - y) & 255 for y in range(144))
    for t in range(TR_FLASH):                                       # two flashes
        frame([0] * 144, list(range(144)))
        lv.append((3, 7, 3, 1)[t % 4])                          # (a pulse: DMG 1, 3, 1, 0)
    dx = [0] * 144; sy = list(range(144))
    for t in range(TR_SWIRL):                                       # the swirl
        u = (t + 1) / TR_SWIRL
        a = 22 * ease(u); ph = 0.55 * t
        k1 = 2 * math.pi * (1.1 + 0.9 * u) / 144
        z = 1 + 0.7 * ease(u) ** 2
        dx = [a * math.sin(k1 * y + ph) + 0.35 * a * math.sin(2.7 * k1 * y - 1.3 * ph)
              for y in range(144)]
        sy = [cy + (y - cy) / z + 3 * ease(u) * math.sin(2 * math.pi * y / 48 + 0.8 * ph)
              for y in range(144)]
        frame(dx, sy)
        lv.append(0)
    for t in range(TR_FADE):                                        # part, fold, white
        u = (t + 1) / TR_FADE
        ph = 0.55 * (TR_SWIRL + t)
        a = 22 * (1 - 0.5 * u)
        k1 = 2 * math.pi * 2.0 / 144
        part = 90 * ease(u) ** 1.5
        z = 1.7 + 14 * ease(u) ** 2
        dx = [a * math.sin(k1 * y + ph) + (part if y & 1 else -part) for y in range(144)]
        sy = [cy + (y - cy) / z for y in range(144)]
        frame(dx, sy)
        lv.append(1 + max(1, min(8, int(round(8 * ease(u))))))
    assert len(out) <= 0x3600
    out += b'\0' * (0x3600 - len(out))
    for f in range(1, 9):
        out += bytes(c + (31 - c) * f // 8 for c in range(32))
    out += b'\0' * (0x3700 - len(out))
    out += bytes(lv)
    return bytes(out)
