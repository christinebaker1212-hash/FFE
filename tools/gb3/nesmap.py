"""Where the FF3 GB build still runs "the NES": the translated code's calls into the NES-hardware
layer of the runtime (PPU / MMC5 / APU / joypad shims) and into the 6502-emulation glue, by
routine of the everything8215 disassembly (routine headers "; [ name ]" in build/ff3/src_gb), and,
with a profile, the share of GB time each routine costs. The worklist for replacing NES-style code
with native Game Boy code (docs/ff3-native-plan.md).

usage: nesmap.py ROM.gbc [PROF.txt] [--top N]
  ROM.gbc: a build (its .gbc.s and .sym are read); PROF.txt: sgbrun SGBRUN_PROF2=K output with
  SGBRUN_PROF_SP (P / S line pairs; tools/gb3/lagcheck.py env LAG_OUT=FILE keeps it)."""
import sys, os, re, glob, bisect, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
KIND = [  # (prefix, class)
    ('rt_ppu', 'PPU'), ('rt_io_r4016', 'joypad'), ('rt_io_w4016', 'joypad'), ('rt_io_w4014', 'PPU'),
    ('rt_apu', 'APU'), ('rt_io', 'APU'), ('rt_mmc_w51', 'MMC5 bank'), ('rt_mmc_w5105', 'PPU'),
    ('rt_mmc_w52', 'MMC5 IRQ'), ('rt_mmc_r52', 'MMC5 IRQ'), ('rt_mmc_w58', 'GB layout reg'),
    ('rt_izy', 'glue'), ('rt_izx', 'glue'), ('rt_rd_', 'glue'), ('rt_lda_', 'glue'), ('rt_sta_', 'glue'),
    ('rt_get_p', 'glue'), ('rt_set_p', 'glue'), ('rt_fcs', 'glue'), ('rt_farcall', 'glue'),
    ('rt_dyn', 'glue'), ('rt_jmp_ind', 'glue'), ('rt_unwind', 'glue'), ('rt_svc', 'save RAM'),
    ('rt_copy', 'glue'), ('rt_wait', 'frame wait'), ('nat_', 'native'), ('jp nat_', 'native'),
]


def kind_of(name):
    for p, k in KIND:
        if name.startswith(p): return k
    return None


def routines():
    """{space: sorted [(addr, name)]} from the disassembly's routine headers"""
    out = collections.defaultdict(list)
    for f in glob.glob(os.path.join(ROOT, 'build', 'ff3', 'src_gb', '*.asm')):
        b = os.path.basename(f)[:-4]
        sp = 'ex' if b == 'exram' else 'fix' if b in ('bank7E', 'bank7F') else 'p' + b[4:].lower()
        head = None
        for l in open(f, errors='replace'):
            m = re.match(r'^; \[ (.*) \]', l)
            if m: head = m.group(1); continue
            m = re.match(r'^(L[0-9A-F]{2}_|F)([0-9A-F]{4}):', l)
            if m and head:
                out[sp].append((int(m.group(2), 16), head)); head = None
    for sp in list(out):
        out[sp].sort()
        if sp[0] == 'p': out['b' + sp[1:]] = out[sp]       # (the translator's 'b' spaces: one window)
    return out


def routine_of(R, sp, a):
    s = R.get(sp, [])
    i = bisect.bisect_right(s, (a, '￿')) - 1
    return '%s:%04X %s' % (sp, s[i][0], s[i][1]) if i >= 0 else '%s:? (before the first header)' % sp


def static(src, R):
    """per routine: calls into the runtime by class"""
    per = collections.defaultdict(collections.Counter); tot = collections.Counter()
    cur = None
    for l in open(src, errors='replace'):
        m = re.match(r'^L_([a-z0-9]+)_([0-9A-F]{4}):', l)
        if m: cur = (m.group(1), int(m.group(2), 16)); continue
        m = re.match(r'^\s+(call|jp)\s+(?:[nz]?c?,\s*)?([A-Za-z_][\w.]*)', l)
        if not (m and cur): continue
        k = kind_of(m.group(2))
        if k is None: continue
        r = routine_of(R, *cur)
        per[r][k] += 1; tot[k] += 1
    return per, tot


