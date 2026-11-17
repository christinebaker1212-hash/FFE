"""Replay the profiler's input (new-game script + random steps) on the GB build alone and
report the first wild jump: execution reaching rst $38 or the boot code again.
usage: PYTHONPATH=build/emu crashfind.py GB SEED STEPS"""
import sys, random
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from compare import new_game_script, GBNAME, UP, DOWN, LEFT, RIGHT, A, B, START
from pyboy import PyBoy

rom, seed, nsteps = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
sym = {}; byaddr = {}
for l in open(rom[:-3] + '.sym'):
    b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
    byaddr.setdefault(int(b, 16), []).append((int(a, 16), n))
for b in byaddr: byaddr[b].sort()
import bisect


def name(bank, a):
    lst = byaddr.get(0 if a < 0x4000 else bank, [])
    i = bisect.bisect_right([x for x, _ in lst], a) - 1
    return '%s+%d' % (lst[i][1], a - lst[i][0]) if i >= 0 else '?'


pb = PyBoy(rom, window='null', cgb=False, sound_emulated=False)
pb.set_emulation_speed(0)
booted = [False]; hit = []


def trap(ctx):
    m = pb.memory; rf = pb.register_file
    if ctx == 'boot' and not booted[0]:
        booted[0] = True; return
    sp = rf.SP
    stack = [m[sp + 2 * k] | m[sp + 2 * k + 1] << 8 for k in range(12)]
    bank = m[0xFF80 + 12]
    hit.append('%s: SP=%04X code_bank=%d stack: %s' % (ctx, sp, bank, ' '.join(
        '%04X(%s)' % (v, name(bank, v)) for v in stack)))


pb.hook_register(0, 0x0038, trap, 'rst38')
pb.hook_register(0, sym['boot'][1], trap, 'boot')
script = new_game_script()
r = random.Random(seed)
btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT]
for _ in range(nsteps): script.append((r.choice(btns), r.randint(2, 40), r.randint(1, 20)))
held = 0; frame = 0
for k, it in enumerate(script):
    if it[0] == 'shot': continue
    m, hold, after = it
    for phase, n in ((m, hold), (0, after)):
        for bit, nm in GBNAME.items():
            if phase & bit and not held & bit: pb.button_press(nm)
            if not phase & bit and held & bit: pb.button_release(nm)
        held = phase
        for _ in range(n):
            pb.tick(); frame += 1
            if hit:
                print('step %d frame %d' % (k, frame)); print('\n'.join(hit[:3])); sys.exit(0)
print('no crash')
