"""Frame pacing of a GB build against the NES (Gambatte, hardware-like timing).

For every NES frame wait k, the NES's real frames (emulated video frames) between wait k and
k+1 are compared with the GB's video frames between the same waits. A GB that keeps pace
takes exactly as many frames; extra GB frames are lag (the game runs slower, the music
stretches).
usage: PYTHONPATH=build/emu lagcheck.py NES GB UNTIL [--field SCRIPT | --newgame | --input MODE]
       [--dmg | --sgb (mGBA)] [--poke P [--poke-at F]] [--win 60]
  prints lag per window of NES frame waits, the worst single waits, and the total.
  env LAG_DUMP=FILE writes 'wait GB-frames NES-frames' per wait (for grouping profiles)."""
import os, sys, subprocess, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cynes import NES

args = sys.argv[1:]


def opt(name, default=None, flag=False):
    if name not in args: return default
    k = args.index(name)
    if flag: del args[k]; return True
    v = args[k + 1]; del args[k:k + 2]; return v


field = opt('--field'); newgame = opt('--newgame', flag=True); mode = opt('--input', 'fight')
dmg = opt('--dmg', flag=True); sgb = opt('--sgb', flag=True); pokes = opt('--poke', ''); poke_at = int(opt('--poke-at', '3700'))
win = int(opt('--win', '60'))
gbj = opt('--gbjitter')            # A-B: GB-only pacing in waits A-B (bursts: GB frames with 2+ waits)
nes_path, gb_path, until = args[0], args[1], int(args[2])

if field is not None:
    import fieldseq
    steps = fieldseq.frames_for(field); pad = lambda f: steps[f] if f < len(steps) else 0
elif newgame:
    from compare import new_game_script
    steps = []
    for it in new_game_script():
        if it[0] == 'shot': continue
        m, h, a = it; steps += [m] * h + [0] * a
    pad = lambda f: steps[f] if f < len(steps) else 0
else:
    import battleseq
    pad = lambda f: battleseq.pad_for(mode, f)

nes = NES(nes_path)
pads = bytearray(until + 2)
nes_at = {}                                  # wait k -> NES video frame
f = 0; poke_nmi = None
while nes.nmi_count < until + 1 and f < until * 3:
    if pokes and f == poke_at:
        import battleseq
        st = nes.save()
        for kv in pokes.split(','):
            a, v = (int(x, 16) for x in kv.split('=')); battleseq.poke_state(st, a, v)
        nes.load(st); poke_nmi = nes.nmi_count + 1
    nes.controller = pad(f)
    k0 = nes.nmi_count
    nes.step(1); f += 1
    for j in range(k0 + 1, min(nes.nmi_count, until + 1) + 1):
        pads[j] = nes.pad_history[j & 0xFF]; nes_at[j] = f
tmp = tempfile.mkdtemp()
pf = os.path.join(tmp, 'pads.bin'); open(pf, 'wb').write(pads)
sram = bytearray(0x8000)
n0 = NES(nes_path)
for i in range(0x2000): sram[i] = n0[0x6000 + i]
sf = os.path.join(tmp, 'sram.bin'); open(sf, 'wb').write(sram)
lf = os.path.join(tmp, 'lag.bin')
if os.environ.get('LAG_KEEP'): print('inputs in', tmp)   # padfile / sram for sgbrun profiling
exe = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'build', 'gbrun')
cmd = [exe, gb_path, str(until * 4), os.path.join(tmp, 's'), '--padfile', pf, '--sram', sf,
       '--lagfile', lf, '--until', str(until)]
if poke_nmi is not None: cmd += ['--poke', str(poke_nmi), pokes]
if dmg: cmd.append('--dmg')
if sgb:                                       # Super Game Boy: mGBA (sgbrun, SGBRUN_LAG)
    exe2 = os.path.join(os.path.dirname(exe), 'sgbrun')
    cmd = [exe2, gb_path, str(until * 4), os.path.join(tmp, 's'), '--padfile', pf, '--sram', sf]
    if os.environ.get('LAG_MGBA_CGB'): cmd.append('--cgb')     # (mGBA as a Game Boy Color)
    subprocess.run(cmd, capture_output=True, env=dict(os.environ, SGBRUN_LAG=lf))
else:
    subprocess.run(cmd, capture_output=True)
