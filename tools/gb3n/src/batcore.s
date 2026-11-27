; FF3's battle algorithms as native code (written from the listing's banks $30 / $31 and the fixed
; bank's helpers $3F $FBEF-$FDF0). Labels carry the listing's address (fe_9E8A = 31/9E8A ...).
; Memory, as FF3's:
;   BZ ($C400, 256 bytes) = FF3's zero page during a battle (NES $00xx -> BZ + $xx).
;   work RAM bank 2 (mapped all through a battle): NES $6000-$63FF (a copy of the save page) at
;   $D000-$D3FF and NES $7400-$7FFF at $D400-$DFFF: an NES address keeps its low 12 bits.
;   Pointers in BZ hold GB addresses ($7575 -> $D575).
; Data: B_BDAT = NES banks $30 / $31 (as mapped in a battle); B_BDAT2 = NES $2E + $01; B_BDAT3 =
; NES $38 + $39
; (NES address - $4000 in the right GB bank).

BZ         = $C400
BV         = $C500          ; our own battle variables (the field's map area, rebuilt after a battle)
B_CH       = $D575          ; character properties (4 x $40)
B_MO       = $D675          ; monster properties (8 x $40)
B_BUF      = $D400          ; FF3's $7400 buffer
RNG_TAB    = $DBE3          ; FF3's $7BE3 battle random table (256)

section bank B_BAT, $4000
; ---- random (X..A) ($FBEF): A = top, B = X; uses rng counter [BZ+$21]
b_rndx:     ld c, a
            ld a, b
            ld [BZ + $20], a
            cp $FF
            ret z                           ; (X = $FF: A = $FF)
            ld a, c
            and a
            ret z
            cp b
            ret z
            sub b
            ld [BZ + $18], a                ; d = A - X
            ld e, a
            xor a
            ld [BZ + $19], a
            ld a, $80
            ld [BZ + $1A], a
            ld a, [BZ + $21]                ; t = table[counter++]
            add low(BZ + $15)
            ld l, a
            ld h, high(BZ)
            ld a, [hl]
            inc [hl]
            ld c, a
            ld b, 0
            ld hl, RNG_TAB
            add hl, bc
            ld a, [hl]
            ld [BZ + $1B], a
            push de
            call mul8                       ; HL = d * t
            pop de
            srl e                           ; + d / 2: the product's bytes 1-2 (d * (256 t + 128))
            ld a, l
            add e
            ld l, a
            ld a, h
            adc 0
            ld [BZ + $1E], a
            ld a, l
            ld [BZ + $1D], a
            ld a, [BZ + $1E]
            bit 7, l
            jr z, .r
            inc a
.r:         ld hl, BZ + $20
            add [hl]
            ret
; random (0..A) ($BEB4): counter 1
b_rnd:      ld c, a
            ld a, 1
            ld [BZ + $21], a
            ld a, c
            ld b, 0
            jr b_rndx

; HL = A * E (8 x 8)
mul8:       ld h, a
            ld l, 0
            ld d, l
            ld b, 8
.m:         add hl, hl
            jr nc, .n
            add hl, de
.n:         dec b
            jr nz, .m
            ret

; $FCD6 multiply: [BZ+$1A] (16) = A * X (B)
b_mul:      ld [BZ + $18], a
            ld e, b
            ld a, b
            ld [BZ + $19], a
            ld a, [BZ + $18]
            call mul8
            ld a, l
            ld [BZ + $1A], a
            ld a, h
            ld [BZ + $1B], a
            ret

; $FCF5 multiply (16-bit): [BZ+$1C] (32) = [BZ+$18] (16) * [BZ+$1A] (16)
b_mul16:    ld hl, BZ + $1C
            xor a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            ld a, [BZ + $1A]
            ld c, a
            ld a, [BZ + $1B]
            ld b, a                         ; BC = multiplier
            ld a, 16
.m:         push af
            ld hl, BZ + $1C                 ; result <<= 1 (from the top bit down)
            sla [hl]
            inc l
            rl [hl]
            inc l
            rl [hl]
            inc l
            rl [hl]
            sla c
            rl b
            jr nc, .n
            ld hl, BZ + $1C                 ; + multiplicand
            ld a, [BZ + $18]
            add [hl]
            ld [hl+], a
            ld a, [BZ + $19]
            adc [hl]
            ld [hl+], a
            ld a, 0
            adc [hl]
            ld [hl+], a
            ld a, 0
            adc [hl]
            ld [hl], a
.n:         pop af
            dec a
            jr nz, .m
            ret

; $FC92 divide (16-bit): [BZ+$1C] = [BZ+$18] / [BZ+$1A], [BZ+$1E] = remainder (0 if either is 0)
b_div16:    xor a
            ld [BZ + $1C], a
            ld [BZ + $1D], a
            ld [BZ + $1E], a
            ld [BZ + $1F], a
            ld a, [BZ + $18]
            ld e, a
            ld a, [BZ + $19]
            ld d, a
            or e
            ret z
            ld a, [BZ + $1A]
            ld c, a
            ld a, [BZ + $1B]
            ld b, a
            or c
            ret z
            ld hl, 0                        ; remainder
            ld a, 16
.d:         push af
            sla e                           ; dividend -> remainder
            rl d
            rl l
            rl h
            ld a, l
            sub c
            ld l, a
            ld a, h
            sbc b
            ld h, a
            jr nc, .q
            add hl, bc
            scf
.q:         ccf                             ; (carry set: the quotient bit is 1)
            ld a, [BZ + $1C]
            rla
            ld [BZ + $1C], a
            ld a, [BZ + $1D]
            rla
            ld [BZ + $1D], a
            pop af
            dec a
            jr nz, .d
            ld a, l
            ld [BZ + $1E], a
            ld a, h
            ld [BZ + $1F], a
            ret

; set / clear / check bit X (B) in A ($FD20 / $FD2C / $FD38: bit 7 first)
b_setbit:   push hl
            ld hl, bit_mask
            jr b_bit
b_clrbit:   push hl
            ld hl, bit_inv
            ld c, a
            ld a, l
            add b
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, c
            and [hl]
            pop hl
            ret
b_chkbit:   push hl
            ld hl, bit_mask
            ld c, a
            ld a, l
            add b
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, c
            and [hl]
            pop hl
            ret
b_bit:      ld c, a
            ld a, l
            add b
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, c
            or [hl]
            pop hl
            ret
bit_mask:   db $80, $40, $20, $10, $08, $04, $02, $01
bit_inv:    db $7F, $BF, $DF, $EF, $F7, $FB, $FD, $FE

; $FDA6 load array item: [BZ+$18] index, [BZ+$1A] size, [BZ+$20] NES address, A = GB bank (the
; NES bank's copy), B = X: the destination offset in B_BUF; returns B = X after the copy
b_ldarr:    push af
            push bc
            xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            ld a, [BZ + $1A]
            push af
            call b_mul16
            ld hl, BZ + $1C
            ld a, [BZ + $20]
            add [hl]
            ld [hl+], a
            ld a, [BZ + $21]
            adc [hl]
            ld [hl], a
            pop af
            ld [BZ + $1A], a
            ld c, a                         ; C = size
            pop de                          ; D = X
            pop af                          ; A = bank
            ld b, a
            ld a, [BZ + $1C]
            ld l, a
            ld a, [BZ + $1D]
            sub $40
            ld h, a
            ld e, d
            ld d, high(B_BUF)
.c:         push bc
            ld a, b
            call far_byte
            ld [de], a
            inc de
            inc hl
            pop bc
            dec c
            jr nz, .c
            ld b, e
            ret

; $FDDC load rom data to buffer: [BZ+$46] NES address, [BZ+$4B] size, A = GB bank -> B_BUF
b_ldrom:    ld b, a
            ld a, [BZ + $46]
            ld l, a
            ld a, [BZ + $47]
            sub $40
            ld h, a
            ld de, B_BUF
            ld a, [BZ + $4B]
            ld c, a
.c:         push bc
            ld a, b
            call far_byte
            ld [de], a
            inc de
            inc hl
            pop bc
            dec c
            jr nz, .c
            ret

; ---- small helpers of bank $31
; $BE90 get character offset: [BZ+$5F] = A = [BZ+$52] * $40
b_choff:    ld a, [BZ + $52]
            rrca
            rrca
            and $C0
            ld [BZ + $5F], a
            ret
; $BE98 add character offset: A += [BZ+$5F] (-> Y)
b_addoff:   ld hl, BZ + $5F
            add [hl]
            ret

; $BE9D calculate pointer: [BZ+$1C] = [BZ+$18] * [BZ+$1A] + [BZ+$20]
b_calcp:    xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            call b_mul16
            ld hl, BZ + $1C
            ld a, [BZ + $20]
            add [hl]
            ld [hl+], a
            ld a, [BZ + $21]
            adc [hl]
            ld [hl], a
            ret

; HL in FF3's ROM range (an NES pointer past $7FFF, GB $E000+): a dummy (writes there do nothing)
wchk:       ld a, h
            cp $E0
            ret c
            ld hl, W_DUMMY
            ret
W_DUMMY    = $C5A0

; A = the attacker's flags (+$2C) ($A2B5) / the target's ($BC25)
b_aflags:   %LDZ $6E, $2C
            ret
b_tflags:   %LDZ $70, $2C
            ret

; ---- $A2BA init attacker and target: slots, status buffers $F0 / $E0
fe_A2BA:    call b_aflags
            and 7
            ld [BZ + $66], a
            add a
            ld [BZ + $62], a
            call b_tflags
            and 7
            ld [BZ + $68], a
            add a
            ld [BZ + $64], a
            %PZ $6E, 1
            ld a, [BZ + $62]
            add low(BZ + $F0)
            ld e, a
            ld d, high(BZ)
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl]
            ld [de], a
            %PZ $70, 1
            ld a, [BZ + $64]
            add low(BZ + $E0)
            ld e, a
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl]
            ld [de], a
            ret

