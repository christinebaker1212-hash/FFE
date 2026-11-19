"""SGB screenshots of the GB build in mGBA (build/sgbrun, from tools/gb/mgba/sgbrun.c) with the
input of the NES checks: the NES build is run with battleseq's input (or the new-game script)
and the pad it latched per NMI is fed to the GB by NES frame number.
usage: PYTHONPATH=build/emu sgbshots.py NES GB OUT.png NMI1,NMI2,... [--input MODE|--newgame|--field SCRIPT]
       [--dmg | --cgb] [--gambatte [--wav F --wav-from K]] [--poke ADDR=VAL,.. [--poke-at F]]
       (MODE: battleseq.py input modes, default fight; pokes as fieldseq.py: NES step F,
       default 3700; the GB gets them at the same NES frame)"""
import os, sys, subprocess, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cynes import NES
from PIL import Image

args = sys.argv[1:]
mode = 'fight'
if '--input' in args:
    k = args.index('--input'); mode = args[k + 1]; del args[k:k + 2]
newgame = '--newgame' in args
if newgame: args.remove('--newgame')
field = None
if '--field' in args:
    k = args.index('--field'); field = args[k + 1]; del args[k:k + 2]
pokes, poke_at = '', 3700
if '--poke' in args:
    k = args.index('--poke'); pokes = args[k + 1]; del args[k:k + 2]
if '--poke-at' in args:
    k = args.index('--poke-at'); poke_at = int(args[k + 1]); del args[k:k + 2]
gamb = '--gambatte' in args             # Gambatte (build/gbrun, tools/gb/gambatte/gbrun.c): GBC
if gamb: args.remove('--gambatte')        #   (or DMG with --dmg), cycle-accurate VRAM access
wav = None
if '--wav' in args:                       # (Gambatte) sound from NES frame WAV_FROM to a WAV file
    k = args.index('--wav'); wav = args[k + 1]; del args[k:k + 2]
wav_from = 0
if '--wav-from' in args:
    k = args.index('--wav-from'); wav_from = int(args[k + 1]); del args[k:k + 2]
dmg = '--dmg' in args
if dmg: args.remove('--dmg')
cgb = '--cgb' in args
if cgb: args.remove('--cgb')
nes_path, gb_path, out, shots = args[0], args[1], args[2], [int(x) for x in args[3].split(',')]
last = max(shots) + 2
nes = NES(nes_path)
if field is not None:                    # fieldseq.py script after the new game (no pokes)
    import fieldseq
    steps = fieldseq.frames_for(field)
    pad = lambda f: steps[f] if f < len(steps) else 0
elif newgame:
    from compare import new_game_script
    steps = []
    for it in new_game_script():
        if it[0] == 'shot': continue
        m, h, a = it
        steps += [m] * h + [0] * a
    pad = lambda f: steps[f] if f < len(steps) else 0
else:
    import battleseq
    pad = lambda f: battleseq.pad_for(mode, f)
pads = bytearray(last + 2)
f = 0
poke_nmi = None
while nes.nmi_count < last and f < last * 3:
    if pokes and f == poke_at:
        import battleseq
        st = nes.save()
        for kv in pokes.split(','):
            a, v = (int(x, 16) for x in kv.split('='))
            battleseq.poke_state(st, a, v)
        nes.load(st); poke_nmi = nes.nmi_count + 1
    nes.controller = pad(f)
    k0 = nes.nmi_count
    nes.step(1); f += 1
    for j in range(k0 + 1, min(nes.nmi_count, last) + 1):
        pads[j] = nes.pad_history[j & 0xFF]
tmp = os.environ.get('SHOTS_KEEP') or tempfile.mkdtemp()   # (env SHOTS_KEEP=DIR: keep the runner's files there)
os.makedirs(tmp, exist_ok=True)
pf = os.path.join(tmp, 'pads.bin'); open(pf, 'wb').write(pads)
sram = bytearray(0x8000)                 # cart RAM: bank 0 = the NES power-on save RAM
n0 = NES(nes_path)
for i in range(0x2000): sram[i] = n0[0x6000 + i]
sf = os.path.join(tmp, 'sram.bin'); open(sf, 'wb').write(sram)
here = os.path.dirname(os.path.abspath(__file__))
exe = os.path.join(here, '..', '..', 'build', 'gbrun' if gamb else 'sgbrun')
cmd = [exe, gb_path, str(last * 4), os.path.join(tmp, 's'), '--padfile', pf, '--sram', sf] + sum([['--nshot', str(s)] for s in shots], [])
if poke_nmi is not None: cmd += ['--poke', str(poke_nmi), pokes]
if dmg: cmd.append('--dmg')
if cgb and not gamb: cmd.append('--cgb')
if wav: cmd += ['--wav', wav, '--wav-from', str(wav_from)]
# stop early: run in chunks is not supported; FRAMES is an upper bound (GB frames)
print(subprocess.run(cmd, capture_output=True, text=True).stdout.strip())  # (env SGBRUN_REGS=1: registers per shot)
ims = []
for s in shots:
    p = os.path.join(tmp, 's_n%05d.ppm' % s)
    if os.path.exists(p): ims.append(Image.open(p).convert('RGB'))
W = sum(i.size[0] + 4 for i in ims); H = max(i.size[1] for i in ims)
sheet = Image.new('RGB', (W, H), (255, 0, 255)); x = 0
for i in ims: sheet.paste(i, (x, 0)); x += i.size[0] + 4
sheet.save(out); print('saved', out, len(ims), 'shots')
