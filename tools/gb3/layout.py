"""FF3 GBC screen layouts on the NES side (after tools/ff3/insert.py), as FF1 / FF2 do: the game
code itself draws its screens for a 160x144 view, so the GB build can still be checked frame
by frame against this "GB-layout" NES ROM.

usage: layout.py EN.nes OUT.nes        (EN.nes = the English build, build/ff3_en.nes)

Patches are matched by their original bytes (a wrong address stops the build). Owner's
decisions: docs/ff3-gb-plan.md section 6.

Battle (decision 3, with FF1 / FF2's battle rules):
- cameras (GB runtime registers, open bus on the NES): battlefield camera NES x 20 / y 48
  (pixels, $5802 / $5803), window camera (tiles, $5800 / $5801) = col 2 / row 6, split at GB
  line 96 ($5804); field camera back after the battle
- party column GB x 140-159: front row NES x 160, back row 164; members 24 px apart from NES
  y 47 (GB rows 0-11, every sprite whole); acting members step 8 px (back row 12)
- battle windows from NES row 18 (GB row 12) instead of 19, one tile row per text line (the
  English text has no dakuten row): 4 text rows; party window cols 2-21 (GB 0-19), command
  and enemy-name windows cols 2-11 (GB 0-9)
"""
import os, sys, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.path.insert(0, HERE)
from asm6502 import asm
B8 = 0x2000
FONT = 0x1B000                          # English font: tile N = code N (PRG offset)
ARROW = 0xCA                            # unused code (Japanese katakana A): the message arrow
ARROW_ROWS = ['........', '..#.....', '..##....', '#####...', '..##....', '..#.....', '........',
              '........']

