; FF3's magic and item effects (31/AF77-31/BB1B) as native code; memory as in batcore.s.
; The effect routines run with the return into fe_AF77 on top of the stack, as on the NES: FF3's
; "PLA PLA / JMP $B15E" (leave the whole spell) is "pop hl / ret" here.

section bank B_BAT, $5800
; ---- battle algorithm $00: do magic effect ($1A = the magic id)
fe_AF77:    xor a
            ld [BZ + $54], a
            ld hl, $DEB8                    ; reflect targets and the target slot cleared
            ld b, 10
.c:         ld [hl+], a
            dec b
            jr nz, .c
            ld a, [BZ + $CC]
            and a
            jr nz, .flg
            call b_aflags
            bit 7, a
            jr nz, .chk
            and $10
            jr z, .chk
            ld a, [BZ + $1A]
            cp $50
            jr nc, .flg                     ; a terrain attack
.chk:       %LDZ $6E, 1
            and $30
            jr z, .ok
            and $20
            jr z, .sil
            ld a, [BZ + $1A]                ; a toad casts only Toad
            cp $F6
            jr z, .ok
            ld a, $53                       ; "Can't use magic"
            jr .no
.sil:       ld a, $50                       ; "Silenced"
.no:        ld [$D8DA], a
            ld a, $18
            ld [$DEC2], a
            ret
.ok:        call b_aflags
            and $18
            jr nz, .flg
            ld a, [BZ + $1A]
            sub $C8
            ld [BZ + $1A], a
.flg:       %LDZ $6E, $2C
            and $E7
            ld [hl], a
            ld b, 0
            ld a, [BZ + $1A]
            ld [$DE88], a
            cp $5B
            jr c, .s
            inc b
.s:         ld a, b
            ld [$DEC3], a
            ld a, [BZ + $1A]                ; the attack's properties (30/98C0) -> $7400
            ld [BZ + $18], a
            ld a, 8
            ld [BZ + $1A], a
            ld a, $C0
            ld [BZ + $20], a
            ld a, $98
            ld [BZ + $21], a
            ld b, 0
            ld a, B_BDAT
            call b_ldarr
            ld a, [$D406]
            ld [$DE9D], a
            ld a, [$DE99]                   ; the number of targets
            ld b, 8
            ld c, 0
.n:         add a
            jr nc, .n0
            inc c
.n0:        dec b
            jr nz, .n
            ld a, c
            ld [BZ + $2A], a
            %LDZ $6E, $30
            bit 7, a
            ld hl, B_CH
            jr z, .t
            ld hl, B_MO
.t:         ld a, l
            ld [BZ + $70], a
            ld a, h
            ld [BZ + $71], a
fe_B031:    call fe_A2BA
            ld a, $FF
            ld hl, BZ + $78
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
            xor a
            ld [$D574], a
            ld [$D573], a
            ld a, [$DE9D]
            cp 6
            jr z, fe_B065
            ld c, 0
            call st_a
            ld a, [hl]
            and $C0
            ret nz
            ld a, [$DEC1]
            ld b, a
            ld a, [$DE99]
            call b_chkbit
            jp z, fe_B139
fe_B065:    ld a, [BZ + $CC]
            and a
            jr nz, fe_B0D3
            ld a, [$D405]
            and $10
            ld c, $10
            jr z, .i
            inc c
.i:         %PZ $6E, 0                      ; intellect or spirit
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [hl]
            ld [BZ + $18], a
            srl a
            ld hl, $D401
            add [hl]
            ld [BZ + $25], a
            ld c, 0
            call st_a
            ld a, [hl]
            and 4
            jr z, .nb
            ld hl, BZ + $25
            srl [hl]
.nb:        %LDZ $6E, $0F                   ; job level / 32
            swap a
            srl a
            and 7
            ld [BZ + $19], a
            %LDZ $6E, 0                     ; level / 16
            swap a
            and 15
            ld [BZ + $1A], a
            ld a, [BZ + $18]
            swap a
            and 15
            scf
            ld hl, BZ + $19
            adc [hl]
            inc l
            adc [hl]
            ld [BZ + $24], a
            ld [BZ + $38], a
            call fe_BB28
            ld [BZ + $7C], a
            %LDZ $6E, $33                   ; (boosted elements: never set, a bug in FF3)
            and $E0
            srl a
            srl a
            srl a
            ld hl, $D400
            and [hl]
            jr z, fe_B0D3
            ld a, [BZ + $30]
            ld [BZ + $18], a
            ld a, 5
            ld [BZ + $1A], a
            xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            call b_div16
            ld a, [BZ + $1C]
            ld hl, BZ + $30
            add [hl]
            ld [BZ + $7C], a
