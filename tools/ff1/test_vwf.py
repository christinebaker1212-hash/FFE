"""Run the GB layout's small-font routines (gb_layout far code) in py65 (pip install
py65): PPU writes are captured, $F499 / $F47D are stubbed, and the uploaded tiles are
printed as pixels. usage: test_vwf.py [party | text "TEXT" ROW COL]"""
import os, sys
sys.argv.append('--gb')
sys.path.insert(0, os.path.dirname(__file__)); sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import insert, gb_layout
from asm6502 import asm
from py65.devices.mpu6502 import MPU
from py65.memory import ObservableMemory

code = asm('    org $C000\n' + gb_layout.far_source(insert.ENC), syms=insert.EX)


class PPU:
    def __init__(self): self.latch, self.addr, self.chr = 0, 0, {}
    def w(self, a, v):
        if a == 0x2006:
            self.addr = ((v & 0x3F) << 8) | (self.addr & 0xFF) if self.latch == 0 else (self.addr & 0x3F00) | v
            self.latch ^= 1
        elif a == 0x2007:
            if self.addr < 0x2000: self.chr[self.addr] = v
            self.addr += 1
    def r(self, a):
        self.latch = 0; return 0


def machine():
    ppu = PPU(); mem = ObservableMemory()
    mem.subscribe_to_write(range(0x2000, 0x2008), lambda a, v: ppu.w(a, v))
    mem.subscribe_to_read(range(0x2000, 0x2008), lambda a: ppu.r(a))
    m = MPU(memory=mem)
    for i, b in enumerate(code.bytes): mem[0xC000 + i] = b
    mem[0xF499] = mem[0xF47D] = mem[gb_layout.MUSIC] = 0x60
    return m, mem, ppu


def call(m, mem, label, a=0):
    mem[0x01FF], mem[0x01FE] = 0xFF, 0xFE
    m.sp, m.pc, m.a = 0xFD, code.labels[label], a
    for _ in range(2000000):
        if m.pc == 0xFFFF: return
        m.step()
    raise SystemExit('no return from ' + label)


def show(ppu, first, n):
    for r in range(8):
        line = ''
        for t in range(first, first + n):
            p0 = ppu.chr.get(t * 16 + r, 0); p1 = ppu.chr.get(t * 16 + 8 + r)
            line += ''.join('#' if p0 >> (7 - b) & 1 else ('.' if p1 is not None and not (p1 >> (7 - b) & 1) else '?') for b in range(8))
        print(line)


if __name__ == '__main__':
    m, mem, ppu = machine()
    if sys.argv[1] == 'party':
        for k, ch in enumerate('WWWW'): mem[0x6102 + k] = insert.ENC[ch]
        mem[0x610A], mem[0x610B], mem[0x610C], mem[0x610D] = 192, 0, 899 & 255, 899 >> 8
        mem[0x6101] = 0x04                                  # poison
        mem[0x685E] = 0
        call(m, mem, 'party_line', 0)
        print('tiles written:', sorted({a >> 4 for a in ppu.chr}))
        show(ppu, 0x80, 10)
