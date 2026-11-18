"""Battle formation survey on the NES: force each formation (every read of the formation
number $6A becomes `LDA #f`), replay the battleshot.py walk from a state saved
just before the encounter, rebuild the nametable from the PPU writes, and report per
formation the NES columns/rows the enemy graphics use and the BG tile numbers shown.
usage: PYTHONPATH=build/emu formations.py NES OUTDIR [f ...]  (default: all 128)
Writes OUTDIR/formations.json and a screenshot per formation type."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from battleshot import battle_input, pad
from cynes import NES
from PIL import Image
import numpy as np

HDR, START, SHOT = 16, 6100, 6300


def patched(rom, f):
    """Every read of the formation number $6A becomes LDA #f (battle graphics $EAD5/$EADD,
    battle entry $C1D4/$C933, setup $F292, bank 11 $9AD3/$A141). (The bytes A5 6A at $F6B0 /
    $F6B6 are the operands of STA / DEC $6AA5, not reads of $6A: left alone.)"""
    r = bytearray(rom)
    sites = [(b, a) for b in (15, 31) for a in (0xC1D4, 0xC933, 0xEAD5, 0xEADD, 0xF292)] + \
            [(11, 0x9AD3), (11, 0xA141)]
    for bank, cpu in sites:
        a = HDR + bank * 0x4000 + (cpu - (0x8000 if bank == 11 else 0xC000))
        if r[a] == 0xA5 and r[a + 1] == 0x6A:
            r[a:a + 2] = bytes([0xA9, f])
        else:
            assert r[a:a + 3] == bytes([0xAD, 0x6A, 0x00]), (bank, hex(cpu), r[a:a + 3].hex())
            r[a:a + 3] = bytes([0xA9, f, 0xEA])
    return bytes(r)


def run(path, state, frames):
    n = NES(path); n.load(state)
    n.watch = (0x2000, 0x2007)
    nt = np.full((30, 32), -1, int)
    latch = addr = ctrl = 0
    img = None
    for f in range(START, SHOT + 1):
        n.controller = pad(frames, f); img = n.step(1)
        for _, a, v in n.watch:
            if a == 0x2000: ctrl = v
            elif a == 0x2006:
                addr = ((v & 0x3F) << 8) | (addr & 0xFF) if latch == 0 else (addr & 0x3F00) | v
                latch ^= 1
            elif a == 0x2005: latch ^= 1
            elif a == 0x2007:
                if 0x2000 <= addr < 0x23C0: nt[(addr >> 5) & 31, addr & 31] = v
                addr = (addr + (32 if ctrl & 4 else 1)) & 0x3FFF
    return nt, np.array(img)


def main():
    nes, out = sys.argv[1], sys.argv[2]
    which = [int(x) for x in sys.argv[3:]] or list(range(128))
    os.makedirs(out, exist_ok=True)
    rom = open(nes, 'rb').read()
    types = [rom[HDR + 11 * 0x4000 + 0x400 + 16 * f] >> 4 for f in range(128)]
    frames = battle_input(); n = NES(nes)
    for f in range(START):
        n.controller = pad(frames, f); n.step(1)
    state = n.save()
    tmp = os.path.join(out, 'tmp.nes')
    res, shot_done = {}, set()
    for f in which:
        open(tmp, 'wb').write(patched(rom, f))
        nt, img = run(tmp, state, frames)
        enemy = nt[6:18, 2:16]
        cells = np.argwhere((enemy > 0) & (enemy != 0xFF))     # empty cells: $00 or $FF
        cols = sorted({int(c) + 2 for _, c in cells}); rows = sorted({int(r) + 6 for r, _ in cells})
        res[f] = dict(type=types[f], cols=[cols[0], cols[-1]] if cols else None,
                      rows=[rows[0], rows[-1]] if rows else None,
                      tiles=sorted({int(t) for t in nt.flatten() if t >= 0}))
        print(f, 'type', types[f], 'cols', res[f]['cols'], 'rows', res[f]['rows'], flush=True)
        if types[f] not in shot_done:
            shot_done.add(types[f]); Image.fromarray(img).save(os.path.join(out, 'type%d_f%d.png' % (types[f], f)))
    os.remove(tmp)
    json.dump(res, open(os.path.join(out, 'formations.json'), 'w'))


if __name__ == '__main__':
    main()
