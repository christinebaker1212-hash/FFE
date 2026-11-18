"""Coverage of a field input script (fieldseq.py) on a NES ROM, for the recompiler.
usage: COV_LOG=OUT.bin PYTHONPATH=build/emu covfield.py ROM SCRIPT FRAMES [--poke ADDR=VAL,...]
(work RAM patches at frame 3700, as fieldseq.py)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fieldseq
from cynes import NES

rom, script, frames = sys.argv[1], sys.argv[2], int(sys.argv[3])
pokes = [tuple(int(x, 16) for x in kv.split('=')) for kv in sys.argv[sys.argv.index('--poke') + 1].split(',') if kv] if '--poke' in sys.argv else []
fr = fieldseq.frames_for(script)
n = NES(rom)
for f in range(frames):
    if f == 3700 and pokes:
        import battleseq
        st = n.save()
        for a, v in pokes: st[battleseq.SRAM_STATE + a - 0x6000] = v
        n.load(st)
    n.controller = fr[f] if f < len(fr) else 0
    n.step(1)
print('script', script, 'frames', frames, 'crashed', n.has_crashed)
