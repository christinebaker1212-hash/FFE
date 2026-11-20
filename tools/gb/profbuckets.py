"""Sort an sgbrun profile (SGBRUN_PROF2 / SGBRUN_PROFC, lines 'P bank:pc wait') into buckets:
picture, glue, game code, music, sprites, timing, interrupts (docs/gb-native-presentation.md).
usage: profbuckets.py PROF SYM [--waits A-B,..] [--lagfile LAG_DUMP] [--top N]
  --lagfile: only waits whose GB frames exceed the NES frames (lagcheck LAG_DUMP)"""
import bisect, re, sys
from collections import Counter, defaultdict

BUCKETS = [   # (bucket, regex on the symbol name); first match wins
    ('music', r'^(mus_|aw$|awf$|mrd$|rt_apu_w|apu_|vscale|vol_change|hl_b|sw_clk|psh|p_|len_|nes_freq|pbase|noise|tri_|lin_|env_)'),
    ('sprites', r'^(oamconv|spr_|sprload|hle_oam_clear|anf_rows|rt_anf|spr_maps|rt_io_w4014)'),
    ('timing', r'^(rt_delay|rt_dlgdelay|rt_band|rt_wait_nmi|vpre|vshow_tramp|vshow_def)'),
    ('interrupts', r'^(vblank_isr|vbl_regs|flush_vbl|stat_isr|timer_isr|emph_bgp|hram_dma|q_drain1)'),
    ('glue', r'^(rt_farcall|xs_|xj_|rt_jp_hl|hle_pfj|hle_back|lookup|rt_dyn|rt_rd_|nes_rd|nes_wr|rt_izy|rt_izx|rt_unwind|rt_get_p|rt_set_p|rt_rts_dispatch|rt_mmc_|rt_jmp_ind|rt_io_r|read_buttons|rt_fatal)'),
    ('picture', r'.'),
]
GAME_MUSIC = [('b13', 0xB000, 0xB400)]     # the NES sound engine (game code, counted as music)

def main():
    a = sys.argv[1:]
    prof, sym = a[0], a[1]
    def opt(n):
        return a[a.index(n) + 1] if n in a else None
    waits = None
    if opt('--waits'):
        waits = set()
        for r in opt('--waits').split(','):
            x, _, y = r.partition('-'); waits.update(range(int(x), int(y or x) + 1))
    if opt('--lagfile'):
        waits = set()
        for l in open(opt('--lagfile')):
            k, g, n = map(int, l.split())
            if g > n: waits.add(k)
    syms = defaultdict(list)
    for l in open(sym):
        p = l.split()
        if len(p) != 2 or '.' in p[1]: continue
        b, ad = p[0].split(':'); syms[int(b, 16)].append((int(ad, 16), p[1]))
    for k in syms: syms[k].sort()
    keys = {k: [x[0] for x in v] for k, v in syms.items()}
    bk = Counter(); names = defaultdict(Counter); n = 0
    for l in open(prof):
        if not l.startswith('P '): continue
        _, bp, w = l.split(); w = int(w) & 0xFFFF
        if waits is not None and w not in waits: continue
        b, pc = (int(x, 16) for x in bp.split(':'))
        b = 0 if pc < 0x4000 else b
        L = syms.get(b, []); i = bisect.bisect_right(keys.get(b, []), pc) - 1
        name = L[i][1] if i >= 0 else '?'
        if re.match(r'^L_[a-z0-9]+_[0-9A-F]{4}$', name):
            sp, ad = name[2:].rsplit('_', 1); ad = int(ad, 16)
            cat = 'music' if any(sp == s and lo <= ad < hi for s, lo, hi in GAME_MUSIC) else 'game code'
        else:
            cat = next(c for c, rx in BUCKETS if re.match(rx, name))
        bk[cat] += 1; names[cat][name[:6] if cat == 'game code' else name] += 1; n += 1
    print('samples', n)
    top = int(opt('--top') or 6)
    for c, v in bk.most_common():
        print('%-11s %5.1f%%  %s' % (c, 100.0 * v / n, ', '.join('%s %d' % kv for kv in names[c].most_common(top))))

main()
