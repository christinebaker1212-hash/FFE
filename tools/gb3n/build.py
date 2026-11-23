"""Build the native FF3 Game Boy Color ROM (tools/gb3n): the user's English NES ROM (made by the
FF3 pipeline: tools/gb3/build.py -> build/ff3_en.nes) is the only input for game data.

usage: build.py [EN.nes] [--map ID] [--group G] [--x X --y Y] [--out ROM]
  group 0-2: map sets (worlds 0, 1, 2+); 3 + w: world map w (then --x / --y: the party)"""
import os, sys, re
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
                                        #   $4200 item prices (2 bytes), $4400 item names (16 each),
                                        #   $5400 the new-game save block (1 KB)
TT_BANK = 75                            # per map: treasures + triggers (32 bytes), a bank a group
JOB_BANK = 79                           # FF3 bank $39 at $4000 (job stats, level tables, MP growth),
                                        #   $6000 the level-table pointers (3D/AD59) as GB addresses
MENU_BANK = 78                          # field menus (menu.py)
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


def snd_tab():
    """NES pulse / triangle period t -> GB 11-bit frequency (2 bytes, little endian): the same
    pitch (pulse: 1789773 / 16 (t + 1) = 131072 / (2048 - x); triangle: / 32 and 65536: the same x)"""
    out = bytearray()
    for t in range(2048):
        x = round(2048 - 131072 * 16 * (t + 1) / 1789773)
        x = max(0, min(2047, x))
        out += bytes([x & 0xFF, x >> 8])
    return bytes(out)


def snd_noise():
    """NES noise period index (0-15, +16 short mode) -> the GB NR43 nearest in frequency"""
    per = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
    import math
    cands = []
    for sft in range(14):
        for r in range(8):
            f = 524288 / (0.5 if r == 0 else r) / (2 ** (sft + 1))
            cands.append((f, (sft << 4) | r))
    out = bytearray(32)
    for k, p in enumerate(per):
        f = 1789773 / p
        best = min(cands, key=lambda c: abs(math.log(c[0] / f)))[1]
        out[k] = best; out[16 + k] = best | 8
    return bytes(out)


def nes_rgb_src():
    """NES colour -> RGB555 (bank 0)"""
    v = [rgb555(c) for c in range(64)]
    return 'section bank 0, $3F00\nNES_RGB:\n' + ''.join(
        '    dw %s\n' % ', '.join(str(x) for x in v[k:k + 8]) for k in range(0, 64, 8))


MODULES = ('npc', 'text', 'event', 'menucore', 'select', 'snd', 'enc', 'btlbase')   # bank 0
SND_BANK0 = 81                          # sound: FF3 bank $36 at $4000 + a song bank ($37, $38, $39,
                                        #   $09) at $6000: banks 81-84
CODE1_MODULES = ('menu', 'selmenu', 'item', 'magic', 'equip', 'job', 'save', 'title', 'shop')  # bank CODE1
ITEMN_BANK0 = 85                        # condensed item names (shop.py): banks 85-87
BDATA_BANK = 88                         # battle data (encounter tables, formations, monsters)
CODE2 = 89                              # battle code: the game logic
CODE2_MODULES = ('btl', 'btlcore', 'btleq', 'btlai', 'btlmain', 'btlact', 'btlfight')
CODE3 = 110                             # battle code: the presentation (graphics, windows, input)
CODE3_MODULES = ('btlgfx', 'btlui', 'btlmsg', 'btlloop')
CODE4 = 111                             # battle code: magic, victory, the other actions
CODE4_MODULES = ('btlmagic', 'btlwin', 'btlact2')
MGFX_BANK0 = 90                         # monster graphics (NES banks $20-$27, $0C-$0D) as GB tiles: 90-94
CHGFX_BANK = 95                         # battle characters (NES banks $28 / $29) as GB tiles
BDATA2_BANK = 96                        # FF3 bank $30 (monsters, stat sets, scripts, items) at $4000
BTXT_BANK = 97                          # battle strings ($0400-$07FF): index + strings, banks 97-
CODE1 = 80


