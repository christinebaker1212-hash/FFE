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

    # -------------------------------------------------------------- code generation
    def compile(self):
        """code per space in address order (translate.emit_program's input). M1: every
        instruction through translate.Emitter, as Recompiler.compile."""
        rc = self.rc
        blocks = {}
        from translate import SPACES
        for sp in SPACES:
            keys = sorted(a for s, a in rc.insns if s == sp)
            blocks[sp] = [((sp, a), rc.xlate(rc.insns[(sp, a)])) for a in keys]
        return blocks

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
