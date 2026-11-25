"""RAM map of the native build's sources: every `ds` in a `section wram/hram, $ADDR`, overlaps
reported (the assembler checks ROM sections only, not RAM), free gaps listed.

usage: python3 tools/gbn/rammap.py                 overlaps only
       python3 tools/gbn/rammap.py LO HI           also the variables in $LO-$HI
       python3 tools/gbn/rammap.py --free LO HI    also the unused gaps (4 bytes or more) in $LO-$HI
Known unions (one screen's buffer reusing another's: the field's queue $C100-$C8FF under the
battle, the battle's line / save buffers under the transition and the gradient, the airship's
view under the battle stage) are listed too; read their comments before moving anything.
Buffers defined by equates (GR_FA = $CBA0 ...) are not seen: grep `= $C` / `= $D` as well."""
import re, glob, os, sys
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'src')


def consts():
    c = {}
    for f in glob.glob(os.path.join(SRC, '*.s')):
        for l in open(f, encoding='latin-1'):
            m = re.match(r'\s*([A-Za-z_]\w*)\s*=\s*([^;]+)', l)
            if m:
                c[m.group(1)] = m.group(2).strip()
    return c


def ev(x, c, depth=0):
    x = x.strip()
    for k in sorted(c, key=len, reverse=True):
        if depth < 4 and re.search(r'\b%s\b' % k, x):
            v = ev(c[k], c, depth + 1)
            if v is None:
                return None
            x = re.sub(r'\b%s\b' % k, str(v), x)
    try:
        return eval(x.replace('$', '0x').replace('%', '0b'), {})
    except Exception:
        return None


def items():
    c = consts(); out = []
    for f in sorted(glob.glob(os.path.join(SRC, '*.s'))):
        cur = None
        for i, l in enumerate(open(f, encoding='latin-1')):
            s = l.split(';')[0]
            m = re.match(r'\s*section\s+(\w+)\s*,\s*(\$[0-9A-Fa-f]+)', s)
            if m:
                cur = int(m.group(2)[1:], 16) if m.group(1) in ('wram', 'hram') else None
                continue
            if re.match(r'\s*section', s):
                cur = None; continue
            m = re.match(r'\s*(?:([\w.]+):)?\s*ds\s+(.+)', s)
            if m and cur is not None:
                n = ev(m.group(2), c)
                if n is None:
                    print('? %s:%d %s' % (os.path.basename(f), i + 1, s.strip())); continue
                out.append((cur, cur + n, m.group(1) or '', os.path.basename(f), i + 1)); cur += n
    return sorted(out)


def main():
    it = items()
    for a, b in zip(it, it[1:]):
        if b[0] < a[1]:
            print('OVERLAP $%04X-$%04X %s (%s:%d) / $%04X %s (%s:%d)' % (a[0], a[1] - 1, a[2], a[3], a[4], b[0], b[2], b[3], b[4]))
    a = sys.argv[1:]
    if a and a[0] == '--free':
        lo, hi = int(a[1], 16), int(a[2], 16); used = bytearray(0x10000)
        for x0, x1, *_ in it:
            for x in range(x0, min(x1, 0x10000)):
                used[x] = 1
        x = lo
        while x < hi:
            if used[x]:
                x += 1; continue
            y = x
            while y < hi and not used[y]:
                y += 1
            if y - x >= 4:
                print('free $%04X-$%04X (%d)' % (x, y - 1, y - x))
            x = y
    elif len(a) == 2:
        lo, hi = int(a[0], 16), int(a[1], 16)
        for x0, x1, n, f, ln in it:
            if lo <= x0 < hi:
                print('$%04X-$%04X %s (%s:%d)' % (x0, x1 - 1, n, f, ln))


if __name__ == '__main__':
    main()
