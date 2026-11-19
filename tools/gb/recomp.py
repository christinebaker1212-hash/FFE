"""6502 → SM83 static recompiler for the FF1 English MMC5 build (see docs/gb-port.md §1).

recompile(codemap) returns (asm_text, info): SM83 assembly for every code bank plus
bank-0 stubs and the dynamic-target table, to be assembled together with tools/gb/rt/*.s.

Conventions (runtime contract, rt/runtime.s):
  A = A, E = X (D = 0), C = Y (B = 0), HL scratch.
  6502 C = GB carry (same polarity at every instruction boundary), Z = GB Z flag,
  N = bit 7 of HRAM nzv, V = bit 6 of HRAM vfl (stored only where live).
  Runtime helpers preserve A, F, BC, DE unless they return a value (in L).
"""
import os, re, sys
from collections import defaultdict
sys.path.insert(0, os.path.dirname(__file__))
from nescode import CodeMap, SPACES, index_of
from asm_sm83 import encode

DATA = 1                    # GB bank of NES 16KB bank 0's data image (NES bank n -> DATA + n)
RT_TABLES = DATA + 32       # runtime tables (sound)
CODE0 = DATA + 33           # first GB bank holding recompiled code
BANK_LIMIT = 0x4000 - 8     # bytes per code bank (room for a closing jump)
ALL = frozenset('NZCV')

DEF = {'ADC': 'NZCV', 'SBC': 'NZCV', 'AND': 'NZ', 'ORA': 'NZ', 'EOR': 'NZ', 'ASL': 'NZC', 'LSR': 'NZC',
       'ROL': 'NZC', 'ROR': 'NZC', 'BIT': 'NZV', 'CMP': 'NZC', 'CPX': 'NZC', 'CPY': 'NZC', 'DEC': 'NZ',
       'DEX': 'NZ', 'DEY': 'NZ', 'INC': 'NZ', 'INX': 'NZ', 'INY': 'NZ', 'LDA': 'NZ', 'LDX': 'NZ', 'LDY': 'NZ',
       'TAX': 'NZ', 'TAY': 'NZ', 'TXA': 'NZ', 'TYA': 'NZ', 'TSX': 'NZ', 'PLA': 'NZ', 'CLC': 'C', 'SEC': 'C',
       'CLV': 'V', 'PLP': 'NZCV', 'RTI': 'NZCV', 'EXT': 'NZ'}
USE = {'ADC': 'C', 'SBC': 'C', 'ROL': 'C', 'ROR': 'C', 'BCC': 'C', 'BCS': 'C', 'BEQ': 'Z', 'BNE': 'Z',
       'BMI': 'N', 'BPL': 'N', 'BVC': 'V', 'BVS': 'V', 'PHP': 'NZCV'}
BRANCH = {'BCC', 'BCS', 'BEQ', 'BNE', 'BMI', 'BPL', 'BVC', 'BVS'}


def label(space, addr):
    return 'L_%s_%04X' % (space, addr)