fe_B0D3:    call fe_B15F
            ld a, [BZ + $79]
            cp $FF
            jr z, fe_B129
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld a, [$D574]
            and a
            jr nz, .refl
            ld hl, $DE4F
            add hl, de
            ld a, [BZ + $78]
            ld [hl+], a
            ld a, [BZ + $79]
            ld [hl], a
            jr fe_B129
.refl:      call b_tflags
            and 7
            add a
            ld e, a
            ld hl, $DE5F
            add hl, de
            inc hl
            ld a, [hl-]
            cp $FF
            jr z, .new
            ld a, [BZ + $78]
            add [hl]
            ld [hl+], a
            ld a, [BZ + $79]
            adc [hl]
            ld [hl], a
            jr .ptr
.new:       ld a, [BZ + $78]
            ld [hl+], a
            ld a, [BZ + $79]
            ld [hl], a
.ptr:       ld a, [$D8B5]
            ld [BZ + $70], a
            ld a, [$D8B6]
            ld [BZ + $71], a
            jr fe_B131
fe_B129:    %MOVZ $24, $70
            xor a
            call fe_BDC5
fe_B131:    %MOVZ $24, $6E
            ld a, 1
            call fe_BDC5
fe_B139:    ld hl, $DEC1
            inc [hl]
            ld a, [hl]
            cp 8
            ret z
            cp 4
            jr nz, .nx
            ld a, [$DE9A]
            and $40
            ret z
.nx:        ld hl, BZ + $70
            ld a, [hl]
            add $40
            ld [hl+], a
            ld a, [hl]
            adc 0
            ld [hl], a
            jp fe_B031

; ---- $B15F do attack effect [$7404]
fe_B15F:    ld a, [$D404]
            add a
            ld l, a
            ld h, 0
            ld de, fx_table
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
fx_table:   dw fe_B17C, fe_B233, fe_B276, fe_B2B5, fe_B30C, fe_B37A, fe_B3CA, fe_B3F1
            dw fe_B474, fe_B480, fe_B48C, fe_B49B, fe_B4C8, fe_B4B9, fe_B4C9, fe_B4D4
            dw fe_B4F4, fe_B4D4, fe_B51F, fe_B56C, fe_B5AA, fe_B5E7, fe_B62C, fe_B17C
            dw fe_B233, fe_B658, fe_B4C8, fe_B17C, fe_B30C, fe_B17C, fe_B17C, fe_B30C
            dw fe_B17C, fe_B17C, fe_B233, fe_B17C, fe_B17C, fe_B17C, fe_B17C, fe_B17C
            dw fe_B48C, fe_B17C, fe_B688, fe_B30C, fe_B17C, fe_B17C, fe_B480, fe_B6B0
            dw fe_B17C, fe_B17C, fe_B30C, fe_B17C, fe_B30C, fe_B30C, fe_B17C, fe_B17C
            dw fe_B17C

; ---- effect $00: normal magic damage
fe_B17C:    %LDZ $70, $26
            and a
            call nz, fe_B9FA                ; reflect
            call fe_B88F
            call fe_B8E7
            jr z, .x
            ld a, [$D403]
            and 1
            jr z, .s1
            ld a, [$DED8]
            bit 7, a
            jr nz, .inef
.s1:        ld a, [$D403]
            and 2
            jr z, .dmg
            ld a, [$DED8]
            bit 7, a
            jr nz, .inef
            %LDZ $70, 1
            ld hl, $D403
            cp [hl]
            jr c, .dmg
.inef:      call fe_B926
.x:         jp .refl
.dmg:       %LDZ $70, $15                   ; m.defence
            ld [BZ + $26], a
            ld a, [$D405]
            and $10
            ld c, $10
            jr z, .i
            inc c
.i:         %PZ $6E, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [hl]
            srl a
            ld hl, $D402
            add [hl]
            ld [BZ + $25], a
            ld a, 0
            adc 0
            ld [BZ + $2B], a
            ld c, 0
            call st_t
            ld a, [hl]
            and $28
            jr nz, .x2
            %LDZ $70, $27
            and a
            jr z, .div
.x2:        ld hl, BZ + $25
            sla [hl]
            ld hl, BZ + $2B
            rl [hl]
            xor a
            ld [BZ + $26], a
.div:       ld a, [$D405]
            and $40
            jr z, .nc
            ld a, 1
            ld [BZ + $2A], a
.nc:        xor a
            ld [BZ + $28], a
            ld [BZ + $29], a
            ld a, [BZ + $7C]
            ld [BZ + $24], a
            call fe_BB44
            ld a, [BZ + $1C]
            ld hl, BZ + $1D
            or [hl]
            jr nz, .m
            ld hl, BZ + $1C
            inc [hl]
