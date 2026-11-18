"""Coverage of a battle input mode (battleseq.py: walk into the battle, then the mode),
for the recompiler.
usage: COV_LOG=OUT.bin PYTHONPATH=build/emu covbattle.py ROM MODE FRAMES [--poke ADDR=VAL,...] [--form F]
(pokes at frame 6100, in the battle, as battleseq.py / firstdiff.py; --form: the battle is
formation F (formations.patched; the patched instructions keep their size, so the log
fits the unpatched ROM))"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import battleseq
from cynes import NES

rom, mode, frames = sys.argv[1], sys.argv[2], int(sys.argv[3])
pokes = [tuple(int(x, 16) for x in kv.split('=')) for kv in sys.argv[sys.argv.index('--poke') + 1].split(',') if kv] if '--poke' in sys.argv else []
if '--form' in sys.argv:
    import formations, tempfile
    f = int(sys.argv[sys.argv.index('--form') + 1])
    tmp = os.path.join(tempfile.mkdtemp(), 'f.nes')
    open(tmp, 'wb').write(formations.patched(open(rom, 'rb').read(), f))
    rom = tmp
n = NES(rom)
for f in range(frames):
    if f == 6100 and pokes:
        st = n.save()
        for a, v in pokes: battleseq.poke_state(st, a, v)
        n.load(st)
    n.controller = battleseq.pad_for(mode, f)
    n.step(1)
print('mode', mode, 'frames', frames, 'crashed', n.has_crashed)