# battle message window (bank 52, in place of FF3's open / close message window routines
# $8D1B-$8E82 and their box table $8E83-$8EAF): one full-width window, NES rows 18-23 cols
# 2-21 (GB rows 12-17), 4 lines of 18 columns. The first window opened saves the area and
# draws an empty frame (a row per frame); each message then takes the next free line(s),
# word-wrapped (a message needing more lines than are free covers the last ones); the target
# goes on the attacker's line after an arrow when it fits. Closing a window blanks its cells;
# closing the last one restores the area. State in the English box save buffer (ExRAM $5E90,
# free: FF3's boxes saved there).
MSG_SRC = '''
MCNT  = $5E90       ; windows open
MUSED = $5E91       ; lines in use (0-4)
MALEN = $5E92       ; attacker's length on line 0 (0: none)
MFIRST = $5E93      ; per window id (5): first line,
MNUM  = $5E98       ;   number of lines,
MCOL  = $5E9D       ;   first column
MLINE = $5EA2       ; line image (18)
MSAVE = $5EB4       ; the area under the window (6 x 20)
WAIT1 = $8185       ; wait one frame
PPUREG = $8D03      ; ppu control / mask / scroll again
SETADR = $F8E0      ; ppu address A (high) X (low)
    org $8D1B
msgopen:            ; A = window id: 0 attacker, 1 action, 2 target, 3 status, 4 message
    sta $1E
    lda MCNT
    bne .o1
    sta MUSED
    sta MALEN
    sta $1F
    sta $1D
.f:
    jsr WAIT1
    jsr maddr
    lda $2007
    ldx #20
    ldy $1D
.r:
    lda $2007
    sta MSAVE,y
    iny
    dex
    bne .r
    sty $1D
    jsr maddr
    ldy $1F
    lda FL,y
    sta $2007
    lda FM,y
    ldx #18
.m:
    sta $2007
    dex
    bne .m
    lda FR,y
    sta $2007
    jsr PPUREG
    inc $1F
    lda $1F
    cmp #6
    bne .f
.o1:
    inc MCNT
    ldx $1E
    lda #0
    sta MCOL,x
    cpx #2
    bne .nl
    ldy #0              ; target: the arrow in front
    lda #ARROW
.i:
    ldx $7AD7,y
    sta $7AD7,y
    iny
    txa
    bne .i
    sta $7AD7,y
    lda MALEN           ; on the attacker's line when it fits
    beq .nl
    jsr mlen
    sec
    adc MALEN
    cmp #19
    bcs .nl
    jsr mclr
    ldy MALEN
    iny
    ldx #0
.a:
    lda $7AD7,x
    beq .ad
    sta MLINE,y
    inx
    iny
    bne .a
.ad:
    lda MALEN
    sta $1D
    sta MCOL+2
    lda #0
    sta $1F
    sta MFIRST+2
    lda #1
    sta MNUM+2
    jmp mput
.nl:
    lda #0              ; lines needed
    sta $1B
    sta $19
.cn:
    jsr mline
    inc $19
    ldx $1B
    lda $7AD7,x
    bne .cn
    lda $19
    cmp #5
    bcc .c4
    lda #4
    sta $19
.c4:
    clc
    adc MUSED
    cmp #5
    lda MUSED
    bcc .st
    lda #4
    sec
    sbc $19
.st:
    sta $1F
    ldx $1E
    sta MFIRST,x
    lda $19
    sta MNUM,x
    clc
    adc $1F
    sta MUSED
    cpx #0              ; the attacker alone on line 0: its length
    bne .dr
    lda $1F
    ora #0
    bne .dr
    jsr mlen
    sta MALEN
.dr:
    lda #0
    sta $1B
    sta $1D
.dl:
    jsr mline
    jsr mput
    inc $1F
    dec $19
    bne .dl
    rts

msgclose:           ; A = window id
    tax
    dec MCNT
    beq .rs
    lda MNUM,x
    sta $19
    lda MFIRST,x
    sta $1F
    lda MCOL,x
    sta $1D
    bne .bl
    lda $1F
    clc
    adc $19
    cmp MUSED
    bne .bl
    lda $1F
    sta MUSED
.bl:
    jsr mclr
.b2:
    jsr mput
    inc $1F
    dec $19
    bne .b2
    rts
.rs:
    lda #0              ; the last one: the area back
    sta $1F
    sta $1D
.r:
    jsr WAIT1
    jsr maddr
    ldx #20
    ldy $1D
.rl:
    lda MSAVE,y
    sta $2007
    iny
    dex
    bne .rl
    sty $1D
    jsr PPUREG
    inc $1F
    lda $1F
    cmp #6
    bne .r
    rts

'''
MSG_END = 0x8EB0
MSGX_SRC = '''
MLINE = $5EA2
WAIT1 = $8185
PPUREG = $8D03
SETADR = $F8E0
    org $5F30           ; (ExRAM, after MSAVE: the window's helpers)
maddr:              ; ppu address of window row $1F, column 0 ($2242 + 32 row)
    lda $1F
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #$42
    tax
    lda #$22
    jmp SETADR

mput:               ; MLINE from column $1D on to text line $1F (0-3), in a frame
    jsr WAIT1
    lda $1F
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #$63
    adc $1D
    tax
    lda #$22
    jsr SETADR
    ldy $1D
.p:
    lda MLINE,y
    sta $2007
    iny
    cpy #18
    bne .p
    jmp PPUREG

mclr:
    ldy #17
    lda #$FF
.c:
    sta MLINE,y
    dey
    bpl .c
    rts

mlen:               ; A = length of the text at $7AD7
    ldx #0
.l:
    lda $7AD7,x
    beq .e
    inx
    bne .l
.e:
    txa
    rts

mline:              ; MLINE = the next line of the text from $7AD7 + $1B (words; a word
    jsr mclr        ;   longer than the line is cut)
    ldy #0
    ldx $1B
.sk:
    lda $7AD7,x
    cmp #$FF
    bne .w
    inx
    bne .sk
.w:
    lda $7AD7,x
    beq .x
    stx $1A
    lda #0
    sta $1C
.wl:
    lda $7AD7,x
    beq .we
    cmp #$FF
    beq .we
    inx
    inc $1C
    bne .wl
.we:
    tya
    clc
    adc $1C
    cmp #19
    bcc .put
    cpy #0
    bne .br
    lda #18
    sta $1C
.put:
    ldx $1A
.pc:
    lda $7AD7,x
    sta MLINE,y
    inx
    iny
    dec $1C
    bne .pc
    lda $7AD7,x
    beq .x
    cmp #$FF
    bne .x
    inx
    iny
    cpy #18
    bcc .w
    bcs .x
.br:
    ldx $1A
.x:
    stx $1B
    rts

FL: .db $F7, $FA, $FA, $FA, $FA, $FC
FM: .db $F8, $FF, $FF, $FF, $FF, $FD
FR: .db $F9, $FB, $FB, $FB, $FB, $FE
'''
MSGX_END = 0x6000


EXRAM = 128                             # ff3src / ff3en index of the ExRAM image