.m:         ld a, [BZ + $1C]
            ld [BZ + $78], a
            ld a, [BZ + $1D]
            ld [BZ + $79], a
            %MOVZ $24, $70
            call fe_BCD2
            call c, fe_BE43
.refl:      ld a, [$D574]
            and a
            ret z
            %PZ $70, 3
            ld a, [hl+]
            or [hl]
            ret nz
            %PZ $70, 1
            set 7, [hl]
            ret

; ---- effect $01 / $18: healing
fe_B233:    call fe_BBE2
            jr nc, fe_B23F
            ld a, 1                         ; "damages undead"
            ld [BZ + $54], a
            jp fe_B17C
fe_B23F:    call fe_B921
            ret z
            ld a, [$D405]
            and 7
            cp 6
            jr nz, .cal
            ld a, [BZ + $2A]
            cp 1
            jr nz, .cal
            %PZ $70, 5                      ; Cure 4 on one: hp to max
            ld a, [hl+]
            ld c, a
            ld a, [hl-]
            dec hl
            ld [hl-], a
            ld [hl], c
            ret
.cal:       call fe_B6DD
            %MOVZ $24, $70
            call fe_BD24
            ld hl, BZ + $79
            set 7, [hl]
            ret

; ---- effect $02: tornado
fe_B276:    call fe_B8E7
            ret z
            call b_tflags
            bit 7, a
            jr z, .go
            ld a, [$DED8]
            bit 7, a
            jp nz, fe_B926
.go:        ld a, [$D402]
            call b_rnd
            ld hl, $D402
            add [hl]                        ; (carry from the random: clear)
            ld [BZ + $18], a
            ld c, a
            %PZ $70, 3
            ld a, [hl+]                     ; (FF3: SBC with the carry the ADC left: clear,
            scf                             ;   so hp - value - 1)
            ccf
            sbc c
            ld a, [hl]
            sbc 0
            jp c, fe_B926
            ld [hl], 0
            dec hl
            ld a, [BZ + $18]
            ld [hl], a
            ret

; ---- effect $03: drain
fe_B2B5:    call fe_B8E7
            jp z, fe_B926
            call b_tflags
            bit 7, a
            jr z, .go
            ld a, [$DED8]
            bit 7, a
            jp nz, fe_B926
.go:        call b_aflags
            and $87
            ld [BZ + $28], a
            %LDZ $70, $2C
            and $87
            ld hl, BZ + $28
            cp [hl]
            jp z, fe_B926
            call fe_B6DD
            ld a, [BZ + $78]
            push af
            ld a, [BZ + $79]
            push af
            %MOVZ $24, $70
            call fe_BD67
            pop af
            ld [BZ + $79], a
            pop af
            ld [BZ + $78], a
            ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, $DE5F
            add hl, de
            ld a, [BZ + $42]
            and a
            jr z, .g
            ld a, [BZ + $78]
            ld [hl+], a
            ld a, [BZ + $79]
            ld [hl], a
            ld hl, BZ + $79
            set 7, [hl]
            ret
.g:         ld a, [BZ + $78]
            ld [hl+], a
            ld a, [BZ + $79]
            or $80
            ld [hl], a
            ret

; ---- effect $04: apply status
fe_B30C:    call fe_BBE2
            jr nc, .st
            ld a, [$DE88]
            cp 1
            jr nz, .st
            ld a, 5
            ld [BZ + $54], a
            jp fe_B23F
.st:        call fe_B8E7
            ret z
            call b_tflags
            bit 7, a
            jr z, .go
            ld a, [$DED8]
            bit 7, a
            jp nz, fe_B926
.go:        ld a, [$D403]
            ld [BZ + $24], a
            and $20
            jr z, .res
            ld c, 0
            call st_t
            ld a, [hl]
            and $40
            jp nz, fe_B926
.res:       call fe_B875
            jp nc, fe_B926
            ld a, [$DE88]
            cp $16
            jp nz, fe_BBF3
            %LDZ $6E, 0                     ; Kill: the target's level below 3/4 of the attacker's
            srl a
            ld c, a
            srl a
            add c
            ld c, a
            %LDZ $70, 0
            cp c
            jp nc, fe_B926
            jp fe_BBF3

; ---- effect $05: raise / arise
fe_B37A:    call fe_BBE2
            jr nc, .go
            ld c, 0
            call st_t
            bit 7, [hl]
            jr nz, .go
            ld a, 4
            ld [BZ + $54], a
            jp fe_B30C
.go:        call fe_B921
            ret z
            ld c, 0
            call st_t
            bit 7, [hl]
            jr nz, .dead
            xor a
            ld [BZ + $7C], a
            jr .go
