"""FF1 native build: data for the screens (title, new game, menus): FF1's class battle sprites,
the hand cursor and the battle sprite palettes from the user's ROM; strings from the project's
English (our own text). Bank UI_GFX: $4000 class sprites for DMG (12 x 32 tiles, ranked by the
class's palette), $5800 for CGB, $7000 cursor (DMG), $7040 cursor (CGB), $7080 cursor 2 x 2
table, $7100 CGB OBJ palettes (4, from FF1's battle sprite palettes), $7120 class -> palette,
$7140 class starting stats (12 x 16)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', '..', 'translations'))
sys.path.insert(0, os.path.join(HERE, '..', 'ff1'))
import data, text

BANK_BTLCHR, BAT_SPR, BAT_OBJ = 9, 0x9000, 0xA800
START_STATS = 0xB040                   # BANK_STARTINGSTATS (0): 16 bytes per class


def _find(rom, sig):
    fix = rom.prg[-0x4000:]
    i = fix.find(bytes(sig))
    assert i >= 0, 'table not found: %s' % bytes(sig).hex()
    return fix, i


def gfx_bank(rom):
    fix, pi = _find(rom, [0x0F, 0x28, 0x18, 0x21, 0x0F, 0x16, 0x30, 0x36])   # battle sprite palettes
    pals = [list(fix[pi + 4 * p:pi + 4 * p + 4]) for p in range(4)]
    _, ci = _find(rom, [0x01, 0x00, 0x00, 0x01, 0x01, 0x00, 0x01, 0x01, 0x00, 0x01, 0x01, 0x00])
    cls_pal = fix[ci:ci + 12]
    _, ui = _find(rom, [0x00, 0x03, 0x02, 0x03, 0x01, 0x03])                  # cursor 2 x 2 table
    cur_tbl = fix[ui:ui + 8]
    blob = bytearray(b'\xff' * 0x4000)
    for c in range(12):
        src = rom.rd(BANK_BTLCHR, BAT_SPR + 0x200 * c, 0x200)
        p = pals[cls_pal[c]]
        for t in range(32):
            t16 = src[16 * t:16 * t + 16]
            o = 32 * c + t
            blob[16 * o:16 * o + 16] = data.spr_rank_tile(t16, p)
            blob[0x1800 + 16 * o:0x1800 + 16 * o + 16] = data.gb_tile(t16)
    cur = rom.rd(BANK_BTLCHR, BAT_OBJ + 0x700, 0x40)                          # sprite tiles $F0-$F3
    for t in range(4):
        blob[0x3000 + 16 * t:0x3010 + 16 * t] = data.spr_rank_tile(cur[16 * t:16 * t + 16], pals[3])
        blob[0x3040 + 16 * t:0x3050 + 16 * t] = data.gb_tile(cur[16 * t:16 * t + 16])
    blob[0x3080:0x3088] = cur_tbl
    blob[0x3100:0x3120] = b''.join(data.rgb555(c).to_bytes(2, 'little') for p in pals for c in p)
    blob[0x3120:0x312C] = cls_pal
    blob[0x3140:0x3140 + 12 * 16] = rom.rd(0, START_STATS, 12 * 16)
    return bytes(blob)


NAME_GRID = ['ABCDEFGHIJ', 'KLMNOPQRST', "UVWXYZ'.,-", 'abcdefghij', 'klmnopqrst',
             'uvwxyz!?&…', '0123456789', '():;/+%"[]', '          ']
TITLE = ['Continue', 'New Game', 'Message Speed']


def enc(s):
    return bytes(0x0A if ch == '\n' else text.code_of(ch) for ch in s)


def strings():
    """{name: encoded} for the screens"""
    import ff1_items
    out = {}
    for i, t in enumerate(TITLE): out['title%d' % i] = enc(t)
    for c in range(12):
        name = ff1_items.T[240 + c]
        out['class%d' % c] = enc('\n'.join(text.wrap(name, 8)))
    for r, row in enumerate(NAME_GRID): out['grid%d' % r] = enc(row)
    return out


def string_table(base):
    """a pointer table (in the order of `names`) and the strings, for assembly at `base`"""
    s = strings()
    names = sorted(s)
    ptrs = bytearray(); body = bytearray()
    a0 = base + 2 * len(names)
    for n in names:
        ptrs += (a0 + len(body)).to_bytes(2, 'little'); body += s[n] + b'\0'
    return names, bytes(ptrs) + bytes(body)
