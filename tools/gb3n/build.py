"""Build the native FF3 Game Boy Color ROM (tools/gb3n): the user's English NES ROM (made by the
FF3 pipeline: tools/gb3/build.py -> build/ff3_en.nes) is the only input for game data.

usage: build.py [EN.nes] [--map ID] [--group G] [--x X --y Y] [--out ROM]
  group 0-2: map sets (worlds 0, 1, 2+); 3 + w: world map w (then --x / --y: the party)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(ROOT, 'tools', 'gb'))
from data import Rom, nes2gb
from asm_sm83 import asm, make_rom
import build as gb1                     # tools/gb/build.py: NES_RGB (the 2C02 colours)


def rgb555(c):
    v = gb1.NES_RGB[c & 0x3F]
    r, g, b = v >> 16, (v >> 8) & 255, v & 255
    return (r >> 3) | (g >> 3) << 5 | (b >> 3) << 10


TS_BANK = 8                             # the 8 tilesets: $4000 + $700 ts (TL TR BL BR ATTR P1 P2)
MT_BANK = 9                             # map entries: 64 bytes, (group * 256 + id) -> bank 9 + group
LAY_BANK0 = 12                          # layouts: 16 a bank
CHR_BANK0 = LAY_BANK0 + 16              # BG tile sets (GB format): 4 a bank
SPR_BANK = CHR_BANK0 + 16               # walking characters: $4000 + $100 job; frames $7F00
WLD_BANK = SPR_BANK + 1                 # world maps: tilesets $4000 + $700 k (k = w >> 1), entries
                                        #   $7000 + 64 w, entrance destinations $7400 + 64 w
WCHR_BANK = WLD_BANK + 1                # world BG tiles: $4000 + $1000 k
NPCT_BANK = WCHR_BANK + 1               # npc tables: $4000 graphics ids (worlds 0-1), $4100 (2+),
                                        #   $4200 / $4300 speeds, $4400 frames, $4500 random
                                        #   table, $4600 new-game switches
NPCL_BANK = 64                          # npc lists: $4000 + 64 index (12 records + 0)
NPCG_BANK0 = 65                         # npc graphics (GB format): $4000 + $100 (g & 63), 2 banks
EVT_BANK = 67                           # FF3 banks 2C / 2D (npc / trigger / event scripts) as they are
GAME_BANK = 74                          # tables: $4000 / $4100 treasure contents (world 0 / others),
                                        #   $4200 item prices (2 bytes), $4400 item names (16 each)
TT_BANK = 75                            # per map: treasures + triggers (32 bytes), a bank a group
TXT_BANK = 68                           # dialogue (text.py): index + strings, banks 68-
WMAP_BANK0 = 48                         # world tilemaps (256 x 256): 4 banks each, 64 rows a bank
WMAPS = (0, 0, 1, 2, 3)                 # world -> tilemap (worlds 0 and 1 share one)


def group_world(g):
    return (0, 1, 2)[g]


def pack(rom):
    """all maps: {bank: bytes}"""
    banks = {}
    ts = bytearray(b'\xFF' * 0x4000)
    for t in range(8):
        d = rom.tileset(t)
        for k, key in enumerate(('tl', 'tr', 'bl', 'br', 'attr', 'p1', 'p2')):
            ts[0x700 * t + 0x100 * k:0x700 * t + 0x100 * k + 0x100] = d[key]
    banks[TS_BANK] = ts
    lay_ix, chr_ix = {}, {}
    ent = {g: bytearray(b'\x00' * 0x4000) for g in range(3)}
    for g in range(3):
        w = group_world(g)
        for mid in range(256):
            tid = rom.u8(0, (0x8B00 if w >= 2 else 0x8A00) + mid)
            sid = rom.u8(0, (0x8D00 if w >= 2 else 0x8C00) + mid)
            lk, ck = (w >= 2, tid), (w >= 2, sid)
            if lk not in lay_ix:
                n = len(lay_ix); lay_ix[lk] = n
                b = LAY_BANK0 + n // 16
                banks.setdefault(b, bytearray(b'\xFF' * 0x4000))
                banks[b][0x400 * (n % 16):0x400 * (n % 16) + 0x400] = rom.layout(mid, w)
            if ck not in chr_ix:
                n = len(chr_ix); chr_ix[ck] = n
                b = CHR_BANK0 + n // 4
                banks.setdefault(b, bytearray(b'\xFF' * 0x4000))
                c, _ = rom.bg_chr(mid, w)
                banks[b][0x1000 * (n % 4):0x1000 * (n % 4) + 0x1000] = b''.join(
                    nes2gb(c[16 * k:16 * k + 16]) for k in range(256))
            mp = rom.map_props(mid, w)
            li, ci = lay_ix[lk], chr_ix[ck]
            e = bytearray(64)
            e[0], e[1] = LAY_BANK0 + li // 16, 0x40 + 4 * (li % 16)     # layout: bank, page
            e[2], e[3] = CHR_BANK0 + ci // 4, 0x40 + 0x10 * (ci % 4)    # tiles: bank, page
            e[4] = mp[0] >> 5                                          # tileset
            e[5], e[6], e[7] = mp[0] & 0x1F, mp[1] & 0x1F, mp[3]       # start x, y, fill
            e[8], e[9] = mp[2], mp[10]                                 # title, song
            e[10] = mp[1]                                              # flags (gil, water)
            e[11] = mp[11]                                             # exit
            e[12] = TS_BANK                                            # tileset bank
            e[13] = mp[4]                                              # npc list
            e[48:64] = rom.b(0x10, ((mp[13] | 0x20) << 8) | mp[12], 16)  # entrances (dest maps)
            e[16:48] = rom.map_palettes(mid, w)                        # NES colours
            ent[g][64 * mid:64 * mid + 64] = e
    for g in range(3): banks[MT_BANK + g] = ent[g]
    sp = bytearray(b'\xFF' * 0x4000)
    for job in range(0x20):
        c = rom.char_chr(job)
        sp[0x100 * job:0x100 * job + 0x100] = b''.join(nes2gb(c[16 * k:16 * k + 16]) for k in range(16))
    sp[0x3F00:0x3F10] = rom.b(0x7E, 0xDC1A, 16)
    fr = rom.b(0x7E, 0xDC2A, 0x40)
    cv = lambda a: (a & 3) | 8 | ((a & 0x40) >> 1) | ((a & 0x80) >> 1) | ((a & 0x20) << 2)
    sp[0x3F10:0x3F50] = bytes(v if k % 2 == 0 else cv(v) for k, v in enumerate(fr))
    banks[SPR_BANK] = sp
    wb, wc = bytearray(b'\xFF' * 0x4000), bytearray(b'\xFF' * 0x4000)
    for k in range(3):
        d = rom.world_tileset(2 * k)
        for i, key in enumerate(('tl', 'tr', 'bl', 'br', 'attr', 'p1', 'p2')):
            wb[0x700 * k + 0x100 * i:0x700 * k + 0x100 * i + 0x100] = d[key]
        c = rom.world_chr(2 * k)
        wc[0x1000 * k:0x1000 * k + 0x1000] = b''.join(nes2gb(c[16 * i:16 * i + 16]) for i in range(256))
    for w in range(5):
        e = bytearray(64)
        e[0], e[2], e[3], e[4] = WMAP_BANK0 + 4 * WMAPS[w], WCHR_BANK, 0x40 + 0x10 * (w >> 1), w >> 1
        e[12] = WLD_BANK
        e[16:48] = rom.world_palettes(w)
        wb[0x3000 + 64 * w:0x3040 + 64 * w] = e
        wb[0x3400 + 64 * w:0x3440 + 64 * w] = rom.world_entrances(w)
    banks[WLD_BANK], banks[WCHR_BANK] = wb, wc
    t = rom.npc_tables()
    nt = bytearray(b'\xFF' * 0x4000)
    cv = lambda a: (a & 3) | 8 | ((a & 0x40) >> 1) | ((a & 0x80) >> 1) | ((a & 0x20) << 2)
    nt[0x0000:0x0100], nt[0x0100:0x0200] = t['g0'], t['g2']
    nt[0x0200:0x0300], nt[0x0300:0x0400] = t['s0'], t['s1']
    nt[0x0400:0x0500] = bytes(v if k % 2 == 0 else cv(v) for k, v in enumerate(t['anim']))
    nt[0x0500:0x0600], nt[0x0600:0x0640] = t['rng'], t['sw']
    banks[NPCT_BANK] = nt
    nl = bytearray(0x4000)
    for i in range(256):
        for k, r in enumerate(rom.npc_list(i)): nl[64 * i + 4 * k:64 * i + 4 * k + 4] = r
    banks[NPCL_BANK] = nl
    for b in range(2):
        banks[NPCG_BANK0 + b] = bytearray(b''.join(
            b''.join(nes2gb(c[16 * k:16 * k + 16]) for k in range(16))
            for c in (rom.npc_chr(64 * b + g) for g in range(64))))
    for k, w in enumerate((0, 2, 3, 4)):
        t = rom.world_tilemap(w)
        for i in range(4): banks[WMAP_BANK0 + 4 * k + i] = bytearray(t[0x4000 * i:0x4000 * i + 0x4000])
    return banks, len(lay_ix), len(chr_ix)


def trig_src(rom):
    """trigger tiles $60-$7F (3A L3A_91C8): type (3A/921F) and the metatile base (3A/923F)"""
    tt, to = rom.b(0x3A, 0x921F, 32), rom.b(0x3A, 0x923F, 32)
    return 'section bank 0, $3E80\nTRIG_T:\n    db %s\nTRIG_O:\n    db %s\n' % (
        ', '.join(str(v) for v in tt), ', '.join(str(v) for v in to))


def nes_rgb_src():
    """NES colour -> RGB555 (bank 0)"""
    v = [rgb555(c) for c in range(64)]
    return 'section bank 0, $3F00\nNES_RGB:\n' + ''.join(
        '    dw %s\n' % ', '.join(str(x) for x in v[k:k + 8]) for k in range(0, 64, 8))


def main():
    args = sys.argv[1:]
    opt = {'--map': '181', '--group': '0', '--x': '255', '--y': '255', '--dlg': '',
           '--out': os.path.join(ROOT, 'build', 'ff3n.gbc')}
    pos = []
    while args:
        a = args.pop(0)
        if a in opt: opt[a] = args.pop(0)
        else: pos.append(a)
    rom = Rom(pos[0] if pos else os.path.join(ROOT, 'build', 'ff3_en.nes'))
    banks, nl, nc = pack(rom)
    import text
    banks.update(text.pack(rom, TXT_BANK))
    banks[EVT_BANK] = bytearray(rom.b(0x2C, 0x8000, 0x4000))
    g = bytearray(0x4000)
    g[0x0000:0x0100], g[0x0100:0x0200] = rom.b(1, 0x9C00, 256), rom.b(1, 0x9D00, 256)
    g[0x0200:0x0400] = rom.b(0x10, 0x9E00, 512)
    for i in range(256):
        nm = text.item_name(rom, i)[:15]
        g[0x0400 + 16 * i:0x0400 + 16 * i + len(nm)] = nm
    banks[GAME_BANK] = g
    for grp in range(3):
        w = group_world(grp)
        tt = bytearray(0x4000)
        for mid in range(256):
            mp = rom.map_props(mid, w)
            tt[32 * mid:32 * mid + 16] = rom.map_treasures(mp[14])
            tt[32 * mid + 16:32 * mid + 32] = rom.map_triggers(mp[15])
        banks[TT_BANK + grp] = tt
    src = open(os.path.join(ROOT, 'tools', 'gb3', 'rt', 'hw.s')).read() + '\n' + \
        open(os.path.join(HERE, 'src', 'main.s')).read() + '\n' + \
        open(os.path.join(HERE, 'src', 'npc.s')).read() + '\n' + \
        open(os.path.join(HERE, 'src', 'text.s')).read() + '\n' + \
        open(os.path.join(HERE, 'src', 'event.s')).read() + '\n' + nes_rgb_src() + '\n' + trig_src(rom)
    r = asm(src, syms={'START_MAP': int(opt['--map'], 0), 'START_GRP': int(opt['--group'], 0),
                       'START_X': int(opt['--x'], 0), 'START_Y': int(opt['--y'], 0),
                       'TS_BANK': TS_BANK, 'MT_BANK': MT_BANK, 'SPR_BANK': SPR_BANK,
                       'WLD_BANK': WLD_BANK, 'NPCT_BANK': NPCT_BANK, 'NPCL_BANK': NPCL_BANK,
                       'NPCG_BANK0': NPCG_BANK0, 'TXT_BANK': TXT_BANK, 'EVT_BANK': EVT_BANK,
                       'GAME_BANK': GAME_BANK, 'TT_BANK': TT_BANK,
                       'DLG_TEST': int(opt['--dlg'].split(':')[1], 0) if opt['--dlg'] else 0,
                       'DLG_TEST_T': int(opt['--dlg'].split(':')[0], 0) if opt['--dlg'] else 0})
    for b, d in banks.items(): r.banks[b] = bytearray(d)
    size = 2
    while size < max(r.banks) + 1: size *= 2
    rom_bytes = make_rom(r.banks, 'FF3 NATIVE', cart_type=0x1B, rom_banks=size, ram_size_code=0x02, cgb=0xC0)
    open(opt['--out'], 'wb').write(rom_bytes)
    open(os.path.splitext(opt['--out'])[0] + '.sym', 'w').write(r.sym_file() + ''.join('ff:%04x %s\n' % (a, n) for n, a in sorted(r.labels.items()) if n not in r.label_bank and isinstance(a, int)))
    print('wrote %s: %d KB, %d layouts, %d tile sets; start map %s group %s'
          % (opt['--out'], len(rom_bytes) // 1024, nl, nc, opt['--map'], opt['--group']))


if __name__ == '__main__':
    main()
