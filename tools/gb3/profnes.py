"""Group sgbrun SGBRUN_PROF2 samples of translated code by NES routine (the listing's titles
in the generated source build/ff3/src_en/*.asm); bank-0 runtime samples by helper.
usage: profnes.py ROM.sym SRCDIR PROF.txt FROM TO [--top N]"""
import sys, os, re, bisect, collections, json, glob
args = [a for a in sys.argv[1:] if not a.startswith('--')]
top = int(sys.argv[sys.argv.index('--top') + 1]) if '--top' in sys.argv else 40
sym_p, srcdir, prof, lo, hi = args[0], args[1], args[2], int(args[3]), int(args[4])
syms = collections.defaultdict(list)
for l in open(sym_p):
    if ':' not in l or l.startswith(';'): continue
    a, n = l.split(); b, o = a.split(':'); syms[int(b, 16)].append((int(o, 16), n))
for b in syms: syms[b].sort()
# routine titles per (bank file, NES address)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ff3code
m = json.load(open(os.path.join(srcdir, 'map.json')))
sp, key = ff3code.spaces_from_map(m)
titles = collections.defaultdict(list)          # space -> [(addr, title)]
for f in glob.glob(os.path.join(srcdir, '*.asm')):
    nm = os.path.basename(f)[:-4]
    b = 128 if nm == 'exram' else int(nm[4:], 16)
    space, base = key[b]
    org = int(m['base'][str(b)]); pc = None; title = None
    for line in open(f):
        t = re.match(r'^; \[ (.*) \]', line)
        if t: title = t.group(1); continue
        lab = re.match(r'^(\w+):', line)
        if lab and title:
            n = lab.group(1)
            a = int(n[-4:], 16) if re.match(r'^(L[0-9A-F]{2}_|F|X)[0-9A-F]{4}$', n[-9:] if n.startswith('L') else n) else None
            if a is not None: titles[space].append((a, title)); title = None
for s_ in titles: titles[s_].sort()
def routine(space, addr):
    t = titles.get(space, [])
    i = bisect.bisect_right(t, (addr, '\xff')) - 1
    return '%s:%04X %s' % (space, t[i][0], t[i][1][:40]) if i >= 0 else '%s:?' % space
c = collections.Counter(); tot = 0
for l in open(prof):
    if not l.startswith('P '): continue
    _, ba, n = l.split(); n = int(n)
    if not lo <= n < hi: continue
    b, a = (int(x, 16) for x in ba.split(':'))
    if a < 0x4000: b = 0
    s = syms.get(b, [])
    i = bisect.bisect_right(s, (a, '\xff')) - 1
    while i >= 0 and '.' in s[i][1]: i -= 1
    nm = s[i][1] if i >= 0 else '?'
    mm = re.match(r'^L_(\w+)_([0-9A-F]{4})', nm)
    k = routine(mm.group(1), int(mm.group(2), 16)) if mm and b else '[rt] ' + nm
    c[k] += 1; tot += 1
for k, v in c.most_common(top): print('%6d %5.1f%%  %s' % (v, 100.0 * v / tot, k))
print('samples', tot)
