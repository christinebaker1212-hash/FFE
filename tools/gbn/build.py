"""Build the native FF1 Game Boy ROM (docs/ff1-native.md) from the English NES ROM the
existing pipeline makes. Game data is read from that ROM here, at build time; the bank layout
is described at the top of tools/gbn/src/main.s.
usage: python3 tools/gbn/build.py [--nes build/ff1_gb.nes] [--out build/ff1n.gb] [--start MAP,X,Y]"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from asm_sm83 import asm, make_rom
import data, minimap, sgb, text, talkconst, ui, names, battle, sound

COMMON, TS_BANK0, MAP_BANK0, OW_TS, OW_INFO, OW_ROWS, ROM_BANKS = 1, 8, 20, 16, 81, 84, 128


def place(banks, bank, addr, blob):
    b = banks.setdefault(bank, bytearray(b'\xff' * 0x4000))
    o = addr - 0x4000
    assert o + len(blob) <= 0x4000, 'bank %d overflow at %04X' % (bank, addr)
    b[o:o + len(blob)] = blob


DIS = os.path.join(ROOT, 'build', 'ref', 'FF1Disassembly', 'Final Fantasy Disassembly')


def domains_source(rom):
    """FF1's encounter domains, all 128 (64 overworld, 64 standard maps: map + 64), 8 formations
    each (lut_Domains, bank $0B $8000), in bank 104 $4C00 (the battle data bank kept 64 only, so
    every dungeon read its formations from the encounter rates and glyphs after them)"""
    d = rom.rd(0x0B, 0x8000, 128 * 8)
    out = ['section bank 104, $4C00', 'B_DOMAINS:']
    for i in range(0, len(d), 16):
        out.append('            db ' + ', '.join('$%02X' % b for b in d[i:i + 16]))
    return '\n'.join(out) + '\n'


def weapon_slots(rom):
    """FF1's weapon and armour slot offsets (16 + 16), from the operands of FindEmptyWeaponSlot
    and FindEmptyArmorSlot in the fixed bank"""
    fix = rom.prg[-0x4000:]
    out = []; i = 0
    while len(out) < 2:
        i = fix.find(bytes([0xA0, 0x00, 0xBE]), i)
        assert i >= 0, 'weapon slot finder not found'
        a = fix[i + 3] | fix[i + 4] << 8
        if fix[i + 5:i + 8] == bytes([0xBD, 0x00, 0x61]):
            out.append(fix[a - 0xC000:a - 0xC000 + 16])
        i += 1
    return out[0] + out[1]


def talk_defs(rom):
    """TK_<routine>_<n> = the n-th operand of FF1's talk routine (save-RAM addresses mapped to
    the engine's copy at $D000)"""
    _, ops = talkconst.extract(rom, DIS)
    out = []
    for n, lst in ops.items():
        for k, (t, v, mn) in enumerate(lst):
            if t == 'a' and 0x6000 <= v < 0x6400: v = 0xD000 + v - 0x6000
            out.append('TK_%s_%d = $%04X' % (n, k, v))
    return '\n'.join(out) + '\n'


def item_defs(rom):
    """IT_<routine>_<n> = the n-th operand of FF1's item routine (as talk_defs)"""
    ops, _ = talkconst.item_routines(rom, DIS)
    out = []
    for n, lst in ops.items():
        for k, (t, v, mn) in enumerate(lst):
            if t == 'a' and 0x6000 <= v < 0x6400: v = 0xD000 + v - 0x6000
            out.append('IT_%s_%d = $%04X' % (n, k, v))
    return '\n'.join(out) + '\n'


def magic_defs(rom):
    """MG_<spell>_ID = its spell id, MG_<spell>_<n> = the n-th operand of FF1's routine"""
    ids, ops, nomp, cant = talkconst.magic_routines(rom)
    out = ['MG_NOMP = $%02X' % nomp, 'MG_CANT = $%02X' % cant]
    for n, i in ids.items():
        out.append('MG_%s_ID = $%02X' % (n, i))
        for k, (t, v, mn) in enumerate(ops[n]):
            if t == 'a' and 0x6000 <= v < 0x6400: v = 0xD000 + v - 0x6000
            out.append('MG_%s_%d = $%04X' % (n, k, v))
    return '\n'.join(out) + '\n'


