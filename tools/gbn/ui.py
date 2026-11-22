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


NAME_GRID = ['ABCDEFGHI', 'JKLMNOPQR', 'STUVWXYZ ', 'abcdefghi', 'jklmnopqr',
             "stuvwxyz'", '012345678', '9.,-!?&…(', '):;/+%"[]']   # (9 x 9, in a window)
TITLE = ['Continue', 'New Game', 'Message Speed']
SAVE_ERROR = ('SAVE DATA ERROR\n\nThe saved game in\nthe Game Pak is\ndamaged.\n\n'
              'Press the A Button\nto erase it.')     # (Lot Check: Nintendo's names)
SUSP_ERROR = ('SUSPEND DATA ERROR\n\nThe suspended game\nin the Game Pak is\ndamaged.\n\n'
              'Press the A Button\nto erase it.')


def enc(s):
    return bytes(0x0A if ch == '\n' else text.code_of(ch) for ch in s)


def strings():
    """{name: encoded} for the screens"""
    import ff1_items
    out = {}
    for i, t in enumerate(TITLE): out['title%d' % i] = enc(t)
    out['saverr'] = enc(SAVE_ERROR)
    out['suserr'] = enc(SUSP_ERROR)
    # Suspend (the recompiled build's wording): 18 letters a line
    out['susq'] = enc('Create a Suspend\nPoint and return\nto the Title?\nSuspend points are\n'
                      'retained when\nturning off the\nPower.')
    out['susc1'] = enc('Continue from\nSuspend point?')
    out['susc2'] = enc('Continue from last\nsave? The suspend\npoint will be\nlost!')
    out['pgok'] = enc('OK to begin\nwith this party?')    # (owner's wording, party creation)
    out['pgyes'] = enc('Yes')
    out['pgno'] = enc('No')
    out['stlab'] = enc('HP\nMP')                     # (the status screen's gold labels)
    out['stlab2'] = enc('Exp\nNext')
    out['nisel'] = enc('SELECT: abc')                   # (name entry: the other case)
    out['nisel2'] = enc('SELECT: ABC')
    out['options'] = enc('Options')                     # (the Options screen)
    out['opt1'] = enc('Message Speed')
    out['opt2'] = enc('Text Speed')
    out['opt3'] = enc('Volume')
    out['formation'] = enc('Formation')                 # (the lineup screen's title)
    out['howmany'] = enc('How many?')                   # (the item shop's quantity)
    out['satk'] = enc('Attack')                         # (the shops' party window)
    out['sdef'] = enc('Defense')
    out['scant'] = enc("Can't use")
    out['scantl'] = enc("Can't learn")
    out['sfull'] = enc('Full')
    out['sok'] = enc('OK')
    out['noeff'] = enc("It wouldn't have\nany effect.")
    out['sknown'] = enc('Known')
    out['sheq'] = enc('Equip it now?')
    out['shwho'] = enc("Who's gonna\ncarry it?")      # (FF1's shop lines 17 / 21 hold variants)
    out['shwhich'] = enc('Which one?')
    out['stl'] = enc('Str\nAgi\nInt\nVit\nLck')
    out['mcmd4'] = enc('Items\nMagic\nEquip\nStatus\nOptions\nSuspend')          # (the main menu, owner 2026-11-22)
    out['eqst'] = enc('Attack\nAccuracy\nDefense\nEvasion')
    out['eqrem'] = enc('Remove')
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
    out['ptime'] = enc('Time')
    out['items'] = enc(M[3].strip())
    out['magic'] = enc('Magic')
    out['yesno'] = enc(sm.S[15])
    out['buysell'] = enc(sm.S[10])
    out['buyleave'] = enc(sm.S[11])
    out['weapons'] = enc(M[52].strip())
    out['armor'] = enc(M[62].strip())
    out['eqcmd'] = enc('Equip  Swap  Drop')
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


def mtext_bank(rom=None):
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
    assert 0x80 + len(body) <= 0x2000
    body = bytearray(); ptrs = bytearray()          # $6000: the shop texts (FF1's shop strings)
    for k in range(64):
        t = re.sub(r'\{[0-9A-F]{2}\}', '', sm.S.get(k, ''))
        lines = t.split('\n')
        if k < 8:                                   # the shop names: the title window (8 wide)
            lines = text.wrap(t.strip(), 8)
        elif len(lines) > 4 or max(len(x) for x in lines) > 18:
            lines = text.wrap(' '.join(x.strip() for x in lines))[:4]
        ptrs += (0x6080 + len(body)).to_bytes(2, 'little')
        body += enc('\n'.join(lines)) + b'\0'
    blob[0x2000:0x2080] = ptrs
    blob[0x2080:0x2080 + len(body)] = body
    st, _, _ = story_bank_part(rom)
    blob[0x3000:0x3000 + len(st)] = st
    return bytes(blob)


def story_texts():
    """{'prologue': {n: text}, 'story': {n: text}} from translations/ff1_story.py"""
    import types
    src = open(os.path.join(HERE, '..', '..', 'translations', 'ff1_story.py')).read()
    got = {}
    def fake_apply(path, d, *a, **k): got[os.path.basename(path).split('.')[0]] = d
    g = {'__file__': os.path.join(HERE, '..', '..', 'translations', 'ff1_story.py'), '__name__': 'story'}
    src = src.replace('from apply import apply', '')
    g['apply'] = fake_apply
    exec(compile(src, 'ff1_story.py', 'exec'), g)
    return got