class FF1:
    """Game-specific facts (English MMC5 build of FF1)."""
    reset = ('fix', 0xFE2E)
    # Native replacements: NES address -> (routine, flags it defines). Each returns to
    # the caller of the NES routine like its RTS would.
    #   $FEDB ($FE00 jumps here): enable NMI and spin; the NMI handler returns to the caller.
    #   $E9F6: CHR upload loop (X pages from ($10)+Y to $2007).
    #   c62:C43C: the per-frame OAM-buffer clear (memset).
    ext = {('fix', 0xFEDB): ('rt_wait_nmi', 'NZ'), ('fix', 0xE9F6): ('hle_chr_pages', 'NZ'),
           ('c62', 0xC43C): ('hle_oam_clear', 'NZ'),
           ('c62', 0xD2EB): ('hle_mapdraw', 'NZC'),     # DrawMapRowCol (rt/ff1_native.s)
           ('c62', 0xD471): ('hle_mapattr', 'NZC'),     # DrawMapAttributes
           ('b12', 0xBF8F): ('hle_swap90', 'NZ')}       # battle: swap $90-$9F / $6D97 (rt/ff1_hle.s)
    # Idioms replaced by a runtime call, then a jump to `resume`:
    #   b14:B0F1 TSX/TXA/CMP #$EF/BCS/CLC/ADC #6/TAX/TXS: drop 3 return frames (camp items
    #   returning from the item menu straight to the field). The S >= $EF guard is not
    #   reproduced (it only matters for a near-empty stack).
    #   c62:D741-D75F: map-transition band (BG off / on / off timed by delay calls): the GB
    #   mask from rt_band (rt/runtime.s), with the delay calls' RAM side effects.
    #   fix:EA7F-EA86: one CHR page to $2007 (map loader): hle_chr_page1 (rt/ff1_hle.s).
    #   c62:D6B8-D6C2: the dialogue box's raster split waits $1B - 1 scanlines through
    #   $D77C every frame the box shows; the GB draws the box into its map, so only the
    #   RAM effects remain (rt_dlgdelay).
    idioms = {('b14', 0xB0F1): ('rt_unwind3', 0xB0FC, 'C'), ('c62', 0xD741): ('rt_band', 0xD760, 'NZC'),
              ('fix', 0xEA7F): ('hle_chr_page1', 0xEA87, 'NZ'),
              ('c62', 0xD1A8): ('hle_rlefill', 0xD1AB, 'Z'),   # map decompression run (rt/ff1_hle.s)
              ('fix', 0xF2CF): ('hle_ntclr', 0xF2DC, 'NZ'),    # battle setup: nametables cleared
              ('fix', 0xF4EA): ('hle_ntrun', 0xF4F6, 'NZC'),   # battle panel: a row to the PPU
              ('b14', 0x9C0F): ('hle_mclr', 0x9C2D, 'NZC'),    # menu screen cleared
              ('fix', 0xE14D): ('hle_wrow', 0xE153, 'NZ'),     # window rows (frame middles)
              ('fix', 0xE17F): ('hle_wrow', 0xE185, 'NZ'),
              ('fix', 0xE1A4): ('hle_wrow', 0xE1AA, 'NZ'),
              ('c62', 0xDEF1): ('hle_tpair', 0xDF04, 'NZ'),  # menu text printer: one letter
              ('c62', 0xD865): ('hle_palup', 0xD87F, 'NZC'),    # palette upload, every frame
              ('c62', 0xD874): ('hle_palup2', 0xD87F, 'NZC'),   #   (entered at its second loop)
              ('c62', 0xD6B8): ('rt_dlgdelay', 0xD6C3, 'NZ'),   # dialogue box split: timing loop
              ('c62', 0xC324): ('hle_pgcopy', 0xC334, 'NZ'),   # copy X pages ($10) -> ($12)
              ('c62', 0xD188): ('hle_mapdec', 0xD158, 'NZC'),  # map decompression to its $FF
              ('fix', 0xF56A): ('hle_boxrow', 0xF592, 'NZC'),  # battle box row into the panel image
              ('fix', 0xF618): ('hle_pclr', 0xF625, 'NZ'),     # battle panel image cleared
              ('fix', 0xFA5B): ('hle_cp64', 0xFA67, 'NZC'),    # battle text: 64 bytes to ExRAM
              ('fix', 0xFCC7): ('hle_sw16', 0xFCD8, 'NZ'),     # swap $90-$9F with $6D74
              ('b21', 0x80C5): ('hle_izr10', 0x80CE, 'NZ'),    # X bytes ($10),Y -> $2007
              ('fix', 0xF24D): ('hle_izr94', 0xF256, 'NZ')}    # X bytes ($94),Y -> $2007     # swap $90-$9F with $6D74
    # bytes each idiom replaces (build.py drops an idiom whose code is not there)
    idiom_code = {('fix', 0xF2CF): bytes.fromhex('a008a2008d0720cad0fa88d0f5'),
                  ('fix', 0xF4EA): bytes.fromhex('a000b1888d0720c8c019d0f6'),
                  ('b14', 0x9C0F): bytes.fromhex('a00098a2038d0720c8d0facad0f78d0720c8c0c090f8a9ff8d0720c8d0fa'),
                  ('fix', 0xE14D): bytes.fromhex('8d0720cad0fa'),
                  ('fix', 0xE17F): bytes.fromhex('8d0720cad0fa'),
                  ('fix', 0xE1A4): bytes.fromhex('8d0720cad0fa'),
                  ('c62', 0xDEF1): bytes.fromhex('ae0220a6558e0620a6548e06208c07208d0720'),
                  ('c62', 0xD865): bytes.fromhex('a50df00bbde0038d0720e8e01090f5bdc0038d0720e8e02090f5'),
                  ('c62', 0xD874): bytes.fromhex('bdc0038d0720e8e02090f5'),
                  ('c62', 0xD6B8): bytes.fromhex('a006a61bca207cd7cad0fa'),
                  ('c62', 0xD188): bytes.fromhex('a000b1101033c9fff0c6297f8514e610d009e6112411500320d9d1b110aaa5149112c8f00bcad0f89818651285129002e613e610d0ca4ccdd19112e612d002e613e610d0bbe611241150b520d9d14c88d1'),
                  ('c62', 0xC324): bytes.fromhex('a000b1109112c8d0f9e611e613cad0f2'),
                  ('fix', 0xF56A): bytes.fromhex('a000adb3689188aea16acacac8adb4689188c8cad0faadb5689188a5881869208588a58969008589'),
                  ('fix', 0xF618): bytes.fromhex('a000a900991e69999e69c8d0f7'),
                  ('fix', 0xFA5B): bytes.fromhex('a000b19099805fc8c040d0f6'),
                  ('fix', 0xFCC7): bytes.fromhex('a20fb59048bd746d9590689d746dca10f1'),
                  ('b21', 0x80C5): bytes.fromhex('b1108d0720c8cad0f7'),
                  ('fix', 0xF24D): bytes.fromhex('b1948d0720c8cad0f7')}
    skip = [('fix', 0xFECF, 0xFEDB), ('fix', 0xFEDC, 0xFEF1)]   # NMI handler + wait loop
    # Jump tables of the JMP (ind) dispatches (space, table, entries): every entry is compiled
    # and a dynamic target, not only those the coverage runs reached (a person whose talk
    # routine no run had used locked the game up).
    jump_tables = [('b14', 0x90D3, 128), ('b14', 0x91D3, 80),     # map objects (talk etc.), b14:9069 / 9076
                   ('c62', 0xCDA3, 16),                           # tile properties, c62:CA99
                   ('b14', 0xA333, 8),                            # shop types, b14:A367
                   ('b14', 0xB18A, 30),                           # b14:B187
                   ('b12', 0x946F, 4), ('b12', 0x94DE, 4),        # battle, b12:946C / 94DB
                   ('b12', 0x9AC5, 5),                            # b12:9AC2
                   ('b12', 0xB807, 19),                           # battle magic effects, b12:B804
                   ('b11', 0xA7AA, 3)]                            # b11:A449


