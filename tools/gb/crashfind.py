"""Replay the profiler's input (new-game script + random steps) on the GB build alone; when
the frame-wait counter goes backwards (the GB re-booted after a wild jump), reload the last
save state and replay with every recompiled-instruction label hooked to show the last
NES instructions executed before the crash.
usage: PYTHONPATH=build/emu crashfind.py GB SEED STEPS"""
import sys, io, random, collections
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from compare import new_game_script, GBNAME, UP, DOWN, LEFT, RIGHT, A, B, START
from pyboy import PyBoy

rom, seed, nsteps = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
sym = {}
for l in open(rom[:-3] + '.sym'):
    b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
pb = PyBoy(rom, window='null', cgb=False, sound_emulated=False)
pb.set_emulation_speed(0)
script = new_game_script()
r = random.Random(seed)
btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT]
for _ in range(nsteps): script.append((r.choice(btns), r.randint(2, 40), r.randint(1, 20)))
frames = []                                  # button mask per frame
for it in script:
    if it[0] == 'shot': continue
    m, h, a = it
    frames += [m] * h + [0] * a
nmi = lambda: pb.memory[0xD830] | pb.memory[0xD831] << 8
held = [0]


def setb(mask):
    for bit, nm in GBNAME.items():
        if mask & bit and not held[0] & bit: pb.button_press(nm)
        if not mask & bit and held[0] & bit: pb.button_release(nm)
    held[0] = mask


snap = None; snap_f = 0; last = 0; crash = None
for f, m in enumerate(frames):
    if f % 60 == 0:
        snap = io.BytesIO(); pb.save_state(snap); snap_f = f; snap_held = held[0]
    setb(m); pb.tick()
    n = nmi()
    if f > 200 and n < last:
        crash = f; break
    last = n
if crash is None:
    print('no crash in %d frames' % len(frames)); sys.exit(0)
print('re-boot detected at frame %d (frame waits %d -> %d); replaying from frame %d' % (crash, last, nmi(), snap_f))
snap.seek(0); pb.load_state(snap); held[0] = snap_held
ring = collections.deque(maxlen=60)
at = {}
for n, (b, a) in sym.items():
    if n.startswith('L_') and n.count('_') == 2: at.setdefault((b, a), []).append(n[2:])
for (b, a), names in at.items():
    pb.hook_register(b, a, lambda ctx: ring.append(ctx), min(names))
pb.hook_register(sym['boot'][0], sym['boot'][1], lambda ctx: ring.append('*** boot ***'), None)
for f in range(snap_f, crash + 1):
    setb(frames[f]); pb.tick()
    if '*** boot ***' in ring: break
print('last labels before the re-boot:')
print(' '.join(ring))
