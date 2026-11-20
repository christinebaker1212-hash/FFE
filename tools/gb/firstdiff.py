"""Lockstep NES/GB (new-game script, then optional random play) and report the first frame
where NES RAM at NMI k differs from GB RAM on entering frame wait k (page 1 excluded).
The GB gets the controller value the NES game latched in each frame (cynes nmi_pad).
usage: PYTHONPATH=build/emu firstdiff.py NES GB [MAXFRAMES] [--random SEED] [--battle]
       [--input MODE (battleseq.py modes, implies --battle)] [--poke ADDR=VAL,... [--poke-at F]]
       [--field SCRIPT (fieldseq.py: new game, then the moves)]
       [--shots F1,F2,... --out SHEET.png]
--battle: the battleshot.py input (new-game script, walk into a battle, A once a second);
--shots: GB screens after those NES frames, saved as one sheet (--out).
--wram F: from NES frame F on, also compare work RAM $6000-$7FFF at each NMI (slow).
env STUCK_SAVE=K: save the PyBoy state on entering frame wait K to build/stuck.state and stop
(for debugging the GB alone from there)."""
import sys, random, os
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from compare import sync_sram, GB, new_game_script, UP, DOWN, LEFT, RIGHT, A, B, START
from cynes import NES

args = sys.argv[1:]
rnd = None
if '--random' in args:
    k = args.index('--random'); rnd = int(args[k + 1]); del args[k:k + 2]
battle = '--battle' in args
if battle: args.remove('--battle')
mode, pokes = 'fight', []
field = None
if '--field' in args:
    k = args.index('--field'); field = args[k + 1]; del args[k:k + 2]
if '--input' in args:
    k = args.index('--input'); mode = args[k + 1]; del args[k:k + 2]; battle = True
if '--poke' in args:
    k = args.index('--poke')
    pokes = [tuple(int(x, 16) for x in kv.split('=')) for kv in args[k + 1].split(',') if kv]; del args[k:k + 2]
poke_at = 6100 if not field else 3700
if '--poke-at' in args:
    k = args.index('--poke-at'); poke_at = int(args[k + 1]); del args[k:k + 2]
wram_from = None
if '--wram' in args:
    k = args.index('--wram'); wram_from = int(args[k + 1]); del args[k:k + 2]
shots_at, out = set(), None
if '--shots' in args:
    k = args.index('--shots'); shots_at = {int(x) for x in args[k + 1].split(',')}; del args[k:k + 2]
if '--out' in args:
    k = args.index('--out'); out = args[k + 1]; del args[k:k + 2]
shots = []
nes = NES(args[0]); gb = GB(args[1]); sync_sram(nes, gb)
limit = int(args[2]) if len(args) > 2 else 100000
sym = {}
for l in open(args[1][:-3] + '.sym'):
    b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
steps = []
for it in new_game_script():
    if it[0] == 'shot': continue
    m, h, a = it
    steps += [m] * h + [0] * a
if battle:
    import battleseq
    steps = [battleseq.pad_for(mode, f) for f in range(limit)]
if field:
    import fieldseq
    steps = [fieldseq.pad_for(field, f) for f in range(limit)]
if rnd is not None:
    r = random.Random(rnd)
    btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT]
    while len(steps) < limit:
        steps += [r.choice(btns)] * r.randint(2, 40) + [0] * r.randint(1, 20)

# 1. the NES alone: RAM at each NMI k, the pad it latched, NES frame of each NMI
nes_ram, pads, frame_of, wram_at = {}, {}, {}, {}
poke_k, shot_k = None, []
f = 0
for m in steps[:limit]:
    if f == poke_at and pokes:                  # work RAM patches (NES state; GB below)
        import battleseq
        st = nes.save()
        for a, v in pokes: battleseq.poke_state(st, a, v)
        nes.load(st); poke_k = nes.nmi_count
    nes.controller = m
    k0 = nes.nmi_count
    nes.step(1); f += 1
    k = nes.nmi_count
    for j in range(k0 + 1, k + 1):
        pads[j] = nes.pad_history[j & 0xFF]; frame_of[j] = f
    if k != k0 and k >= 8: nes_ram[k] = bytes(nes.nmi_ram)
    if k != k0 and wram_from is not None and f >= wram_from:
        wram_at[k] = bytes(nes[0x6000 + i] for i in range(0x2000))
    if f in shots_at: shot_k.append(k)
