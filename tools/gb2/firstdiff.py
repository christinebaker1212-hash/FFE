"""Lockstep FF2 NES/GB check: report the first frame wait where NES RAM differs from GB RAM.

FF2's NMI fires every frame (an RTI at $0100 when nothing waits), so NMIs are not frame
waits. A *wait NMI* is one taken while $0100 holds JMP $FA3C / JMP $FEA1 (the waits
fix:FA2A / fix:FEAD); NES RAM at wait NMI w (cynes nmi_ram) is compared with GB RAM on
entering frame wait w (rt_frame; GB count at $D830). Page 1 (stack) is excluded. The GB
gets the pad the NES latched before each wait NMI, at its joypad read (feed_pads).
usage: PYTHONPATH=build/emu firstdiff.py NES GB [FRAMES] [--random SEED] [--script S]
  --script: newgame (default: power-on, Start through the prologue, New Game, names)
  --shots F1,F2.. --out SHEET.png: GB screens after those NES frames
  --strict: also compare the sound driver's RAM (SOUND)
  --form F: the opening battle shows battle F (ff2form.patched, NES and GB data banks)
  --press F:K,..: from the first F on, only these presses (K: A B U D L R S, 4 frames)
  --poke ADDR=VAL,..: RAM pokes at NES frame 9700 (the GB at the matching frame wait)
Work RAM $6000-$7FFF (cart RAM bank 0 on the GB) is compared every WRAM_EVERY waits."""
import sys, os, random
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from compare import GB, sync_sram, UP, DOWN, LEFT, RIGHT, A, B, START
from cynes import NES

# zero-page bytes where FF2 saves S (TSX / STX, later LDX / TXS: b14:919A -> 91FD): the GB
# runtime's S is its own stack depth (rt_tsx), exact only as a round trip, so a stack-like
# value (>= $C0 on both) there is not a difference
TSX_SAVES = {0x04}
WRAM_EVERY = int(os.environ.get('WRAM_EVERY', '50'))
# Sound-driver state (ram-map.txt): music runs in real time, and in the battle phases with
# an asynchronous NMI the GB ticks it at its own vblanks, so these may differ (not game
# logic; the song id $6F25 stays compared). --strict compares them too.
SOUND = set(range(0xB0, 0xF0)) | set(range(0x6F00, 0x6F25)) | set(range(0x6F26, 0x6F5E))   # + saved song state (b13:988E)
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


def add_random(steps, seed, start=4000):
    """random play from NES frame `start` on (held 2-40 frames, released 1-20)"""
    r = random.Random(seed); k = start; n = len(steps)
    btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT]
    while k < n:
        m = r.choice(btns); h = r.randint(2, 40); g = r.randint(1, 20)
        for j in range(k, min(k + h, n)): steps[j] = m
        for j in range(k + h, min(k + h + g, n)): steps[j] = 0
        k += h + g


def nes_pass(nes, steps, limit, shots_at=(), pokes=(), poke_frame=9700):
    """Run the NES build for `limit` frames with pad steps[f]; returns per wait NMI w:
    RAM, the pad the game read after it (w + 1), the NES frame, work RAM every
    WRAM_EVERY waits, and the wait reached at each frame in shots_at."""
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
    # The other joypad routine (fix:FC3E, menus) shifts the pad into $35 bit-reversed by
    # ROR $35 at fix:FC4B.
    ROL20 = 31 * 0x4000 + 0xDBBC - 0xC000          # coverage index of that instruction
    ROR35 = 31 * 0x4000 + 0xFC4B - 0xC000
    rev = [int('{:08b}'.format(i)[::-1], 2) for i in range(256)]
    w = 0; nrol = 0; nror = 0
    poke_wait = None
    for f in range(limit):
        if pokes and f == poke_frame:           # RAM pokes (the GB gets them at the same wait)
            for a, v in pokes:
                nes[a] = v
                if a < 0x800: shadow[a] = v
                elif a >= 0x6000: shadow[a] = v
            poke_wait = w
        nes.controller = steps[f]
        nes.step(1)
        for ix, a, v in nes.watch:
            if a == 0x100 and v == 0x40 and (shadow[0x100], shadow[0x101], shadow[0x102]) in WAIT_STUBS:
                w += 1; nrol = nror = 0
                nes_ram[w] = bytes(shadow[:0x800]); frame_of[w] = f
                if w % WRAM_EVERY == 0: wram[w] = bytes(shadow[0x6000:0x8000])
            if a == 0x20:
                nrol = nrol + 1 if ix == ROL20 else 0
                if nrol == 8: pads[w + 1] = v; nrol = 0
            elif a == 0x35:
                nror = nror + 1 if ix == ROR35 else 0
                if nror == 8: pads[w + 1] = rev[v]; nror = 0
            if a < 0x2000: shadow[a & 0x7FF] = v
            elif a >= 0x6000: shadow[a] = v
        if f in shots_at: shot_w.append(w)
    nes_pass.poke_wait = poke_wait
    return nes_ram, pads, frame_of, wram, shot_w