; HL = the status buffer entry of the target (BZ+$E0+[$64] + C) / attacker ($F0+[$62] + C)
st_t:       ld a, [BZ + $64]
            add $E0
            jr st_x
st_a:       ld a, [BZ + $62]
            add $F0
st_x:       add c
            ld l, a
            ld h, high(BZ)
            ret

; ---- $A300 choose random target: A = the highest slot, [BZ+$22] the records' base
fe_A300:    ld [BZ + $4A], a
            ld a, [BZ + $1A]
            push af
            xor a
            ld hl, BZ + $65
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
.r:         ld a, [BZ + $4A]
            call b_rnd
            ld [BZ + $30], a
            ld b, $40
            call b_mul
            ld a, [BZ + $1A]                ; target = base + slot * $40
            ld hl, BZ + $22
            add [hl]
            ld [BZ + $70], a
            ld a, [BZ + $1B]
            inc l
            adc [hl]
            ld [BZ + $71], a
            %LDZ $70, 1
            and $C0
            jr nz, .bad
            inc hl
            ld a, [hl]
            and 1
            jr z, .ok
.bad:       ld a, [BZ + $30]
            add low(BZ + $65)
            ld l, a
            ld h, high(BZ)
            ld [hl], 1
            ld a, [BZ + $65]
            ld hl, BZ + $66
            add [hl]
            inc l
            add [hl]
            inc l
            add [hl]
            cp 4
            jr nz, .r
            ld hl, BZ + $69
            inc [hl]
            jr .x
