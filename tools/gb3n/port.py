"""Build the FF3 Game Boy Color ROM: the native port (docs/ff3-gb-rewrite.md). The engine is FF1's
native engine (tools/gbn) carried over in tools/gb3n/eng, with FF3's game logic written natively from
what the everything8215/ff3 listing says FF3 does. Every game byte is read from the user's ROM here,
at build time, and converted so the engine only copies (GB tiles, RGB555 colours, maps unpacked).

usage: python3 tools/gb3n/port.py [--nes build/ff3_en.nes] [--out build/ff3p.gbc] [--start MAP,WORLD,X,Y]

Bank layout (eng/field.s has the RAM side):
  1  COMMON   $4000 NES colour -> RGB555 (64 x 2), $4080 the player poses (3E/DC2A, 64), $40C0 the pose
              offsets by facing (3E/DC1A, 9), $4100 trigger tiles' base tiles (3A/93C1, 128), $4180
              trigger type per tile $60-$7F (3A/921F, 32), $41A0 first tile per tile $60-$7F (3A/923F,
              32), $41C0 bit masks (3A/925F, 8), $4200 init tables (3A/8E76: npc switches 00/B600 (64),
              job base stats 39/A000 (8), initial MP 39/BB88 (16), HP 39/BBD8 (2), stats 39/BBDA (20),
              equipment 39/BBF0 (16)), $4400 the sprite palettes per map character id and world half
              (2 x 64 x 32 bytes RGB555, $3A $9050 / $9091), $5800 the menu window / text tiles
              (0D/B700, 144 GB tiles)
  2  CHARS    the map character graphics (0E/8000: 64 sets of 16 GB tiles)
  3  TSETS    the 8 normal-map tilesets, 1 KB each (UL, UR, DL, DR corner tiles, palette, property
              bytes 1 and 2, as FF3 keeps them: data.tileset_block)
  8-13 MAPREC  a record of 128 bytes per (map, world class): world 0, world 1, worlds 2-4 (768)
  16-  TMAPS   the tilemaps unpacked (1 KB each, 16 a bank), then the graphics subsets (112 GB tiles
              each, 9 a bank)
Map record: 0 tilemap bank, 1-2 its address, 3 graphics bank, 4 its address (high), 5 tileset,
  16-31 FF3's map properties (02/A000 + 16 p), 32-63 BG palettes 0-3 (RGB555), 64-79 entrances
  (10/8000 + byte 12/13), 80-95 treasures, 96-111 triggers."""
import os, sys, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'gb'))
sys.path.insert(0, HERE)
from asm_sm83 import asm, make_rom
import data
import importlib.util


def _load(name):
    sp = importlib.util.spec_from_file_location('gb3n_' + name, os.path.join(HERE, name + '.py'))
    m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
    return m


tiles = _load('tiles')
text = _load('text')

COMMON, CHARS, TSETS, SCRIPT, NPCGFX, MAPREC0, TMAP0 = 100, 101, 102, 103, 104, 108, 114
SNDT = 99                                        # the sound's period -> frequency table
WROWS, WTSET, WGFX = 160, 176, 177              # the world maps (world.s)
ROM_BANKS = 256
ob = _load('build')                              # the kept battle / sound modules' builder
KEPT = ['batlib.s', 'batcore.s', 'batmagic.s', 'batinit.s', 'batequip.s', 'batflow.s', 'batvict.s',
        'batloop.s', 'batsetup.s', 'batscr.s', 'batui.s', 'banim.s', 'bsumn.s', 'batfx.s', 'batbk.s', 'sound.s',
        'menu.s', 'mini.s', 'cut.s', 'cutend.s']
BANK0_MOVE = {'batlib.s': ('$0450', '$1D00'), 'sound.s': ('$1000', '$2200')}
B8 = data.B8