.dead:      ld a, [$D403]
            ld [BZ + $24], a
            call fe_B7F1
            call b_tflags
            bit 7, a
            jr z, .msg
            and 7
            ld e, a
            ld d, 0
            ld hl, $DEC4
            add hl, de
            ld [hl], 0
.msg:       xor a
            ld [$D8D9], a
            call fe_BD03
            %MOVZ $24, $70
            call fe_BD24
            ld hl, BZ + $79
            set 7, [hl]
            ret

; ---- effect $06: remove status
fe_B3CA:    call fe_B921
            ret z
            ld a, [$D403]
            ld [BZ + $24], a
            cp $FF
            jr nz, .r
            ld c, 0
            call st_t
            ld a, [hl+]
            and $40
            jr z, .r
            ld a, [hl]
            and $20
            jp nz, fe_B926
.r:         jp fe_B7F1

; ---- effect $07: toad / mini
fe_B3F1:    call b_aflags
            bit 7, a
            jr nz, .ev
            %LDZ $70, $2C
            bit 7, a
            jr z, .tg
.ev:        call fe_B8E7
            ret z
.tg:        call b_tflags
            bit 7, a
            jr z, .go
            ld a, [$DED8]
            bit 7, a
            jp nz, fe_B926
.go:        %PZ $70, 1
            ld a, [hl]
            ld [BZ + $18], a
            ld c, a
            ld a, [$D403]
            xor c
            ld [hl], a
            ld [BZ + $19], a
            and $28
            jr z, .b
            ld a, [$D403]
            or [hl]
.b:         push af
            ld c, 0
            call st_t
            pop af
            ld [hl], a
            ld a, [BZ + $19]
            and $20
            jr z, .mi
            ld a, [BZ + $18]
            and $20
            ret nz
            ld a, $0F                       ; "Frog"
            jr .m
.mi:        ld a, [BZ + $19]
            and 8
            jr z, .ct
            ld a, [BZ + $18]
            and 8
            ret nz
            ld a, $11                       ; "Mini"
            jr .m
.ct:        ld a, [BZ + $18]
            and $20
            jr z, .ce
            ld a, [BZ + $19]
            and $20
            ret nz
            ld a, $05                       ; "Cured"
            jr .m
.ce:        ld a, [BZ + $18]
            and 8
            ret z
            ld a, [BZ + $19]
            and 8
            ret nz
            ld a, $07                       ; "Enlarged"
.m:         ld [$D8D9], a
            ret

; ---- effect $08: protect; $09: haste; $0A: reflect
fe_B474:    call fe_B921
            ret z
            call fe_B6DD
            jp fe_B704
fe_B480:    call fe_B921
            ret z
            call fe_B6DD
            jp fe_B752
fe_B48C:    call fe_B921
            ret z
            %PZ $70, $26
            inc [hl]
            ret

; ---- effect $0B: erase
fe_B49B:    call fe_B8E7
            ret z
            call b_tflags
            bit 7, a
            jr z, .go
            ld a, [$DED8]
            bit 7, a
            jp nz, fe_B926
.go:        %PZ $70, $20
            ld a, [hl]
            and 3
            ld [hl], a
            ret

; ---- effect $0D: libra (hp to $78E4); $0C: sight
fe_B4B9:    %PZ $70, 3
            ld de, $D8E4
            ld b, 4
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
fe_B4C8:    ret

; ---- effect $0E / $0F / $11: divide
fe_B4C9:    call fe_B936
            call fe_B9A0
fe_B4CF:    pop hl                          ; (leave the whole spell)
            ret
fe_B4D4:    %PZ $6E, 3
            ld a, [hl+]
            ld c, a
            inc hl
            ld a, [hl-]
            dec hl
            cp c
            jr nz, .s
            inc hl
            ld a, [hl+]
            inc hl
            cp [hl]
            call z, fe_B98B
.s:         call fe_B936
            call fe_B9A0
            jr fe_B4CF

; ---- effect $10: monster summon
fe_B4F4:    call fe_B936
            ld a, [BZ + $1C]
            ld [BZ + $27], a
            call fe_B9ED
.r:         ld a, 3
            call b_rnd
            and a
            jr z, .r
            ld e, a
            ld d, 0
            ld [$DE99], a
            ld hl, $DD6B
            add hl, de
            ld a, [hl]
            ld [BZ + $26], a
            ld a, 1
            ld [$DE9B], a
            call fe_A4FE
            xor a
            %STZ $5D, $2E
            jr fe_B4CF

