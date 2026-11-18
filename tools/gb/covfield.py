"""Coverage of a field input script (fieldseq.py) on a NES ROM, for the recompiler.
usage: COV_LOG=OUT.bin PYTHONPATH=build/emu covfield.py ROM SCRIPT FRAMES"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fieldseq
from cynes import NES

rom, script, frames = sys.argv[1], sys.argv[2], int(sys.argv[3])
fr = fieldseq.frames_for(script)
n = NES(rom)
for f in range(frames):
    n.controller = fr[f] if f < len(fr) else 0
    n.step(1)
print('script', script, 'frames', frames, 'crashed', n.has_crashed)
