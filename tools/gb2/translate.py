"""6502 -> SM83 translator for FF2 (English MMC5 build), from the generated source.

Adapted from tools/gb/recomp.py (FF1; copied, not shared). The instruction set comes
from the source base (tools/gb2/ff2code.py: everything8215 listing + insert.py modules),
so every routine is translated; nothing comes from running the NES (no coverage logs:
stack tricks and dynamic targets are found in the code and data of the source). emit_program(rc) returns
SM83 assembly for every code bank plus bank-0 stubs and the dynamic-target table, to be
assembled with tools/gb2/rt/*.s. See docs/ff2-gb-plan.md §3.

Conventions (runtime contract, rt/runtime.s):
  A = A, E = X (D = 0), C = Y (B = 0), HL scratch.
  6502 C = GB carry (same polarity at every instruction boundary), Z = GB Z flag,
  N = bit 7 of HRAM nzv, V = bit 6 of HRAM vfl (stored only where live).
  Runtime helpers preserve A, F, BC, DE unless they return a value (in L).
"""
import os, re, sys
from collections import defaultdict
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from ff2code import CodeMap, SPACES, index_of   # (SPACES: also ftrans)
from asm_sm83 import encode

DATA = 1                    # GB bank of NES 16KB bank 0's data image (NES bank n -> DATA + n)
RT_TABLES = DATA + 32       # runtime tables (sound)
CODE0 = DATA + 33           # first GB bank holding recompiled code
BANK_LIMIT = 0x4000 - 8     # bytes per code bank (room for a closing jump)
HOME_BASE = 0x1000          # bank_of value of home code: HOME_BASE + its data bank (code in bank 0)
HOME_ORG, HOME_END = 0x2800, 0x3400   # bank-0 area for home code (rt/native_layer.s helpers below, rt/ff2_pal.s after)
ALL = frozenset('NZCV')
# FF2: flags assumed live where control goes somewhere unknown (dynamic jumps / calls, returns to
# them): not V. Every BVC / BVS in FF2 tests V from a BIT just before it (b11:9C32, A076, B102,
# B186, B1D8, fix:C504, EDF3, FD49, FD5E), PHP / PLP keep their own liveness, so V from ADC / SBC
# never reaches an unknown successor (350 ADC and 149 SBC sites stopped computing it).
UNK = frozenset('NZC')

DEF = {'ADC': 'NZCV', 'SBC': 'NZCV', 'AND': 'NZ', 'ORA': 'NZ', 'EOR': 'NZ', 'ASL': 'NZC', 'LSR': 'NZC',
       'ROL': 'NZC', 'ROR': 'NZC', 'BIT': 'NZV', 'CMP': 'NZC', 'CPX': 'NZC', 'CPY': 'NZC', 'DEC': 'NZ',
       'DEX': 'NZ', 'DEY': 'NZ', 'INC': 'NZ', 'INX': 'NZ', 'INY': 'NZ', 'LDA': 'NZ', 'LDX': 'NZ', 'LDY': 'NZ',
       'TAX': 'NZ', 'TAY': 'NZ', 'TXA': 'NZ', 'TYA': 'NZ', 'TSX': 'NZ', 'PLA': 'NZ', 'CLC': 'C', 'SEC': 'C',
       'CLV': 'V', 'PLP': 'NZCV', 'RTI': 'NZCV', 'EXT': 'NZ'}
USE = {'ADC': 'C', 'SBC': 'C', 'ROL': 'C', 'ROR': 'C', 'BCC': 'C', 'BCS': 'C', 'BEQ': 'Z', 'BNE': 'Z',
       'BMI': 'N', 'BPL': 'N', 'BVC': 'V', 'BVS': 'V', 'PHP': 'NZC'}
# (FF2: after each PLP the code tests C or Z only (b03:AD45, b11:9BA3, B98D, fix:C084, CB46,
# EA9D; the battle NMI handlers' PLP / RTI restore their own context): PHP does not need V)
BRANCH = {'BCC', 'BCS', 'BEQ', 'BNE', 'BMI', 'BPL', 'BVC', 'BVS'}


def label(space, addr):
    return 'L_%s_%04X' % (space, addr)


