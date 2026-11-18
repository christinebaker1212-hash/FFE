"""Game Boy layout for the FF1 English build (applied by `insert.py --gb`).

The GB shows NES nametable columns 6-25, rows 6-23 (20x18 tiles; camera in
tools/gb/rt/runtime.s). Each screen is re-laid out inside that view in FF1's own code,
following docs/gb-screens.md (SaGa 3 / GB RPG style, party sprites visible in battle).

Camera: the NES code selects the GB view per screen by writing tile coordinates to
$5800 (X) / $5801 (Y) (unmapped on the MMC5; the GB runtime moves its view). Default
(field, until a screen sets its own): X = 6, Y = 6.

Battle: camera (2, 6), so GB = NES - (2, 6):
  enemy area   GB cols 0-13, rows 0-11  (NES enemy box interior, unchanged)
  party column GB cols 14-19, rows 0-11 (sprite at cols 14-15, name/HP at 16-19)
  bottom window GB rows 12-17, full width (enemy names, commands over its right half,
  battle messages)
"""
import os, sys
HDR = 16
BANK = 0x4000


def fixed(rom, cpu):
    """file offsets of a fixed-bank address (copies in banks 15 and 31)"""
    return [HDR + b * BANK + cpu - 0xC000 for b in (15, 31)]


def put(rom, cpu, data, expect=None):
    for o in fixed(rom, cpu):
        if expect is not None and bytes(rom[o:o + len(expect)]) != expect:
            raise SystemExit('gb_layout: unexpected bytes at $%04X' % cpu)
        rom[o:o + len(data)] = data


def bank_off(bank, cpu):
    return HDR + bank * BANK + cpu - 0x8000


def battle_frames(rom):
    """$F2DC-$F30B draws the enemy box (1,1,16,18), the party box (17,1,8,18) and the four
    6x7 HP boxes; the GB layout has no frames there. The freed bytes hold the battle
    camera (X = 2: NES cols 2-21) and a wrapper for the two battle calls from the field
    (overworld $C1D6, dungeons $C935) that sets the field camera (X = 6) again after the
    battle, keeping A and the flags (the dungeon caller branches on carry)."""
    put(rom, 0xF2DC, bytes([0xA9, 0x02, 0x8D, 0x00, 0x58,      # LDA #2 / STA $5800
                            0x4C, 0x0C, 0xF3]),                 # JMP $F30C
        expect=bytes([0xA9, 0x01, 0x8D, 0x38, 0x00]))
    wrap = 0xF2E4
    put(rom, wrap, bytes([0x20, 0x00, 0xF2,                    # JSR $F200 (battle)
                          0x08, 0x48,                          # PHP / PHA
                          0xA9, 0x06, 0x8D, 0x00, 0x58,        # LDA #6 / STA $5800
                          0x68, 0x28, 0x60]))                  # PLA / PLP / RTS
    for site in (0xC1D6, 0xC935):
        put(rom, site, bytes([0x20, wrap & 0xFF, wrap >> 8]), expect=bytes([0x20, 0x00, 0xF2]))


# Battle line writer for the GB layout (replaces the English patch's boxline in the far
# code; insert.py assembles it when --gb is given). Input: the decoded line in $6CD4
# (pairs: dakuten, character; ends at 0), box image row at ($8A). Width W = cells up to
# the box frame. The line is word-wrapped greedily over up to 4 rows of the box (the
# dakuten row is not drawn: English text has none); a $FE marker forces a break. OVF = 1
# when a word does not fit or text is left after 4 rows (checked by the test harness).
BOXLINE = """boxline:
    ldy #0
.w:
    lda ($8A),y
    cmp #$F7
    bcc .wn
    cmp #$FF
    bcc .wend
.wn:
    iny
    cpy #32
    bne .w
.wend:
    sty SAVEX       ; W
    lda #0
    sta SAVEX2      ; row offset in the box image: 0, 32, 64, 96
    ldx #1          ; $6CD4 index of the next character
.row:
    stx PREV
    ldy #0          ; n = characters measured
    sty TMP         ; last space that fits (0 = none)
.m:
    lda $6CD4,x
    beq .fits
    cmp #$FE
    beq .fits
    cmp #$FF
    bne .mn
    sty TMP
.mn:
    cpy SAVEX       ; a character at position W: the row is too long
    beq .long
    inx
    inx
    iny
    bne .m
.fits:
    pha
    tya
    jsr .draw
    pla
    beq .done
    inx             ; skip the $FE marker
    inx
    jmp .next
.long:
    lda TMP
    beq .nosp
    jsr .draw
    inx             ; skip the space
    inx
    jmp .next
.nosp:
    lda #1
    sta OVF
    lda SAVEX
    jsr .draw
.next:
    lda SAVEX2
    clc
    adc #32
    sta SAVEX2
    cmp #128
    bcc .row
    lda $6CD4,x
    beq .done
    lda #1
    sta OVF
.done:
    rts
.draw:              ; A characters from index PREV to ($8A) + SAVEX2; X = index after them
    sta TMP
    ldx PREV
    ldy SAVEX2
    lda TMP
    beq .dr2
.dr:
    lda $6CD4,x
    sta ($8A),y
    inx
    inx
    iny
    dec TMP
    bne .dr
.dr2:
    rts
"""


