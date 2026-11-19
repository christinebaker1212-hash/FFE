"""FF2 GB layout: NES-side re-layout of the English FF2 build for the Game Boy's 160x144.

Applied after tools/ff2/insert.py: build/ff2_en.nes -> build/ff2_gb.nes (still an NES ROM:
it runs in cynes, and the GB build of it is checked against it frame by frame). The GB
runtime reads the camera registers written here ($5800-$5805, nothing on the NES; see
tools/gb2/rt/ff2.s). Owner's layouts: docs/ff2-gb-screens.md.

usage: layout.py build/ff2_en.nes build/ff2_gb.nes

Free space used: fixed bank $F800-$F84F (unused code, rom-map.txt) and $FFD0-$FFF9 (the
rom-info block), bank 23 (empty). RAM in battle: $7800-$78DF (the box save stack the
English patch moved to ExRAM), $75C0-$75FF, $7FDF-$7FFF (never written by the game), zero
page $D2-$D7 (unused per ram-map.txt) for the renderer's pointers."""
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
CAM_BATTLE = dict(x=2, fine=4, y=6, line=96, x2=0, y2=6)

FIX_SRC = '''
    org $F800
gbf:                    ; X = GB routine index, A = bank to return to (bank 23 code)
    stx GBIDX
    sta GBRB
    lda #23
    jsr $FA7F           ; (switch with $3E set: the battle NMI's return (long) restores it)
    jsr $8000           ; bank 23 dispatcher
    lda GBRB
    jmp $FA7F
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
    lda #0
    sta GBPOOL          ; tile pool: made again for this battle
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


# Battle RAM (free in battle, see the module docstring)
RAM = dict(GBIDX=0x7FDF, GBRB=0x7FE0, GBPOOL=0x7FE1, VX=0x7FE2, VN=0x7FE3, VT=0x7FE4, VC=0x7FE5,
           VSH=0x7FE6, VCNT=0x7FE7, VP=0xD2, VQ=0xD4, VS=0xD6, VNUM=0x7FEC, VPAD=0x7FEE, VDIG=0x7FEF,
           VROW=0x7FF0, VCOL=0x7FF1, VW=0x7FF2, VH=0x7FF3, VLINE=0x7FF4, VSV=0x7FF5, VI=0x7FF6,
           USED=0x75C0, VBUF=0x7800, PTILE=0x7860, LTILE=0x7888, FTILE=0x78A0, NTBUF=0x78AC)
# fixed-bank entries (7 bytes each, at $FFD0): index, bank to return to, the NES routine replaced
ENTRIES = [('gb_party', 0x0C, 0x912A)]

ENT_SRC = '''
    org $FFD0
'''

B23_SRC = '''
    org $8000
gbdisp:                 ; dispatch GBIDX (word table: entries of the code map)
    lda GBIDX
    asl a
    tax
    lda gbtab,x
    sta $00
    lda gbtab+1,x
    sta $01
    jmp ($0000)
gbtab:
    .dw gb_party

; ---- tile pool: table-1 tiles this battle's battlefield does not use
poolinit:
    lda GBPOOL
    beq .go
    rts
.go:
    ldx #31
    lda #0
.c:
    sta USED,x
    dex
    bpl .c
    lda #$FF            ; $00-$1F: backdrop and fixed battle tiles
    sta USED
    sta USED+1
    sta USED+2
    sta USED+3
    ldy #7
.slot:
    lda $7B62,y         ; monster in this slot?
    bmi .ns
    lda $7B72,y         ; graphics id
    cmp #9
    bcs .boss
    tax
    lda FIRST,x
    sta VT
    lda $7B8A,y         ; width * height tiles from the first
    sta VCNT
    lda #0
    ldx $7B82,y
.mul:
    clc
    adc VCNT
    dex
    bne .mul
    tax
.mk:
    lda VT
    jsr usemark
    inc VT
    dex
    bne .mk
.ns:
    dey
    bpl .slot
    jmp .alloc
.boss:                  ; boss: a precomputed bitmap of its tilemap
    sec
    sbc #9
    asl a
    asl a
    asl a
    asl a
    asl a
    tax
    ldy #0
.bl:
    lda BOSSUSED,x
    ora USED,y
    sta USED,y
    inx
    iny
    cpy #32
    bne .bl
.alloc:                 ; pool: free tiles from $FF down: blank, party 40, left 24, frame 8
    ldx #0
    lda #$FF
    sta VT
