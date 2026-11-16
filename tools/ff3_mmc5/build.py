"""Convert Final Fantasy III (J) from MMC3 (512KB) to MMC5 (1MB PRG, 8KB battery
PRG-RAM, 8KB CHR-RAM).

8KB bank layout of the output:
  0-63   original banks (bank numbers used by the game unchanged)
  64     source of the helper routines copied to MMC5 ExRAM ($5C00) at reset
  65-125 free (0xFF) -- room for the English script
  126/127 patched copies of the fixed banks $3E/$3F; MMC5 maps the last bank at $E000
          on power-on, and the reset code maps 126 at $C000.

MMC3 -> MMC5 mapping
  R6/R7 ($8000/$A000 8KB PRG)  -> $5114/$5115 (PRG mode 3), value | $80 (ROM)
  $A000 mirroring               -> $5105 ($44 vertical, $50 horizontal)
  $A001 PRG-RAM enable          -> $5102=2/$5103=1, $5113=0
  CHR R0-R5 (CHR-RAM, identity) -> CHR mode 0, bank 0
  IRQ counter                   -> $5203/$5204 scanline IRQ. MMC3 semantics as used by
     the game: latch L + reload in vblank fires on line L-1; latch V written right after
     an IRQ on line s (no reload) fires on line s+1+V. The helper routines keep the
     current target in ExRAM and reproduce exactly that. MMC5 fires at the start of the
     line, MMC3 around dot 260, so the IRQ entry delays 85 CPU cycles before running
     the game's handler.

usage: build.py "Final Fantasy III (Japan).nes" OUT.nes
"""
import sys, hashlib

SHA1_IN = 'c4443fc24625e3c2bb859525eb44b6b3a80e7c35'
B8 = 0x2000
NOP = 0xEA

# ---- helper routines, assembled for $5C00 (ExRAM) ----
# Item syntax: int = byte; 'name' = 16-bit address of a label; ('lo'|'hi', name) = one
# byte of it; ('L', name) defines a label here; ('b', opcode, name) = relative branch.
_PARTS = [
    ('curtgt',  [0x00]),                      # line of the next IRQ (MMC3 numbering)
    ('lastirq', [0x00]),                      # line of the IRQ just delivered
    ('entab',   [0x00, 0x80]),                # $5204 values: disable / enable
    ('irq_entry', [                           # hardware IRQ at the start of the line
        0x2C, 0x04, 0x52,                     # BIT $5204   ; acknowledge (clears pending)
        0x48,                                 # PHA
        0xAD, 'curtgt', 0x8D, 'lastirq',      # LDA curtgt / STA lastirq
        0xA9, 8,                              # LDA #8 + 2 NOPs ; delay: the game's handler
        ('L', 'd1'), 0x38, 0xE9, 0x01, ('b', 0xD0, 'd1'),   # starts on the same dot as with
        0xEA, 0xEA,                           #   MMC3 (calibrated against its $E000 write)
        0x68,                                 # PLA
        0x4C, 0x30, 0xFB]),                   # JMP $FB30   ; the game's IRQ handler
    ('nmi_setup', [                           # A = latch L + reload, $01 = 0 disable / 1 enable
        0x38, 0xE9, 0x01,                     # SEC / SBC #1 ; MMC3 fires on line L-1
        0x8D, 'curtgt', 0x8D, 0x03, 0x52,     # STA curtgt / STA $5203
        0x2C, 0x04, 0x52,                     # BIT $5204   ; drop a stale pending flag
        0xA6, 0x01,                           # LDX $01
        0xBD, 'entab',                        # LDA entab,X
        0x8D, 0x04, 0x52,                     # STA $5204
        0x60]),                               # RTS
    ('latch',   [0x00]),                      # emulated MMC3 latch ($C000)
    ('enable', [                              # $E001 after a latch write right after an IRQ
        0xAD, 'latch',                        # LDA latch
        0x38, 0x6D, 'lastirq',                # SEC / ADC lastirq ; MMC3: line + V + 1
        0x8D, 'curtgt', 0x8D, 0x03, 0x52,     # STA curtgt / STA $5203
        0xA9, 0x80, 0x8D, 0x04, 0x52,         # LDA #$80 / STA $5204
        0x60]),                               # RTS
    # Battle raster effect (bank $2F, $B8AC-$B8D9). The MMC3 loop chains an IRQ every 2
    # lines and writes $2000 twice per pair; its timing is too tight for MMC5's line-start
    # IRQ, so it is reproduced directly: table value k takes effect on line 41+k (k < 108),
    # i.e. it is written at the start of line 40+k, found by polling MMC5's pending flag.
    ('fx_line', [0x00]),
    ('fx2f', [
        0xA0, 0x00,                           # LDY #0
        0xA9, 40, 0x8D, 'fx_line',            # LDA #40 / STA fx_line
        ('L', 'fxl'),
        0xAD, 'fx_line', 0x8D, 0x03, 0x52,    # LDA fx_line / STA $5203 (IRQ itself disabled)
        ('L', 'fxp'),
        0x2C, 0x04, 0x52, ('b', 0x10, 'fxp'), # BIT $5204 / BPL fxp   ; line start
        0xB9, 0x00, 0x73,                     # LDA $7300,Y
        0x8D, 0x00, 0x20, 0x85, 0x08,         # STA $2000 / STA $08
        0xC8, 0xEE, 'fx_line',                # INY / INC fx_line
        0xC0, 108, ('b', 0xD0, 'fxl'),        # CPY #108 / BNE fxl
        # leave the IRQ model as the MMC3 loop leaves it: last IRQ on line 147
        0xA9, 147, 0x8D, 'lastirq',
        0x2C, 0x04, 0x52,                     # BIT $5204 (drop pending)
        0xA2, 0x36,                           # LDX #$36 (as the loop leaves it; Y = 108)
        0x60]),
    ('mir_h', [0xA9, 0x50, 0x8D, 0x05, 0x51, 0x60]),
    ('mir_v', [0xA9, 0x44, 0x8D, 0x05, 0x51, 0x60]),
]

