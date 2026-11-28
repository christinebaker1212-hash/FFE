"""A headless NES for FF3's game logic (the core rewrite's checks, docs/ff3-gb-rewrite.md): py65's 6502,
the English build's MMC5 (PRG banks $5113-$5117, ExRAM, the scanline IRQ $5203 / $5204), PPU registers
with VRAM / palette memory for $2007 reads and the V-Blank flag / NMI timing, the pad on $4016. Nothing
is drawn; FF3's code runs from reset on the user's English ROM (build/ff3_en.nes).

    nes = Nes('build/ff3_en.nes'); nes.frames(60, pad=0)
    nes.breakpoints = {0xE1E1}; nes.run_until_break()   (hooks at any PC: entry states for fdiff)
    st = nes.state(); nes.load_state(st)
"""
import os, sys, pickle
from py65.devices.mpu6502 import MPU

B8 = 0x2000
FRAME = 29781                    # CPU cycles a frame (NTSC)
VBL_START = 241 * 341 // 3       # cycles into the frame where V-Blank starts (scanline 241)
LINE = 341 / 3


class Bus(bytearray):
    def __init__(self, nes):
        bytearray.__init__(self, 0x10000)
        self.nes = nes

    def __getitem__(self, a):
        if isinstance(a, slice):
            return bytearray.__getitem__(self, a)
        n = self.nes
        if a < 0x2000:
            return bytearray.__getitem__(self, a & 0x7FF)
        if a < 0x4000:
            return n.ppu_read(a & 7)
        if a == 0x4016:
            v = (n.shift >> 7) & 1
            n.shift = (n.shift << 1) & 0xFF
            return v | 0x40
        if a == 0x5204:
            v = (0x80 if n.irq_pending else 0) | (0x40 if n.in_frame() else 0)
            n.irq_pending = False
            return v
        return bytearray.__getitem__(self, a)

    def __setitem__(self, a, v):
        if isinstance(a, slice):
            return bytearray.__setitem__(self, a, v)
        n = self.nes
        v &= 0xFF
        if a < 0x2000:
            bytearray.__setitem__(self, a & 0x7FF, v)
        elif a < 0x4000:
            n.ppu_write(a & 7, v)
        elif a == 0x4016:
            if v & 1:
                n.shift = n.pad
        elif 0x5113 <= a <= 0x5117:
            n.prg_write(a, v)
        elif a == 0x5105:
            n.mirror = v
        elif a == 0x5203:
            n.irq_line = v
        elif a == 0x5204:
            n.irq_on = bool(v & 0x80)
        elif 0x5C00 <= a < 0x6000 or 0x6000 <= a < 0x8000:
            bytearray.__setitem__(self, a, v)