.ok:        call b_tflags
            and $87
            ld [$D8D8], a
            ld a, [BZ + $30]
            ld b, a
            xor a
            call b_setbit
            %STZ $6E, $2F
            ld [$DE99], a
.x:         pop af
            ld [BZ + $1A], a
            ret

; ---- $A368 add to net damage (max 9999)
fe_A368:    ld hl, BZ + $6A
            ld a, [BZ + $78]
            add [hl]
            ld [hl+], a
            ld a, [BZ + $79]
            adc [hl]
            ld [hl], a
            ld a, [BZ + $6A]
            sub $0F
            ld a, [BZ + $6B]
            sbc $27
            ret c
            ld a, $0F
            ld [BZ + $6A], a
            ld a, $27
            ld [BZ + $6B], a
            ret

; $A389 add weapon bonus to attack (attacker + C)
fe_A389:    %PZ $6E, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [BZ + $25]
            add [hl]
            ld [BZ + $25], a
            ld a, [BZ + $2B]
            adc 0
            ld [BZ + $2B], a
            ret

; $A397 check for back row penalty: A = slot; carry set if no penalty
fe_A397:    and 7
            ld [BZ + $52], a
            %LDZ $6E, $31
            inc hl
            or [hl]
            and 8
            jr nz, .no                      ; arrows equipped
            call b_choff
            add 3
            ld c, a
            %PZ $59, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [hl+]
            ld [BZ + $18], a
            ld e, a
            inc hl
            ld a, [hl]
            ld [BZ + $19], a
            ld d, a
            or e
            jr z, .pen                      ; unarmed
            ld a, [$D41E]
            and a
            jr nz, .two
            ld a, e
            and a
            jr z, .left
            cp $57
            jr nc, .left
            jr .rng
.left:      ld a, d
            jr .rng
.two:       ld a, [$D41F]
            cp 2
            ld a, e
            jr z, .rng
            ld a, d
.rng:       cp $42                          ; (the long-range weapons $3F-$41)
            jr nc, .pen
            cp $3F
            jr c, .pen
.no:        scf
            ret
.pen:       and a
            ret

; ---- $9E8A battle algorithm $03: do fight effect
fe_9E8A:    call fe_A2BA
            ld c, 0
            call st_t
            ld a, [hl+]
            and $C0
            jr nz, .rt
            ld a, [hl]
            and 1
            jr z, fe_9ED5
.rt:        %LDZ $6E, $30                   ; retarget at random
            bit 7, a
            jr z, .ch
            ld a, low(B_MO)
            ld [BZ + $22], a
            ld a, high(B_MO)
            ld [BZ + $23], a
            ld a, 7
            call fe_A300
            jr .re
.ch:        ld a, low(B_CH)
            ld [BZ + $22], a
            ld a, high(B_CH)
            ld [BZ + $23], a
            ld a, 3
            call fe_A300
            ld a, [BZ + $69]
            and a
            jr z, .re
            xor a
            ld [$DEC2], a
            dec a
            ld [$D8D8], a
            ld a, 1
            ld [fe_cy], a
            jp fe_A264
.re:        call fe_A2BA
fe_9ED5:    ld a, $FF
            ld [$DEE1], a
            xor a
            ld [$DCE9], a
            ld [BZ + $7C], a
            ld [BZ + $7D], a
            ld [$D41E], a
            ld [BZ + $6A], a
            ld [BZ + $6B], a
            ld [BZ + $42], a
            inc a
            ld [$D41F], a
            %PZ $6E, 3                      ; hp before
            ld a, [hl+]
            ld [BZ + $40], a
            ld a, [hl]
            ld [BZ + $41], a
            %PZ $70, 3
            ld a, [hl+]
            ld [BZ + $3C], a
            ld a, [hl]
            ld [BZ + $3D], a
            call b_aflags
            bit 7, a
            jr z, .chr
            ld a, [BZ + $74]                ; a monster: a target trying to run
            and a
            jr z, .stats
            call b_tflags
            bit 7, a
            jr nz, .stats
            %PZ $70, $27
            inc [hl]
            jr .stats