def engine_src(rom=None):
    """main.s's code, then each module's code (its `section bank 0` lines dropped: the code
    continues in bank 0), then all RAM sections"""
    rd = lambda n: open(os.path.join(HERE, 'src', n + '.s')).read()
    def split(t):
        i = t.find('\nsection wram')
        return (t, '') if i < 0 else (t[:i], t[i:])
    main_code, main_ram = split(rd('main'))
    codes, rams = [], []
    for m in MODULES:
        c, r = split(rd(m))
        codes.append('\n'.join(l for l in c.split('\n') if not l.startswith('section bank 0,')))
        rams.append(r)
    codes.append('section bank %d, $4000' % CODE1)
    for m in CODE1_MODULES:
        c, r = split(rd(m))
        codes.append('\n'.join(l for l in c.split('\n') if not l.startswith('section bank 0,')))
        rams.append(r)
    if rom is not None:
        import menu, title, shop
        codes.append(menu.code_data(rom, rgb555))
        codes.append(title.code_data(rom))
        codes.append(shop.code_data(rom))
    # the battle banks: calls between them go through bank-0 stubs (A passed and returned)
    lab = lambda t: set(re.findall(r'^([A-Za-z_]\w*):', t, re.M))
    bb = [(CODE2, CODE2_MODULES), (CODE3, CODE3_MODULES), (CODE4, CODE4_MODULES)]
    srcs = [[split(rd(m)) for m in mods] for _, mods in bb]
    labs = [set().union(*(lab(c) for c, _ in ss)) for ss in srcs]
    owner = {}
    for (bank, _), ls in zip(bb, labs):
        for n in ls: owner[n] = bank
    used = {}
    def xcalls(t, bank):
        def f(mo):
            o = owner.get(mo.group(3))
            if o is not None and o != bank:
                used[mo.group(3)] = o
                return mo.group(1) + (mo.group(2) or '') + ' ' + mo.group(3) + '__f'
            return mo.group(0)
        t = re.sub(r'\b(call|jp)(\s+(?:nz|z|nc|c)\s*,)?\s+([A-Za-z_]\w*)\b', f, t)
        def g(mo):                      # (jump tables: the routines' stubs)
            names = [n.strip() for n in mo.group(1).split(',')]
            out = []
            for n in names:
                o = owner.get(n)
                if o is not None and o != bank:
                    used[n] = o; n = n + '__f'
                out.append(n)
            return 'dw ' + ', '.join(out)
        t = re.sub(r'\bdw\s+([A-Za-z_][\w, ]*)', g, t)
        for mo in re.finditer(r'\bld\s+hl,\s+([A-Za-z_]\w*)\b', t):
            o = owner.get(mo.group(1))
            if o is not None and o != bank: raise SystemExit('cross-bank reference to %s' % mo.group(1))
        return t
    cs = [[xcalls(c, bank) for c, _ in ss] for (bank, _), ss in zip(bb, srcs)]
    codes.insert(len(MODULES), ''.join(
        '%s__f: ld [fx_a], a\n ld a, low(%s)\n ld [fx_t], a\n ld a, high(%s)\n ld [fx_t + 1], a\n'
        ' ld a, %d\n jp far_x\n' % (n, n, n, b) for n, b in sorted(used.items())))
    for (bank, _), c1, ss in zip(bb, cs, srcs):
        codes.append('section bank %d, $4000' % bank)
        for c, (_, r) in zip(c1, ss):
            codes.append('\n'.join(l for l in c.split('\n') if not l.startswith('section bank 0,')))
            rams.append(r)
    zp = ''.join('Z_%02X = $%04X\n' % (n, 0xFFB0 + n - 0x18) for n in range(0x18, 0x60))
    shadow = lambda t: t.replace('ld [MBC5_BANKL], a', 'ld [rom_bank], a\n            ld [MBC5_BANKL], a')
    return (open(os.path.join(ROOT, 'tools', 'gb3', 'rt', 'hw.s')).read() + '\n' + zp + shadow(main_code) + '\n' +
            shadow('\n'.join(codes)) + '\n' + main_ram + '\n' + '\n'.join(rams))


def gb_text_syms(rom):
    import menu
    return {k: v for k, v in menu.status_pack(rom)[1].items() if k.startswith('st_c')}