class Nes:
    def __init__(self, rom_path):
        d = open(rom_path, 'rb').read()
        self.prg = d[16:16 + d[4] * 0x4000]
        self.nbanks = len(self.prg) // B8
        self.bus = Bus(self)
        self.cpu = MPU(memory=self.bus)
        self.vram = bytearray(0x800); self.pal = bytearray(0x20); self.chr = bytearray(0x2000)
        self.mirror = 0x44                 # MMC5 $5105: $44 vertical (side by side), $50 horizontal
        self.ctrl = self.mask = 0; self.addr = 0; self.latch = 0; self.vbl = False; self.buf = 0
        self.pad = 0; self.shift = 0
        self.irq_line = 0; self.irq_on = False; self.irq_pending = False; self.irq_done = False
        self.banks = [0, 0, 0, self.nbanks - 1]
        for s in range(4):
            self.map(s, self.banks[s])
        self.cyc = 0                      # cycles into the frame
        self.frame_no = 0
        self.breakpoints = set()
        self.hit = None
        self.cpu.reset()
        self.cpu.pc = self.bus[0xFFFC] | self.bus[0xFFFD] << 8

    # ---- the mapper
    def map(self, slot, bank):
        bank %= self.nbanks
        self.banks[slot] = bank
        o = bank * B8
        bytearray.__setitem__(self.bus, slice(0x8000 + slot * B8, 0xA000 + slot * B8), self.prg[o:o + B8])

    def prg_write(self, a, v):
        if a == 0x5113:
            return                         # one 8 KB PRG-RAM bank
        slot = a - 0x5114
        if v & 0x80:
            self.map(slot, v & 0x7F)

    # ---- the PPU registers
    def vaddr(self, a):
        a &= 0x3FFF
        if a >= 0x3F00:
            a &= 0x1F
            if a in (0x10, 0x14, 0x18, 0x1C):
                a -= 0x10
            return ('p', a)
        if a >= 0x2000:
            sel = (a >> 10) & 3                       # nametable 0-3 -> its 1 KB page by $5105
            page = (self.mirror >> (2 * sel)) & 1
            return ('v', (a & 0x3FF) | (page << 10))
        return ('c', a)

    def ppu_read(self, r):
        if r == 2:
            v = (0x80 if self.vbl else 0)
            self.vbl = False; self.latch = 0
            return v
        if r == 7:
            k, o = self.vaddr(self.addr)
            if k == 'p':
                v = self.pal[o]
            else:
                v = self.buf
                self.buf = self.vram[o] if k == 'v' else self.chr[o]
            self.addr = (self.addr + (32 if self.ctrl & 4 else 1)) & 0x3FFF
            return v
        return 0

    def ppu_write(self, r, v):
        if r == 0:
            self.ctrl = v
        elif r == 1:
            self.mask = v
        elif r == 6:
            if self.latch == 0:
                self.addr = (self.addr & 0xFF) | (v & 0x3F) << 8
            else:
                self.addr = (self.addr & 0xFF00) | v
            self.latch ^= 1
        elif r == 5:
            self.latch ^= 1
        elif r == 7:
            if getattr(self, 'plog', None) is not None:
                self.plog.append((self.addr, v))
            k, o = self.vaddr(self.addr)
            if k == 'p':
                self.pal[o] = v
            elif k == 'v':
                self.vram[o] = v
            else:
                self.chr[o] = v
            self.addr = (self.addr + (32 if self.ctrl & 4 else 1)) & 0x3FFF

    def in_frame(self):
        return self.cyc < VBL_START

    # ---- interrupts
    def interrupt(self, vec):
        c = self.cpu
        c.stPushWord(c.pc)
        c.stPush((c.p | c.UNUSED) & ~c.BREAK)
        c.p |= c.INTERRUPT
        c.pc = self.bus[vec] | self.bus[vec + 1] << 8

    def step(self):
        c = self.cpu
        before = c.processorCycles
        c.step()
        d = c.processorCycles - before
        old = self.cyc
        self.cyc += d
        if self.irq_on and not self.irq_done and self.irq_line and self.cyc >= self.irq_line * LINE:
            self.irq_done = True
            self.irq_pending = True
        if self.irq_pending and self.irq_on and not (c.p & c.INTERRUPT):
            self.irq_pending_taken = True
            self.interrupt(0xFFFE)
            self.irq_pending = False
        if old < VBL_START <= self.cyc:
            self.vbl = True
            if self.ctrl & 0x80:
                self.interrupt(0xFFFA)
        if self.cyc >= FRAME:
            self.cyc -= FRAME
            self.vbl = False
            self.irq_done = False
            self.frame_no += 1
            return True
        return False

    def frames(self, n, pad=0):
        self.pad = pad
        for _ in range(n):
            while not self.step():
                if self.cpu.pc in self.breakpoints:
                    self.hit = self.cpu.pc
                    return False
        return True

    def run_until_break(self, max_frames=600, pad=0):
        self.pad = pad
        f0 = self.frame_no
        while self.frame_no - f0 < max_frames:
            self.step()
            if self.cpu.pc in self.breakpoints:
                self.hit = self.cpu.pc
                return True
        return False

    # ---- state
    def ram(self):
        """the NES RAM FF3 uses: $0000-$07FF, $6000-$7FFF"""
        b = self.bus
        return bytes(bytearray.__getitem__(b, slice(0, 0x800))), bytes(bytearray.__getitem__(b, slice(0x6000, 0x8000)))

    def state(self):
        c = self.cpu
        return pickle.dumps({'mem': bytes(self.bus), 'cpu': (c.pc, c.a, c.x, c.y, c.sp, c.p),
                             'banks': list(self.banks), 'ppu': (self.ctrl, self.mask, self.addr, self.latch, self.vbl,
                             self.buf, bytes(self.vram), bytes(self.pal)), 'irq': (self.irq_line, self.irq_on),
                             'chr': bytes(self.chr), 'mirror': self.mirror,
                             'cyc': self.cyc, 'frame': self.frame_no})

    def load_state(self, blob):
        s = pickle.loads(blob)
        bytearray.__setitem__(self.bus, slice(0, 0x10000), s['mem'])
        c = self.cpu
        c.pc, c.a, c.x, c.y, c.sp, c.p = s['cpu']
        self.banks = s['banks']
        (self.ctrl, self.mask, self.addr, self.latch, self.vbl, self.buf, v, p) = s['ppu']
        self.vram = bytearray(v); self.pal = bytearray(p)
        self.irq_line, self.irq_on = s['irq']
        self.chr = bytearray(s.get('chr', bytes(0x2000))); self.mirror = s.get('mirror', 0x44)
        self.cyc = s['cyc']; self.frame_no = s['frame']


if __name__ == '__main__':
    import time
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')
    n = Nes(os.path.join(root, 'build', 'ff3_en.nes'))
    t = time.time()
    n.frames(int(sys.argv[1]) if len(sys.argv) > 1 else 120)
    print('frames', n.frame_no, 'pc %04X' % n.cpu.pc, 'banks', [hex(b) for b in n.banks], '%.1fs' % (time.time() - t))
    print('ram 0-1F', n.ram()[0][:32].hex())
