"""FF3 native engine: the Bestiary's data (owner, 2026-11-28: FF1's Bestiary in FF3), built from the
user's ROM at build time for bank CODE12 (bst.s reads it). For each of FF3's monsters ($00-$E6):

BS_NAME   its name (the battle strings 18/8800: $0520 + id, $0600 + id - $E0 from $E0)
BS_STAT   8 bytes: level, HP (2), EXP (2: 10/9C80 + id -> 10/9D80 + 2 n), Gil (2: 30/9C58 + 2 id), 0
BS_GFX    32 bytes: kind (0 a monster, 1 a boss), the graphics bank (0-4: MGFX_BANK0 + n), the first
          tile (2), width, height (tiles), the boss id, the tiles flipped (summon graphics),
          8 bytes of palette bits (a 2 x 2 block each, MSB first: 0 palette A, 1 palette B),
          palette A and B (3 colours each, RGB555)

FF3's rules, as the battle (btl.s mon_attr, btlgfx.s mon_gfx1 / mon_attr1 / boss_gfx): graphics
property 2E/8B00 + id (class = bits 7-5, index = bits 4-0); class 6: a boss (its 144 tiles from
the pointer 2E/9068 + 2 index, its 18 x 12 tilemap 2A/8000 + 216 index, its bits 2E/8FC0 + 7 index);
else 2F/A4B4 + 4 class (address, bank pair, size id) and 2F/A4CC + 2 size (width, height), the tiles
at the address + index x tiles, the bits at 2E/8F20.. (2F/A8D8 / A8E4); the palettes from the
first monster set (2E/8400, 6 bytes) that has the monster, 2E/8C00 + 3 palette."""
import text

N = 0xE7
MATTR_BASE = (0x8F20, 0x8F20, 0x8F48, 0x8F48, 0x8FA8, 0x8FB4)
MATTR_MUL = (1, 1, 2, 2, 3, 3)
PAIRS = {0x10: 0, 0x11: 1, 0x12: 2, 0x13: 3, 0x06: 4}


def name(rom, m):
    i = 0x120 + m if m < 0xE0 else 0x200 + m - 0xE0
    b = text.raw_string(rom, 'names8800', i)
    return bytes(c for c in b if c >= 0x80 or c == 0xFF)


def code_data(rom, rgb555):
    def db(label, data):
        return '%s:\n' % label + ''.join('    db %s\n' % ', '.join(str(v) for v in data[k:k + 16])
                                         for k in range(0, len(data), 16))
    gp = rom.b(0x2E, 0x8B00, 256)
    tbg = rom.b(0x2F, 0xA4B4, 24)
    tbs = rom.b(0x2F, 0xA4CC, 16)
    sets = rom.b(0x2E, 0x8400, 0x600)
    pals = rom.b(0x2E, 0x8C00, 0x300)
    expid = rom.b(0x10, 0x9C80, 256)
    expv = rom.b(0x10, 0x9D80, 512)
    gil = rom.b(0x30, 0x9C58, 512)
    recs = rom.b(0x30, 0x8000, 0x1000)
    names, stat, gfx = [], bytearray(), bytearray()
    for m in range(N):
        names.append(name(rom, m))
        hp = recs[16 * m + 1] | recs[16 * m + 2] << 8
        e = expv[2 * expid[m]] | expv[2 * expid[m] + 1] << 8
        g = gil[2 * m] | gil[2 * m + 1] << 8
        stat += bytes([recs[16 * m], hp & 255, hp >> 8, e & 255, e >> 8, g & 255, g >> 8, 0])
        pa, pb = 0, 0
        for s in range(256):
            if m in sets[6 * s + 2:6 * s + 6]:
                pa, pb = sets[6 * s], sets[6 * s + 1]
                break
        cls, ix = gp[m] >> 5, gp[m] & 31
        r = bytearray(32)
        if cls == 6:
            w = rom.b(0x2E, 0x9068 + 2 * ix, 2)
            word = w[0] | w[1] << 8
            r[0] = 1
            if word & 0x2000:
                r[1], r[7] = 4, 1
            else:
                r[1] = (word >> 14) & 3
            t = word & 0x3FF
            r[2], r[3], r[4], r[5], r[6] = t & 255, t >> 8, 18, 12, ix
            r[8:16] = rom.b(0x2E, 0x8FC0 + 7 * ix, 8)
        else:
            lo, hi, bk, sz = tbg[4 * cls:4 * cls + 4]
            wd, ht = tbs[2 * sz], tbs[2 * sz + 1]
            t = ((hi << 8 | lo) - 0x8000) // 16 + ix * wd * ht
            r[1], r[2], r[3], r[4], r[5] = PAIRS[bk], t & 255, t >> 8, wd, ht
            d = ({1: 0x10, 3: 0x18}.get(cls, 0) + ix) & 0x3F
            r[8:12] = rom.b(0x2E, MATTR_BASE[cls] + MATTR_MUL[cls] * d, 4)
        for k, p in enumerate((pa, pb)):
            for c in range(3):
                v = rgb555(pals[3 * p + c])
                r[16 + 6 * k + 2 * c] = v & 255
                r[17 + 6 * k + 2 * c] = v >> 8
        gfx += r
    out = ''
    out += 'BS_NAME:\n' + ''.join('    dw BS_NAME_%d\n' % k for k in range(N))
    for k, b in enumerate(names):
        out += 'BS_NAME_%d:\n    db %s\n' % (k, ', '.join(str(v) for v in b + b'\0'))
    return out + db('BS_STAT', stat) + db('BS_GFX', gfx)
