"""The GB sprite conversion checked against its own input: at every $4014 write the NES
sprite page (GB WRAM $C200 + page) is converted in Python with the camera and compared with
the GB's OAM shadow after the conversion. Reports GB sprites with no source and sources
missing on the GB.
usage: PYTHONPATH=build/emu oamconv.py NES GB SCRIPT K0 K1 [CAMX CAMY]"""
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
fr = fieldseq.frames_for(script); f = 0; pads = {}
while nes.nmi_count < k1 + 2 and f < len(fr) + 10:
    nes.controller = fr[f] if f < len(fr) else 0; k = nes.nmi_count; nes.step(1); f += 1
    for j in range(k + 1, nes.nmi_count + 1): pads[j] = nes.pad_history[j & 0xFF]
gb.feed_pads(sym, lambda n: pads.get(n + 1))
pb = gb.pb; st = {'src': None, 'bad': 0, 'n': 0}
def h_in(ctx):
    k = gb_nmi(gb)
    if k0 <= k <= k1:
        page = pb.register_file.A & 7
        st['src'] = bytes(pb.memory[0xC000 + page * 256 + i] for i in range(256))
def h_out(ctx):
    src = st['src']; st['src'] = None
    if src is None: return
    m = pb.memory; st['n'] += 1
    got = [(m[0xCC00 + 4 * i], m[0xCC01 + 4 * i]) for i in range(40)]
    got = [g for g in got if 0 < g[0] < 160 and 0 < g[1] < 168]
    want = []
    for i in range(64):
        y, t, a, x = src[4 * i:4 * i + 4]
        if y >= 0xEF: continue
        gy = y + 17 - camy * 8
        gx = x + 8 - camx * 8
        if 0 <= gy < 160 and 0 <= gx < 168 and gy and gx: want.append((gy, gx))
    extra = sorted(set(got) - set(want)); miss = sorted(set(want) - set(got))
    if extra or miss:
        st['bad'] += 1
        if st['bad'] <= 12: print('wait %d: GB extra %s  missing %s' % (gb_nmi(gb), extra[:6], miss[:6]))
b, a = sym['rt_io_w4014']; pb.hook_register(b, a, h_in, None)
b, a = sym['rt_io_w4014.end']; pb.hook_register(b, a, h_out, None)
while gb_nmi(gb) < k1: pb.tick()
print('conversions %d, wrong %d' % (st['n'], st['bad']))