class FF2:
    """Game-specific facts (English MMC5 build of FF2)."""
    reset = ('fix', 0xFE2E)
    reset_txs = ('fix', 0xFE8D)                  # DEX / TXS with X = 0 (vblank wait loop)
    # Native replacements: NES address -> (routine, flags it defines[, flags it reads]);
    # each returns to the caller of the NES routine like its RTS would.
    #   $FA2A / $FEAD: wait for vblank. FF2's NMI vector is $0100 in RAM; the wait writes
    #   JMP $FA3C / JMP $FEA1 there and spins; that stub writes RTI back, reads $2002 and
    #   drops the interrupt frame (PLA x3, A = $FA / $FE), returning to the waiter.
    ext = {('fix', 0xFA2A): ('rt_wait_fa2a', 'NZ'), ('fix', 0xFEAD): ('rt_wait_fead', 'NZ'),
           ('fix', 0xFD6F): ('hle_ppucopy', 'NZ'),       # copy data to ppu (rt/ff2.s, native)
           ('b11', 0x9D68): ('hle_fill', 'NZ'),          # fill ppu (rt/ff2.s, native)
           ('fix', 0xE50E): ('hle_copy_e50e', 'NZ'),     # copy large data to ppu (native)
           ('fix', 0xE51E): ('hle_copy_e51e', 'NZ'),     # copy data to ppu (native)
           # multiply / multiply (16-bit) / divide (16-bit): the same steps in registers
           # (results, side effects on $00-$07, A, flags); they read the incoming carry
           ('fix', 0xFC79): ('hle_mul8', 'NZC', 'C'), ('fix', 0xFC98): ('hle_mul16', 'NZC', 'C'),
           ('fix', 0xFCC3): ('hle_div16', 'NZC', 'C'),
           ('b11', 0x97D5): ('hle_initrng', 'NZC', 'C'),   # init rng (closed form, same end state)
           ('fix', 0xC46E): ('hle_oamclr', 'NZ'),       # clear OAM data (rt/ff2_pal.s, native)
           ('fix', 0xD21B): ('hle_mapupd', 'NZC'),      # update map background (rt/ff2_banked.s, native)
           ('b03', 0xA902): ('hle_objspr', 'NZCV'),     # draw object sprite (rt/ff2_banked.s, native)
           ('fix', 0xC2F3): ('hle_water', 'NZCV'),      # world-map water animation (rt/ff2_banked.s, native)
           ('fix', 0xF321): ('hle_ntclr0', 'NZC'),      # clear nametable 0 (rt/ff2_banked.s, native)
           ('b11', 0xA43A): ('hle_bspr', 'NZCV'),       # draw battle character sprite (rt/ff2_banked.s, native)
           ('fix', 0xDBA9): ('hle_pad20_b', 'NZC'),       # read joypad registers (rt/selmenu.s, native joypad)
           ('fix', 0xFE1A): ('hle_bank', 'NZC'),        # switch prg bank (rt/selmenu.s, native)
           ('fix', 0xDC30): ('hle_palcp_b', 'NZC'),       # copy colour palettes to ppu (rt/native_layer.s)
           ('fix', 0xFD4B): ('hle_scr4b_b', 'NZ'),        # battlefield scroll (rt/native_layer.s)
           ('fix', 0xCDF5): ('hle_cdf5_b', 'NZC'),        # update ppu registers, normal map (rt/native_layer.s)
           ('b13', 0x9C1F): ('hle_apuout_b', 'NZC'),      # update apu registers, music (rt/native_layer.s)
           ('fix', 0xF069): ('far:hle_txrow_b', 'NZC'),
           ('fix', 0xDCB5): ('hle_palbg_b', 'NZC'),     # copy color palettes to ppu (BG)
           ('fix', 0xD2FE): ('far:hle_dlgatt_b', 'NZ'),
           ('fix', 0xD308): ('far:hle_dlgatt8_b', 'NZ'),
           ('fix', 0xE9DC): ('hle_scr00_b', 'NZ'),      # clear ppu scrolling registers
           ('fix', 0xF689): ('hle_scr00_b', 'NZ'),      # (the same, splash screen)
           ('b11', 0x9D7C): ('hle_palbtl_b', 'NZC')}    # copy color palettes to ppu (battle)     # update dialog window attributes       # copy text to ppu (rt/native_layer.s)
    # Idioms: NES address -> (runtime routine, resume address, flags defined)
    #   fix:FA91-FA99: PHA $FA / PHA $99 / JMP ($0040): "jump (long)" calls through ($40)
    #   with a pushed return address: on the GB a call through the pointer, then $FA9A.
    #   Sprite-0 polling (BIT $2002 / BVS or BVC to itself): fix:FD46 (battle: wait for the
    #   flag to clear, battlefield scroll follows), fix:FD5B (wait for the hit, menu scroll
    #   follows), b11:A073 (wait for the end of vblank before a timed raster loop). No wait
    #   on the GB, V as the loop leaves it; the split itself is the battle layout's job.
    idioms = {('fix', 0xFA91): ('rt_call_ind40', 0xFA9A, 'NZ'),
              # the three calls of the music update b13:9800 (fix:FA53 in the battle NMI's sound
              # update, C754, and C74B's tail jump, resuming at the RTS C74E): one update owed,
              # played by mus_drain at most once per GB frame (rt/native_layer.s)
              ('fix', 0xFA53): ('hle_musreq', 0xFA56, 'NZC'), ('fix', 0xC754): ('hle_musreq', 0xC757, 'NZC'),
              ('fix', 0xC74B): ('hle_musreq', 0xC74E, 'NZC'),
              ('fix', 0xFD46): ('rt_s0_clear', 0xFD4B, 'NZV'), ('fix', 0xFD5B): ('rt_s0_hit', 0xFD60, 'NZV'),
              ('b11', 0xA073): ('rt_s0_clear', 0xA078, 'NZV'),
              # LDA $AC / BNE (wait until the battle NMI handler has run): rt_ac_wait
              ('b05', 0xA70A): ('rt_ac_wait', 0xA70E, 'NZ'), ('b12', 0xA630): ('rt_ac_wait', 0xA634, 'NZ'),
              ('b12', 0xA990): ('rt_ac_wait', 0xA994, 'NZ'),
              # fix:D93B-D95E map-transition curtain (BG off / on / off timed by delay calls,
              # fix:D962): the GB mask from rt_band (rt/runtime.s), with the calls' RAM effects
              ('fix', 0xD93B): ('rt_band', 0xD95F, 'NZ'),
              # fix:E69E-E6A5 LDA ($80),Y / STA $2007 / INY / BNE: a graphics page (rt/ff2.s)
              ('fix', 0xE69E): ('hle_chrpg', 0xE6A6, 'NZ'),
              # b11:9DB1-9DB8 LDA ($02),Y / STA $2007 / INY / BPL: battle intro tiles (rt/ff2.s)
              ('b11', 0x9DB1): ('hle_chr128', 0x9DB9, 'NZ'),
              # b11:9D82-9D8C LDA $79A8,X / STA $2007 / INX / CPX #$20 / BNE: battle palettes
              ('b11', 0x9D82): ('hle_palup', 0x9D8D, 'NZC'),
              # b11:9D24 STA ($24),Y / DEY / BPL; 9D4A LDA ($24),Y / STA ($26/$28/$2A),Y / INY /
              # CPY #$10 / BNE (battle, every frame; rt/ff2_banked.s)
              ('b11', 0x9D24): ('hle_bfill', 0x9D29, 'NZ'), ('b11', 0x9D4A): ('hle_bcopy', 0x9D57, 'NZC'),
              # fix:F496 / F4B1 STA $2007 / INY / BNE / DEX / BNE: X pages of A (rt/ff2.s)
              ('fix', 0xF496): ('hle_fillxy', 0xF49F, 'NZ'), ('fix', 0xF4B1): ('hle_fillxy', 0xF4BA, 'NZ'),
              ('b14', 0xB8B6): ('hle_fill4', 0xB8C5, 'NZ'),   # 4 x STA $2007 / DEX / BNE
              # b00 map load: metatile expansion, the >= $39 scan, a ROM page to $0400 (rt/ff2*.s)
              ('b00', 0x9D97): ('hle_mexp', 0x9DD0, 'NZC'), ('b00', 0x9DDB): ('hle_mscan', 0x9DDF, 'NZC'),
              ('b00', 0x9E44): ('hle_rcopy', 0x9E4D, 'NZ'),
              ('fix', 0xDAD4): ('hle_csum', 0xDADF, 'NZC'),    # save slot checksum (rt/ff2_banked.s)
              ('b14', 0xB27A): ('hle_savecp', 0xB288, 'NZ'),   # save copy + slot mark (rt/save.s)
              ('fix', 0xFC38): ('hle_pad35_b', 0xFC50, 'NZC'),   # battle joypad read (rt/selmenu.s)
              ('fix', 0xFD60): ('hle_scr60_b', 0xFD6C, 'NZ'),    # menu scroll after the sprite-0 hit (rt/native_layer.s)
              # boot splash (fix:F476..): row fills and glyph tile uploads (rt/native_layer.s)
              ('fix', 0xF565): ('far:hle_splrow0_b', 0xF580, 'NZ'),
              ('fix', 0xF5D4): ('far:hle_splrow8_b', 0xF5EE, 'NZ'),
              ('fix', 0xF632): ('far:hle_splchr8_b', 0xF649, 'NZC'),
              ('fix', 0xF653): ('far:hle_splchr64_b', 0xF681, 'NZC')}
    # battle NMI handlers (run by rt_nmi_run through the dynamic table; RTI = ret)
    nmi_handlers = [('b12', 0x9A79), ('b05', 0xA9A2)]
    idiom_code = {('fix', 0xFA91): bytes.fromhex('a9fa48a999486c4000'),
                  ('fix', 0xFA53): bytes.fromhex('200098'), ('fix', 0xC754): bytes.fromhex('200098'),
                  ('fix', 0xC74B): bytes.fromhex('4c009860'),
                  ('fix', 0xF565): bytes.fromhex('a5628d0620a5618d0620a5618580a2008e0720e680a580291fd0f5'),
                  ('fix', 0xF5D4): bytes.fromhex('2c0220a5628d0620a5618d0620a2808e0720e680a580291fd0f5'),
                  ('fix', 0xF632): bytes.fromhex('a9088d0620a9008d0620a200bd50038d0720e8e01090f5'),
                  ('fix', 0xF653): bytes.fromhex('a5644a4a4a4a8d0620a5640a0a0a0a8d0620a200bd50038d0720e8e01090f5'
                                                 'a5628d0620a5618d0620a5648d0720'),
                  ('fix', 0xFD46): bytes.fromhex('2c022070fb'), ('fix', 0xFD5B): bytes.fromhex('2c022050fb'),
                  ('b11', 0xA073): bytes.fromhex('2c022070fb'),
                  ('b05', 0xA70A): bytes.fromhex('a5acd0fc'), ('b12', 0xA630): bytes.fromhex('a5acd0fc'),
                  ('b12', 0xA990): bytes.fromhex('a5acd0fc'),
                  ('fix', 0xD93B): bytes.fromhex('a20acad0fda9108d0120'),
                  ('fix', 0xE69E): bytes.fromhex('b1808d0720c8d0f8'),
                  ('b11', 0x9DB1): bytes.fromhex('b1028d0720c810f8'),
                  ('b11', 0x9D82): bytes.fromhex('bda8798d0720e8e020d0f5'),
                  ('b11', 0x9D24): bytes.fromhex('91248810fb'),
                  ('b11', 0x9D4A): bytes.fromhex('b12491269128912ac8c010d0f3'),
                  ('fix', 0xF496): bytes.fromhex('8d0720c8d0faca'), ('fix', 0xF4B1): bytes.fromhex('8d0720c8d0faca'),
                  ('b14', 0xB8B6): bytes.fromhex('8d07208d07208d07208d0720cad0f1'),
                  ('b00', 0x9D97): bytes.fromhex('a488be0074a000bd00789180c8bd8078'),
                  ('b00', 0x9DDB): bytes.fromhex('b180c939'), ('b00', 0x9E44): bytes.fromhex('bd008b9d0004e8d0f7'),
                  ('fix', 0xDAD4): bytes.fromhex('187180c8d0fae681cad0f5'),
                  ('b14', 0xB27A): bytes.fromhex('b1829180c8d0f9e681e683cad0f2'),
                  ('fix', 0xFC38): bytes.fromhex('a9018d1640a9008d1640a208ad16406ab0016a6635cad0f4'),
                  ('fix', 0xFD60): bytes.fromhex('a53a29ff8d0020a5388d0520')}
    skip = [('fix', 0xFA2C, 0xFA48), ('fix', 0xFEA1, 0xFEAD), ('fix', 0xFEAF, 0xFEBF)]   # waits (but their entries) + NMI return stubs
    # Annotation (everything8215 disassembly, for ftrans' write sets): zero-page indexed
    # stores of a space stay in this range. b13 (music engine): X is the channel id $C5
    # (0-2), $C6 = 2 * id, $C7 = 4 * id, or a loop counter (L0D_987C X < 6, L0D_98AB X < $12,
    # L0D_98C8 X < 4): $B0,X .. $C0,X stores land in $B0-$C1 (bound kept at $B0-$CF).
    zpx_writes = {'b13': (0xB0, 0xCF)}


