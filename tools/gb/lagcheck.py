"""Frame pacing of a GB build against the NES (Gambatte, hardware-like timing).

For every NES frame wait k, the NES's real frames (emulated video frames) between wait k and
k+1 are compared with the GB's video frames between the same waits. A GB that keeps pace
takes exactly as many frames; extra GB frames are lag (the game runs slower, the music
stretches).
usage: PYTHONPATH=build/emu lagcheck.py NES GB UNTIL [--field SCRIPT | --newgame | --input MODE]
       [--dmg | --sgb (mGBA)] [--poke P [--poke-at F]] [--win 60]
  prints lag per window of NES frame waits, the worst single waits, and the total."""
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
exe = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'build', 'gbrun')
cmd = [exe, gb_path, str(until * 4), os.path.join(tmp, 's'), '--padfile', pf, '--sram', sf,
       '--lagfile', lf, '--until', str(until)]
if poke_nmi is not None: cmd += ['--poke', str(poke_nmi), pokes]
if dmg: cmd.append('--dmg')
if sgb:                                       # Super Game Boy: mGBA (sgbrun, SGBRUN_LAG)
    exe2 = os.path.join(os.path.dirname(exe), 'sgbrun')
    cmd = [exe2, gb_path, str(until * 4), os.path.join(tmp, 's'), '--padfile', pf, '--sram', sf]
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
w10 = sorted(((span(k, k + 10), k) for k in range(k0, k1 - 10)), reverse=True)
shown, out = set(), []
for v, k in w10:
    if v <= 1 or len(out) >= 12: break
    if any(abs(k - s) < 10 for s in shown): continue
    shown.add(k); out.append('%d:+%d' % (k, v))
print('worst 10-wait spans:', ' '.join(out))
smooth = sum(1 for k in range(k0, k1 - 10, 10) if span(k, k + 10) <= 1)
print('10-wait spans keeping pace (<= 1 frame extra): %d of %d' % (smooth, (k1 - k0) // 10))