.al:
    lda VT
    jsr usetest
    bne .an
    lda VT
    sta PTILE-1,x       ; (the first, highest free tile: the blank, at PTILE-1)
    inx
    cpx #73
    beq .done
.an:
    dec VT
    lda VT
    cmp #$1F
    bne .al
.done:
    lda #1
    sta GBPOOL
    jsr frames          ; frame tiles into the pool
    jmp blank           ; blank tile (PTILE-1) over the window rows 18-23

usemark:                ; A = tile: mark used (X, Y kept)
    pha
    sty VSH
    pha
    lsr a
    lsr a
    lsr a
    tay
    pla
    and #7
    sta VC
    lda #$80
.s:
    dec VC
    bmi .o
    lsr a
    jmp .s
.o:
    ora USED,y
    sta USED,y
    ldy VSH
    pla
    rts
usetest:                ; A = tile: Z clear if used (X kept)
    sty VSH
    pha
    lsr a
    lsr a
    lsr a
    tay
    pla
    and #7
    sta VC
    lda #$80
.s:
    dec VC
    bmi .o
    lsr a
    jmp .s
.o:
    and USED,y
    ldy VSH
    and #$FF
    rts

; ---- CHR upload (in vblank, after the game's frame wait): VN tiles of VBUF (1 bit per
; pixel) as ink colour 3 on window colour 2 into pattern table 1 at the tiles listed at
; (VP), at most 6 per frame; then the battle scroll as fix:FD46 leaves it
vupload:
    lda #0
    sta VC
.frame:
    jsr $FA2A           ; wait for vblank
    lda #6
    sta VCNT
.tile:
    lda VC
    cmp VN
    bcs .end
    tay
    lda (VP),y
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    ora #$10
    sta $2006
    pla
    asl a
    asl a
    asl a
    asl a
    sta $2006
    lda VC
    asl a
    asl a
    asl a
    tax
    ldy #8
.p0:
    lda VBUF,x
    sta $2007
    inx
    dey
    bne .p0
    lda #$FF
    ldy #8
.p1:
    sta $2007
    dey
    bne .p1
    inc VC
    dec VCNT
    bne .tile
    jsr scroll
    jmp .frame
.end:
    jmp scroll
scroll:
    lda $3B
    sta $2000
    lda $39
    sta $2005
    lda $37
    sta $2005
    rts

frames:                 ; the 8 frame tiles (ROM font $F7-$FE, copied at build time) to FTILE
    lda #<FRAMEGFX
    sta VQ
    lda #>FRAMEGFX
    sta VQ+1
    lda #0
    sta VC
.f:
    jsr $FA2A
    ldy VC
    lda FTILE,y
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    ora #$10
    sta $2006
    pla
    asl a
    asl a
    asl a
    asl a
    sta $2006
    ldy #0
.b:
    lda (VQ),y
    sta $2007
    iny
    cpy #16
    bne .b
    clc
    lda VQ
    adc #16
    sta VQ
    lda VQ+1
    adc #0
    sta VQ+1
    jsr scroll
    inc VC
    lda VC
    cmp #8
    bne .f
    rts

blank:                  ; tile PTILE-1 = window colour 2; NES rows 18-23 cols 0-31 filled with it
    jsr $FA2A
    lda PTILE-1
    jsr tileaddr
    lda #0
    ldx #8
.p0:
    sta $2007
    dex
    bne .p0
    lda #$FF
    ldx #8
.p1:
    sta $2007
    dex
    bne .p1
    jsr scroll
    lda #18
    sta VLINE
.r:
    jsr $FA2A
    lda #$22            ; row 18 = $2240, row k = $2000 + 32k
    sta VSH
    lda VLINE
    asl a
    asl a
    asl a
    asl a
    asl a
    sta VT
    lda VLINE
    lsr a
    lsr a
    lsr a
    ora #$20
    sta $2006
    lda VT
    sta $2006
    lda PTILE-1
    ldx #32
.f:
    sta $2007
    dex
    bne .f
    jsr scroll
    inc VLINE
    lda VLINE
    cmp #24
    bne .r
    rts
tileaddr:               ; A = table-1 tile: PPU address of its pattern
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    ora #$10
    sta $2006
    pla
    asl a
    asl a
    asl a
    asl a
    sta $2006
    rts

; ---- small-font renderer: VBUF holds VN tiles of one text line (tile-major, 8 rows)
vclear:
    lda VN
    asl a
    asl a
    asl a
    tax
    lda #0
    sta VX
.c:
    dex
    sta VBUF,x
    bne .c
    rts