d = open(lf, 'rb').read()
cnt = [d[i] | d[i + 1] << 8 for i in range(0, len(d), 2)]
gb_at = {}
for g, n in enumerate(cnt):
    for j in range(max(gb_at, default=0) + 1, n + 1): gb_at[j] = g
ks = sorted(k for k in nes_at if k in gb_at and k + 1 in nes_at and k + 1 in gb_at)
span = lambda a, b: (gb_at[b] - gb_at[a]) - (nes_at[b] - nes_at[a])   # extra GB frames from wait a to b
k0, k1 = ks[0], ks[-1]
tot = span(k0, k1)
print('NES waits %d-%d: GB %d frames, NES %d frames, lag %d frames (%+.1f%%)' % (
    k0, k1, gb_at[k1] - gb_at[k0], nes_at[k1] - nes_at[k0], tot, 100.0 * tot / max(1, nes_at[k1] - nes_at[k0])))
row = []
for w0 in range(k0, k1 - win + 1, win):
    row.append('%d:%d' % (w0, span(w0, w0 + win)))
print('lag per %d waits: %s' % (win, ' '.join(row)))
if os.environ.get('LAG_DUMP'):                 # LAG_DUMP=FILE: "k gb_frames nes_frames" per wait
    with open(os.environ['LAG_DUMP'], 'w') as o:
        for k in ks: o.write('%d %d %d\n' % (k, gb_at[k + 1] - gb_at[k], nes_at[k + 1] - nes_at[k]))
if os.environ.get('LAG_SHOW'):                 # LAG_SHOW=k,..: GB / NES frames of those waits
    print('GB/NES frames:', ' '.join('%d:%d/%d' % (k, gb_at[k + 1] - gb_at[k], nes_at[k + 1] - nes_at[k])
                                      for k in map(int, os.environ['LAG_SHOW'].split(',')) if k in gb_at and k + 1 in gb_at))
w10 = sorted(((span(k, k + 10), k) for k in range(k0, k1 - 10)), reverse=True)
shown, out = set(), []
for v, k in w10:
    if v <= 1 or len(out) >= 12: break
    if any(abs(k - s) < 10 for s in shown): continue
    shown.add(k); out.append('%d:+%d' % (k, v))
print('worst 10-wait spans:', ' '.join(out))
if gbj:
    a, b = (int(x) for x in gbj.split('-'))
    burst = {}; slow = []
    for g in range(1, len(cnt)):
        d = cnt[g] - cnt[g - 1]
        if a <= cnt[g] <= b and d >= 2: burst[cnt[g]] = d
    for k in range(a, b):
        if k in gb_at and k + 1 in gb_at and gb_at[k + 1] - gb_at[k] >= 2: slow.append('%d:%d' % (k, gb_at[k + 1] - gb_at[k]))
    print('GB frames running 2+ waits (music rushed):', ' '.join('%d:x%d' % kv for kv in sorted(burst.items())) or 'none')
    print('waits taking 2+ GB frames:', ' '.join(slow) or 'none')
    diff = []                                    # waits whose GB frames differ from the NES's
    for k in range(a, b):
        if k in gb_at and k + 1 in gb_at and k in nes_at and k + 1 in nes_at:
            g, n = gb_at[k + 1] - gb_at[k], nes_at[k + 1] - nes_at[k]
            if g != n: diff.append('%d:%d/%d' % (k, g, n))
    print('waits where GB frames != NES frames (GB/NES): %d' % len(diff), ' '.join(diff[:int(os.environ.get('LAG_N', '80'))]))
    if os.environ.get('LAG_TIMELINE'):           # wait count at each GB frame around a wait
        c = int(os.environ['LAG_TIMELINE'])
        g0 = gb_at.get(c, 0)
        print('GB frame: wait', ' '.join('%d:%d' % (g, cnt[g]) for g in range(max(0, g0 - 12), min(len(cnt), g0 + 12))))
        print('NES frame of waits', ' '.join('%d:%d' % (k, nes_at[k]) for k in range(c - 8, c + 8) if k in nes_at))
smooth = sum(1 for k in range(k0, k1 - 10, 10) if span(k, k + 10) <= 1)
print('10-wait spans keeping pace (<= 1 frame extra): %d of %d' % (smooth, (k1 - k0) // 10))
