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
_PARTS = [
    ('curtgt', [0x00]),                       # current IRQ target line
    ('entab',  [0x00, 0x80]),                 # $5204 values: disable / enable
    ('irq_entry', [
        0x2C, 0x04, 0x52,                     # BIT $5204   ; acknowledge (clears pending)
        0x48,                                 # PHA
        0xA9, 10,                             # LDA #10     ; 15 + 7*10 = 85 cycles in total
        0x38, 0xE9, 0x01, 0xD0, 0xFB,         # loop: SEC / SBC #1 / BNE loop
        0x68,                                 # PLA
        0x4C, 0x30, 0xFB]),                   # JMP $FB30   ; the game's IRQ handler
    ('nmi_setup', [                           # A = MMC3 latch L, $01 = 0 disable / 1 enable
        0x38, 0xE9, 0x01,                     # SEC / SBC #1 ; fires on line L-1
        0x8D, 'curtgt',                       # STA curtgt
        0x8D, 0x03, 0x52,                     # STA $5203
        0xA6, 0x01,                           # LDX $01
        0xBD, 'entab',                        # LDA entab,X
        0x8D, 0x04, 0x52,                     # STA $5204
        0x60]),                               # RTS
    ('chain', [                               # A = latch V written right after an IRQ (kept)
        0x48,                                 # PHA
        0x38, 0x6D, 'curtgt',                 # SEC / ADC curtgt ; curtgt + V + 1
        0x8D, 'curtgt',                       # STA curtgt
        0x8D, 0x03, 0x52,                     # STA $5203
        0xA9, 0x80, 0x8D, 0x04, 0x52,         # LDA #$80 / STA $5204
        0x68, 0x60]),                         # PLA / RTS
    ('mir_h', [0xA9, 0x50, 0x8D, 0x05, 0x51, 0x60]),
    ('mir_v', [0xA9, 0x44, 0x8D, 0x05, 0x51, 0x60]),
]
def _assemble(base=0x5C00):
    labels, pc = {}, base
    for name, code in _PARTS:
        labels[name] = pc
        pc += sum(2 if isinstance(x, str) else 1 for x in code)
    out = bytearray()
    for name, code in _PARTS:
        for x in code:
            if isinstance(x, str): out += bytes([labels[x] & 0xFF, labels[x] >> 8])
            else: out.append(x)
    return bytes(out), labels
EXRAM, LABELS = _assemble()
IRQ_ENTRY, NMI_SETUP, CHAIN = LABELS['irq_entry'], LABELS['nmi_setup'], LABELS['chain']
MIR_H, MIR_V = LABELS['mir_h'], LABELS['mir_v']
assert len(EXRAM) <= 0x80

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
    # chained splits: STA $C000 / STA $E001 -> JSR chain
    for off in (0x20B43, 0x3F5E1, 0x5F8AE, 0x5F8E0, 0x6408B, 0x64B52):
        patch(rom, off, [0x8D,0x00,0xC0,0x8D,0x01,0xE0], jsr(CHAIN) + bytes([NOP]*3))
    # --- reset: MMC3 init ($FF6D-$FFAF) -> MMC5 init + copy helpers to ExRAM ---
    init = bytes([
        0xA9,0x03,0x8D,0x00,0x51,                  # PRG mode 3 (4x 8KB)
        0xA9,0x02,0x8D,0x02,0x51,0x8D,0x04,0x51,   # PRG-RAM protect 1 / ExRAM = CPU RAM
        0xA9,0x01,0x8D,0x03,0x51,                  # PRG-RAM protect 2
        0xA9,0x44,0x8D,0x05,0x51,                  # vertical mirroring
        0xA9,0x00,0x8D,0x01,0x51,0x8D,0x13,0x51,0x8D,0x27,0x51,0x8D,0x2B,0x51,0x8D,0x30,0x51,
        0xA9,0xFE,0x8D,0x16,0x51,                  # $C000 = bank 126 (patched copy of $3E)
        0xA9,0xC0,0x8D,0x14,0x51,                  # $8000 = bank 64 (helper source)
        0xA2,0x7F,0xBD,0x00,0x80,0x9D,0x00,0x5C,0xCA,0x10,0xF7,   # copy 128 bytes
        0xA2,0x06,0xA9,0x80,                       # leave X/A as the MMC3 code did
    ])
    n = 0xFFB0 - 0xFF6D
    assert len(init) <= n
    rom[E+0xFF6D:E+0xFFB0] = init + bytes([NOP] * (n - len(init)))
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
