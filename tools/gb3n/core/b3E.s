; FF3 bank $3E translated routine by routine (docs/ff3-gb-rewrite.md); GB bank GB_3E. NES addresses in
; the comments; GB: $7C00 / $7D00 / $7E00 -> $DC00 / $DD00 / $DE00, $7200 -> $C200, $0600 -> $CA00,
; the map $7400-$77FF -> $D400, the row / column buffers $0780-$07FF -> NR2 + $0780 ($CB80).

section bank GB_3E, $4000
; ---- 3E/CEB4 load tiles for scrolling (normal map): the 16 metatiles of map row $2C from column $2B
; (moving vertically) or of column $2B from row $2C (horizontally) into the buffers: $0780 / $0790 /
; $07A0 / $07B0 = their four tiles ($7C00 / $7D00 / $7E00 / $7200), $07C0 their palettes ($0600);
; outside the 32 x 32 map the fill tile $4C. $2B / $2C move on by 16, $80-$82 as FF3 leaves them.
f3E_CEB4:   ld e, 0
            ld a, [BZ + $2C]
            and $1F
            srl a
            srl a
            srl a
            or $74
            ld [BZ + $81], a
            ld a, [BZ + $2C]
            swap a
            add a
            and $E0
            ld [BZ + $82], a
            ld a, [BZ + $2B]
            and $1F
            ld hl, BZ + $82
            or [hl]
            ld [BZ + $80], a
            ld a, [BZ + $2D]
            and 2
            jr nz, .h
