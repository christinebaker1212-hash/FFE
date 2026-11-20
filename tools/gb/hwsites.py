"""Inventory of the NES-hardware layer still reached by the recompiled FF1 code (the plan in
docs/gb-native-presentation.md, step 1): every call from compiled NES code into the PPU,
OAM-DMA, APU, joypad or mapper layer of the runtime, grouped by the disassembly routine it
belongs to (build/ff1dis.map from tools/gb/ff1dis.py).

usage: python3 tools/gb/hwsites.py GB.s [--map build/ff1dis.map] [--out FILE]
  GB.s: the assembly build.py writes next to the ROM (OUT.gb.s).
  Prints per subsystem the routines and their call counts; FILE (default
  build/hwsites.txt) gets every site (space:addr routine call)."""
import os, re, sys, bisect, collections

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
HW = re.compile(r'\b(?:call|jp)\s+(rt_ppu_[wr]\w*|rt_io_[wr]40\w\w|rt_apu_w\w*|rt_mmc_[wr]\w+)')
LBL = re.compile(r'^(?:\w+_)?L_([a-z]\w*?)_([0-9A-F]{4}):')
SUB = {'rt_ppu': 'picture (PPU)', 'rt_io_w4014': 'sprites (OAM DMA)', 'rt_apu': 'sound (APU)',
       'rt_io_w4016': 'joypad', 'rt_io_r4016': 'joypad', 'rt_mmc': 'mapper / GB registers'}


def subsystem(call):
    for k, v in SUB.items():
        if call.startswith(k): return v
    return 'other I/O'


def main():
    a = sys.argv[1:]
    mp = a[a.index('--map') + 1] if '--map' in a else os.path.join(ROOT, 'build', 'ff1dis.map')
    out = a[a.index('--out') + 1] if '--out' in a else os.path.join(ROOT, 'build', 'hwsites.txt')
    routines = collections.defaultdict(list)          # space -> [(addr, name, length)]
    for line in open(mp):
        sa, name, ln, _ = line.split()
        sp, ad = sa.split(':'); routines[sp].append((int(ad, 16), name, int(ln)))
    for v in routines.values(): v.sort()
    keys = {sp: [x[0] for x in v] for sp, v in routines.items()}

    def owner(sp, ad):
        i = bisect.bisect_right(keys.get(sp, []), ad) - 1
        if i < 0: return '?'
        a0, name, ln = routines[sp][i]
        return name if ad - a0 < ln * 3 + 16 else '?(after %s)' % name

    sites = []
    cur = None
    for line in open(a[0]):
        m = LBL.match(line)
        if m: cur = (m.group(1), int(m.group(2), 16)); continue
        m = HW.search(line)
        if m and cur: sites.append((cur[0], cur[1], m.group(1)))
    sites = sorted(set(sites))
    by = collections.defaultdict(collections.Counter)
    with open(out, 'w') as f:
        for sp, ad, call in sites:
            o = owner(sp, ad)
            f.write('%s:%04X %s %s\n' % (sp, ad, o, call))
            by[subsystem(call)][o] += 1
    print('%d call sites into the NES-hardware layer' % len(sites))
    for sub, c in sorted(by.items(), key=lambda kv: -sum(kv[1].values())):
        print('%s: %d sites in %d routines' % (sub, sum(c.values()), len(c)))
        print('   ' + ', '.join('%s %d' % kv for kv in c.most_common(18)))


if __name__ == '__main__':
    main()
