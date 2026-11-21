"""FF1 native build: data for the screens (title, new game, menus): FF1's class battle sprites,
the hand cursor and the battle sprite palettes from the user's ROM; strings from the project's
English (our own text). Bank UI_GFX: $4000 class sprites for DMG (12 x 32 tiles, ranked by the
class's palette), $5800 for CGB, $7000 cursor (DMG), $7040 cursor (CGB), $7080 cursor 2 x 2
table, $7100 CGB OBJ palettes (4, from FF1's battle sprite palettes), $7120 class -> palette,
$7140 class starting stats (12 x 16), $7300 orb tiles (DMG: 16 lit + 4 unlit),
$7480 for CGB, $7600 the lit orbs' CGB palette."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', '..', 'translations'))
sys.path.insert(0, os.path.join(HERE, '..', 'ff1'))
import data, text

BANK_BTLCHR, BAT_SPR, BAT_OBJ = 9, 0x9000, 0xA800
BANK_ORBCHR, ORB_CHR = 0x0D, 0xB600      # FF1 lut_OrbCHR: menu tiles $60-$7F (orbs)
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
    orb = rom.rd(BANK_ORBCHR, ORB_CHR, 0x200)                                 # menu tiles $60-$7F
    m14 = rom.prg[14 * 0x4000:15 * 0x4000]
    mi = m14.find(bytes([0x0F, 0x30, 0x01, 0x22, 0x0F, 0x00, 0x01]))    # menu palettes
    assert mi >= 0, 'menu palettes not found'
    lit = list(m14[mi:mi + 4])
    for i, t in enumerate(list(range(0x64, 0x74)) + list(range(0x76, 0x7A))):
        t16 = orb[16 * (t - 0x60):16 * (t - 0x60) + 16]
        blob[0x3300 + 16 * i:0x3310 + 16 * i] = data.gb_tile(t16, (3, 0, 3, 1) if i < 16 else text.DMG_WIN)
        blob[0x3480 + 16 * i:0x3490 + 16 * i] = data.gb_tile(t16)
    blob[0x3600:0x3608] = b''.join(data.rgb555(c).to_bytes(2, 'little') for c in lit)
    blob[0x3610:0x3610 + 49 * 3] = rom.rd(0x0B, 0x9000, 49 * 3)                # FF1 lut_ExpToAdvance
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
    import ff1_shop_menu as sm
    import re
    M = {k: re.sub(r'\{[0-9A-F]{2}\}', '', v) for k, v in sm.M.items()}
    for c in range(12): out['cname%d' % c] = enc(ff1_items.T[240 + c])
    out['mcmd'] = enc('\n'.join(x.strip() for x in sm.M[2].split('\n')))
    out['gil'] = enc('Gil')
    out['items'] = enc(M[3].strip())
    out['magic'] = enc('Magic')
    out['mp'] = enc('  MP ')
    out['level'] = enc('Level ')
    out['exp'] = enc('Experience')
    out['next'] = enc('Until next level')
    out['stats'] = enc('\n'.join(x.split('  ')[0].strip() for x in M[39].split('\n')))
    out['bstats'] = enc('\n'.join(x.split('  ')[0].strip() for x in M[40].split('\n')))
    for k, w in (('dead', 'Dead'), ('stone', 'Stone'), ('poison', 'Poison')): out['st_' + k] = enc(w)
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


MTEXT_BANK = 5


def mtext_bank():
    """the menu texts (FF1's menu strings: descriptions, prompts), wrapped to the GB windows:
    $4000 pointers by FF1's string id (64), the strings after them"""
    import re
    import ff1_shop_menu as sm
    blob = bytearray(b'\xff' * 0x4000); body = bytearray(); ptrs = bytearray()
    for k in range(64):
        t = re.sub(r'\{[0-9A-F]{2}\}', '', sm.M.get(k, ''))
        lines = []
        for para in t.split('\n'):
            para = para.strip()
            if 'button...' in para:                       # "A button...Yes  B button...No"
                lines += [x.strip() for x in para.split('  ') if x.strip()]
            else:
                lines.append(para)
        out = []                                          # joined, rewrapped to 18 columns
        buf = ''
        for ln in lines:
            if 'button...' in ln:
                if buf: out += text.wrap(buf); buf = ''
                out.append(ln)
            else:
                buf = (buf + ' ' + ln).strip()
        if buf: out += text.wrap(buf)
        ptrs += (0x4080 + len(body)).to_bytes(2, 'little')
        body += enc('\n'.join(out[:7])) + b'\0'
    blob[0:0x80] = ptrs
    blob[0x80:0x80 + len(body)] = body
    return bytes(blob)