last = nes.nmi_count

# 2. the GB with those pads; RAM on entering each frame wait compared with the NES
state = {'diff': None, 'k': 0}


def do_poke(m):
    if state.pop('poke', None):
        for a, v in pokes:
            if a < 0x800: m[0xC000 + a] = v              # NES RAM at GB $C000
            else: m[0, 0xA000 + a - 0x6000] = v


def on_wait(ctx):
    m = gb.pb.memory
    k = (m[0xD830] | m[0xD831] << 8) + 1                # entering wait number k
    state['k'] = k
    if k == poke_k:                                     # (after this wait's comparison: the
        state['poke'] = True                            #   NES snapshot at NMI k precedes its poke)
    if state['diff'] is not None or k not in nes_ram:
        do_poke(m); return
    a = nes_ram[k]; b = bytes(m[0xC000 + i] for i in range(0x800))
    d = [i for i in range(0x800) if a[i] != b[i] and not 0x100 <= i < 0x200]
    if d:
        state['diff'] = 'frame %d nmi %d: %s' % (frame_of.get(k, -1), k, ' '.join('%03X:%02X/%02X' % (i, a[i], b[i]) for i in d[:16]))
    elif k in wram_at:
        w = [0x6000 + i for i in range(0x2000) if wram_at[k][i] != m[0, 0xA000 + i]]
        if w:
            state['diff'] = 'frame %d nmi %d work RAM: %s' % (frame_of.get(k, -1), k, ' '.join(
                '%04X:%02X/%02X' % (x, wram_at[k][x - 0x6000], m[0, 0xA000 + x - 0x6000]) for x in w[:16]))
    do_poke(m)
    if os.environ.get('GBWATCH') and frame_of.get(k, 0) >= int(os.environ.get('WATCH_FROM', '0')):
        lo, hi = (int(x, 16) for x in os.environ['GBWATCH'].split('-'))
        print(frame_of.get(k), k, 'GB ', bytes(m[x] for x in range(lo, hi)).hex(' '))


gb.pb.hook_register(*sym['rt_wait_nmi'], on_wait, None)
gb.feed_pads(sym, lambda n: pads.get(n + 1))      # (frame after wait n: the pad of NMI n + 1)
guard = 0; prev = 0
while state['k'] <= last and state['diff'] is None:
    gb.pb.tick(); guard += 1
    if state['k'] != prev: prev, guard = state['k'], 0
    if guard > 2000: raise SystemExit('GB stuck before wait %d (PC %02X:%04X SP %04X)' % (state['k'] + 1, gb.pb.memory[0x2000] if False else 0, gb.pb.register_file.PC, gb.pb.register_file.SP))
    if os.environ.get('STUCK_SAVE') and state['k'] + 1 >= int(os.environ['STUCK_SAVE']):
        with open('build/stuck.state', 'wb') as fh: gb.pb.save_state(fh)
        raise SystemExit('saved before wait %d' % (state['k'] + 1))
    while shot_k and state['k'] >= shot_k[0]:
        shots.append(gb.image()); shot_k.pop(0)
if state['diff']:
    print(state['diff'])
else:
    print('no difference in %d frames (%d NMIs)' % (f, last))
if shots and out:
    from PIL import Image
    sheet = Image.new('RGB', (164 * min(len(shots), 6), 148 * ((len(shots) + 5) // 6)), 'white')
    for i, g in enumerate(shots):
        sheet.paste(g, ((i % 6) * 164, (i // 6) * 148))
    sheet.save(out)
    print('saved', out)