.chr:       %LDZ $6E, $31
            bit 7, a
            jr nz, .one
            and 1
            jr z, .one
            inc hl
            ld a, [hl]
            bit 7, a
            jr nz, .one
            and 1
            jr z, .one
.two:       ld hl, $D41F
            inc [hl]
            ld hl, $D41E
            inc [hl]
            jr .stats
.one:       %LDZ $6E, $31
            inc hl
            or [hl]
            jr z, .two                      ; unarmed in both hands
.stats:     %PZ $6E, $16                    ; the attacker's attack stats (10) to $7420 and $7440
            ld de, $D420
            ld b, 10
.s1:        ld a, [hl+]
            ld [de], a
            set 6, e                        ; ($D420-$D429 -> $D460-$D469, then -$20: $D440-)
            res 5, e
            ld [de], a
            res 6, e
            set 5, e
            inc e
            dec b
            jr nz, .s1
            %PZ $70, $20                    ; the target's defence stats (5)
            ld de, $D42A
            ld b, 5
.s2:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .s2
            %PZ $6E, $27                    ; the attacker's job modifiers (3)
            ld b, 3
.s3:        ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .s3
fe_9F6A:    ld a, [$D441]                   ; (a hand) attack multiplier, hit %
            ld [BZ + $24], a
            ld a, [$D442]
            ld [BZ + $25], a
            ld c, 0
            call st_a
            ld a, [hl]
            and 4
            jr z, .nb
            ld hl, BZ + $25                 ; blind: hit % halved
            srl [hl]
.nb:        %LDZ $6E, $33
            and 4
            jr nz, .hits                    ; harp or bow + arrow
            %LDZ $6E, $2C
            bit 7, a
            jr nz, .mon
            call fe_A397
            jr c, .hits
.mon:       %LDZ $6E, $33
            and 1
            jr z, .tb
            ld hl, BZ + $25
            srl [hl]
.tb:        %LDZ $70, $33
            and 1
            jr z, .hits
            ld hl, $DCE9
            inc [hl]
            ld hl, BZ + $25
            srl [hl]
.hits:      call fe_BB28
            ld [BZ + $7C], a
            ld a, [$D42B]                   ; the target's evasion
            ld [BZ + $24], a
            ld a, [$D42C]
            ld [BZ + $25], a
            ld c, 0
            call st_t
            ld a, [hl]
            and 4
            jr z, .tnb
            push hl
            ld hl, BZ + $25
            srl [hl]
            pop hl
.tnb:       ld a, [hl]
            and $28
            jr nz, .noev                    ; toad / mini
            %LDZ $70, $27
            and a
            jr z, .ev
.noev:      xor a
            ld [BZ + $24], a
.ev:        call fe_BB28
            ld a, [$DCE9]
            and a
            jr z, .net
            ld hl, BZ + $30
            inc [hl]
.net:       ld a, [BZ + $30]
            ld b, a
            ld a, [BZ + $7C]
            sub b
            ccf                             ; (FF3 reads this carry at $A275 after a miss)
            call fe_cyset
            jr c, .n0
            xor a
.n0:        ld [BZ + $24], a
            ld [BZ + $7C], a
            and a
            jr nz, .hit
            xor a
            %STZ $6E, $27
            jp fe_A139
.hit:       %LDZ $70, $12                   ; weak elements: x4 / absorbed: x1 / x2
            ld hl, $D440
            and [hl]
            ld a, 4
            jr nz, .mul
            ld a, [$D42A]
            cp 2
            jr z, .m1
            and [hl]
            jr z, .m2
.m1:        ld a, 1
            jr .mul
.m2:        ld a, 2
.mul:       ld [BZ + $27], a
            xor a
            ld [BZ + $2B], a
            inc a
            ld [BZ + $2A], a
            ld a, [$D431]
            ld [BZ + $28], a
            xor a
            ld [BZ + $29], a
            ld a, [$D443]
            ld [BZ + $25], a
            call b_aflags
            bit 7, a
            jr nz, .def
            ld c, $38
            call fe_A389
            ld c, $39
            call fe_A389
.def:       ld a, [$D42D]
            ld [BZ + $26], a
            call b_tflags
            bit 7, a
            jr nz, .tm
            and 7
            ld c, a
            ld b, 0
            ld hl, $DCE4
            add hl, bc
            ld a, [hl]
            and a
            jr z, .tm
            ld a, [BZ + $26]                ; defending: defence x 2 (max 255)
            cp $80
            jr c, .d2
            ld a, $FF
            ld [BZ + $26], a
            jr .tm
.d2:        ld hl, BZ + $26
            sla [hl]
.tm:        ld c, 0
            call st_a
            ld a, [hl]
            and $28
            jr z, .tt
            ld a, 1
            ld [BZ + $25], a
.tt:        ld c, 0
            call st_t
            ld a, [hl]
            and $28
            jr nz, .x2
            %LDZ $70, $27
            and a
            jr z, .crit
