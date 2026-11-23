"""btlcmp.py ID [NES_FRAME] [GB_FRAME]: the native battle against the NES with the same party and
the same random seed. The NES (build/ff3/cave.state, nesbattle.py) starts battle ID; its battle
random table ($7BE3) gives its seed (FF3's generator, fix:FC27, run for every seed); the native
build (build/ff3n_w.gbc: a world map test start) gets the NES's save block ($6000-$63FF), the
seed (test hook btl_seedf / btl_seedv) and the battle (act $20). Then FF3's battle RAM regions
are compared. Reference only: nothing of the ROM is kept."""
import sys, os, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..', '..')
spec = importlib.util.spec_from_file_location('nb', os.path.join(HERE, 'nesbattle.py'))
nb = importlib.util.module_from_spec(spec); spec.loader.exec_module(nb)

REGIONS = [('char props', 0x7575, 0x7675), ('monster props', 0x7675, 0x7875), ('monster set', 0x7D67, 0x7D7C),
           ('slots', 0x7DA7, 0x7DB7), ('remaining', 0x7DCE, 0x7DD3), ('palettes', 0x7CF7, 0x7D17),
           ('attributes', 0x7D17, 0x7D67), ('rng table', 0x7BE3, 0x7CE3), ('battle type', 0x78BA, 0x78BB),
           ('status disp', 0x78BB, 0x78C8), ('flags', 0x7ED8, 0x7ED9)]


def table(seed):
    """FFC27 for a seed: the 256-byte table"""
    x = 1
    out = []
    m22 = (seed & 2) + 3
    for y in range(256):
        p = (m22 * x) & 0xFFFFFFFF
        num = p & 0xFFFF
        q, r = (num // 0x400, num % 0x400) if num else (0, 0)
        if not (((r >> 8) - 2) & 0xFF | (r & 0xFF)) == 0 and (r >> 8) >= 2:
            r = (0x400 - r) & 0xFFFF
        x = r
        out.append((r >> 1) & 0xFF)
    return bytes(out)


SEED = 0


def main():
    global SEED
    bid = int(sys.argv[1], 0)
    nf = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    gf = int(sys.argv[3]) if len(sys.argv) > 3 else 330
    st = open(os.path.join(ROOT, 'build', 'ff3', 'cave.state'), 'rb').read()
    sram0 = st[nb.SRAM:nb.SRAM + 0x2000]
    _, out = nb.run(bid, [], [], [(nf, 'd')])
    ram, sram = out['d']
    nes_t = sram[0x1BE3:0x1CE3]
    seeds = [s for s in range(256) if table(s) == nes_t]
    # the counters ($15-$17) start at the seed: with the same uses on both sides the seed is the
    # NES counter minus the uses (found by a first native run with seed 0)
    nes_c = ram[0x15:0x18]
    print('NES seed candidates', len(seeds), 'NES counters', nes_c.hex())
    SEED = 0
    g = native(bid, gf, sram0, seeds)
    uses = [g[0][0x15 + k] for k in range(3)]
    cand = [(nes_c[0] - uses[0]) & 0xFF]
    if cand[0] in seeds:
        SEED = cand[0]
    else:
        print('seed from the counters not a table seed:', cand, '(counters', bytes(uses).hex(), ')')
    print('seed', SEED)
    zp, w = native(bid, gf, sram0, seeds)
    report(sram, ram, zp, w)


def native(bid, gf, sram0, seeds):
    from pyboy import PyBoy
    rom = os.path.join(ROOT, 'build', 'ff3n_w.gbc')
    sym = {}
    for l in open(rom[:-4] + '.sym'):
        p = l.split()
        if len(p) == 2: sym[p[1]] = int(p[0].split(':')[1], 16)
    pb = PyBoy(rom, window='null', cgb=True)
    m = pb.memory
    for f in range(gf):
        if f == 100: pb.button('right', 3)
        if f == 103:
            for i in range(0x400): m[0xC800 + i] = sram0[i]
            if True:
                m[sym['btl_seedf']] = 0xA5; m[sym['btl_seedv']] = SEED
        if f == 104: m[sym['act_id']] = bid; m[sym['act']] = 0x20
        pb.tick()
    m[0xFF70] = 3
    zp = bytes(m[0xD000:0xD100]); w = bytes(m[0xD200:0xDF00]); gsb = bytes(m[0xC800:0xCC00])
    pb.stop(save=False)
    return zp, (w, gsb)


def report(sram, ram, zp, wg):
    w, gsb = wg
    bad = 0
    for name, a, b in REGIONS:
        n = sram[a - 0x6000:b - 0x6000]; g = w[a - 0x7200:b - 0x7200]
        d = [i for i in range(len(n)) if n[i] != g[i]]
        print('%-14s %s' % (name, 'identical' if not d else 'differ at ' + ' '.join('$%04X(%02X/%02X)' % (a + i, n[i], g[i]) for i in d[:10])))
        bad += bool(d)
    gs = [i for i in range(0x100, 0x300) if sram[i] != gsb[i]]
    print('save block $6100-$62FF', 'identical' if not gs else 'differ at ' + ' '.join('$%04X' % (0x6000 + i) for i in gs[:12]))


if __name__ == '__main__':
    main()