def _size(x):
    if isinstance(x, tuple):
        return {'L': 0, 'b': 2, 'lo': 1, 'hi': 1}[x[0]]
    return 2 if isinstance(x, str) else 1

def _assemble(base=0x5C00):
    labels, pc = {}, base
    for name, code in _PARTS:
        labels[name] = pc
        for x in code:
            if isinstance(x, tuple) and x[0] == 'L': labels[x[1]] = pc
            pc += _size(x)
    out = bytearray(); pc = base
    for name, code in _PARTS:
        for x in code:
            if isinstance(x, tuple):
                if x[0] == 'b':
                    d = labels[x[2]] - (pc + 2); assert -128 <= d <= 127
                    out += bytes([x[1], d & 0xFF])
                elif x[0] == 'lo': out.append(labels[x[1]] & 0xFF)
                elif x[0] == 'hi': out.append(labels[x[1]] >> 8)
            elif isinstance(x, str): out += bytes([labels[x] & 0xFF, labels[x] >> 8])
            else: out.append(x)
            pc += _size(x)
    return bytes(out), labels

EXRAM, LABELS = _assemble()
IRQ_ENTRY, NMI_SETUP = LABELS['irq_entry'], LABELS['nmi_setup']
MIR_H, MIR_V, ENABLE, LATCH = LABELS['mir_h'], LABELS['mir_v'], LABELS['enable'], LABELS['latch']
FX2F = LABELS['fx2f']
assert len(EXRAM) <= 0xFF

def jsr(a): return bytes([0x20, a & 0xFF, a >> 8])

def patch(rom, off, old, new):
    old = bytes(old); new = bytes(new)
    assert len(old) == len(new), (hex(off), old.hex(), new.hex())
    assert rom[off:off+len(old)] == old, (hex(off), rom[off:off+len(old)].hex(), old.hex())
    rom[off:off+len(new)] = new

