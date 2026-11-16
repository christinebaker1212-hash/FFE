"""Split the Japanese "Final Fantasy I・II" cart (MMC1/SUROM, 512KB) into two
standalone MMC5 ROMs (512KB PRG each, 8KB battery PRG-RAM, 8KB CHR-RAM).

Layout of each output ROM (16KB banks):
  0-15  : the game's original 256KB half (bank numbers used by the game unchanged)
  16-30 : free (0xFF) -- room for the English script
  31    : patched copy of the game's fixed bank; MMC5 maps the last bank at
          $E000 on power-on, and mode 1 keeps it at $C000-$FFFF.

usage: build_mmc5.py "Final Fantasy I, II (Japan).nes" OUTDIR
"""
import sys, os, hashlib

SHA1_IN = '4b22c2c88fc71eacf270ea51ef218944bb4c536a'
BANK = 0x4000

def asm_init_mmc5():
    """MMC5 init, split in three chunks (sizes 12 / 11 / rest)."""
    p1 = bytes([0xA9, 0x01, 0x8D, 0x00, 0x51,   # LDA #1 / STA $5100  PRG mode 1 (16K+16K)
                0x8D, 0x03, 0x51,               # STA $5103 = 1        PRG-RAM write enable (2/2)
                0x0A, 0x8D, 0x02, 0x51])        # ASL A / STA $5102 = 2 PRG-RAM write enable (1/2)
    p2 = bytes([0xA9, 0x00, 0x8D, 0x01, 0x51,   # LDA #0 / STA $5101  CHR mode 0 (8KB)
                0x8D, 0x13, 0x51,               # STA $5113            PRG-RAM bank 0 at $6000
                0x8D, 0x27, 0x51])              # STA $5127            CHR bank 0
    p3 = bytes([0xA9, 0x44, 0x8D, 0x05, 0x51])  # LDA #$44 / STA $5105 vertical mirroring
    return p1, p2, p3

JMP = lambda a: bytes([0x4C, a & 0xFF, a >> 8])
NOP = 0xEA

def put(fixed, cpu, data):
    o = cpu - 0xC000
    fixed[o:o+len(data)] = data

def common_patches(fixed):
    # Both MMC1 routines leave A = A_in >> 4 with the flags of the last LSR, and
    # callers rely on that, so the replacements end the same way. X/Y untouched.
    LSR4_RTS = bytes([0x68, 0x4A, 0x4A, 0x4A, 0x4A, 0x60])        # PLA / LSR x4 / RTS
    # Each replacement is padded to exactly the 34 cycles of the MMC1 original
    # (5x STA abs + 4x LSR + RTS), so game timing (lag frames, RNG) is unchanged.
    # Padding = LDA $00 (3) / NOP (2) before PLA, which restores A and N/Z.
    # $FE06 (MMC1 control write): both games only ever select vertical mirroring.
    code = bytes([0x48, 0xA9, 0x44, 0x8D, 0x05, 0x51,              # PHA / LDA #$44 / STA $5105   (9)
                  0xA5, 0x00, 0xEA, 0xEA]) + LSR4_RTS             # LDA $00 / NOP / NOP (7) + 18 = 34
    put(fixed, 0xFE06, code + bytes([NOP]) * (0xFE1A - 0xFE06 - len(code)))
    # $FE1A (MMC1 PRG bank write): A = 16KB bank -> MMC5 $5115 = bank*2 | $80 (ROM)
    code = bytes([0x48, 0x0A, 0x09, 0x80, 0x8D, 0x15, 0x51,        # PHA / ASL / ORA #$80 / STA $5115 (11)
                  0xA5, 0x00, 0xEA]) + LSR4_RTS                   # LDA $00 / NOP (5) + 18 = 34
    put(fixed, 0xFE1A, code + bytes([NOP]) * (0xFE2E - 0xFE1A - len(code)))

def patch_ff1(fixed):
    common_patches(fixed)
    p1, p2, p3 = asm_init_mmc5()
    # $FDF0 was the MMC1 reset routine (called once from reset at $FE48): first half
    # of MMC5 init. Mirroring is then set by the JSR $FE06 at $FE4B.
    put(fixed, 0xFDF0, p1 + b'\x60' + bytes([NOP]) * 2)
    # Reset: $FE50-$FE5A selected the low 256KB half via the CHR register (MMC1 only);
    # the rest of MMC5 init fits there exactly. X is already 0 (vblank wait loop),
    # as the loop used to leave it.
    assert len(p2) == 0xFE5B - 0xFE50
    put(fixed, 0xFE50, p2)
    # Skip the compilation's game-select menu (JSR $AD00 in bank 6) -> straight to FF1.
    assert fixed[0xFE7B - 0xC000:0xFE7E - 0xC000] == bytes([0x20, 0x00, 0xAD])
    put(fixed, 0xFE7B, bytes([NOP]) * 3)

def patch_ff2(fixed):
    common_patches(fixed)
    p1, p2, p3 = asm_init_mmc5()
    # Reset jumped to $FF00 (the cart's boot path into the menu). Go to FF2's own
    # start-up at $FE4B instead, which the menu used to enter after switching halves.
    assert fixed[0xFE48 - 0xC000:0xFE4B - 0xC000] == JMP(0xFF00)
    put(fixed, 0xFE48, bytes([NOP]) * 3)
    # $FE4B-$FE78 was MMC1 reset + CHR register writes; replace with MMC5 init
    # (X is already 0 here from the vblank wait loop), then continue at $FE79.
    code = p1 + p2 + p3 + JMP(0xFE79)
    assert len(code) <= 0xFE79 - 0xFE4B
    put(fixed, 0xFE4B, code + bytes([NOP]) * (0xFE79 - 0xFE4B - len(code)))

def header(prg_16k_banks):
    # NES 2.0: mapper 5, battery, 8KB PRG-NVRAM, 8KB CHR-RAM
    h = bytearray(b'NES\x1a')
    h += bytes([prg_16k_banks & 0xFF, 0, 0x52, 0x08, 0, prg_16k_banks >> 8, 0x70, 0x07, 0, 0, 0, 0])
    return bytes(h)

def build(rom, which):
    half = rom[0:0x40000] if which == 1 else rom[0x40000:0x80000]
    out = bytearray(b'\xFF' * (32 * BANK))
    out[0:0x40000] = half
    fixed = bytearray(half[15*BANK:16*BANK])
    (patch_ff1 if which == 1 else patch_ff2)(fixed)
    out[15*BANK:16*BANK] = fixed      # keep bank 15 identical to the fixed bank
    out[31*BANK:32*BANK] = fixed
    return header(32) + bytes(out)

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()
    if hashlib.sha1(data).hexdigest() != SHA1_IN:
        sys.exit('unexpected input ROM (sha1 mismatch)')
    rom = data[16:]
    os.makedirs(sys.argv[2], exist_ok=True)
    for which, name in ((1, 'ff1_mmc5.nes'), (2, 'ff2_mmc5.nes')):
        p = os.path.join(sys.argv[2], name)
        open(p, 'wb').write(build(rom, which))
        print('wrote', p)
