"""FF1 native build: item / spell / class names with FF3's icons.

Names: the project's English (translations/ff1_items.py), one table for FF1's whole name list
(items 1-27, weapons 28-67, armour 68-107, gold 108-175, spells 176-239, classes 240-251).
Icons: FF3's weapon / armour / item / white / black magic icons, read from the user's FF3 ROM
at build time (font tiles $60-$75 of FF3's menu graphics) and placed at font codes that the
text never uses. Which icon a name gets: weapons by FF1's battle graphic of the weapon (ROM),
armour by FF1's armour type table (ROM), bracelets / rings by name, spells by their place in
a level (FF1: 4 white, then 4 black)."""
import hashlib, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'translations'))
import data

FF3_SHA1 = 'c4443fc24625e3c2bb859525eb44b6b3a80e7c35'
FF3_FONT = 0x1B000                    # FF3's menu font tiles (file offset after the header)
# icon -> (native font code, FF3 tile)
ICONS = {
    'item': (0x01, 0x72), 'white': (0x03, 0x74), 'black': (0x04, 0x75),
    'shield': (0x05, 0x60), 'helmet': (0x06, 0x61), 'armour': (0x07, 0x62),
    'gloves': (0x08, 0x63), 'bracelet': (0x09, 0x64), 'sword': (0x19, 0x6B),
    'knife': (0x1A, 0x69), 'axe': (0x1B, 0x6A), 'hammer': (0x1C, 0x67),
    'staff': (0x1D, 0x68), 'rod': (0x1E, 0x66), 'claw': (0x1F, 0x73),
}
ICON_CODES = [c for c, _ in ICONS.values()]
# FF1 weapon battle graphic (weapon data byte 6, high bits) -> icon
WPN_GFX = {0x80: 'sword', 0x84: 'sword', 0x88: 'sword', 0x8C: 'sword', 0x90: 'sword',
           0x94: 'hammer', 0x98: 'knife', 0x9C: 'axe', 0xA0: 'staff', 0xA4: 'rod', 0xA8: 'claw'}
ARM_TYPE = {0: 'armour', 1: 'shield', 2: 'helmet', 3: 'gloves'}
BANK_EQUIP, WEAPONS = 0x0C, 0x8000    # 40 x 8 bytes
NAMES_BANK = 4


def ff3_rom(path=None):
    path = path or os.path.join(HERE, '..', '..', 'roms', 'Final Fantasy III (Japan).nes')
    if not os.path.exists(path): return None
    d = open(path, 'rb').read()
    if hashlib.sha1(d).hexdigest() != FF3_SHA1:
        print('warning: %s is not the expected FF3 ROM: no icons' % path); return None
    return d[16:]


# The items' icon: a drawstring bag (owner, 2026-11-22). FF3's own consumables have no icon
# (their names start with a blank; its red ball is the summon-magic icon), so this one is our
# own drawing in FF3's icon colours: '.' background (2), '#' outline (3), 'o' fill (1).
BAG = ['........',
       '..#.#...',
       '...#....',
       '..#o#...',
       '.#ooo#..',
       '#oo#oo#.',
       '#ooooo#.',
       '.#####..']


def own_tile(rows):
    """an NES 2bpp tile from rows of '.', 'o', '#' (colours 2, 1, 3)"""
    col = {'.': 2, 'o': 1, '#': 3}
    p0 = bytearray(8); p1 = bytearray(8)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            c = col[ch]
            if c & 1: p0[y] |= 0x80 >> x
            if c & 2: p1[y] |= 0x80 >> x
    return bytes(p0 + p1)


def icon_tiles(ff3):
    """{code: NES tile} for the icons (blank tiles without the FF3 ROM)"""
    out = {}
    for code, t in ICONS.values():
        out[code] = ff3[FF3_FONT + 16 * t:FF3_FONT + 16 * t + 16] if ff3 else bytes(8) + b'\xff' * 8
    out[ICONS['item'][0]] = own_tile(BAG)
    return out


def armour_types(rom):
    fix = rom.prg[0xE * 0x4000:0xF * 0x4000]
    sig = bytes([0] * 16 + [1] * 9 + [2] * 7 + [3] * 8)
    i = fix.find(sig)
    assert i >= 0, 'armour type table not found'
    return fix[i:i + 40]


def icon_of(rom, k, name):
    if 1 <= k <= 27: return 'item'
    if 28 <= k <= 67:
        g = rom.rd(BANK_EQUIP, WEAPONS + 8 * (k - 28) + 6)
        return WPN_GFX.get(g & 0xFC, 'sword')
    if 68 <= k <= 107:
        if 'Bracelet' in name or 'Ring' in name: return 'bracelet'
        return ARM_TYPE[armour_types(rom)[k - 68]]
    if 176 <= k <= 239: return 'white' if (k - 176) % 8 < 4 else 'black'
    return None


def name_codes(rom, k, icons=True):
    import ff1_items, text
    name = ff1_items.T.get(k, '')
    out = bytearray()
    ic = icon_of(rom, k, name)
    if ic and icons: out.append(ICONS[ic][0])
    out += bytes(text.code_of(ch) for ch in name)
    return bytes(out)


