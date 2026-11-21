"""FF1 native build: battle data, read from the user's ROM at build time (the tables FF1's
battle code reads, at the addresses the disassembly names; the Japanese ROM keeps them in
the same places, checked by their contents' shape), plus the project's English names and
messages. Our own layout of the data banks:

bank BTL_DATA:
  $4000 formations (128 x 16)          $4800 encounter domains (64 x 8)
  $4A00 encounter rates (by map)        $4C00 enemy stats (128 x 20)
  $5600 enemy AI (44 x 16)              $5900 magic data ($5C x 8)
  $5C00 magic battle messages ($5C)     $5C80 battle palettes (64 x 4)
  $5E00 DMG shades per formation (128 x 8: palette A, palette B -> shade per colour index)
  $6200 enemy names: 128 pointers, strings     $6C00 battle messages: 80 pointers, strings
banks ENEMY_CHR, +1: enemy graphics pages 0-7 / 8-15 at $4000 + $800 page (tile t at
  + 16 t, t = $12-$7F; GB 2bpp, colour indices as on the NES)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'translations'))
import data

BTL_DATA, ENEMY_CHR = 92, 93
BANK_DOMAINS, FORMATIONS, DOMAINS = 0x0B, 0x8400, 0x8000
BANK_BTLC, ENEMY_STATS, ENEMY_AI, MAGIC_DATA, MAGIC_MSGS, BTL_PALS = 0x0C, 0x8520, 0x9020, 0x81E0, 0x84C0, 0x8F20
BANK_BATTLECHR = 0x07


def enc(s):
    import text
    return bytes(text.code_of(ch) for ch in s)


def battle_rates(rom):
    """FF1 lut_BattleRates (bank 0B): found after the formations' end by the disassembly's
    order (lut_BattleFormations then lut_BattleRates, one byte per map)"""
    return rom.rd(BANK_DOMAINS, FORMATIONS + 0x800, 64)


def dmg_shades(rom):
    """per formation: the DMG shade of each colour index of its two enemy palettes, by the
    brightness grouping of the field (data.map_shades) over both palettes and the window"""
    out = bytearray()
    for f in range(128):
        fd = rom.rd(BANK_DOMAINS, FORMATIONS + 16 * f, 16)
        pa = list(rom.rd(BANK_BTLC, BTL_PALS + 4 * fd[10], 4))
        pb = list(rom.rd(BANK_BTLC, BTL_PALS + 4 * fd[11], 4))
        win = [0x0F, 0x00, 0x0F, 0x30]
        msh = data.map_shades([win, pa, pb, win])
        out += bytes(msh[c] for c in pa) + bytes(msh[c] for c in pb)
    return bytes(out)


def strtab(base, strings):
    ptrs = bytearray(); body = bytearray()
    a0 = base + 2 * len(strings)
    for s in strings:
        ptrs += (a0 + len(body)).to_bytes(2, 'little'); body += s + b'\0'
    return bytes(ptrs) + bytes(body)


def data_bank(rom):
    import ff1_monsters, ff1_battle
    b = bytearray(b'\xff' * 0x4000)
    def put(a, d): b[a - 0x4000:a - 0x4000 + len(d)] = d
    put(0x4000, rom.rd(BANK_DOMAINS, FORMATIONS, 128 * 16))
    put(0x4800, rom.rd(BANK_DOMAINS, DOMAINS, 64 * 8))
    put(0x4A00, battle_rates(rom))
    put(0x4C00, rom.rd(BANK_BTLC, ENEMY_STATS, 128 * 20))
    put(0x5600, rom.rd(BANK_BTLC, ENEMY_AI, 44 * 16))
    put(0x5900, rom.rd(BANK_BTLC, MAGIC_DATA, 0x5C * 8))
    put(0x5C00, rom.rd(BANK_BTLC, MAGIC_MSGS, 0x5C))
    put(0x5C80, rom.rd(BANK_BTLC, BTL_PALS, 64 * 4))
    put(0x5E00, dmg_shades(rom))
    names = strtab(0x6200, [enc(n) for n in ff1_monsters.M[:128]])
    assert len(names) <= 0xA00
    put(0x6200, names)
    msgs = strtab(0x6C00, [enc(ff1_battle.B.get(k, '')) for k in range(80)])
    assert len(msgs) <= 0x1400
    put(0x6C00, msgs)
    return bytes(b)


def chr_banks(rom):
    """the 16 enemy graphics pages as GB tiles (colour indices)"""
    out = {}
    for half in range(2):
        blob = bytearray(b'\xff' * 0x4000)
        for p in range(8):
            page = rom.rd(BANK_BATTLECHR + half, 0x8000 + 0x800 * p, 0x800)
            for t in range(0x12, 0x80):
                blob[0x800 * p + 16 * t:0x800 * p + 16 * t + 16] = data.gb_tile(page[16 * t:16 * t + 16])
        out[ENEMY_CHR + half] = bytes(blob)
    return out
