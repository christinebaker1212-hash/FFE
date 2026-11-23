"""nesbattle.py ID OUT.png "F F F" [PRESSES] [--dump F:FILE]: the NES (build/ff3/cave.state, the
English ROM) starting battle ID from the field (FF3 $6A = id, $AB = $20 as a random battle sets
them): screenshots at frames F, and with --dump the 2 KB work RAM + 8 KB cart RAM at frame F
(FILE.ram / FILE.sram). PRESSES: F:KEYS:HOLD (R L D U S E B A). Reference for the native battle;
nothing of it is kept."""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'build', 'emu3'))
from cynes import NES
import numpy as np
from PIL import Image

RAM = 0x500A                            # offsets in a cynes state
SRAM = 0x23E2
BITS = {'R': 1, 'L': 2, 'D': 4, 'U': 8, 'S': 16, 'E': 32, 'B': 64, 'A': 128}


def run(bid, shots, presses=(), dumps=(), pokes=()):
    n = NES(os.path.join(ROOT, 'build', 'ff3_en.nes'))
    st = bytearray(open(os.path.join(ROOT, 'build', 'ff3', 'cave.state'), 'rb').read())
    st[RAM + 0x6A] = bid; st[RAM + 0xAB] = 0x20
    for a, v in pokes:
        if a < 0x800: st[RAM + a] = v
        else: st[SRAM + a - 0x6000] = v
    n.load(np.array(st, dtype=np.uint8))
    ims, out = [], {}
    last = max(list(shots) + [f for f, _ in dumps] + [0])
    for f in range(last + 1):
        c = 0
        for a, k, h in presses:
            if a <= f < a + h: c |= k
        n.controller = c
        fr = n.step(1)
        if f in shots: ims.append(Image.fromarray(fr.copy()))
        for df, name in dumps:
            if df == f:
                s = bytes(n.save())
                out[name] = (s[RAM:RAM + 0x800], s[SRAM:SRAM + 0x2000])
    return ims, out


if __name__ == '__main__':
    args = sys.argv[1:]
    dumps = []
    while '--dump' in args:
        i = args.index('--dump'); f, name = args[i + 1].split(':'); dumps.append((int(f), name)); del args[i:i + 2]
    bid, outp, shots = int(args[0], 0), args[1], [int(x) for x in args[2].split()]
    pr = []
    for p in (args[3].split() if len(args) > 3 else []):
        f, k, h = p.split(':'); pr.append((int(f), sum(BITS[c] for c in k), int(h)))
    ims, out = run(bid, shots, pr, dumps)
    for name, (ram, sram) in out.items():
        open(name + '.ram', 'wb').write(ram); open(name + '.sram', 'wb').write(sram)
    sh = Image.new('RGB', (4 * 260, ((len(ims) + 3) // 4) * 244))
    for i, im in enumerate(ims): sh.paste(im, ((i % 4) * 260, (i // 4) * 244))
    sh.save(outp)