def find14(rom, sig, off=0):
    b14 = rom.prg[14 * 0x4000:15 * 0x4000]
    i = b14.find(bytes(sig))
    assert i >= 0, 'not found: ' + bytes(sig).hex()
    return 0x8000 + i + off


def equip_tables(rom):
    """{weapon stats (40 x 8), armour stats (40 x 4), weapon / armour permissions (40 words
    each), armour types (40)}; the permission tables found by FF1's IsEquipLegal code"""
    import re
    b14 = rom.prg[14 * 0x4000:15 * 0x4000]
    perms = []
    for m in re.finditer(re.escape(bytes([0xA6, 0x10, 0xBD])), b14):
        i = m.start()
        if b14[i + 5:i + 7] == bytes([0x25, 0x14]): perms.append(b14[i + 3] | b14[i + 4] << 8)
    assert len(perms) == 2
    return dict(wstat=rom.rd(BANK_EQUIP, WEAPONS, 320), astat=rom.rd(BANK_EQUIP, 0x8140, 160),
                wperm=rom.rd(14, perms[0], 80), aperm=rom.rd(14, perms[1], 80),
                atype=armour_types(rom))


def shop_tables(rom):
    """FF1's shops: type per shop id (71, found by EnterShop's lookup in the fixed bank),
    each shop's 5 items (or the inn / clinic price) from lut_ShopData (found by
    LoadShopInventory), the classes' magic permissions (12 x 8, lut_MagicPermisPtr)"""
    import re
    b14 = rom.prg[14 * 0x4000:15 * 0x4000]; b15 = rom.prg[15 * 0x4000:16 * 0x4000]
    sd = None
    for m in re.finditer(re.escape(bytes([0x0A, 0xAA, 0xBD])), b14):
        i = m.start()
        if b14[i + 5:i + 7] == b'\x85\x10' and b14[i + 10:i + 14] == bytes([0x85, 0x11, 0xA0, 0x04]):
            sd = b14[i + 3] | b14[i + 4] << 8; sid = b14[i - 1]
    assert sd, 'shop data not found'
    i = b15.find(bytes([0xA6, sid, 0xBD]))
    assert i >= 0, 'shop types not found'
    t = b15[i + 3] | b15[i + 4] << 8
    types = b15[t - 0xC000:t - 0xC000 + 71]
    items = bytearray()
    for k in range(71):
        p = b14[sd - 0x8000 + 2 * k] | b14[sd - 0x8000 + 2 * k + 1] << 8
        items += b14[p - 0x8000:p - 0x8000 + 5]
    i = [m.start() for m in re.finditer(re.escape(bytes([0x38, 0xE9, 0xB0])), b14)
         if b14[m.start() - 5:m.start() - 3] == b'\x85\x11'][0]
    k = i
    while not (b14[k] == 0xBD and b14[k + 3:k + 5] == b'\x85\x10'): k -= 1
    mp = b14[k + 1] | b14[k + 2] << 8
    perms = bytearray()
    for c in range(12):
        p = b14[mp - 0x8000 + 2 * c] | b14[mp - 0x8000 + 2 * c + 1] << 8
        perms += b14[p - 0x8000:p - 0x8000 + 8]
    return bytes(types), bytes(items), bytes(perms)


def inv_icons(ff3):
    """the icons inverted (an equipped item): DMG and CGB tiles by font code (32 each)"""
    import text
    dmg = bytearray(512); cgb = bytearray(512)
    for code, t16 in icon_tiles(ff3).items():
        dmg[16 * code:16 * code + 16] = data.gb_tile(t16, (3, 2, 0, 3))
        cgb[16 * code:16 * code + 16] = data.gb_tile(t16, (0, 1, 3, 0))
    return bytes(dmg), bytes(cgb)


def names_bank(rom, ff3=None):
    """$4000 256 pointers, the names (icon + letters, 0-terminated) after them; $7300 the
    equipment tables, $7600 / $7800 the inverted icons (DMG / CGB)"""
    blob = bytearray(b'\xff' * 0x4000)
    body = bytearray(); ptrs = bytearray()
    for k in range(256):
        ptrs += (0x4200 + len(body)).to_bytes(2, 'little')
        body += name_codes(rom, k) + b'\0'
    blob[0:0x200] = ptrs
    blob[0x200:0x200 + len(body)] = body
    assert 0x200 + len(body) <= 0x3000
    e = equip_tables(rom)
    blob[0x3300:0x3440] = e['wstat']
    blob[0x3440:0x34E0] = e['astat']
    blob[0x3500:0x3550] = e['wperm']
    blob[0x3550:0x35A0] = e['aperm']
    blob[0x35A0:0x35C8] = e['atype']
    d, c = inv_icons(ff3)
    blob[0x3600:0x3800] = d
    blob[0x3800:0x3A00] = c
    t, it, pm = shop_tables(rom)
    blob[0x3A00:0x3A47] = t                       # $7A00 shop type per shop id
    blob[0x3B00:0x3B00 + len(it)] = it            # $7B00 5 items per shop
    blob[0x3D00:0x3D60] = pm                      # $7D00 magic permissions (8 per class)
    return blob
