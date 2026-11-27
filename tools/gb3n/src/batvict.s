; FF3's poison damage (35/BA41), battle victory (35/BB49-35/BFF1) and the status for display
; (34/9D06) as native code. FF3's message display ($8FF7), battle graphics ($FA0E) and animations
; ($8411) are hooks into our battle screen: bat_script, bat_gfx, bat_anim.

section bank B_BAT2, $6800
; ---- $BA41 do poison damage
fe_BA41:    ld hl, B_BUF
            ld b, $20
            ld a, $FF
.z:         ld [hl+], a
            dec b
            jr nz, .z
            xor a
            ld [BZ + $64], a
            ld a, 8
            ld [BZ + $24], a
            ld a, low(B_CH)
            ld [BZ + $28], a
            ld a, high(B_CH)
            ld [BZ + $29], a
.c:         call fe_BADC
            call .nx
            ld a, [BZ + $24]
            cp $0C
            jr nz, .c
            call fe_9D06
            xor a
            ld [BZ + $24], a
            ld a, low(B_MO)
            ld [BZ + $28], a
            ld a, high(B_MO)
            ld [BZ + $29], a
.m:         call fe_BADC
            ld a, [BZ + $24]
            ld e, a
            ld d, 0
            push de
            %LDZ $28, 1
            pop de
            ld hl, $DEC4
            add hl, de
            ld [hl], a
            call .nx
            ld a, [BZ + $24]
            cp 8
            jr nz, .m
            ld a, [BZ + $64]
            and a
            ret z
            ld hl, B_BUF
            ld de, $DE4F
            ld b, $20
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            ld a, $80
            ld [$DE98], a
            ld [$DE99], a
            srl a
            ld [$DE9A], a
            ld a, 5
            ld [$D8D5], a
            ld a, $41                       ; "Damaged by poison"
            ld [$D8DA], a
            ld a, $17
            ld [$DEC2], a
            call bat_script
            ld a, $16
            ld [$DEC2], a
            call bat_anim
            jp fe_A458
.nx:        ld hl, BZ + $28
            ld a, [hl]
            add $40
            ld [hl+], a
            ld a, [hl]
            adc 0
            ld [hl], a
            ld hl, BZ + $24
            inc [hl]
            ret
; $BADC calculate poison damage for the record at [BZ+$28] (max hp / 16)
fe_BADC:    %LDZ $28, 1
            ld c, a
            and 2
            jr z, fe_BB3F
            ld a, c
            and $C0
            jr nz, fe_BB3F
            ld hl, BZ + $64
            inc [hl]
            ld a, [BZ + $24]
            add a
            ld [BZ + $62], a
            %PZ $28, 5
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            ld b, 4
.s:         srl d
            rr e
            dec b
            jr nz, .s
            ld a, e
            ld [BZ + $26], a
            ld a, d
            ld [BZ + $27], a
            ld a, [BZ + $62]
            ld l, a
            ld h, high(B_BUF)
            ld [hl], e
            inc l
            ld [hl], d
            %PZ $28, 3
            ld a, [hl]
            sub e
            ld [hl+], a
            ld a, [hl]
            sbc d
            ld [hl], a
            jr nc, fe_BB3F
fe_BB2B:    %PZ $28, 3
            xor a
            ld [hl+], a
            ld [hl], a
            %PZ $28, 1
            ld a, [hl]
            or $80
            and $FE
            ld [hl], a
            ret
fe_BB3F:    %PZ $28, 3
            ld a, [hl+]
            or [hl]
            jr z, fe_BB2B
            ret

; ---- $BB49 battle victory
fe_BB49:    ld a, $0F
            call bat_gfx
            xor a
            ld [$D570], a
            ld [$D571], a
            ld [BZ + $52], a
            ld b, 0                         ; the living characters
.l:         call b_choff
            inc a
            ld c, a
            call p5b
            ld a, [hl]
            and $C0
            jr nz, .d
            inc b
.d:         ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .l
            ld a, b
            ld [BZ + $53], a
            xor a
            ld [BZ + $52], a
            ld hl, B_BUF
            ld b, $34
.z:         ld [hl+], a
            dec b
            jr nz, .z
            ld a, $FF
            ld b, $80 - $34
.f:         ld [hl+], a
            dec b
            jr nz, .f
