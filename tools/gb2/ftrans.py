"""Function-level front end of the FF2 GB translator (docs/ff2-gb-function-translator.md).

M1: the game's code as routines instead of a flat instruction list:
  - routines: entries (static JSR targets, dynamic targets, vectors, NMI handlers, native
    replacements' resume points), the instructions each reaches without crossing another
    entry (falling or jumping into another entry is a tail edge), its returns and calls;
  - basic blocks and a control-flow graph per routine; the call graph across banks;
  - an IR per instruction: what it reads and writes (registers A / X / Y / S, flags
    N / Z / C / V, memory with its region, index and indirection), its control effect.
Code generation still goes through translate.Emitter (byte-identical output), so the
analyses of later milestones (summaries, regions / banks, native code) build on a front
end that is checked against today's build.

Nothing here is game data: everything is read from the user's ROM and the disassembly at
build time.

usage: python3 tools/gb2/ftrans.py NES SRCDIR [--routines]   (report)"""
import os, sys
from collections import defaultdict
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from translate import Recompiler, nes_region, DEF, USE, BRANCH

# ------------------------------------------------------------------ IR

REG_USE = {'LDA': '', 'LDX': '', 'LDY': '', 'STA': 'A', 'STX': 'X', 'STY': 'Y',
           'TAX': 'A', 'TAY': 'A', 'TXA': 'X', 'TYA': 'Y', 'TXS': 'X', 'TSX': 'S',
           'ADC': 'A', 'SBC': 'A', 'AND': 'A', 'ORA': 'A', 'EOR': 'A', 'CMP': 'A', 'CPX': 'X', 'CPY': 'Y',
           'BIT': 'A', 'INX': 'X', 'DEX': 'X', 'INY': 'Y', 'DEY': 'Y', 'PHA': 'AS', 'PLA': 'S', 'PHP': 'S', 'PLP': 'S',
           'JSR': 'S', 'RTS': 'S', 'RTI': 'S'}
REG_DEF = {'LDA': 'A', 'LDX': 'X', 'LDY': 'Y', 'TAX': 'X', 'TAY': 'Y', 'TXA': 'A', 'TYA': 'A', 'TXS': 'S',
           'TSX': 'X', 'ADC': 'A', 'SBC': 'A', 'AND': 'A', 'ORA': 'A', 'EOR': 'A', 'INX': 'X', 'DEX': 'X',
           'INY': 'Y', 'DEY': 'Y', 'PHA': 'S', 'PLA': 'AS', 'PHP': 'S', 'PLP': 'S', 'JSR': 'S', 'RTS': 'S', 'RTI': 'S'}
MEM_READ = {'LDA', 'LDX', 'LDY', 'ADC', 'SBC', 'AND', 'ORA', 'EOR', 'CMP', 'CPX', 'CPY', 'BIT',
            'ASL', 'LSR', 'ROL', 'ROR', 'INC', 'DEC'}
MEM_WRITE = {'STA', 'STX', 'STY', 'ASL', 'LSR', 'ROL', 'ROR', 'INC', 'DEC'}


class Mem:
    """a memory operand: NES address (or zero-page pointer for indirect modes), its region,
    index register and indirection"""
    __slots__ = ('addr', 'region', 'index', 'ind')

    def __init__(self, addr, region, index, ind):
        self.addr, self.region, self.index, self.ind = addr, region, index, ind

    def __repr__(self):
        s = '$%04X' % self.addr
        if self.ind == 'izy': s = '($%02X),Y' % self.addr
        elif self.ind == 'izx': s = '($%02X,X)' % self.addr
        elif self.index: s += ',' + self.index
        return '%s[%s]' % (s, self.region)


class Op:
    """IR of one 6502 instruction"""
    __slots__ = ('key', 'mn', 'mem', 'imm', 'ruse', 'rdef', 'fuse', 'fdef', 'mread', 'mwrite', 'kind', 'target')

    def __repr__(self):
        a = self.mem if self.mem is not None else ('#$%02X' % self.imm if self.imm is not None else '')
        return '%s:%04X %s %s' % (self.key[0], self.key[1], self.mn, a)