.x2:        ld hl, BZ + $25
            sla [hl]
            ld hl, BZ + $2B
            rl [hl]
            xor a
            ld [BZ + $26], a
.crit:      ld a, $63
            call b_rnd
            ld hl, $D430
            cp [hl]
            jr nc, .nc
            ld hl, BZ + $29
            inc [hl]
            ld hl, BZ + $CB
            inc [hl]
.nc:        ld c, 0
            call st_a
            ld a, [hl]
            and $28
            jr z, .dmg
            xor a
            ld [BZ + $29], a
            ld [BZ + $CB], a
.dmg:       call fe_BB44
            ld a, [BZ + $29]
            and a
            jr z, .jmp
            ld a, $34                       ; "Critical hit!"
            call msg_q
.jmp:       %LDZ $6E, $27
            and a
            jr z, .min
            inc a                           ; jump / buildup: damage x (n + 1)
            ld [BZ + $18], a
            xor a
            ld [hl], a
            ld [BZ + $19], a
            ld a, [BZ + $1C]
            ld [BZ + $1A], a
            ld a, [BZ + $1D]
            ld [BZ + $1B], a
            call b_mul16
.min:       ld a, [BZ + $1C]
            ld hl, BZ + $1D
            or [hl]
            jr nz, .d1
            ld hl, BZ + $1C
            inc [hl]
.d1:        ld a, [BZ + $1C]
            ld [BZ + $78], a
            ld a, [BZ + $1D]
            ld [BZ + $79], a
            %MOVZ $24, $70
            ld a, [$D440]
            and 1
            jr z, .norm
            call fe_BBE2                    ; drain
            call nc, fe_A368
            call b_tflags
            and $87
            ld [BZ + $18], a
            call b_aflags
            and $87
            ld hl, BZ + $18
            cp [hl]
            jr z, .sub
            call fe_BD67
            ld a, [BZ + $26]
            and a
            jr z, fe_A129
            bit 7, a
            jr nz, .adie
            jr .tdie
.norm:      xor a
            ld [BZ + $26], a
            call fe_A368
.sub:       call fe_BCD2
            jr c, fe_A129
.tdie:      ld c, 0
            call st_t
            set 7, [hl]
            jr fe_A139
.adie:      ld c, 0
            call st_a
            set 7, [hl]
            jr fe_A139
fe_A129:    ld a, [$DED8]
            bit 7, a
            jr nz, fe_A139
            %LDZ $6E, 1
            and $28
            jr nz, fe_A139
            call fe_BE14
fe_A139:    ld hl, $D41F                    ; the next hand
            dec [hl]
            jr z, .end
            ld hl, $D425
            ld de, $D440
            ld b, 5
.c:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .c
            ld a, [BZ + $7C]
            ld [BZ + $7D], a
            xor a
            ld [BZ + $7C], a
            ld [BZ + $78], a
            ld [BZ + $79], a
            jp fe_9F6A
.end:       ld a, [$D41E]
            and a
            jr z, .sw
            ld a, [BZ + $7C]                ; the hands' hits swapped
            ld b, a
            ld a, [BZ + $7D]
            ld [BZ + $7C], a
            ld a, b
            ld [BZ + $7D], a
.sw:        ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld a, [BZ + $7C]
            ld [BZ + $BB], a
            ld hl, BZ + $7D
            or [hl]
            jr nz, .some
            ld [BZ + $BC], a
            ld hl, $DE4F                    ; a miss
            add hl, de
            ld [hl+], a
            ld [hl], $40
            jp fe_A264
.some:      ld a, [BZ + $7D]
            ld [BZ + $BC], a
            %PZ $6E, 3                      ; the attacker's hp now
            ld a, [hl+]
            ld [BZ + $78], a
            ld a, [hl]
            ld [BZ + $79], a
            call b_aflags
            and $87
            ld [BZ + $18], a
            %LDZ $70, $2C
            and $87
            ld hl, BZ + $18
            cp [hl]
            jp z, fe_A203
            ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, $DE5F
            add hl, de
            ld a, [BZ + $78]                ; previous hp - hp now
            ld c, a
            ld a, [BZ + $40]
            sub c
            ld c, a
            ld a, [BZ + $79]
            ld b, a
            ld a, [BZ + $41]
            sbc b
            jr c, .gain
            ld [hl], c                      ; the attacker lost hp
            inc hl
            ld [hl], a
            %LDZ $6E, $16
            ld b, a
            %LDZ $6E, $1B
            or b
            and 1
            jr z, fe_A203
            ld a, $27                       ; "HP drained!"
            call msg_set
            jr fe_A203
.gain:      ld a, [BZ + $40]                ; the attacker gained hp: green
            ld c, a
            ld a, [BZ + $78]
            sub c
            ld [hl+], a
            ld a, [BZ + $41]
            ld c, a
            ld a, [BZ + $79]
            sbc c
            or $80
            ld [hl], a
            call b_aflags
            bit 7, a
            ld a, $25                       ; "Absorbed HP!"
            jr z, .g
            ld a, $26                       ; "HP drained!"
