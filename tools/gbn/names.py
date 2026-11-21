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


def icon_tiles(ff3):
    """{code: NES tile} for the icons (blank tiles without the FF3 ROM)"""
    out = {}
    for code, t in ICONS.values():
        out[code] = ff3[FF3_FONT + 16 * t:FF3_FONT + 16 * t + 16] if ff3 else bytes(8) + b'\xff' * 8
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


def names_bank(rom):
    """$4000 256 pointers, the names (icon + letters, 0-terminated) after them"""
    blob = bytearray(b'\xff' * 0x4000)
    body = bytearray(); ptrs = bytearray()
    for k in range(256):
        ptrs += (0x4200 + len(body)).to_bytes(2, 'little')
        body += name_codes(rom, k) + b'\0'
    blob[0:0x200] = ptrs
    blob[0x200:0x200 + len(body)] = body
    assert 0x200 + len(body) <= 0x3000
    return blob