class Recompiler:
    def __init__(self, cm, game=FF2):
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
        out.append((i.space, i.addr + i.size))
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
        # From the code alone (the disassembly, no NES run): a run of 2 or 4 PLAs that leaves
        # by RTS / JMP within 8 straight-line instructions, with no PHA in the 16 bytes before, drops return addresses (b05:A021
        # battle victory exit, b11:AF16, fix:F194, ...)
        for (sp, a), i in self.insns.items():
            if i.mn != 'PLA' or (sp, a) in self.pla_drop: continue
            p = self.insns.get((sp, a - 1))
            if p is not None and p.mn == 'PLA': continue            # not the first of the run
            n = 0
            while (lambda j: j is not None and j.mn == 'PLA')(self.insns.get((sp, a + n))): n += 1
            if n not in (2, 4): continue
            if any((lambda j: j is not None and j.mn in ('PHA', 'PHP'))(self.insns.get((sp, b))) for b in range(a - 16, a)):
                continue
            q, ok = a + n, False
            for _ in range(8):
                j = self.insns.get((sp, q))
                if j is None or j.mode == 'rel' or j.mn in ('PHA', 'PHP', 'PLA', 'PLP', 'RTI', 'BRK', 'TXS'): break
                if j.mn in ('RTS', 'JMP'): ok = True; break
                q += j.size
            if not ok: continue
            for m in range(n):
                self.pla_drop[(sp, a + m)] = 'pop' if m % 2 == 0 else 'none'
            self.static_drops = getattr(self, 'static_drops', []) + [(sp, a, n)]
        # RTS dispatch (PHA / PHA / RTS): none in FF2 (the "jump (long)" fix:FA91 is an idiom)

    # ------------------------------------------------------------ dynamic targets
    def dyn_targets(self):
        """NES addresses that can be reached through JMP (ind), RTS dispatch or a JSR/JMP
        into $8000-$BFFF from code outside that bank."""
        t = set()
        for k, i in self.insns.items():
            if i.mn in ('JSR', 'JMP') and i.mode == 'abs' and self.target(i, i.arg) is None:
                for c in self.dyn_candidates(i.arg): t.add(c)
                if not self.dyn_candidates(i.arg): self.warn.append('no known code for %r' % i)
        t.add(self.g.reset)
        t |= set(self.g.nmi_handlers)
        t |= self.static_dyn_targets()
        return sorted(t)

    def static_dyn_targets(self):
        """FF2: targets of JMP (ind) / jump (long) known from the source: little-endian
        words in a space's data (not instruction bytes) that point at an instruction start
        of that space (or the fixed bank / ExRAM), and pointer pairs built from immediates
        (LDA #lo / STA zp ... LDA #hi / STA zp+1)."""
        t = set(); code = defaultdict(set)
        for (sp, a), i in self.insns.items():
            code[sp].update(range(a, a + i.size))
        ends = {}                                       # (space, addr) -> insn ending there
        for (sp, a), i in self.insns.items(): ends[(sp, a + i.size)] = i
        def owner(sp, w):
            for ts in (sp, 'fix', 'ex'):
                if (ts, w) in self.insns and SPACES[ts][0] <= w < SPACES[ts][0] + SPACES[ts][2]:
                    p = ends.get((ts, w))               # a routine start: not reached by
                    if p is None or p.mn in ('RTS', 'RTI', 'JMP', 'BRK'):   # falling through
                        return ts
            return None
        for sp, (base, off, size) in SPACES.items():
            for a in range(base, base + size - 1):
                if a in code[sp] or a + 1 in code[sp]: continue
                w = self.cm.byte(sp, a) | self.cm.byte(sp, a + 1) << 8
                ts = owner(sp, w)
                if ts: t.add((ts, w))
        for (sp, a), i in self.insns.items():           # jump tables: runs of 3+ JMP abs (entries
            def jmp(k):                                 #   reached through jump (long) / RTS
                j = self.insns.get((sp, k))             #   dispatch with a computed low byte)
                return j is not None and j.mn == 'JMP' and j.mode == 'abs'
            if jmp(a) and ((jmp(a - 3) and jmp(a - 6)) or (jmp(a - 3) and jmp(a + 3)) or (jmp(a + 3) and jmp(a + 6))):
                t.add((sp, a))
        for (sp, a), i in self.insns.items():
            if not (i.mn == 'LDA' and i.mode == 'imm'): continue
            st = self.insns.get((sp, a + 2))
            if st is None or st.mn != 'STA' or st.mode != 'zp': continue
            for d in range(4, 12):
                j = self.insns.get((sp, a + d)); k = self.insns.get((sp, a + d + 2))
                if j is None or k is None: continue
                if j.mn == 'LDA' and j.mode == 'imm' and k.mn == 'STA' and k.mode == 'zp' and k.arg == st.arg + 1:
                    ts = owner(sp, i.arg | j.arg << 8)
                    if ts: t.add((ts, i.arg | j.arg << 8))
                    break
        return t

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
        work = list(ins)
        while work:
            k = work.pop(); i = ins[k]
            lo = frozenset()
            for s in outs[k]:
                lo |= UNK if (s is None or s not in ins) else live_in[s]
            if k in self.g.ext:                             # (an optional third field: flags
                li = (lo - frozenset(self.g.ext[k][1])) | frozenset(self.g.ext[k][2:3] and self.g.ext[k][2] or '')
            elif k in self.g.idioms:
                li = lo - frozenset(self.g.idioms[k][2])
            elif i.mn == 'JSR':
                li = lo                                     # = live_in(callee), set via outs
            else:
                li = frozenset(USE.get(i.mn, '')) | (lo - frozenset(DEF.get(i.mn, '')))
                if i.mn == 'JMP' and i.mode == 'ind': li = UNK
                if k in self.rts_dispatch: li = UNK
            if lo != live_out[k] or li != live_in[k]:
                live_out[k], live_in[k] = lo, li
                work.extend(preds[k])
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
        if self.k in getattr(rc, 'nskip', ()): self.need = self.need - {'N'}   # (N tested from the register)
        self.keep = self.lo - d                           # live flags it must not disturb
        self.cf = getattr(rc, 'cfix', {}).get(self.k, ())   # carry polarity (ftrans.carry_states)

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
        if self.i.mode in ('zpx', 'zpy'): self.o('res 0, h')   # zero-page index wraps ($C0xx)
        if protect: self.o('pop af')

    def izy_direct(self):
        """(zp),Y whose pointer high byte is proven (ftrans facts) to lie in work RAM
        $00-$06, ExRAM $5C-$5E or cart RAM $60-$7E (so ptr + Y stays in the region, which
        maps linearly to GB memory): HL = GB address, inline. Returns False otherwise."""
        i = self.i
        if i.mode != 'izy': return False
        f = getattr(self.rc, 'izy_facts', {}).get(self.k)     # (lo, hi) of the pointer high byte
        if not f: return False
        def reg(h):
            return 'ram' if h <= 0x06 else 'ex' if 0x5C <= h <= 0x5E else 'sram' if 0x60 <= h <= 0x7E else None
        rs = {reg(f[0]), reg(f[1])}
        if len(rs) != 1 or None in rs: return False
        off = {'ram': 0xC0, 'ex': 0x6C, 'sram': 0x40}[rs.pop()]
        zp = 0xC000 + i.arg
        protect = 'C' in self.keep or 'C' in USE.get(i.mn, '')
        if f[0] == f[1]:
            self.o('ld hl, $%04X' % zp, 'ld l, [hl]', 'ld h, $%02X' % ((f[0] + off) & 0xFF))
            if protect: self.o('push af', 'add hl, bc', 'pop af')
            else: self.o('add hl, bc')
        else:                                         # (the NES pointer read as the runtime does: $FF -> $C100)
            self.o('push af', 'ld hl, $%04X' % zp, 'ld a, [hl+]', 'ld h, [hl]', 'ld l, a',
                   'ld a, h', 'add a, $%02X' % off, 'ld h, a', 'add hl, bc', 'pop af')
        self.rc.izy_direct_n = getattr(self.rc, 'izy_direct_n', 0) + 1
        return True

    def operand(self):
        """emit code that makes the source operand available; returns an SM83 operand
        string ('[hl]', 'l', or '$nn')."""
        i = self.i; m = i.mode
        if m == 'imm': return '$%02X' % i.arg
        if self.izy_direct(): return '[hl]'
        hb = getattr(self.rc, 'home', {}).get(self.k)
        if m == 'izy' and hb is not None:                 # home code: pointer into the mapped bank
            self.o('ld l, $%02X' % i.arg, 'call %s' % ('rt_izy_rdem' if hb == DATA + 31 else 'rt_izy_rd8m'))
            return 'l'
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
            hb = getattr(self.rc, 'home', {}).get(self.k)      # home code: its data bank is mapped
            if hb is not None and ((r == 'rom8' and i.space.startswith('b') and hb == DATA + int(i.space[1:]))
                                   or (r == 'rome' and hb == DATA + 31)):
                self.rc.home_direct = getattr(self.rc, 'home_direct', 0) + 1
                return '[hl]'
            self.o('call rt_rd_%s' % r[3:])
            return 'l'
        if r == 'ppu':
            self.o('call rt_ppu_r%d' % (a & 7)); return 'l'
        if r == 'io':
            self.o('call rt_io_r%04X' % a if a in (0x4015, 0x4016, 0x4017) else 'call rt_io_rnone'); return 'l'
        self.o('ld l, 0'); self.rc.warn.append('read of %04X at %r' % (a, i)); return 'l'

    def store(self, reg):
        """store register reg ('a', 'e', 'c') to the instruction's address"""
        i = self.i; m = i.mode
        if self.izy_direct():
            self.o('ld [hl], %s' % reg); return
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
        if r == 'ppu' and a & 7 in (3, 4): return       # OAM address / data: no GB effect
        if r == 'ppu' and a & 7 == 0:                   # control: the runtime's copy
            if reg == 'a': self.o('ldh [ppu_ctrl], a')
            else: self.o('push af', 'ld a, %s' % reg, 'ldh [ppu_ctrl], a', 'pop af')
            return
        if r == 'ppu': name = 'rt_ppu_w%d' % (a & 7)
        elif r == 'io': name = 'gb_sprites' if a == 0x4014 else 'rt_io_w4016' if a == 0x4016 else 'rt_apu_w'
        elif r == 'mmc': name = 'rt_mmc_w%04X' % a if a in (0x5115, 0x5116, 0x5800, 0x5801, 0x5802, 0x5803, 0x5804, 0x5805, 0x5806, 0x5807, 0x5808, 0x5809, 0x580A, 0x580B) else None
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
        if inverted and 'C' in self.need and 'keep' not in self.cf: self.o('ccf')

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
        if 'pre' in self.cf: self.o('ccf')
        self.run1()
        if 'post' in self.cf: self.o('ccf')

    def run1(self):
        i = self.i; mn = i.mn; rc = self.rc
        k = self.k
        if k in rc.g.ext:
            r = rc.g.ext[k][0]
            if r.startswith('far:'):                    # banked native routine: called in place
                r = r[4:]
                for l in ('call rt_fcs', 'db bank(%s)' % r, 'dw %s' % r): self.o(l)   # (returns to our caller)
            else:
                self.o('jp ' + r)
            return
        if k in rc.g.idioms:
            r = rc.g.idioms[k][0]
            if r.startswith('far:'):                    # banked native: rst $08 (returns here)
                self.o('rst $08', 'db bank(%s)' % r[4:], 'dw %s' % r[4:])
            else:
                self.o('call ' + r)
            self.jump(None, (i.space, rc.g.idioms[k][1])); return
        h = getattr(self, 'x_' + mn, None)
        if h is None:
            rc.warn.append('no translation for %r' % i); self.o('call rt_fatal')
        else:
            h()

    # loads / stores
    def x_LDA(self):
        i = self.i
        if i.mode in ('zp', 'abs') and (i.mode == 'zp' or nes_region(i.arg) in ('ram', 'ex', 'sram')):
            g = gb_ram(i.arg if i.mode == 'abs' else i.arg)   # (direct: ld a, [nn])
            self.o('ld a, [$%04X]' % g)
        else:
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
        if (p is not None and p.mn == 'LDX' and p.mode == 'imm' and p.arg == 0xFF) or \
                (p1 is not None and p1.mn == 'DEX' and self.k == self.rc.g.reset_txs):
            self.o('ld sp, STACK_TOP'); return     # stack reset (reset: DEX from X = 0)
        # FF2: X from an earlier TSX (saved stack pointer): rt_txs maps it back
        self.rc.warn.append('TXS from a saved X at %r' % self.i)
        self.o('call rt_txs')

    def x_TSX(self):
        # FF2: X = an NES-like stack pointer: $FF - (GB stack depth) / 2. GB entries are
        # 2 bytes each (a PHA too), so this is >= the NES S; the GB stack pointer itself
        # is kept for rt_txs (stack depth checks and longjmp-style restores)
        self.rc.warn.append('TSX at %r' % self.i)
        self.o('call rt_tsx'); self.set_nz_reg('e')

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
            if 'sbc_i' not in self.cf: self.o('ccf')
            self.o('sbc a, %s' % src)
            if 'C' in self.need and 'keep' not in self.cf: self.o('ccf')
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
        ns = getattr(self.rc, 'nsrc', {}).get(self.k)
        if flag_test and ns and flag_test[0] == 'nzv':    # N from the register (ftrans.n_tests)
            self.o('bit 7, %s' % ns)
            self.jump(cond_true, tk)
            return
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

    def x_BCC(self): self.branch('c' if 'swap' in self.cf else 'nc')
    def x_BCS(self): self.branch('nc' if 'swap' in self.cf else 'c')
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

    def thread(self, tk):
        """follow JMP abs stubs (FF2: fix:FE00 JMP $FEAD wait for vblank, FE03 JMP $FE1A
        switch bank ...) to the routine they lead to"""
        for _ in range(4):
            if tk is None or tk in self.rc.g.ext: return tk
            j = self.rc.insns.get(tk)
            if j is None or j.mn != 'JMP' or j.mode != 'abs' or tk in self.rc.g.idioms: return tk
            nt = self.rc.target(j, j.arg)
            if nt is None or (nt not in self.rc.insns and nt not in self.rc.g.ext): return tk
            tk = nt
        return tk

    def x_JSR(self):
        i = self.i
        tk = self.thread(self.rc.target(i, i.arg))
        if tk is None:
            self.o('ld hl, $%04X' % i.arg, 'call rt_dyn_call'); return
        if tk in self.rc.g.ext:                       # a native replacement: called directly
            r = self.rc.g.ext[tk][0]
            if r.startswith('far:'): self.o('rst $08', 'db bank(%s)' % r[4:], 'dw %s' % r[4:])
            else: self.o('call ' + r)
            return
        if tk not in self.rc.insns and tk not in self.rc.g.ext:
            self.rc.warn.append('call to uncompiled %s:%04X from %r' % (tk[0], tk[1], i))
            self.o('call rt_fatal'); return
        self.o('call ' + label(*tk))

    def x_RTS(self):
        if self.k in self.rc.rts_dispatch: self.o('jp rt_rts_dispatch')
        else: self.o('ret')

    def x_RTI(self):
        # FF2: only the battle NMI handlers end in RTI; rt_nmi_run calls them
        self.o('ret')

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
    if mn == 'db': return len(args)
    if mn == 'dw': return 2 * len(args)
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
    for k in code:                                  # (room for in-place far calls: retarget)
        sizes[k] += sum(1 if l.strip().startswith('call L_') else 2 if l.strip().startswith('jp L_') else 0
                        for l in code[k])
    comps = components(rc)
    comps.sort(key=lambda c: (min(c)[0], min(c)[1]))
    bank_of = {}
    banks = []                                            # [(bank, [keys], size)]
    cur, used, keys = CODE0, 0, []
    home = getattr(rc, 'home', {})
    homes = defaultdict(list)
    for k, hb in home.items():                            # home code (per instruction: cross-bank
        bank_of[k] = HOME_BASE + hb                       #   fall-through / jumps are routed)
        homes[HOME_BASE + hb].append(k)
    comps = [[k for k in c if k not in home] for c in comps]
    comps = [c for c in comps if c]
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
    for hb, ks in sorted(homes.items()): banks.append((hb, ks))
    return bank_of, banks, code, sizes


