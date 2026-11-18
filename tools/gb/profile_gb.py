"""Statistical profile of a GB build: sample PC at every frame boundary while playing
the new-game script; reports busy frames by NES routine (nearest L_ label) and runtime routine.
usage: profile_gb.py ROM.gb [FRAMES]"""
import sys, bisect
from collections import Counter
from pyboy import PyBoy
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from compare import new_game_script, GBNAME


def main():
    rom = sys.argv[1]
    sy = []
    for l in open(rom[:-3] + '.sym'):
        b, rest = l.split(':'); a, n = rest.split()
        sy.append((int(b, 16), int(a, 16), n))
    by_bank = {}
    for b, a, n in sy: by_bank.setdefault(b, []).append((a, n))
    for b in by_bank: by_bank[b].sort()

    def name(bank, pc):
        lst = by_bank.get(0 if pc < 0x4000 else bank, [])
        i = bisect.bisect_right([a for a, _ in lst], pc) - 1
        return lst[i][1].split('.')[0] if i >= 0 else '?'
    pb = PyBoy(rom, window='null', cgb=__import__('os').environ.get('GB_CGB') == '1', sound_emulated=False)
    pb.set_emulation_speed(0)
    wait_lo = [a for b, a, n in sy if n == 'rt_wait_nmi'][0]
    held = 0; total = 0; rows = []; c = Counter()
    rd = lambda a: pb.memory[a] | pb.memory[a + 1] << 8
    last = (0, 0)
    script = new_game_script()
    if '--random' in sys.argv:
        import random
        from compare import UP, DOWN, LEFT, RIGHT, A, B, START
        r = random.Random(int(sys.argv[sys.argv.index('--random') + 1]))
        btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT]
        for _ in range(int(sys.argv[sys.argv.index('--random') + 2])):
            script.append((r.choice(btns), r.randint(2, 40), r.randint(1, 20)))
    for k, it in enumerate(script):
        if it[0] == 'shot': continue
        m, hold, after = it
        for phase, n in ((m, hold), (0, after)):
            for bit, nm in GBNAME.items():
                if phase & bit and not held & bit: pb.button_press(nm)
                if not phase & bit and held & bit: pb.button_release(nm)
            held = phase
            for _ in range(n):
                n0 = rd(0xD830)
                pb.tick(); total += 1
                if rd(0xD830) == n0:                 # no NES frame ended: a long computation
                    pc = pb.register_file.PC
                    nm = name(pb.memory[0xFF80 + 12], pc)
                    c[nm] += 1
                    if nm.startswith('L_'): c['space ' + nm[2:5]] += 1
        cur = (rd(0xD830), rd(0xD832))
        dn, dv = cur[0] - last[0], cur[1] - last[1]
        rows.append((k, total, dn, dv)); last = cur
    if '--quiet' not in sys.argv:
        for k, t, dn, dv in rows:
            print('step %3d frame %5d: NES frames %4d in %4d GB frames (%.2fx)' % (k, t, dn, dv, dv / dn if dn else 0))
    tn = sum(r[2] for r in rows); tv = sum(r[3] for r in rows)
    print('total: %d NES frames in %d GB frames (%.2fx)' % (tn, tv, tv / tn))
    print('PC samples in frames without a NES frame end:', sum(v for k, v in c.items() if not k.startswith('space')))
    for k, v in c.most_common(30): print('  %5d  %s' % (v, k))


if __name__ == '__main__':
    main()
