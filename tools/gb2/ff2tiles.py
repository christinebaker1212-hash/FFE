"""FF2 battle tile survey (NES, cynes PPU_LOG): for each forced formation (ff2form.py), the
pattern-table writes ($0000-$1FFF, per 16-byte tile) and nametable writes ($2000-$2FFF)
during the first FRAMES frames of the battle; reports, over all formations, which tiles of
each pattern table are loaded and which tiles the battle's nametables reference.
usage: PYTHONPATH=build/emu ff2tiles.py NES OUTDIR [IDS 0-127] [FRAMES 400]"""
import os, sys, subprocess, pickle
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb')); sys.path.insert(0, HERE)


def child(rom, state, frames, steps_start):
    from cynes import NES
    import firstdiff as fd, ff2form as F
    import numpy as np
    st = np.load(state)
    steps = fd.script_newgame(steps_start + frames + 1); fd.add_random(steps, 1)
    m = NES(rom); m.load(st)
    for f in range(steps_start, steps_start + frames): m.controller = steps[f]; m.step(1)


def main():
    if sys.argv[1] == '--child':
        child(sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])); return
    nes_path, out = sys.argv[1], sys.argv[2]
    lo, hi = (0, 127) if len(sys.argv) < 4 else map(int, sys.argv[3].split('-'))
    frames = int(sys.argv[4]) if len(sys.argv) > 4 else 400
    os.makedirs(out, exist_ok=True)
    from cynes import NES
    import firstdiff as fd, ff2form as F
    import numpy as np
    steps = fd.script_newgame(F.START + 1); fd.add_random(steps, 1)
    n = NES(nes_path)
    for f in range(F.START): n.controller = steps[f]; n.step(1)
    state = os.path.join(out, 'state.npy'); np.save(state, n.save())
    rom = open(nes_path, 'rb').read()
    res = {}
    for bid in range(lo, hi + 1):
        p = os.path.join(out, 'f%d.nes' % bid); open(p, 'wb').write(F.patched(rom, bid))
        env = dict(os.environ, PPU_LOG='1')
        r = subprocess.run([sys.executable, __file__, '--child', p, state, str(frames), str(F.START)],
                           env=env, capture_output=True, text=True)
        os.remove(p)
        chr_w = [set(), set()]; nt = {}
        for l in r.stderr.splitlines():
            if not l.startswith('P '): continue
            a, v = int(l[2:6], 16), int(l[7:9], 16)
            if a < 0x2000: chr_w[a >> 12].add((a & 0xFFF) >> 4)
            elif a < 0x3000 and (a & 0x3FF) < 0x3C0: nt[a] = v
        res[bid] = (chr_w, nt)
        field = {v for a, v in nt.items() if a < 0x2400 and 2 <= ((a & 0x3FF) >> 5) < 18}   # rows 2-17
        menu = {v for a, v in nt.items() if ((a & 0x3FF) >> 5) >= 18}
        print(bid, 'battlefield rows 2-17 use %d tiles (%02X-%02X)' % (len(field), min(field), max(field)),
              '| menu rows 18+ use %d' % len(menu), flush=True)
    pickle.dump(res, open(os.path.join(out, 'tiles_%d_%d.pkl' % (lo, hi)), 'wb'))
    used = set()
    for bid, (cw, nt) in res.items():
        used |= {v for a, v in nt.items() if a < 0x2400 and ((a & 0x3FF) >> 5) < 18}
    free = [t for t in range(256) if t not in used]
    print('table-1 tiles never on the battlefield (rows 0-17, nametable 0):', len(free),
          ' '.join('%02X' % t for t in free))


if __name__ == '__main__':
    main()