class Recompiler:
    def __init__(self, cm, game=FF1):
        self.cm, self.g = cm, game
        self.insns = {k: i for k, i in cm.insns.items() if not self.skipped(*k)}
        self.warn = []

    def skipped(self, sp, a):
        return any(sp == s and lo <= a < hi for s, lo, hi in self.g.skip)

    # ------------------------------------------------------------ control flow
    def succ(self, i):
        """static successors (space, addr) within compiled code; None entries = dynamic"""
        out = []
        k = (i.space, i.addr)
        if k in self.g.ext: return []
        if k in self.g.idioms: return [(i.space, self.g.idioms[k][1])]
        if i.mn in ('RTS', 'RTI', 'BRK'): return []
        if i.mn == 'JMP':
            if i.mode == 'ind': return [None]
            return [self.target(i, i.arg)]
        out.append((i.space, i.addr + i.size) if not (i.space == 'c62' and i.addr + i.size == 0xE000)
                   else ('fix', 0xE000))
        if i.mode == 'rel': out.append(self.target(i, i.arg))
        return out

    def target(self, i, addr):
        ts = self.cm.target_space(i.space, addr)
        if ts is None and i.mn in ('JSR', 'JMP') and addr == i.arg:
            ts = self.cm.static_bank(i.space, i.addr)     # LDA #n / JSR $FE03 / JSR $8xxx
        return (ts, addr) if ts else None

    def dyn_candidates(self, addr):
        """compiled code locations an address can mean at run time"""
        return [(sp, addr) for sp in SPACES if (sp, addr) in self.insns
                and SPACES[sp][0] <= addr < SPACES[sp][0] + SPACES[sp][2]]

    # ------------------------------------------------------------ stack tricks
    def classify(self):
        self.pla_drop = {}             # PLA key -> 'pop' (first of the pair) / 'none' (second)
        self.rts_dispatch = set()
        for k, i in self.insns.items():
            if i.mn == 'PLA' and i.stk & 2:
                nxt = self.insns.get((i.space, i.addr + 1))
                if nxt is not None and nxt.mn == 'PLA' and nxt.stk & 2:
                    self.pla_drop[k] = 'pop'; self.pla_drop[(i.space, i.addr + 1)] = 'none'
        for k, i in self.insns.items():
            if i.mn == 'PLA' and i.stk & 2 and k not in self.pla_drop:
                self.warn.append('lone PLA popping a return address at %r' % i)
            if i.mn == 'RTS' and i.stk & 1:
                prev = self.insns.get((i.space, i.addr - 1))
                if prev is not None and prev.mn == 'PLA' and (prev.space, prev.addr) in self.pla_drop:
                    continue                                    # PLA PLA RTS: normal ret
                if prev is not None and prev.mn == 'PHA':
                    self.rts_dispatch.add(k)
                else:
                    self.warn.append('RTS with stack mismatch, not understood: %r' % i)

    # ------------------------------------------------------------ dynamic targets
    def dyn_targets(self):
        """NES addresses that can be reached through JMP (ind), RTS dispatch or a JSR/JMP
        into $8000-$BFFF from code outside that bank."""
        t = set()
        for k, i in self.insns.items():
            if i.cov & 6:                                   # reached by RTS or JMP (ind)
                if i.cov & 4: t.add(k)
                if i.cov & 2:
                    # an RTS lands after a JSR normally; anything else is a dispatch target
                    prev3 = self.insns.get((i.space, i.addr - 3))
                    if prev3 is None or prev3.mn != 'JSR': t.add(k)
            if i.mn in ('JSR', 'JMP') and i.mode == 'abs' and self.target(i, i.arg) is None:
                for c in self.dyn_candidates(i.arg): t.add(c)
                if not self.dyn_candidates(i.arg): self.warn.append('no known code for %r' % i)
        t.add(self.g.reset)
        return sorted(t)

    # ------------------------------------------------------------ liveness
    def liveness(self):
        ins = self.insns
        entries = defaultdict(list)                         # callee -> JSR sites
        for k, i in ins.items():
            if i.mn == 'JSR':
                tk = self.target(i, i.arg)
                if tk: entries[tk].append(k)
        # which RTSes each entry reaches without following calls
        ret_sites = defaultdict(set)                        # RTS key -> return-site keys
        unknown_ret = set()
        for e, sites in entries.items():
            seen = set(); work = [e]; rts = []
            while work:
                k = work.pop()
                if k in seen or k not in ins: continue
                seen.add(k); i = ins[k]
                if i.mn == 'RTS' or k in self.g.ext: rts.append(k); continue
                for s in self.succ(i):
                    if s is not None: work.append(s)
            for r in rts:
                for s in sites: ret_sites[r].add((s[0], s[1] + 3))
        self.ret_sites = ret_sites
        live_in = {k: frozenset() for k in ins}
        live_out = {k: frozenset() for k in ins}
        # predecessor lists for a worklist solve
        preds = defaultdict(set)
        outs = {}
        for k, i in ins.items():
            o = []
            if i.mn == 'JSR':
                tk = self.target(i, i.arg)
                o = [tk] if tk else [None]
            elif i.mn == 'RTS' or k in self.g.ext:
                o = list(ret_sites.get(k, ())) or [None]
                if k in self.rts_dispatch or any((i.space, i.addr - 2) in self.pla_drop for _ in [0]):
                    o = [None]
            else:
                o = self.succ(i)
            outs[k] = o
            for s in o:
                if s is not None: preds[s].add(k)
        # PHP ... PLP in straight-line code: the PHP needs only the flags live after the PLP
        php_plp, plp_php = {}, {}
        php_mask = {}                  # PHP / PLA / AND #m / PHA / PLP: flags kept by the mask
        for k, i in ins.items():
            if i.mn != 'PHP': continue
            seq = [ins.get((k[0], k[1] + d)) for d in (1, 2, 4, 5)]
            if all(seq) and [x.mn for x in seq] == ['PLA', 'AND', 'PHA', 'PLP'] and seq[1].mode == 'imm':
                m = seq[1].arg
                php_mask[k] = frozenset(f for f, b in (('N', 7), ('V', 6), ('Z', 1), ('C', 0)) if m >> b & 1)
                php_plp[k] = (k[0], k[1] + 5); plp_php[(k[0], k[1] + 5)] = k
                continue
            d, c = 0, k
            for _ in range(40):
                o = [(c[0], c[1] + 3)] if ins[c].mn == 'JSR' else outs.get(c, [])   # (calls return)
                if len(o) != 1 or o[0] is None or o[0] not in ins: break
                c = o[0]; m = ins[c].mn
                if ins[c].mode == 'rel' or m in ('JMP', 'RTS', 'RTI') or c in self.g.ext or c in self.g.idioms: break
                if m in ('PHA', 'PHP'): d += 1
                elif m in ('PLA', 'PLP'):
                    if d == 0:
                        if m == 'PLP': php_plp[k] = c; plp_php[c] = k
                        break
                    d -= 1
        # V at unknown edges: FF1 reads V in a few places only (BVC / BVS, PHP). If no reader
        # can be reached from a target of an unknown edge (a dynamic target or a JSR's return
        # site) before V is set again, unknown edges do not keep V live, and ADC / SBC whose
        # V only reached them compile without computing it (checked after solving with V
        # dead there; else solved again with all flags live).
        entry_like = set(self.dyn_targets()) | {(k[0], k[1] + 3) for k, i in ins.items() if i.mn == 'JSR'}
        def defs(k):
            if k in self.g.ext: return frozenset(self.g.ext[k][1])
            if k in self.g.idioms: return frozenset(self.g.idioms[k][2])
            i = ins[k]
            return frozenset() if i.mn == 'JSR' else frozenset(DEF.get(i.mn, ''))
        NZCV = frozenset('NZCV')
        # V readers that never ran and overlap an instruction that did (static flow into
        # the operand bytes of real code, e.g. after a branch that is always taken)
        ran = [k for k, i in ins.items() if i.cov & 1]
        inside = set()
        for k in ran:
            for d in range(1, ins[k].size): inside.add((k[0], k[1] + d))
        bogus_v = {k for k, i in ins.items() if i.mn in ('BVC', 'BVS', 'PHP') and not i.cov & 1 and k in inside}
        def solve(U):
            for k in ins: live_in[k] = live_out[k] = frozenset()
            work = list(ins)
            while work:
                k = work.pop(); i = ins[k]
                lo = frozenset()
                for s in outs[k]:
                    lo |= U if (s is None or s not in ins) else live_in[s]
                if k in self.g.ext:
                    li = lo - frozenset(self.g.ext[k][1])
                elif k in self.g.idioms:
                    li = lo - frozenset(self.g.idioms[k][2])
                elif i.mn == 'JSR':
                    li = lo                                     # = live_in(callee), set via outs
                elif k in php_plp:
                    li = lo | (live_out[php_plp[k]] & php_mask.get(k, NZCV))
                else:
                    li = frozenset(USE.get(i.mn, '')) | (lo - frozenset(DEF.get(i.mn, '')))
                    if k in bogus_v: li = li - frozenset('V')
                    if i.mn == 'JMP' and i.mode == 'ind': li = U
                    if k in self.rts_dispatch: li = U
                if lo != live_out[k] or li != live_in[k]:
                    live_out[k], live_in[k] = lo, li
                    work.extend(preds[k])
                    if k in plp_php: work.append(plp_php[k])
        def v_reaches_unknown():
            for r, ri in ins.items():
                if r in self.g.ext or r in self.g.idioms or r in bogus_v: continue
                if ri.mn in ('BVC', 'BVS') or ri.mn == 'PHP' and (r not in php_plp or 'V' in live_out[php_plp[r]] & php_mask.get(r, NZCV)):
                    seen = set(); st = [r]
                    while st:
                        k = st.pop()
                        if k in seen: continue
                        seen.add(k)
                        if k in entry_like or ins[k].mn == 'JMP' and ins[k].mode == 'ind' or k in self.rts_dispatch:
                            return (r, k)
                        for q in preds[k]:
                            if 'V' not in defs(q): st.append(q)
            return None
        U = ALL - frozenset('V')
        solve(U)
        self.v_reason = v_reaches_unknown()
        if self.v_reason:
            U = ALL
            solve(U)
        self.U = U
        import sys as _s; print('V at unknown edges:', 'live' if U == ALL else 'dead', self.v_reason, 'bogus V readers', len(bogus_v), file=_s.stderr)
        # JSR: flags live after the call that the callee does not define must pass through
        self.live_out, self.live_in = live_out, live_in

    # ------------------------------------------------------------ translation
    def compile(self):
        self.classify()
        self.liveness()
        self.dyn = self.dyn_targets()
        blocks = {}                                         # space -> [(key, lines)]
        for sp in SPACES:
            keys = sorted(a for s, a in self.insns if s == sp)
            out = []
            for a in keys:
                k = (sp, a)
                out.append((k, self.xlate(self.insns[k])))
            blocks[sp] = out
        return blocks

    def xlate(self, i):
        e = Emitter(self, i)
        e.run()
        return e.lines


