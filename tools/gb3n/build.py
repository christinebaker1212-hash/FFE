"""Build the native FF3 Game Boy Color ROM (docs/ff3-gb-status.md) from the English NES ROM the
existing pipeline makes (tools/ff3_mmc5/build.py, then tools/ff3/insert.py). Game data is read
from that ROM here, at build time; nothing game-specific is kept in the repository.

usage: python3 tools/gb3n/build.py [--nes build/ff3_en.nes] [--out build/ff3n.gbc] [--map M[,WORLD[,X,Y]]]"""
import os, sys, hashlib, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from asm_sm83 import asm, make_rom
import tiles, data, text, cutdata

BATTLE_SRC = ['batlib.s', 'batcore.s', 'batmagic.s', 'batinit.s', 'batequip.s', 'batflow.s', 'batvict.s', 'batloop.s', 'batsetup.s', 'batscr.s', 'batui.s']
ROM_BANKS = 128             # 2 MB (sized to the game later)
RAM_CODE = 0x03             # 32 KB cart RAM (4 banks, as retail MBC5 games: docs/gb-lessons.md)
EN_SHA1 = '4a7f1ae4c89305cf161aa3d78fd4416548663f99'   # build/ff3_en.nes (patches/README.md)


def db(data, per=16):
    return ''.join('            db ' + ', '.join('$%02X' % b for b in data[i:i + per]) + '\n'
                   for i in range(0, len(data), per))


def menu_data():
    """the menu's words: FF3's own from the English text (t8200 $31 commands, $37 Status, $47 the
    status labels), ours where FF3 has none (Config, Suspend, CP, Lv, Exp)"""
    t = text.load('t8200')
    clean = lambda s: re.sub(r'\{[0-9A-F]{2}(:[0-9A-F]{2})?\}', '', text.plain(s)).replace('…', '').strip()
    cmds = [clean(l.replace('[E1][E2][E3][E4]', t[0x37])) for l in t[0x31].split('\n')]
    assert len(cmds) == 7, cmds
    cmds = cmds[:6] + ['Config', cmds[6], 'Suspend']
    st = [clean(l) for l in t[0x47].split('\n')]
    lab = {}
    for l in st:
        m = re.match(r'([A-Za-z][A-Za-z ]*?)\s*(\d+x)?$', l.split('‥')[0].strip()) if l else None
        if m: lab[m.group(1).strip()] = 1
    want = ['Strength', 'Agility', 'Stamina', 'Intelligence', 'Spirit', 'Attack', 'Hit rate', 'Defense']
    for w in want: assert any(k.startswith(w) for k in lab), (w, lab)
    prof = [k for k in lab if k.startswith('Proficiency')][0]
    z = lambda w: ''.join('$%02X, ' % ord(c) for c in w) + '0'
    return ('section bank %d, $7800\nm_cmdtxt:\n' % B_MENU + ''.join('            db %s\n' % z(c) for c in cmds) +
            'm_labels:\n' + ''.join('            db %s\n' % z(w) for w in want) +
            'm_gil:      db %s\n' % z(clean(t[5])) + 'm_cp:       db %s\n' % z('CP') +
            'm_lv:       db %s\n' % z('Lv') + 'm_hp:       db %s\n' % z('HP') + 'm_mp:       db %s\n' % z('MP') +
            'm_exp:      db %s\n' % z('Exp') + 'm_prof:     db %s\n' % z(prof) +
            'm_s_erase:  db %s\n' % z(clean(t[0x4C].split('{15')[0]).replace('\n', '\x0a')) +
            'm_s_yes:    db %s\n' % z(clean(t[6].split('\n')[0])) +
            'm_s_no:     db %s\n' % z(clean(t[6].split('\n')[1])) +
            'm_damaged:  db %s\n' % z('Damaged') + 'm_trash:    db %s\n' % z('Trash') +
            'm_s_chg:    db %s\n' % z(clean(t[0x70]).replace('\n', '\x0a')) +
            'm_s_cfg:    db %s\n' % z('Config') + 'm_s_mspd:   db %s\n' % z('Message Speed') +
            'm_s_resume: db %s\n' % z('Resume') +
            'm_s_susp:   db %s\n' % z('Game suspended.\x0aResume it from the\x0atitle screen.') +
            ''.join('m_s_%s:%s db %s\n' % (n, ' ' * (6 - len(n)), z(w)) for n, w in zip(
                ['buy', 'sell', 'exit'], [x.strip() for x in re.split(r'\{15:..\}', t[0x0B])[1:]])) +
            ''.join('m_s_%s:%s db %s\n' % (n, ' ' * (6 - len(n)), z(w)) for n, w in zip(
                ['q1', 'q4', 'q10'], [x.strip() for x in re.split(r'\{15:..\}', t[0x2D])[1:]])) +
            'm_s_qall:   db %s\n' % z(re.split(r'\{15:..\}', t[0x2E])[2].strip()) +
            'm_s_use:    db %s\n' % z(re.split(r'\{15:..\}', t[0x36])[1].strip()) +
            ''.join('m_f_%s:%s db %s\n' % (n, ' ' * (5 - len(n)), z(w)) for n, w in zip(
                ['dep', 'wd', 'exit'], [x.strip() for x in re.split(r'\{15:..\}', t[0x24])[1:]])) +
            'm_s_item:   db %s\n' % z(re.split(r'\{15:..\}', t[0x36])[3].strip()) +
            'm_s_swap:   db %s\n' % z(re.split(r'\{15:..\}', t[0x36])[2].strip()) +
            'm_remove:   db %s\n' % z(clean(t[0x3E].split('\n')[-1])) + name_grid())


