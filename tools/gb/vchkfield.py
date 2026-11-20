"""Lot Check 2.2 (docs/gb-release-checks.md): VRAM / OAM access check of a GB build over one
input script, on DMG, CGB and SGB (mGBA, build/sgbrun with env SGBRUN_VCHK=1: every CPU write
to VRAM in mode 3 or to OAM in mode 2 / 3 with the LCD on is counted).
usage: PYTHONPATH=build/emu vchkfield.py NES GB UNTIL [--field SCRIPT | --newgame | --input MODE]
       [--poke P [--poke-at F]]
  the input is made as lagcheck.py makes it (the NES run's latched pads); prints per mode the
  frames / NES frame waits reached and the violation count (and the first few)."""
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
exe = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'build', 'sgbrun')
res = []
for m in ('dmg', 'cgb', 'sgb'):
    cmd = [exe, gb_path, str(until + 400), os.path.join(tmp, 's'), '--padfile', pf, '--sram', sf]
    if poke_nmi is not None: cmd += ['--poke', str(poke_nmi), pokes]
    if m != 'sgb': cmd.append('--' + m)
    r = subprocess.run(cmd, capture_output=True, text=True, env=dict(os.environ, SGBRUN_VCHK='1'))
    tot = [l for l in r.stdout.split('\n') if l.startswith('VCHK total') or l.startswith('frames')]
    res.append('%s: %s' % (m, ' | '.join(tot)))
    first = [l for l in r.stderr.split('\n') if l.startswith('VCHK ')][:3]
    if first: res.append('   ' + ' / '.join(first))
print('\n'.join(res))
