"""Sprites of the GB build against the NES, frame by frame (PyBoy, DMG; GB_CGB=1 for Color).
For every frame wait k: the NES sprite table at NMI k, converted to GB screen positions with
the camera, against the GB's converted table (OAM shadow). A GB sprite with no NES sprite at
its position is reported (stale or misplaced pieces).
usage: PYTHONPATH=build/emu oamcheck.py NES GB SCRIPT K0 K1 [CAMX CAMY]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare import GB, sync_sram, gb_nmi
from cynes import NES
import fieldseq

nes_path, gb_path, script, k0, k1 = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
camx, camy = (int(sys.argv[6]), int(sys.argv[7])) if len(sys.argv) > 7 else (5, 6)
nes = NES(nes_path); gb = GB(gb_path); sync_sram(nes, gb)
sym = {}
for l in open(gb_path[:-3] + '.sym'):
    b, rest = l.split(':'); a, n = rest.split(); sym[n] = (int(b, 16), int(a, 16))
fr = fieldseq.frames_for(script); f = 0; pads = {}; oam = {}
while nes.nmi_count < k1 + 2 and f < len(fr) + 10:
    nes.controller = fr[f] if f < len(fr) else 0; k = nes.nmi_count; nes.step(1); f += 1
    for j in range(k + 1, nes.nmi_count + 1):
        pads[j] = nes.pad_history[j & 0xFF]
        oam[j] = bytes(nes.nmi_ram)[0x200:0x300]
gb.feed_pads(sym, lambda n: pads.get(n + 1))
bad = 0
SPAN = int(os.environ.get('OAM_SPAN', '2'))
for k in range(k0, k1):
    while gb_nmi(gb) < k + 1: gb.pb.tick()
    m = gb.pb.memory
    g = [(m[0xCC00 + 4 * i], m[0xCC01 + 4 * i]) for i in range(40)]
    g = {(y, x) for y, x in g if 0 < y < 160 and 0 < x < 168}
    want = set()
    for o in [oam.get(k + d) for d in range(-SPAN, SPAN + 1)]:   # (which NMI's table the GB shows)
        if o is None: continue
        for i in range(64):
            y, t, a, x = o[4 * i:4 * i + 4]
            if y >= 0xEF: continue
            gy, gx = (y + 17 - camy * 8) & 255, (x + 8 - camx * 8) & 255
            want.add((gy, gx))
    extra = g - want
    if extra:
        bad += 1
        if bad <= 15: print('wait %d: GB sprites with no NES sprite there: %s' % (k, sorted(extra)[:6]))
print('frames %d-%d: %d with stray GB sprites' % (k0, k1, bad))
