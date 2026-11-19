"""Frame pacing of the FF2 GB build against the NES (Gambatte, hardware-like timing).

For each window of NES frame waits (wait NMIs, see firstdiff.py), the NES's video frames
between the waits are compared with the GB's video frames between the same waits. A GB
that keeps pace takes exactly as many; extra GB frames are lag (the game slower, music
stretched). Input: firstdiff.py's scripts (new game, optional random play).
usage: PYTHONPATH=build/emu lagcheck.py NES GB FRAMES [--random SEED] [--dmg] [--win 60]"""
import os, sys, subprocess, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
sys.path.insert(0, HERE)
from cynes import NES
import firstdiff as fd


def main():
    args = sys.argv[1:]
    def opt(name, default=None, flag=False):
        if name not in args: return default
        k = args.index(name)
        if flag: del args[k]; return True
        v = args[k + 1]; del args[k:k + 2]; return v
    dmg = opt('--dmg', flag=True); win = int(opt('--win', '60')); rnd = opt('--random')
    nes_path, gb_path, limit = args[0], args[1], int(args[2])
    steps = fd.script_newgame(limit)
    if rnd is not None: fd.add_random(steps, int(rnd))
    nes_ram, pads, frame_of, wram, _ = fd.nes_pass(NES(nes_path), steps, limit)
    last = max(frame_of)
    tmp = tempfile.mkdtemp()
    pf = os.path.join(tmp, 'pads.bin'); lf = os.path.join(tmp, 'lag.bin')
    # gbrun's test-input mode: the read after GB wait n gets pads file byte n
    open(pf, 'wb').write(bytes(pads.get(n + 1, 0) for n in range(last + 2)))
    gbrun = os.path.join(HERE, '..', '..', 'build', 'gbrun')
    cmd = [gbrun, gb_path, str(limit * 3), os.path.join(tmp, 'x'), '--padfile', pf, '--lagfile', lf,
           '--nshot', str(last)] + (['--dmg'] if dmg else [])
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    lag = open(lf, 'rb').read()
    waits = [lag[i] | lag[i + 1] << 8 for i in range(0, len(lag), 2)]   # wait count after each GB frame
    gb_at = {}                                                        # GB frame when wait k was
    top = 0                                                           #   reached (several waits
    for g, k in enumerate(waits):                                     #   can pass in one GB frame)
        while top < k:
            top += 1; gb_at[top] = g + 1
    print(out.strip())
    tot_n = tot_g = 0; worst = []
    for a in range(1, last - win, win):
        b = a + win
        if a not in gb_at or b not in gb_at: break
        n = frame_of[b] - frame_of[a]; g = gb_at[b] - gb_at[a]
        tot_n += n; tot_g += g
        print('waits %5d-%5d (NES frames %6d-%6d): NES %4d  GB %4d  lag %+d' % (a, b, frame_of[a], frame_of[b], n, g, g - n))
    for k in range(2, last):
        if k in gb_at and k - 1 in gb_at:
            worst.append(((gb_at[k] - gb_at[k - 1]) - (frame_of[k] - frame_of[k - 1]), k))
    worst.sort(reverse=True)
    print('total: NES %d frames, GB %d frames (%+.1f%%)' % (tot_n, tot_g, 100.0 * (tot_g - tot_n) / max(1, tot_n)))
    print('worst single waits (lag, wait, NES frame):', ', '.join('%+d@%d(f%d)' % (l, k, frame_of[k]) for l, k in worst[:10]))


if __name__ == '__main__':
    main()