def snd_tables(rom):
    ft, tsm, vm = sound.tables(rom)
    db = lambda b: ''.join('            db ' + ', '.join('$%02X' % x for x in b[i:i + 16]) + '\n'
                           for i in range(0, len(b), 16))
    sfx, nz = sound.sfx_data(rom)
    return ('section bank 7, $6F00\n' + db(tsm) + 'section bank 7, $6F10\n' + db(vm) +
            'section bank 7, $7000\n' + db(ft) + 'section bank 7, $%04X\n' % sound.SFX_ADDR +
            db(sfx) + 'section bank 7, $6E40\n' + db(nz))


def mmp_source():
    """the Modern MP table (tools/gbn/modern_mp.py: Dawn of Souls data kept there) at MMP_TAB"""
    import modern_mp
    t = modern_mp.tables()
    return 'section bank %d, $7F00\n' % modern_mp.MMP_BANK + ''.join(
        '            db ' + ', '.join(str(v) for v in t[k:k + 16]) + '\n' for k in range(0, len(t), 16))


def cc_source():
    """the Color's LCD colour correction (Options: LCD, owner 2026-11-24): per mode a 32-entry
    curve applied to each channel before the saturation step (src/cc.s): GBC Corrected deepens
    the mid-tones (the GBC panel washes them out), GBA Corrected lifts them (the GBA's darker
    screen)"""
    out = ['section bank 0, $2F80', 'cc_lut:']
    for gam in (1.25, 0.70):
        v = [min(31, round(31 * (c / 31) ** gam)) for c in range(32)]
        out.append('            db ' + ', '.join(str(x) for x in v))
    return '\n'.join(out) + '\n'


def ap_source():
    """the airship's view (src/air.s): per level k (0-32, smoothed) the SCY offset of each line
    0-63 above the ship's line (the mock-up's curve: a line d above it shows the map d + t a d^2
    above, so the horizon line shows ROOM lines up), the levels' horizons, the sky's colours"""
    YC, ROOM = 64, 160
    rows, hzs = [], []
    for k in range(33):
        t = k / 32; t = t * t * (3 - 2 * t)
        hz = int(round(28 * t)); dmax = YC - hz
        a = (ROOM - dmax) / (dmax * dmax) if dmax > 0 else 0
        row = []
        for y in range(YC):
            d = YC - y
            row.append(0 if y < hz else min(255, int(round(t * a * d * d))))
        rows.append(row); hzs.append(hz)
    top, hor = (6, 12, 28), (25, 28, 31)                 # RGB555 levels: deep blue to pale
    sky = []
    for y in range(32):
        f = min(1.0, y / 27)
        c = [int(round(top[i] + (hor[i] - top[i]) * f)) for i in range(3)]
        sky.append(c[0] | c[1] << 5 | c[2] << 10)
    out = ['section bank 99, $6600']
    for row in rows:
        out.append('            db ' + ', '.join(str(v) for v in row))
    out.append('            db ' + ', '.join(str(v) for v in hzs))
    out.append('            dw ' + ', '.join('$%04X' % v for v in sky))
    return '\n'.join(out) + '\n'


def ui_strings():
    """the screens' strings as str_<name> labels in code bank 2"""
    out = ['section bank 2, $6C00']
    for n, b in sorted(ui.strings().items()):
        out.append(data.db('str_' + n, b + b'\0'))
    out.append('zz_end_7000:')
    return '\n'.join(out) + '\n'