def scenario(args):
    """the input scenario from the options (removed from args): NES GB [FRAMES] with
    --random SEED, --form F (forced formation: data patch in copies of both ROMs), --press
    'frame:key,..' (from the first press on only these), --poke ADDR=VAL,.. at --pokeat F.
    Returns (nes_path, gb_path, steps, pokes, poke_at, limit)."""
    def opt(name, default=None, conv=str):
        if name in args:
            k = args.index(name); v = conv(args[k + 1]); del args[k:k + 2]; return v
        return default
    rnd = opt('--random', None, int)
    form = opt('--form', None, int)
    presses = opt('--press', '')
    pokes = [tuple(int(x, 16) for x in kv.split('=')) for kv in opt('--poke', '').split(',') if kv]
    poke_at = opt('--pokeat', 9700, int)        # NES frame of the pokes
    nes_path, gb_path = args[0], args[1]
    if form is not None:                       # the opening battle shows battle `form` (ff2form)
        import ff2form, tempfile, shutil
        tmp = tempfile.mkdtemp()
        nes_rom = open(nes_path, 'rb').read()
        p = ff2form.patched(nes_rom, form)
        nes_path = os.path.join(tmp, 'f.nes'); open(nes_path, 'wb').write(p)
        g = bytearray(open(gb_path, 'rb').read())     # GB data bank 1 + 11 = NES bank 11
        o_n, o_g = 16 + 11 * 0x4000, (1 + 11) * 0x4000
        g[o_g:o_g + 0x4000] = p[o_n:o_n + 0x4000]
        g[0x14E] = g[0x14F] = 0                     # (global checksum not used)
        shutil.copy(gb_path[:-3] + '.sym', os.path.join(tmp, 'f.sym'))
        gb_path = os.path.join(tmp, 'f.gb'); open(gb_path, 'wb').write(g)
    limit = int(args[2]) if len(args) > 2 else 6000
    steps = script_newgame(limit)
    if rnd is not None: add_random(steps, rnd)
    if presses:                                # NES frame:key after which the input is only these
        K = dict(A=A, B=B, U=UP, D=DOWN, L=LEFT, R=RIGHT, S=START)
        first = min(int(x.split(':')[0]) for x in presses.split(','))
        for f in range(first, limit): steps[f] = 0
        for item in presses.split(','):
            t, k = item.split(':')
            for j in range(int(t), min(int(t) + 4, limit)): steps[j] = K[k]
    return nes_path, gb_path, steps, pokes, poke_at, limit


