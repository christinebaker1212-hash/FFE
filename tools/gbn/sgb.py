"""FF1 native build: Super Game Boy data. Bank SGB_BANK: $4000 the border's tiles (SNES 4bpp,
tools/gb/sgb_border.py: drawn there, no game graphics), $5000 its map and palettes (PCT_TRN),
$5880 per formation (128) the enemy palette's colours 1-3 (RGB555: per DMG shade 1-3 the
formation's colour in that shade, battle.dmg_shades' grouping), $5B80 fixed palettes
(4 colours each: menus, battle windows, the party column, the world map)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
import data, battle, minimap

SGB_BANK = 98


def _grey(c):
    return (c & 0x0F) in (0x00, 0x0D, 0x0E, 0x0F)


def bank(rom):
    import sgb_border
    chr_, pct, n = sgb_border.make()
    blob = bytearray(b'\0' * 0x4000)
    blob[0:len(chr_)] = chr_
    blob[0x1000:0x1000 + len(pct)] = pct
    for f in range(128):
        fd = rom.rd(battle.BANK_DOMAINS, battle.FORMATIONS + 16 * f, 16)
        pa = list(rom.rd(battle.BANK_BTLC, battle.BTL_PALS + 4 * fd[10], 4))
        pb = list(rom.rd(battle.BANK_BTLC, battle.BTL_PALS + 4 * fd[11], 4))
        win = [0x0F, 0x00, 0x0F, 0x30]
        msh = data.map_shades([win, pa, pb, win])
        cols = []
        for s, dflt in ((1, 0x10), (2, 0x00), (3, 0x0F)):
            cs = [c for c in pa[1:] + pb[1:] if msh.get(c) == s]
            cs = sorted(cs, key=_grey)
            cols.append(cs[0] if cs and s < 3 else dflt)
        blob[0x1880 + 6 * f:0x1886 + 6 * f] = b''.join(
            data.rgb555(c).to_bytes(2, 'little') for c in cols)
    mini = minimap.bank(rom)
    mpal = list(mini[0x2309:0x230D])
    order = sorted(range(4), key=lambda i: -data.lum(mpal[i]))      # shade order (as minimap.py)
    fixed = [[0x30, 0x10, 0x00, 0x01],                              # menus: FF1's blue windows
             [0x30, 0x10, 0x00, 0x0F],                              # battle windows (black)
             [0x30, 0x36, 0x16, 0x0F],                              # the party column
             [mpal[i] for i in order]]                              # the world map
    fix = rom.prg[-0x4000:]                                         # FF1's battle sprite
    pi = fix.find(bytes([0x0F, 0x28, 0x18, 0x21, 0x0F, 0x16, 0x30, 0x36]))   #   palette 0 (Thief,
    assert pi >= 0, 'battle sprite palettes not found'             #   Monk, White Magician)
    sp0 = list(fix[pi:pi + 4])
    rk = sorted(range(1, 4), key=lambda i: -data.lum(sp0[i]))      # (ranks as data.spr_rank_tile)
    fixed.append([0x30, sp0[rk[1]], sp0[rk[2]], 0x0F])              # the party: palette 0 jobs
    for k, p in enumerate(fixed):
        blob[0x1B80 + 8 * k:0x1B88 + 8 * k] = b''.join(data.rgb555(c).to_bytes(2, 'little') for c in p)
    return bytes(blob)
