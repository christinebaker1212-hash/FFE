"""Summarise an sgbrun SGBRUN_PROF2 sample list (P BB:AAAA n lines) by routine (.sym).
usage: profsum.py ROM.sym PROF.txt [FROM_WAIT [TO_WAIT]] [--top N]"""
import sys, bisect, collections
args = [a for a in sys.argv[1:] if not a.startswith('--')]
top = int(sys.argv[sys.argv.index('--top') + 1]) if '--top' in sys.argv else 30
syms = collections.defaultdict(list)
for l in open(args[0]):
    if ':' not in l or l.startswith(';'): continue
    a, n = l.split()
    if '.' in n: continue                      # local labels: fold into their routine
    b, o = a.split(':'); syms[int(b, 16)].append((int(o, 16), n))
for b in syms: syms[b].sort()
lo = int(args[2]) if len(args) > 2 else 0; hi = int(args[3]) if len(args) > 3 else 1 << 30
c = collections.Counter(); tot = 0
for l in open(args[1]):
    if not l.startswith('P '): continue
    _, ba, n = l.split(); n = int(n)
    if not lo <= n < hi: continue
    b, a = ba.split(':'); b = int(b, 16); a = int(a, 16)
    if a < 0x4000: b = 0
    s = syms.get(b, [])
    i = bisect.bisect_right(s, (a, '\xff')) - 1
    c[s[i][1] if i >= 0 else '%02X:?' % b] += 1; tot += 1
for n, k in c.most_common(top): print('%6d %5.1f%%  %s' % (k, 100.0 * k / tot, n))
print('samples', tot)