; ---- effect $12: self-destruct
fe_B51F:    %PZ $6E, 3
            ld a, [hl+]
            ld [BZ + $18], a
            ld e, a
            ld a, [hl+]
            ld [BZ + $19], a
            ld d, a
            ld a, e
            sub [hl]
            inc hl
            ld a, d
            sbc [hl]
            jr z, .full
            sla e                           ; damage = hp x 4
            rl d
            sla e
            rl d
            ld a, e
            ld [BZ + $78], a
            ld a, d
            ld [BZ + $79], a
            %MOVZ $24, $70
            call fe_BCD2
            %PZ $6E, 1
            ld [hl], $80
            inc hl
            inc hl
            xor a
            ld [hl+], a
            ld [hl], a
            ret
.full:      ld a, $FF
            ld [$D8D7], a
            ld [$D8D8], a
            xor a
            ld [$DE99], a
            ld a, $44                       ; "Searching..."
            ld [$D8DA], a
            ret

; ---- effect $13: barrier shift
fe_B56C:    call fe_B57A
            ld a, $FF
            ld [$DBE2], a
            ld [$D8D8], a
            jr fe_B4CF
fe_B57A:    ld a, 1
            ld [BZ + $21], a
            ld b, 3
            ld a, 5
            call b_rndx
            ld [BZ + $24], a
.r:         ld a, 1
            ld [BZ + $21], a
            ld b, 3
            ld a, 5
            call b_rndx
            ld hl, BZ + $24
            cp [hl]
            jr z, .r
            ld [fe_x], a
            ld b, a
            xor a
            call b_setbit
            %STZ $6E, $12
            ld a, [fe_x]
            ld b, a
            ld a, $FF
            call b_clrbit
            %STZ $6E, $20
            ret

; ---- effect $14: elixir
fe_B5AA:    %PZ $70, 5
            ld a, [hl+]
            ld c, a
            ld a, [hl-]
            dec hl
            ld [hl-], a
            ld [hl], c
            call b_tflags
            and 7
            ld [BZ + $52], a
            call b_choff
            add $31
            ld [BZ + $18], a
            ld a, [BZ + $5F]
            add 7
            ld [BZ + $19], a
            ld b, 8
.c:         push bc
            ld a, [BZ + $18]
            ld c, a
            %PZ $57, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld a, [hl]
            ld e, a
            ld a, [BZ + $19]
            ld c, a
            %PZ $5B, 0
            ld a, l
            add c
            ld l, a
            ld a, h
            adc 0
            ld h, a
            ld [hl], e
            ld hl, BZ + $18
            inc [hl]
            inc [hl]
            inc l
            inc [hl]
            pop bc
            dec b
            jr nz, .c
            xor a
            ld [BZ + $52], a
            ret

; ---- effect $15: defence; $16: bite (Adamantoise)
fe_B5E7:    ld a, [$D8C9]
            and a
            jr nz, .x
            %PZ $6E, $13
            ld de, $D8C9
            ld b, 3
.a:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .a
            %PZ $6E, $21
            ld b, 3
.d:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .d
            %PZ $6E, $13
            ld [hl], $10
            inc hl
            ld [hl], $63
            inc hl
            ld [hl], $FF
            %PZ $6E, $21
            ld [hl], $10
            inc hl
            ld [hl], $63
            inc hl
            ld [hl], $FF
.x:         ld a, $FF
            ld [$D8D8], a
            ret
fe_B62C:    %PZ $6E, $13
            ld de, $D8C9
            ld b, 3
.a:         ld a, [de]
            ld [hl+], a
            inc de
            dec b
            jr nz, .a
            %PZ $6E, $21
            ld b, 3
.d:         ld a, [de]
            ld [hl+], a
            inc de
            dec b
            jr nz, .d
            ld hl, $D8C9
            xor a
            ld b, 6
.z:         ld [hl+], a
            dec b
            jr nz, .z
            jp fe_B17C

; ---- effect $19: chocobo dash; $2A zantetsuken; $2F rend
fe_B658:    ld a, [$DED8]
            bit 7, a
            jr nz, fx_inef
            ld a, $63
            call b_rnd
            cp $50
            jr nc, fx_inef
            ld a, 2                         ; ran away
            ld [$D8D3], a
            jp fe_B4CF
fx_inef:    ld hl, $DE93
            inc [hl]
            ld a, $3B                       ; "Ineffective"
            ld [$D8DA], a
            jp fe_B4CF
fe_B688:    ld a, [$DED8]
            bit 7, a
            jr nz, fx_inef
            ld a, $63
            call b_rnd
            cp $3C
            jr nc, fx_inef
            ld hl, BZ + $EE                 ; all enemies dead
.z:         set 7, [hl]
            dec l
            dec l
            ld a, l
            cp low(BZ + $E0) - 2
            jr nz, .z
            jp fe_B4CF
fe_B6B0:    ld a, [$DED8]
            bit 7, a
            jr nz, fx_inef
            ld a, $63
            call b_rnd
            cp $3C
            jr nc, fx_inef
            %PZ $70, 3
            xor a
            ld [hl+], a
            ld [hl], a
            ld c, 0
            call st_t
            set 7, [hl]
            jp fe_B4CF

