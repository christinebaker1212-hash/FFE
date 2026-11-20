"""RAM equivalence of the FF3 GBC build against the English NES build, frame by frame.

usage: PYTHONPATH=build/emu3 firstdiff.py NES GB FRAMES [--input NAME] [--from K] [--max N]
              [--ignore LO-HI,..]

The NES (cynes, build/emu3) and the GB (PyBoy, CGB mode) run with the same input
(tools/gb3/cmpshots.py INPUTS). Two clocks, counted the same way on both:
  - input frames (NES nmi_count, GB NMI_CNT $D830): NMIs through JMP $FF2A (a wait) or
    JMP $FB57 (the battle / cutscene handler) in the RAM vector $0100; the GB reads the
    pad the NES latched in the same frame (pad_history; test-mode slots);
  - waited-for frames (NES ff3_waits, GB WAIT_CNT $D834): the equivalence points, where
    the main thread waits ($FF36, or the $FB80 loop for the asynchronous handler). NES
    RAM at that NMI; GB at wait_vbl entry (WAIT_CNT = k - 1) or where rt_wait_nmi runs the
    handler (rt_async.cnt, WAIT_CNT = k).
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
    ap.add_argument('--sram', default='', help='LO-HI: compare this PRG-RAM range ($6000-$7FFF) '
                    'at the end of both runs (for data that stays put, e.g. the battle rng table)')
    a = ap.parse_args()
    a.show = tuple(int(v, 16) for v in a.show.split('-')) if a.show else None
    pad = INPUTS[a.input]
    # (the synchronous wait's NMI stub at $0100-$0102, replaced natively on the GB, and the
    # NES stack $0162-$01FF: the GB stack is elsewhere)
    ign = set(range(0x100, 0x103)) | set(range(0x162, 0x200))
    for r in [x for x in a.ignore.split(',') if x]:
        lo, hi = (int(v, 16) for v in r.split('-')); ign |= set(range(lo, hi + 1))
    # NES: RAM at each counted frame
    n = NES(a.nes); W = Waits(n); nes_ram = {}; k = 0; f = 0; latched = {}; wk = 0; nes_clock = {}
    import cmpshots; cmpshots.CUR_NES = n
    sram0 = bytes(n[0x6000 + i] for i in range(0x2000))   # power-on save RAM (the game reads
                                                         #   unwritten save RAM: copied to the GB)
    while k < a.frames and f < a.frames * 4 + 1000:
        c = pad(k + 1)
        n.controller = c
        n.step(1); f += 1
        k = W.update(c)
        w2 = n.ff3_waits
        if w2 != wk:
            wk = w2
            nes_clock[wk] = k
            if wk >= a.frm: nes_ram[wk] = bytes(n.nmi_ram)
    print('NES: %d frames (input clock), %d waited-for frames, in %d NES frames' % (k, wk, f))
    nes_sram = bytes(n[0x6000 + i] for i in range(0x2000))
    k = wk
    # GB
    S = sym(os.path.splitext(a.gb)[0] + '.sym')
    pb = PyBoy(a.gb, window='null', cgb=True)
    m = pb.memory
    st = {'diffs': 0, 'checked': 0, 'last': 0}

    def feed(kk):
        m[1, 0xD83E] = 0xA5
        for j in range(kk, kk + 40):                 # slot j: the NES's latch after frame j
            v = W.latch.get(j)
            if v is None: v = W.latch.get(j - 1, 0)
            m[3, 0xA000 + (j & 0xFF)] = gb_order(v)

    def check(kk, before=0):
        st['last'] = kk
        # (PyBoy runs the CGB at normal speed, so in the asynchronous phases more vblanks
        # pass per unit of game progress than on the NES or a real GBC: the GB's input clock
        # is set to the NES's at each equivalence point, so both read the same pads)
        c = nes_clock.get(kk)
        if c is not None:
            c -= before                          # (at a wait's entry its frame is not counted yet)
            m[1, 0xD830] = c & 0xFF; m[1, 0xD831] = c >> 8
            feed(c)
        if kk not in nes_ram: return
        st['checked'] += 1
        g = bytes(m[0xC000 + i] for i in range(0x800))
        d = [i for i in range(0x800) if g[i] != nes_ram[kk][i] and i not in ign]
        if a.show:
            lo, hi = a.show
            print('frame %d NES %s | GB %s   (GB input clock %d, NES %s)' % (kk, nes_ram[kk][lo:hi + 1].hex(),
                  g[lo:hi + 1].hex(), m[1, 0xD830] | m[1, 0xD831] << 8, nes_clock.get(kk)))
        if d and st['diffs'] < a.max:
            st['diffs'] += 1
            print('frame %d: %d bytes differ: %s' % (kk, len(d), ' '.join(
                '%04X:%02X/%02X' % (i, nes_ram[kk][i], g[i]) for i in d[:24])))

    def nmi(): return m[1, 0xD830] | m[1, 0xD831] << 8
    def waits(): return m[1, 0xD834] | m[1, 0xD835] << 8
    def on_wait(ctx):
        feed(nmi()); check(waits() + 1, 1)
    def on_async(ctx):
        check(waits())
    def on_frame(ctx):
        feed(nmi())
    pb.hook_register(*S['wait_vbl'], on_wait, None)
    pb.hook_register(*S['rt_async.cnt'], on_async, None)
    pb.hook_register(*S['rt_async.c'], on_frame, None)
    for i in range(0x2000): m[0, 0xA000 + i] = sram0[i]
    feed(0)
    t = 0
    while st['last'] < k and t < a.frames * 6 + 2000:
        pb.tick(1, False); t += 1
        if st['diffs'] >= a.max: break
    if a.sram:
        lo, hi = (int(v, 16) for v in a.sram.split('-'))
        d = [x for x in range(lo, hi + 1) if m[0, 0xA000 + x - 0x6000] != nes_sram[x - 0x6000]]
        print('PRG-RAM %04X-%04X at the end: %d bytes differ %s' % (lo, hi, len(d),
              ' '.join('%04X:%02X/%02X' % (x, nes_sram[x - 0x6000], m[0, 0xA000 + x - 0x6000]) for x in d[:16])))
    dbg = [m[1, 0xD820 + i] for i in range(8)]
    print('GB: %d GB frames, reached frame %d, %d frames compared, %d with differences; DBG %s'
          % (t, st['last'], st['checked'], st['diffs'], ' '.join('%02X' % x for x in dbg)))
    pb.stop(save=False)

if __name__ == '__main__':
    main()