.type:      ld a, [$D570]                   ; each monster type
            ld e, a
            ld d, 0
            ld hl, $DDD3
            add hl, de
            ld a, [hl]
            ld [BZ + $2C], a
            and a
            jp z, .ntype
            ld hl, $DD6B
            add hl, de
            ld a, [hl]
            ld [BZ + $32], a
            ld [BZ + $18], a
            ld a, 1                         ; experience id (10/9C80)
            ld [BZ + $1A], a
            ld a, $80
            ld [BZ + $20], a
            ld a, $9C
            ld [BZ + $21], a
            ld b, 0
            ld a, B_EVENTS
            call b_ldarr
            ld a, [B_BUF]
            ld [BZ + $18], a
            ld a, 2                         ; experience (10/9D80)
            ld [BZ + $1A], a
            ld a, $80
            ld [BZ + $20], a
            ld a, $9D
            ld [BZ + $21], a
            ld b, 1
            ld a, B_EVENTS
            call b_ldarr
            ld a, [BZ + $32]                ; properties (30/8000)
            ld [BZ + $18], a
            ld a, $10
            ld [BZ + $1A], a
            xor a
            ld [BZ + $20], a
            ld a, $80
            ld [BZ + $21], a
            ld b, 3
            ld a, B_BDAT
            call b_ldarr
            ld a, [$D412]                   ; items (10/9B80)
            and $1F
            ld [BZ + $18], a
            ld a, 8
            ld [BZ + $1A], a
            ld a, $80
            ld [BZ + $20], a
            ld a, $9B
            ld [BZ + $21], a
            ld b, $13
            ld a, B_EVENTS
            call b_ldarr
            ld a, [BZ + $32]                ; gil (30/9C58)
            ld [BZ + $18], a
            ld a, 2
            ld [BZ + $1A], a
            ld a, $58
            ld [BZ + $20], a
            ld a, $9C
            ld [BZ + $21], a
            ld b, $1B
            ld a, B_BDAT
            call b_ldarr
            ld a, [BZ + $32]                ; capacity (39/B2AE)
            ld [BZ + $18], a
            ld a, 1
            ld [BZ + $1A], a
            ld a, $AE
            ld [BZ + $20], a
            ld a, $B2
            ld [BZ + $21], a
            ld b, $1D
            ld a, B_BDAT3
            call b_ldarr
            ld a, [$D401]                   ; experience / living characters
            ld [BZ + $18], a
            ld a, [$D402]
            ld [BZ + $19], a
            ld a, [BZ + $53]
            ld [BZ + $1A], a
            xor a
            ld [BZ + $1B], a
            call b_div16
            ld a, [BZ + $1C]
            ld [$D401], a
            ld a, [BZ + $1D]
            ld [$D402], a
.each:      ld hl, $D424                    ; (per monster of the type) experience, gil
            ld a, [$D401]
            add [hl]
            ld [hl+], a
            ld a, [$D402]
            adc [hl]
            ld [hl+], a
            ld a, 0
            adc [hl]
            ld [hl+], a
            ld a, [$D41B]
            add [hl]
            ld [hl+], a
            ld a, [$D41C]
            adc [hl]
            ld [hl+], a
            ld a, 0
            adc [hl]
            ld [hl], a
            ld a, [$D412]                   ; a drop
            swap a
            srl a
            and 7
            ld [BZ + $2E], a
            ld a, 6
            call b_rnd
            ld hl, BZ + $2E
            cp [hl]
            jr nc, .cp
            ld a, $FF
            call b_rnd
            ld c, 0
            cp $30
            jr c, .it
            inc c
            cp $60
            jr c, .it
            inc c
            cp $90
            jr c, .it
            inc c
            cp $C0
            jr c, .it
            inc c
            cp $D8
            jr c, .it
            inc c
            cp $F0
            jr c, .it
            inc c
            cp $FC
            jr c, .it
            inc c
.it:        ld b, 0
            ld hl, $D413
            add hl, bc
            ld a, [hl]
            and a
            jr z, .cp
            call fe_BFB3
            jr nc, .cp
            ld c, a
            ld a, [$D571]
            cp $30
            jr nc, .cp
            ld e, a
            ld d, 0
            ld hl, $D434
            add hl, de
            ld [hl], c
            ld hl, $D571
            inc [hl]