def gbt(nes):
    """NES planar tiles (8 low bytes, 8 high) -> Game Boy (low, high per row)"""
    return bytes(nes[16 * i + y + 8 * k] for i in range(len(nes) // 16) for y in range(8) for k in (0, 1))


def rgb2(c):
    return data.rgb555(c).to_bytes(2, 'little')


def blank():
    return bytearray(b'\xff' * 0x4000)


def tbl16(rom, lo_bank, addr, idx):
    """FF3's 16-byte map tables (entrances / treasures / triggers): a pointer table of 256 at
    addr (10/8000, /8100: index & $80 picks the second), pointer | $2000 in the bank pair 10/11"""
    a = addr + (0x100 if idx & 0x80 else 0) + 2 * (idx & 0x7F)
    lo, hi = rom.rd(0x10, a, 2)
    p = (hi << 8 | lo) | 0x2000                     # ($3A $936F: ORA #$20: bank 10 at $A000)
    return rom.rd(0x10, p, 16)


def data_banks(rom):
    banks = {}
    c = blank()
    c[0x0000:0x0080] = b''.join(rgb2(k) for k in range(64))
    c[0x0080:0x00C0] = rom.player_poses()
    c[0x00C0:0x00C9] = rom.rd(0x3E, 0xDC1A, 9)
    c[0x0100:0x0180] = rom.rd(0x3A, 0x93C1, 128)
    c[0x0180:0x01A0] = rom.rd(0x3A, 0x921F, 32)
    c[0x01A0:0x01C0] = rom.rd(0x3A, 0x923F, 32)
    c[0x01C0:0x01C8] = rom.rd(0x3A, 0x925F, 8)
    c[0x0200:0x0240] = rom.rd(0x00, 0xB600, 64)       # ($3A $8EB7: bank 1 = 00 at $A000: 00/B600)
    c[0x0240:0x0248] = rom.rd(0x39, 0xA000, 8)
    c[0x0248:0x0258] = rom.rd(0x39, 0xBB88, 16)
    c[0x0258:0x025A] = rom.rd(0x39, 0xBBD8, 2)
    c[0x0260:0x0274] = rom.rd(0x39, 0xBBDA, 20)
    c[0x0280:0x0290] = rom.rd(0x39, 0xBBF0, 16)
    for half in range(2):                             # sprite palettes: 4 NES palettes, 0 / 1 with
        for pid in range(64):                         #   the character's colours 2-3 ($3A $9050)
            base = list(rom.rd(0x00, 0x9670 + 16 * half, 16))
            cc = rom.rd(0x00, 0x9690 + 4 * pid, 4) if 0x9690 + 4 * pid < 0x9700 else bytes(4)
            base[2], base[3], base[6], base[7] = cc[0], cc[1], cc[2], cc[3]
            o = 0x0400 + 0x800 * half + 32 * pid
            c[o:o + 32] = b''.join(rgb2(v) for v in base)
    c[0x0300:0x0308] = b''.join(rgb2(v) for v in data.window_colours(rom))
    c[0x1400:0x1500] = rom.rd(0x3B, 0xB41A, 256)        # npc animation data (3B/B41A)
    c[0x1500:0x1600] = rom.rd(0x3F, 0xFE00, 256)        # the random number table (3F/FE00)
    c[0x1600:0x1700] = tiles.ff3_to_ascii()
    c[0x1700:0x1900] = rom.rd(0x00, 0x9400, 512)        # npc id -> graphics id (00/9400, 9500)
    c[0x1900:0x1B00] = rom.rd(0x01, 0xBE00, 512)        # npc speeds (01/BE00, BF00)
    c[0x1B00:0x1D00] = rom.rd(0x2C, 0x8000, 512)        # npc list pointers (2C/8000)
    c[0x1D00:0x1F00] = rom.rd(0x01, 0x9C00, 512)        # chest contents (01/9C00, 9D00)
    c[0x3E00:0x4000] = rom.rd(0x10, 0x9E00, 512)        # item prices (10/9E00)
    c[0x3100:0x3300] = rom.rd(0x39, 0xBE00, 512)        # encounter rates by map (39/BE00, BF00)
    c[0x3300:0x3500] = rom.rd(0x2E, 0x92F0, 512)        # battle group by map (2E/92F0, 93F0)
    c[0x3500:0x3540] = rom.rd(0x3D, 0xBD78, 64)         # a group's battle by chance (3D/BD78)
    c[0x3600:0x3E00] = rom.rd(0x2E, 0x94F0, 0x800)      # battle groups (2E/94F0)
    menut = rom.rd(0x0D, 0xB700, 144 * 16)
    c[0x2000:0x2000 + 144 * 16] = gbt(menut)
    font = [bytes(t) for t in tiles.tileset(fg=3, bg=2)[:128]]   # the window font: ours, FF3's frame
    for k in range(9):                                   #   ($F7-$FF -> $10-$18) and icons
        font[0x10 + k] = gbt(menut[16 * (0xF7 - 0x70 + k):16 * (0xF7 - 0x70 + k) + 16])
    raw = rom.at(0x0D * B8 + 0x1000, 0x1000)
    for k, code in enumerate(text.ICON_CODES):
        font[code] = gbt(raw[16 * (0x60 + k):16 * (0x60 + k) + 16])
    c[0x2900:0x3100] = b''.join(font)
    banks[COMMON] = c
    banks[CHARS] = bytearray(gbt(rom.at(0x0E * B8, 0x4000)))
    t = blank()
    for ts in range(8):
        t[0x400 * ts:0x400 * ts + 0x400] = data.tileset_block(rom, ts)
    banks[TSETS] = t
    banks[SCRIPT] = bytearray(rom.at(0x2C * B8, 0x4000))  # event / trigger / npc scripts (2C / 2D)
    for k in range(4):                                   # npc graphics by graphics id (3E/DF41)
        banks[NPCGFX + k] = bytearray(b''.join(gbt(data.npc_gfx_block(rom, g)) for g in range(64 * k, 64 * k + 64)))
    # tilemaps (unpacked) and graphics subsets, then the map records
    tm_at, bank, off = {}, TMAP0, 0
    tids = sorted(set(rom.rd(0x00, 0x8A00, 512)))
    for tid in tids:
        if off == 0x4000: bank, off = bank + 1, 0
        out = bytearray()
        lo, hi = rom.rd(0x11, 0x8000 + 2 * tid, 2)
        o = data.ptr(lo, hi, 0x11)
        while len(out) < 1024:                        # ($3E $CBFA: a byte < $80 a metatile, $80|v
            v = rom.at(o); o += 1                     #   then a run length, 0 = 256)
            if v & 0x80:
                n = rom.at(o) or 256; o += 1
                out += bytes([v & 0x7F]) * n
            else:
                out.append(v)
        banks.setdefault(bank, blank())[off:off + 1024] = out[:1024]
        tm_at[tid] = (bank, 0x4000 + off)
        off += 1024
    bank, off = bank + 1, 0
    sub_at = {}
    per = 0x4000 // (16 * data.SUBSET_TILES)
    for sub in range(max(rom.rd(0x00, 0x8C00, 512)) + 1):
        if off + 16 * data.SUBSET_TILES > 0x4000: bank, off = bank + 1, 0
        banks.setdefault(bank, blank())[off:off + 16 * data.SUBSET_TILES] = gbt(data.subset_tiles(rom, sub))
        sub_at[sub] = (bank, 0x4000 + off)
        off += 16 * data.SUBSET_TILES
    assert bank < 160
    for wi, w in enumerate(data.WORLD_MAPS):         # the world maps' rows (3E/CC47: unpacked here)
        rows = data.world_rows(rom, w)
        for k in range(4):
            banks[WROWS + 4 * wi + k] = bytearray(b''.join(rows[64 * k:64 * k + 64]))
    wt = blank()
    for w in range(5):
        wt[0x400 * w:0x400 * w + 0x400] = data.world_tileset(rom, w)
        wt[0x1400 + 32 * w:0x1420 + 32 * w] = b''.join(rgb2(c) for pal in data.world_palettes(rom, w) for c in pal)
    wt[0x1500:0x1540] = rom.rd(0x00, 0x8880, 64)         # exits (00/8880, 88C0)
    wt[0x1540:0x1580] = rom.rd(0x00, 0x88C0, 64)
    wt[0x1580:0x1600] = rom.rd(0x00, 0x8800, 128)        # entrances (00/8800, 8840)
    wt[0x1600:0x1640] = rom.rd(0x3B, 0xA027, 64)         # world songs / effects (3B/A027, A047)
    wt[0x1640:0x1648] = rom.rd(0x3E, 0xC6CD, 8)          # passability masks (3E/C6CD)
    wt[0x1700:0x1710] = rom.rd(0x2E, 0x9CF0, 16)         # world battles (2E/9CF0, 9D00, 9D40)
    wt[0x1710:0x1750] = rom.rd(0x2E, 0x9D00, 64)
    wt[0x1750:0x1760] = rom.rd(0x2E, 0x9D40, 16)
    banks[WTSET] = wt
    wg = blank()
    for k, w in enumerate((0, 2, 4)):
        wg[0x1000 * k:0x1000 * k + 0x1000] = gbt(data.world_tiles(rom, w))
    banks[WGFX] = wg
    for cls in range(3):                              # world 0; world 1; worlds 2-4
        for m in range(256):
            p = m + (256 if cls else 0)               # ($3A $9177: maps $100-$1FF off the floating continent)
            t = m + (256 if cls == 2 else 0)          # ($3E $CBAD / $DE63: worlds 2+ the second tables)
            props = rom.rd(0x02, 0xA000 + 16 * p, 16)
            tid = rom.rd(0x00, 0x8A00 + t)
            sub = rom.rd(0x00, 0x8C00 + t)
            rec = bytearray(128)
            rec[0] = tm_at[tid][0]; rec[1:3] = tm_at[tid][1].to_bytes(2, 'little')
            rec[3] = sub_at[sub][0]; rec[4] = sub_at[sub][1] >> 8; rec[5] = props[0] >> 5
            rec[16:32] = props
            mp = data.Map(rom, p, t)
            rec[32:64] = b''.join(rgb2(v) for pal in mp.bg_palettes() for v in pal)
            rec[64:80] = entrances(rom, props)
            rec[80:96] = tbl16(rom, 0x10, 0xA000, props[14])
            rec[96:112] = tbl16(rom, 0x10, 0xA200, props[15])
            i = cls * 256 + m
            b = MAPREC0 + i // 128
            banks.setdefault(b, blank())[128 * (i % 128):128 * (i % 128) + 128] = rec
    return banks


def entrances(rom, props):
    """the map's 16 entrance destinations: pointer in map properties bytes 12 / 13 | $2000, in the
    bank pair 10/11 ($3A $9356)"""
    p = (props[13] << 8 | props[12]) | 0x2000
    return rom.rd(0x10, p, 16)


def order_defs(defs):
    """the constants in an order where each is defined before it is used (files define them in any
    order)"""
    names = {}
    for l in defs:
        n = re.match(r'^([A-Za-z_]\w*)', l).group(1)
        if n in names:
            a, b = (x.split('=', 1)[1].split(';')[0].strip() for x in (names[n], l))
            assert a == b, '%s defined twice: %s / %s' % (n, a, b)
        names.setdefault(n, l)
    out, done = [], set()
    def emit(n, depth=0):
        if n in done or n not in names or depth > 50:
            return
        done.add(n)
        rhs = names[n].split('=', 1)[1].split(';')[0]
        for t in re.findall(r'[A-Za-z_]\w*', rhs):
            emit(t, depth + 1)
        out.append(names[n])
    for l in defs:
        emit(re.match(r'^([A-Za-z_]\w*)', l).group(1))
    return out


def pack0(src):
    """bank 0's sections (after the header) packed one after the other: measured first in banks of
    their own (the same code at $4000: the same sizes), then placed from $0150 in their order"""
    pat = re.compile(r'^section bank 0, \$([0-9A-Fa-f]{4})\s*(;.*)?$', re.M)
    secs = [m for m in pat.finditer(src) if int(m.group(1), 16) >= 0x150]
    trial, k = [], 0
    out = src
    for i, m in enumerate(reversed(secs)):
        n = len(secs) - 1 - i
        out = out[:m.start()] + 'section bank %d, $4000' % (300 + n) + out[m.end():]
    import asm_sm83
    keep = asm_sm83.AsmError
    r = asm(out)
    at = 0x150
    addr = []
    for n, m in enumerate(secs):
        a0 = int(m.group(1), 16)
        al = 0x100 if a0 & 0xFF == 0 and a0 >= 0x1000 else 1
        at = (at + al - 1) // al * al
        addr.append(at)
        at += len(r.banks.get(300 + n, b''))
    assert at <= 0x4000, 'bank 0 overflow: $%04X' % at
    for n, m in reversed(list(enumerate(secs))):
        src = src[:m.start()] + 'section bank 0, $%04X' % addr[n] + src[m.end():]
    print('bank 0: $%04X used' % at)
    return src


def main():
    a = sys.argv[1:]
    nes = a[a.index('--nes') + 1] if '--nes' in a else os.path.join(ROOT, 'build', 'ff3_en.nes')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'ff3p.gbc')
    st = (a[a.index('--start') + 1] if '--start' in a else 'new').split(',')
    rom = data.Rom(nes)
    dbanks = data_banks(rom)
    raw = open(nes, 'rb').read()
    tbanks, L, tlast = text.banks(ob.B_TEXT)        # (the text: the kept modules' layout)
    cutdata = _load('cutdata')                       # (the cutscenes' data: prophecy, prologue, ending)
    cut_raw, cut_gfx, cut_eq = cutdata.build(rom)
    if st == ['new']:                                # a new game: map 0, FF3's program start
        st = ['0', '0', '0', '0']; aa = 0
    elif st[0] == 'w':                               # (test builds: the world map, WORLD,X,Y)
        st = ['$FF'] + st[1:]; aa = 0
    else:
        aa = 0x81
    src = ('START_MAP = %s\nSTART_WORLD = %s\nSTART_X = %s\nSTART_Y = %s\n' % tuple(st) +
           'START_AA = $%02X\n' % aa +
           'COMMON = %d\nCHARS = %d\nTSETS = %d\nMAPREC0 = %d\n' % (COMMON, CHARS, TSETS, MAPREC0) +
           'SCRIPT = %d\nNPCGFX = %d\nTXT_IDX = %d\n' % (SCRIPT, NPCGFX, ob.B_TEXT) +
           'WROWS = %d\nWTSET = %d\nWGFX = %d\n' % (WROWS, WTSET, WGFX) +
           ''.join('%s = %d\n' % (k, v) for k, v in sorted(vars(ob).items()) if k.startswith('B_') and isinstance(v, int)) +
           ''.join('T_%s = $%04X\n' % (k.upper(), v) for k, v in L.items()) +
           'section bank 0, $2FB0\ntxt_tab:    dw $%04X, $%04X, $%04X, $%04X, $%04X\n' % (
               L['t8000'], L['t8200'], L['t8400'], L['t8600'], L['names8800']) +
           open(os.path.join(ROOT, 'tools', 'gb', 'rt', 'hw.s')).read())
    for f in ('event.s', 'npc.s', 'dlg.s', 'bridge.s', 'world.s', 'field.s'):
        src += '\n' + open(os.path.join(HERE, 'eng', f)).read()
    for f in KEPT:                               # FF3's battle rules / screen and sound driver (kept)
        t = open(os.path.join(HERE, 'src', f)).read()
        if f in BANK0_MOVE:
            a0, a1 = BANK0_MOVE[f]
            assert t.count('section bank 0, ' + a0) == 1
            t = t.replace('section bank 0, ' + a0, 'section bank 0, ' + a1)
        src += '\n' + t
    sd = ob.sound_data()                         # (the period table: out of bank 0)
    assert sd.count('section bank 0, $3000') == 1
    src += '\n' + cut_eq + '\n' + ob.menu_data() + '\n' + ob.own_data(raw) + '\n' + sd.replace('section bank 0, $3000', 'section bank %d, $4000' % SNDT)
    src = ob.expand(src)
    is_def = lambda l: re.match(r'^[A-Za-z_]\w*\s+=', l)
    lines = src.split('\n')
    src = '\n'.join(order_defs([l for l in lines if is_def(l)]) + [l for l in lines if not is_def(l)])
    import asm_sm83
    asm_sm83.RAM_SECTIONS[:] = []
    r = asm(pack0(src))
    secs = sorted(set((a, b) for a, b, _ in asm_sm83.RAM_SECTIONS if b > a))
    over = [(x, y) for x, y in zip(secs, secs[1:]) if x[1] > y[0]]
    for x, y in over:
        print('RAM sections overlap: %04X-%04X and %04X-%04X' % (x + y))
    for lbl in ('oam_buf', 'qbuf'):
        assert r.labels[lbl] % 0x100 == 0, '%s not aligned' % lbl
    banks = dict(r.banks)
    for b, blob in dbanks.items():
        assert b not in banks, 'bank %d used by code and data' % b
        banks[b] = blob
    ob.post_data(rom, r, banks, tbanks, cut_raw, cut_gfx)          # (the kept modules' data: battle, sound, text)
    img = make_rom(banks, 'FF3 GBC', cart_type=0x1B, rom_banks=ROM_BANKS, ram_size_code=ob.RAM_CODE,
                   sgb=False, cgb=0xC0)
    open(out, 'wb').write(img)
    open(out[:-4] + '.sym', 'w').write(r.sym_file())
    open(out[:-4] + '.lab', 'w').write(''.join('%04x %s\n' % (a, n) for n, a in sorted(r.labels.items(), key=lambda x: x[1])
                                               if isinstance(a, int) and 0xC000 <= a < 0x10000))
    print('wrote %s (%d KB), bank 0 used %d bytes' % (out, len(img) // 1024, len(r.banks[0])))


if __name__ == '__main__':
    main()