class Rom:
    def module(self, src, syms=None):
        """assemble a code module, as tools/gb3/ff3en.py records insert.py's: org, bytes,
        labels, insns (instruction starts)"""
        import ff3en
        m = asm(src, syms=syms)
        msrc, n = ff3en.marked(src)
        m2 = asm(msrc, syms=syms)
        assert m2.bytes == m.bytes
        insns = sorted(v for k, v in m2.labels.items() if re.search(r'\.__i\d+$', k))
        assert len(insns) == n
        labels = {k: v for k, v in m.labels.items() if syms is None or k not in syms}
        return dict(org=m.org, bytes=bytes(m.bytes), labels=labels, insns=insns)

    def __init__(self, data):
        self.d = bytearray(data); self.log = []; self.mods = []

    def off(self, bank, addr):
        return 16 + bank * B8 + (addr & 0x1FFF)

    def patch(self, bank, addr, old, new, why):
        """bytes at CPU addr in 8 KB bank: old (hex) -> new (hex)"""
        old = bytes.fromhex(old.replace(' ', '')); new = bytes.fromhex(new.replace(' ', ''))
        o = self.off(bank, addr)
        if self.d[o:o + len(old)] != old:
            raise SystemExit('layout: %02X:%04X is %s, expected %s (%s)' % (
                bank, addr, self.d[o:o + len(old)].hex(), old.hex(), why))
        self.d[o:o + len(new)] = new
        self.log.append((bank, addr, why))


TRAMP_SRC = '''
    org $5E7F
gbbon:              ; battle start: the GB's battle cameras
    lda #1
    bne gbcam
gbboff:             ; battle end: the field camera
    lda #0
gbcam:
    sta $5806       ; (GB runtime: camera set; open bus on the NES)
    jmp $FA1D       ; reset ppu control (the call this replaces)
'''


def battle(r):
    B2F, B34, B7F, B40 = 0x2F, 0x34, 0x7F, 0x40
    # cameras: two trampolines in the ExRAM image's free bytes ($5E7F-$5E8F; the English
    # engine's box save buffer starts at $5E90), called instead of "reset ppu control"
    # ($FA1D) at the start and the end of a battle ($FA26)
    t = r.module(TRAMP_SRC)
    assert t['org'] + len(t['bytes']) <= 0x5E90
    r.patch(B40, 0x827F, 'FF' * len(t['bytes']), t['bytes'].hex(), 'battle camera trampolines (ExRAM $5E7F)')
    r.mods.append(dict(t, where=(EXRAM, t['org'] - 0x5C00)))
    r.patch(B7F, 0xFA2F, '20 1D FA', '20 7F 5E', 'battle start: battle cameras')
    r.patch(B7F, 0xFA73, '20 1D FA', '20 83 5E', 'battle end: field camera')
    # party column: x by row (front, back) and members 24 px apart
    r.patch(B2F, 0xB516, 'D0 E0', 'A0 A4', 'party x: front 160 / back 164 (GB 140 / 144)')
    for a in (0xB51E, 0xB526):
        r.patch(B2F, a, '2C 48 64 80', '2F 47 5F 77', 'party y: 24 px apart from 47')
    # step forward / back: 8 px (front row), 12 (back row), 8 confused
    r.patch(B2F, 0xB3B8, '10', '08', 'step forward (front row) 8 px')
    r.patch(B2F, 0xB3B1, '20', '0C', 'step forward (back row) 12 px')
    r.patch(B2F, 0xB37C, '10', '08', 'step back (front row) 8 px')
    r.patch(B2F, 0xB375, '20', '0C', 'step back (back row) 12 px')
    r.patch(B2F, 0xB362, 'F0', 'F8', 'confused: step back 8 px')
    r.patch(B2F, 0xB39E, 'F0', 'F8', 'confused: step back 8 px')
    # the split between the battlefield and the windows: scanline 143 (was 151: windows
    # from row 19)
    for bank, a, why in ((0x2E, 0x9F1E, 'init battle'), (0x2F, 0xB8FC, 'battle intro end'),
                         (0x32, 0x80D5, 'summon animation'), (0x10, 0x8BC4, 'final boss death')):
        r.patch(bank, a, 'A9 97 85 03', 'A9 8F 85 03', 'battle split at scanline 143 (%s)' % why)
    # battle windows: from row 18, 4 rows of text (one tile row per line)
    r.patch(B34, 0x8B8F, '69 60 85 2A A9 00 69 22', '69 40 85 2A A9 00 69 22', 'windows from row 18 (nt 0)')
    r.patch(B34, 0x8BA0, '69 60 85 2A A9 00 69 26', '69 40 85 2A A9 00 69 26', 'windows from row 18 (nt 1)')
    r.patch(B34, 0x8BB0, 'A9 60', 'A9 40', 'windows from row 18 (overflow, nt 0)')
    r.patch(B34, 0x8BBB, 'A9 60', 'A9 40', 'windows from row 18 (overflow, nt 1)')
    r.patch(B34, 0x8BC3, 'A9 08', 'A9 04', 'windows: 4 rows')
    r.patch(B34, 0x966A, 'A5 18', 'A9 00', 'text lines in the first buffer row (bconv)')
    r.patch(B34, 0x969C, 'A5 18', 'A9 00', 'text lines in the first buffer row (bconvb)')
    r.patch(B34, 0x967E, '0A', 'EA', 'bconv newline: one buffer row (was two)')
    r.patch(B34, 0x9BB0, 'A9 77 8D 0A 72 A9 79 8D 0B 72', 'EA' * 10, 'no HP header (on line 1 now)')
    r.patch(B34, 0x9CD4, 'A9 0B 85 18 A9 1E', 'A9 02 85 18 A9 15', 'party window cols 2-21')
    for a in (0x9AD8, 0x9DD5):
        r.patch(B34, a, 'A9 01 85 18 A9 0A', 'A9 02 85 18 A9 0B', 'command / names window cols 2-11')