CREDIT_PAGES = 4


def credit_pages(rom):
    """FF1's bridge-scene credits (bank 13 lut_CreditsText: 4 pages, already in Latin letters
    in the ROM): per page its lines, each segment on the line of its NES row in the story box
    (NES row 5 = our line 0), upper case"""
    b13 = rom.prg[13 * 0x4000:14 * 0x4000]
    t = None                                        # the table: 4 pointers, the first just
    for a in range(0, 0x4000 - 8):                  #   past it, each page ending in $00
        p0 = b13[a] | b13[a + 1] << 8
        if p0 == 0x8000 + a + 8 and all(0x8000 + a + 8 <= (b13[a + 2 * k] | b13[a + 2 * k + 1] << 8)
                                        < 0xC000 for k in range(4)) and b13[a + 9] in (0x20, 0x21, 0x22, 0x23):
            t = a; break
    assert t is not None, 'credits table not found'
    pages = []
    for p in range(CREDIT_PAGES):
        a = (b13[t + 2 * p] | b13[t + 2 * p + 1] << 8) - 0x8000
        lines = [''] * 10
        while True:
            lo, hi = b13[a], b13[a + 1]; a += 2
            row = ((hi << 8 | lo) - 0x2000) // 32 - 5
            s = ''
            while b13[a] not in (0, 1):
                c = b13[a]; a += 1
                s += (chr(0x41 + c - 0x20) if 0x20 <= c <= 0x39 else ' ' if c == 0xFF
                      else '-' if c == 0xC2 else '')
            if 0 <= row < 10: lines[row] = ' '.join(s.split())
            if b13[a] == 0: break
            a += 1
        while lines and not lines[-1]: lines.pop()
        pages.append(lines)
    return pages


def story_pages(rom=None):
    """the pages (each up to 10 lines of 18): prologue first, then the story texts in order
    (with the ROM: FF1's credits after the bridge's four pages); returns (pages, index of the
    first story page)"""
    st = story_texts()
    pages = []
    pro = st.get('prologue', {}).get(0, '')
    lines = []
    for sent in pro.split('\n'):
        lines += text.wrap(sent.strip()) + ['']
    while lines and not lines[-1]: lines.pop()
    page = []
    for ln in lines:                                   # pages of up to 10 lines, broken at blanks
        if len(page) >= 12 and ln == '':        # (the prologue: a full screen a page)
            pages.append(page); page = []; continue
        page.append(ln)
    if page: pages.append(page)
    first = len(pages)
    for k in sorted(st.get('story', {})):
        t = st['story'][k]
        ls = []
        for para in t.split('\n'):
            ls.append(para.strip())
        ls = text.wrap(' '.join(x for x in ls if x)) if max(len(x) for x in ls) > 18 else ls
        pages.append([x for x in ls][:10])
    if rom is not None:
        pages[first + 4:first + 4] = credit_pages(rom)
    return pages, first


def story_bank_part(rom=None):
    """$7000 in the menu text bank: pointers (64), the pages (lines joined by $0A)"""
    pages, first = story_pages(rom)
    body = bytearray(); ptrs = bytearray()
    for pg in pages[:64]:
        ptrs += (0x7080 + len(body)).to_bytes(2, 'little')
        body += enc('\n'.join(pg)) + b'\0'
    assert 0x80 + len(body) <= 0x1000
    return bytes(ptrs.ljust(0x80, b'\0')) + bytes(body), first, len(pages)


# place names for the map-entry banner and the main menu (owner, 2026-11-22, as the WonderSwan
# Color remake): the project's English names (docs/glossary-ff1.md, the dialogue's wording, the
# Japanese names where the dialogue has none), by FF1 standard map number; no floors
LOC_NAMES = ['Cornelia', 'Pravoka', 'Elfheim', 'Melmond', 'Crescent Lake', 'Gaia', 'Onrac', "Hawk's Wing",
             'Cornelia Castle', 'Elf Castle', 'Northwest Castle', 'Castle of Ordeals', 'Temple of Chaos',
             'Earth Cave', 'Gurgu Volcano', 'Ice Cave', 'Cardia Islands', "Bahamut's Cave", 'Waterfall Cave',
             'Dwarf Cave', "Matoya's Cave", "Sarda's Cave", 'Marsh Cave', 'Mirage Tower', 'Undersea Shrine',
             'Floating Castle', "Giant's Cave", 'World Map']
LOC_MAP = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
           8, 11, 11, 22, 22, 13, 13, 13, 13, 14, 14, 14, 14, 15, 15, 17, 23, 23,
           24, 24, 24, 24, 24, 25, 25, 25, 25, 25, 12, 12, 12, 12, 12, 12, 12, 12, 26]


def loc_source():
    """bank 99 $7000: loc_tab (map -> name), loc_ptr, the names (ASCII, 0-terminated)"""
    assert len(LOC_MAP) == 61
    out = ['section bank 99, $7000', 'loc_tab:']
    out += ['            db ' + ', '.join(str(v) for v in LOC_MAP[k:k + 16]) for k in range(0, 61, 16)]
    out.append('loc_ptr:')
    out += ['            dw loc_s%d' % i for i in range(len(LOC_NAMES))]
    for i, n in enumerate(LOC_NAMES):
        assert len(n) <= 18
        out.append('loc_s%d:      db %s, 0' % (i, ', '.join(str(ord(c)) for c in n)))
    return '\n'.join(out) + '\n'