.cp:        ld a, [$D42A]                   ; capacity
            ld hl, $D41D
            add [hl]
            ld [$D42A], a
            ld hl, BZ + $2C
            dec [hl]
            jp nz, .each
.ntype:     ld hl, $D570
            inc [hl]
            ld a, [hl]
            cp 4
            jp nz, .type
            ld hl, $D01C                    ; gil
            ld a, [$D427]
            add [hl]
            ld [hl+], a
            ld a, [$D428]
            adc [hl]
            ld [hl+], a
            ld a, [$D429]
            adc [hl]
            ld [hl], a
            ld a, [$D42A]                   ; capacity / 4 + 1 (max 255)
            and a
            jr z, .msg
            srl a
            srl a
            inc a
            ld [$D42A], a
            ld hl, $D01B
            add [hl]
            jr nc, .cps
            ld a, $FF
.cps:       ld [hl], a
.msg:       ld a, 2                         ; the messages: gil, capacity, experience, items
            ld [$D8D5], a
            ld [$DEC2], a
            ld a, $2D
            ld [$D8DA], a
            ld a, [$D427]
            ld [$D8E4], a
            ld a, [$D428]
            ld [$D8E5], a
            call bat_script
            ld a, $2E
            ld [$D8DA], a
            ld a, [$D42A]
            ld [$D8E4], a
            xor a
            ld [$D8E5], a
            call bat_script
            ld a, $40
            ld [$D8DA], a
            ld a, [$D424]
            ld [$D8E4], a
            ld a, [$D425]
            ld [$D8E5], a
            call bat_script
            xor a
            ld [BZ + $3C], a
.drop:      ld a, [BZ + $3C]
            ld e, a
            ld d, 0
            ld hl, $D434
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, fe_BD9B
            ld [$D8E4], a
            ld a, $29                       ; "Found "
            ld [$D8DA], a
            call bat_script
            ld hl, BZ + $3C
            inc [hl]
            jr .drop
; each character: job experience and level, experience and level
fe_BD9B:    call b_choff
            inc a
            ld c, a
            call p5b
            ld a, [hl]
            and $C0
            jp nz, fe_BF70
            xor a
            ld [BZ + $1E], a
            ld [BZ + $1F], a
            ld [BZ + $20], a
            ld a, [BZ + $52]
            add a
            add a
            ld [BZ + $1C], a
            ld a, $35
            call b_addoff
            ld c, a
            call p5b
            ld a, [hl]
            ld [BZ + $22], a
.cm:        xor a                           ; job experience: uses x multiplier (2 bits)
            ld [BZ + $23], a
            ld hl, BZ + $22
            sla [hl]
            inc l
            rl [hl]
            dec l
            sla [hl]
            inc l
            rl [hl]
            ld a, [BZ + $1C]
            ld e, a
            ld d, 0
            ld hl, $D8F0
            add hl, de
            ld a, [BZ + $23]
            ld b, a
            ld a, [hl]
            call b_mul
            ld hl, BZ + $1E
            ld a, [BZ + $1A]
            add [hl]
            ld [hl+], a
            ld a, [BZ + $1B]
            adc [hl]
            ld [hl], a
            ld hl, BZ + $1C
            inc [hl]
            ld hl, BZ + $20
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .cm
            ld hl, BZ + $1E                 ; x 4, added to the job experience
            sla [hl]
            inc l
            rl [hl]
            dec l
            sla [hl]
            inc l
            rl [hl]
            ld a, $11
            call b_addoff
            ld c, a
            call p57
            ld a, [BZ + $1E]
            add [hl]
            ld [BZ + $1E], a
            ld [hl], a
            ld a, [BZ + $1F]
            adc 0
            ld [BZ + $1F], a
            ld a, [BZ + $1E]
            sub $64
            ld a, [BZ + $1F]
            sbc 0
            jr c, .exp
            ld [hl], 0                      ; 100: a job level
            dec hl
            ld a, [hl]
            inc a
            cp $63
            jr nc, .exp
            ld [hl], a
            ld a, 4
            ld [$D8D5], a
            ld a, [BZ + $52]
            ld [$D8D6], a
            ld a, $22                       ; "Skill up!"
            ld [$D8DA], a
            call bat_script
