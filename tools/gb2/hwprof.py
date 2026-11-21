"""Which game routines still use the NES-hardware layer (PPU / APU / joypad / mapper
register emulation in rt/), and how often: PyBoy with firstdiff's input, a hook on each
layer entry point, the caller's NES routine from the return address (source labels).
The measure for replacing the layer with native routines (docs/ff2-gb-native-layer.md).
usage: PYTHONPATH=build/emu hwprof.py NES GB FRAMES [--random S] [--press ..] [--top N]"""
import os, sys, json, bisect, collections
sys.path.insert(0, 'tools/gb'); sys.path.insert(0, 'tools/gb2')
from cynes import NES
import firstdiff as fd
a = sys.argv[1:]
top = 45
if '--top' in a:
    k = a.index('--top'); top = int(a[k + 1]); del a[k:k + 2]
nes_path, gb_path, steps, pokes, poke_at, limit = fd.scenario(a)
_, pads, _, _, _ = fd.nes_pass(NES(nes_path), steps, limit, (), pokes, poke_at)
sym = {}; byaddr = collections.defaultdict(list)
for l in open(gb_path[:-3] + '.sym'):
    b, rest = l.split(':'); ad, n = rest.split(); b, ad = int(b, 16), int(ad, 16); sym[n] = (b, ad)
    if n.startswith('L_') and '.' not in n: byaddr[b].append((ad, n))
for b in byaddr: byaddr[b].sort()
keys = {b: [x[0] for x in v] for b, v in byaddr.items()}
# NES routine starts: labels of the source (map.json)
mp = json.load(open('build/ff2/src_gb/map.json'))
SP = {str(b): 'b%02d' % b for b in list(range(15)) + list(range(23, 31))}; SP['15'] = 'fix'; SP['16'] = 'ex'
BASE = {'fix': 0xC000, 'ex': 0x5C00}
rl = collections.defaultdict(list)
for b, d in mp['labels'].items():
    sp = SP.get(b)
    if sp is None: continue
    base = BASE.get(sp, 0x8000)
    for o, n in d.items(): rl[sp].append((base + int(o), n))
for sp in rl: rl[sp].sort()
def routine(sp, addr):
    v = rl.get(sp, []); i = bisect.bisect_right([x[0] for x in v], addr) - 1
    return '%s:%04X %s' % (sp, v[i][0], v[i][1]) if i >= 0 else '%s:?' % sp
gb = fd.GB(gb_path); m = gb.pb.memory
cnt = collections.Counter(); kinds = collections.Counter(); st = {'k': 0}
def on_wait(_):
    st['k'] = (m[0xD830] | m[0xD831] << 8) + 1
gb.pb.hook_register(*sym['rt_frame'], on_wait, None)
gb.feed_pads(sym, lambda n: pads.get(n + 1, 0))
HW = [n for n in sym if n.startswith(('rt_ppu_w', 'rt_ppu_r', 'rt_apu_w', 'rt_io_', 'rt_mmc_w')) and '.' not in n]
def hk(name):
    spv = gb.pb.register_file.SP; ret = m[spv] | m[spv + 1] << 8
    bank = m[0xFF8C] if ret >= 0x4000 else 0
    k = keys.get(bank)
    if not k: cnt[(name, 'bank%d' % bank)] += 1; return
    i = bisect.bisect_right(k, ret - 1) - 1
    lab = byaddr[bank][i][1]             # L_bNN_ADDR
    _, sp, ad = lab.split('_'); cnt[(name, routine(sp, int(ad, 16)))] += 1; kinds[name] += 1
seen = set()
for n in sorted(HW):
    if sym[n] in seen: continue
    seen.add(sym[n]); gb.pb.hook_register(*sym[n], hk, n)
last = max(pads)
while st['k'] < last - 2: gb.pb.tick()
print('frames', st['k'])
for k, v in kinds.most_common(): print('  %-16s %8d  (%.1f / frame)' % (k, v, v / st['k']))
print('by routine:')
for (n, r), v in cnt.most_common(top): print('  %8d  %-14s %s' % (v, n, r))