def main():
    args = sys.argv[1:]
    opt = {'--map': '', '--group': '0', '--x': '255', '--y': '255', '--dlg': '', '--song': '',
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
    g[0x1400:0x1800] = rom.new_game_state()                    # $5400: the new-game save block
    g[0x1800:0x1880] = rom.b(0, 0x9690, 128)                   # $5800: walking character colours
    g[0x2000:0x2800] = rom.prg[0x30 * 0x2000 + 0x1400:0x30 * 0x2000 + 0x1C00]   # $6000: 30/9400
    g[0x2800:0x3800] = snd_tab()                               # $6800: NES period -> GB frequency
    g[0x3800:0x3820] = snd_noise()                             # $7800: NES noise -> NR43
    g[0x3840:0x3860] = rom.b(0x3B, 0xA027, 32)                 # $7840: world map songs (3B/A006)
    g[0x3880:0x38A0] = rom.b(0x3B, 0xA047, 32)                 # $7880: and their sound effects
    bd = bytearray(0x4000)                                     # BDATA_BANK: encounter tables
    bd[0x0000:0x0010] = rom.b(0x2E, 0x9D40, 16)
    bd[0x0010:0x0020] = rom.b(0x2E, 0x9CF0, 16)
    bd[0x0020:0x0060] = rom.b(0x2E, 0x9D00, 64)
    bd[0x0060:0x00A0] = rom.b(0x3D, 0xBD78, 64)
    bd[0x0100:0x0200] = rom.b(0x2E, 0x92F0, 256)
    bd[0x0200:0x0300] = rom.b(0x2E, 0x93F0, 256)
    bd[0x0300:0x0400] = rom.b(0x39, 0xBE00, 256)
    bd[0x0400:0x0500] = rom.b(0x39, 0xBF00, 256)
    bd[0x0800:0x1000] = rom.b(0x2E, 0x94F0, 0x800)
    bd[0x1000:0x1400] = rom.b(0x2E, 0x8000, 0x400)             # $5000: battles (set, count id)
    bd[0x1400:0x1A00] = rom.b(0x2E, 0x8400, 0x600)             # $5400: monster sets (6 bytes)
    bd[0x1A00:0x1B00] = rom.b(0x2E, 0x8A00, 0x100)             # $5A00: monster counts (4 bytes)
    bd[0x1B00:0x1C00] = rom.b(0x2E, 0x8B00, 0x100)             # $5B00: monster graphics properties
    bd[0x1C00:0x1F00] = rom.b(0x2E, 0x8C00, 0x300)             # $5C00: battle palettes (3 colours)
    bd[0x1F00:0x2000] = rom.b(0x2E, 0x8F00, 0x100)             # $5F00: boss flags, attribute data
    bd[0x2000:0x220C] = rom.b(0x2F, 0xA4A4, 0x20C)             # $6000: 2F/A4A4.. placement tables
    bd[0x220C:0x2210] = rom.b(0x2F, 0xA2D0, 4)                 # $620C: 2F/A2D0 first tiles
    bd[0x2220:0x2234] = rom.b(0x2F, 0xB516, 20)                # $6220: 2F/B516 row x, start x / y
    bd[0x2800:0x2F00] = rom.b(0x32, 0x9100, 0x700)             # $6800: 32/9100- sprite frames
    bd[0x2240:0x2298] = rom.b(0x34, 0x9B21, 88)                # $6240: 34/9B21 commands by job
    bd[0x22A0:0x2336] = rom.b(0x34, 0x950D, 0x96)              # $62A0: 34/950D action scripts, types
    bd[0x2340:0x2360] = rom.b(0x34, 0x8739, 0x20)              # $6340: 34/8739 monster rows by tilemap
    bd[0x2360:0x23B0] = rom.b(0x32, 0x9EAD, 0x50)              # $6360: 32/9EAD target grid by tilemap
    bd[0x23B0:0x23BE] = rom.b(0x31, 0xBB0E, 14)                # $63B0: 31/BB0E spell reflectability
    bd[0x23C0:0x23CC] = rom.b(0x35, 0xA5FD, 12)                # $63C0: 35/A5FD spells with a message
    bd[0x3100:0x3500] = rom.b(0x10, 0x9B80, 0x400)             # $7100: 10/9B80 drops, 9C80 exp ids, 9D80 exp
    bd[0x3500:0x3600] = rom.b(1, 0xA24E, 256)                  # $7500: 01/A24E terrain attacks by map
    bd[0x3600:0x3601] = rom.b(0x35, 0xAB06, 1)                 # $7600: 35/AB06 terrain targeting
    bd[0x3610:0x3632] = rom.b(1, 0xA35E, 34)                   # $7610: 01/A35E item multipliers
    bd[0x23D0:0x2400] = rom.b(0x2E, 0x91A0, 48)                # $63D0: 2E/91A0 item spells
    f = rom.prg[0x0D * 0x2000 + 0x1700:0x0D * 0x2000 + 0x1700 + 144 * 16]   # $7000: numeral sprites
    for k, c in enumerate(list(range(0x80, 0x8A)) + [text.ENC[ch] for ch in 'Mis']):
        p0 = f[16 * (c - 0x70):16 * (c - 0x70) + 8]                 #   (the font's ink, clear around)
        bd[0x3000 + 16 * k:0x3010 + 16 * k] = bytes(x for r in range(8) for x in (p0[r], p0[r]))
    for k, a in enumerate((0x9100, 0x9200, 0x9300)):           # $6400: general use palettes
        bd[0x2400 + 0x100 * k:0x2500 + 0x100 * k] = rom.b(0, a, 0x100)
    banks[BDATA_BANK] = bd
    for k, pair in enumerate((0x10, 0x11, 0x12, 0x13, 0x06)):   # monster graphics as GB tiles
        src = rom.prg[pair * 0x4000:pair * 0x4000 + 0x4000]
        banks[MGFX_BANK0 + k] = bytearray(b''.join(nes2gb(src[16 * t:16 * t + 16]) for t in range(1024)))
    banks[BDATA2_BANK] = bytearray(rom.b(0x30, 0x8000, 0x2000) + bytes(0x2000))
    bt = text.pack_battle(rom, BTXT_BANK)
    assert max(bt) < 100, max(bt)
    banks.update(bt)
    src = rom.prg[0x14 * 0x4000:0x15 * 0x4000]                 # characters (NES banks $28 / $29)
    banks[CHGFX_BANK] = bytearray(b''.join(nes2gb(src[16 * t:16 * t + 16]) for t in range(1024)))
    import shop
    nb, nflags = shop.name_tiles(rom)
    g[0x3900:0x3A00] = nflags                                  # $7900: condensed item names
    for k, d in nb.items(): banks[ITEMN_BANK0 + k] = d
    banks[GAME_BANK] = g
    for grp in range(3):
        w = group_world(grp)
        tt = bytearray(0x4000)
        for mid in range(256):
            mp = rom.map_props(mid, w)
            tt[32 * mid:32 * mid + 16] = rom.map_treasures(mp[14])
            tt[32 * mid + 16:32 * mid + 32] = rom.map_triggers(mp[15])
        banks[TT_BANK + grp] = tt
    import menu
    banks[MENU_BANK] = menu.pack(rom, rgb555)
    jb = bytearray(0x4000)
    jb[0:0x2000] = rom.prg[0x39 * 0x2000:0x3A * 0x2000]
    lp = rom.b(0x3D, 0xAD59, 44)
    for k in range(22):
        v = (lp[2 * k] | lp[2 * k + 1] << 8) - 0x4000
        jb[0x2000 + 2 * k] = v & 0xFF; jb[0x2001 + 2 * k] = v >> 8
    banks[JOB_BANK] = jb
    for k, sb in enumerate((0x37, 0x38, 0x39, 0x09)):          # sound banks
        banks[SND_BANK0 + k] = bytearray(rom.prg[0x36 * 0x2000:0x37 * 0x2000] + rom.prg[sb * 0x2000:(sb + 1) * 0x2000])
    src = engine_src(rom) + '\n' + nes_rgb_src() + '\n' + trig_src(rom)
    title_on = opt['--map'] == '' and opt['--group'] == '0'
    r = asm(src, syms={'START_MAP': int(opt['--map'] or '0', 0), 'START_GRP': int(opt['--group'], 0),
                       'TITLE': 1 if title_on else 0,
                       'START_X': int(opt['--x'], 0), 'START_Y': int(opt['--y'], 0),
                       'TS_BANK': TS_BANK, 'MT_BANK': MT_BANK, 'SPR_BANK': SPR_BANK,
                       'WLD_BANK': WLD_BANK, 'NPCT_BANK': NPCT_BANK, 'NPCL_BANK': NPCL_BANK,
                       'NPCG_BANK0': NPCG_BANK0, 'TXT_BANK': TXT_BANK, **gb_text_syms(rom), 'EVT_BANK': EVT_BANK,
                       'GAME_BANK': GAME_BANK, 'TT_BANK': TT_BANK, 'MENU_BANK': MENU_BANK,
                       'JOB_BANK': JOB_BANK, 'CODE1': CODE1, 'SND_BANK0': SND_BANK0, 'ITEMN_BANK0': ITEMN_BANK0, 'BDATA_BANK': BDATA_BANK, 'CODE2': CODE2, 'MGFX_BANK0': MGFX_BANK0, 'CHGFX_BANK': CHGFX_BANK, 'BDATA2_BANK': BDATA2_BANK, 'BTXT_BANK': BTXT_BANK, 'CODE3': CODE3, 'CODE4': CODE4,
                       'TEST_SONG': int(opt['--song'], 0) if opt['--song'] else 255,
                       'SND_MASK': int(os.environ.get('GB_SND_MASK', 'FF'), 16),     # (test builds: NR51)
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