.exp:       ld a, [BZ + $5F]                ; experience (max 9,999,999)
            add 3
            ld c, a
            call p57
            ld a, [$D424]
            add [hl]
            ld [BZ + $2F], a
            ld [hl+], a
            ld a, [$D425]
            adc [hl]
            ld [BZ + $30], a
            ld [hl+], a
            ld a, [$D426]
            adc [hl]
            ld [BZ + $31], a
            ld [hl-], a
            dec hl
            ccf                             ; (FF3: SBC with the carry the add left)
            ld a, [hl+]
            sbc $7F
            ld a, [hl+]
            sbc $96
            ld a, [hl]
            sbc $98
            jr c, .lv
            ld a, $98
            ld [hl-], a
            ld [BZ + $31], a
            ld a, $96
            ld [hl-], a
            ld [BZ + $30], a
            ld a, $7F
            ld [hl], a
            ld [BZ + $2F], a
.lv:        ld a, [BZ + $5F]                ; the next level's experience (39/A0B0)
            inc a
            ld c, a
            call p57
            ld a, [hl]
            ld [BZ + $18], a
            ld a, 3
            ld [BZ + $1A], a
            ld a, $B0
            ld [BZ + $20], a
            ld a, $A0
            ld [BZ + $21], a
            ld b, $1E
            ld a, B_BDAT3
            call b_ldarr
            ld a, [$D41E]
            ld c, a
            ld a, [BZ + $2F]
            sub c
            ld a, [$D41F]
            ld c, a
            ld a, [BZ + $30]
            sbc c
            ld a, [$D420]
            ld c, a
            ld a, [BZ + $31]
            sbc c
            jp c, fe_BF70
            ld a, [BZ + $5F]                ; a level up
            inc a
            ld c, a
            call p57
            ld a, [hl]
            ld [BZ + $32], a
            inc a
            cp $63
            jp nc, fe_BF70
            ld [hl], a
            ld a, $14                       ; max hp + vitality x (1..1.5) + level x 2
            call b_addoff
            ld c, a
            call p57
            ld a, [hl]
            ld [BZ + $24], a
            srl a
            call b_rnd
            ld hl, BZ + $24
            add [hl]
            ld [hl], a
            ld a, [BZ + $5F]
            inc a
            ld c, a
            call p57
            ld a, [hl]
            add a
            ld hl, BZ + $24
            add [hl]
            ld [hl], a
            ld a, $0E
            call b_addoff
            ld c, a
            call p57
            ld a, [BZ + $24]
            add [hl]
            ld [hl+], a
            ld a, 0
            adc [hl]
            ld [hl-], a
            ld a, [hl+]
            sub $0F
            ld a, [hl]
            sbc $27
            jr c, .st
            ld [hl], $27
            dec hl
            ld [hl], $0F
.st:        ld a, [BZ + $5F]                ; stat bonuses (39/A1D6 + job x 196 + level x 2)
            ld c, a
            call p57
            ld a, [hl]
            ld [BZ + $18], a
            ld a, $C4
            ld [BZ + $1A], a
            xor a
            ld [BZ + $19], a
            ld [BZ + $1B], a
            call b_mul16
            ld a, [BZ + $1C]
            add $D6
            ld [BZ + $20], a
            ld a, [BZ + $1D]
            adc $A1
            ld [BZ + $21], a
            ld a, [BZ + $32]
            ld [BZ + $18], a
            ld a, 2
            ld [BZ + $1A], a
            ld b, $21
            ld a, B_BDAT3
            call b_ldarr
            ld a, [$D421]
            call fe_BF7C
            ld a, $31                       ; mp: one more for each bit (max 99)
            call b_addoff
            ld c, a
            call p57
            ld b, 8
.mp:        ld a, [$D422]
            srl a
            ld [$D422], a
            jr nc, .mn
            ld a, [hl]
            inc a
            cp $64
            jr nc, .mn
            ld [hl], a
.mn:        inc hl
            inc hl
            dec b
            jr nz, .mp
            ld a, 4
            ld [$D8D5], a
            ld a, [BZ + $52]
            ld [$D8D6], a
            ld a, $20                       ; "Level up!"
            ld [$D8DA], a
            call bat_script
