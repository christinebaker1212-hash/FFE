"""Lockstep FF2 NES/GB check: report the first frame wait where NES RAM differs from GB RAM.

FF2's NMI fires every frame (an RTI at $0100 when nothing waits), so NMIs are not frame
waits. A *wait NMI* is one taken while $0100 holds JMP $FA3C / JMP $FEA1 (the waits
fix:FA2A / fix:FEAD); NES RAM at wait NMI w (cynes nmi_ram) is compared with GB RAM on
entering frame wait w (rt_frame; GB count at $D830). Page 1 (stack) is excluded. The GB
gets the pad the NES latched before each wait NMI, at its joypad read (feed_pads).
usage: PYTHONPATH=build/emu firstdiff.py NES GB [FRAMES] [--random SEED] [--script S]
  --script: newgame (default: power-on, Start through the prologue, New Game, names)
  --shots F1,F2.. --out SHEET.png: GB screens after those NES frames
Work RAM $6000-$7FFF (cart RAM bank 0 on the GB) is compared every WRAM_EVERY waits."""
import sys, os, random
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from compare import GB, sync_sram, UP, DOWN, LEFT, RIGHT, A, B, START
from cynes import NES

WRAM_EVERY = 50
WAIT_STUBS = {(0x4C, 0x3C, 0xFA), (0x4C, 0xA1, 0xFE)}


def script_newgame(n):
    """NES frame -> pad: Start at 2960 (prologue), A at 3360 (load menu: New Game), then A
    every 60 frames (name entry etc.)"""
    pads = [0] * n
    def press(f, m, h=5):
        for k in range(f, min(f + h, n)): pads[k] = m
    press(2960, START)
    for f in range(3360, n, 60): press(f, A)
    return pads


def main():
    args = sys.argv[1:]
    def opt(name, default=None, conv=str):
        if name in args:
            k = args.index(name); v = conv(args[k + 1]); del args[k:k + 2]; return v
        return default
    rnd = opt('--random', None, int)
    shots_at = {int(x) for x in opt('--shots', '').split(',') if x}
    out = opt('--out')
    nes = NES(args[0]); gb = GB(args[1]); sync_sram(nes, gb)
    limit = int(args[2]) if len(args) > 2 else 6000
    steps = script_newgame(limit)
    if rnd is not None:
        r = random.Random(rnd); start = 4000
        btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT]
        k = start
        while k < limit:
            m = r.choice(btns); h = r.randint(2, 40); g = r.randint(1, 20)
            for j in range(k, min(k + h, limit)): steps[j] = m
            for j in range(k + h, min(k + h + g, limit)): steps[j] = 0
            k += h + g
    sym = {}
    for l in open(args[1][:-3] + '.sym'):
        b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
    # 1. NES alone: RAM and latched pad at each wait NMI. One cynes step can take two
    # NMIs and nmi_ram keeps only the last, so NES RAM is rebuilt from the logged writes
    # (watch $0000-$07FF) and taken at the stub's write of RTI to $0100 after a wait's
    # JMP (= RAM at the NMI; the stub writes nothing before it).
    nes_ram, pads, frame_of, shot_w = {}, {}, {}, []
    shadow = bytearray(nes[k] if k < 0x800 or k >= 0x6000 else 0 for k in range(0x8000))
    nes.watch = (0, 0x8000)
    wram = {}                                      # work RAM $6000-$7FFF every WRAM_EVERY waits
    # The pad: what the game read (the 8th ROL $20 of its joypad loop at fix:DBBC), fed
    # to the GB at its read after the same wait.
    ROL20 = 31 * 0x4000 + 0xDBBC - 0xC000          # coverage index of that instruction
    w = 0; nrol = 0
    for f in range(limit):
        nes.controller = steps[f]
        nes.step(1)
        for ix, a, v in nes.watch:
            if a == 0x100 and v == 0x40 and (shadow[0x100], shadow[0x101], shadow[0x102]) in WAIT_STUBS:
                w += 1; nrol = 0
                nes_ram[w] = bytes(shadow[:0x800]); frame_of[w] = f
                if w % WRAM_EVERY == 0: wram[w] = bytes(shadow[0x6000:0x8000])
            if a == 0x20:
                nrol = nrol + 1 if ix == ROL20 else 0
                if nrol == 8: pads[w + 1] = v; nrol = 0
            if a < 0x2000: shadow[a & 0x7FF] = v
            elif a >= 0x6000: shadow[a] = v
        if f in shots_at: shot_w.append(w)
    last = w
    print('NES: %d frames, %d NMIs, %d wait NMIs' % (limit, nes.nmi_count, last))
    # 2. GB with those pads
    state = {'diff': None, 'k': 0}
    def on_wait(_):
        m = gb.pb.memory
        k = (m[0xD830] | m[0xD831] << 8) + 1
        state['k'] = k
        if state['diff'] is not None or k not in nes_ram: return
        a = nes_ram[k]; b = bytes(m[0xC000 + i] for i in range(0x800))
        d = [i for i in range(0x800) if a[i] != b[i] and not 0x100 <= i < 0x200]
        if d:
            state['diff'] = 'NES frame %d, wait %d: %s' % (frame_of[k], k, ' '.join(
                '%03X:%02X/%02X' % (i, a[i], b[i]) for i in d[:16]))
        elif k in wram:
            x = wram[k]; y = bytes(m[0, 0xA000 + i] for i in range(0x2000))
            d = [i for i in range(0x2000) if x[i] != y[i]]
            if d:
                state['diff'] = 'NES frame %d, wait %d, work RAM: %s' % (frame_of[k], k, ' '.join(
                    '%04X:%02X/%02X' % (0x6000 + i, x[i], y[i]) for i in d[:16]))
    gb.pb.hook_register(*sym['rt_frame'], on_wait, None)
    gb.feed_pads(sym, lambda n: pads.get(n + 1, 0))
    shots = []; guard = 0; prev = 0
    while state['k'] < last and state['diff'] is None:
        gb.pb.tick(); guard += 1
        if state['k'] != prev: prev, guard = state['k'], 0
        if guard > 2000: raise SystemExit('GB stuck before wait %d' % (state['k'] + 1))
        while shot_w and state['k'] >= shot_w[0]:
            shots.append(gb.image()); shot_w.pop(0)
    print(state['diff'] or 'no difference in %d frame waits (NES frames 0-%d)' % (last, limit))
    if shots and out:
        from PIL import Image
        sheet = Image.new('RGB', (164 * min(len(shots), 6), 148 * ((len(shots) + 5) // 6)), 'white')
        for i, g in enumerate(shots): sheet.paste(g, ((i % 6) * 164, (i // 6) * 148))
        sheet.save(out); print('saved', out)


if __name__ == '__main__':
    main()