def battle_panel(rom):
    """Bottom panel (25x12 image at $691E, NES rows 18-29; the GB shows panel rows 0-5,
    cols 2-21). Box records: type 0 = frame (x y w h), type 1 = text (x y, pointer).
    Windows are 6 rows high (panel rows 0-5 = GB rows 12-17), bottom frame included, with
    4 text rows (rows 1-4)."""
    # panel clear: no row of box bottoms for the (removed) enemy/party boxes
    put(rom, 0xF625, bytes([0x60]), expect=bytes([0xA9, 0xFD]))
    # enemy names: full-width window, names on rows 1-4 (single spacing)
    put(rom, 0xF9DC, bytes([0, 2, 0, 20, 6]), expect=bytes([0, 1, 0, 12, 10]))
    put(rom, 0xF6D2, bytes([0xEA] * 3), expect=bytes([0xCE, 0xA0, 0x6A]))      # no DEC $6AA0
    put(rom, 0xF6D7, bytes([0xEA] * 3), expect=bytes([0xEE, 0xA0, 0x6A]))      # one INC $6AA0
    # command window over the right half: Fight Run / Magic / Medicine / Items
    cmd = fixed(rom, 0xFA13)[0]
    ptr = [bytes(rom[cmd + 5 * k + 3:cmd + 5 * k + 5]) for k in range(1, 6)]   # Fight Magic Medicine Items Run
    rec = bytes([0, 11, 0, 11, 6])
    for k, (x, y) in enumerate(((12, 1), (12, 2), (12, 3), (12, 4), (18, 1))):
        rec += bytes([1, x, y]) + ptr[k]
    put(rom, 0xFA13, rec)
    # battle messages: attacker / action / target / result on rows 1 / 2 / 3 / 4(-5) of
    # one window; boxes 2-4 are drawn in panel rows 8-10, which the GB does not show
    # (a box must be at least 3 rows high: the frame drawer $F593 draws h-2 middle rows,
    # and h = 2 wraps to 255 rows and overwrites RAM)
    msg = bytes([0, 2, 0, 20, 6, 1, 3, 1,
                 0, 2, 8, 20, 3, 1, 3, 2,
                 0, 2, 8, 20, 3, 1, 3, 3,
                 0, 2, 8, 20, 3, 1, 3, 4,
                 0, 2, 0, 20, 6, 1, 3, 1])           # long single message (record 4)
    put(rom, 0xF9E1, msg)
    # item / medicine list window: into the visible rows
    put(rom, 0xFA0E, bytes([0, 2, 0, 20, 6]))


def put_bank(rom, bank, cpu, data, expect):
    o = bank_off(bank, cpu)
    if bytes(rom[o:o + len(expect)]) != expect:
        raise SystemExit('gb_layout: unexpected bytes at b%02d:%04X' % (bank, cpu))
    rom[o:o + len(data)] = data


def party_sprites(rom):
    """Party sprites at NES x = 128 (cols 16-17 = GB cols 14-15) instead of 176, so they
    stay visible beside the enemies; y stays 48/72/96/120 (GB rows 0-11). The acting
    member steps 8 px forward ($9951) and back ($997C); all other code reads $6AD3."""
    put_bank(rom, 12, 0x9740, bytes([0xA9, 0x80]), bytes([0xA9, 0xB0]))
    put_bank(rom, 12, 0x9951, bytes([0xA9, 0x78]), bytes([0xA9, 0xA8]))
    put_bank(rom, 12, 0x997C, bytes([0xA9, 0x80]), bytes([0xA9, 0xB0]))


def party_status(rom):
    """Name / HP-or-status label / HP number beside each sprite: NES cols 18-21 (GB 16-19),
    rows 6+3i, 7+3i, 8+3i (the sprite's three rows). The NES boxes (cols 26-29, rows 4+6i)
    had a dakuten row above the name and above the label; those rows are blank in English
    and are not drawn. Routine b12:AA5B (one member per frame), row writer $AAFC, row
    addresses $AB21."""
    nop5 = bytes([0xEA] * 5)
    put_bank(rom, 12, 0xAAB0, nop5, bytes([0xA0, 0x00, 0x20, 0xFC, 0xAA]))   # dakuten row of the name
    put_bank(rom, 12, 0xAABA, nop5, bytes([0xA0, 0x08, 0x20, 0xFC, 0xAA]))   # dakuten row of the label
    rows = b''.join((0x2000 + (6 + 3 * i) * 32 + 18).to_bytes(2, 'little') for i in range(4))
    # palette 3 (the HP boxes' palette) for cols 18-21, rows 6-17 in the battle
    # attribute table $F3F8 (copied to $23C0 at battle setup and kept as the base)
    for i, (old, new) in {0x0C: (0x33, 0xF3), 0x14: (0x33, 0xFF), 0x1C: (0x33, 0xFF), 0x24: (0xF3, 0xFF),
                          0x0D: (0x00, 0x30), 0x15: (0x00, 0x33), 0x1D: (0x00, 0x33), 0x25: (0xF0, 0xF3)}.items():
        put(rom, 0xF3F8 + i, bytes([new]), expect=bytes([old]))
    put_bank(rom, 12, 0xAB21, rows, bytes([0x9A, 0x20, 0x5A, 0x21, 0x1A, 0x22, 0xDA, 0x22]))


def apply(rom, report):
    battle_frames(rom)
    battle_panel(rom)
    party_sprites(rom)
    party_status(rom)
    report.append('GB layout applied')
