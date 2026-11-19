"""Attribute runtime-helper samples to their callers (sgbrun SGBRUN_PROF2 + SGBRUN_PROF_SP: each
P line is followed by an S line with the word at SP and the mapped bank).
usage: profcall.py ROM.sym PROF.txt FROM TO [--top N] [--helpers a,b,..]
Prints, for samples whose PC is in a bank-0 helper, the translated routine the return
address points into (labels L_<space>_<addr> of the NES instruction after the call)."""
import sys, bisect, collections
args = [a for a in sys.argv[1:] if not a.startswith('--')]
top = int(sys.argv[sys.argv.index('--top') + 1]) if '--top' in sys.argv else 40
syms = collections.defaultdict(list)
for l in open(args[0]):
    if ':' not in l or l.startswith(';'): continue
    a, n = l.split()
    b, o = a.split(':'); syms[int(b, 16)].append((int(o, 16), n))
for b in syms: syms[b].sort()
def name(b, a, local=True):
    if a < 0x4000: b = 0
    s = syms.get(b, [])
    i = bisect.bisect_right(s, (a, '\xff')) - 1
    while i >= 0 and not local and '.' in s[i][1]: i -= 1
    return s[i][1] if i >= 0 else '%02X:%04X' % (b, a)
lo, hi = int(args[2]), int(args[3])
c = collections.Counter(); tot = collections.Counter(); last = None
for l in open(args[1]):
    if l.startswith('P '):
        _, ba, n = l.split(); n = int(n); b, a = (int(x, 16) for x in ba.split(':'))
        last = (b, a, n)
    elif l.startswith('S ') and last:
        b, a, n = last
        if lo <= n < hi:
            fn = name(b, a, False)
            _, ba, _ = l.split(); cb, ca = (int(x, 16) for x in ba.split(':'))
            if a < 0x4000:
                tot[fn] += 1
                c[(fn, name(cb, ca, True))] += 1
        last = None
print('helper samples by caller (NES routine of the return address):')
for (h, cl), k in c.most_common(top): print('%6d  %-16s <- %s' % (k, h, cl))
