"""Run a built GB ROM headless in PyBoy: frames, fault report, screenshot.
usage: run_gb.py ROM.gb FRAMES [--shots N] [--press BUTTON@FRAME ...]"""
import os, sys
from pyboy import PyBoy


def syms(path):
    out = {}
    for l in open(path):
        b, rest = l.split(':'); a, n = rest.split()
        out[n] = (int(b, 16), int(a, 16))
    return out


def where(sy, bank, addr):
    best = None
    for n, (b, a) in sy.items():
        if (b == bank or b == 0) and a <= addr and (best is None or a > best[1]): best = (n, a, b)
    return '%s+%d' % (best[0], addr - best[1]) if best else '?'


def main():
    rom, frames = sys.argv[1], int(sys.argv[2])
    shots = 1; presses = []
    a = sys.argv[3:]
    while a:
        x = a.pop(0)
        if x == '--shots': shots = int(a.pop(0))
        elif x == '--press': b, f = a.pop(0).split('@'); presses.append((int(f), b))
    sy = syms(rom[:-3] + '.sym')
    halted = sy['rt_halted'][1]
    pb = PyBoy(rom, window='null', cgb=False, sound_emulated=False)
    pb.set_emulation_speed(0)
    base = rom[:-3]
    step = max(1, frames // shots)
    for f in range(frames):
        for pf, b in presses:
            if pf == f: pb.button(b, 3)
        pb.tick()
        if pb.register_file.PC in range(halted, halted + 2):
            m = pb.memory
            dbg = [m[0xD820 + k] for k in range(8)]
            ret = dbg[5] | dbg[6] << 8
            print('FAULT code %d at frame %d: HL=%04X SP=%04X caller=%02X:%04X (%s)' % (
                dbg[0], f, dbg[1] | dbg[2] << 8, dbg[3] | dbg[4] << 8, dbg[7], ret, where(sy, dbg[7], ret)))
            break
        if (f + 1) % step == 0:
            pb.screen.image.save('%s_f%05d.png' % (base, f + 1))
    pc = pb.register_file.PC
    print('end: frame %d PC=%04X bank=%02X (%s)' % (f + 1, pc, pb.memory[0xFF80 + 12] if False else 0, where(sy, 0, pc)))
    pb.screen.image.save(base + '_last.png')
    pb.stop(save=False)


if __name__ == '__main__':
    main()
