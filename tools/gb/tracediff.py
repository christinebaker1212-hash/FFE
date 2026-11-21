"""Find where the GB build first runs a different NES instruction than the NES build:
lockstep to frame wait K-1 (as firstdiff.py), then trace NES instructions and GB labels
(L_space_addr hooks) for frame K and compare the two sequences.
usage: PYTHONPATH=build/emu tracediff.py NES GB K [--random SEED | --battle | --field SCRIPT]"""
import os, sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from compare import sync_sram, GB, new_game_script
from nescode import space_of_index
from cynes import NES

import random
from compare import UP, DOWN, LEFT, RIGHT, A, B, START
nes = NES(sys.argv[1]); gb = GB(sys.argv[2]); sync_sram(nes, gb); K = int(sys.argv[3])
RND = int(sys.argv[sys.argv.index('--random') + 1]) if '--random' in sys.argv else None
sym = {}
for l in open(sys.argv[2][:-3] + '.sym'):
    b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
waits = [0]


def on_wait(ctx):
    waits[0] += 1


gb.pb.hook_register(*sym['rt_wait_nmi'], on_wait, None)
steps = []
for it in new_game_script():
    if it[0] == 'shot': continue
    m, h, a = it
    steps += [m] * h + [0] * a
if '--battle' in sys.argv:                 # battleshot / firstdiff --battle input
    import battleseq
    steps = [battleseq.pad_for('fight', f) for f in range(60000)]
if '--field' in sys.argv:                  # fieldseq script (as firstdiff --field; no pokes)
    import fieldseq
    fs = sys.argv[sys.argv.index('--field') + 1]
    steps = [fieldseq.pad_for(fs, f) for f in range(60000)]
if RND is not None:
    r = random.Random(RND)
    btns = [UP, DOWN, LEFT, RIGHT, A, A, B, START, UP, DOWN, LEFT, RIGHT]
    while len(steps) < 60000:
        steps += [r.choice(btns)] * r.randint(2, 40) + [0] * r.randint(1, 20)
gbtrace = []
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
        print('tracing from wait', k, file=sys.stderr)
        # hook every instruction label for the next frame
        at = {}
        for n, (b, a) in sym.items():
            if n.startswith('L_') and n.count('_') == 2:
                at.setdefault((b, a), []).append(n[2:])
            elif n.startswith('C') and '_L_' in n and n.count('_') == 3 and '.' not in n:   # (copies in calling banks)
                at.setdefault((b, a), []).append(n.split('_L_')[1])
        for (b, a), names in at.items():       # empty translations share an address
            gb.pb.hook_register(b, a, lambda ctx: gbtrace.extend(ctx), sorted(names))
        hooked = True
        nes.trace = True
        continue
    if k >= K:
        while waits[0] < k: gb.pb.tick()
        break
nt = list(nes.trace)
print('trace len', len(nt), 'k', k, file=sys.stderr)
nseq = []
for v in nt:
    sp, a = space_of_index(v >> 8)
    if sp == 'fix' and (0xFECF <= a < 0xFEDB or 0xFEDC <= a < 0xFEF1): continue   # NMI handler / wait loop
    nseq.append('%s_%04X' % (sp, a))
if os.environ.get('TD_SPACE'):                    # env TD_SPACE=b12,..: only those spaces (natives
    keep = tuple(x + '_' for x in os.environ['TD_SPACE'].split(','))   #   skip NES code elsewhere)
    nseq = [x for x in nseq if x.startswith(keep)]
    gbtrace[:] = [x for x in gbtrace if x.startswith(keep)]
if os.environ.get('TD_SKIP'):                     # env TD_SKIP=sp:A-B,..: ranges left out of both
    rng = []
    for t in os.environ['TD_SKIP'].split(','):
        sp, ab = t.split(':'); a0, b0 = (int(x, 16) for x in ab.split('-')); rng.append((sp, a0, b0))
    out = lambda x: any(x.startswith(sp + "_") and a0 <= int(x.split("_")[1][:4], 16) < b0 for sp, a0, b0 in rng)
    nseq = [x for x in nseq if not out(x)]
    gbtrace[:] = [x for x in gbtrace if not out(x)]
gbtrace[:] = [x for x in gbtrace if '.' not in x]  # (local labels inside a translation)
if os.environ.get('TD_DUMP'):                     # env TD_DUMP=FILE: both sequences
    with open(os.environ['TD_DUMP'], 'w') as fh:
        fh.write('NES ' + ' '.join(nseq) + '\nGB ' + ' '.join(gbtrace) + '\n')
print('NES %d instructions, GB %d labels' % (len(nseq), len(gbtrace)))
# GB labels only exist for compiled instructions; compare in order
i = nseq.index(gbtrace[0]) if gbtrace and gbtrace[0] in nseq[:50] else 0
j = 0
while i < len(nseq) and j < len(gbtrace):
    if nseq[i] == gbtrace[j]: i += 1; j += 1; continue
    if j > 0 and gbtrace[j] == gbtrace[j - 1] and (i == 0 or nseq[i - 1] == gbtrace[j]): j += 1; continue
    print('first difference at NES #%d / GB #%d' % (i, j))
    print('  NES:', ' '.join(nseq[max(0, i - 12):i + 8]))
    print('  GB :', ' '.join(gbtrace[max(0, j - 12):j + 8]))
    break
else:
    print('sequences agree up to the shorter one (NES %d / GB %d); where the shorter ends:' % (i, j))
    print('  NES:', ' '.join(nseq[max(0, i - 12):i + 12]))
    print('  GB :', ' '.join(gbtrace[max(0, j - 12):j + 12]))