def nes_region(a):
    if a < 0x2000: return 'ram'
    if a < 0x4000: return 'ppu'
    if a < 0x4020: return 'io'
    if a < 0x5C00: return 'mmc'
    if a < 0x6000: return 'ex'
    if a < 0x8000: return 'sram'
    if a < 0xC000: return 'rom8'
    if a < 0xE000: return 'romc'
    return 'rome'


def gb_ram(a):
    r = nes_region(a)
    if r == 'ram': return 0xC000 + (a & 0x7FF)
    if r == 'ex': return 0xC800 + a - 0x5C00
    if r == 'sram': return 0xA000 + a - 0x6000
    return None


class Emitter:
    def __init__(self, rc, i):
        self.rc, self.i = rc, i
        self.k = (i.space, i.addr)
        self.lines = []
        self.lo = rc.live_out.get(self.k, ALL)
        d = frozenset(DEF.get(i.mn, ''))
        self.need = self.lo & d                           # flags this instruction must produce
        self.keep = self.lo - d                           # live flags it must not disturb

    def o(self, *ls):
        self.lines.extend(ls)

    def lab(self, sp, a):
        return label(sp, a)

    # -- operand access -------------------------------------------------------------
    def index_reg(self):
        return {'abx': 'de', 'zpx': 'de', 'aby': 'bc', 'zpy': 'bc'}.get(self.i.mode)

    def addr_hl(self, gbaddr, idx):
        """HL = gbaddr (+ index). add hl,rr clobbers GB carry: protect it if C is live."""
        if idx is None:
            self.o('ld hl, $%04X' % gbaddr); return
        if gbaddr & 0xFF == 0 and self.i.mode in ('abx', 'aby'):   # page-aligned base: no carry
            self.o('ld h, $%02X' % (gbaddr >> 8), 'ld l, %s' % idx[1]); return
        protect = 'C' in self.keep or 'C' in USE.get(self.i.mn, '')
        if protect: self.o('push af')
        self.o('ld hl, $%04X' % gbaddr, 'add hl, %s' % idx)
        if protect: self.o('pop af')

    def operand(self):
        """emit code that makes the source operand available; returns an SM83 operand
        string ('[hl]', 'l', or '$nn')."""
        i = self.i; m = i.mode
        if m == 'imm': return '$%02X' % i.arg
        if m in ('izy', 'izx'):
            self.o('ld l, $%02X' % i.arg, 'call rt_%s_rd' % m)
            return 'l'
        a = i.arg; idx = self.index_reg()
        r = nes_region(a)
        if m in ('zp', 'zpx', 'zpy'): r = 'ram'
        if r in ('ram', 'ex', 'sram'):
            self.addr_hl(gb_ram(a), idx); return '[hl]'
        if r in ('rom8', 'romc', 'rome'):
            gb = 0x4000 + (a - 0x8000) if r == 'rom8' else 0x4000 + (a - 0xC000) if r == 'romc' else 0x6000 + (a - 0xE000)
            self.addr_hl(gb, idx)
            self.o('call rt_rd_%s' % r[3:])
            return 'l'
        if r == 'ppu':
            self.o('call rt_ppu_r%d' % (a & 7)); return 'l'
        if r == 'io':
            self.o('call rt_io_r%04X' % a if a in (0x4015, 0x4016, 0x4017) else 'call rt_io_rnone'); return 'l'
        if r == 'mmc' and a in (0x5802, 0x5803, 0x5804):            # GB runtime registers
            self.o('call rt_mmc_r%04X' % a); return 'l'
        self.o('ld l, 0'); self.rc.warn.append('read of %04X at %r' % (a, i)); return 'l'

    def store(self, reg):
        """store register reg ('a', 'e', 'c') to the instruction's address"""
        i = self.i; m = i.mode
        if m in ('izy', 'izx'):
            if reg == 'a': self.o('ld l, $%02X' % i.arg, 'call rt_%s_wr' % m)
            else: self.o('push af', 'ld a, %s' % reg, 'ld l, $%02X' % i.arg, 'call rt_%s_wr' % m, 'pop af')
            return
        a = i.arg; idx = self.index_reg()
        r = 'ram' if m in ('zp', 'zpx', 'zpy') else nes_region(a)
        if r in ('ram', 'ex', 'sram'):
            g = gb_ram(a)
            if idx is None and reg == 'a': self.o('ld [$%04X], a' % g)
            else:
                self.addr_hl(g, idx); self.o('ld [hl], %s' % reg)
            return
        name = None
        if r == 'ppu': name = 'rt_ppu_w%d' % (a & 7)
        elif r == 'io': name = 'rt_io_w%04X' % a if a in (0x4014, 0x4016) else 'rt_apu_w'
        elif r == 'mmc': name = 'rt_mmc_w%04X' % a if a in (0x5115, 0x5116, 0x5800, 0x5801, 0x5802, 0x5803, 0x5804, 0x5805, 0x5806, 0x5807, 0x5808) else None
        else:
            self.rc.warn.append('store to ROM %04X at %r' % (a, i)); return
        if name is None: return
        if r == 'io' and name == 'rt_apu_w':
            self.o('ld l, $%02X' % (a & 0xFF))
        if reg == 'a': self.o('call %s' % name)
        else: self.o('push af', 'ld a, %s' % reg, 'call %s' % name, 'pop af')

    def rmw_target(self):
        """HL = RAM address for read-modify-write; returns False for non-RAM"""
        i = self.i
        if i.mode == 'acc': return False
        a = i.arg
        r = 'ram' if i.mode in ('zp', 'zpx') else nes_region(a)
        if r not in ('ram', 'ex', 'sram'):
            self.rc.warn.append('RMW on %s at %r' % (r, i)); return None
        self.addr_hl(gb_ram(a), self.index_reg()); return True

    # -- flags ------------------------------------------------------------------------
    def set_nz_reg(self, reg):
        """N/Z from a register value after a load/transfer (GB flags untouched by ld)"""
        if 'Z' in self.need: self.o('inc %s' % reg, 'dec %s' % reg)
        if 'N' in self.need:
            if reg == 'a': self.o('ldh [nzv], a')
            else: self.o('ld hl, nzv', 'ld [hl], %s' % reg)

    def set_n_mem(self):
        """N from [hl] after a memory RMW; GB flags kept"""
        if 'N' in self.need: self.o('push af', 'ld a, [hl]', 'ldh [nzv], a', 'pop af')

    def fix_carry(self, inverted):
        if inverted and 'C' in self.need: self.o('ccf')

    def jump(self, cond, tk):
        """jp to compiled location tk (None = dynamic)"""
        if tk is None:
            self.o('call rt_fatal'); return
        if tk not in self.rc.insns and tk not in self.rc.g.ext:
            self.rc.warn.append('jump to uncompiled %s:%04X from %r' % (tk[0], tk[1], self.i))
            self.o(('call %s, ' % cond if cond else 'call ') + 'rt_fatal'); return
        self.o(('jp %s, ' % cond if cond else 'jp ') + label(*tk))

    # -- main ------------------------------------------------------------------------
    def run(self):
        i = self.i; mn = i.mn; rc = self.rc
        k = self.k
        if k in rc.g.ext:
            self.o('jp ' + rc.g.ext[k][0]); return
        if k in rc.g.idioms:
            self.o('call ' + rc.g.idioms[k][0]); self.jump(None, (i.space, rc.g.idioms[k][1])); return
        h = getattr(self, 'x_' + mn, None)
        if h is None:
            rc.warn.append('no translation for %r' % i); self.o('call rt_fatal')
        else:
            h()
        # fall through into the next space region (c62 -> fix)
        if mn not in ('JMP', 'RTS', 'RTI', 'BRK') and i.space == 'c62' and i.addr + i.size == 0xE000:
            self.o('jp ' + label('fix', 0xE000))

    # loads / stores
    def x_LDA(self):
        op = self.operand()
        if op != 'a': self.o('ld a, %s' % op)
        self.set_nz_reg('a')

    def x_LDX(self):
        op = self.operand(); self.o('ld e, %s' % op); self.set_nz_reg('e')

    def x_LDY(self):
        op = self.operand(); self.o('ld c, %s' % op); self.set_nz_reg('c')

    def x_STA(self): self.store('a')
    def x_STX(self): self.store('e')
    def x_STY(self): self.store('c')

    def x_TAX(self): self.o('ld e, a'); self.set_nz_reg('e')
    def x_TAY(self): self.o('ld c, a'); self.set_nz_reg('c')
    def x_TXA(self): self.o('ld a, e'); self.set_nz_reg('a')
    def x_TYA(self): self.o('ld a, c'); self.set_nz_reg('a')

    def x_TXS(self):
        p = self.rc.insns.get((self.i.space, self.i.addr - 2))
        p1 = self.rc.insns.get((self.i.space, self.i.addr - 1))
        if not ((p is not None and p.mn == 'LDX' and p.mode == 'imm' and p.arg == 0xFF) or
                (p1 is not None and p1.mn == 'DEX')):
            self.rc.warn.append('TXS with unknown X at %r' % self.i)
        self.o('ld sp, STACK_TOP')

    def x_TSX(self):
        self.rc.warn.append('TSX at %r' % self.i); self.o('ld e, $FF'); self.set_nz_reg('e')

    # arithmetic / logic
    def alu(self, op):
        src = self.operand()
        protect = 'C' in self.keep
        if protect:
            if src == '[hl]': self.o('ld l, [hl]'); src = 'l'
            self.o('push af', '%s %s' % (op, src), 'ld h, a', 'pop af', 'ld a, h')
            if 'Z' in self.need: self.o('inc a', 'dec a')
        else:
            self.o('%s %s' % (op, src))
        if 'N' in self.need: self.o('ldh [nzv], a')

    def x_AND(self): self.alu('and')
    def x_ORA(self): self.alu('or')
    def x_EOR(self): self.alu('xor')

    def x_ADC(self):
        src = self.operand()
        if 'V' in self.need:
            if src == '[hl]': self.o('ld l, [hl]')
            elif src != 'l': self.o('ld l, %s' % src)
            self.o('call rt_adc_v')
        else:
            self.o('adc a, %s' % src)
        if 'N' in self.need: self.o('ldh [nzv], a')

    def x_SBC(self):
        src = self.operand()
        if 'V' in self.need:
            if src == '[hl]': self.o('ld l, [hl]')
            elif src != 'l': self.o('ld l, %s' % src)
            self.o('call rt_sbc_v')                   # takes/returns 6502-polarity carry
        else:
            self.o('ccf', 'sbc a, %s' % src)
            if 'C' in self.need: self.o('ccf')
        if 'N' in self.need: self.o('ldh [nzv], a')

    def compare(self, reg):
        src = self.operand()
        if 'N' in self.need:
            if src == '[hl]': self.o('ld l, [hl]'); src = 'l'
            self.o('ld h, a')
            if reg != 'a': self.o('ld a, %s' % reg)
            self.o('sub %s' % src, 'ldh [nzv], a')
            if reg != 'a': self.o('ld a, %s' % reg)
            else: self.o('ld a, h')
            self.o('cp %s' % src)
            if reg != 'a': self.o('ld a, h')
        elif reg == 'a':
            self.o('cp %s' % src)
        else:
            if src == '[hl]': self.o('ld l, [hl]'); src = 'l'
            self.o('ld h, a', 'ld a, %s' % reg, 'cp %s' % src, 'ld a, h')
        self.fix_carry(True)

    def x_CMP(self): self.compare('a')
    def x_CPX(self): self.compare('e')
    def x_CPY(self): self.compare('c')

    def x_BIT(self):
        src = self.operand()
        if src == '[hl]': self.o('ld l, [hl]')
        elif src != 'l': self.o('ld l, %s' % src)
        if self.need & {'N', 'V'}:
            self.o('ld h, a', 'ld a, l')
            if 'N' in self.need: self.o('ldh [nzv], a')
            if 'V' in self.need: self.o('ldh [vfl], a')
            self.o('ld a, h')
        if 'Z' in self.need:
            if 'C' in self.keep:     # Z from A & M without touching carry
                self.o('ld h, a', 'push af', 'and l', 'ld l, a', 'pop af', 'ld a, h', 'inc l', 'dec l')
            else:
                self.o('ld h, a', 'and l', 'ld a, h')

    def shift(self, op_reg, op_fast):
        i = self.i
        if i.mode == 'acc':
            if 'Z' in self.need or op_fast is None: self.o('%s a' % op_reg)
            else: self.o(op_fast)
            if 'N' in self.need: self.o('ldh [nzv], a')
            return
        if self.rmw_target():
            self.o('%s [hl]' % op_reg); self.set_n_mem()

    def x_ASL(self): self.shift('sla', 'add a, a')
    def x_LSR(self): self.shift('srl', None)
    def x_ROL(self): self.shift('rl', 'rla')
    def x_ROR(self): self.shift('rr', 'rra')

    def incdec(self, op):
        if self.rmw_target():
            self.o('%s [hl]' % op); self.set_n_mem()

    def x_INC(self): self.incdec('inc')
    def x_DEC(self): self.incdec('dec')

    def regstep(self, op, reg):
        i = self.i
        n = self.nxt()
        if (op == 'dec' and n is not None and n.mn == 'BNE' and n.arg == i.addr):
            # timing loop DEY/BNE or DEX/BNE to itself: NES-equivalent delay
            self.o('call rt_delay_%s' % reg)
            if 'N' in self.need: self.o('ld hl, nzv', 'ld [hl], 0')
            return
        self.o('%s %s' % (op, reg))
        if 'N' in self.need:
            self.o('ld hl, nzv', 'ld [hl], %s' % reg)

    def x_INX(self): self.regstep('inc', 'e')
    def x_DEX(self): self.regstep('dec', 'e')
    def x_INY(self): self.regstep('inc', 'c')
    def x_DEY(self): self.regstep('dec', 'c')

    # flags
    def x_CLC(self): self.o('scf', 'ccf')
    def x_SEC(self): self.o('scf')
    def x_CLV(self): self.o('ld hl, vfl', 'res 6, [hl]')
    def x_SEI(self): pass
    def x_CLI(self): pass
    def x_CLD(self): pass
    def x_SED(self): pass
    def x_NOP(self): pass

    # stack
    def x_PHA(self):
        n = self.nxt()
        if n is not None and n.mn == 'PLP': return  # PHA / PLP pair
        self.o('push af')

    def x_PLA(self):
        k = self.k
        if k in self.rc.pla_drop:
            if self.rc.pla_drop[k] == 'pop': self.o('call rt_unwind1')   # farcall-aware
            return
        p = self.prv()
        if p is not None and p.mn == 'PHP':          # PHP / PLA pair: A already = P
            self.set_nz_reg('a'); return
        self.o('pop hl', 'ld a, h'); self.set_nz_reg('a')

    def nxt(self):
        i = self.i
        return self.rc.insns.get((i.space, i.addr + i.size))

    def prv(self):
        i = self.i
        return self.rc.insns.get((i.space, i.addr - 1))

    def x_PHP(self):
        n = self.nxt()
        if n is not None and n.mn == 'PLA':          # PHP / PLA: A = P
            self.o('call rt_get_p'); return
        self.o('ldh [sv_a], a', 'call rt_get_p', 'push af', 'ldh a, [sv_a]')

    def x_PLP(self):
        p = self.prv()
        if p is not None and p.mn == 'PHA':          # PHA / PLP: P = A
            self.o('call rt_set_p'); return
        self.o('ldh [sv_a], a', 'pop hl', 'ld a, h', 'call rt_set_p', 'ldh a, [sv_a]')

    # control flow
    def branch(self, cond_true, flag_test=None):
        i = self.i
        tk = self.rc.target(i, i.arg)
        if flag_test:
            hram, bit = flag_test
            regen = 'Z' in self.lo and hram == 'nzv'
            self.o('ld hl, %s' % hram, 'bit %d, [hl]' % bit)
            if regen:
                t = '.t_%04X' % i.addr
                self.o('jp %s, %s_%s' % (cond_true, label(i.space, i.addr), 'tk'))
                self.o('inc [hl]', 'dec [hl]')
                self.o('jp %s_nt' % label(i.space, i.addr))
                self.o('%s_tk:' % label(i.space, i.addr), 'inc [hl]', 'dec [hl]')
                self.jump(None, tk)
                self.o('%s_nt:' % label(i.space, i.addr))
                return
            elif 'Z' in self.lo:
                self.rc.warn.append('Z live across %s (from BIT) at %r' % (i.mn, i))
            self.jump(cond_true, tk)
            return
        self.jump(cond_true, tk)

    def x_BCC(self): self.branch('nc')
    def x_BCS(self): self.branch('c')
    def x_BEQ(self): self.branch('z')
    def x_BNE(self): self.branch('nz')
    def x_BMI(self): self.branch('nz', ('nzv', 7))
    def x_BPL(self): self.branch('z', ('nzv', 7))
    def x_BVS(self): self.branch('nz', ('vfl', 6))
    def x_BVC(self): self.branch('z', ('vfl', 6))

    def x_JMP(self):
        i = self.i
        if i.mode == 'ind':
            if gb_ram(i.arg) is None:
                self.rc.warn.append('JMP (ind) through non-RAM at %r' % i)
                self.o('ld hl, $%04X' % i.arg, 'jp rt_jmp_ind_nes'); return
            self.o('ld hl, $%04X' % gb_ram(i.arg), 'jp rt_jmp_ind'); return
        tk = self.rc.target(i, i.arg)
        if tk is None:
            self.o('ld hl, $%04X' % i.arg, 'jp rt_dyn_jump'); return
        self.jump(None, tk)

    def x_JSR(self):
        i = self.i
        tk = self.rc.target(i, i.arg)
        if tk is None:
            self.o('ld hl, $%04X' % i.arg, 'call rt_dyn_call'); return
        if tk not in self.rc.insns and tk not in self.rc.g.ext:
            self.rc.warn.append('call to uncompiled %s:%04X from %r' % (tk[0], tk[1], i))
            self.o('call rt_fatal'); return
        self.o('call ' + label(*tk))

    def x_RTS(self):
        if self.k in self.rc.rts_dispatch: self.o('jp rt_rts_dispatch')
        else: self.o('ret')

    def x_RTI(self):
        self.rc.warn.append('RTI at %r' % self.i); self.o('call rt_fatal')

    def x_BRK(self):
        self.o('call rt_fatal')