vchar:                  ; A = code: draw its glyph at VX (columns, bit 7 = top row)
    tax
    lda GW,x            ; width (0: no glyph)
    beq .sp
    sta VCNT
    lda GOFF,x
    sta VQ
    lda GHI,x
    sta VQ+1
    ldy #0
.col:
    lda VX
    lsr a
    lsr a
    lsr a
    cmp VN
    bcs .full
    asl a
    asl a
    asl a
    sta VT              ; VBUF offset of the tile
    lda VX
    and #7
    tax
    lda BIT,x
    sta VC              ; pixel bit
    lda (VQ),y
    sta VSH
    ldx VT
.row:
    asl VSH
    bcc .n
    lda VBUF,x
    ora VC
    sta VBUF,x
.n:
    inx
    txa
    and #7
    bne .row
    inc VX
    iny
    dec VCNT
    bne .col
    inc VX              ; 1-px gap
.full:
    rts
.sp:
    lda VX
    clc
    adc #2
    sta VX
    rts
vstr:                   ; draw the 0-terminated codes at (VQ+... in VP) -> VX
    ldy #0
.l:
    lda (VP),y
    beq .e
    sty VDIG
    jsr vchar
    ldy VDIG
    iny
    bne .l
.e:
    rts
vwidth:                 ; A = code -> A = its advance (pixels)
    tax
    lda GW,x
    beq .sp
    clc
    adc #1
    rts
.sp:
    lda #2
    rts
vnum:                   ; VNUM (16 bits) in small digits, right edge at A (pixels)
    sta VPAD
    ldx #0
.d:                     ; digits into NTBUF (most significant first), at least one
    lda #0
    sta VDIG
.sub:
    lda VNUM
    sec
    sbc POW,x
    tay
    lda VNUM+1
    sbc POWH,x
    bcc .nd
    sta VNUM+1
    sty VNUM
    inc VDIG
    jmp .sub
.nd:
    lda VDIG
    sta NTBUF,x
    inx
    cpx #4
    bne .d
    ldx #0              ; skip leading zeros (keep the last)
.z:
    lda NTBUF,x
    bne .w
    inx
    cpx #3
    bne .z
.w:
    stx VI
    lda VPAD            ; VX = right edge - 4 * digits
    ldy VI
.wx:
    cpy #4
    beq .wd
    sec
    sbc #4
    iny
    bne .wx
.wd:
    sta VX
.dr:
    ldx VI
    cpx #4
    beq .ok
    lda NTBUF,x
    clc
    adc #$10            ; small digits: codes $10-$19
    jsr vchar
    inc VI
    jmp .dr
.ok:
    rts

; ---- window frame + text tiles into the nametable. VROW/VCOL = NES row/column of the top
; left corner, VW/VH = size, (VP) = the text tiles, row-major, (VW-2) per text row
ntwin:
    lda #0
    sta VLINE
.row:
    jsr $FA2A
    lda VROW            ; PPU address of the row
    clc
    adc VLINE
    sta VSH
    lda #0
    sta VT
    ldx #5
.sh:
    asl VSH
    rol VT
    dex
    bne .sh
    lda VT
    ora #$20
    sta $2006
    lda VSH
    ora VCOL
    sta $2006
    lda VLINE
    beq .top
    clc
    adc #1
    cmp VH
    beq .bot
    lda FTILE+3         ; left side, text, right side
    sta $2007
    ldx VW
    dex
    dex
.t:
    ldy #0
    lda (VP),y
    sta $2007
    inc VP
    bne .t1
    inc VP+1
.t1:
    dex
    bne .t
    lda FTILE+4
    jmp .end
.top:
    lda FTILE+0
    sta $2007
    ldx VW
    dex
    dex
    lda FTILE+1
.tt:
    sta $2007
    dex
    bne .tt
    lda FTILE+2
    jmp .end
.bot:
    lda FTILE+5
    sta $2007
    ldx VW
    dex
    dex
    lda FTILE+6
.bb:
    sta $2007
    dex
    bne .bb
    lda FTILE+7
.end:
    sta $2007
    jsr scroll
    inc VLINE
    lda VLINE
    cmp VH
    beq .x
    jmp .row
.x:
    rts

; ---- party window (replaces b12:912A): GB cols 8-19, rows 12-17 = NES rows 18-23; one
; line per member: name (condensed letters), HP current/max and MP in 3-px digits
gb_party:
    jsr poolinit
    lda #0
    sta VLINE