.g:         call msg_set
fe_A203:    xor a
            ld [BZ + $43], a
            call msg_at
            ld a, [hl]
            cp $FF
            ccf
            call fe_cyset                   ; (the carry $A275 reads)
            jr z, .nm
            ld hl, BZ + $43
            inc [hl]
            ld hl, $D8EE
            inc [hl]
.nm:        ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, $DE5F
            add hl, de
            ld a, [hl+]
            ld b, a
            ld a, [hl-]
            and $7F
            or b
            jr nz, .tn
            ld a, $FF
            ld [hl+], a
            ld [hl], a
            ld a, [BZ + $43]
            and a
            jr z, .tn
            ld hl, $D8EE
            dec [hl]
            call msg_at
            ld [hl], $FF
.tn:        ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, $DE4F
            add hl, de
            ld a, [BZ + $42]
            and a
            jr z, .dm
            push hl                         ; hp restored: green numerals
            %PZ $70, 3
            ld a, [BZ + $3C]
            ld c, a
            ld a, [hl+]
            sub c
            ld c, a
            ld a, [BZ + $3D]
            ld b, a
            ld a, [hl]
            sbc b
            ccf
            call fe_cyset
            or $80
            pop hl
            ld [hl], c
            inc hl
            ld [hl], a
            jr fe_A264
.dm:        ld a, [BZ + $6A]
            ld [hl+], a
            ld a, [BZ + $6B]
            ld [hl], a
fe_A264:    ld a, [BZ + $74]
            and a
            jr z, .split
            call b_aflags
            bit 7, a
            jr z, .split
            %LDZ $70, $2C
            bit 7, a
            jr nz, .split
            %PZ $70, $27                    ; (undo the running penalty: FF3's SBC #1 with the
            dec [hl]                        ;   carry its last arithmetic left: clear -> 2)
            ld a, [fe_cy]
            and a
            jr nz, .cy
            dec [hl]
.cy:
            ld a, [BZ + $7C]
            and a
            jr z, .split
            ld a, $55                       ; "Defenceless"
            call msg_q
.split:     call b_aflags
            bit 7, a
            ret nz
            call fe_BF53
            %LDZ $6E, $31
            bit 7, a
            jr nz, .h
            and 1
            jr nz, .bow
.h:         ld a, [BZ + $7D]
            and a
            jr nz, .bow
            ld a, [BZ + $7C]
            ld [BZ + $BC], a
            xor a
            ld [BZ + $BB], a
.bow:       %LDZ $6E, $33
            and 4
            jr z, .x
            ld a, [BZ + $7C]
            ld hl, BZ + $7D
            add [hl]
            ld [BZ + $BB], a
.x:         jp b_aflags

; FF3's carry after its last arithmetic (6502 sense: set = no borrow), kept where it is read later
fe_cyset:   push af
            ld a, 0
            jr nc, .c
            inc a
.c:         ld [fe_cy], a
            pop af
            ret

; the message queue ($78DA + [$78EE]): msg_q adds message A; msg_set sets it without moving on;
; msg_at: HL = the queue entry now
msg_q:      call msg_set
            ld hl, $D8EE
            inc [hl]
            ret
msg_set:    push af
            call msg_at
            pop af
            ld [hl], a
            ret
msg_at:     ld a, [$D8EE]
            add low($D8DA)
            ld l, a
            ld a, high($D8DA)
            adc 0
            ld h, a
            ret

; ---- $BB28 get number of hits: [BZ+$24] tries at [BZ+$25] % -> A = [BZ+$30]
fe_BB28:    xor a
            ld [BZ + $30], a
            ld a, [BZ + $24]
            and a
            jr z, .x
.h:         ld a, $63
            call b_rnd
            ld hl, BZ + $25
            cp [hl]
            jr nc, .m
            ld hl, BZ + $30
            inc [hl]
.m:         ld hl, BZ + $24
            dec [hl]
            jr nz, .h
.x:         ld a, [BZ + $30]
            ret

; ---- $BB44 calculate damage -> [BZ+$1C]
fe_BB44:    ld a, [BZ + $2B]                ; attack * (1 .. 3/2)
            srl a
            ld a, [BZ + $25]
            rra
            call b_rnd
            ld hl, BZ + $25
            add [hl]
            ld [BZ + $18], a
            ld a, [BZ + $2B]
            adc 0
            ld [BZ + $19], a
            xor a
            ld [BZ + $1B], a
            ld a, [BZ + $27]
            srl a
            jr nz, .mul
            ld hl, BZ + $19                 ; x 1/2
            srl [hl]
            dec l
            rr [hl]
            ld a, [BZ + $18]
            ld [BZ + $1C], a
            ld a, [BZ + $19]
            ld [BZ + $1D], a
            jr .crit
.mul:       ld [BZ + $1A], a
            call b_mul16
.crit:      ld a, [BZ + $1C]
            ld [BZ + $30], a
            ld a, [BZ + $1D]
            ld [BZ + $31], a
            ld a, [BZ + $28]                ; + crit bonus x crit flag
            ld b, a
            ld a, [BZ + $29]
            call b_mul
            ld hl, BZ + $30
            ld a, [BZ + $1A]
            add [hl]
            ld [BZ + $18], a
            inc l
            ld a, [BZ + $1B]
            adc [hl]
            ld [BZ + $19], a
            call b_aflags
            bit 7, a
            jr nz, .def
            %LDZ $70, $2C
            bit 7, a
            jr z, .hits
