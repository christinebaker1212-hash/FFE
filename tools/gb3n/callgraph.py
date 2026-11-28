"""FF3's call graph from the listing (build/ref/ff3/ff3j.asm, never committed), for the core rewrite's order
(docs/ff3-gb-rewrite.md): JSR / JMP targets of each routine, with the bank of a $8000-$BFFF target taken
from the bank switch before it (LDA #n + JSR $FF06 / FF09 / FF03 ..., JSR $EB28 = $3C/$3D, $EB23 =
$2C/$2D; otherwise the routine's own bank pair). Prints the routines reachable from a start and their
status (inventory.py's).

usage: callgraph.py 3F/E1DC [--stop 3C,3D,...] [--todo]   (banks not followed with --stop)"""
import os, re, sys, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import inventory

INS = re.compile(r'^([0-9A-F]{2})/([0-9A-F]{4}): ((?:[0-9A-F]{2} )+)\s*([A-Z]{3})\s*(\S*)')
SWITCH = {0xFF06: 'b8', 0xFF09: 'bA', 0xFF03: 'seq', 0xFF0C: 'b8', 0xFF1F: 'bA', 0xFF17: 'seq'}


def pair(bank):
    """the bank pair a routine of `bank` runs with: (bank at $8000, bank at $A000)"""
    return (bank & ~1, bank | 1)


def graph():
    """{(bank, addr): set((bank, addr) targets)} by routine (routine = from a header to the next)"""
    starts = {}
    for b, a, name, ins in inventory.routines():
        starts[(b, a)] = name
    calls = collections.defaultdict(set)
    cur = None
    st = None
    last_imm = None
    for line in open(inventory.LISTING, encoding='utf-8', errors='replace'):
        m = INS.match(line)
        if not m:
            continue
        b, a = int(m.group(1), 16), int(m.group(2), 16)
        if (b, a) in starts:
            cur = (b, a)
            st = list(pair(b)) if b < 0x3E else [None, None]
        if cur is None:
            continue
        op, arg = m.group(4), m.group(5)
        if op == 'LDA' and arg.startswith('#$'):
            last_imm = int(arg[2:], 16)
            continue
        if op in ('JSR', 'JMP') and arg.startswith('$') and len(arg) == 5:
            t = int(arg[1:], 16)
            if t in SWITCH and last_imm is not None:
                k = SWITCH[t]
                if k == 'b8': st[0] = last_imm
                elif k == 'bA': st[1] = last_imm
                else: st[0], st[1] = last_imm, last_imm + 1
            elif t == 0xEB28:
                st = [0x3C, 0x3D]
            elif t == 0xEB23:
                st = [0x2C, 0x2D]
            if t >= 0xC000:
                tb = 0x3E if t < 0xE000 else 0x3F
            elif t >= 0x8000:
                tb = st[0] if t < 0xA000 else st[1]
            else:
                tb = None
            if tb is not None:
                calls[cur].add((tb, t))
        last_imm = None if op != 'LDA' else last_imm
    return calls, starts


def owner(starts, b, a):
    """the routine containing (b, a): the nearest start at or before it in that bank"""
    best = None
    for (sb, sa) in starts:
        if sb == b and sa <= a and (best is None or sa > best[1]):
            best = (sb, sa)
    return best


def main():
    args = sys.argv[1:]
    b, a = args[0].split('/')
    start = (int(b, 16), int(a, 16))
    stop = set(int(x, 16) for x in args[args.index('--stop') + 1].split(',')) if '--stop' in args else set()
    calls, starts = graph()
    status = {}
    for line in open(inventory.OUT):
        p = line.split()
        sb, sa = p[0].split('/')
        status[(int(sb, 16), int(sa, 16))] = (int(p[1]), p[3], ' '.join(p[4:]))
    seen, todo = set(), [start]
    while todo:
        r = todo.pop()
        r = owner(starts, *r) or r
        if r in seen:
            continue
        seen.add(r)
        if r[0] in stop and r != start:
            continue
        for t in calls.get(r, ()):
            todo.append(t)
    total = 0
    for r in sorted(seen):
        n, st, name = status.get(r, (0, '?', starts.get(r, '')))
        if '--todo' in args and st != 'todo':
            continue
        total += n
        print('%02X/%04X %4d %-4s %s%s' % (r[0], r[1], n, st, name, '  (not followed)' if r[0] in stop else ''))
    print('%d routines, %d instructions listed' % (len(seen), total))


if __name__ == '__main__':
    main()