.mem:
    lda #10
    sta VN
    jsr vclear
    lda VLINE           ; members 0-3: properties $6100 + 64 * i, battle stats $7D7A + 48 * i
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #2
    sta VP
    lda #$61
    sta VP+1
    lda VLINE
    cmp #3
    bne .shown
    lda $6235           ; slot 4: hidden when bit 7 is set (as b12:9510)
    bpl .shown
    jmp .up
.shown:
    lda #1
    sta VX
    ldy #0
.nm:
    lda (VP),y
    cmp #$FF
    beq .nd
    sty VDIG
    jsr vchar
    ldy VDIG
    iny
    cpy #6
    bne .nm
.nd:
    ldx VLINE           ; battle stats: +$0A current HP, +$0C current MP, +$0E max HP
    lda STATOFS,x
    sta VS
    lda #$7D
    clc
    adc STATHI,x
    sta VS+1
    ldy #$0A            ; current HP
    lda (VS),y
    sta VNUM
    iny
    lda (VS),y
    sta VNUM+1
    lda #48
    jsr vnum
    lda #$1A            ; small '/'
    jsr vchar
    ldy #$0E            ; max HP
    lda (VS),y
    sta VNUM
    iny
    lda (VS),y
    sta VNUM+1
    lda #66
    jsr vnum
    ldy #$0C            ; current MP
    lda (VS),y
    sta VNUM
    iny
    lda (VS),y
    sta VNUM+1
    lda #80
    jsr vnum
.up:
    lda VLINE           ; upload this line's 10 tiles
    asl a
    sta VSH
    asl a
    asl a
    clc
    adc VSH             ; * 10
    clc
    adc #<PTILE
    sta VP
    lda #>PTILE
    adc #0
    sta VP+1
    jsr vupload
    inc VLINE
    lda VLINE
    cmp #4
    beq .win
    jmp .mem
.win:
    lda #18
    sta VROW
    lda #8
    sta VCOL
    lda #12
    sta VW
    lda #6
    sta VH
    lda #<PTILE
    sta VP
    lda #>PTILE
    sta VP+1
    jmp ntwin

