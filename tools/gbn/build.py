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
import data, text, talkconst, ui, names

COMMON, TS_BANK0, MAP_BANK0, OW_TS, OW_INFO, OW_ROWS, ROM_BANKS = 1, 8, 20, 16, 81, 84, 128


def place(banks, bank, addr, blob):
    b = banks.setdefault(bank, bytearray(b'\xff' * 0x4000))
    o = addr - 0x4000
    assert o + len(blob) <= 0x4000, 'bank %d overflow at %04X' % (bank, addr)
    b[o:o + len(blob)] = blob


DIS = os.path.join(ROOT, 'build', 'ref', 'FF1Disassembly', 'Final Fantasy Disassembly')


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


def ui_strings():
    """the screens' strings as str_<name> labels in code bank 2"""
    out = ['section bank 2, $7000']
    for n, b in sorted(ui.strings().items()):
        out.append(data.db('str_' + n, b + b'\0'))
    return '\n'.join(out) + '\n'


def data_banks(rom, ff3=None):
    banks = {}
    data.FONT_CODES = text.field_codes()
    c = data.common_pack(rom)
    place(banks, COMMON, 0x4000, c['spr_tiles'])
    place(banks, COMMON, 0x4100, c['mapman'])
    place(banks, COMMON, 0x4200, c['tele'])
    place(banks, COMMON, 0x4400, c['objtbl'])                 # object 2x2 tables (64)
    place(banks, COMMON, 0x4500, c['init_unsram'])            # new game: save page 0
    place(banks, COMMON, 0x4600, c['init_flags'])             #   and the game flags
    place(banks, COMMON, 0x4700, text.win_palette())
    fd, fc = text.font_banks(rom, ff3)
    place(banks, COMMON, 0x4800, fd)
    place(banks, COMMON, 0x5000, fc)
    place(banks, COMMON, 0x5800, rom.rd(14, talkconst.TALK_DATA, 4 * talkconst.N_OBJ))  # talk data
    kind, _ = talkconst.extract(rom, DIS)
    place(banks, COMMON, 0x5C00, kind)                         # talk routine kind per object id
    place(banks, COMMON, 0x5D00, weapon_slots(rom))           # weapon slots (16), armour (16)
    nb = names.names_bank(rom)
    nb[0x3000:0x3200] = rom.rd(0x0D, 0xBC00, 0x200)            # item prices (FF1 lut_ItemPrices)
    nb[0x3200:0x3300] = rom.rd(0x00, 0xB100, 0x100)            # chest contents (lut_Treasure)
    banks[names.NAMES_BANK] = nb
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
    place(banks, OW_INFO, 0x5060, bytes([8]))
    place(banks, OW_INFO, 0x7200, o['party_dmg'])
    place(banks, OW_INFO, 0x7300, b'\0' * 64)                  # no objects
    place(banks, OW_INFO, 0x5100, o['mt_dmg'] + o['mt_dmg'])
    place(banks, OW_INFO, 0x5800, o['dmg_tiles'])
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


def main():
    a = sys.argv[1:]
    nes = a[a.index('--nes') + 1] if '--nes' in a else os.path.join(ROOT, 'build', 'ff1_gb.nes')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff1n.gb')
    st = a[a.index('--start') + 1].split(',') if '--start' in a else ['$FE', '0', '0']
    st = (list(st) + ['0'])[:4]                  # MAP,X,Y[,ROOM]
    rom = data.Rom(nes)
    ff3 = names.ff3_rom(a[a.index('--ff3') + 1] if '--ff3' in a else None)
    src = ('START_MAP = %s\nSTART_X = %s\nSTART_Y = %s\nSTART_ROOM = %s\n' % tuple(st) + talk_defs(rom) +
           open(os.path.join(HERE, '..', 'gb', 'rt', 'hw.s')).read() +
           open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'objects.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'text.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'talk.s')).read() + '\n' +
           open(os.path.join(HERE, 'src', 'screens.s')).read() + '\n' + ui_strings())
    import re                                    # (constants from every module first: the
    defs = [l for l in src.split('\n') if re.match(r'^[A-Za-z_]\w*\s+=', l)]   #   assembler
    rest = [l for l in src.split('\n') if not re.match(r'^[A-Za-z_]\w*\s+=', l)] #   needs them
    src = '\n'.join(defs + rest)                                                  #   defined first)
    r = asm(src)
    for lbl in ('qbuf', 'oam_buf', 'objs', 'game_flags', 'font_tbl', 'win_buf'):
        assert r.labels[lbl] % 0x100 == 0, '%s at %04X not aligned' % (lbl, r.labels[lbl])
    banks = dict(r.banks)
    for b, blob in data_banks(rom, ff3).items():
        assert b not in banks, 'bank %d used by code and data' % b
        banks[b] = blob
    img = make_rom(banks, 'FF1 NATIVE', cart_type=0x1B, rom_banks=ROM_BANKS, ram_size_code=0x03,
                   sgb=True, cgb=0x80)
    open(out, 'wb').write(img)
    open(out[:-3] + '.sym', 'w').write(r.sym_file())
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


if __name__ == '__main__':
    main()