; ---- $B6DD calculate restorative damage -> [BZ+$78]
fe_B6DD:    xor a
            ld [BZ + $28], a
            ld [BZ + $29], a
            ld [BZ + $2B], a
            ld a, 2
            ld [BZ + $27], a
            ld a, [BZ + $7C]
            ld [BZ + $24], a
            ld a, [$D402]
            ld [BZ + $25], a
            %LDZ $70, $15
            ld [BZ + $26], a
            call fe_BB44
            ld a, [BZ + $1C]
            ld [BZ + $78], a
            ld a, [BZ + $1D]
            ld [BZ + $79], a
            ret

; ---- $B704 protect effect: + [BZ+$78] to defence and m.defence
fe_B704:    %LDZ $70, $23
            cp $FF
            jr nz, .go
            %LDZ $70, $15
            cp $FF
            jr z, .no
.go:        %PZ $70, $23
            call .add
            %PZ $70, $15
            call .add
            jp fe_B74B
.add:       ld a, [BZ + $78]
            add [hl]
            ld [hl], a
            ld a, [BZ + $79]
            adc 0
            ld [BZ + $79], a
            ret z
            ld [hl], $FF
            ret
.no:        call fe_B74B
            jp fe_B926
fe_B74B:    ld a, $FF
            ld [BZ + $79], a
            ld [BZ + $78], a
            ret

; ---- $B752 haste effect: + [BZ+$78] attack, + [BZ+$7C] multiplier (max 16)
fe_B752:    %LDZ $70, $19
            cp $FF
            jr z, .no
            %LDZ $70, $1E
            cp $FF
            jr z, .no
            %LDZ $70, $17
            cp $10
            jr nc, .no
            %LDZ $70, $1C
            cp $10
            jr nc, .no
            %PZ $70, $19
            call fe_B704.add
            %PZ $70, $1E
            call fe_B704.add
            %PZ $70, $17
            call .mul
            %PZ $70, $1C
            call .mul
            jp fe_B74B
.mul:       ld a, [BZ + $7C]
            add [hl]
            cp $10
            jr c, .m
            ld a, $10
.m:         ld [hl], a
            ret
.no:        call fe_B74B
            jp fe_B926

; ---- $B7F1 remove status [BZ+$24]
fe_B7F1:    ld a, [BZ + $24]
            and 1
            jr nz, .s2
            %LDZ $70, 1
            ld hl, BZ + $24
            and [hl]
            jp z, fe_B926
            ld a, [hl]
            cpl
            ld c, a
            %PZ $70, 1
            ld a, [hl]
            and c
            ld [hl], a
            push af
            ld c, 0
            call st_t
            pop af
            ld [hl], a
            ld c, 0
            call fe_B865
            ld b, 0
            ld a, [BZ + $24]
.f:         add a
            jr c, .fd
            inc b
            jr .f
.fd:        ld a, b
            cp 2
            jr c, .m
            add 3
.m:         ld [$D8D9], a
            ret
.s2:        %PZ $70, 1
            ld a, [hl+]
            or [hl]
            jp z, fe_B926
            ld a, [BZ + $24]
            cp $FF
            ld a, $80
            jr z, .a
            ld a, $BF
.a:         dec hl
            and [hl]
            ld [hl+], a
            ld a, [BZ + $24]
            cp $FF
            ld a, 0
            jr z, .b
            ld a, [hl]
            and $F9