def lift(rc, k):
    """IR op for the instruction at key k"""
    i = rc.insns[k]; o = Op(); o.key = k; o.mn = i.mn
    o.mem = o.imm = o.target = None
    m = i.mode
    if m == 'imm':
        o.imm = i.arg
    elif m in ('izy', 'izx'):
        o.mem = Mem(i.arg, 'ptr', 'Y' if m == 'izy' else 'X', m)
    elif m in ('zp', 'zpx', 'zpy'):
        o.mem = Mem(i.arg, 'ram', {'zpx': 'X', 'zpy': 'Y'}.get(m), None)
    elif m in ('abs', 'abx', 'aby') and i.mn not in ('JMP', 'JSR'):
        o.mem = Mem(i.arg, nes_region(i.arg), {'abx': 'X', 'aby': 'Y'}.get(m), None)
    elif m == 'ind':
        o.mem = Mem(i.arg, nes_region(i.arg), None, 'ind')
    ru = set(REG_USE.get(i.mn, '')); rd = set(REG_DEF.get(i.mn, ''))
    if m == 'acc': ru.add('A'); rd.add('A')
    if o.mem is not None and o.mem.index: ru.add(o.mem.index)
    o.ruse, o.rdef = frozenset(ru), frozenset(rd)
    o.fuse, o.fdef = frozenset(USE.get(i.mn, '')), frozenset(DEF.get(i.mn, ''))
    o.mread = o.mem is not None and i.mn in MEM_READ and m != 'acc'
    o.mwrite = o.mem is not None and i.mn in MEM_WRITE and m != 'acc'
    if i.mn in BRANCH: o.kind = 'branch'; o.target = rc.target(i, i.arg)
    elif i.mn == 'JMP': o.kind = 'jump'; o.target = rc.target(i, i.arg) if m != 'ind' else None
    elif i.mn == 'JSR': o.kind = 'call'; o.target = rc.target(i, i.arg)
    elif i.mn in ('RTS', 'RTI'): o.kind = 'return'
    elif i.mn == 'BRK': o.kind = 'stop'
    else: o.kind = 'op'
    return o


# ------------------------------------------------------------------ routines

class Routine:
    def __init__(self, entry):
        self.entry = entry
        self.keys = set()            # instructions reached from the entry (not other entries)
        self.calls = set()           # callee entries (static)
        self.dyncalls = []           # JSR / JMP to unknown targets
        self.tails = set()           # other entries reached by fall-through / jump
        self.returns = []            # RTS / RTI keys
        self.blocks = {}             # block start -> [keys]
        self.succ = {}               # block start -> [block starts in this routine]
        self.tricks = set()          # 'pla_drop', 'tsx', 'txs', 'jmp_ind', 'dyn_jump', 'ext', 'idiom'


