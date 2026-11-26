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
import asm_sm83
asm_sm83.PROTECT_RAM[:] = [(0xD000, 0xD3FF)]          # FF1's save page (main.s unsram): only its own section
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
    assert ui.PG_BANK not in banks                             # (code: src/pgen.s)
    import spelldesc                                           # (the magic shops' descriptions)
    assert spelldesc.SDESC_BANK not in banks
    banks[spelldesc.SDESC_BANK] = bytearray(spelldesc.bank())
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
    wa, wad, wa_info = water_anim(o)                            # (the animated sea and rivers)
    place(banks, WANIM_BANK, 0x4000, wa)
    place(banks, WANIM_DMG, 0x4000, wad)
    print('water animation:', wa_info)
    place(banks, WTOWN_BANK, 0x4000, town_water(rom))           # (the towns' water tile)
    wt2_blob, wt2_src = town_water2(rom)                         # (its canal in shadow)
    place(banks, WT2_BANK, 0x4000, wt2_blob)
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


WANIM_BANK = 106                                 # (src/wanim.s; the DMG's frames in WANIM_DMG)
WANIM_DMG = 108
WTOWN_BANK = 109
TOWN_WATER = 0x0F                                # (tileset 0's water tile: metatiles 39-41, 59)


def town_water(rom):
    """the towns' water (owner, 2026-11-25): tileset 0's one water tile, moving as the sea
    (src/wanim.s wt_cp): two bands of 4 lines, each a pixel sideways per 16 frames, the bands
    8 frames apart; 64 steps (one per 4 frames). $4400 per entry (towns = maps 0-7, 8 = the
    Color) the tile's VRAM address, $4800 + $400 entry its 64 pictures (the DMG's pre-shaded).
    """
    def shifts(t16):
        px = [[(t16[2 * y] >> (7 - x) & 1) | (t16[2 * y + 1] >> (7 - x) & 1) << 1 for x in range(8)]
              for y in range(8)]
        out = bytearray()
        for j in range(64):
            for y in range(8):
                sh = ((j + 3 - 2 * (y // 4)) // 4) % 8
                row = [px[y][(x - sh) % 8] for x in range(8)]
                out += bytes([sum((v & 1) << (7 - x) for x, v in enumerate(row)),
                              sum((v >> 1) << (7 - x) for x, v in enumerate(row))])
        return bytes(out)
    def vram(d): return (0x9000 + 16 * d) if d < 128 else (0x8000 + 16 * d)
    t = data.tileset_pack(rom, 0)
    blob = bytearray(0x3000)
    # the world map's waterfall (owner's audit, 2026-11-25, W2): the one metatile whose two tiles
    # (left / right column, each repeated top and bottom) only it uses, falling a pixel each water
    # step (8 steps): $6C00 the tiles' VRAM (Color, Color, DMG, DMG), $6C10 the Color's 8 x 2
    # pictures, $6D10 the DMG's (src/wanim.s wf_tick)
    o = data.ow_pack(rom)
    wf = [mt for mt in range(128) if o['prop'][2 * mt] & 5 == 5 and o['tsa'][mt] == o['tsa'][256 + mt]
          and o['tsa'][128 + mt] == o['tsa'][384 + mt] and o['tsa'][mt] != o['tsa'][128 + mt]
          and all(o['tsa'][128 * k + m2] not in (o['tsa'][mt], o['tsa'][128 + mt])
                  for k in range(4) for m2 in range(128) if m2 != mt)]
    assert len(wf) == 1, 'waterfall: %r' % wf
    mt = wf[0]
    def fall(t16):
        out = bytearray()
        for st in range(8):
            for y in range(8):
                yy = (y - st) % 8
                out += t16[2 * yy:2 * yy + 2]
        return out
    cid = [o['tsa'][mt], o['tsa'][128 + mt]]
    did = [o['mt_dmg'][mt], o['mt_dmg'][128 + mt]]
    hdr = b''.join(vram(x).to_bytes(2, 'little') for x in cid + did)
    blob[0x2C00:0x2C08] = hdr
    for k in range(2):
        fc = fall(o['cgb_tiles'][16 * cid[k]:16 * cid[k] + 16])
        fd = fall(o['dmg_tiles'][16 * did[k]:16 * did[k] + 16])
        for st in range(8):
            blob[0x2C10 + 32 * st + 16 * k:0x2C20 + 32 * st + 16 * k] = fc[16 * st:16 * st + 16]
            blob[0x2D10 + 32 * st + 16 * k:0x2D20 + 32 * st + 16 * k] = fd[16 * st:16 * st + 16]
    blob[0x410:0x412] = vram(TOWN_WATER).to_bytes(2, 'little')
    blob[0x2800:0x2C00] = shifts(t['cgb_tiles'][16 * TOWN_WATER:16 * TOWN_WATER + 16])
    for m in range(8):
        assert rom.rd(data.BANK_SMINFO, data.TILESETS + m) == 0
        p = data.map_pack(rom, m)
        d = p['mt_dmg_out'][39]
        assert all(p['mt_dmg_out'][128 * k + 39] == d for k in range(4))
        blob[0x400 + 2 * m:0x402 + 2 * m] = vram(d).to_bytes(2, 'little')
        blob[0x800 + 0x400 * m:0xC00 + 0x400 * m] = shifts(p['dmg_tiles'][16 * d:16 * d + 16])
    return bytes(blob)
WT2_BANK = 112
def town_water2(rom):
    """the towns' canal water in shadow (owner, 2026-11-25: "add water movement to the darkened tiles
    of the water"): tileset 0's shadowed water tile (metatiles 40 / 41, upper left) moves as the
    water does, and the corner where the shadow's edge meets open water (41, lower left) moves on
    both sides of its edge, the edge itself still (each row: up to its last shadow pixel the
    shadow's picture, after it the water's). Returns (bank WT2_BANK blob from $4000, the header's
    source: WT2_HDR, 8 bytes an entry (towns = maps 0-7 on the plain Game Boy, 8 = the Color):
    shadow tile VRAM, its pictures' high byte, 0, corner tile VRAM, its pictures' high byte, 0;
    VRAM 0: none). src/wanim.s wt_cp2."""
    def dec(t16): return [[(t16[2 * y] >> (7 - x) & 1) | (t16[2 * y + 1] >> (7 - x) & 1) << 1 for x in range(8)]
                          for y in range(8)]
    def enc(px):
        out = bytearray()
        for row in px:
            out += bytes([sum((v & 1) << (7 - x) for x, v in enumerate(row)),
                          sum((v >> 1) << (7 - x) for x, v in enumerate(row))])
        return bytes(out)
    def frames(t16):                                  # as town_water: two bands of 4 lines
        px = dec(t16)
        return [[[px[y][(x - ((j + 3 - 2 * (y // 4)) // 4) % 8) % 8] for x in range(8)] for y in range(8)]
                for j in range(64)]
    def vram(d): return (0x9000 + 16 * d) if d < 128 else (0x8000 + 16 * d)
    t = data.tileset_pack(rom, 0)
    tsa = t['tsa']
    sh_c, co_c = tsa[40], tsa[256 + 41]                # (UL of 40, DL of 41)
    assert tsa[41] == sh_c and tsa[128 + 40] == TOWN_WATER and tsa[256 + 40] == sh_c
    uses = lambda tid, tab: sorted((k, m) for k in range(4) for m in range(128) if tab[128 * k + m] == tid)
    assert uses(sh_c, tsa) == [(0, 40), (0, 41), (2, 40)] and uses(co_c, tsa) == [(2, 41)], 'shared tiles'
    cpx = dec(t['cgb_tiles'][16 * co_c:16 * co_c + 16])
    edge = [max([x for x in range(8) if cpx[y][x] == 3] or [-1]) for y in range(8)]
    def corner(fs, fw):
        return b''.join(enc([[fs[j][y][x] if x <= edge[y] else fw[j][y][x] for x in range(8)] for y in range(8)])
                        for j in range(64))
    blob = bytearray(); hdr = bytearray()
    def add(pics):
        nonlocal blob
        hi = 0x40 + len(blob) // 256
        blob += pics
        assert len(blob) <= 0x3F00
        return hi
    entries = {}
    tl = t['cgb_tiles']
    fs = frames(tl[16 * sh_c:16 * sh_c + 16]); fw = frames(tl[16 * TOWN_WATER:16 * TOWN_WATER + 16])
    entries[8] = (vram(sh_c), add(b''.join(enc(f) for f in fs)), vram(co_c), add(corner(fs, fw)))
    for m in range(8):
        p = data.map_pack(rom, m)
        md = p['mt_dmg_out']
        if md[40] == 0 or md[256 + 41] == 0 or md[39] == 0:
            entries[m] = (0, 0, 0, 0); continue
        ds, dc, dw = md[40], md[256 + 41], md[39]
        for tab in (p['mt_dmg_out'], p['mt_dmg_in']):
            assert sorted(set(uses(dc, tab))) == [(2, 41)], 'DMG corner shared on map %d' % m
        dt = p['dmg_tiles']
        fs = frames(dt[16 * ds:16 * ds + 16]); fw = frames(dt[16 * dw:16 * dw + 16])
        same = all(fs[j] == fs[0] for j in range(64))      # (a one-shade shadow: nothing moves)
        sv = (0, 0) if same else (vram(ds), add(b''.join(enc(f) for f in fs)))
        if not same:
            for tab in (p['mt_dmg_out'], p['mt_dmg_in']):
                assert sorted(set(uses(ds, tab))) == [(0, 40), (0, 41), (2, 40)], 'DMG shadow shared'
        entries[m] = sv + (vram(dc), add(corner(fs, fw)))
    for e in range(9):
        a, b, c, d = entries[e]
        hdr += bytes([a & 255, a >> 8, b, 0, c & 255, c >> 8, d, 0])
    src = 'section bank 99, $4A80\nWT2_HDR:\n' + '            db %s\n' % ', '.join('$%02X' % v for v in hdr)
    return bytes(blob), src


def refl_source(rom):
    """the reflection's water (owner, 2026-11-25: the reflection should slip into the shore):
    per overworld metatile one byte, a bit per 8 x 8 quarter drawn with open water (bit 0 UL,
    1 UR, 2 DL, 3 DR): a quarter whose tile is one of the open sea's or the river's tiles (the
    commonest sea and river metatiles of the map, as water_anim). Coasts drawn half in water
    count by their quarters, whatever their walking property says. src/refl.s refl_clip."""
    o = data.ow_pack(rom)
    prop, tsa = o['prop'], o['tsa']
    freq = {}
    for r_ in o['rows']:
        for v in r_: freq[v & 0x7F] = freq.get(v & 0x7F, 0) + 1
    def kind(mt):
        d = prop[2 * mt]
        if not d & 1 or (d & 6) == 6: return None
        return 'sea' if not d & 4 else 'river'
    water = set()
    for want in ('sea', 'river'):
        cand = [mt for mt in range(128) if kind(mt) == want]
        if cand:
            mt = max(cand, key=lambda m: freq.get(m, 0))
            water |= {tsa[128 * k + mt] for k in range(4)}
    tab = [sum(1 << k for k in range(4) if tsa[128 * k + mt] in water) for mt in range(128)]
    # per pixel (owner, 2026-11-25: the reflection on the coasts too, cut to their water): for
    # each metatile, quarter and pixel row a byte, bit 7 the left pixel, set where the pixel
    # shows a colour of the open sea's / river's pictures; only metatiles drawn next to water
    # somewhere on the map (a blue roof inland stays dry). REFL_MASK + 32 mt + 8 quarter + row
    tiles, pal, mt_pal = o['cgb_tiles'], o['cgb_bg'], o['mt_pal']
    def px(mt, k, y, x):
        t = tiles[16 * tsa[128 * k + mt]:16 * tsa[128 * k + mt] + 16]
        v = (t[2 * y] >> (7 - x) & 1) | (t[2 * y + 1] >> (7 - x) & 1) << 1
        c = 2 * (4 * mt_pal[mt] + v)
        return pal[c] | pal[c + 1] << 8
    wcol = {px(mt, k, y, x) for mt in range(128) if tab[mt] == 15
            for k in range(4) for y in range(8) for x in range(8)}
    wet = {mt for mt in range(128) if tab[mt] == 15}
    near = set(wet)
    rows = o['rows']
    for y in range(256):
        for x in range(256):
            if rows[y][x] & 0x7F in wet:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    near.add(rows[(y + dy) & 255][(x + dx) & 255] & 0x7F)
    mask = bytearray(4096)
    for mt in range(128):
        if mt not in near: continue
        for k in range(4):
            for y in range(8):
                mask[32 * mt + 8 * k + y] = sum(0x80 >> x for x in range(8) if px(mt, k, y, x) in wcol)
    # the plain Game Boy's own: its pre-shaded tiles (a coast's water edge can be shaded as
    # land there), the shades of the open water's pictures (REFL_MASK + $1000)
    dt, mtd = o['dmg_tiles'], o['mt_dmg']
    def pxd(mt, k, y, x):
        t = dt[16 * mtd[128 * k + mt]:16 * mtd[128 * k + mt] + 16]
        return (t[2 * y] >> (7 - x) & 1) | (t[2 * y + 1] >> (7 - x) & 1) << 1
    wsh = {pxd(mt, k, y, x) for mt in wet for k in range(4) for y in range(8) for x in range(8)}
    mask += bytes(4096)
    for mt in range(128):
        if mt not in near: continue
        for k in range(4):
            for y in range(8):
                mask[4096 + 32 * mt + 8 * k + y] = sum(0x80 >> x for x in range(8) if pxd(mt, k, y, x) in wsh)
    # the plain Game Boy's party on the overworld, every class pre-shaded as party_spr shades
    # it there (its tiles ranked by o['party_perm'], palette by the tile's bit 1): the
    # reflection's masked tiles read them as they are (REFL_PDMG + 256 class + 16 tile)
    perm = o['party_perm']; pdmg = bytearray()
    for c in range(12):
        for t in range(16):
            pb = perm[2 * c + (t >> 1 & 1)]
            raw = rom.rd(data.BANK_MAPCHR, data.MAPMAN_CHR + 0x100 * c + 16 * t, 16)
            pdmg += data.gb_tile(raw, (0, pb & 3, pb >> 2 & 3, pb >> 4 & 3))
    # each quarter whole: $FF all water, $00 none, $01 mixed (Color at REFL_UNI, DMG + $200)
    uni = bytearray()
    for base in (0, 4096):
        for mt in range(128):
            for k in range(4):
                rows8 = mask[base + 32 * mt + 8 * k:base + 32 * mt + 8 * k + 8]
                uni.append(0xFF if all(v == 0xFF for v in rows8) else 0 if not any(rows8) else 1)
    # the towns (tileset 0, maps 0-7; owner, 2026-11-25: "enable reflections in towns"): their water
    # is whole tiles (the water tile, the canal in shadow and its corner), so a quarter flag per
    # metatile ($FF water) is the mask (rows from RF_ROWSFF / RF_ROWS00); and per map the first 8
    # sprite tiles no object, font or map tile uses for the masked tiles (0: none, Onrac)
    tt = data.tileset_pack(rom, 0)
    ttsa = tt['tsa']
    twet = {TOWN_WATER, ttsa[40], ttsa[256 + 41]}
    twat = bytes(0xFF if ttsa[128 * k + mt] in twet else 0 for mt in range(128) for k in range(4))
    tbase = bytearray()
    for m in range(8):
        p = data.map_pack(rom, m)
        bl = set(p['objs']['blocks']); nb = p['n_dmg']; ft = set(p['font_tbl']) - {0}
        lo = [b for b in range(16, 128, 16) if b not in bl]
        hi = [b for b in range(128, 256, 8) if all(b + k >= nb and b + k not in ft and
              not any(b0 <= b + k < b0 + 16 for b0 in bl) for k in range(8))]
        tbase.append(lo[0] if lo else hi[0] if hi else 0)
    tbase += bytes([0x70, 0])                       # (8: the overworld; 9: no reflection)
    p0 = data.map_pack(rom, 0)
    c = 2 * (4 * tt['mt_pal'][39] + 2)
    twc = p0['cgb_bg_out'][c:c + 2]
    town = ('section bank 111, $4800\nRF_TWAT:\n' +
            ''.join('            db %s\n' % ', '.join('$%02X' % v for v in twat[i:i + 16]) for i in range(0, 512, 16)) +
            'RF_ROWSFF:  db ' + ', '.join(['$FF'] * 8) + '\nRF_ROWS00:  db ' + ', '.join(['0'] * 8) + '\n' +
            'section bank 99, $469A\nRF_TWC:     db $%02X, $%02X\nRF_TBT:     db %s\n' %
            (twc[0], twc[1], ', '.join('$%02X' % v for v in tbase)))
    return (town + 'section bank 111, $7000\nREFL_UNI:\n' +
            ''.join('            db %s\n' % ', '.join('$%02X' % v for v in uni[i:i + 16]) for i in range(0, len(uni), 16)) +
            'section bank 111, $7400\nREFL_PDMG:\n' +
            ''.join('            db %s\n' % ', '.join('$%02X' % v for v in pdmg[i:i + 16]) for i in range(0, len(pdmg), 16)) +
            'section bank 111, $5000\nREFL_MASK:\n' +
            ''.join('            db %s\n' % ', '.join('$%02X' % v for v in mask[i:i + 16]) for i in range(0, len(mask), 16)))


def water_anim(o):
    """the animated sea and rivers (owner's list, 2026-11-24; FF1 has none): the commonest open
    sea metatile and river metatile of the overworld. Motion as Final Fantasy Legend III's water
    (owner, 2026-11-24), made finer (owner: two more strips): the 16 x 16 picture in four bands
    of 4 lines (river: 4 columns), each moving a pixel per 16 frames (sea sideways, river
    downwards), the bands in turn 4 frames apart (order 0, 2, 1, 3): 64 steps, one per 4 frames;
    bands together where one tile fills every corner (the river). Only metatiles whose tiles
    stay right wherever they are used move: coasts and land never change.
    Returns (Color bank, DMG bank, info). Each bank: $4000 count, $4008 the sea's main colour
    (RGB555: the reflection's water), $4010 entries of 16 bytes (the bank's own 4 tiles),
    frames from $4100 + $1000 e: 64 steps x 4 tiles x 16 bytes (the Color's / the DMG's
    pre-shaded). The copies wa_run makes (src/wanim.s), per step: at $6200 + 16 step those of
    the tiles that change at it, at $6600 + 32 step every tile (a redraw); each list a count,
    then (VRAM address, frame address) words. A corner showing the same tile as an earlier
    corner (the river) is copied once: the plain Game Boy has V-Blank lines 148-150 for them."""
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
    ORDER = (0, 2, 1, 3)
    def frames(tiles16, vertical, stagger=True):
        q = [dec(t) for t in tiles16]                       # UL, UR, DL, DR
        img = [[q[(y >= 8) * 2 + (x >= 8)][y & 7][x & 7] for x in range(16)] for y in range(16)]
        out = []
        for j in range(64):
            sh_b = [((j + 3 - ORDER[b]) // 4 if stagger else j // 4) % 16 for b in range(4)]
            if vertical:
                sh = [[img[(y - sh_b[x // 4]) % 16][x] for x in range(16)] for y in range(16)]
            else:
                sh = [[img[y][(x - sh_b[y // 4]) % 16] for x in range(16)] for y in range(16)]
            out.append([enc([[sh[qy * 8 + y][qx * 8 + x] for x in range(8)] for y in range(8)])
                        for qy in range(2) for qx in range(2)])
        return out
    pos_c, pos_d = {}, {}                               # tile -> the corners it is used at
    for k in range(4):
        for mt in range(128):
            pos_c.setdefault(tsa[128 * k + mt], set()).add(k)
            pos_d.setdefault(tbl[128 * k + mt], set()).add(k)
    def same(ids, pos_of, fr):
        # every use of a tile, by any metatile at any corner, must get the same picture in
        # every step: the same corner as here, or a corner whose shifted quarter is equal
        for k, t in enumerate(ids):
            for k2 in pos_of[t]:
                if k2 != k and any(f[k2] != f[k] for f in fr): return False
        return True
    ents, dc, dd, water = [], bytearray(), bytearray(), 0x7E40
    slots = {False: [], True: []}                       # (per bank: entry, corner, tile; changes)
    for want, vert in (('sea', False), ('river', True)):
        cand = sorted((m for m in range(128) if kind(m) == want), key=lambda m: -freq.get(m, 0))
        for mt in cand[:1]:
            cid = [tsa[128 * k + mt] for k in range(4)]
            did = [tbl[128 * k + mt] for k in range(4)]
            for stag in (True, False):
                fc = frames([o['cgb_tiles'][16 * t:16 * t + 16] for t in cid], vert, stag)
                fd = frames([o['dmg_tiles'][16 * t:16 * t + 16] for t in did], vert, stag)
                if same(cid, pos_c, fc) and same(did, pos_d, fd): break
            else:
                continue
            e = len(ents)
            for dmg, ids, fr in ((False, cid, fc), (True, did, fd)):
                for qq in range(4):                     # a corner showing a tile an earlier
                    if ids[qq] in ids[:qq]:             #   corner copies is never copied again
                        assert all(f[qq] == f[ids.index(ids[qq])] for f in fr)
                        continue
                    slots[dmg].append((e, qq, ids[qq],
                                       {j for j in range(64) if fr[j][qq] != fr[j - 1][qq]}))
            dc += b''.join(b''.join(f) for f in fc)
            dd += b''.join(b''.join(f) for f in fd)
            ents.append(bytes(cid) + bytes(did) + bytes(8))
            if want == 'sea':                           # its main colour: the reflection's water
                cnt = [0] * 4
                for t in cid:
                    for row in dec(o['cgb_tiles'][16 * t:16 * t + 16]):
                        for v in row: cnt[v] += 1
                k_ = cnt.index(max(cnt)); p_ = o['mt_pal'][mt]
                water = int.from_bytes(o['cgb_bg'][8 * p_ + 2 * k_:8 * p_ + 2 * k_ + 2], 'little')
    def head(dmg):                                      # (each bank's entries: its own tiles)
        h = bytearray(0x100)
        h[0] = len(ents)
        h[8:10] = water.to_bytes(2, 'little')
        for i_, e_ in enumerate(ents): h[0x10 + 16 * i_:0x14 + 16 * i_] = e_[4:8] if dmg else e_[0:4]
        return bytes(h)
    def lists(dmg):                                     # ($6200: the changes, $6600: redraws)
        out = bytearray(0xC00)
        def put(at, sl, j):
            out[at] = len(sl)
            for i_, (e_, q_, t_, _) in enumerate(sl):
                va = (0x9000 + 16 * t_) if t_ < 128 else (0x8000 + 16 * t_)
                src = 0x4100 + 0x1000 * e_ + 64 * j + 16 * q_
                out[at + 1 + 4 * i_:at + 5 + 4 * i_] = va.to_bytes(2, 'little') + src.to_bytes(2, 'little')
        for j in range(64):
            ch = [x for x in slots[dmg] if j in x[3]]
            assert len(ch) <= 3 and len(slots[dmg]) <= 7
            put(16 * j, ch, j)
            put(0x400 + 32 * j, slots[dmg], j)
        return bytes(out)
    assert len(dc) <= 0x2100
    def bank(dmg, d_):
        return head(dmg) + bytes(d_) + bytes(0x2100 - len(d_)) + lists(dmg)
    return bank(False, dc), bank(True, dd), [(e_[0:4].hex(), e_[4:8].hex()) for e_ in ents]


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
           'START_DLG = %s\n' % (a[a.index('--dlg') + 1] if '--dlg' in a else '$FF') +
           'START_SHOP = %s\n' % (a[a.index('--shop') + 1] if '--shop' in a else '$FF') + talk_defs(rom) + item_defs(rom) + magic_defs(rom) +
           open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() +
           open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'objects.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'text.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'talk.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'screens.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'menu.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'shop.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'ul.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'pal.s')).read() + '\n' + refl_source(rom) + '\n' + town_water2(rom)[1] + '\n' +
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
           open(os.path.join(HERE, 'src', 'pgen.s')).read() + '\n' + ui.pg_source() +
           open(os.path.join(HERE, 'src', 'snd.s')).read() + '\nsection bank 7, $4400\n' + sound.engine_source() + '\n' +
           snd_tables(rom) +
           'section bank 104, $6000\n' +              # (the small font's glyphs: bank BTL6)
           battle.vwf_source() + ui.status_words() + ui_strings() + ui.loc_source() +
           domains_source(rom))
    import re                                    # (constants from every module first: the
    defs = [l for l in src.split('\n') if re.match(r'^[A-Za-z_]\w*\s+=', l)]   #   assembler
    rest = [l for l in src.split('\n') if not re.match(r'^[A-Za-z_]\w*\s+=', l)] #   needs them
    src = '\n'.join(defs + rest)                                                  #   defined first)
    r = asm(src)
    if os.environ.get('GBN_GAPS'):              # free runs (16+ bytes) of a code bank: GBN_GAPS=6
        gb = int(os.environ['GBN_GAPS']); run = []
        for off in range(0x4000 + 1):
            if off < 0x4000 and not r.claimed.get((gb, off)): run.append(off)
            else:
                if len(run) >= int(os.environ.get('GBN_GAPMIN', 16)): print('bank %d free: $%04X-$%04X (%d)' % (gb, run[0] + (0x4000 if gb else 0), run[-1] + (0x4000 if gb else 0), len(run)))
                run = []
    for lbl in ('qbuf', 'oam_buf', 'objs', 'game_flags', 'font_tbl', 'win_buf'):
        assert r.labels[lbl] % 0x100 == 0, '%s at %04X not aligned' % (lbl, r.labels[lbl])
    banks = dict(r.banks)
    for b, blob in data_banks(rom, ff3, init).items():
        assert b not in banks, 'bank %d used by code and data' % b
        banks[b] = blob
    import spelldesc                             # (the magic shops' descriptions: no other data there)
    assert bytes(banks[spelldesc.SDESC_BANK][:128]) == spelldesc.bank()[:128], 'spell descriptions overwritten'
    img = make_rom(banks, 'FF1 NATIVE', cart_type=0x1B, rom_banks=ROM_BANKS, ram_size_code=0x03,
                   sgb=True, cgb=0x80)
    open(out, 'wb').write(img)
    open(out[:-3] + '.sym', 'w').write(r.sym_file())
    open(out[:-3] + '.lab', 'w').write(''.join('%04x %s\n' % (a, n) for n, a in sorted(r.labels.items(), key=lambda x: x[1])
                                               if isinstance(a, int) and 0xC000 <= a < 0x10000))
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


if __name__ == '__main__':
    main()
