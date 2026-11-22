"""cross-bank call check (usage: xbank.py build/ff1n.sym): call / jp / jr in banked code must
target bank 0 or the same bank. Bank-0 code that calls a banked routine is listed too: it
is right only when that bank is mapped at the call (bank_call, or a helper only ever called
from that bank)."""
import re, sys, glob, os
sym = {}
for l in open(sys.argv[1]):
    a, n = l.split()[:2]; b, x = a.split(':')
    sym[n] = (int(b, 16), int(x, 16))
bad = 0
for f in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'src', '*.s'))):
    bank = None; glob_lbl = None
    for i, line in enumerate(open(f), 1):
        code = line.split(';')[0]
        m = re.match(r'\s*section\s+bank\s+(\d+)', code)
        if m: bank = int(m.group(1)); continue
        if re.match(r'\s*section\s+(wram|hram)', code): bank = None; continue
        m = re.match(r'([A-Za-z_]\w*):', code)
        if m: glob_lbl = m.group(1)
        m = re.search(r'\b(call|jp|jr)\s+(?:(?:nz|z|nc|c),\s*)?([A-Za-z_.][\w.]*)\s*$', code)
        if not m or bank is None: continue
        t = m.group(2)
        if t in ('hl',): continue
        if t.startswith('.'): t = glob_lbl + t
        if t not in sym: continue
        tb = sym[t][0]
        if tb not in (0, bank):
            bad += 1; print('%s:%d bank %d -> %s (bank %d)' % (f.split('/')[-1], i, bank, t, tb))
print(bad, 'cross-bank calls')