fe_BF70:    ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jp nz, fe_BD9B
            ret

; $BF7C add level up stat bonuses: A = 5 stat bits + the amount (low 3 bits)
fe_BF7C:    ld [BZ + $19], a
            and 7
            ld [BZ + $18], a
            ld a, $12
            call b_addoff
            ld c, a
            call p57
            ld b, 5
.s:         ld a, [BZ + $19]
            add a
            ld [BZ + $19], a
            jr nc, .n
            ld a, [BZ + $18]                ; the base stat and (+5) the stat now, max 99
            add [hl]
            cp $64
            jr c, .a
            ld a, $63
.a:         ld [hl], a
            push hl
            ld de, 5
            add hl, de
            ld a, [BZ + $18]
            add [hl]
            cp $64
            jr c, .b
            ld a, $63
.b:         ld [hl], a
            pop hl
.n:         inc hl
            dec b
            jr nz, .s
            ret

; $BFB3 give item A: carry set if it fitted (FF3: a full stack goes on looking for a 0 from its
; count's place, X wrapping in the page)
fe_BFB3:    ld [BZ + $18], a
            ld c, a
            ld b, 0
.f:         call inv_x
            ld a, [hl+]
            cp c
            jr nz, .nf
            inc b
            ld a, [hl]
            inc a
            cp $64
            jr nc, .e
            ld [hl], a
            jr .ok
.nf:        inc b
            inc b
            ld a, b
            cp $40
            jr nz, .f
            ld b, 0
.e:         call inv_x
            ld a, [hl]
            and a
            jr nz, .ne
            ld [hl], c
            inc b
            call inv_x
            inc [hl]
.ok:        ld a, [BZ + $18]
            scf
            ret
.ne:        inc b
            inc b
            ld a, b
            cp $40
            jr nz, .e
            ld a, [BZ + $18]
            and a
            ret
inv_x:      ld a, b                         ; HL = $60C0 + X
            add low($D0C0)
            ld l, a
            ld a, high($D0C0)
            adc 0
            ld h, a
            ret

; ---- $9D06 update character status for display ($78BB / $78BC, $78C4)
fe_9D06:    xor a
            ld [BZ + $52], a
.c:         call b_choff
            call fe_9D1D
            ld hl, BZ + $52
            inc [hl]
            ld a, [hl]
            cp 4
            jr nz, .c
            xor a
            ld [BZ + $52], a
            ret
fe_9D1D:    ld a, [BZ + $5F]
            inc a
            ld c, a
            call p5b
            ld a, [hl+]
            ld [BZ + $1C], a
            push af
            and $C0
            ld [BZ + $1A], a
            ld a, [hl]
            ld [BZ + $1D], a
            and $E0
            srl a
            srl a
            ld hl, BZ + $1A
            or [hl]
            ld [hl], a
            xor a
            ld [BZ + $1B], a
            pop af
            and $3F
            ld b, 3
.r:         srl a
            ld hl, BZ + $1B
            rr [hl]
            dec b
            jr nz, .r
            ld hl, BZ + $1A
            or [hl]
            ld [hl], a
            ld a, [BZ + $52]
            add a
            ld e, a
            ld d, 0
            ld hl, $D8BB
            add hl, de
            ld a, [BZ + $1A]
            ld [hl+], a
            ld a, [BZ + $1B]
            ld [hl], a
            ld a, [BZ + $1C]
            and $C0
            jr nz, .none
            ld a, [BZ + $1C]
            ld c, a
            and 7
            ld b, a
            ld a, c
            and $10
            srl a
            or b
            add a
            ld b, a
            ld a, [BZ + $1D]
            ld c, a
            and $E0
            or b
            ld b, a
            ld a, c
            and 6
            jr z, .s
            set 0, b
.s:         ld a, b
            ld [BZ + $1C], a
            ld c, 0
            and a
            jr nz, .f
.none:      ld c, $FF
            jr .st
.f:         add a
            jr c, .st
            inc c
            ld b, a
            ld a, c
            cp 8
            ld a, b
            jr nz, .f
            ret
.st:        ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, $D8C4
            add hl, de
            ld [hl], c
            ret

; ---- hooks into the battle screen (test builds: nothing)
bat_script: ret
bat_gfx:    ret
bat_anim:   ret