def data_banks(rom, ff3=None, init=None):
    banks = {}
    data.FONT_CODES = text.field_codes()
    c = data.common_pack(rom)
    place(banks, COMMON, 0x4000, c['spr_tiles'])
    place(banks, COMMON, 0x4100, c['mapman'])
    place(banks, COMMON, 0x4200, c['tele'])
    place(banks, COMMON, 0x4340, c['rooms'])                  # teleports into rooms (C_ROOMS)
    place(banks, COMMON, 0x4400, c['objtbl'])                 # object 2x2 tables (64)
    place(banks, COMMON, 0x4500, c['init_unsram'])            # new game: save page 0
    place(banks, COMMON, 0x4600, c['init_flags'])             #   and the game flags
    if init:                                                   # test builds: a whole save page
        pg = bytearray(c['init_unsram'] + bytes(256) + c['init_flags'] + bytes(256))
        for a_, v in init: pg[a_] = v
        place(banks, COMMON, 0x5E00, bytes(pg))
    place(banks, COMMON, 0x4700, text.win_palette())
    fd, fc = text.font_banks(rom, ff3)
    place(banks, COMMON, 0x4800, fd)
    place(banks, COMMON, 0x5000, fc)
    place(banks, COMMON, 0x5800, rom.rd(14, talkconst.TALK_DATA, 4 * talkconst.N_OBJ))  # talk data
    kind, _ = talkconst.extract(rom, DIS)
    place(banks, COMMON, 0x5C00, kind)                         # talk routine kind per object id
    place(banks, COMMON, 0x5D00, weapon_slots(rom))           # weapon slots (16), armour (16)
    nb = names.names_bank(rom, ff3)
    nb[0x3000:0x3200] = rom.rd(0x0D, 0xBC00, 0x200)            # item prices (FF1 lut_ItemPrices)
    nb[0x3200:0x3300] = rom.rd(0x00, 0xB100, 0x100)            # chest contents (lut_Treasure)
    banks[names.NAMES_BANK] = nb
    banks[ui.MTEXT_BANK] = bytearray(ui.mtext_bank(rom))
    banks[battle.BTL_DATA] = bytearray(battle.data_bank(rom))
    banks[sound.MUS_DATA] = bytearray(rom.prg[13 * 0x4000:14 * 0x4000])   # FF1's music data
    for b, blob in battle.chr_banks(rom).items(): banks[b] = bytearray(blob)
    for b, blob in battle.sil_banks(rom).items(): banks[b] = bytearray(blob)
    place(banks, battle.HITL_BANK, 0x4000, battle.hit_tiles())
    place(banks, battle.TRANS_BANK, 0x4000, battle.trans_tables())
    banks[battle.BOBJ_BANK] = bytearray(battle.obj_bank(rom))
    banks[minimap.MINI_BANK] = bytearray(minimap.bank(rom))
    banks[sgb.SGB_BANK] = bytearray(sgb.bank(rom))
    place(banks, COMMON, 0x5D40, b''.join(data.rgb555(c).to_bytes(2, 'little') for c in range(64)))
    banks[3] = bytearray(ui.gfx_bank(rom))                     # UI_GFX
    for b, blob in text.dialogue_banks(90).items():
        banks[b] = bytearray(blob)
    for ts in range(8):
        t = data.tileset_pack(rom, ts)
        place(banks, TS_BANK0 + ts, 0x4000, t['prop'])
        place(banks, TS_BANK0 + ts, 0x4100, t['tsa'])          # UL, UR / DL, DR pages
        place(banks, TS_BANK0 + ts, 0x4300, t['mt_pal'])
        place(banks, TS_BANK0 + ts, 0x4400, t['cgb_tiles'])
    o = data.ow_pack(rom)
    place(banks, OW_TS, 0x4000, o['prop'])
    place(banks, OW_TS, 0x4100, o['tsa'])
    place(banks, OW_TS, 0x4300, o['mt_pal'])
    place(banks, OW_TS, 0x4400, o['cgb_tiles'])
    place(banks, OW_INFO, 0x5000, o['cgb_bg'] + o['cgb_bg'])
    place(banks, OW_INFO, 0x5040, o['cgb_obj'])
    wa, wa_info = water_anim(o)                                 # (the animated sea and rivers)
    place(banks, WANIM_BANK, 0x4000, wa)
    print('water animation:', wa_info)
    place(banks, OW_INFO, 0x7400, o['veh_cgb'])                # vehicle sprites (FF1 OW objects)
    place(banks, OW_INFO, 0x7A00, o['veh_dmg'])
    fix = rom.prg[-0x4000:]                                     # FF1's vehicle sprite tables
    place(banks, OW_INFO, 0x5070, fix[0xE3F9 - 0xC000:0xE3F9 - 0xC000 + 9])   # lut_VehicleSprY
    place(banks, OW_INFO, 0x5080, fix[0xE4A6 - 0xC000:0xE4A6 - 0xC000 + 9])   # facing offsets
    vt = fix[0xE4F6 - 0xC000:0xE4F6 - 0xC000 + 64]           # lut_VehicleSprTbl (FF1's order
    vt = b''.join(vt[8 * f:8 * f + 2] + vt[8 * f + 4:8 * f + 6] + vt[8 * f + 2:8 * f + 4] +
                  vt[8 * f + 6:8 * f + 8] for f in range(8))  #   UL, DL, UR, DR -> UL, UR, DL, DR)
    place(banks, OW_INFO, 0x50A0, vt)
    place(banks, OW_INFO, 0x5060, bytes([8]))
    place(banks, OW_INFO, 0x7200, o['party_dmg'])
    place(banks, OW_INFO, 0x7380, o['party_perm'])
    place(banks, OW_INFO, 0x73A0, o['sgb'])
    place(banks, OW_INFO, 0x73C0, o['nes_bg'])                   # (the palette cycling)
    mt, mc = data.mapman_all(rom)                               # the leader's map sprite
    place(banks, minimap.MINI_BANK, 0x6400, mt)
    place(banks, minimap.MINI_BANK, 0x7000, mc)
    pt, ps, pr = minimap.puzzle(rom)                            # the 15-puzzle
    place(banks, minimap.MINI_BANK, 0x7400, pt)
    place(banks, minimap.MINI_BANK, 0x7800, ps + pr)
    te, tg = minimap.the_end(rom)                               # "The End"
    place(banks, minimap.MINI_BANK, 0x7C00, te)
    place(banks, minimap.MINI_BANK, 0x7820, tg)
    place(banks, OW_INFO, 0x7300, b'\0' * 64)                  # no objects
    place(banks, OW_INFO, 0x5100, o['mt_dmg'] + o['mt_dmg'])
    place(banks, OW_INFO, 0x5800, o['dmg_tiles'])
    place(banks, OW_INFO, 0x7F00, o['font_tbl'])                 # (code $20: the black tile)
    place(banks, COMMON, 0x43C0, bytes([o['start'], o['start_y']]))
    for row in range(256):
        place(banks, OW_ROWS + row // 64, 0x4000 + (row % 64) * 256, o['rows'][row])
    for m in range(data.N_MAPS):
        p = data.map_pack(rom, m)
        b = MAP_BANK0 + m
        place(banks, b, 0x4000, p['map'])
        place(banks, b, 0x5000, p['cgb_bg_out'])
        place(banks, b, 0x5020, p['cgb_bg_in'])
        place(banks, b, 0x5040, p['cgb_obj'])
        place(banks, b, 0x5060, bytes([p['ts']]))
        place(banks, b, 0x7200, p['party_dmg'])
        place(banks, b, 0x7380, p['party_perm'])
        place(banks, b, 0x73A0, p['sgb'])
        place(banks, b, 0x73C0, p['nes_bg'])
        ob = p['objs']
        place(banks, b, 0x7300, ob['slots'].ljust(64, b'\0'))      # 15 x (id, x+flags, y, tile)
        place(banks, b, 0x7340, ob['blocks'].ljust(16, b'\0'))     # tile bases of the blocks
        place(banks, b, 0x7350, bytes([len(ob['blocks'])]))
        place(banks, b, 0x6800, ob['dmg'])                         # DMG object tiles (pre-shaded)
        place(banks, b, 0x7400, ob['cgb'])                          # CGB object tiles (raw)
        place(banks, b, 0x7F00, p['font_tbl'])                     # DMG font code -> tile
        place(banks, b, 0x5100, p['mt_dmg_out'])
        place(banks, b, 0x5300, p['mt_dmg_in'])
        place(banks, b, 0x5800, p['dmg_tiles'])
    return banks


WANIM_BANK = 106                                 # (src/wanim.s)
def water_anim(o):
    """the animated sea and rivers (owner's list, 2026-11-24; FF1 has none): the commonest open
    sea metatile and river metatile of the overworld, the halves of each 16 x 16 picture
    shifted a pixel in turn (sea sideways, river downwards), 32 half steps, for the Color's tiles and the DMG's
    pre-shaded ones. Only metatiles whose four tiles no other metatile uses (and that stay
    consistent where they repeat a tile) move: coasts and land never change.
    Bank layout: $4000 count; entries of 16 bytes from $4010 (Color tiles 4, DMG tiles 4, the
    frames' offsets (Color, DMG)); frames: 32 x 64 bytes each."""
    prop, tsa, tbl = o['prop'], o['tsa'], o['mt_dmg']
    freq = {}
    for r_ in o['rows']:
        for v in r_: freq[v & 0x7F] = freq.get(v & 0x7F, 0) + 1
    def kind(mt):
        d = prop[2 * mt]
        if not d & 1 or (d & 6) == 6: return None
        return 'sea' if not d & 4 else 'river'
    def dec(t):
        px = [[0] * 8 for _ in range(8)]
        for y in range(8):
            lo, hi = t[2 * y], t[2 * y + 1]
            for x in range(8): px[y][x] = (lo >> (7 - x) & 1) | (hi >> (7 - x) & 1) << 1
        return px
    def enc(px):
        out = bytearray()
        for y in range(8):
            lo = hi = 0
            for x in range(8):
                v = px[y][x]; lo |= (v & 1) << (7 - x); hi |= (v >> 1) << (7 - x)
            out += bytes([lo, hi])
        return bytes(out)
    def frames(tiles16, vertical, stagger=True):
        # (owner, 2026-11-24: as Final Fantasy Legend III's water) a pixel per 16 frames, the two
        # halves of the 16 x 16 picture taking turns 8 frames apart (sea: the upper and lower
        # halves sideways; river: the left and right halves downwards): 32 half steps, one per
        # 8 frames, half step j = the first half shifted (j + 1) / 2, the second j / 2
        q = [dec(t) for t in tiles16]                       # UL, UR, DL, DR
        img = [[q[(y >= 8) * 2 + (x >= 8)][y & 7][x & 7] for x in range(16)] for y in range(16)]
        out = []
        for j in range(32):
            a, b = ((j + 1) // 2, j // 2) if stagger else (j // 2, j // 2)
            if vertical:
                sh = [[img[(y - (a if x < 8 else b)) % 16][x] for x in range(16)] for y in range(16)]
            else:
                sh = [[img[y][(x - (a if y < 8 else b)) % 16] for x in range(16)] for y in range(16)]
            out.append([enc([[sh[qy * 8 + y][qx * 8 + x] for x in range(8)] for y in range(8)])
                        for qy in range(2) for qx in range(2)])
        return out
    pos_c, pos_d = {}, {}                               # tile -> the corners it is used at
    for k in range(4):
        for mt in range(128):
            pos_c.setdefault(tsa[128 * k + mt], set()).add(k)
            pos_d.setdefault(tbl[128 * k + mt], set()).add(k)
    ents, data_ = [], bytearray()
    for want, vert in (('sea', False), ('river', True)):
        cand = sorted((m for m in range(128) if kind(m) == want), key=lambda m: -freq.get(m, 0))
        for mt in cand[:1]:
            cid = [tsa[128 * k + mt] for k in range(4)]
            did = [tbl[128 * k + mt] for k in range(4)]
            # every use of a tile, by any metatile at any corner, must get the same picture in
            # every phase: the same corner as here, or a corner whose shifted quarter is equal
            def same(ids, pos_of, fr):
                for k, t in enumerate(ids):
                    for k2 in pos_of[t]:
                        if k2 != k and any(f[k2] != f[k] for f in fr): return False
                return True
            for stag in (True, False):                          # (one tile at every corner,
                fc = frames([o['cgb_tiles'][16 * t:16 * t + 16] for t in cid], vert, stag)  # as
                fd = frames([o['dmg_tiles'][16 * t:16 * t + 16] for t in did], vert, stag)  # the
                if same(cid, pos_c, fc) and same(did, pos_d, fd): break  # river: halves together)
            if not (same(cid, pos_c, fc) and same(did, pos_d, fd)): continue
            oc = 0x4100 + 0x1000 * len(ents)                   # (fixed places: entry e's Color
            od = oc + 0x800                                     #   frames at $4100 + $1000 e, DMG
            data_ += b''.join(b''.join(f) for f in fc)          #   at + $800)
            data_ += b''.join(b''.join(f) for f in fd)
            ents.append(bytes(cid) + bytes(did) + oc.to_bytes(2, 'little') + od.to_bytes(2, 'little')
                        + bytes(4))
    blob = bytearray(0x100)
    blob[0] = len(ents)
    for i, e in enumerate(ents): blob[0x10 + 16 * i:0x20 + 16 * i] = e
    return bytes(blob) + bytes(data_), [(e[0:4].hex(), e[4:8].hex()) for e in ents]


def main():
    a = sys.argv[1:]
    nes = a[a.index('--nes') + 1] if '--nes' in a else os.path.join(ROOT, 'build', 'ff1_gb.nes')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff1n.gb')
    st = a[a.index('--start') + 1].split(',') if '--start' in a else ['$FE', '0', '0']
    st = (list(st) + ['0'])[:4]                  # MAP,X,Y[,ROOM]
    rom = data.Rom(nes)
    ff3 = names.ff3_rom(a[a.index('--ff3') + 1] if '--ff3' in a else None)
    init = None                                  # --init ADDR=VAL,.. (save page offsets $000-$3FF)
    if '--init' in a:
        init = []
        for kv in a[a.index('--init') + 1].split(','):
            k, v = kv.split('=')
            if '*' in k:                         # ADDR*N=VAL: N bytes
                k, n = k.split('*')
            else: n = 1
            for j in range(int(n)): init.append((int(k, 16) + j, int(v, 16)))
    src = ('START_MAP = %s\nSTART_X = %s\nSTART_Y = %s\nSTART_ROOM = %s\n' % tuple(st) +
           'SND_MASK = $%02X\n' % int(os.environ.get('GBN_SND_MASK', 'FF'), 16) +
           'VOL_FORCE = %d\n' % {'0': 0, '1': 2, '2': 1, '3': 3}[os.environ.get('GBN_VOLMODE', '0')] +
           'TEST_INIT = %d\n' % (1 if init else 0) + 'FONT_D0 = $%02X\n' % text.code_of('0') + sound.mus_defs(rom) + sound.sfx_defs() +
           'STORY_FIRST = %d\nSTORY_END = %d\nSTORY_CRED = %d\n' % (ui.story_pages(rom)[1], len(ui.story_pages(rom)[0]), ui.CREDIT_PAGES) +
           'ENC_OW = %s\n' % (a[a.index('--enc') + 1] if '--enc' in a else '10') +
           'START_BATTLE = %s\n' % (a[a.index('--battle') + 1] if '--battle' in a else '$FF') +
           'START_DLG = %s\n' % (a[a.index('--dlg') + 1] if '--dlg' in a else '$FF') + talk_defs(rom) + item_defs(rom) + magic_defs(rom) +
           open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() +
           open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'objects.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'text.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'talk.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'screens.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'menu.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'shop.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'btl.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'btl2.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'btl3.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'btl4.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'btl5.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'btl6.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'loc.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'field2.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'sgb.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'mmp.s')).read() + '\n' + mmp_source() +
           open(os.path.join(HERE, 'src', 'cc.s')).read() + '\n' + cc_source() +
           open(os.path.join(HERE, 'src', 'air.s')).read() + '\n' + ap_source() +
           open(os.path.join(HERE, 'src', 'fx.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'refl.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'wanim.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'sgbx.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'extras.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'snd.s')).read() + '\nsection bank 7, $4400\n' + sound.engine_source() + '\n' +
           snd_tables(rom) +
           'section bank 104, $4000\n' +              # (the small font's glyphs: bank BTL6)
           battle.vwf_source() + ui.status_words() + ui_strings() + ui.loc_source() +
           domains_source(rom))
    import re                                    # (constants from every module first: the
    defs = [l for l in src.split('\n') if re.match(r'^[A-Za-z_]\w*\s+=', l)]   #   assembler
    rest = [l for l in src.split('\n') if not re.match(r'^[A-Za-z_]\w*\s+=', l)] #   needs them
    src = '\n'.join(defs + rest)                                                  #   defined first)
    r = asm(src)
    for lbl in ('qbuf', 'oam_buf', 'objs', 'game_flags', 'font_tbl', 'win_buf'):
        assert r.labels[lbl] % 0x100 == 0, '%s at %04X not aligned' % (lbl, r.labels[lbl])
    banks = dict(r.banks)
    for b, blob in data_banks(rom, ff3, init).items():
        assert b not in banks, 'bank %d used by code and data' % b
        banks[b] = blob
    img = make_rom(banks, 'FF1 NATIVE', cart_type=0x1B, rom_banks=ROM_BANKS, ram_size_code=0x03,
                   sgb=True, cgb=0x80)
    open(out, 'wb').write(img)
    open(out[:-3] + '.sym', 'w').write(r.sym_file())
    open(out[:-3] + '.lab', 'w').write(''.join('%04x %s\n' % (a, n) for n, a in sorted(r.labels.items(), key=lambda x: x[1])
                                               if isinstance(a, int) and 0xC000 <= a < 0x10000))
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


if __name__ == '__main__':
    main()
