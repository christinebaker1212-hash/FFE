"""RAM equivalence of the FF3 GBC build against the English NES build, frame by frame.

usage: PYTHONPATH=build/emu3 firstdiff.py NES GB FRAMES [--input NAME] [--from K] [--max N]
              [--ignore LO-HI,..]

The NES (cynes) and the GB (PyBoy, CGB mode) run with the same input (tools/gb3/cmpshots.py
INPUTS, one pad byte per counted frame). Counted frames are NMIs taken while the RAM NMI
vector $0100 holds a JMP (cmpshots.Waits); the GB counts the same (NMI_CNT $D830):
  - synchronous waits ($FF36): NES RAM at the NMI = the state at the wait; GB: entry of
    wait_vbl (NMI_CNT = k - 1 there);
  - asynchronous NMIs (battle, cutscenes): NES RAM when the NMI was taken; GB: the safe
    point where rt_async runs the handler (rt_async.c, NMI_CNT = k).
NES RAM $0000-$07FF is compared with GB $C000-$C7FF (the GB keeps its own stack out of it),
except $0100-$0102 (the wait's NMI stub) and the NES stack $0162-$01FF.
Prints the first frames with differences (address, NES, GB)."""
import sys, os, argparse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from cmpshots import INPUTS, Waits
from cynes import NES
from pyboy import PyBoy

def sym(path):
    s = {}
    for l in open(path):
        if l.startswith(';') or ':' not in l: continue
        a, n = l.split()
        b, o = a.split(':'); s[n] = (int(b, 16), int(o, 16))
    return s

def gb_order(v):                        # NES pad (bit 0 Right .. 7 A) -> runtime (bit 0 A .. 7 Right)
    r = 0
    for b in range(8):
        if v & (1 << b): r |= 0x80 >> b
    return r

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('nes'); ap.add_argument('gb'); ap.add_argument('frames', type=int)
    ap.add_argument('--input', default='none'); ap.add_argument('--from', dest='frm', type=int, default=0)
    ap.add_argument('--max', type=int, default=5); ap.add_argument('--ignore', default='')
    ap.add_argument('--show', default='', help='LO-HI: print these RAM bytes of both every frame')
    a = ap.parse_args()
    a.show = tuple(int(v, 16) for v in a.show.split('-')) if a.show else None
    pad = INPUTS[a.input]
    # (the synchronous wait's NMI stub at $0100-$0102, replaced natively on the GB, and the
    # NES stack $0162-$01FF: the GB stack is elsewhere)
    ign = set(range(0x100, 0x103)) | set(range(0x162, 0x200))
    for r in [x for x in a.ignore.split(',') if x]:
        lo, hi = (int(v, 16) for v in r.split('-')); ign |= set(range(lo, hi + 1))
    # NES: RAM at each counted frame
    n = NES(a.nes); W = Waits(n); nes_ram = {}; k = 0; f = 0; latched = {}
    sram0 = bytes(n[0x6000 + i] for i in range(0x2000))   # power-on save RAM (the game reads
                                                         #   unwritten save RAM: copied to the GB)
    while k < a.frames and f < a.frames * 4 + 1000:
        c = pad(k + 1)
        n.controller = c
        n.step(1); f += 1
        k2 = W.update(c)
        if k2 != k:
            k = k2
            if k >= a.frm: nes_ram[k] = bytes(n.nmi_ram)
    print('NES: %d counted frames in %d NES frames' % (k, f))
    # GB
    S = sym(os.path.splitext(a.gb)[0] + '.sym')
    pb = PyBoy(a.gb, window='null', cgb=True)
    m = pb.memory
    st = {'diffs': 0, 'checked': 0, 'last': 0}

    def feed(kk):
        m[0xD83E] = 0xA5
        for j in range(kk, kk + 40):                 # slot j: the NES's latch after frame j
            v = W.latch.get(j)
            if v is None: v = W.latch.get(j - 1, 0)
            m[3, 0xA000 + (j & 0xFF)] = gb_order(v)

    def check(kk):
        st['last'] = kk
        feed(kk)
        if kk not in nes_ram: return
        st['checked'] += 1
        g = bytes(m[0xC000 + i] for i in range(0x800))
        d = [i for i in range(0x800) if g[i] != nes_ram[kk][i] and i not in ign]
        if a.show:
            lo, hi = a.show
            print('frame %d NES %s | GB %s' % (kk, nes_ram[kk][lo:hi + 1].hex(), g[lo:hi + 1].hex()))
        if d and st['diffs'] < a.max:
            st['diffs'] += 1
            print('frame %d: %d bytes differ: %s' % (kk, len(d), ' '.join(
                '%04X:%02X/%02X' % (i, nes_ram[kk][i], g[i]) for i in d[:24])))

    def on_wait(ctx):
        check((m[0xD830] | m[0xD831] << 8) + 1)
    def on_async(ctx):
        check(m[0xD830] | m[0xD831] << 8)
    pb.hook_register(*S['wait_vbl'], on_wait, None)
    pb.hook_register(*S['rt_async.c'], on_async, None)
    for i in range(0x2000): m[0, 0xA000 + i] = sram0[i]
    feed(0)
    t = 0
    while st['last'] < k and t < a.frames * 6 + 2000:
        pb.tick(1, False); t += 1
        if st['diffs'] >= a.max: break
    dbg = [m[0xD820 + i] for i in range(8)]
    print('GB: %d GB frames, reached frame %d, %d frames compared, %d with differences; DBG %s'
          % (t, st['last'], st['checked'], st['diffs'], ' '.join('%02X' % x for x in dbg)))
    pb.stop(save=False)

if __name__ == '__main__':
    main()
