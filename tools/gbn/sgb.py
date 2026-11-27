"""FF1 native build: Super Game Boy data. Bank SGB_BANK: $4000 the border's tiles (SNES 4bpp,
tools/gb/sgb_border.py: drawn there, no game graphics), $5000 its map and palettes (PCT_TRN),
$5880 per formation (128) the enemy palette's colours 1-3 (RGB555: per DMG shade 1-3 the
formation's colour in that shade, battle.dmg_shades' grouping; $6000 / $6300 the same from palette
A / B alone, for battles whose enemies use only one), $5B80 fixed palettes
(4 colours each: menus, battle windows, the party column, the world map), $5C00 the border's
colours per region (owner's list, 2026-11-24: 9 x 32 bytes, palette 4: colours 1-5 change, the
frame's whites and the crystals stay), $5E00 the region of each map (61)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
import data, battle, minimap

SGB_BANK = 98


def _grey(c):
    return (c & 0x0F) in (0x00, 0x0D, 0x0E, 0x0F)


def bank(rom, forms=None):
    import sgb_border
    chr_, pct, n = sgb_border.make()
    blob = bytearray(b'\0' * 0x4000)
    blob[0:len(chr_)] = chr_
    blob[0x1000:0x1000 + len(pct)] = pct
    for f in range(128):
        if forms is None:
            fd = rom.rd(battle.BANK_DOMAINS, battle.FORMATIONS + 16 * f, 16)
            pa = list(rom.rd(battle.BANK_BTLC, battle.BTL_PALS + 4 * fd[10], 4))
            pb = list(rom.rd(battle.BANK_BTLC, battle.BTL_PALS + 4 * fd[11], 4))
        elif f < len(forms):
            pa, pb = forms[f]                      # (the post-game's formations: pgbattle.py)
        else:
            continue
        win = [0x0F, 0x00, 0x0F, 0x30]
        msh = data.map_shades([win, pa, pb, win])
        def pick(src, base=None):
            cols = []
            for k, (s, dflt) in enumerate(((1, 0x10), (2, 0x00), (3, 0x0F))):
                cs = sorted([c for c in src if msh.get(c) == s], key=_grey)
                cols.append(cs[0] if cs and s < 3 else (base[k] if base else dflt))
            return b''.join(data.rgb555(c).to_bytes(2, 'little') for c in cols), cols
        both, bc = pick(pa[1:] + pb[1:])
        blob[0x1880 + 6 * f:0x1886 + 6 * f] = both
        # (owner's audit, 2026-11-25: a battle whose enemies all use one of the two palettes takes
        #   that palette's colours: $6000 + 6 f palette A only, $6300 + 6 f palette B only)
        blob[0x2000 + 6 * f:0x2006 + 6 * f] = pick(pa[1:], bc)[0]
        blob[0x2300 + 6 * f:0x2306 + 6 * f] = pick(pb[1:], bc)[0]
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
    fixed.append([0x30, 0x28, 0x00, 0x01])                          # (owner's audit, 2026-11-25:
                                                                    #   menus' gold labels: colour
                                                                    #   1 FF1's gold, as the Color's)
    for k, p in enumerate(fixed):
        blob[0x1B80 + 8 * k:0x1B88 + 8 * k] = b''.join(data.rgb555(c).to_bytes(2, 'little') for c in p)
    import sgb_border, ui
    for r, cols in enumerate(REGION_COLS):
        pal = list(sgb_border.PAL)
        if cols: pal[1:6] = cols
        for i, (rr, gg, bb) in enumerate(pal):
            c = (rr >> 3) | (gg >> 3) << 5 | (bb >> 3) << 10
            blob[0x1C00 + 32 * r + 2 * i] = c & 0xFF; blob[0x1C01 + 32 * r + 2 * i] = c >> 8
    lm = ui.loc_map_all()
    for m in range(len(lm)):
        blob[0x1E00 + m] = region_of(m, ui.LOC_NAMES[lm[m]])
    return bytes(blob)


# the border's field and band colours per region (None: as drawn, the world's blue)
REGION_COLS = [
    None,                                                                     # 0 world
    [(26, 14, 6), (52, 30, 12), (86, 52, 20), (150, 96, 40), (200, 140, 70)],     # 1 town
    [(14, 14, 20), (32, 32, 44), (56, 56, 74), (110, 110, 140), (150, 150, 180)],  # 2 castle
    [(20, 12, 6), (44, 26, 12), (70, 44, 22), (130, 84, 40), (175, 120, 62)],     # 3 cave
    [(4, 18, 22), (8, 40, 50), (14, 66, 80), (30, 130, 150), (70, 180, 190)],     # 4 sea
    [(20, 24, 40), (40, 52, 90), (70, 90, 140), (120, 160, 220), (180, 210, 250)],  # 5 sky
    [(22, 4, 10), (48, 8, 20), (80, 14, 34), (150, 30, 60), (200, 60, 90)],       # 6 Chaos
    [(10, 22, 30), (24, 48, 64), (40, 80, 104), (110, 170, 210), (170, 220, 245)],  # 7 ice
    [(30, 8, 4), (64, 16, 8), (100, 28, 12), (190, 60, 30), (240, 110, 50)],      # 8 volcano
]


def region_of(m, name):
    """map m (its place name) -> border region"""
    if m < 8: return 1                                          # towns
    if 'Castle' in name and 'Floating' not in name: return 2
    if 'Temple' in name: return 6
    if 'Undersea' in name or 'Waterfall' in name: return 4
    if 'Floating' in name or 'Mirage' in name: return 5
    if 'Ice' in name: return 7
    if 'Volcano' in name: return 8
    return 3                                                    # caves and the rest
