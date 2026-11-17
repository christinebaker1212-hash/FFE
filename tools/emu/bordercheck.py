"""Check that text never draws over a window border.

Reads a PPU write log (emulator built with tools/emu/build_emu.sh, env PPU_LOG=1:
lines 'P addr value pc=XXXX b=YY') and replays the nametable writes. Cells whose last
value is a window-frame tile are borders; any later write of a non-frame tile to a
border cell by a text routine is reported.

usage: bordercheck.py LOG GAME     (GAME = ff1 | ff2 | ff3)"""
import sys, re

CFG = {
    # frame tiles, and PCs (address after the store) of the text-drawing stores
    'ff1': dict(frame=set(range(0xF7, 0xFF)),
                text=lambda pc: pc in (0xDF01, 0xDF04, 0xE050, 0xE053, 0xE067, 0xE06A, 0xDBA5)
                                or 0x5C00 <= pc < 0x6000),
}

def check(lines, game):
    cfg = CFG[game]; nt = {}; bad = []
    for ln in lines:
        m = re.match(r'P ([0-9A-F]{4}) ([0-9A-F]{2}) pc=([0-9A-F]{4})', ln)
        if not m: continue
        a, v, pc = int(m.group(1), 16), int(m.group(2), 16), int(m.group(3), 16)
        if not (0x2000 <= a < 0x3000) or (a & 0x3FF) >= 0x3C0: continue   # nametable cells only
        old = nt.get(a)
        if old is not None and old in cfg['frame'] and v not in cfg['frame'] and cfg['text'](pc):
            bad.append('row %2d col %2d (nt %d): frame %02X overwritten by %02X  pc=%04X'
                       % ((a & 0x3FF) // 32, a & 31, (a - 0x2000) // 0x400, old, v, pc))
        nt[a] = v
    return bad

if __name__ == '__main__':
    bad = check(open(sys.argv[1]), sys.argv[2])
    for b in bad: print(b)
    print('%d border overwrites' % len(bad))
    sys.exit(1 if bad else 0)