def convert(src):
    rom = bytearray(src)
    E = 0x7E000 - 0xE000        # file offset of a $E000-$FFFF address in bank $3F
    # --- PRG bank routines (cycle-matched, A and flags as before) ---
    patch(rom, E+0xFF0C, [0x48,0xA9,0x06,0x8D,0x00,0x80,0x68,0x8D,0x01,0x80,0x60],
                         [0x48,0x09,0x80,0x8D,0x14,0x51,0x68,NOP,NOP,0x60,NOP])
    patch(rom, E+0xFF1F, [0x48,0xA9,0x07,0x8D,0x00,0x80,0x68,0x8D,0x01,0x80,0x60],
                         [0x48,0x09,0x80,0x8D,0x15,0x51,0x68,NOP,NOP,0x60,NOP])
    for at, reg in ((0xFB8B, 0x14), (0xFB9C, 0x15)):   # IRQ-guarded variant at $FB87
        patch(rom, E+at, [0xA9,0x06 if reg == 0x14 else 0x07,0xE6,0xA9,0x8D,0x00,0x80,0x68,0x8D,0x01,0x80],
                         [0xE6,0xA9,0x68,0x09,0x80,0x8D,reg,0x51,0x29,0x7F,NOP])
    # bank $36: R7 switch split over two places; table entries get bit 7 (ROM select)
    patch(rom, 0x6C99F, [0xA9,0x07,0x8D,0x00,0x80], [0xA5,0x07,0x4C,0xA4,0x89])  # 6 cycles kept
    patch(rom, 0x6C9BB, [0x8D,0x01,0x80], [0x8D,0x15,0x51])
    for k in range(4): rom[0x6C9BF+k] |= 0x80
    # --- mirroring ---
    patch(rom, 0x3F15C, [0xA9,0x01,0x8D,0x00,0xA0], jsr(MIR_H) + bytes([0xA9,0x01]))
    patch(rom, 0x3F1D0, [0xA9,0x00,0x8D,0x00,0xA0], jsr(MIR_V) + bytes([0xA9,0x00]))
    # --- IRQ ---
    # NMI handler: latch + reload + enable/disable
    patch(rom, E+0xFB66, [0x8D,0x00,0xC0,0x8D,0x01,0xC0,0xA6,0x01,0x9D,0x00,0xE0],
                         jsr(NMI_SETUP) + bytes([NOP]*8))
    # IRQ handler ack ($E000 = disable + ack) -> disable MMC5 IRQ (ack happens at entry)
    patch(rom, E+0xFB45, [0x8D,0x00,0xE0,0xA9,0x00,0x85,0x00], [0xA9,0x00,0x8D,0x04,0x52,0x85,0x00])
    # IRQ vector trampoline $0103: JMP $FB30 -> JMP irq_entry
    patch(rom, E+0xFAD2, [0xA9,0x30,0x8D,0x04,0x01,0xA9,0xFB,0x8D,0x05,0x01],
                         [0xA9,IRQ_ENTRY & 0xFF,0x8D,0x04,0x01,0xA9,IRQ_ENTRY >> 8,0x8D,0x05,0x01])
    # battle raster effect loop ($B8AC-$B8D9 in bank $2F) -> JSR fx2f / JMP $B8DA
    loop = bytes.fromhex('a9018d00c08d01e0b9007385084820' '79fb688d0020c8b9007385' '08a905857ec67ed0fca5088d0020c8e8e036d0d2')
    patch(rom, 0x5F8AC, loop, jsr(FX2F) + bytes([0x4C, 0xDA, 0xB8]) + bytes([NOP] * (len(loop) - 6)))
    # chained splits: STA $C000 / STA $E001 -> STA latch / JSR enable. Kept as two
    # 3-byte halves because code also enters at the second one (JSR $808E in bank $33).
    for off in (0x20B43, 0x3F5E1, 0x5F8E0, 0x6408B, 0x64B52):
        patch(rom, off, [0x8D,0x00,0xC0,0x8D,0x01,0xE0],
              [0x8D, LATCH & 0xFF, LATCH >> 8] + list(jsr(ENABLE)))
    # --- reset ($FF48-$FFB8) rebuilt ---
    # MMC5 init and the ExRAM copy (~1900 cycles) run between the two vblank waits,
    # where the original idles anyway (the PPU can power up inside vblank, so running
    # them before the first wait would miss that vblank and start a frame late). After the waits, a delay replaces the 404-cycle
    # MMC3 init so the game starts on exactly the same CPU cycle with the same
    # registers (A=$80, X=6, Y=0, N=1 Z=0 C=1).
    mmc5_init = bytes([
        0xA9,0x03,0x8D,0x00,0x51,                  # PRG mode 3 (4x 8KB)
        0xA9,0x02,0x8D,0x02,0x51,0x8D,0x04,0x51,   # PRG-RAM protect 1 / ExRAM = CPU RAM
        0xA9,0x01,0x8D,0x03,0x51,                  # PRG-RAM protect 2
        0xA9,0x44,0x8D,0x05,0x51,                  # vertical mirroring
        0xA9,0x00,0x8D,0x01,0x51,0x8D,0x13,0x51,0x8D,0x27,0x51,0x8D,0x2B,0x51,  # ($5130 unused with 8KB CHR-RAM)
        0xA9,0xFE,0x8D,0x16,0x51,                  # $C000 = bank 126 (patched copy of $3E)
        0xA9,0xC0,0x8D,0x14,0x51,                  # $8000 = bank 64 (helper source)
        0xA2,len(EXRAM),0xBD,0xFF,0x7F,0x9D,0xFF,0x5B,0xCA,0xD0,0xF7,   # copy helpers (X=n..1)
    ])
    orig_head = rom[E+0xFF48:E+0xFF55]      # SEI CLD LDA #0 STA $2000 STA $2001 STA $4010
    orig_wait = rom[E+0xFF55:E+0xFF5F]      # LDX #2 / BIT $2002 / BPL / DEX / BNE
    orig_stack = rom[E+0xFF5F:E+0xFF6D]     # LDX #$FF TXS LDA #$40 STA $0100 STA $0103 STA $4017
    assert orig_head.hex() == '78d8a9008d00208d01208d1040' and orig_wait.hex() == 'a2022c022010fbcad0f8'
    tail = bytes([0xA0,79, 0x88,0xD0,0xFD,       # LDY #79 / DEY / BNE : 2 + 5*79 - 1, Y=0
                  0xEA, 0xA2,0x06, 0x38, 0xA9,0x80,   # NOP LDX #6 SEC LDA #$80   (total 404)
                  0x4C,0x00,0xC0])               # JMP $C000
    wait1 = bytes([0x2C,0x02,0x20,0x10,0xFB])      # BIT $2002 / BPL
    wait2 = wait1 + bytes([0xEA, 0xEA])            # 4 cycles = the original DEX/BNE exit
                                                    # (X is reloaded right after)
    code = orig_head + wait1 + mmc5_init + wait2 + orig_stack + tail
    n = 0xFFB9 - 0xFF48                           # through the old CHR table at $FFB3-$FFB8
    assert len(code) <= n, len(code)
    rom[E+0xFF48:E+0xFFB9] = code + bytes([NOP] * (n - len(code)))
    # --- assemble the 1MB image ---
    out = bytearray(b'\xFF' * (128 * B8))
    out[0:len(rom)] = rom
    out[64*B8:64*B8+len(EXRAM)] = EXRAM
    out[126*B8:127*B8] = rom[0x3E*B8:0x3F*B8]
    out[127*B8:128*B8] = rom[0x3F*B8:0x40*B8]
    hdr = bytes([0x4E,0x45,0x53,0x1A, 0x40, 0x00, 0x52, 0x08, 0x00, 0x00, 0x70, 0x07, 0,0,0,0])
    return hdr + bytes(out)

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()
    if hashlib.sha1(data).hexdigest() != SHA1_IN:
        sys.exit('unexpected input ROM (sha1 mismatch)')
    open(sys.argv[2], 'wb').write(convert(data[16:]))
    print('wrote', sys.argv[2])
