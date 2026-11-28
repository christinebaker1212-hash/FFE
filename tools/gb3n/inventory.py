"""FF3's routines from the listing (build/ref/ff3/ff3j.asm, never committed), for the core rewrite
(docs/ff3-gb-rewrite.md): each routine's bank / address / size / name, whether the English ROM still
has the listing's bytes there (the MMC5 conversion and the English patch change some), and whether our
code has its translation (a label fBB_AAAA in tools/gb3n/src, or fe_AAAA for the kept battle rules).

usage: inventory.py [--bank 3F] [--todo]     writes build/ff3_routines.txt, prints a summary
(no game code or data is written to the repo; the output goes to build/, which is git-ignored)"""
import os, re, sys, glob, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
LISTING = os.path.join(ROOT, 'build', 'ref', 'ff3', 'ff3j.asm')
EN_ROM = os.path.join(ROOT, 'build', 'ff3_en.nes')
OUT = os.path.join(ROOT, 'build', 'ff3_routines.txt')
FIXED = {0x3E: 126, 0x3F: 127}            # the English MMC5 build runs patched copies of the fixed banks

INS = re.compile(r'^([0-9A-F]{2})/([0-9A-F]{4}): ((?:[0-9A-F]{2} )+)\s*([A-Z]{3})?')
HDR = re.compile(r'^; \[ (.*) \]')


def routines():
    """[(bank, addr, name, [(addr, bytes)])] in listing order; a routine runs from its "[ name ]"
    header to the next header"""
    out = []
    cur = None
    for line in open(LISTING, encoding='utf-8', errors='replace'):
        h = HDR.match(line)
        if h:
            cur = [None, None, h.group(1).strip(), []]
            out.append(cur)
            continue
        m = INS.match(line)
        if m and cur is not None and m.group(4):
            b, a = int(m.group(1), 16), int(m.group(2), 16)
            if cur[0] is None:
                cur[0], cur[1] = b, a
            if b == cur[0]:
                cur[3].append((a, bytes(int(x, 16) for x in m.group(3).split())))
    return [r for r in out if r[0] is not None]


def en_bytes(prg, bank, addr, n):
    b = FIXED.get(bank, bank)
    o = b * 0x2000 + (addr & 0x1FFF)
    return prg[o:o + n]


def ours():
    have = set()
    for f in glob.glob(os.path.join(HERE, 'src', '*.s')):
        for m in re.finditer(r'^f([0-9A-F]{2})_([0-9A-F]{4}):', open(f).read(), re.M):
            have.add((int(m.group(1), 16), int(m.group(2), 16)))
        for m in re.finditer(r'^fe_([0-9A-F]{4}):', open(f).read(), re.M):
            have.add(('fe', int(m.group(1), 16)))
    return have


def main():
    a = sys.argv[1:]
    only = int(a[a.index('--bank') + 1], 16) if '--bank' in a else None
    d = open(EN_ROM, 'rb').read()
    prg = d[16:16 + d[4] * 0x4000]
    have = ours()
    rows = []
    summ = collections.Counter()
    for bank, addr, name, ins in routines():
        if only is not None and bank != only:
            continue
        n = len(ins)
        same = all(en_bytes(prg, bank, x, len(by)) == by for x, by in ins)
        done = (bank, addr) in have or (bank in (0x30, 0x31, 0x34, 0x35) and ('fe', addr) in have)
        st = 'ours' if done else 'todo'
        rows.append('%02X/%04X %4d %-7s %-4s %s' % (bank, addr, n, 'same' if same else 'CHANGED', st, name))
        summ[(bank, st)] += n
    open(OUT, 'w').write('\n'.join(rows) + '\n')
    if '--todo' in a:
        print('\n'.join(r for r in rows if ' todo ' in r))
    banks = sorted(set(b for b, _ in summ))
    for b in banks:
        t = summ[(b, 'todo')]; o = summ[(b, 'ours')]
        print('bank %02X: %5d instructions translated, %5d to do' % (b, o, t))
    print('written', os.path.relpath(OUT, ROOT))


if __name__ == '__main__':
    main()