.v:         call .tile                      ; vertical: 16 along the row
            ld a, [BZ + $80]
            inc a
            and $1F
            ld hl, BZ + $82
            or [hl]
            ld [BZ + $80], a
            ld hl, BZ + $2B
            inc [hl]
            inc e
            ld a, e
            cp $10
            jr c, .v
            ld a, [BZ + $80]
            scf                             ; (CPX #$10 with X = $10)
            ret
.h:         call .tile                      ; horizontal: 16 down the column
            ld a, [BZ + $80]
            add $20
            ld [BZ + $80], a
            ld a, [BZ + $81]
            adc 0
            and 3
            or $74
            ld [BZ + $81], a
            inc e
            ld hl, BZ + $2C
            inc [hl]
            ld a, e
            cp $10
            jr c, .h
            ld a, [BZ + $81]
            scf
            ret
; Y = the metatile at ($80), or the fill tile outside the map; its tiles / palette to the buffers at X
.tile:      ld a, [BZ + $2B]
            ld hl, BZ + $2C
            or [hl]
            and $20
            jr z, .in
            ld a, [BZ + $4C]
            ld c, a
            jr .cp
.in:        ld a, [BZ + $80]
            ld l, a
            ld a, [BZ + $81]
            add $D4 - $74
            ld h, a
            ld c, [hl]
.cp:        ld b, 0
            ld d, e                         ; (DE = NR2 + $0780 + X below)
            ld l, c
            ld h, $DC
            ld a, [hl]
            ld hl, NR2 + $0780
            call .put
            ld l, c
            ld h, $DD
            ld a, [hl]
            ld hl, NR2 + $0790
            call .put
            ld l, c
            ld h, $DE
            ld a, [hl]
            ld hl, NR2 + $07A0
            call .put
            ld l, c
            ld h, $C2
            ld a, [hl]
            ld hl, NR2 + $07B0
            call .put
            ld l, c
            ld h, $CA
            ld a, [hl]
            ld hl, NR2 + $07C0
.put:       push af
            ld a, l
            add e
            ld l, a
            pop af
            ld [hl], a
            ret

; ---- 3E/CDA3 init player movement (normal map): by the facing direction ($33: r l d u), the
; column / row about to come into view goes into the buffers (CEB4) at nametable position $30 / $31,
; $68 / $69 = the party's next tile; $32 = 1 (background to update), $34 = 1 (speed)
f3E_CDA3:   ld a, [BZ + $33]
            srl a
            jr c, .r
            srl a
            jr c, .l
            srl a
            jr c, .d
            srl a
            jr c, .u
            ret
.r:         ld a, [BZ + $29]
            add 8
            and $3F
            ld [BZ + $68], a
            add 8
            and $3F
.rl:        ld [BZ + $2B], a
            and $1F
            ld [BZ + $31], a
            ld a, [BZ + $2F]
            ld [BZ + $30], a
            ld a, [BZ + $2A]
            ld [BZ + $2C], a
            ld a, [BZ + $2D]
            or 2
            ld [BZ + $2D], a
            call f3E_CEB4
.go:        ld a, 1
            ld [BZ + $32], a
            ld [BZ + $34], a
            ret
.l:         ld a, [BZ + $29]
            add 6
            and $3F
            ld [BZ + $68], a
            sub 7
            and $3F
            jr .rl
.d:         ld a, [BZ + $2A]
            add 8
            and $3F
            ld [BZ + $69], a
            add 7
            and $3F
            ld [BZ + $2C], a
            ld a, [BZ + $2F]                ; ($2F + 15) mod 15 = $2F
            jr .du
.u:         ld a, [BZ + $2A]
            add 6
            and $3F
            ld [BZ + $69], a
            sub 7
            and $3F
            ld [BZ + $2C], a
            ld a, [BZ + $2F]
            sub 1
            jr nc, .du
            add $0F
.du:        ld [BZ + $30], a
            ld a, [BZ + $29]
            ld [BZ + $2B], a
            and $1F
            ld [BZ + $31], a
            ld a, [BZ + $2D]
            and $FD
            ld [BZ + $2D], a
            call f3E_CEB4
            jr .go

; ---- 3E/CA79 update map background: the buffered row / column to the nametables (3B/BE00), its
; attribute bytes (CB61); $32 = 0
f3E_CA79:   ld a, $3B
            call f3F_FF1F                   ; (switch prg bank 1: FF3's $A000 window to $3B)
            %X f3B_BE00
            call f3E_CB61
            ld a, 0
            ld [BZ + $32], a
            ret

; ---- 3E/CA89 (one row up before a redraw): normal map $2A - 1 (mod 64), world map $28 - 1; $2F - 1
; (mod 15)
f3E_CA89:   ld a, [BZ + $2D]
            srl a
            jr nc, .w
            ld a, [BZ + $2A]
            sub 1
            and $3F
            ld [BZ + $2A], a
            jr .f
.w:         ld a, [BZ + $28]
            sub 1
            ld [BZ + $28], a
.f:         ld a, [BZ + $2F]
            sub 1
            jr nc, .s
            add $0F
.s:         ld [BZ + $2F], a
            ret

; ---- 3E/CAAD the attribute bytes of a whole row (32 tiles: $86 = 16); 3E/CAB1 $86 of them (moving
; vertically) or 15 down a column: for each attribute quadrant from ($30, $31) its nametable address
; ($07D0 high, $07E0 low), its mask ($07F0); then the new palettes ($07C0) merged into FF3's attribute
; shadow $0300-$037F under the masks, the merged bytes to $07F0
f3E_CAAD:   ld a, $10
            ld [BZ + $86], a
f3E_CAB1:   ld a, [BZ + $31]
            push af
            ld a, [BZ + $30]
            push af
            ld c, 0
.l:         ld a, [BZ + $30]
            ld e, $0F
            srl a
            jr nc, .e
            ld e, $F0
.e:         add a                           ; (ASL x 3 of ($30 >> 1))
            add a
            add a
            ld [BZ + $80], a
            ld a, e
            ld [BZ + $81], a
            ld a, [BZ + $31]
            ld e, $23
            cp $10
            jr c, .n0
            and $0F
            ld e, $27
.n0:        push af
            ld a, e
            ld [BZ + $82], a
            pop af
            ld e, $33
            srl a
            jr nc, .c0
            ld e, $CC
.c0:        ld hl, BZ + $80
            or [hl]
            ld [hl+], a
            ld a, e
            and [hl]
            ld [hl], a
            ld b, 0
            ld hl, NR2 + $07D0
            add hl, bc
            ld a, [BZ + $82]
            ld [hl], a
            ld a, l
            add $10
            ld l, a
            ld a, [BZ + $80]
            or $C0
            ld [hl], a
            ld a, l
            add $10
            ld l, a
            ld a, [BZ + $81]
            ld [hl], a
            ld a, [BZ + $2D]
            and 2
            jr nz, .hz
            ld a, [BZ + $31]
            inc a
            and $1F
            ld [BZ + $31], a
            inc c
            ld a, [BZ + $86]
            ld b, a
            ld a, c
            cp b
            jr c, .l
            jr .m
.hz:        ld a, [BZ + $30]
            inc a
            cp $0F
            jr c, .h1
            sub $0F
.h1:        ld [BZ + $30], a
            inc c
            ld a, c
            cp $0F
            jr c, .l
.m:         pop af
            ld [BZ + $30], a
            pop af
            ld [BZ + $31], a
            ld a, [BZ + $86]
            dec a
            ld e, a
            ld a, [BZ + $2D]
            and 2
            jr z, .mv
            dec e
.mv:        ld a, e                         ; Y = ($07E0 & $3F) | ($07D0 & 4 ? $40 : 0)
            add low(NR2 + $07D0)
            ld l, a
            ld h, high(NR2 + $07D0)
            ld b, [hl]
            ld a, l
            add $10
            ld l, a
            ld a, [hl]
            and $3F
            bit 2, b
            jr z, .y
            or $40
.y:         ld c, a
            ld a, e
            add low(NR2 + $07C0)
            ld l, a
            ld d, [hl]                      ; the new palettes ($07C0 + X)
            ld a, l
            add $30
            ld l, a
            ld b, [hl]                      ; the mask ($07F0 + X)
            push hl
            ld h, high(NR2 + $0300)
            ld l, c
            ld a, [hl]                      ; ((shadow ^ new) & mask) ^ shadow
            xor d
            and b
            xor [hl]
            ld [hl], a
            pop hl
            ld [hl], a                      ; -> $07F0 + X too
            dec e
            bit 7, e
            jr z, .mv
            scf                             ; (the carry from the first part's CPY)
            ret

; ---- 3E/CB61 update dialogue window attributes (native): the 16 (vertical) / 15 (horizontal)
; attribute bytes FF3 merged into its shadow (CAB1: addresses $07D0 / $07E0, bytes $07F0) give the CGB
; attributes of their 4 x 4 cells (from the shadow, as gbv_attr reads it); X ends $FF as FF3's loop
f3E_CB61:   ld a, [BZ + $2D]
            ld e, $0F
            and 2
            jr z, .l
            ld e, $0E
.l:         push de
            ld a, e
            add low(NR2 + $07E0)
            ld l, a
            ld h, high(NR2 + $07E0)
            ld a, [hl]                      ; $C0 + 8 row / 4 + column / 4 (FF3's attribute address)
            and $3F
            ld c, a
            ld a, l
            sub $10
            ld l, a
            ld a, [hl]                      ; $23 / $27: the nametable
            and 4
            add a
            add a
            add a                           ; (4 -> 32: the second nametable's columns)
            ld b, a
            ld a, c
            and 7
            add a
            add a
            add b
            ld e, a                         ; E = first column (0-63)
            ld a, c
            and $38
            srl a
            ld d, a                         ; D = first row
            ld b, 4
.r:         push de
            ld c, 4
.c:         ld a, d
            cp 30
            jr nc, .sk
            call gbv_attr
.sk:        inc e
            dec c
            jr nz, .c
            pop de
            inc d
            dec b
            jr nz, .r
            pop de
            dec e
            bit 7, e
            jr z, .l
            ret