# ---------------------------------------------------------------- layout

def line_size(line):
    """byte size of one assembly line (sizes do not depend on label values)"""
    s = line.strip()
    if not s or s.endswith(':'): return 0
    parts = s.split(None, 1)
    mn = parts[0].lower()
    from asm_sm83 import _split_args
    args = _split_args(parts[1]) if len(parts) > 1 else []
    return len(encode(mn, args, lambda e: 0, 0x4000, 1))


def components(rc):
    """intraprocedural components: instructions linked by fall-through, branches and
    JMP stay together in one GB bank (cross-bank transfers are then only calls)."""
    parent = {k: k for k in rc.insns}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]; x = parent[x]
        return x
    for k, i in rc.insns.items():
        if i.mn in ('JSR',):
            nx = (i.space, i.addr + 3)
            if nx in parent: parent[find(nx)] = find(k)
            continue
        for s in rc.succ(i):
            if s is not None and s in parent: parent[find(s)] = find(k)
    comp = defaultdict(list)
    for k in rc.insns: comp[find(k)].append(k)
    return list(comp.values())


def layout(rc, blocks):
    """assign each component to a code bank; returns {key: bank} and per-bank line lists"""
    code = {k: lines for sp in blocks for k, lines in blocks[sp]}
    sizes = {k: sum(line_size(l) for l in code[k]) for k in code}
    comps = components(rc)
    comps.sort(key=lambda c: (min(c)[0], min(c)[1]))
    bank_of = {}
    banks = []                                            # [(bank, [keys], size)]
    cur, used, keys = CODE0, 0, []
    for c in comps:
        c.sort()
        sz = sum(sizes[k] for k in c) + 3 * len(c) // 8 + 8   # slack for split jumps
        if sz > BANK_LIMIT:
            rc.warn.append('component of %d bytes at %s:%04X is larger than a bank' % (sz, *min(c)))
        if used + sz > BANK_LIMIT and keys:
            banks.append((cur, keys)); cur += 1; used, keys = 0, []
        for k in c: bank_of[k] = cur
        keys.extend(c); used += sz
    if keys: banks.append((cur, keys))
    return bank_of, banks, code, sizes


