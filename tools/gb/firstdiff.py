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
snaps = {}


def on_wait(ctx):
    m = gb.pb.memory
    k = (m[0xD830] | m[0xD831] << 8) + 1                # entering wait number k
    snaps[k] = bytes(m[0xC000 + i] for i in range(0x800))


gb.pb.hook_register(*sym['rt_wait_nmi'], on_wait, None)
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
f = 0
for m in steps[:limit]:
    if f == poke_at and pokes:                  # work RAM patches (NES state + GB cart RAM)
        import battleseq
        st = nes.save()
        for a, v in pokes:
            battleseq.poke_state(st, a, v)
            if a < 0x800: gb.pb.memory[0xC000 + a] = v          # NES RAM at GB $C000
            else: gb.pb.memory[0, 0xA000 + a - 0x6000] = v
        nes.load(st)
    nes.controller = m
    k0 = nes.nmi_count
    nes.step(1); f += 1
    if nes.nmi_count == k0: continue
    k = nes.nmi_count
    hist = nes.pad_history
    for j in range(k0 + 1, k + 1):          # one GB frame per NES NMI, with that frame's pad
        gb.set(hist[j & 0xFF])
        guard = 0
        while j not in snaps:
            gb.pb.tick(); guard += 1
            if guard > 2000: raise SystemExit('GB stuck before wait %d' % j)
            if os.environ.get('STUCK_SAVE') and j == int(os.environ['STUCK_SAVE']):
                with open('build/stuck.state', 'wb') as fh: gb.pb.save_state(fh)
                raise SystemExit('saved before wait %d' % j)
        if j < k: snaps.pop(j)
    if f in shots_at:
        shots.append(gb.image())
    if k < 8: continue
    a = nes.nmi_ram; b = snaps.pop(k)
    d = [i for i in range(0x800) if a[i] != b[i] and not 0x100 <= i < 0x200]
    if os.environ.get('WATCH') and f >= int(os.environ.get('WATCH_FROM', '0')):   # WATCH=6E90-6EB0: print both
        lo, hi = (int(x, 16) for x in os.environ['WATCH'].split('-'))
        print(f, k, 'NES', bytes(nes[x] for x in range(lo, hi)).hex(' '))
        print(f, k, 'GB ', bytes(gb.pb.memory[0, 0xA000 + x - 0x6000] for x in range(lo, hi)).hex(' '))
    if os.environ.get('GBWATCH') and f >= int(os.environ.get('WATCH_FROM', '0')):   # GBWATCH=D840-D872: GB WRAM
        lo, hi = (int(x, 16) for x in os.environ['GBWATCH'].split('-'))
        print(f, k, 'GB ', bytes(gb.pb.memory[x] for x in range(lo, hi)).hex(' '))
    if wram_from is not None and f >= wram_from and not d:     # (NES now, GB now: both at the wait)
        w = [0x6000 + i for i in range(0x2000) if nes[0x6000 + i] != gb.pb.memory[0, 0xA000 + i]]
        if w:
            print('frame %d nmi %d work RAM: %s' % (f, k, ' '.join('%04X:%02X/%02X' % (x, nes[x], gb.pb.memory[0, 0xA000 + x - 0x6000]) for x in w[:16])))
            break
    if d:
        print('frame %d nmi %d: %s' % (f, k, ' '.join('%03X:%02X/%02X' % (i, a[i], b[i]) for i in d[:16])))
        break
else:
    print('no difference in %d frames (%d NMIs)' % (f, nes.nmi_count))
if shots and out:
    from PIL import Image
    sheet = Image.new('RGB', (164 * min(len(shots), 6), 148 * ((len(shots) + 5) // 6)), 'white')
    for i, g in enumerate(shots):
        sheet.paste(g, ((i % 6) * 164, (i // 6) * 148))
    sheet.save(out)
    print('saved', out)