.def:       ld hl, BZ + $26                 ; - defence (min 0)
            ld a, [BZ + $18]
            sub [hl]
            ld [BZ + $18], a
            ld a, [BZ + $19]
            sbc 0
            ld [BZ + $19], a
            jr nc, .hits
            xor a
            ld [BZ + $18], a
            ld [BZ + $19], a
.hits:      xor a
            ld [BZ + $1B], a
            ld a, [BZ + $7C]
            ld [BZ + $1A], a
            call b_mul16
            ld a, [BZ + $1C]
            ld [BZ + $18], a
            ld a, [BZ + $1D]
            ld [BZ + $19], a
            xor a
            ld [BZ + $1B], a
            ld a, [BZ + $2A]
            ld [BZ + $1A], a
            call b_div16
            ld a, [BZ + $1C]
            sub $0F
            ld a, [BZ + $1D]
            sbc $27
            ret c
            ld a, $0F
            ld [BZ + $1C], a
            ld a, $27
            ld [BZ + $1D], a
            ret

; $BBE2 check if the target is undead (weak to holy): carry set ([BZ+$27] = 2)
fe_BBE2:    %LDZ $70, $12
            bit 7, a
            jr z, .n
            ld a, 2
            ld [BZ + $27], a
            scf
            ret
.n:         xor a
            ret

; ---- $BBF3 apply status [BZ+$24] to the target
fe_BBF3:    call b_tflags
            and 7
            add a
            ld e, a
            ld d, high(BZ)
            ld a, [BZ + $24]
            and 1
            jr nz, .s2
            ld a, e                         ; status 1
            add $E0
            ld l, a
            ld h, d
            ld a, [BZ + $24]
            ld c, a
            ld a, [hl]
            cp c
            jp nc, fe_B926
            or c
            ld [hl], a
            ld b, 0                         ; the status' index -> message $0A +
            ld a, c
.f:         add a
            jr c, .fd
            inc b
            jr .f
.fd:        ld a, b
            cp 2
            jr c, .m
            add 3
.m:         add $0A
            ld [$D8D9], a
            jp b_tflags
.s2:        ld a, [BZ + $24]
            and $20
            jr z, .s2b
            ld a, [$DED8]
            bit 7, a
            jp nz, fe_B926                  ; no confusion in boss battles
.s2b:       inc e
            ld a, e
            add $E0
            ld l, a
            ld h, d
            ld a, [BZ + $24]
            and 6
            jr nz, .pet
            ld a, [hl]                      ; paralysed, asleep, confused
            ld [BZ + $25], a
            and $E0
            ld c, a
            ld a, [BZ + $24]
            and $E0
            ld b, a
            ld a, c
            cp b
            jp nc, fe_B926
            ld a, [BZ + $25]
            and 7
            ld c, a
            ld a, [BZ + $24]
            and $FE
            or c
            ld [hl], a
            and $20
            jr z, .msg
            xor a
            %STZ $70, $2E
            call b_tflags
            and $E7
            ld [hl], a
.msg:       ld b, 0
            ld a, [BZ + $24]
.f2:        add a
            jr c, .f2d
            inc b
            jr .f2
.f2d:       ld a, b
            add $0C
            ld [$D8D9], a
            ret
.pet:       ld a, [BZ + $24]                ; partial petrification
            and $7E
            ld b, a
            ld a, [hl]
            ld [BZ + $25], a
            and 6
            add b
            cp 8
            jr nc, .stone
            ld a, [BZ + $25]
            add b
            ld [hl], a
            %LDZ $6E, $2E
            cp 4
            ret nz
            ld a, $3C                       ; "Petrifying..."
            jp msg_q
.stone:     ld a, [BZ + $25]
            and $F9
            ld [hl-], a
            set 6, [hl]
            ld a, $0B
            ld [$D8D9], a
            ld a, $28                       ; "Shattered"
            jp msg_set

; ---- $BCD2 subtract damage [BZ+$78] from the hp at [BZ+$24]: carry clear if it reached 0
fe_BCD2:    ld a, [BZ + $78]
            ld hl, BZ + $79
            or [hl]
            jr nz, .s
            scf
            ret
.s:         %PZ $24, 3
            ld a, [BZ + $78]
            ld c, a
            ld a, [hl]
            sub c
            ld [hl+], a
            ld a, [BZ + $79]
            ld c, a
            ld a, [hl]
            sbc c
            ld [hl], a
            jr c, .dead
            dec hl
            or [hl]
            jr z, .dead0
            scf
            ret
.dead0:     inc hl
.dead:      push hl
            ld hl, $D573
            inc [hl]
            pop hl
            xor a
            ld [hl-], a
            ld [hl], a
            ret                             ; (carry clear)

; $BD03 restore hp (life spells): [BZ+$78]
fe_BD03:    ld a, [$D402]
            cp $FF
            jr nz, .r
            %PZ $70, 5
            ld a, [hl+]
            ld [BZ + $78], a
            ld a, [hl]
            ld [BZ + $79], a
            ret