def emit_program(rc, blocks=None):
    if blocks is None: blocks = rc.compile()
    bank_of, banks, code, sizes = layout(rc, blocks)
    out = []
    xrefs = set()                                         # labels needing a bank-0 stub
    first_home = True
    for bank, keys in banks:
        if bank >= HOME_BASE:
            if first_home: out.append('section bank 0, $%04X' % HOME_ORG); first_home = False
            out.append('home_%02X:' % (bank - HOME_BASE))
        else:
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
                ft = (i.space, i.addr + i.size)
                if ft is not None and (n + 1 >= len(keys) or keys[n + 1] != ft):
                    if ft in rc.insns:
                        out.append('    ' + retarget('jp ' + label(*ft), bank, bank_of, xrefs))
                    elif i.mn != 'JSR' or True:
                        out.append('    call rt_fatal')
    # stubs (bank 0): call rt_fcs reads the target's bank and address after the call
    stubs = []                                          # (bank 0, after the home code)
    for lab in sorted(xrefs):
        stubs += ['xs_%s:' % lab, '    call rt_fcs', '    db %s' % bank_expr(lab, bank_of), '    dw %s' % lab,
                  'xj_%s:' % lab, '    call xs_%s' % lab, '    ret']
    # dynamic targets (bank DYN_BANK): 256 buckets by (nes_lo + nes_hi + key) & $FF; index
    # of bucket pointers at $4000, each bucket = count, then entries of nes_lo, nes_hi,
    # key, gb_bank, gb_lo, gb_hi
    buckets = defaultdict(list)
    for sp, a in rc.dyn:
        if (sp, a) not in rc.insns: continue
        key = int(sp[1:]) if sp.startswith('b') else 0xFF
        buckets[((a & 0xFF) + (a >> 8) + key) & 0xFF].append((a, key, label(sp, a)))
    tab = ['section bank DYN_BANK, $4000', 'dyn_index:']
    for h in range(256): tab.append('    dw dyn_b%d' % h)
    for h in range(256):
        tab.append('dyn_b%d:' % h)
        tab.append('    db %d' % len(buckets[h]))
        for a, key, lab in buckets[h]:
            tab.append('    db $%02X, $%02X, $%02X, %s, low(%s), high(%s)' % (a & 0xFF, a >> 8, key, bank_expr(lab, bank_of), lab, lab))
    rc.n_dyn = sum(len(v) for v in buckets.values())
    if stubs:
        if first_home: out.append('section bank 0, $%04X' % HOME_ORG)
        out.append('xstubs:')
        out.extend(stubs)
    return '\n'.join(tab + out) + '\n', bank_of, banks


def bank_expr(lab, bank_of):
    """the bank to map for a code label: its ROM bank, or a home routine's data bank"""
    sp, a = lab[2:].rsplit('_', 1)
    b = bank_of.get((sp, int(a, 16)))
    return '$%02X' % (b - HOME_BASE) if b is not None and b >= HOME_BASE else 'bank(%s)' % lab


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
                    if op == 'jp ':
                        # a jump into another bank: call the stub and return (keeps the
                        # caller's bank correct when the target finally returns)
                        if ',' in s:
                            cond = s[len(op):].split(',')[0].strip()
                            xrefs.add(tgt)
                            return 'jp %s, xj_%s' % (cond, tgt)
                        return 'rst $08\n    db %s\n    dw %s\n    ret' % (bank_expr(tgt, bank_of), tgt)
                    if ',' in s:
                        xrefs.add(tgt)
                        return line.replace(tgt, 'xs_' + tgt)
                    # (rt_fci: the far call in place)
                    return 'rst $08\n    db %s\n    dw %s' % (bank_expr(tgt, bank_of), tgt)
    return line