def main():
    argv = sys.argv[1:]; top = 40
    if '--top' in argv: i = argv.index('--top'); top = int(argv[i + 1]); del argv[i:i + 2]
    args = argv
    rom = args[0]; src = rom + '.s'; symf = os.path.splitext(rom)[0] + '.sym'
    R = routines()
    per, tot = static(src, R)
    print('static calls into the runtime by class:', dict(tot.most_common()))
    hw = ('PPU', 'MMC5 bank', 'MMC5 IRQ', 'APU', 'joypad')
    rank = sorted(per.items(), key=lambda kv: -sum(kv[1][k] for k in hw))
    print('\nroutines with the most NES-hardware call sites (PPU / MMC5 / APU / joypad):')
    for r, c in rank[:top]:
        n = sum(c[k] for k in hw)
        if not n: break
        print('  %3d  %-58s %s' % (n, r[:58], ' '.join('%s %d' % (k, c[k]) for k in hw + ('glue',) if c[k])))
    if len(args) < 2: return
    syms = collections.defaultdict(list)
    for l in open(symf):
        if ':' not in l or l.startswith(';'): continue
        a, n = l.split(); b, o = a.split(':'); syms[int(b, 16)].append((int(o, 16), n))
    for b in syms: syms[b].sort()
    def sym(b, a):
        if a < 0x4000: b = 0
        s = syms.get(b, []); i = bisect.bisect_right(s, (a, '￿')) - 1
        while i >= 0 and s[i][1].startswith('.'): i -= 1
        return s[i][1] if i >= 0 else '?'
    def nes_of(label):
        m = re.match(r'L_([a-z0-9]+)_([0-9A-F]{4})', label)
        return routine_of(R, m.group(1), int(m.group(2), 16)) if m else None
    lines = open(args[1]).read().splitlines()
    buckets = collections.Counter(); byrt = collections.Counter(); n = 0
    for i, l in enumerate(lines):
        if not l.startswith('P '): continue
        _, ba, _ = l.split(); b, a = (int(x, 16) for x in ba.split(':'))
        nm = sym(b, a); n += 1
        if nm.startswith('L_'):
            buckets['game code (translated)'] += 1; byrt[nes_of(nm)] += 1; continue
        caller = None
        if i + 1 < len(lines) and lines[i + 1].startswith('S '):
            _, cb, _ = lines[i + 1].split(); b2, a2 = (int(x, 16) for x in cb.split(':'))
            c = sym(b2, a2)
            if c.startswith('L_'): caller = nes_of(c)
        base = nm.split('.')[0]
        k = kind_of(base) or ('vblank / interrupts' if base in ('vblank_isr', 'stat_isr', 'mnu_isr', 'wrap_isr',
                                                              'map_flush', 'hd_flush', 'hram_dma', 'load_palettes')
                              else 'frame wait' if base in ('rt_wait_nmi', 'wait_vbl', 'rt_async') else
                              'PPU' if base in ('attr_apply', 'cell_map', 'map_mark', 'tile_mark', 'wc_setup',
                                                'ppu_addr_inc', 'vput0', 'vput1', 'oam_conv', 'rt_oam')
                              else 'runtime other: ' + base)
        buckets[k] += 1
        if caller and k not in ('frame wait', 'vblank / interrupts'): byrt[caller + '  [via %s]' % k] += 1
    print('\nGB time by class (%d samples):' % n)
    for k, v in buckets.most_common(25): print('  %5.1f%%  %s' % (100.0 * v / n, k))
    print('\nGB time by disassembly routine (translated code, and runtime helpers by caller):')
    for k, v in byrt.most_common(top): print('  %5.1f%%  %s' % (100.0 * v / n, k))


if __name__ == '__main__':
    main()