class Program:
    def __init__(self, rc):
        self.rc = rc
        rc.classify()
        rc.liveness()
        rc.dyn = rc.dyn_targets()
        self.ops = {k: lift(rc, k) for k in rc.insns}
        self.entries = self.find_entries()
        self.routines = {e: self.walk(e) for e in sorted(self.entries)}
        self.owner = defaultdict(set)            # key -> routine entries containing it
        for e, r in self.routines.items():
            for k in r.keys: self.owner[k].add(e)
        self.callers = defaultdict(set)
        for e, r in self.routines.items():
            for c in r.calls: self.callers[c].add(e)

    def find_entries(self):
        rc = self.rc; ins = rc.insns
        e = set(k for k in rc.dyn if k in ins)
        for k, o in self.ops.items():
            if o.kind == 'call' and o.target in ins: e.add(o.target)
        for k, v in rc.g.idioms.items():                       # native replacements resume here
            r = (k[0], v[1])
            if r in ins: e.add(r)
        for k in rc.g.ext:
            if k in ins: e.add(k)
        # code no entry reaches (data-driven, the disassembly's own labels): its own routine
        reached = set()
        for x in e: reached |= self._reach(x, e)
        for k in sorted(ins):
            if k not in reached:
                e.add(k); reached |= self._reach(k, e)
        return e

    def _reach(self, start, entries):
        rc = self.rc; ins = rc.insns; seen = set(); work = [start]
        while work:
            k = work.pop()
            if k in seen or k not in ins: continue
            if k != start and k in entries: continue
            seen.add(k)
            for s in self.out(k):
                if s is not None: work.append(s)
        return seen

    def out(self, k):
        """successors inside the code (a call continues after it; returns end)"""
        o = self.ops[k]; i = self.rc.insns[k]
        if k in self.rc.g.ext: return []
        if o.kind == 'call': return [(i.space, i.addr + 3)]
        return self.rc.succ(i)

    def walk(self, entry):
        rc = self.rc; ins = rc.insns; r = Routine(entry)
        work = [entry]
        while work:
            k = work.pop()
            if k in r.keys: continue
            if k not in ins: continue
            if k != entry and k in self.entries: r.tails.add(k); continue
            r.keys.add(k); o = self.ops[k]; i = ins[k]
            if k in rc.g.ext: r.tricks.add('ext'); r.returns.append(k); continue
            if k in rc.g.idioms: r.tricks.add('idiom')
            if o.kind == 'call':
                if o.target in ins: r.calls.add(o.target)
                else: r.dyncalls.append(k)
            elif o.kind == 'return': r.returns.append(k)
            elif o.kind == 'jump' and o.target is None:
                r.tricks.add('jmp_ind' if i.mode == 'ind' else 'dyn_jump')
            if k in rc.pla_drop: r.tricks.add('pla_drop')
            if i.mn == 'TSX': r.tricks.add('tsx')
            if i.mn == 'TXS': r.tricks.add('txs')
            for s in self.out(k):
                if s is not None: work.append(s)
        self.split_blocks(r)
        return r

    def split_blocks(self, r):
        """basic blocks: starts at the entry, branch / jump targets inside the routine and
        after branches, jumps, calls (a call ends a block: the callee's effects are not
        inside it)"""
        rc = self.rc; ins = rc.insns
        starts = {r.entry}
        for k in r.keys:
            o = self.ops[k]; i = ins[k]
            if o.kind in ('branch', 'jump', 'call', 'return', 'stop') or k in rc.g.idioms:
                for s in self.out(k):
                    if s in r.keys: starts.add(s)
                if o.target in r.keys: starts.add(o.target)
        for s in starts:
            blk = []; k = s
            while k in r.keys:
                blk.append(k); o = self.ops[k]; i = ins[k]
                if o.kind != 'op' or k in rc.g.idioms or k in rc.g.ext: break
                nk = (i.space, i.addr + i.size)
                if nk in starts: break
                k = nk
            r.blocks[s] = blk
        for s, blk in r.blocks.items():
            last = blk[-1]
            r.succ[s] = [x for x in self.out(last) if x in r.blocks]

    # -------------------------------------------------------------- M3: values
    # Per routine, a forward analysis of small sets of possible values (<= VMAX, else
    # unknown) for A / X / Y / C and the zero-page bytes the routine uses as pointers,
    # with per-routine write sets so a call only forgets what the callee (or an NMI
    # handler run at a cross-bank return) can change. Facts: for each (zp),Y access the
    # possible high bytes of its pointer.
    VMAX = 4

    def write_sets(self, facts=None):
        """routine entry -> set of zero-page addresses it may write (None: any). A native
        replacement (ext / idiom) has the NES code's RAM effects, so its set is that code's.
        A (zp),Y write counts only if its pointer may point into page 0 (facts from the
        previous round of values(); none: any)."""
        rc = self.rc; ins = rc.insns; facts = facts or {}
        dynset = set(k for k in rc.dyn if k in self.routines)
        def cands(k):
            """routines a dynamic JSR / JMP at k can reach: code at its address in any space
            (absolute operand), else every dynamic target"""
            i = ins[k]
            if i.mode == 'abs':
                c = set(x for x in rc.dyn_candidates(i.arg) if x in self.routines)
                if c: return c
            return dynset
        def insn_writes(k):
            """zero-page addresses one instruction may write (None: any)"""
            o = self.ops[k]
            if not o.mwrite: return set()
            mm = o.mem
            if mm.ind == 'izy':
                f = facts.get(k)
                return set() if f and f[0] >= 0x08 else None
            if mm.ind is not None: return None
            if mm.region != 'ram': return set()
            a = mm.addr & 0x7FF
            if mm.index is None: return {a} if a < 0x100 else set()
            if ins[k].mode in ('zpx', 'zpy'):                # zp,X / zp,Y: anywhere in page 0
                b = getattr(rc.g, 'zpx_writes', {}).get(k[0])   # (unless annotated)
                return set(range(b[0], b[1] + 1)) if b else None
            return set(range(a, 0x100)) if a < 0x100 else set()   # abs,X: no wrap
        def raw(start, stop=None):
            """writes of the NES code from start (native markers ignored) until stop / RTS;
            callees by their sets (returns (set, callee entries)) or None"""
            w = set(); calls = set(); seen = set(); work = [start]
            while work:
                k = work.pop()
                if k in seen or k not in ins or k == stop: continue
                seen.add(k); o = self.ops[k]; i = ins[k]
                x = insn_writes(k)
                if x is None: return None
                w |= x
                if o.kind == 'call':
                    if o.target not in ins: calls |= cands(k)
                    else: calls.add(o.target)
                    work.append((i.space, i.addr + 3)); continue
                if o.kind == 'jump' and o.target is None: calls |= dynset; continue
                if o.kind == 'return': continue
                for s2 in rc.succ(i):
                    if s2 is None: return None
                    work.append(s2)
            return w, calls
        own = {}; deps = {}
        for e, r in self.routines.items():
            w = set(); c = set(r.calls) | set(r.tails); ok = True
            for d in r.dyncalls: c |= cands(d)
            for k in r.keys:
                if not ok: break
                if k in rc.g.ext or k in rc.g.idioms:
                    rr = raw(k, (k[0], rc.g.idioms[k][1]) if k in rc.g.idioms else None)
                    if rr is None: ok = False; break
                    w |= rr[0]; c |= rr[1]
                    continue
                x = insn_writes(k)
                if x is None: ok = False; break
                w |= x
            own[e] = w if ok else None; deps[e] = c
        ws = dict(own)
        for c in set().union(*deps.values()) if deps else ():
            if c not in ws:                                   # (callee not a routine: unknown)
                ws[c] = None
        changed = True
        while changed:
            changed = False
            for e in self.routines:
                if ws[e] is None: continue
                acc = set(ws[e])
                for c in deps[e]:
                    cw = ws.get(c)
                    if cw is None: acc = None; break
                    acc |= cw
                if acc is None or acc != ws[e]:
                    ws[e] = acc; changed = True
        nmi = set()
        for h in rc.g.nmi_handlers:
            hw = ws.get(h)
            if hw is None: nmi = None; break
            nmi |= hw
        self.nmi_writes = nmi
        return ws

    def values(self):
        facts = None
        for rnd in range(6):                         # facts and write sets refine each other
            ws = self.write_sets(facts)
            nf = self._values(ws)
            if nf == facts: break
            facts = nf
        self.izy_facts = facts
        return facts

    def _values(self, ws):
        """one round, whole program: ranges (lo, hi) of A / X / Y / C and of every
        zero-page byte used as a pointer; a routine reached only by static calls / tail
        edges starts from the merge of its callers' states there, others from unknown"""
        rc = self.rc
        facts = {}                                     # izy key -> (lo, hi) of the pointer high byte / None
        ptr = set()
        for o in self.ops.values():
            if o.mem is not None and o.mem.ind == 'izy':
                ptr.add(o.mem.addr); ptr.add((o.mem.addr + 1) & 0xFF)
        keys = ['A', 'X', 'Y', 'C'] + sorted(ptr)
        unknown = {x: None for x in keys}
        def merge(a, b):
            if a is None: return dict(b)
            out = {}
            for x in keys:
                va, vb = a.get(x), b.get(x)
                out[x] = None if (va is None or vb is None) else (min(va[0], vb[0]), max(va[1], vb[1]))
            return out
        # entries whose state is unknown: reached dynamically, natively, by interrupt, or
        # from code outside every routine walk
        open_entry = set(k for k in rc.dyn) | set(rc.g.ext) | set(rc.g.nmi_handlers)
        open_entry |= set((k[0], v[1]) for k, v in rc.g.idioms.items())
        called = set()
        for r in self.routines.values(): called |= r.calls | r.tails
        for e in self.routines:
            if e not in called: open_entry.add(e)
        entry = {e: (dict(unknown) if e in open_entry else None) for e in self.routines}
        work = [e for e in self.routines if entry[e] is not None]
        inwork = set(work)
        self._callsite = {}
        while work:
            e = work.pop(); inwork.discard(e)
            r = self.routines[e]
            inn = {r.entry: dict(entry[e])}
            bw = [r.entry]
            while bw:
                b = bw.pop()
                st = dict(inn[b])
                for k in r.blocks[b]:
                    o = self.ops[k]
                    if o.kind == 'call' and o.target in self.routines:
                        c = o.target
                        m = merge(entry[c], st)
                        if m != entry[c]:
                            entry[c] = m
                            if c not in inwork: work.append(c); inwork.add(c)
                    self._step(k, st, ptr, ws, facts)
                last = r.blocks[b][-1]
                for t in self.out(last):                 # tail edges into other routines
                    if t in r.tails and t in self.routines:
                        m = merge(entry[t], st)
                        if m != entry[t]:
                            entry[t] = m
                            if t not in inwork: work.append(t); inwork.add(t)
                for s2 in r.succ[b]:
                    m = merge(inn.get(s2), st)
                    if s2 not in inn or m != inn[s2]: inn[s2] = m; bw.append(s2)
        return facts

    def rom_range(self, k, mm):
        """(lo, hi) of the bytes a ROM operand can read: one byte, or the 256 from the base
        for an indexed read; the bank at $8000 is the code's own (code of a bNN space runs
        there), unknown from the fixed bank"""
        sp = k[0]; a = mm.addr
        if 0x8000 <= a < 0xC000:
            if not sp.startswith('b'): return None
            space = sp
        elif a >= 0xC000: space = 'fix'
        else: return None
        base = 0x8000 if space != 'fix' else 0xC000
        n = 1 if mm.index is None else 0x100
        bs = [self.rc.cm.byte(space, x) for x in range(a, min(a + n, base + 0x4000))]
        return (min(bs), max(bs)) if bs else None

    def _step(self, k, st, ptr, ws, facts):
        rc = self.rc; o = self.ops[k]; mn = o.mn; mm = o.mem
        FULL = None
        def rd():                                       # operand range
            if o.imm is not None: return (o.imm, o.imm)
            if mm is None or mm.ind is not None: return FULL
            if mm.region == 'ram' and mm.index is None:
                a = mm.addr & 0x7FF
                return st.get(a, FULL)
            if mm.region in ('rom8', 'romc', 'rome'): return self.rom_range(k, mm)
            return FULL
        def clobber_ptr_by(mm2, mode):
            if mm2.ind is None and mm2.region == 'ram':
                a = mm2.addr & 0x7FF
                if mm2.index is None:
                    if a in st: st[a] = FULL
                else:
                    for x in ptr:
                        if mode in ('zpx', 'zpy') or a <= x < a + 0x100: st[x] = FULL
            elif mm2.ind is not None:
                f = facts.get(k)
                if not (f is not None and f[0] >= 0x08):
                    for x in ptr: st[x] = FULL
        mode = rc.insns[k].mode
        if mm is not None and mm.ind == 'izy':
            hi = st.get((mm.addr + 1) & 0xFF)
            if k in facts and facts[k] is None: pass
            elif hi is None: facts[k] = None
            else:
                p = facts.get(k)
                facts[k] = hi if p is None and k not in facts else (min(p[0], hi[0]), max(p[1], hi[1]))
        if k in rc.g.idioms or k in rc.g.ext:
            for x in st: st[x] = FULL
            return
        if mn in ('LDA', 'LDX', 'LDY'):
            st[mn[2]] = rd()
        elif mn in ('TAX', 'TAY', 'TXA', 'TYA'):
            st[mn[2]] = st[mn[1]]
        elif mn in ('STA', 'STX', 'STY'):
            if mm.ind is None and mm.region == 'ram' and mm.index is None and (mm.addr & 0x7FF) in st:
                st[mm.addr & 0x7FF] = st[mn[2]]
            else:
                clobber_ptr_by(mm, mode)
        elif mn == 'CLC': st['C'] = (0, 0)
        elif mn == 'SEC': st['C'] = (1, 1)
        elif mn in ('ADC', 'SBC'):
            v = rd(); a = st['A']; c = st['C']
            if v is None or a is None or c is None:
                st['A'] = st['C'] = FULL
            else:
                if mn == 'ADC': lo, hi = a[0] + v[0] + c[0], a[1] + v[1] + c[1]
                else: lo, hi = a[0] - v[1] - (1 - c[0]), a[1] - v[0] - (1 - c[1])
                if mn == 'ADC':
                    cl, ch = (1 if lo > 0xFF else 0), (1 if hi > 0xFF else 0)
                else:
                    cl, ch = (1 if lo >= 0 else 0), (1 if hi >= 0 else 0)
                st['C'] = (cl, ch)
                if lo >= 0 and hi <= 0xFF: st['A'] = (lo, hi)
                elif lo > 0xFF: st['A'] = (lo - 0x100, hi - 0x100)
                elif hi < 0: st['A'] = (lo + 0x100, hi + 0x100)
                else: st['A'] = FULL
        elif mn == 'AND':
            v = rd(); a = st['A']
            if v is not None and v[0] == v[1]:
                if a is not None and a[0] == a[1]: st['A'] = (a[0] & v[0],) * 2
                else: st['A'] = (0, v[0])
            elif a is not None and a[0] == a[1]: st['A'] = (0, a[0])
            else: st['A'] = FULL
        elif mn in ('ORA', 'EOR'):
            v = rd(); a = st['A']
            if v is not None and a is not None and v[0] == v[1] and a[0] == a[1]:
                st['A'] = ((a[0] | v[0]) if mn == 'ORA' else (a[0] ^ v[0]),) * 2
            else: st['A'] = FULL
        elif mn in ('INX', 'DEX', 'INY', 'DEY'):
            r = mn[2]; d = 1 if mn[0] == 'I' else -1; v = st[r]
            st[r] = None if v is None or not (0 <= v[0] + d and v[1] + d <= 0xFF) else (v[0] + d, v[1] + d)
        elif mn in ('INC', 'DEC') and mm is not None and mm.ind is None and mm.index is None \
                and mm.region == 'ram' and (mm.addr & 0x7FF) in st:
            a = mm.addr & 0x7FF; d = 1 if mn == 'INC' else -1; v = st[a]
            st[a] = None if v is None or not (0 <= v[0] + d and v[1] + d <= 0xFF) else (v[0] + d, v[1] + d)
        elif mn == 'JSR':
            for x in ('A', 'X', 'Y', 'C'): st[x] = FULL
            w = ws.get(o.target) if o.target in ws else None
            nmi = self.nmi_writes
            for x in ptr:
                if w is None or nmi is None or x in w or x in nmi: st[x] = FULL
        else:
            for r in o.rdef:
                if r in st: st[r] = FULL
            if 'C' in o.fdef: st['C'] = FULL
            if o.mwrite and mm is not None: clobber_ptr_by(mm, mode)

    # -------------------------------------------------------------- code generation
    # -------------------------------------------------------------- M4: carry polarity
    # In routines without stack tricks, the GB carry is not kept in 6502 polarity at every
    # instruction: CMP / CPX / CPY / SBC leave it inverted (GB borrow = NOT 6502 C) and the
    # state is tracked; BCC / BCS test the matching condition; a CCF is emitted only where
    # the 6502 polarity is needed (ADC, rotates, PHP, calls, returns, jumps, natives) or at
    # a block whose entry is shared by several paths (normalised at the end of the paths).
    # rc.cfix[key]: set of 'pre' (CCF before), 'post' (CCF after the code), 'swap' (branch
    # on the other condition), 'keep' (CMP / SBC: leave the result inverted), 'sbc_i'
    # (SBC: carry already inverted, no CCF before).
    NEEDS_N = {'ADC', 'ROL', 'ROR', 'PHP', 'JSR', 'RTS', 'RTI', 'JMP', 'BRK', 'TXS', 'TSX', 'PLP'}

    def carry_states(self):
        rc = self.rc; ins = rc.insns; cfix = {}
        lazy = set()
        rng = os.environ.get('LAZY_BISECT')               # debug: only routines lo <= index < hi
        lo_i, hi_i = (int(x) for x in rng.split(',')) if rng else (0, 1 << 30)
        for n, (e, r) in enumerate(sorted(self.routines.items())):
            if not lo_i <= n < hi_i: continue
            if r.tricks & {'pla_drop', 'tsx', 'txs', 'jmp_ind', 'dyn_jump'} or r.dyncalls: continue
            for k in r.keys:
                if len(self.owner[k]) == 1 and k not in rc.g.ext and k not in rc.g.idioms:
                    lazy.add(k)
        self.lazy = lazy
        def step(k, s):
            """state after instruction k from state s before it -> (s_out, flags)"""
            i = ins[k]; mn = i.mn; f = set()
            cl = 'C' in rc.live_in.get(k, ())
            if k not in lazy:                           # (code outside the lazy set: 6502 polarity in)
                if s == 'i' and cl: f.add('pre')
                return 'n', f
            lo = rc.live_out.get(k, frozenset('NZCV'))
            v_sbc = mn == 'SBC' and 'V' in lo
            if mn in self.NEEDS_N or v_sbc or mn == 'ADC':
                if s == 'i' and cl: f.add('pre')
                s = 'n'
            elif mn == 'SBC':
                if s == 'i' or (s == '?' and not cl): f.add('sbc_i')
            elif mn in ('BCC', 'BCS'):
                if s == 'i': f.add('swap')
            if mn in ('CMP', 'CPX', 'CPY') or (mn == 'SBC' and not v_sbc):
                if 'C' in lo: f.add('keep'); s = 'i'
                else: s = '?'
            elif mn in ('ADC', 'ROL', 'ROR', 'ASL', 'LSR', 'CLC', 'SEC', 'PLP', 'JSR', 'RTS'):
                s = 'n'
            elif 'C' not in lo:
                s = '?'
            return s, f
        def meet(a, b):
            if a is None: return b
            if a == '?': return b
            if b == '?' or a == b: return a
            return 'X'                                  # conflict
        for e, r in self.routines.items():
            if not (r.keys & lazy): continue
            preds = defaultdict(set)
            for b, ss in r.succ.items():
                for s2 in ss: preds[s2].add(b)
            def fixed_n(b):
                """entries that hold 6502 polarity: the routine entry, blocks after a call or
                reached from code outside the lazy set"""
                if b == r.entry or b not in lazy: return True
                for p in preds[b]:
                    last = r.blocks[p][-1]
                    if last not in lazy or self.ops[last].kind == 'call': return True
                return False
            force = set(b for b in r.blocks if fixed_n(b))
            def norm_end(b, st):
                """the block ends in the inverted state with C live and flows into a block
                that needs 6502 polarity (or leaves the routine): CCF at its end"""
                last = r.blocks[b][-1]
                return st == 'i' and 'C' in rc.live_out.get(last, ()) and \
                    (not r.succ[b] or any(s2 in force for s2 in r.succ[b]))
            while True:
                inn = {}; out = {}
                changed = True
                while changed:
                    changed = False
                    for b in r.blocks:
                        if b in force: si = 'n'
                        else:
                            si = None
                            for p in preds[b]:
                                if p in out: si = meet(si, out[p])
                            if si is None: continue
                            if si == 'X': si = 'n'          # (handled below)
                        if inn.get(b) == si and b in out: continue
                        inn[b] = si; st = si
                        for k in r.blocks[b]: st, _ = step(k, st)
                        if norm_end(b, st): st = 'n'
                        if out.get(b) != st: out[b] = st; changed = True
                # blocks whose predecessors disagree: force 6502 polarity there
                newforce = set()
                for b in r.blocks:
                    if b in force: continue
                    m = None
                    for p in preds[b]:
                        if p in out: m = meet(m, out[p])
                    if m == 'X': newforce.add(b)
                if not newforce: break
                force |= newforce
            # flags: per instruction, plus normalisation at the end of blocks flowing into a
            # forced block in the inverted state
            for b, blk in r.blocks.items():
                if b not in inn: continue
                st = inn[b]
                for idx, k in enumerate(blk):
                    st, f = step(k, st)
                    if idx == len(blk) - 1 and norm_end(b, st):
                        if self.ops[k].kind == 'branch':
                            f.discard('swap'); f.add('pre')
                        else:
                            f.add('post')
                    if f: cfix[k] = f
        self.rc.cfix = cfix
        return cfix

    # -------------------------------------------------------------- M4: N flag
    # BMI / BPL test bit 7 of the register that produced N when that instruction is in the
    # same block of lazy code, the register is unchanged in between, nothing else reads N
    # and neither N nor Z is needed after the branch: no store of N into HRAM, no reload.
    NREG = {'LDA': 'A', 'ADC': 'A', 'SBC': 'A', 'AND': 'A', 'ORA': 'A', 'EOR': 'A', 'PLA': 'A', 'TXA': 'A',
            'TYA': 'A', 'LDX': 'X', 'INX': 'X', 'DEX': 'X', 'TAX': 'X', 'LDY': 'Y', 'INY': 'Y', 'DEY': 'Y',
            'TAY': 'Y'}

    def n_tests(self):
        rc = self.rc; ins = rc.insns; nsrc = {}; nskip = set()
        GB = {'A': 'a', 'X': 'e', 'Y': 'c'}
        for e, r in self.routines.items():
            for b, blk in r.blocks.items():
                for j, k in enumerate(blk):
                    i = ins[k]
                    if i.mn not in ('BMI', 'BPL') or k not in self.lazy: continue
                    if rc.live_out.get(k, frozenset('NZCV')) & {'N', 'Z'}: continue
                    for d in range(j - 1, -1, -1):
                        kd = blk[d]; od = self.ops[kd]
                        if kd not in self.lazy or od.kind != 'op': break
                        if 'N' in od.fdef:
                            reg = self.NREG.get(od.mn)
                            if reg is None or (od.mn in ('ASL', 'LSR', 'ROL', 'ROR')): break
                            if od.mn in ('ADC', 'SBC') and 'V' in rc.live_out.get(kd, ()): break
                            ok = all(reg not in self.ops[blk[m]].rdef and 'N' not in self.ops[blk[m]].fuse
                                     for m in range(d + 1, j))
                            if ok:
                                nsrc[k] = GB[reg]; nskip.add(kd)
                            break
                        if 'N' in od.fuse: break
        rc.nsrc, rc.nskip = nsrc, nskip
        return nsrc

    def compile(self):
        """code per space in address order (translate.emit_program's input). M1: every
        instruction through translate.Emitter, as Recompiler.compile."""
        rc = self.rc
        rc.izy_facts = self.values()
        self.carry_states()
        self.n_tests()
        rc.home = {}
        blocks = self._emit()
        self.choose_home(blocks)
        if rc.home: blocks = self._emit()
        return blocks

    def _emit(self):
        from translate import SPACES
        rc = self.rc; blocks = {}
        rc.home_direct = 0; rc.izy_direct_n = 0
        for sp in SPACES:
            keys = sorted(a for s, a in rc.insns if s == sp)
            blocks[sp] = [((sp, a), rc.xlate(rc.insns[(sp, a)])) for a in keys]
        return blocks

    # Home placement (M3 / M5): routines whose hot loops read ROM data run from bank 0
    # with that data bank mapped at $4000, so the reads are plain loads. Candidates (from
    # the dynamic profile, tools/gb2/hwprof.py HW_PREFIX=rt_izy_,rt_rd_): the music engine
    # (space b13, its own bank's music data) and the field sprite drawing around fix:E102
    # (sprite tables in the fixed bank at $E000-$FFFF).
    HOME_CANDIDATES = [('space', 'b13', 13), ('key', ('fix', 0xE102), 31)]

    def choose_home(self, blocks):
        from translate import line_size, DATA, HOME_ORG, HOME_END
        rc = self.rc
        size = {k: sum(line_size(l) for l in lines) for sp in blocks for k, lines in blocks[sp]}
        room = (HOME_END - HOME_ORG) * 9 // 10          # (direct reads only shrink the code)
        chosen = {}
        for kind, what, nesbank in self.HOME_CANDIDATES:
            if kind == 'space': ks = [k for k in rc.insns if k[0] == what]
            else: ks = sorted(set().union(*(self.routines[e].keys for e in self.owner.get(what, ()))))
            ks = [k for k in ks if k not in chosen]
            sz = sum(size[k] for k in ks) + len(ks) // 4 + 16
            if sz > room: continue
            room -= sz
            for k in ks: chosen[k] = DATA + nesbank
        rc.home = chosen

    # -------------------------------------------------------------- report
    def report(self, verbose=False):
        rs = self.routines
        n_ins = len(self.rc.insns)
        shared = sum(1 for k, v in self.owner.items() if len(v) > 1)
        tr = defaultdict(int)
        for r in rs.values():
            for t in r.tricks: tr[t] += 1
        clean = [e for e, r in rs.items() if not r.tricks & {'pla_drop', 'tsx', 'txs', 'jmp_ind', 'dyn_jump'}
                 and not r.dyncalls]
        print('instructions %d, routines %d, blocks %d' % (n_ins, len(rs), sum(len(r.blocks) for r in rs.values())))
        print('instructions in more than one routine: %d' % shared)
        print('routines with tail edges: %d, with dynamic calls: %d' % (
            sum(1 for r in rs.values() if r.tails), sum(1 for r in rs.values() if r.dyncalls)))
        print('tricks: ' + ', '.join('%s %d' % kv for kv in sorted(tr.items())))
        print('routines without stack tricks / dynamic control: %d (%d instructions)' % (
            len(clean), sum(len(rs[e].keys) for e in clean)))
        xb = 0; calls = 0
        for e, r in rs.items():
            for c in r.calls:
                calls += 1
                if c[0] != e[0] and c[0] not in ('fix', 'ex') and e[0] not in ('fix',): xb += 1
        print('static call edges %d (bank to another switchable bank: %d)' % (calls, xb))
        if verbose:
            for e, r in sorted(rs.items()):
                print('%s:%04X %4d insns %3d blocks calls %d tails %d %s' % (
                    e[0], e[1], len(r.keys), len(r.blocks), len(r.calls), len(r.tails), ' '.join(sorted(r.tricks))))

    def check(self):
        """every instruction belongs to a routine; IR flag sets match the translator's"""
        missing = [k for k in self.rc.insns if k not in self.owner]
        assert not missing, 'instructions outside every routine: %r' % missing[:5]
        for k, o in self.ops.items():
            assert o.fdef == frozenset(DEF.get(o.mn, '')) and o.fuse == frozenset(USE.get(o.mn, ''))
        return True


def main():
    sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
    from ff2code import CodeMap
    a = sys.argv[1:]
    cm = CodeMap(a[0], a[1]).build()
    p = Program(Recompiler(cm))
    p.check()
    p.report('--routines' in a)


if __name__ == '__main__':
    main()