BIT:    .db $80, $40, $20, $10, $08, $04, $02, $01
POW:    .db <1000, <100, <10, <1
POWH:   .db >1000, >100, >10, >1
STATOFS: .db $7A, $AA, $DA, $0A
STATHI:  .db 0, 0, 0, 1
'''


def glyph_tables():
    """glyph data for the small-font renderer (bank 23): code -> width, columns (bit 7 =
    top row); letters condensed (tools/latin_font.py COND, else G), 3-px digits at codes
    $10-$19, small '/' at $1A (FF1's battle digits)"""
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ff2'))
    from latin_font import _glyph_cols, COND, G
    import importlib.util
    spec = importlib.util.spec_from_file_location('ff2insert', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ff2', 'insert.py'))
    ins = importlib.util.module_from_spec(spec); spec.loader.exec_module(ins)
    DIG3 = {'0': ["###", "#.#", "#.#", "#.#", "#.#", "#.#", "###"], '1': [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
            '2': ["###", "..#", "..#", "###", "#..", "#..", "###"], '3': ["###", "..#", "..#", ".##", "..#", "..#", "###"],
            '4': ["#.#", "#.#", "#.#", "###", "..#", "..#", "..#"], '5': ["###", "#..", "#..", "###", "..#", "..#", "###"],
            '6': ["###", "#..", "#..", "###", "#.#", "#.#", "###"], '7': ["###", "..#", "..#", ".#.", ".#.", ".#.", ".#."],
            '8': ["###", "#.#", "#.#", "###", "#.#", "#.#", "###"], '9': ["###", "#.#", "#.#", "###", "..#", "..#", "###"],
            '/': ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."]}
    glyph = {}
    for ch, code in ins.ENC.items():
        if ch == ' ': continue
        cols = _glyph_cols(ch, COND if ch in COND else G)
        glyph[code] = [sum(b << (7 - r) for r, b in enumerate(c)) for c in cols]
    for i, ch in enumerate('0123456789/'):
        art = DIG3[ch]
        glyph[0x10 + i] = [sum((1 << (7 - (r + 1))) for r in range(7) if art[r][c] == '#') for c in range(3)]
    return glyph


def bank23(rom, L):
    """bank 23 source + data from the user's ROM (first monster tiles, boss tilemaps, frame
    tiles) and the glyph tables"""
    b11 = rom[HDR + 11 * BANK:HDR + 12 * BANK]
    first = b11[0x9FA5 - 0x8000:0x9FA5 - 0x8000 + 9]
    boss = []
    for k in range(6):                                  # boss tilemaps (b11:8DDE, 144 each)
        used = bytearray(32)
        for t in b11[0x8DDE - 0x8000 + 144 * k:0x8DDE - 0x8000 + 144 * (k + 1)]: used[t >> 3] |= 0x80 >> (t & 7)
        boss.append(bytes(used))
    b9 = rom[HDR + 9 * BANK:HDR + 10 * BANK]
    frame = b''.join(b9[0x0320 + 16 * t:0x0320 + 16 * t + 16] for t in range(0xF7, 0xFF))
    g = glyph_tables()
    gw = bytes(len(g.get(c, [])) for c in range(256))
    data, offs = bytearray(), []
    for c in range(256):
        offs.append(len(data)); data += bytes(g.get(c, []))
    src = B23_SRC + '\nFIRST: .db ' + ', '.join('$%02X' % v for v in first)
    src += '\nBOSSUSED:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in b) for b in boss)
    src += 'FRAMEGFX:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in frame[i:i + 16]) for i in range(0, 128, 16))
    src += 'GW:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in gw[i:i + 16]) for i in range(0, 256, 16))
    src += 'GLYPHS:\n' + ''.join('    .db %s\n' % ', '.join('$%02X' % v for v in data[i:i + 16]) for i in range(0, len(data), 16))
    src += 'GOFF:\n' + ''.join('    .db %s\n' % ', '.join('<(GLYPHS+%d)' % o for o in offs[i:i + 16]) for i in range(0, 256, 16))
    src += 'GHI:\n' + ''.join('    .db %s\n' % ', '.join('>(GLYPHS+%d)' % o for o in offs[i:i + 16]) for i in range(0, 256, 16))
    return asm(src, syms=dict(RAM, **L))


def battle(rom):
    c = CAM_BATTLE
    f = asm(FIX_SRC, syms=dict(RAM, CX=c['x'], CF=c['fine'], CY=c['y'], CX2=c['x2'], CY2=c['y2'], CL=c['line']))
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
    # one BG pattern table: the menu area keeps table 1 (no switch at the split, fix:FD60
    # AND #$EF -> AND #$FF), the menu does not scroll (b12:9AC6 scroll menu -> RTS)
    put(rom, 31, 0xFD63, bytes([0xFF]), old=bytes([0xEF]))
    put(rom, 12, 0x9AC6, bytes([0x60]), old=bytes([0x20]))
    put(rom, 12, 0x904A, bytes([0x00]), old=bytes([0x01]))   # menu area: nametable 0 (not 1)
    # the NES windows no longer reach the nametable (b12:930C copy window tilemap -> RTS);
    # the GB windows are drawn by bank 23
    put(rom, 12, 0x930C, bytes([0x60]), old=bytes([0x18]))
    # b12:9B3E (clear the old menu area with $FF, 10 rows): only its $7CCA = 0 is kept
    put(rom, 12, 0x9B3E, bytes.fromhex('a9008dca7c60'), old=bytes.fromhex('2046fda98885'))
    # bank 5 message boxes: their nametable writes off (STA $2007 -> BIT $07FF; the save /
    # restore reads stay); the GB message window replaces them
    for a in (0xAB0D, 0xAB14, 0xAB1C, 0xAB2A, 0xAB34, 0xAB3D, 0xAB91):
        put(rom, 5, a, bytes([0x2C, 0xFF, 0x07]), old=bytes([0x8D, 0x07, 0x20]))
    # bank 23 + entries
    rom[HDR + 23 * BANK:HDR + 24 * BANK] = b'\xFF' * BANK
    b23 = bank23(rom, dict(gbf=f.labels['gbf']))
    assert len(b23.bytes) <= BANK
    put(rom, 23, 0x8000, b23.bytes)
    ent = 'org $FFD0\n'
    for k, (name, rb, nes) in enumerate(ENTRIES):
        ent += 'e%d:\n    ldx #%d\n    lda #$%02X\n    jmp gbf\n' % (k, k, rb)
    e = asm(ent, syms=dict(gbf=f.labels['gbf']))
    assert e.org + len(e.bytes) <= 0xFFFA
    put(rom, 31, e.org, e.bytes)
    for k, (name, rb, nes) in enumerate(ENTRIES):
        put(rom, rb, nes, bytes([0x4C]) + e.labels['e%d' % k].to_bytes(2, 'little'))


def apply(rom):
    battle(rom)


if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    apply(rom)
    open(sys.argv[2], 'wb').write(rom)
    print('wrote', sys.argv[2])