.b:         ld [hl], a
            ld c, 0
            call st_t
            xor a
            ld [hl+], a
            ld [hl], a
            ld c, 1                         ; (FF3: X = the target's + 1 here)
            call fe_B865
            ret nz
            ld c, 0
            call st_a
            ld [hl], 0
            ret
; $B865: the target the attacker itself: the status buffer byte C copied ($E0 -> $F0); Z set
; when they are the same
fe_B865:    push bc
            call b_tflags
            ld [BZ + $18], a
            %LDZ $6E, $2C
            ld hl, BZ + $18
            cp [hl]
            pop bc
            ret nz
            push bc
            call st_t
            ld a, [hl]
            pop bc
            push af
            call st_a
            pop af
            ld [hl], a
            xor a
            ret
fe_B875:    call fe_B921
            %LDZ $70, $24
            ld hl, BZ + $24
            and [hl]
            jr nz, .c
            scf
            ret
.c:         and a
            ret

; ---- $B88F apply elemental modifiers
fe_B88F:    xor a
            ld [BZ + $27], a
            %LDZ $70, $24
            and 1
            jr z, .weak
            %LDZ $70, $20
            ld hl, $D400
            and [hl]
            jr z, .weak
            ld a, 4                         ; absorbed: healing instead
            ld [BZ + $27], a
            pop hl
            ld a, 2
            ld [BZ + $54], a
            jp fe_B23F
.weak:      %LDZ $70, $12
            ld hl, $D400
            and [hl]
            jr nz, .x4
            %LDZ $6E, $33                   ; (FF3's shift goes the wrong way: never boosted)
            and $E0
            add a
            add a
            add a
            ld hl, $D400
            and [hl]
            jr z, .str
.x4:        ld a, 4
            ld [BZ + $27], a
            ret
.str:       %LDZ $70, $20
            ld hl, $D400
            and [hl]
            jr nz, .x1
            %LDZ $70, $20
            cp 2
            jr z, .x1
            ld a, 2
            jr .s
.x1:        ld a, 1
.s:         ld [BZ + $27], a
            ret

; ---- $B8E7 apply m.evade -> [BZ+$7C]; Z set when no hits
fe_B8E7:    call b_aflags
            bit 7, a
            jr nz, .ev
            %LDZ $70, $2C
            bit 7, a
            jr nz, .ev
            ld a, [BZ + $7C]
            and a
            jr nz, .st
.ev:        %PZ $70, $13
            ld a, [hl+]
            ld [BZ + $24], a
            ld a, [hl]
            ld [BZ + $25], a
            %LDZ $70, 1
            and 4
            jr z, .nb
            ld hl, BZ + $25
            srl [hl]
.nb:        %LDZ $70, 1
            and $28
            jr z, .h
            xor a
            ld [BZ + $24], a
.h:         call fe_BB28
            ld a, [BZ + $30]
            ld c, a
            ld a, [BZ + $7C]
            sub c
            jr nc, .st
            xor a
.st:        ld [BZ + $7C], a
fe_B921:    ld a, [BZ + $7C]
            and a
            ret nz
fe_B926:    ld a, [$DEC1]                   ; attack ineffective: off the target mask
            ld b, a
            ld a, [$DE9B]
            call b_clrbit
            ld [$DE9B], a
            ld a, [BZ + $7C]
            and a
            ret

; ---- $B936 (split / summon: status buffers from the monsters, a free slot)
fe_B936:    ld hl, B_MO + 1
            ld de, BZ + $E0
            ld b, 4
.c:         ld a, [hl]
            ld [de], a
            ld c, a
            ld a, e
            add $10
            ld e, a
            ld a, c
            ld [de], a
            ld a, e
            sub $0E
            ld e, a
            ld a, l
            add $40
            ld l, a
            ld a, h
            adc 0
            ld h, a
            dec b
            jr nz, .c
            ld hl, $DDA7
            ld b, 0
.f:         ld a, [hl+]
            cp $FF
            jr z, .fr
            inc b
            ld a, b
            cp 6
            jr nz, .f
            jr fe_B98B
.fr:        ld a, b
            ld [BZ + $1C], a
            ld e, a
            ld d, 0
            ld hl, $DEC4
            add hl, de
            ld [hl], 0
            ld a, $FF
            ld [$D8D8], a
            call b_aflags
            and 7
            ld [BZ + $18], a
            ld e, a
            ld hl, $DDA7
            add hl, de
            ld a, [hl]
            ld [$DE99], a
            ld a, 1
            ld [$DE9B], a
            ret
fe_B98B:    ld a, $FF
            ld [$D8D7], a
            ld [$D8D8], a
            ld [$DE99], a
            ld a, $44                       ; "Searching..."
            ld [$D8DA], a
            pop hl                          ; (out of the caller too)
            jp fe_B4CF
fe_B9A0:    ld a, $FF
            ld [$D8D8], a
            call fe_B9AB
            jp fe_B9ED
; $B9AB copy monster properties: slot [BZ+$18] -> slot [BZ+$1C] ([BZ+$20] = the new record)
fe_B9AB:    ld a, [BZ + $18]
            ld b, $40
            call b_mul
            ld a, [BZ + $1A]
            add low(B_MO)
            ld [BZ + $1E], a
            ld a, [BZ + $1B]
            adc high(B_MO)
            ld [BZ + $1F], a
            ld a, [BZ + $1C]
            ld b, $40
            call b_mul
            ld a, [BZ + $1A]
            add low(B_MO)
            ld [BZ + $20], a
            ld e, a
            ld a, [BZ + $1B]
            adc high(B_MO)
            ld [BZ + $21], a
            ld d, a
            ld a, [BZ + $1E]
            ld l, a
            ld a, [BZ + $1F]
            ld h, a
            ld b, $40
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            %PZ $20, $2C
            ld a, [BZ + $1C]
            or $80
            and $E7
            ld [hl+], a
            inc hl
            ld [hl], 0
            ret
; $B9ED clear target status [BZ+$1C]
fe_B9ED:    ld a, [BZ + $1C]
            add a
            add low(BZ + $E0)
            ld l, a
            ld h, high(BZ)
            xor a
            ld [hl], a
            set 4, l
            ld [hl], a
            ret

; ---- $B9FA do reflect effect
fe_B9FA:    call b_aflags
            bit 7, a
            jr nz, .mon
            %LDZ $70, $2C
            bit 7, a
            ret z
            jr .go
.mon:       %LDZ $70, $2C
            bit 7, a
            ret nz
.go:        ld a, [$DE88]                   ; reflectable? (a bit per spell)
            ld [BZ + $18], a
            srl a
            srl a
            srl a
            ld e, a
            ld d, 0
            ld hl, refl_bits
            add hl, de
            ld a, [BZ + $18]
            and 7
            inc a
            ld b, a
            ld a, [hl]
.sh:        add a
            dec b
            jr nz, .sh
            ret nc
            ld a, [BZ + $70]
            ld [$D8B5], a
            ld a, [BZ + $71]
            ld [$D8B6], a
            call b_tflags
            push af
            and 7
            ld b, a
            ld a, [$DEB8]
            call b_setbit
            ld [$DEB8], a
            xor a
            %STZ $70, $26
            ld [BZ + $24], a
            ld [BZ + $27], a
            ld a, 3
            ld [BZ + $25], a
            pop af
            bit 7, a
            jr nz, .r
            ld a, 4
            ld [BZ + $24], a
            ld a, $0B
            ld [BZ + $25], a
            ld a, $FC
            ld [BZ + $27], a
.r:         ld a, 1
            ld [BZ + $21], a
            ld a, [BZ + $24]
            ld b, a
            ld a, [BZ + $25]
            call b_rndx
            push af
            ld hl, BZ + $27
            add [hl]
            ld [BZ + $26], a
            pop af
            ld b, $40
            call b_mul
            ld a, [BZ + $1A]
            add low(B_CH)
            ld [BZ + $70], a
            ld a, [BZ + $1B]
            adc high(B_CH)
            ld [BZ + $71], a
            %LDZ $70, 1
            and $C0
            jr nz, .r
            inc hl
            ld a, [hl]
            and 1
            jr nz, .r
            ld a, [BZ + $26]
            ld b, a
            xor a
            call b_setbit
            ld c, a
            ld a, [$DEC1]
            inc a
            add low($DEB8)
            ld l, a
            ld h, high($DEB8)
            ld [hl], c
            ld hl, $D574
            inc [hl]
            ret

; ---- $BDC5 check if the target (A = 0) / attacker (A = 1) at [BZ+$24] is dead
fe_BDC5:    push af
            ld c, $80
            %LDZ $24, $2C
            bit 7, a
            jr z, .ch
            ld c, $E0
.ch:        and 7
            add a
            ld e, a
            pop af
            and a
            ld a, e
            jr nz, .att
            add low(BZ + $E0)
            jr .t
.att:       add low(BZ + $F0)
.t:         ld l, a
            ld h, high(BZ)
            push hl
            ld a, [hl]
            and c
            jr z, .hp
            %PZ $24, 3                      ; (dead by status: hp 0; FF3's BEQ after it tests
            xor a                           ;   its INY, so it goes on to the hp test below
            ld [hl+], a                     ;   and sets the dead bit too)
            ld [hl], a
.hp:        %PZ $24, 3
            ld a, [hl+]
            or [hl]
            pop hl
            ret nz
            set 7, [hl]
            ret

; ---- $BE43 apply magic status
fe_BE43:    ld a, [BZ + $7C]
            and a
            ret z
            ld a, [$D403]
            and a
            ret z
            %LDZ $70, $24
            ld hl, $D403
            and [hl]
            ret nz
            ld a, [BZ + $7C]
            ld [BZ + $18], a
            ld a, $64
            ld [BZ + $1A], a
            xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            call b_mul16
            ld a, [BZ + $38]
            ld [BZ + $1A], a
            ld a, [BZ + $1C]
            ld [BZ + $18], a
            ld a, [BZ + $1D]
            ld [BZ + $19], a
            xor a
            ld [BZ + $1B], a
            call b_div16
            ld a, [BZ + $1C]
            ld [BZ + $25], a
            ld a, [BZ + $7C]
            ld [BZ + $24], a
            call fe_BB28
            and a
            ret z
            ld a, [$D403]
            ld [BZ + $24], a
            jp fe_BBF3

; (the reflectable spells: one bit each, from the ROM at build time: ROMDATA in build.py)
refl_bits:  ds 11

section wram, $C501
fe_x:       ds 1
