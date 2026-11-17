"""Writes to one NES address during frames K-2..K: NES (emulator write watch, with the
writing instruction) vs GB (value seen at each recompiled instruction label).
usage: PYTHONPATH=build/emu watchdiff.py NES GB K ADDR [--random SEED]"""
import sys, random
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from compare import sync_sram, GB, new_game_script, UP, DOWN, LEFT, RIGHT, A, B, START
from nescode import space_of_index
from cynes import NES

nes = NES(sys.argv[1]); gb = GB(sys.argv[2]); sync_sram(nes, gb); K = int(sys.argv[3]); ADDR = int(sys.argv[4], 16)
RND = int(sys.argv[sys.argv.index('--random') + 1]) if '--random' in sys.argv else None
sym = {}
for l in open(sys.argv[2][:-3] + '.sym'):
    b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
waits = [0]
gb.pb.hook_register(*sym['rt_wait_nmi'], lambda c: waits.__setitem__(0, waits[0] + 1), None)
steps = []
for it in new_game_script():
    if it[0] == 'shot': continue
    m, h, a = it
    steps += [m] * h + [0] * a
if RND is not None:
    r = random.Random(RND)
    btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT]
    while len(steps) < 60000:
        steps += [r.choice(btns)] * r.randint(2, 40) + [0] * r.randint(1, 20)
gblog = []; last = [None]
gaddr = 0xC000 + (ADDR & 0x7FF) if ADDR < 0x2000 else 0xA000 + ADDR - 0x6000


def on_label(name):
    v = gb.pb.memory[gaddr]
    if v != last[0]:
        gblog.append((name, v)); last[0] = v


hooked = False
for m in steps:
    nes.controller = m
    k0 = nes.nmi_count
    nes.step(1)
    if nes.nmi_count == k0: continue
    k = nes.nmi_count
    hist = nes.pad_history
    for j in range(k0 + 1, k + 1):
        gb.set(hist[j & 0xFF])
        guard = 0
        while waits[0] < j:
            gb.pb.tick(); guard += 1
            if guard > 3000: raise SystemExit('GB stuck before frame wait %d (PC=%04X)' % (j, gb.pb.register_file.PC))
    if K - 3 <= k < K and not hooked:
        last[0] = gb.pb.memory[gaddr]
        at = {}
        for n, (b, a) in sym.items():
            if n.startswith('L_') and n.count('_') == 2: at.setdefault((b, a), []).append(n[2:])
        for (b, a), names in at.items():
            gb.pb.hook_register(b, a, on_label, min(names))
        nes.watch = (ADDR, ADDR)
        if '--probe' in sys.argv:
            lab = sys.argv[sys.argv.index('--probe') + 1]
            def probe(ctx):
                m = gb.pb.memory; rf = gb.pb.register_file
                print('  probe %s: $10/$11=%02X%02X Y=%02X X=%02X A=%02X nes_bank8=%d data_bank8=%d nes_bankC=%d code_bank=%d' % (
                    lab, m[0xC011], m[0xC010], rf.C, rf.E, rf.A, m[0xFF80 + 13], m[0xFF80 + 14], m[0xFF80 + 15], m[0xFF80 + 12]))
            b, a = sym['L_' + lab]
            gb.pb.hook_deregister(b, a)
            gb.pb.hook_register(b, a, probe, None)
        print('watching from wait', k, 'value', hex(last[0]))
        hooked = True
    if k >= K: break
print('NES writes:')
for idx, ad, v in nes.watch:
    sp, a = space_of_index(idx)
    print('  %s:%04X wrote %02X' % (sp, a, v))
print('GB value changes (seen at label):')
for n, v in gblog: print('  before %s: %02X' % (n, v))
