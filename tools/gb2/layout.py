"""FF2 GB layout: NES-side re-layout of the English FF2 build for the Game Boy's 160x144.

Applied after tools/ff2/insert.py: build/ff2_en.nes -> build/ff2_gb.nes (still an NES ROM:
it runs in cynes, and the GB build of it is checked against it frame by frame). The GB
runtime reads the camera registers written here ($5800-$5805, nothing on the NES; see
tools/gb2/rt/ff2.s). Owner's layouts: docs/ff2-gb-screens.md.

usage: layout.py build/ff2_en.nes build/ff2_gb.nes

Free space used: fixed bank $F800-$F84F (unused code, rom-map.txt)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from asm6502 import asm

HDR, BANK = 16, 0x4000


def put(rom, bank, cpu, data, old=None):
    base = 0xC000 if bank == 31 else 0x8000
    o = HDR + bank * BANK + cpu - base
    if old is not None:
        assert rom[o:o + len(old)] == old, ('%02X/%04X' % (bank, cpu), rom[o:o + len(old)].hex(), old.hex())
    rom[o:o + len(data)] = data


# ---------------------------------------------------------------- battle
# GB view (docs/ff2-gb-screens.md): GB lines 0-95 = NES x 20-179, y 48-143 (enemy area +
# party column); lines 96-143 = the windows (second camera).
CAM_BATTLE = dict(x=2, fine=4, y=6, line=96, x2=0, y2=7)

FIX_SRC = '''
    org $F800
btlcam:                 ; fix:FAB9 (JMP $9639, init battle): battle cameras first
    lda #CX
    sta $5800
    lda #CF
    sta $5802
    lda #CY
    sta $5801
    lda #CX2
    sta $5804
    lda #CY2
    sta $5805
    lda #CL
    sta $5803
    jmp $9639
fieldcam:               ; fix:FA0F (return from battle; LDA #$0E / JSR $FE1A): field camera
    lda #6
    sta $5800
    sta $5801
    lda #0
    sta $5802
    sta $5803
    lda #$0E
    jmp $FE1A
end:
'''


def battle(rom):
    c = CAM_BATTLE
    f = asm(FIX_SRC, syms=dict(CX=c['x'], CF=c['fine'], CY=c['y'], CX2=c['x2'], CY2=c['y2'], CL=c['line']))
    assert f.org + len(f.bytes) <= 0xF850
    put(rom, 31, f.org, f.bytes)
    put(rom, 31, 0xFAB9, bytes([0x4C]) + f.labels['btlcam'].to_bytes(2, 'little'), old=bytes.fromhex('4c3996'))
    put(rom, 31, 0xFA0F, bytes([0x20]) + f.labels['fieldcam'].to_bytes(2, 'little') + b'\xEA\xEA',
        old=bytes.fromhex('a90e201afe'))
    # party: y = slot * 24 + 48 (NES: * 27 + 44), base x 156 front / 160 back (NES 208 / 224):
    # GB x 140 / 144, every member in a 24-px slot of the 96-px battlefield
    put(rom, 11, 0x9B68, bytes([0xA2, 24]), old=bytes([0xA2, 0x1B]))
    put(rom, 11, 0x9B6F, bytes([0x69, 48]), old=bytes([0x69, 0x2C]))
    put(rom, 11, 0xA102, bytes([0xA9, 156]), old=bytes([0xA9, 0xD0]))
    put(rom, 11, 0xA109, bytes([0xA9, 160]), old=bytes([0xA9, 0xE0]))


def apply(rom):
    battle(rom)


if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    apply(rom)
    open(sys.argv[2], 'wb').write(rom)
    print('wrote', sys.argv[2])
