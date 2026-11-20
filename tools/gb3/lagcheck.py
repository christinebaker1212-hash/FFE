"""Speed of the FF3 GBC build against the NES: real frames between waited-for frames.

usage: PYTHONPATH=build/emu3 lagcheck.py NES GB FROM TO [--input NAME] [--step N] [--jump J]
                                         [--frames F]

The NES (cynes, build/emu3) runs the input script (tools/gb3/cmpshots.py INPUTS) and records
the pad it latched in each input frame and the NES frame at which each waited-for frame
(ff3_waits) first comes. The GB runs in mGBA (build/sgbrun, CGB double speed) with those
pads in test mode; at every input frame FROM..TO (step N) the runtime's counters are read
(NMI_CNT, VBL_CNT, WAIT_CNT). For each waited-for frame w reached on both: lead = GB real
frames - NES real frames since the first such w. Printed: every change of the lead by J or
more (default 2) and the lead every 50 waited-for frames; at the end the total.
A positive lead = the GB is behind. (A scripted button press that comes before the GB's menu
is ready waits for the next press: a jump of up to 16 frames there is the script, not speed.)
"""
import sys, os, argparse, subprocess, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
from cmpshots import INPUTS, Waits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('nes'); ap.add_argument('gb')
    ap.add_argument('frm', type=int); ap.add_argument('to', type=int)
    ap.add_argument('--input', default='newgame'); ap.add_argument('--step', type=int, default=1)
    ap.add_argument('--jump', type=int, default=2)
    ap.add_argument('--frames', type=int, default=0, help='GB frames to run (default: TO * 1.25)')
    ap.add_argument('--resync', action='store_true', help='set the GB input clock to the NES\'s at '
                    'each waited-for frame (sgbrun SGBRUN_CLOCK), for scripts that steer by game state')
    a = ap.parse_args()
    from cynes import NES
    pad = INPUTS[a.input]
    n = NES(a.nes); W = Waits(n); k = 0; f = 0; nesw = {}
    import cmpshots; cmpshots.CUR_NES = n
    clock = {}
    while k < a.to + 200 and f < (a.to + 200) * 4:
        n.controller = pad(k + 1); n.step(1); f += 1; k = W.update()
        nesw.setdefault(n.ff3_waits, f)
        clock.setdefault(n.ff3_waits, k)
    tmp = tempfile.mkdtemp(prefix='lagcheck')
    try:
        pads = os.path.join(tmp, 'pads.bin')
        # (sgbrun puts file byte k + 1 in test-mode slot k; slot k must hold the NES's latch
        #  after frame k, as firstdiff.py feeds it)
        open(pads, 'wb').write(bytes(W.latch.get(j - 1, W.latch.get(j - 2, 0)) for j in range(a.to + 200)))
        cmd = [os.path.join(ROOT, 'build', 'sgbrun'), a.gb, str(a.frames or int(a.to * 1.25) + 600),
               os.path.join(tmp, 'q'), '--cgb', '--padfile', pads]
        for j in range(a.frm, a.to + 1, a.step): cmd += ['--nshot', str(j)]
        env = dict(os.environ, SGBRUN_PEEK='D830')
        if a.resync:
            import struct
            cf = os.path.join(tmp, 'clock.bin')
            top = max(clock) + 1
            open(cf, 'wb').write(b''.join(struct.pack('<H', clock.get(w, 0) & 0xFFFF) for w in range(top)))
            env['SGBRUN_CLOCK'] = cf
        out = subprocess.run(cmd, env=env, capture_output=True, text=True).stdout + ''
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    gbw = {}
    for l in out.splitlines():
        if not l.startswith('peek'): continue
        p = l.split(); b = [int(x, 16) for x in p[3:9]]
        w = b[4] | b[5] << 8
        if w: gbw.setdefault(w, (int(p[1]), b[2] | b[3] << 8))
    ws = sorted(w for w in gbw if w in nesw)
    if not ws: raise SystemExit('no waited-for frames in range')
    g0 = gbw[ws[0]][1]; f0 = nesw[ws[0]]; last = 0; blk = None
    print('waited  GB input  lead  (GB real frames - NES real frames since waited-for %d)' % ws[0])
    for w in ws:
        lead = (gbw[w][1] - g0) - (nesw[w] - f0)
        if abs(lead - last) >= a.jump or w // 50 != blk:
            print('%6d  %8d  %+5d  (%+d)' % (w, gbw[w][0], lead, lead - last))
            blk = w // 50
        last = lead
    w = ws[-1]
    print('total: waited %d-%d: GB %d frames, NES %d frames (%+.1f%%)' % (
        ws[0], w, gbw[w][1] - g0, nesw[w] - f0,
        100.0 * ((gbw[w][1] - g0) / max(1, nesw[w] - f0) - 1)))


if __name__ == '__main__':
    main()