def name_grid():
    """the name entry's letters in FF3's codes (the English ROM's ENC): upper / lower case, digits,
    punctuation (9 x 5 each), and our help lines (Nintendo's button names)"""
    sys.path.insert(0, os.path.join(HERE, '..', 'ff3'))
    import insert
    enc = insert.ENC
    tail = '0123456789' + ".,'-!?&/:"
    g0 = [enc[c] for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' + tail]
    g1 = [enc[c] for c in 'abcdefghijklmnopqrstuvwxyz' + tail]
    assert len(g0) == len(g1) == 45
    z = lambda w: ''.join('$%02X, ' % ord(c) for c in w) + '0'
    return ('n_grid0:    db %s\n' % ', '.join('$%02X' % c for c in g0) +
            'n_grid1:    db %s\n' % ', '.join('$%02X' % c for c in g1) +
            'n_help0:    db %s\n' % z('SELECT: abc') + 'n_help1:    db %s\n' % z('SELECT: ABC') +
            'n_help2:    db %s\n' % z('B:Delete  START:OK'))


def own_data(raw):
    """our own tiles / screens in bank B_OWN; the window font's icon codes get FF3's icons (font
    tiles $60-$75 of the user's ROM, text.ICON_CODES)"""
    rgb = lambda r, g, b: (r | g << 5 | b << 10).to_bytes(2, 'little')
    pal0 = rgb(0, 0, 0) + rgb(21, 21, 21) + rgb(10, 10, 10) + rgb(31, 31, 31)
    wfont = [t if i != 1 else bytes(16) for i, t in enumerate(tiles.tileset(fg=3, bg=2)[:128])]
    for k, c in enumerate(text.ICON_CODES):
        o = 16 + 0x1B000 + 16 * (0x60 + k)
        wfont[c] = tiles.gb(raw[o:o + 16])
    test = tiles.screen([(2, None, 'FINAL FANTASY III'), ('frame', 1, 5, 18, 7),
                         (7, None, 'Native engine'), (9, None, 'Game Boy Color')])
    return ('section bank %d, $4000\nC_TILES:\n' % B_OWN + db(b''.join(tiles.tileset())) +
            'C_SCR_CGBONLY:\n' + db(tiles.screen(tiles.CGB_ONLY), 20) +
            'C_SCR_TEST:\n' + db(test, 20) + 'C_PAL0:\n' + db(pal0) +
            'section bank %d, $6000\nC_WFONT:\n' % B_OWN + db(b''.join(wfont)) +
            'C_FF3ASC:\n' + db(tiles.ff3_to_ascii()) +
            'C_SPRDIG:\n' + db(spr_digits()))


def spr_digits():
    """battle sprite tiles (ours): digits 0-9, "Miss" in 4 tiles, the hand cursor (colour 0
    clear, 3 the figure, 1 its outline)"""
    t = tiles.tileset(fg=3, bg=0)
    out = [t[ord(c)] for c in '0123456789Miss']
    hand = ['........', '.11.....', '1331111.', '13333331', '1333331.', '13333311', '1133331.', '.111111.']
    b = bytearray()
    for row in hand:
        lo = hi = 0
        for x, ch in enumerate(row):
            v = int(ch) if ch != '.' else 0
            lo |= (v & 1) << (7 - x); hi |= (v >> 1) << (7 - x)
        b += bytes([lo, hi])
    out.append(bytes(b))
    out.append(bytes(16))
    return b''.join(out)


B_MAPINFO, B_MAPAUX, B_EVENTS, B_CHARS, B_TMAP0, B_SUB0, B_COMMON = 3, 4, 5, 6, 8, 12, 17
B_NPCS, B_NPCGFX, B_OWN, B_TEXT, B_SCRIPT, B_FIELD = 18, 19, 20, 21, 28, 29
B_WORLD0, B_WINFO, B_WGFX = 32, 48, 49
B_SND0 = 50                 # 50-53: NES bank $36 at $4000, song bank $37 / $38 / $39 / $09 at $6000
B_BAT, B_BDAT, B_BDAT2, B_BDAT3 = 54, 55, 56, 57   # battle code; NES $30 + $31; $2E + $01; $38 + $39
B_BAT2 = 58                 # battle flow code
B_BSET = 59                 # NES $2E / $2F: battle setup data
B_BSCR, B_BINFO, B_CGFX, B_MGFX0 = 60, 61, 62, 64   # battle screen code; monster index; job graphics; monster graphics (64-71)
B_BOSS0 = 72                # boss graphics (72-75)
B_MENU = 76                 # the main menu's code
B_VGFX = 77                 # world map vehicles' graphics (NES 0B)
B_CUT, B_CUTG = 79, 80      # cutscenes: NES bank $1F + the code; their graphics / texts
B_WSPR = 81                 # world-map sprites: FF3's tiles $80-$FF, bank $3C's lists, the code
B_MINI = 82                 # the minimap: its screen data (tools/gb3n/minimap.py) and code
B_ANIM = 83                 # battle animations' graphics: NES 2B/B000 (weapons, hits)
B_MAGIC = 84                # the spells' graphics: NES 16 KB bank $15 (2A / 2B)
B_BANIM = 85                # battle animations' code and tables
B_SUMN = 86                 # the summons' tiles: NES 16 KB bank 6 from $9800 (0D/9800..)


def field_banks(rom):
    """the field's data banks (layouts: the top of src/field.s), all from the user's ROM"""
    banks = {}
    def blank(): return bytearray(b'\xff' * 0x4000)
    gbt = lambda nes: b''.join(tiles.gb(nes[16 * i:16 * i + 16]) for i in range(len(nes) // 16))
    b = blank()                                          # map info
    b[0x0000:0x2000] = rom.at(0x02 * data.B8, 0x2000)
    for ts in range(data.TILESET_COUNT):
        b[0x2000 + 0x400 * ts:0x2400 + 0x400 * ts] = data.tileset_block(rom, ts)
    base, typ, first = data.trigger_tables(rom)
    b[0x3C00:0x3C80] = base; b[0x3C80:0x3CA0] = typ; b[0x3CA0:0x3CC0] = first
    b[0x3CC0:0x3CC4] = data.window_colours(rom)
    b[0x3D00:0x3D80] = b''.join(data.rgb555(c).to_bytes(2, 'little') for c in range(64))
    banks[B_MAPINFO] = b
    b = blank()                                          # map aux tables
    b[0x0000:0x0100] = rom.rd(0x00, 0x9100, 256)
    b[0x0100:0x0200] = rom.rd(0x00, 0x9200, 256)
    b[0x0200:0x0300] = rom.rd(0x00, 0x9300, 256)
    b[0x0300:0x0500] = rom.rd(0x00, 0x8A00, 512)
    b[0x0500:0x0700] = rom.rd(0x00, 0x8C00, 512)
    b[0x0700:0x0720] = rom.rd(0x00, 0x9670, 32)
    b[0x0720:0x0788] = rom.rd(0x00, 0x9690, 104)
    b[0x0788:0x0798] = rom.rd(0x00, 0x96F8, 16)          # the guests' palettes (3B/BB40)
    b[0x0C00:0x0C40] = rom.rd(0x00, 0x8880, 64)
    b[0x0C40:0x0C80] = rom.rd(0x00, 0x88C0, 64)
    b[0x0D00:0x0D40] = rom.player_poses()
    b[0x0D40:0x0D80] = rom.rd(0x3E, 0xDCAA, 64)                  # vehicles' poses
    b[0x0D80:0x0D88] = rom.rd(0x3E, 0xC6CD, 8)                   # passability masks
    b[0x0D88:0x0D90] = rom.rd(0x3E, 0xC851, 8)                   # landing flags
    b[0x0D90:0x0D98] = rom.rd(0x3E, 0xD8CA, 8)                   # sprite rows
    v = blank()                                          # vehicles' graphics (NES 0B: 3D/BDE0)
    v[0x0000:0x0600] = gbt(rom.rd(0x0B, 0x8800, 0x600))
    v[0x0600:0x0780] = gbt(rom.rd(0x0B, 0x8E00, 0x180))
    v[0x0780:0x0900] = gbt(rom.rd(0x0B, 0x8F80, 0x180))
    v[0x0900:0x0940] = gbt(rom.rd(0x0B, 0xAC00, 0x40))       # the Enterprise turning (3E/D799):
    v[0x0940:0x0D40] = gbt(rom.rd(0x0B, 0xB100, 0x400))      #   the ship, 16 frames of 4 tiles
    banks[B_VGFX] = v
    tm = {}                                              # tilemaps: streams packed per bank
    bank, at = B_TMAP0, 0
    for tid in sorted(set(rom.rd(0x00, 0x8A00, 512))):
        st = data.tilemap_stream(rom, tid)
        if at + len(st) > 0x4000: bank, at = bank + 1, 0
        assert bank < B_SUB0, 'tilemaps overflow'
        banks.setdefault(bank, blank())[at:at + len(st)] = st
        b[0x0800 + 3 * tid:0x0803 + 3 * tid] = bytes([bank, (0x4000 + at) & 0xFF, (0x4000 + at) >> 8])
        at += len(st)
    per = 0x4000 // (16 * data.SUBSET_TILES)             # graphics subsets
    for sub in range(max(rom.rd(0x00, 0x8C00, 512)) + 1):
        bk, k = B_SUB0 + sub // per, sub % per
        assert bk < B_COMMON, 'subsets overflow'
        a = 16 * data.SUBSET_TILES * k
        banks.setdefault(bk, blank())[a:a + 16 * data.SUBSET_TILES] = gbt(data.subset_tiles(rom, sub))
        b[0x0B00 + 3 * sub:0x0B03 + 3 * sub] = bytes([bk, (0x4000 + a) & 0xFF, (0x4000 + a) >> 8])
    banks[B_MAPAUX] = b
    b = blank(); b[0:0x2000] = rom.at(0x10 * data.B8, 0x2000); banks[B_EVENTS] = b
    b = blank(); b[0:0x4000] = gbt(rom.at(0x0E * data.B8, 0x4000)); banks[B_CHARS] = b
    b = blank(); b[0:144 * 16] = gbt(rom.rd(0x0D, 0xB700, 144 * 16))
    b[0x2000:0x2040] = gbt(rom.rd(0x0D, 0xB440, 64))       # FF3's cursor: 4 tiles (3E/DF31 -> $E4-$E7)
    b[0x2040:0x2140] = gbt(rom.rd(0x0D, 0x8000, 256))      # Guzco's graphics (guest 4: 3B/BAD8)
    b[0x2140:0x2240] = gbt(rom.rd(0x0A, 0x8A00, 256))      # the Fat Chocobo (3F/E05A, E06E)
    b[0x2240:0x2340] = gbt(rom.rd(0x0D, 0x8E00, 256))
    banks[B_COMMON] = b
    banks[B_SCRIPT] = bytearray(rom.at(0x2C * data.B8, 0x4000))   # NES $2C/$2D: npc lists, scripts
    b = blank()                                          # people: tables, init
    b[0x2000:0x2200] = rom.rd(0x00, 0x9400, 512)
    b[0x2200:0x2400] = rom.rd(0x01, 0xBE00, 512)
    b[0x2400:0x2500] = rom.rd(0x3B, 0xB41A, 256)
    si = data.sram_init_data(rom)
    b[0x2500:0x2540] = si['npcsw']
    b[0x2540:0x2548] = si['base']; b[0x2548:0x2550] = si['mp']; b[0x2550:0x2552] = si['hp']
    b[0x2560:0x2574] = si['stats']; b[0x2580:0x2590] = si['equip']
    b[0x2590:0x2592] = bytes([si['wmx'], si['wmy']])
    b[0x2A00:0x2C00] = rom.rd(0x01, 0x9C00, 512)        # chest contents (world 0 / others)
    gfx = blank(); at = 0
    for g in range(256):
        if g < 0x40:
            ent = (B_CHARS, 0x4000 + 0x100 * g)
        else:
            gfx[at:at + 0x100] = gbt(data.npc_gfx_block(rom, g)); ent = (B_NPCGFX, 0x4000 + at); at += 0x100
            if at >= 0x4000: break
        b[0x2700 + 3 * g:0x2703 + 3 * g] = bytes([ent[0], ent[1] & 0xFF, ent[1] >> 8])
    banks[B_NPCS] = b; banks[B_NPCGFX] = gfx
    for wi, w in enumerate(data.WORLD_MAPS):             # world maps unpacked: 4 banks each
        rows = data.world_rows(rom, w)
        for k in range(4):
            banks[B_WORLD0 + 4 * wi + k] = bytearray(b''.join(rows[64 * k:64 * k + 64]))
    b = blank()                                          # world tilesets, palettes, entrances
    for w in range(5):
        b[0x400 * w:0x400 * w + 0x400] = data.world_tileset(rom, w)
        b[0x1400 + 16 * w:0x1410 + 16 * w] = bytes(c for pal in data.world_palettes(rom, w) for c in pal)
    b[0x1500:0x1540] = rom.rd(0x00, 0x8800, 64)
    b[0x1540:0x1580] = rom.rd(0x00, 0x8840, 64)
    banks[B_WINFO] = b
    b = blank()                                          # world graphics: 256 tiles per pair
    for k, w in enumerate((0, 2, 4)):
        b[0x1000 * k:0x1000 * k + 0x1000] = gbt(data.world_tiles(rom, w))
    banks[B_WGFX] = b
    banks[B_BDAT] = bytearray(rom.at(0x30 * data.B8, 0x4000))      # battle data: NES $30/$31 as mapped
    banks[B_BDAT3] = bytearray(rom.at(0x38 * data.B8, 0x4000))
    banks[B_BSET] = bytearray(rom.at(0x2E * data.B8, 0x4000))         # NES $2E / $2F
    banks[B_BDAT2] = bytearray(rom.at(0x2E * data.B8, 0x2000) + rom.at(0x01 * data.B8, 0x2000))
    battle_gfx(rom, banks, gbt, blank)
    for k, sb in enumerate((0x37, 0x38, 0x39, 0x09)):     # sound: driver tables + song data
        banks[B_SND0 + k] = bytearray(rom.at(0x36 * data.B8, 0x2000) + rom.at(sb * data.B8, 0x2000))
    return banks


def battle_gfx(rom, banks, gbt, blank):
    """monster graphics (GB tiles) by graphics block, the index by monster id in B_BINFO $4000 (4
    bytes: bank, address, width << 4 | height; 0 for the boss sizes, drawn from their tilemaps);
    the jobs' battle graphics (NES $28 / $29) in B_CGFX"""
    tab = data.mon_gfx_table(rom)
    info = blank(); seen = {}; bank, at = B_MGFX0, 0
    for mid in range(256):
        p = rom.rd(0x2E, 0x8B00 + mid)
        cls, g = p >> 5, p & 0x1F
        if cls >= len(tab):
            continue
        if (cls, g) not in seen:
            nb, addr, w, h = tab[cls]
            size = 16 * w * h
            gfx = gbt(rom.at(nb * data.B8 + (addr - 0x8000) + size * g, size))
            if at + size > 0x4000: bank, at = bank + 1, 0
            banks.setdefault(bank, blank())[at:at + size] = gfx
            seen[(cls, g)] = (bank, 0x4000 + at, w, h); at += size
        bk, a, w, h = seen[(cls, g)]
        info[4 * mid:4 * mid + 4] = bytes([bk, a & 0xFF, a >> 8, w << 4 | h])
    assert bank < B_MGFX0 + 8, 'monster graphics overflow'
    # bosses (2F/A3B8): 144 tiles (2E/9068: bank, tile) and an 18 x 12 tilemap (2A/8000 + $D8 x id;
    # 0 empty, $70+ the tiles) -> B_BINFO $4400 + 3 x id (bank, address), $4500 + 216 x id the map
    # (our tiles 0-143, $FF empty)
    bank, at = B_BOSS0, 0
    ids = sorted(set(rom.rd(0x2E, 0x8B00 + m) & 0x1F for m in range(256) if rom.rd(0x2E, 0x8B00 + m) >> 5 == 6))
    for g in ids:
        w = rom.rd(0x2E, 0x9068 + 2 * g) | rom.rd(0x2E, 0x9069 + 2 * g) << 8
        # (2F/A3BB: bbs---tt tttttttt: 16 KB bank $10 + b, or $06 for a summon's graphics, which
        # 2F/A40B flips to face the party)
        b16 = 0x06 if w & 0x2000 else 0x10 + ((w >> 14) & 3)
        src = b16 * 2 * data.B8 + ((w & 0x3FF) << 4)
        raw = rom.at(src, 144 * 16)
        if w & 0x2000:
            raw = bytes(int('{:08b}'.format(x)[::-1], 2) for x in raw)
        gfx = gbt(raw)
        if at + len(gfx) > 0x4000: bank, at = bank + 1, 0
        banks.setdefault(bank, blank())[at:at + len(gfx)] = gfx
        info[0x400 + 3 * g:0x403 + 3 * g] = bytes([bank, (0x4000 + at) & 0xFF, (0x4000 + at) >> 8])
        at += len(gfx)
        tm = rom.rd(0x2A, 0x8000 + 0xD8 * g, 0xD8)
        info[0x500 + 0xD8 * g:0x500 + 0xD8 * g + 0xD8] = bytes(t - 0x70 if 0x70 <= t < 0x70 + 144 else 0xFF for t in tm)
    assert bank < B_BOSS0 + 4, 'boss graphics overflow'
    banks[B_BINFO] = info
    banks[B_CGFX] = bytearray(gbt(rom.at(0x28 * data.B8, 0x4000)))


NES_NOISE = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]


def sound_data():
    """bank 0 tables: NES period -> GB frequency (pulses and triangle alike: 2048 - 1.1717 (p + 1)),
    NES noise period index (+ 16 for the short mode) -> NR43"""
    import math
    ft = []
    for p in range(2048):
        x = int(round(2048 - 131072.0 * 16 * (p + 1) / 1789773.0))
        ft.append(max(0, min(2047, x)))
    nt = []
    for mode in (0, 1):
        for per in NES_NOISE:
            f = 1789773.0 / per
            best = min(((abs(math.log(262144.0 / ((r or 0.5) * 2 ** sh)) - math.log(f)), sh << 4 | r)
                        for sh in range(14) for r in range(8)))
            nt.append(best[1] | (8 if mode else 0))
    lines = ['section bank 0, $3000', 'snd_ftab:']
    for i in range(0, 2048, 8):
        lines.append('    dw ' + ', '.join('$%04X' % v for v in ft[i:i + 8]))
    lines.append('section bank 0, $2FC0')
    lines.append('snd_ntab:')
    lines.append('    db ' + ', '.join('$%02X' % v for v in nt))
    return '\n'.join(lines) + '\n'


# battle code macros (src/bat*.s): pointer accesses as FF3's (zp),Y. %LDZ zp, off: A = [[BZ+zp] + off]
# (HL left at the byte); %STZ zp, off: the same address = A (B used); %PZ zp, off: HL = the address
# (%STZ / %PZ: an address in FF3's ROM range, GB $E000+, goes to a dummy: the NES ignores such writes);
# %LDX table: A = [table + X] with X in [BZ_X]; %MOVZ dst, src: a 16-bit pointer copy in BZ
# tables of FF3's code banks filled from the user's ROM after assembling: label -> (NES bank, address, n)
ROMDATA = {
    'w_songs': (0x3B, 0xA027, 32),       # world map songs by world and vehicle
    'refl_bits': (0x31, 0xBB0E, 11),     # spells that Reflect bounces
    'mon_rows': (0x34, 0x8739, 20),      # monster rows by formation tilemap
    'mmsg_bits': (0x35, 0xA5FD, 9),      # spells with a message after them
    'job_cmds': (0x34, 0x9B21, 88),      # the four battle commands of each job
    'msg_vars': (0x34, 0x9575, 72),      # each battle message's variable (a nibble each)
    'eq_types': (0x00, 0x8900, 384),     # equipment / spell types: the jobs allowed (3 bytes)
    'terr_bits': (0x35, 0xAB06, 1),      # terrain attacks: one monster or all
    'fld_rng': (0x3F, 0xFE00, 256),      # the field's random numbers
    'enc_prob': (0x3D, 0xBD78, 64),      # which of a group's 8 battles
    'sp_mask': (0x3D, 0xA20C, 56),       # menu: each spell's bit in its level's known byte
    'sp_lvl': (0x3D, 0xA244, 56),        # menu: each spell's level byte ($6207 + n)
    'sp_ptr': (0x3D, 0xA27C, 56),        # menu: each spell's level slots in the list buffer
    'wp_comb': (0x3C, 0x9D4B, 16),       # menu: the hand pairs allowed (weapon types 4 x 4)
    'job_prog': (0x3D, 0xAD59, 44),      # menu: each job's level-up table (bank 39)
    'sa_a5f9': (0x3B, 0xA5F9, 16),       # special animations ($EF): their sprite data
    'sa_a6d4': (0x3B, 0xA6D4, 96),
    'sa_a77a': (0x3B, 0xA77A, 96),
    'sa_a906': (0x3B, 0xA906, 80),
    'sa_a99a': (0x3B, 0xA99A, 32),
    'sa_ab61': (0x3B, 0xAB61, 8),
    'sa_99e4': (0x3A, 0x99E4, 80),       # (the statue explosion's five frames, 3 bytes a blast)
    'sa_9a48': (0x3A, 0x9A48, 40),
    'sa_9b04': (0x3A, 0x9B04, 16),
    'sa_9b2e': (0x3A, 0x9B2E, 26),
    'sa_9c1c': (0x3A, 0x9C1C, 24),
    'sa_9c34': (0x3A, 0x9C34, 128),
    'sa_9cb4': (0x3A, 0x9CB4, 240),
    'ws_sin': (0x3A, 0x9E3E, 256),       # world sprites: FF3's sine table, the ship's chain
    'ws_chtab': (0x3D, 0xBF7A, 126),
    'mg_prop': (0x2E, 0x91D0, 3 * 0x60),  # spells' animation properties (33/AF6F)
    'an_sin': (0x10, 0x9A80, 256),       # FF3's sine (2E/9F6C)
    'mg_blk': (0x33, 0xB1D7, 11),        # black / white pre-animation frames
    'mg_wht': (0x33, 0xB1E2, 12),
    'mg_bub': (0x33, 0xAEB2, 32),        # black magic's bubbles
    'mf_grid': (0x33, 0xB89B, 16),       # the spells' 6 x 6 frames: corner / steps, flips
    'mf_flip': (0x33, 0xB8AB, 4),
    'kl_ang': (0x33, 0xB413, 4),
    'sm_snd': (0x2F, 0xAFC0, 24),        # summons: each attack's sound
    'bs_bblks': (0x2F, 0xBE7F, 24),      # each boss's 4-tile blocks (entry / death)
    'sm_pal': (0x32, 0x8043, 8),         # the pre-animation's palette by summon
    'sm_pre': (0x33, 0xB1EE, 10),        # the pre-animation's frames
    'sm_fly': (0x33, 0xAFF2, 16),        # its four sprites flying off
    'fd_spd': (0x10, 0x8A4C, 16),        # the final boss's death: columns' speeds, the shake
    'fd_shk': (0x10, 0x8A5C, 8),
    'fw_pal': (0x10, 0x8BC9, 12),        # Flare Wave's green palettes, the wave's shapes and
    'fw_rows': (0x10, 0x8D30, 80),       #   sprite lists (10/8A15, 10/8CE6)
    'fw_lst': (0x10, 0x8D80, 0x44),
    'sm_data': (0x2A, 0x9440, 0x1C0),    # the summons' properties (2A/9440) and sprite maps
    'sm_lst': (0x32, 0x8F8B, 0x91D7 - 0x8F8B),   # the summon attacks' sprite lists
    'if_hue': (0x32, 0x87E9, 3),
    'mn_rows': (0x34, 0x8739, 20),
    'fb_tiles': (0x33, 0xB9CE, 12),
    'fb_x': (0x33, 0xB9DA, 6),
    'fb_cnt': (0x33, 0xB9E0, 6),
    'fb_spr': (0x32, 0x91D7, 48),
    'gl_col': (0x32, 0x804B, 22),
    'em_data': (0x06, 0x8E20, 5 * 0x60),
    'mg_snd': (0x34, 0x83A0, 0x58),      # each spell's sound
    'an_blob': (0x32, 0x943D, 0x375),    # battle animations (src/banim.s)
    'sl_pos': (0x32, 0x99D1, 24),
    'sl_tile': (0x32, 0x99E9, 12),
    'sl_mask': (0x32, 0x9968, 4),
    'an_max': (0x33, 0xA077, 9),
    'an_ids': (0x34, 0x83F8, 25),
    'wp_prop': (0x2E, 0x9098, 3 * 0x60),
    'cf_tiles': (0x32, 0x972E, 126),     # battle characters' frames (32/9111)
    'cf_pos': (0x32, 0x91D7, 144),
    'cf_set': (0x32, 0x926B, 21),
    'cf_setf': (0x32, 0x9280, 21),
    'f_spr0': (0x3C, 0x835E, 65),        # the Fat Chocobo's two pictures
    'f_spr1': (0x3C, 0x839F, 65),
    'uw_rng': (0x3F, 0xFE00, 256),       # underwater: random numbers, fish, wobble
    'uw_sw': (0x3A, 0x962D, 64),
    'uw_ft': (0x3A, 0x966D, 32),
    'uw_wt': (0x3A, 0x97EF, 32),
    'gu_poses': (0x3E, 0xDC6A, 64),      # the guest's poses
    'nj_h': (0x3B, 0xAC0C, 25),          # event: a person's jump height
    'dn_x': (0x3B, 0xADB1, 84),          # event: the dance's sub-x, sub-y, facings
    'dn_y': (0x3B, 0xAE05, 84),
    'dn_f': (0x3B, 0xAE59, 84),
}

MACROS = {
    'PZ': ['ld hl, BZ + ({0})', 'ld a, [hl+]', 'ld h, [hl]', 'add {1}', 'ld l, a', 'ld a, h', 'adc 0', 'ld h, a',
           'call wchk'],
    'LDZ': ['ld hl, BZ + ({0})', 'ld a, [hl+]', 'ld h, [hl]', 'add {1}', 'ld l, a', 'ld a, h', 'adc 0', 'ld h, a',
            'ld a, [hl]'],
    'STZ': ['ld b, a', 'ld hl, BZ + ({0})', 'ld a, [hl+]', 'ld h, [hl]', 'add {1}', 'ld l, a', 'ld a, h', 'adc 0',
            'ld h, a', 'call wchk', 'ld [hl], b', 'ld a, b'],
    'FAR': ['ld hl, {1}', 'ld a, {0}', 'call far_call'],
    'MOVZ': ['ld a, [BZ + ({1})]', 'ld [BZ + ({0})], a', 'ld a, [BZ + ({1}) + 1]', 'ld [BZ + ({0}) + 1], a'],
}


def expand(src):
    import re
    out = []
    for line in src.split('\n'):
        m = re.match(r'^(\s*(?:[.\w]+:)?\s*)%(\w+)\s*(.*?)\s*(;.*)?$', line)
        if m and m.group(2) in MACROS:
            args = [a.strip() for a in m.group(3).split(',')] if m.group(3) else []
            body = MACROS[m.group(2)]
            out.append(m.group(1) + body[0].format(*args))
            out += ['            ' + b.format(*args) for b in body[1:]]
        else:
            out.append(line)
    return '\n'.join(out)


def main():
    a = sys.argv[1:]
    nes = a[a.index('--nes') + 1] if '--nes' in a else os.path.join(ROOT, 'build', 'ff3_en.nes')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff3n.gbc')
    mp = (a[a.index('--map') + 1] if '--map' in a else '0').split(',')   # --map M[,WORLD[,X,Y]]
    mp = [int(v) for v in mp] + [0, 255, 255][len(mp) - 1:]
    test_map, test_world, test_x, test_y = mp[:4]
    raw = open(nes, 'rb').read()
    cut_raw, cut_gfx, cut_eq = cutdata.build(data.Rom(nes))
    tbanks, tlay, tlast = text.banks(B_TEXT)
    assert tlast < B_SCRIPT, 'text banks overflow'
    text_defs = ''.join('T_%s = $%04X\n' % (k.upper(), v) for k, v in tlay.items())
    if hashlib.sha1(raw).hexdigest() != EN_SHA1:
        print('note: %s is not the expected English FF3 NES ROM (SHA-1 %s)' % (nes, EN_SHA1))
    src = (open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() + '\n' +
           'START_MAP = %d\nSTART_WORLD = %d\nSTART_X = %d\nSTART_Y = %d\n' % (test_map, test_world, test_x, test_y) +
           'HAS_TITLE = %d\n' % (1 if os.environ.get('GB3N_TITLE') else 0 if ('--map' in a or os.environ.get('GB3N_TEST')) else 1) +
           'B_MAPINFO = %d\nB_MAPAUX = %d\nB_EVENTS = %d\nB_CHARS = %d\nB_COMMON = %d\n' % (
               B_MAPINFO, B_MAPAUX, B_EVENTS, B_CHARS, B_COMMON) +
           'B_NPCS = %d\nB_NPCGFX = %d\nB_OWN = %d\nB_TEXT = %d\nB_SCRIPT = %d\nB_FIELD = %d\n' % (
               B_NPCS, B_NPCGFX, B_OWN, B_TEXT, B_SCRIPT, B_FIELD) +
           'B_WORLD0 = %d\nB_WINFO = %d\nB_WGFX = %d\nB_SND0 = %d\n' % (B_WORLD0, B_WINFO, B_WGFX, B_SND0) +
           'B_BAT = %d\nB_BDAT = %d\nB_BDAT2 = %d\nB_BDAT3 = %d\nB_BAT2 = %d\nB_BSET = %d\n' % (B_BAT, B_BDAT, B_BDAT2, B_BDAT3, B_BAT2, B_BSET) +
           'B_BSCR = %d\nB_BINFO = %d\nB_CGFX = %d\nB_MGFX0 = %d\nB_BOSS0 = %d\nB_MENU = %d\nB_VGFX = %d\n' % (B_BSCR, B_BINFO, B_CGFX, B_MGFX0, B_BOSS0, B_MENU, B_VGFX) + text_defs +
           'B_CUT = %d\nB_CUTG = %d\nB_WSPR = %d\nB_MINI = %d\nB_ANIM = %d\nB_MAGIC = %d\nB_BANIM = %d\nB_SUMN = %d\n' % (B_CUT, B_CUTG, B_WSPR, B_MINI, B_ANIM, B_MAGIC, B_BANIM, B_SUMN) + cut_eq +
           open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'field.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'npc.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'text.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'event.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'evfx.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'guest.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'world.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'fbattle.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'vehicle.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'water.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'sound.s')).read() + '\n' +
           ''.join(open(os.path.join(HERE, 'src', f)).read() + '\n' for f in BATTLE_SRC) +
           open(os.path.join(HERE, 'src', 'cut.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'cutend.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'wspr.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'sa.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'mini.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'banim.s')).read() + '\n' + open(os.path.join(HERE, 'src', 'bsumn.s')).read() + '\n' + open(os.path.join(HERE, 'src', 'batfx.s')).read() + '\n' + open(os.path.join(HERE, 'src', 'batbk.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'menu.s')).read() + '\n' + menu_data() + sound_data() + own_data(raw))
    if os.environ.get('GB3N_BATTLE'):            # test builds only: every encounter is this battle
        src = src.replace('            ld [bs_id], a\n            xor a\n            ld [bs_id + 1], a',
                          '            ld a, %s\n            ld [bs_id], a\n            xor a\n            ld [bs_id + 1], a' % os.environ['GB3N_BATTLE'])
    if os.environ.get('GB3N_STORY'):             # test builds only: Start runs the ending ($DD)
        st = os.environ['GB3N_STORY']
        ev = {'prol': 'ev_prol', 'epi': 'ev_epi', 'fx': 'ev_fxtest'}.get(st, 'ev_satest' if st.startswith('sa') else 'ev_ending')
        if st == 'ipick':
            ev = 'ev_iptest'
            src += 'section bank B_FIELD, $7980\nev_iptest:  %FAR B_MENU, m_ipick\n            jp map_reload\n'
        if st == 'bat':                          # (GB3N_STORY=bat: battle GB3N_BATTLE on Start)
            ev = 'ev_battest'
            src += 'section bank B_FIELD, $7980\nev_battest: ld a, %s\n            ld [bs_id], a\n            xor a\n            ld [bs_id + 1], a\n            jp battle_run\n' % os.environ.get('GB3N_BATTLE', '1')
        if st == 'dlg':                          # (GB3N_STORY=dlg: dialogue GB3N_DLG of t8400 on Start)
            ev = 'ev_dlgtest'
            src += 'section bank B_FIELD, $7980\nev_dlgtest: ld c, %s\n            ld b, TB_DLG1\n            jp dlg_open\n' % os.environ.get('GB3N_DLG', '$1A')
        if st == 'mini':                         # (GB3N_STORY=mini: the minimap on Start)
            ev = 'ev_mmtest'
            src += 'section bank B_FIELD, $7980\nev_mmtest:  %FAR B_MINI, mm_show\n            jp map_reload\n'
        if st == 'fat':                          # (GB3N_STORY=fat: the Fat Chocobo on Start)
            ev = 'ev_fattest'
            src += 'section bank B_FIELD, $7980\nev_fattest: ld a, $FC\n            ld [ev_who], a\n            %FAR B_MENU, m_shop\n            jp map_reload\n'
        if ev == 'ev_satest':                    # (GB3N_STORY=saN: special animation N on Start)
            src += 'section bank B_FIELD, $7980\nev_satest:  ld a, %d\n            ld [ev_arg], a\n            jp ev_sanim\n' % int(st[2:], 16)
        src = src.replace('            jp nz, menu_open', '            jp nz, ' + ev)
        if ev == 'ev_fxtest':                    # (each event effect in turn, Ur's people 1 / 2)
            src += '''section bank B_FIELD, $7400
ev_fxtest:  call ev_shake
            call ev_flash
            call ev_dark
            ld b, 60
.w:         push bc
            call ev_fx_fr
            pop bc
            dec b
            jr nz, .w
            call ev_undark
            ld hl, NPC1 + $10
            ld a, $0B
            call ev_npcx
            ld hl, NPC1 + $10
            ld a, $0F
            call ev_npcx
            ld hl, NPC1 + $20
            ld a, $0E
            call ev_npcx
            jp ev_dance
'''
    if os.environ.get('GB3N_ANTEST'):            # test builds only: every fight shows spell N's cast
        extra = ''
        if os.environ.get('GB3N_ANTYPE'):       # (and the animation type $7E9D)
            extra += '            ld a, %s\n            ld [$DE9D], a\n' % os.environ['GB3N_ANTYPE']
        if os.environ.get('GB3N_ANSUM'):        # (the summon: id x 16 + attack)
            extra += '            ld a, %s\n            ld [$DE94], a\n' % os.environ['GB3N_ANSUM']
        if os.environ.get('GB3N_ANTGT') == 'char':   # (shown on member 0)
            extra += '            ld a, [$DE9A]\n            and $BF\n            ld [$DE9A], a\n            ld a, $80\n            ld [$DE9B], a\n            ld [$DE99], a\n'
        src = src.replace('an_kind:    ld a, [$DEC2]', 'an_kind:    ld a, %s\n            ld [$DE88], a\n            ld a, [$DEC2]\n            cp 4\n            jr nz, .ak\n%s            ld a, %s\n            ret\n.ak:        ld a, [$DEC2]' % (os.environ['GB3N_ANTEST'], extra, os.environ.get('GB3N_ANKIND', '1')))
    if os.environ.get('GB3N_BATHI'):             # test builds only: the battle index + $100 (event battles)
        src = src.replace('.w0:        ld [$DCEE], a', '.w0:        ld a, 1\n            ld [$DCEE], a')
    if os.environ.get('GB3N_BACKTEST'):          # test builds only: every battle a back attack
        a = '            ld [$D8BA], a\n            ld a, [$DED8]\n'
        assert src.count(a) == 1
        src = src.replace(a, '            ld [$D8BA], a\n            jp .back\n            ld a, [$DED8]\n')
    if os.environ.get('GB3N_CANNON'):            # test builds only: every battle as on the Invincible (cannon)
        a = '.w:         ld a, [$D4C6]\n            cp 7\n            jr nz, .v\n'
        assert src.count(a) == 1
        src = src.replace(a, '.w:\n')
    if os.environ.get('GB3N_FDTEST'):            # test builds only: the boss's death right after its entry
        src = src.replace('            call bs_bossin2\n', '            call bs_bossin2\n            ld b, 60\n.fdw:       push bc\n            call bs_frame\n            pop bc\n            dec b\n            jr nz, .fdw\n            ld a, $80\n            call bs_bossdie\n')
    if os.environ.get('GB3N_MSGTEST'):           # test builds only: a battle message with an item at the start
        src = src.replace('            call bs_bossin2\n', '            call bs_bossin2\n            ld a, %s\n            ld [$D8E4], a\n            ld a, $29\n            ld [$D8DA], a\n            ld a, 2\n            ld [$D8D5], a\n            ld a, 1\n            ld [$DEC2], a\n            call bs_script\n' % os.environ['GB3N_MSGTEST'])
    if os.environ.get('GB3N_WIPETEST'):          # test builds only: the death wipe on slot 0 at the start
        src = src.replace('            call bs_bossin2\n', '            call bs_bossin2\n            ld b, 60\n.wtw:       push bc\n            call bs_frame\n            pop bc\n            dec b\n            jr nz, .wtw\n            ld a, $80\n            call bs_mwipe\n')
    if os.environ.get('GB3N_ANWPN'):             # test builds only: the right hand's weapon animation
        src = src.replace('            call an_wgfx                    ; the weapons\' tiles and palettes (2F/A8EA)',
                          '            call an_wgfx\n            ld a, %s\n            ld [an_t1], a\n            ld a, [BZ + $BB]\n            and a\n            jr nz, .wt\n            inc a\n            ld [BZ + $BB], a\n.wt:' % os.environ['GB3N_ANWPN'])
    if os.environ.get('GB3N_TEST'):              # test builds: tools/gb3n/test (never a release)
        src = src.replace('.nw:        call map_enter', '.nw:        jp test_loop')
        src += open(os.path.join(HERE, 'src', 'test.s')).read() + '\n'
    import re                                    # (constants from every file first)
    lines = expand(src).split('\n')
    is_def = lambda l: re.match(r'^[A-Za-z_]\w*\s+=', l)
    src = '\n'.join([l for l in lines if is_def(l)] + [l for l in lines if not is_def(l)])
    import asm_sm83
    asm_sm83.RAM_SECTIONS[:] = []
    r = asm(src)
    secs = sorted(set((a, b) for a, b, _ in asm_sm83.RAM_SECTIONS if b > a))   # (RAM sections may
    for (a0, a1), (b0, b1) in zip(secs, secs[1:]):                        #   not overlap)
        assert a1 <= b0, 'RAM sections overlap: %04X-%04X and %04X-%04X' % (a0, a1, b0, b1)
    if os.environ.get('GB3N_RAMMAP'):            # the RAM sections (and the gaps between them)
        for (a0, a1), nx in zip(secs, secs[1:] + [(0xE000, 0xE000)]):
            print('ram %04X-%04X%s' % (a0, a1, '  gap %d' % (nx[0] - a1) if nx[0] > a1 else ''))
    for a0, a1 in secs:                                                     # ($CF00-$CFFF: the stack)
        assert a1 <= 0xCF00 or a0 >= 0xD000, 'RAM section %04X-%04X in the stack' % (a0, a1)
    banks = dict(r.banks)
    if os.environ.get('GB3N_GAPS'):              # free runs (32+ bytes) of a code bank: GB3N_GAPS=29
        gb = int(os.environ['GB3N_GAPS']); run = []
        for off in range(0x4000 + 1):
            if off < 0x4000 and not r.claimed.get((gb, off)): run.append(off)
            else:
                if len(run) >= 32: print('bank %d free: $%04X-$%04X (%d)' % (gb, run[0] + (0x4000 if gb else 0), run[-1] + (0x4000 if gb else 0), len(run)))
                run = []
    rom = data.Rom(nes)
    for name, (nb, addr, n) in ROMDATA.items():
        if name not in r.labels: continue
        gb, ga = r.label_bank[name], r.labels[name]
        off = ga - (0x4000 if gb else 0)
        banks[gb] = bytearray(banks[gb])
        v = rom.rd(nb, addr, n)
        banks[gb][off:off + n] = bytes([v]) if isinstance(v, int) else v
    cb = bytearray(banks[B_CUT]) + bytearray(0x4000 - len(banks[B_CUT]))
    assert not any(r.claimed.get((B_CUT, o)) for o in range(0x2000)), 'cut code below $6000'
    cb[0:0x2000] = cut_raw; banks[B_CUT] = cb            # NES bank $1F under the cutscene code
    assert B_CUTG not in banks; banks[B_CUTG] = cut_gfx
    wb = bytearray(banks[B_WSPR]) + bytearray(0x4000 - len(banks[B_WSPR]))   # world-map sprites:
    assert not any(r.claimed.get((B_WSPR, o)) for o in range(0x1D00))      #   3D/BDE0's loads
    rd = lambda b8, a, n: rom.rd(b8, a, n)
    base = rd(0x0B, 0x8700, 0x100) + rd(0x0B, 0x9E80, 0x80) + rd(0x0B, 0x9900, 0x80)
    for k, mid in enumerate((rd(0x0B, 0x9500, 0x200), rd(0x0B, 0x9700, 0x200),
                             rd(0x0B, 0x9980, 0x100) + rd(0x0B, 0x9F00, 0x100))):
        t = base + mid + rd(0x0B, 0x9A80, 0x400)
        wb[0x800 * k:0x800 * k + 0x800] = b''.join(tiles.gb(t[16 * i:16 * i + 16]) for i in range(128))
    wb[0x1800:0x1D00] = rd(0x3C, 0x8300, 0x500)                       # bank $3C's sprite lists
    banks[B_WSPR] = wb
    import minimap                               # the minimap's screen data
    mb = bytearray(banks.get(B_MINI, b'')) + bytearray(0x4000 - len(banks.get(B_MINI, b'')))
    assert not any(r.claimed.get((B_MINI, o)) for o in range(0x2000))
    mb[0:0x2000] = minimap.gb_bank(rom)
    banks[B_MINI] = mb
    ab = bytearray(b"".join(tiles.gb(t) for t in (rom.rd(0x2B, 0xB000 + 16 * i, 16) for i in range(256)))) + bytearray(0x3000)
    at, an = bytearray(), bytearray()               # 33/BEB2's animation graphics sets: tiles from
    for k in range(18):                             #   $1000, the table at $0F00 (offset, OBJ tile, count)
        lo, hi, plo, phi, cnt, bk = rom.rd(0x33, 0xBEB2 + 6 * k, 6)
        addr, ppu = hi << 8 | lo, phi << 8 | plo
        if not (0x1000 <= ppu < 0x2000 and addr >= 0x8000):
            at += bytes(4); continue
        o = 0x1000 + len(an)
        an += b''.join(tiles.gb(rom.at(bk * 0x4000 + addr - 0x8000 + 16 * i, 16)) for i in range(cnt))
        at += bytes([o & 255, (o >> 8) + 0x40, (ppu - 0x1000) // 16, cnt])
    def rd16(b8, a):                              # (a pointer in a 16 KB bank pair)
        lo, hi = rom.rd(b8, a, 2)
        return hi << 8 | lo
    def at16(b16, a, n):                          # n bytes at $8000-$BFFF of 16 KB bank b16
        return rom.at(b16 * 0x4000 + a - 0x8000, n)
    mdat = bytearray()                            # the spells' hit animations (33/B68D): lists
    mtab = bytearray()                            #   (06/8C00) and 6 x 6 frames (00/9708)
    base = 0x1000 + len(an)
    for sp in range(0x80):
        a = rd16(0x06, 0x8C00 + 2 * sp)
        n = at16(3, a, 2)[0] if 0x8000 <= a < 0xC000 else 0
        lst = at16(3, a, n + 1) if n else bytes(1)
        o = base + len(mdat)
        mtab += bytes([o & 255, (o >> 8) + 0x40])
        mdat += lst
    ftab = bytearray()
    for f in range(0x80):
        a = rd16(0x00, 0x9708 + 2 * f)
        raw, i, k = (at16(0, a, 80) if 0x8000 <= a < 0xC000 else bytes(80)), 0, 0
        while k < 36 and i < 80:                  # (rvhttttt; r: the next byte repeats it)
            if raw[i] & 0x80:
                k += raw[i + 1] or 256; i += 2
            else:
                k += 1; i += 1
        o = base + len(mdat)
        ftab += bytes([o & 255, (o >> 8) + 0x40])
        mdat += raw[:i]
    an += mdat
    assert len(an) <= 0x2C00, hex(len(an))
    ab[0xE00:0xF00] = mtab + ftab[:0]
    ab[0xD00:0xE00] = ftab[:256]
    ab[0xF00:0xF00 + len(at)] = at
    ab[0x1000:0x1000 + len(an)] = an
    banks[B_ANIM] = ab
    banks[B_MAGIC] = bytearray(b''.join(tiles.gb(rom.at(0x15 * 0x4000 + 16 * i, 16)) for i in range(1024)))
    st = b''.join(tiles.gb(rom.at(6 * 0x4000 + 0x1800 + 16 * i, 16)) for i in range(640))
    banks.setdefault(B_SUMN, bytearray(0x4000))
    banks[B_SUMN] = bytearray(banks[B_SUMN])
    banks[B_SUMN][:len(st)] = st
    for k, v in tbanks.items():
        assert k not in banks, 'bank %d used twice' % k
        banks[k] = v
    for k, v in field_banks(rom).items():
        assert k not in banks, 'bank %d used twice' % k
        banks[k] = v
    img = make_rom(banks, 'FF3 NATIVE', cart_type=0x1B, rom_banks=ROM_BANKS,
                   ram_size_code=RAM_CODE, sgb=False, cgb=0xC0)
    check_header(img)
    open(out, 'wb').write(img)
    base = os.path.splitext(out)[0]
    open(base + '.sym', 'w').write(r.sym_file())
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


def check_header(rom):
    """Lot Check 1.x (docs/gb-release-checks.md), recomputed independently of make_rom: the logo (by
    its SHA-1), the header and global checksums, FF3's flags (Color only $C0, no SGB, MBC5 + RAM +
    battery, 32 KB cart RAM) and the size"""
    import hashlib
    assert hashlib.sha1(bytes(rom[0x104:0x134])).hexdigest() == '0745fdef34132d1b3d488cfbdf0379a39fd54b4c', 'logo'
    x = 0
    for i in range(0x134, 0x14D): x = (x - rom[i] - 1) & 0xFF
    assert rom[0x14D] == x, 'header checksum'
    assert (sum(rom) - rom[0x14E] - rom[0x14F]) & 0xFFFF == rom[0x14E] << 8 | rom[0x14F], 'global checksum'
    assert (rom[0x143], rom[0x146], rom[0x147], rom[0x149]) == (0xC0, 0x00, 0x1B, 0x03), 'flags'
    assert len(rom) == ROM_BANKS * 0x4000 == 0x8000 << rom[0x148], 'ROM size'


if __name__ == '__main__':
    main()