def battle_messages(r):
    B34 = 0x34
    x = r.module(MSGX_SRC)
    assert x['org'] + len(x['bytes']) <= MSGX_END, hex(x['org'] + len(x['bytes']))
    xo = r.off(0x40, x['org'] - 0x5C00 + 0x8000)
    assert set(r.d[xo:xo + len(x['bytes'])]) == {0xFF}
    r.d[xo:xo + len(x['bytes'])] = x['bytes']
    r.log.append((0x40, x['org'], 'message window helpers in ExRAM (%d bytes)' % len(x['bytes'])))
    r.mods.append(dict(x, where=(EXRAM, x['org'] - 0x5C00)))
    r.patch(0x40, 0x8290, 'FF', '00', 'MCNT = 0 at reset (ExRAM image)')
    syms = {k: v for k, v in x['labels'].items() if '.' not in k}
    syms['ARROW'] = ARROW
    m = r.module(MSG_SRC, syms)
    assert m['org'] == 0x8D1B and m['org'] + len(m['bytes']) <= MSG_END, hex(m['org'] + len(m['bytes']))
    m['bytes'] += b'\xEA' * (MSG_END - 0x8D1B - len(m['bytes']))       # (the old routines' rest)
    o = r.off(B34, 0x8D1B)
    if r.d[o:o + 5].hex() != '8518203ffd' or r.d[r.off(B34, 0x8E83):r.off(B34, 0x8E85)].hex() != '6122':
        raise SystemExit('layout: open message window / box table not found')
    r.d[o:r.off(B34, MSG_END)] = m['bytes']
    r.log.append((B34, 0x8D1B, 'message window routines'))
    r.mods.append(dict(m, where=(B34, 0x8D1B & 0x1FFF)))
    # the close call ($94DF LDA $4B / JSR $8E14) -> msgclose
    c = m['labels']['msgclose']
    r.patch(B34, 0x94E0, '4B 20 14 8E', '4B 20 %02X %02X' % (c & 0xFF, c >> 8), 'close message window')
    # box texts: never split (one row of 64 in the buffer; the window wraps them itself)
    for a in (0x9091, 0x90C1, 0x9168, 0x91BF, 0x91EF, 0x9253, 0x9313):
        o = r.off(B34, a)
        assert r.d[o] == 0xA9 and r.d[o + 2:o + 4] == bytes([0x85, 0x18]), hex(a)
        r.d[o + 1] = 0x40
    r.log.append((B34, 0x9091, 'box text widths 64'))
    # the arrow glyph
    lo = bytearray(8); hi = bytearray(8)
    for y, row in enumerate(ARROW_ROWS):
        for x in range(8):
            c = 3 if row[x] == '#' else 2
            if c & 1: lo[y] |= 0x80 >> x
            if c & 2: hi[y] |= 0x80 >> x
    o = 16 + FONT + ARROW * 16
    r.d[o:o + 16] = bytes(lo + hi)
    r.log.append((0, 0, 'arrow glyph $%02X' % ARROW))


def apply(data):
    """English NES ROM bytes -> (GB-layout ROM bytes, code modules for tools/gb3/ff3src.py)"""
    r = Rom(data)
    battle(r)
    battle_messages(r)
    return bytes(r.d), r.mods, r.log


def main():
    src, out = sys.argv[1], sys.argv[2]
    d, mods, log = apply(open(src, 'rb').read())
    open(out, 'wb').write(d)
    print('layout: %d patches, %d code modules -> %s' % (len(log), len(mods), out))


if __name__ == '__main__':
    main()