.r:         ld a, 9
            call b_rnd
            and a
            jr z, .r
            ld [BZ + $78], a
            xor a
            ld [BZ + $79], a
            ret

; $BD24 restore hp [BZ+$78] at [BZ+$24] (max: max hp; [BZ+$78] = what was restored)
fe_BD24:    %PZ $24, 3
            ld a, [hl]
            ld [BZ + $1A], a
            ld c, a
            ld a, [BZ + $78]
            add c
            ld [hl+], a
            ld a, [hl]
            ld [BZ + $1B], a
            ld c, a
            ld a, [BZ + $79]
            adc c
            ld [hl+], a
            ld a, [hl+]                     ; max hp
            ld [BZ + $18], a
            ld e, a
            ld a, [hl]
            ld [BZ + $19], a
            ld d, a
            dec hl
            dec hl
            dec hl                          ; (current hp)
            ld a, e
            sub [hl]
            inc hl
            ld a, d
            sbc [hl]
            ret nc
            ld [hl], d
            dec hl
            ld [hl], e
            ld a, [BZ + $1A]
            ld c, a
            ld a, e
            sub c
            ld [BZ + $78], a
            ld a, [BZ + $1B]
            ld c, a
            ld a, d
            sbc c
            ld [BZ + $79], a
            ret

; $BD67 drain hp to the attacker: [BZ+$26] 0 / 1 target died / $81 attacker died
fe_BD67:    xor a
            ld [BZ + $26], a
            call fe_BBE2
            jr nc, .live
            ld hl, BZ + $42                 ; undead: inverted
            inc [hl]
            %MOVZ $24, $6E
            call fe_BCD2
            jr c, .ad
            ld a, $81
            ld [BZ + $26], a
.ad:        %LDZ $6E, $2E
            cp 4
            call z, fe_BDAA
            jp fe_BD24
.live:      call fe_BCD2
            jr c, .td
            ld a, 1
            ld [BZ + $26], a
.td:        %MOVZ $24, $6E
            %LDZ $6E, $2E
            cp 4
            call z, fe_BDAA
            jp fe_BD24
fe_BDAA:    ld hl, BZ + $79
            srl [hl]
            dec l
            rr [hl]
            inc l
            srl [hl]
            dec l
            rr [hl]
            ret

; ---- $BE14 apply attack status (fight)
fe_BE14:    ld a, [$D444]
            ld [BZ + $25], a
            and a
            ret z
            ld a, [BZ + $7C]
            ld [BZ + $24], a
            and a
            ret z
            ld a, [BZ + $25]
            ld hl, $D42E
            and [hl]
            ret nz
            ld a, [$D42C]
            ld c, a
            ld a, [$D442]
            sub c
            jr nc, .p
            xor a
.p:         ld [BZ + $25], a
            call fe_BB28
            and a
            ret z
            ld a, [$D444]
            ld [BZ + $24], a
            jp fe_BBF3

; ---- $BF53 split monster
fe_BF53:    xor a
            ld [BZ + $18], a
            call b_tflags
            bit 7, a
            ret z
            ld c, 0
            call st_t
            ld a, [hl+]
            and $E8
            ret nz
            ld a, [hl]
            and $E0
            ret nz
            %LDZ $70, $38
            cp $4F
            ret nz
            ld a, [BZ + $BB]
            ld hl, BZ + $BC
            or [hl]
            ret z
            %LDZ $6E, $31
            and a
            jr z, .l
            bit 7, a
            jr nz, .l
            %LDZ $6E, $16
            and 2
            jr z, .go
            %LDZ $6E, $32
            and a
            ret z
            bit 7, a
            ret nz
            %LDZ $6E, $1B
            and 2
            jr z, .go
            ret
.l:         %LDZ $6E, $32
            and a
            jr z, .go
            bit 7, a
            jr nz, .go
            %LDZ $6E, $1B
            and 2
            jr z, .go
            ret
.go:        ld hl, $DDA7                    ; a free slot (0-5)
            ld b, 0
.f:         ld a, [hl+]
            cp $FF
            jr z, .fr
            inc b
            ld a, b
            cp 6
            jr nz, .f
            ret
.fr:        ld a, b
            ld [BZ + $1C], a
            ld e, a
            ld d, 0
            ld hl, $DEC4
            add hl, de
            ld [hl], 0
            ld a, b
            add a
            add low(BZ + $E0)
            ld l, a
            ld h, high(BZ)
            ld [hl], 0
            ld a, [BZ + $68]
            ld b, a
            ld a, [$DBE1]
            call b_clrbit
            ld [$DBE1], a
            call b_tflags
            and 7
            ld [BZ + $18], a
            ld e, a
            ld d, 0
            ld hl, $DDA7
            add hl, de
            ld a, [hl]
            ld [$DEE1], a
            call fe_B9AB
            %PZ $20, 1
            xor a
            ld [hl+], a
            ld [hl], a
            ld a, $6F                       ; "Divided"
            jp msg_set

section wram, $C500
fe_cy:      ds 1