def main():
    args = sys.argv[1:]
    def opt(name, default=None, conv=str):
        if name in args:
            k = args.index(name); v = conv(args[k + 1]); del args[k:k + 2]; return v
        return default
    mask = set() if '--strict' in args else SOUND
    if '--strict' in args: args.remove('--strict')
    shots_at = {int(x) for x in opt('--shots', '').split(',') if x}
    out = opt('--out')
    sc = scenario(args)
    nes_path, gb_path, steps, pokes, poke_at, limit = sc
    nes = NES(nes_path); gb = GB(gb_path); sync_sram(nes, gb)
    poke_w = None
    sym = {}
    for l in open(gb_path[:-3] + '.sym'):
        b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
    nes_ram, pads, frame_of, wram, shot_w = nes_pass(nes, steps, limit, shots_at, pokes, poke_at)
    w = max(nes_ram) if nes_ram else 0
    last = w
    print('NES: %d frames, %d NMIs, %d wait NMIs' % (limit, nes.nmi_count, last))
    # 2. GB with those pads
    state = {'diff': None, 'k': 0}
    pw = getattr(nes_pass, 'poke_wait', None)
    def on_wait(_):
        m = gb.pb.memory
        k = (m[0xD830] | m[0xD831] << 8) + 1
        state['k'] = k
        if pw is not None and k == pw + 1:      # the NES pokes went in between waits pw and pw+1
            for a, v in pokes:
                if a < 0x800: m[0xC000 + a] = v
                else: m[0, 0xA000 + a - 0x6000] = v
        if state['diff'] is not None or k not in nes_ram: return
        a = nes_ram[k]; b = bytes(m[0xC000 + i] for i in range(0x800))
        d = [i for i in range(0x800) if a[i] != b[i] and not 0x100 <= i < 0x200 and i not in mask
             and not (i in TSX_SAVES and a[i] >= 0xC0 and b[i] >= 0xC0)]
        if d:
            state['diff'] = 'NES frame %d, wait %d: %s' % (frame_of[k], k, ' '.join(
                '%03X:%02X/%02X' % (i, a[i], b[i]) for i in d[:16]))
        elif k in wram:
            x = wram[k]; y = bytes(m[0, 0xA000 + i] for i in range(0x2000))
            d = [i for i in range(0x2000) if x[i] != y[i] and 0x6000 + i not in mask]
            if d:
                state['diff'] = 'NES frame %d, wait %d, work RAM: %s' % (frame_of[k], k, ' '.join(
                    '%04X:%02X/%02X' % (0x6000 + i, x[i], y[i]) for i in d[:16]))
    gb.pb.hook_register(*sym['rt_frame'], on_wait, None)
    for hn in [h for h in os.environ.get('HOOKS', '').split(',') if h]:   # debug: print at labels
        def hk(name, gb=gb, state=state):
            m = gb.pb.memory
            if state['k'] >= int(os.environ.get('HOOK_FROM', '0')):
                print('hook %s wait %d $40/$41 %02X%02X A %02X' % (name, state['k'], m[0xC041], m[0xC040], gb.pb.register_file.A))
        gb.pb.hook_register(*sym[hn], hk, hn)
    gb.feed_pads(sym, lambda n: pads.get(n + 1, 0))
    shots = []; guard = 0; prev = 0
    while state['k'] < last and state['diff'] is None:
        gb.pb.tick(); guard += 1
        if state['k'] != prev: prev, guard = state['k'], 0
        if guard > 2000:
            m = gb.pb.memory; pc = gb.pb.register_file.PC; cb = m[0xFF8C]
            bank = cb if pc >= 0x4000 else 0
            best = max(((a, n) for n, (b, a) in sym.items() if b == bank and a <= pc), default=(0, '?'))
            raise SystemExit('GB stuck before wait %d: PC %04X bank %d (%s+%d) SP %04X, fault info $D820: %s' % (
                state['k'] + 1, pc, cb, best[1], pc - best[0], gb.pb.register_file.SP,
                bytes(m[0xD820 + i] for i in range(16)).hex(' ')))
        while shot_w and state['k'] >= shot_w[0]:
            shots.append(gb.image()); shot_w.pop(0)
            if os.environ.get('SHOT_INFO'): print('shot at wait %d: LCDC %02X SCX %d SCY %d' % (state['k'], gb.pb.memory[0xFF40], gb.pb.memory[0xFF43], gb.pb.memory[0xFF42]))
    print(state['diff'] or 'no difference in %d frame waits (NES frames 0-%d)' % (last, limit))
    if shots and out:
        from PIL import Image
        sheet = Image.new('RGB', (164 * min(len(shots), 6), 148 * ((len(shots) + 5) // 6)), 'white')
        for i, g in enumerate(shots): sheet.paste(g, ((i % 6) * 164, (i // 6) * 148))
        sheet.save(out); print('saved', out)


if __name__ == '__main__':
    main()