def emit_program(rc):
    blocks = rc.compile()
    bank_of, banks, code, sizes = layout(rc, blocks)
    out = []
    xrefs = set()                                         # labels needing a bank-0 stub
    for bank, keys in banks:
        out.append('section bank %d, $4000' % bank)
        keys = sorted(keys)
        for n, k in enumerate(keys):
            out.append(label(*k) + ':')
            for line in code[k]:
                out.append('    ' + retarget(line, bank, bank_of, xrefs))
            # instruction falling through to a key that is not next in this bank
            i = rc.insns[k]
            nxt_keys = [s for s in rc.succ(i) if s is not None and s[1] == i.addr + i.size]
            if i.mn not in ("JMP", "RTS", "RTI", "BRK") and k not in rc.g.ext and k not in rc.g.idioms:
                ft = (i.space, i.addr + i.size) if not (i.space == 'c62' and i.addr + i.size == 0xE000) else None
                if ft is not None and (n + 1 >= len(keys) or keys[n + 1] != ft):
                    if ft in rc.insns:
                        out.append('    ' + retarget('jp ' + label(*ft), bank, bank_of, xrefs))
                    elif i.mn != 'JSR' or True:
                        out.append('    call rt_fatal')
    # stubs (bank 0)
    stubs = ['section bank 0, $%04X' % (0x3D20 - 18 * len(xrefs))]   # (18 bytes each, ending at pf_call)
    for lab in sorted(xrefs):
        stubs += ['xs_%s:' % lab, '    ldh [sv_a], a', '    ld a, bank(%s)' % lab, '    ldh [fc_bank], a',
                  '    ldh a, [sv_a]', '    ld hl, %s' % lab, '    jp rt_farcall',
                  'xj_%s:' % lab, '    call xs_%s' % lab, '    ret']
    # dynamic target table (bank DYN_BANK): 256 buckets by the NES address's low byte, each a
    # count and entries nes_hi, key, gb_bank, gb_lo, gb_hi (runtime lookup)
    buckets = defaultdict(list)
    for sp, a in rc.dyn:
        if (sp, a) not in rc.insns: continue
        key = int(sp[1:]) if sp.startswith('b') else 62 if sp == 'c62' else 40 if sp == 'far' else 0xFF
        buckets[a & 0xFF].append((a >> 8, key, label(sp, a)))
    tab = ['section bank DYN_BANK, $4000', 'dyn_buckets:']
    tab += ['    dw ' + ', '.join('dynb_%02X' % (lo + k) for k in range(8)) for lo in range(0, 256, 8)]
    for lo in range(256):
        tab.append('dynb_%02X:' % lo)
        tab.append('    db %d' % len(buckets[lo]))
        for hi, key, lab in buckets[lo]:
            tab.append('    db $%02X, $%02X, bank(%s), low(%s), high(%s)' % (hi, key, lab, lab, lab))
    return '\n'.join(stubs + out + tab) + '\n', bank_of, banks


def retarget(line, bank, bank_of, xrefs):
    """route jp/call to labels in another bank through a bank-0 stub"""
    s = line.strip()
    for op in ('call ', 'jp '):
        if s.startswith(op):
            tgt = s.split(',')[-1].strip() if ',' in s else s[len(op):].strip()
            if re.match(r'^L_[a-z0-9]+_[0-9A-F]{4}$', tgt):
                sp, a = tgt[2:].rsplit('_', 1)
                tb = bank_of.get((sp, int(a, 16)))
                if tb is not None and tb != bank:
                    xrefs.add(tgt)
                    if op == 'jp ':
                        # a jump into another bank: call the stub and return (keeps the
                        # caller's bank correct when the target finally returns)
                        if ',' in s:
                            cond = s[len(op):].split(',')[0].strip()
                            return 'jp %s, xj_%s' % (cond, tgt)
                        return 'jp xj_%s' % tgt
                    return line.replace(tgt, 'xs_' + tgt)
    return line
