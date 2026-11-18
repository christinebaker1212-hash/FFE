"""Game state check for the SGB (or DMG) run in mGBA: NES RAM of the GB build at NES frames
K1, K2, ... (sgbrun --nshot with SGBRUN_RAM) against the NES build at those NMIs, with the
battleseq input. Prints the differing bytes (page 1 and the sound bytes $B4-$D5 vary with
the moment of the snapshot).
usage: PYTHONPATH=build/emu sgbram.py NES GB K1,K2,... [--input MODE] [--dmg | --cgb]"""
import os, sys, subprocess, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cynes import NES
import battleseq

args = sys.argv[1:]
mode = 'fight'
if '--input' in args:
    k = args.index('--input'); mode = args[k + 1]; del args[k:k + 2]
dmg = '--dmg' in args
if dmg: args.remove('--dmg')
cgb = '--cgb' in args
if cgb: args.remove('--cgb')
checks = [int(x) for x in args[2].split(',')]
last = max(checks) + 2
nes = NES(args[0])
tmp = tempfile.mkdtemp()
sram = bytearray(0x8000)
for i in range(0x2000): sram[i] = nes[0x6000 + i]
open(os.path.join(tmp, 'sram.bin'), 'wb').write(sram)
pads = bytearray(last + 2); ram = {}; f = 0
while nes.nmi_count < last:
    nes.controller = battleseq.pad_for(mode, f); k0 = nes.nmi_count; nes.step(1); f += 1
    for j in range(k0 + 1, min(nes.nmi_count, last) + 1):
        pads[j] = nes.pad_history[j & 0xFF]
        if j in checks: ram[j] = bytes(nes.nmi_ram)
open(os.path.join(tmp, 'pads.bin'), 'wb').write(pads)
exe = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'build', 'sgbrun')
cmd = [exe, args[1], str(last * 4), os.path.join(tmp, 'r'), '--padfile', os.path.join(tmp, 'pads.bin'),
       '--sram', os.path.join(tmp, 'sram.bin')] + sum([['--nshot', str(c)] for c in checks], []) + (['--dmg'] if dmg else []) + (['--cgb'] if cgb else [])
print(subprocess.run(cmd, capture_output=True, text=True, env=dict(os.environ, SGBRUN_RAM='1')).stdout.strip().splitlines()[-1])
bad = 0
for c in checks:
    g = open(os.path.join(tmp, 'r_n%05d.ram' % c), 'rb').read(); n = ram[c]
    d = [i for i in range(0x800) if g[i] != n[i] and not 0x100 <= i < 0x200 and not 0xB4 <= i <= 0xD5]
    bad += len(d) > 0
    print(c, len(d), ' '.join('%03X' % i for i in d[:16]))
print('checkpoints with differences:', bad)
