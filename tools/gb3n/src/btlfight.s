; ---- 35/A104 action $04 fight and 30/9E8A + 31/A000 battle algorithm $03: do fight effect, as
; FF3: hits from hit % (blind / back row halve it) against evade (blind halves it; toad, mini,
; jumping / building up: none), the element multiplier (weak 4, resisted 1, else 2: halved in
; the damage), crits, attack x (1..1.5) x multiplier / 2 + crit bonus - defence, x hits / targets,
; capped at 9999, jump / buildup multipliers, drain, hp, weapon statuses; two hands one by one.

; 35/A104
act_fight:  call atk_flags
            bit 7, a
            jp z, .chr
            ld c, $2C                       ; a monster: a knight covers a near fatal member
            ld a, $70
            call zpy
            ld a, [hl]
            and 7
            ld [BZ + $18], a
            call bitmask
            ld b, a
            ld a, [W7 + $7CEC]
            and b
            jp z, .eff
            ld c, 1
            ld a, $70
            call zpy
            ld a, [hl+]
            and $C0
            jp nz, .eff
            ld a, [hl]
            and $21
            jp nz, .eff
            xor a
            ld [BZ + $52], a
            ld [BZ + $22], a
.k:         ld a, [BZ + $52]                ; knights able to act: their hp at $1A + 2 m
            add a, a
            ld [BZ + $19], a
            ld e, a
            ld d, 0
            ld hl, BZ + $24
            add hl, de
            ld [hl], a
            call chr_ofs
            ld c, a
            ld a, $57
            call zpy
            ld a, [hl]
            cp 7
            jr nz, .k0
            call chr_ofs
            inc a
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl+]
            and $C1
            jr nz, .k0
            ld a, [hl+]
            and $E0
            jr nz, .k0
            ld a, [hl+]
            ld b, [hl]
            ld c, a
            ld a, [BZ + $19]
            ld e, a
            ld d, 0
            ld hl, BZ + $1A
            add hl, de
            ld [hl], c
            inc hl
            ld [hl], b
            ld hl, BZ + $22
            inc [hl]
            jr .k1
.k0:        ld a, [BZ + $19]
            ld e, a
            ld d, 0
            ld hl, BZ + $1A
            add hl, de
            xor a
            ld [hl+], a
            ld [hl], a
.k1:        ld a, [BZ + $52]
            inc a
            ld [BZ + $52], a
            cp 4
            jr nz, .k
            ld a, [BZ + $22]
            and a
            jp z, .eff
            call high_hp                    ; -> $52, $5F
            ld a, [BZ + $52]
            call bitmask
            ld [W7 + $7E99], a
            ld [W7 + $7EDF], a
            ld a, [BZ + $18]
            call bitmask
            ld [W7 + $7EE0], a
            ld a, [BZ + $5F]                ; target = the knight
            ld e, a
            ld d, 0
            ld hl, W7 + $7575
            add hl, de
            ld a, $70
            call zpset
            ld c, $33
            ld a, $70
            call zpy
            ld a, [hl]
            ld [W7 + $7CEA], a
            and $FE
            ld [hl], a
            jp .eff
.chr:       ld c, 1                         ; a member: the weapons for the animation
            push af
            ld a, $6E
            call zpy
            pop af
            ld a, [hl]
            and $28
            jr z, .w
            xor a
            ld [W7 + $7E1F], a
            ld [W7 + $7E20], a
            jp .eff
.w:         call atk_flags
            and 7
            ld [BZ + $52], a
            call chr_ofs
            add a, 3
            ld c, a
            ld a, $59
            call zpy
            ld a, [hl+]
            ld [W7 + $7E1F], a
            inc hl
            ld a, [hl]
            ld [W7 + $7E20], a
            ld a, [W7 + $7E1F]
            and a
            jr z, .w1
            cp $58
            jr c, .w2
            xor a
            ld [W7 + $7E1F], a
            jr .w2
.w1:        ld a, [W7 + $7E20]
            cp $4A
            jr c, .eff
            xor a
            ld [W7 + $7E20], a
            jr .eff
.w2:        ld a, [W7 + $7E20]
            and a
            jr z, .w3
            cp $58
            jr c, .eff
            xor a
            ld [W7 + $7E20], a
            jr .eff
.w3:        ld a, [W7 + $7E1F]
            cp $4A
            jr c, .eff
            xor a
            ld [W7 + $7E1F], a
.eff:       call fight_eff
            ld a, [W7 + $7EDF]
            and a
            jr z, .h
            ld a, [W7 + $78EE]              ; "Knight guards ally", the row back
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            ld [hl], $52
            ld c, $33
            ld a, $70
            call zpy
            ld a, [W7 + $7CEA]
            ld [hl], a
.h:         ld a, [BZ + $7C]                ; hits (32 at most shown)
            ld b, a
            ld a, [BZ + $7D]
            add a, b
            cp $21
            jr c, .h1
            ld a, $20
.h1:        ld [W7 + $78D7], a
            and a
            jp z, .dead
            ld a, [BZ + $64]                ; the target's status 2 turn counter
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl+]
            and $80
            jp nz, .dead
            ld a, [hl]
            and $18
            jp z, .dead
            sub 8
            and $18
            jr nz, .tc
            ld a, [hl]                      ; (the counter ran out: the status removed)
            ld [btl_tmp], a
            and 7
            ld [hl], a
            push hl
            push af
            ld c, 2
            ld a, $70
            call zpy
            pop af
            ld [hl], a
            call atk_flags
            and $87
            ld b, a
            call tgt_flags
            and $87
            cp b
            pop hl
            jr nz, .tn
            ld a, [hl]                      ; (self: FF3 copies it to $F0 + the target's x)
            ld de, $10
            add hl, de
            ld [hl], a
            push af
            ld c, 2
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
.tn:        ld a, [btl_tmp]
            ld b, 0
.tb:        add a, a
            jr c, .tb1
            inc b
            jr .tb
.tb1:       ld a, b
            add a, 2
            ld [W7 + $78D9], a
            call tgt_flags
            and $E7
            ld [hl], a
            ld c, $2E
            ld a, $70
            call zpy
            ld [hl], 0
            jr .dead
.tc:        ld a, [hl]
            sub 8
            ld [hl], a
            push af
            ld c, 2
            ld a, $70
            call zpy
            pop af
            ld [hl], a
.dead:      ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl]
            and $80
            jr z, .s
            ld a, [W7 + $78EE]              ; "Slain" / "Defeated"
            ld e, a
            ld hl, W7 + $78DA
            add hl, de
            ld [hl], $1A
            push hl
            ld c, $2C
            ld a, $70
            call zpy
            ld a, [hl]
            pop hl
            bit 7, a
            jr z, .s
            inc [hl]
.s:         xor a                           ; action script $00: fight
            ld [W7 + $78D5], a
            ld [BZ + $24], a
            call atk_flags
            bit 7, a
            ret nz
            and 7                           ; arrows / shuriken used up
            ld [BZ + $52], a
            call chr_ofs
            add a, $31
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            and 4
            jr z, .a1
            ld a, 4
            call ammo_dec
.a1:        call chr_ofs
            add a, $32
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            and 4
            jr z, .a2
            ld a, 6
            call ammo_dec
.a2:        ld a, [BZ + $5F]
            add a, 3
            ld c, a
            ld a, $59
            call zpy
            ld a, [hl]
            cp $41
            jr nz, .a3
            ld a, 4
            call ammo_dec
.a3:        ld a, [BZ + $5F]
            add a, 5
            ld c, a
            ld a, $59
            call zpy
            ld a, [hl]
            cp $41
            jr nz, .a4
            ld a, 6
            call ammo_dec
.a4:        ld a, [BZ + $24]
            and a
            ret z
            jp beq_update

; 35/A30F find highest hp: the four values at $1A + 2 m (with their ids at $24 + 2 m) -> the
; largest first; $52 = its member, $5F its offset
high_hp:    ld c, 2
.l:         ld a, [BZ + $1A]                ; [0] - [X]: borrow -> swap
            ld e, a
            ld a, [BZ + $1B]
            ld d, a
            ld b, 0
            ld hl, BZ + $1A
            add hl, bc
            ld a, e
            sub [hl]
            inc hl
            ld a, d
            sbc [hl]
            jr nc, .n
            dec hl
            ld a, [hl]                      ; swap the values
            ld [BZ + $1A], a
            ld [hl], e
            inc hl
            ld a, [hl]
            ld [BZ + $1B], a
            ld [hl], d
            ld hl, BZ + $24                 ; and the ids
            add hl, bc
            ld a, [hl]
            ld e, a
            ld a, [BZ + $24]
            ld [hl], a
            ld a, e
            ld [BZ + $24], a
.n:         inc c
            inc c
            ld a, c
            cp 8
            jr nz, .l
            ld a, [BZ + $24]
            srl a
            ld [BZ + $52], a
            jp chr_ofs

; 35/A353 decrement arrow / shuriken quantity (A = 4 right / 6 left): none left -> removed
ammo_dec:   ld b, a
            ld a, [BZ + $5F]
            add a, b
            ld c, a
            ld a, $59
            call zpy
            dec [hl]
            ret nz
            dec hl
            ld [hl], 0
            ld hl, BZ + $24
            inc [hl]
            ret

; 31/A2BA init attacker and target: slots $66 / $68, x 2 $62 / $64, status buffers $F0 / $E0
init_at:    call atk_flags
            and 7
            ld [BZ + $66], a
            add a, a
            ld [BZ + $62], a
            ld c, $2C
            ld a, $70
            call zpy
            ld a, [hl]
            and 7
            ld [BZ + $68], a
            add a, a
            ld [BZ + $64], a
            ld c, 1
            ld a, $6E
            call zpy
            ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld a, [hl+]
            ld b, [hl]
            ld hl, BZ + $F0
            add hl, de
            ld [hl+], a
            ld [hl], b
            ld c, 1
            ld a, $70
            call zpy
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld a, [hl+]
            ld b, [hl]
            ld hl, BZ + $E0
            add hl, de
            ld [hl+], a
            ld [hl], b
            ret

; 31/A300 choose random target: A = highest index, [$22] = the records' base; $69 if none
rnd_target: ld [BZ + $4A], a
            ld a, [BZ + $1A]
            push af
            xor a
            ld hl, BZ + $65
            ld b, 5
.c:         ld [hl+], a
            dec b
            jr nz, .c
.r:         ld a, [BZ + $4A]
            call rnd_0a
            ld [BZ + $30], a
            rrca
            rrca
            ld l, a
            and $C0
            ld e, a
            ld a, l
            and 3
            ld d, a
            ld [BZ + $1B], a
            ld a, [BZ + $22]
            ld l, a
            ld a, [BZ + $23]
            ld h, a
            add hl, de
            ld a, $70
            call zpset
            ld c, 1
            ld a, $70
            call zpy
            ld a, [hl+]
            and $C0
            jr nz, .x
            ld a, [hl]
            and 1
            jr z, .ok
.x:         ld a, [BZ + $30]
            ld e, a
            ld d, 0
            ld hl, BZ + $65
            add hl, de
            ld [hl], 1
            ld a, [BZ + $65]
            ld hl, BZ + $66
            add a, [hl]
            inc hl
            add a, [hl]
            inc hl
            add a, [hl]
            cp 4
            jr nz, .r
            ld hl, BZ + $69
            inc [hl]
            jr .end
.ok:        call tgt_flags
            and $87
            ld [W7 + $78D8], a
            ld a, [BZ + $30]
            call bitmask
            push af
            ld c, $2F
            ld a, $6E
            call zpy
            pop af
            ld [hl], a
            ld [W7 + $7E99], a
.end:       pop af
            ld [BZ + $1A], a
            ret

; 31/A368 add to net damage ($6A += $78, capped at 9999)
net_add:    ld a, [BZ + $6A]
            ld l, a
            ld a, [BZ + $6B]
            ld h, a
            ld a, [BZ + $78]
            ld e, a
            ld a, [BZ + $79]
            ld d, a
            add hl, de
            ld a, l
            sub $0F
            ld a, h
            sbc $27
            jr c, .s
            ld hl, 9999
.s:         ld a, l
            ld [BZ + $6A], a
            ld a, h
            ld [BZ + $6B], a
            ret

; 31/A397 back row penalty for member A: carry = no penalty (an arrow, a short-range weapon
; pair rules of FF3: $3F-$41 weapons ignore the back row)
back_row:   and 7
            ld [BZ + $52], a
            ld c, $31
            ld a, $6E
            call zpy
            ld a, [hl+]
            or [hl]
            and 8
            jr nz, .no                      ; (an arrow: FF3 tests the harp bit $08 here)
            call chr_ofs
            add a, 3
            ld c, a
            ld a, $59
            call zpy
            ld a, [hl+]
            ld [BZ + $18], a
            inc hl
            ld a, [hl]
            ld [BZ + $19], a
            ld b, a
            ld a, [BZ + $18]
            or b
            jr z, .pen
            ld a, [W7 + $741E]
            and a
            jr nz, .two
            ld a, [BZ + $18]
            and a
            jr z, .left
            cp $57
            jr nc, .left
            jr .rng
.left:      ld a, [BZ + $19]
.rng:       cp $42
            jr nc, .pen
            cp $3F
            jr c, .pen
            jr .no
.two:       ld a, [W7 + $741F]
            cp 2
            ld a, [BZ + $18]
            jr z, .rng
            ld a, [BZ + $19]
            jr .rng
.pen:       and a                           ; (carry clear: the penalty)
            ret
.no:        scf
            ret

; 31/BB28 get number of hits: $24 tries at hit % $25 (random 0..99 < $25) -> A = $30
hit_count:  xor a
            ld [BZ + $30], a
            ld a, [BZ + $24]
            and a
            jr z, .x
.l:         ld a, 99
            call rnd_0a
            ld b, a
            ld a, [BZ + $25]
            ld c, a
            ld a, b
            cp c
            jr nc, .n
            ld hl, BZ + $30
            inc [hl]
.n:         ld hl, BZ + $24
            dec [hl]
            jr nz, .l
.x:         ld a, [BZ + $30]
            ret

; 31/BB44 calculate damage -> $1C:$1D
calc_dmg:   ld a, [BZ + $2B]                ; random (0..attack / 2) + attack
            rra
            ld a, [BZ + $25]
            rra
            call rnd_0a
            ld b, a
            ld a, [BZ + $25]
            add a, b
            ld [BZ + $18], a
            ld a, [BZ + $2B]
            adc a, 0
            ld [BZ + $19], a
            xor a
            ld [BZ + $1B], a
            ld a, [BZ + $27]
            srl a
            jr nz, .m
            ld a, [BZ + $19]                ; (multiplier 1: halved)
            srl a
            ld [BZ + $1D], a
            ld a, [BZ + $18]
            rra
            ld [BZ + $1C], a
            jr .c
.m:         ld [BZ + $1A], a
            call bmul16
.c:         ld a, [BZ + $1C]
            ld [BZ + $30], a
            ld a, [BZ + $1D]
            ld [BZ + $31], a
            ld a, [BZ + $28]                ; + crit bonus x crit flag
            ld b, a
            ld a, [BZ + $29]
            call bmul8
            ld e, a
            ld d, b
            ld a, [BZ + $30]
            ld l, a
            ld a, [BZ + $31]
            ld h, a
            add hl, de
            ld a, l
            ld [BZ + $18], a
            ld a, h
            ld [BZ + $19], a
            call atk_flags                  ; - defence (unless a member hits a member)
            bit 7, a
            jr nz, .df
            call tgt_flags
            bit 7, a
            jr z, .h
.df:        ld a, [BZ + $26]
            ld b, a
            ld a, [BZ + $18]
            sub b
            ld [BZ + $18], a
            ld a, [BZ + $19]
            sbc 0
            ld [BZ + $19], a
            jr nc, .h
            xor a
            ld [BZ + $18], a
            ld [BZ + $19], a
.h:         xor a                           ; x total hits / targets
            ld [BZ + $1B], a
            ld a, [BZ + $7C]
            ld [BZ + $1A], a
            call bmul16
            ld a, [BZ + $1C]
            ld [BZ + $18], a
            ld a, [BZ + $1D]
            ld [BZ + $19], a
            xor a
            ld [BZ + $1B], a
            ld a, [BZ + $2A]
            ld [BZ + $1A], a
            call bdiv16
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

; 31/BBE2 undead (weak to holy): carry, $27 = 2
undead:     ld c, $12
            ld a, $70
            call zpy
            ld a, [hl]
            bit 7, a
            jr z, .n
            ld a, 2
            ld [BZ + $27], a
            scf
            ret
.n:         and a
            ret

; 31/BCD2 subtract damage ($78) from hp at [$24]: carry clear if it reached zero
sub_hp:     ld a, [BZ + $78]
            ld b, a
            ld a, [BZ + $79]
            or b
            jr nz, .s
            scf
            ret
.s:         ld c, 3
            ld a, $24
            call zpy
            ld a, [hl]
            sub b
            ld [hl+], a
            ld a, [BZ + $79]
            ld b, a
            ld a, [hl]
            sbc b
            ld [hl], a
            jr c, .z
            dec hl
            or [hl]
            jr z, .z1
            scf
            ret
.z1:        inc hl
.z:         ld a, [W7 + $7573]
            inc a
            ld [W7 + $7573], a
            xor a
            ld [hl-], a
            ld [hl], a
            and a
            ret

; 31/BD24 restore hp: [$24] hp += $78, capped at max ($78 = what was restored then)
add_hp:     ld c, 3
            ld a, $24
            call zpy
            ld a, [hl]
            ld [BZ + $1A], a
            ld b, a
            ld a, [BZ + $78]
            add a, b
            ld [hl+], a
            ld a, [hl]
            ld [BZ + $1B], a
            ld b, a
            ld a, [BZ + $79]
            adc a, b
            ld [hl+], a
            ld a, [hl+]                     ; max - current: no borrow -> done
            ld [BZ + $18], a
            ld e, a
            ld a, [hl]
            ld [BZ + $19], a
            ld d, a
            dec hl
            dec hl
            dec hl                          ; (current lo)
            ld a, e
            sub [hl]
            inc hl
            ld a, d
            sbc [hl]
            ret nc
            ld a, [BZ + $19]
            ld [hl-], a
            ld a, [BZ + $18]
            ld [hl], a
            ld a, [BZ + $1A]
            ld b, a
            ld a, [hl+]
            sub b
            ld [BZ + $78], a
            ld a, [BZ + $1B]
            ld b, a
            ld a, [hl]
            sbc b
            ld [BZ + $79], a
            ret

; 31/BD67 drain hp to attacker: $26 = 0 / 1 target died / $81 attacker died; $42 inverted
drain:      xor a
            ld [BZ + $26], a
            call undead
            jr nc, .nu
            ld hl, BZ + $42                 ; (undead: the attacker loses it)
            inc [hl]
            call at_ptr
            call sub_hp
            jr c, .u1
            ld a, $81
            ld [BZ + $26], a
.u1:        call .q
            jr .rs
.nu:        call sub_hp
            jr c, .n1
            ld a, 1
            ld [BZ + $26], a
.n1:        call at_ptr
            call .q
.rs:        jp add_hp
.q:         ld c, $2E                       ; (the fight command drains a quarter)
            ld a, $6E
            call zpy
            ld a, [hl]
            cp 4
            ret nz
            ld hl, BZ + $79
            srl [hl]
            dec hl
            rr [hl]
            inc hl
            srl [hl]
            dec hl
            rr [hl]
            ret
; 31/B926 attack ineffective: the target out of the hit mask
atk_ineff:  ld a, [W7 + $7EC1]
            call bitmask
            cpl
            ld b, a
            ld a, [W7 + $7E9B]
            and b
            ld [W7 + $7E9B], a
            ld a, [BZ + $7C]
            ret

; 31/BBF3 apply status $24 (bit 0: status 2) to the target's buffer, with its message
app_status: call tgt_flags
            and 7
            add a, a
            ld e, a
            ld d, 0
            ld a, [BZ + $24]
            and 1
            jr nz, .s2
            ld hl, BZ + $E0                 ; status 1: already as strong -> ineffective
            add hl, de
            ld a, [BZ + $24]
            ld b, a
            ld a, [hl]
            cp b
            jp nc, atk_ineff
            or b
            ld [hl], a
            ld a, b
            ld c, 0
.f:         add a, a
            jr c, .f1
            inc c
            jr .f
.f1:        ld a, c
            cp 2
            jr c, .f2
            add a, 3
.f2:        add a, $0A
            ld [W7 + $78D9], a
            ret
.s2:        ld a, [BZ + $24]
            and $20
            jr z, .s3
            ld a, [W7 + $7ED8]
            bit 7, a
            jp nz, atk_ineff                ; (no confusion in boss battles)
.s3:        ld hl, BZ + $E1
            add hl, de
            ld a, [BZ + $24]
            and 6
            jr nz, .pp
            ld a, [hl]                      ; paralysed / asleep / confused
            ld [BZ + $25], a
            and $E0
            ld b, a
            ld a, [BZ + $24]
            and $E0
            ld c, a
            ld a, b
            cp c
            jp nc, atk_ineff
            ld a, [BZ + $25]
            and 7
            ld b, a
            ld a, [BZ + $24]
            and $FE
            or b
            ld [hl], a
            and $20
            jr z, .s4
            ld c, $2E
            push hl
            ld a, $70
            call zpy
            ld [hl], 0
            call tgt_flags
            and $E7
            ld [hl], a
            pop hl
.s4:        ld a, [BZ + $24]
            ld c, 0
.s5:        add a, a
            jr c, .s6
            inc c
            jr .s5
.s6:        ld a, c
            add a, $0C
            ld [W7 + $78D9], a
            ret
.pp:        ld a, [BZ + $24]                ; partial petrify
            and $7E
            ld [BZ + $18], a
            ld a, [hl]
            ld [BZ + $25], a
            and 6
            ld b, a
            ld a, [BZ + $18]
            add a, b
            cp 8
            jr nc, .stone
            ld a, [BZ + $25]
            ld b, a
            ld a, [BZ + $18]
            add a, b
            ld [hl], a
            ld c, $2E
            ld a, $6E
            call zpy
            ld a, [hl]
            cp 4
            ret nz
            ld a, [W7 + $78EE]              ; "Petrifying..."
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            ld [hl], $3C
            ld hl, W7 + $78EE
            inc [hl]
            ret
.stone:     ld a, [BZ + $25]
            and $F9
            ld [hl-], a
            ld a, [hl]
            or $40
            ld [hl], a
            ld a, $0B
            ld [W7 + $78D9], a
            ld a, [W7 + $78EE]              ; "Shattered"
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            ld [hl], $28
            ret

; 31/BE14 apply attack status (the weapon's, $7444): hits at (hit % - evade %)
atk_status: ld a, [W7 + $7444]
            ld [BZ + $25], a
            and a
            ret z
            ld a, [BZ + $7C]
            ld [BZ + $24], a
            and a
            ret z
            ld a, [W7 + $742E]
            ld b, a
            ld a, [BZ + $25]
            and b
            ret nz
            ld a, [W7 + $742C]
            ld b, a
            ld a, [W7 + $7442]
            sub b
            jr nc, .p
            xor a
.p:         ld [BZ + $25], a
            call hit_count
            and a
            ret z
            ld a, [W7 + $7444]
            ld [BZ + $24], a
            jp app_status

; ---- 30/9E8A do fight effect
fight_eff:  call init_at
            ld a, [BZ + $64]                ; a dead / stone / jumping target: another
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl+]
            and $C0
            jr nz, .re
            ld a, [hl]
            and 1
            jr z, .go
.re:        ld c, $30
            ld a, $6E
            call zpy
            ld a, [hl]
            bit 7, a
            jr z, .rc
            ld hl, W7 + $7675
            ld a, l
            ld [BZ + $22], a
            ld a, h
            ld [BZ + $23], a
            ld a, 7
            call rnd_target
            jr .ri
.rc:        ld hl, W7 + $7575
            ld a, l
            ld [BZ + $22], a
            ld a, h
            ld [BZ + $23], a
            ld a, 3
            call rnd_target
            ld a, [BZ + $69]
            and a
            jr z, .ri
            xor a
            ld [W7 + $7EC2], a
            dec a
            ld [W7 + $78D8], a
            jp fe_end
.ri:        call init_at
.go:        ld a, $FF
            ld [W7 + $7EE1], a
            xor a
            ld [W7 + $7CE9], a
            ld [BZ + $7C], a
            ld [BZ + $7D], a
            ld [W7 + $741E], a
            ld [BZ + $6A], a
            ld [BZ + $6B], a
            ld [BZ + $42], a
            inc a
            ld [W7 + $741F], a              ; (1 hand)
            ld c, 3                         ; hp before: attacker $40, target $3C
            ld a, $6E
            call zpy
            ld a, [hl+]
            ld [BZ + $40], a
            ld a, [hl]
            ld [BZ + $41], a
            ld c, 3
            ld a, $70
            call zpy
            ld a, [hl+]
            ld [BZ + $3C], a
            ld a, [hl]
            ld [BZ + $3D], a
            call atk_flags
            bit 7, a
            jr z, .hands
            ld a, [BZ + $74]                ; a monster vs running members: penalty
            and a
            jr z, .copy
            call tgt_flags
            bit 7, a
            jr nz, .copy
            ld c, $27
            ld a, $70
            call zpy
            inc [hl]
            jr .copy
.hands:     ld c, $31                       ; two weapons (or none): two hands
            ld a, $6E
            call zpy
            ld a, [hl+]
            bit 7, a
            jr nz, .h1
            and 1
            jr z, .h1
            ld a, [hl]
            bit 7, a
            jr nz, .h1
            and 1
            jr z, .h1
.two:       ld hl, W7 + $741F
            inc [hl]
            ld hl, W7 + $741E
            inc [hl]
            jr .copy
.h1:        ld c, $31
            ld a, $6E
            call zpy
            ld a, [hl+]
            or [hl]
            jr z, .two
.copy:      ld c, $16                       ; attacker's attack stats -> $7420 / $7440 (10)
            ld a, $6E
            call zpy
            ld de, W7 + $7420
            ld b, 10
.c1:        ld a, [hl+]
            ld [de], a
            push hl
            ld hl, $20
            add hl, de
            ld [hl], a
            pop hl
            inc de
            dec b
            jr nz, .c1
            ld c, $20                       ; target's defence stats -> $742A (5)
            ld a, $70
            call zpy
            ld de, W7 + $742A
            ld b, 5
.c2:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c2
            ld c, $27                       ; attacker's +$27-$29 -> $742F
            ld a, $6E
            call zpy
            ld de, W7 + $742F
            ld b, 3
.c3:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c3
fe_hand:    ld a, [W7 + $7441]              ; one hand: hits from hit % ...
            ld [BZ + $24], a
            ld a, [W7 + $7442]
            ld [BZ + $25], a
            ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            ld a, [hl]
            and 4
            jr z, .nb
            ld hl, BZ + $25                 ; (blind)
            srl [hl]
.nb:        ld c, $33
            ld a, $6E
            call zpy
            ld a, [hl]
            and 4
            jr nz, .hit
            call atk_flags
            bit 7, a
            jr nz, .br
            call back_row
            jr c, .hit
.br:        ld c, $33
            ld a, $6E
            call zpy
            ld a, [hl]
            and 1
            jr z, .br1
            ld hl, BZ + $25
            srl [hl]
.br1:       ld c, $33
            ld a, $70
            call zpy
            ld a, [hl]
            and 1
            jr z, .hit
            ld hl, W7 + $7CE9
            inc [hl]
            ld hl, BZ + $25
            srl [hl]
.hit:       call hit_count
            ld [BZ + $7C], a
            ld a, [W7 + $742B]              ; ... minus evaded ones
            ld [BZ + $24], a
            ld a, [W7 + $742C]
            ld [BZ + $25], a
            ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl]
            and 4
            jr z, .eb
            push hl
            ld hl, BZ + $25
            srl [hl]
            pop hl
.eb:        ld a, [hl]
            and $28
            jr nz, .ez
            ld c, $27
            ld a, $70
            call zpy
            ld a, [hl]
            and a
            jr z, .ev
.ez:        xor a
            ld [BZ + $24], a
.ev:        call hit_count
            ld a, [W7 + $7CE9]
            and a
            jr z, .ev1
            ld hl, BZ + $30
            inc [hl]
.ev1:       ld a, [BZ + $30]
            ld b, a
            ld a, [BZ + $7C]
            sub b
            jr nc, .ev2
            xor a
.ev2:       ld [BZ + $24], a
            ld [BZ + $7C], a
            and a
            jr nz, .el
            ld c, $27                       ; no hits: the jump / buildup multiplier lost
            ld a, $6E
            call zpy
            ld [hl], 0
            jp fe_next
.el:        ld c, $12                       ; the element multiplier
            ld a, $70
            call zpy
            ld a, [W7 + $7440]
            and [hl]
            ld a, 4
            jr nz, .em
            ld a, [W7 + $742A]
            cp 2
            jr z, .e1
            ld b, a
            ld a, [W7 + $7440]
            and b
            jr z, .e2
.e1:        ld a, 1
            jr .em
.e2:        ld a, 2
.em:        ld [BZ + $27], a
            xor a
            ld [BZ + $2B], a
            inc a
            ld [BZ + $2A], a
            ld a, [W7 + $7431]
            ld [BZ + $28], a
            xor a
            ld [BZ + $29], a
            ld a, [W7 + $7443]
            ld [BZ + $25], a
            call atk_flags
            bit 7, a
            jr nz, .df
            ld c, $38                       ; the weapons' bonus attack
            ld a, $6E
            call zpy
            call .wb
            inc hl
            call .wb
.df:        ld a, [W7 + $742D]
            ld [BZ + $26], a
            call tgt_flags
            bit 7, a
            jr nz, .tm
            and 7                           ; a defending member: defence doubled
            ld e, a
            ld d, 0
            ld hl, W7 + $7CE4
            add hl, de
            ld a, [hl]
            and a
            jr z, .tm
            ld a, [BZ + $26]
            cp $80
            jr c, .d2
            ld a, $FF
            ld [BZ + $26], a
            jr .tm
.d2:        add a, a
            ld [BZ + $26], a
.tm:        ld a, [BZ + $62]                ; a toad / mini attacker: attack 1
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            ld a, [hl]
            and $28
            jr z, .tt
            ld a, 1
            ld [BZ + $25], a
.tt:        ld a, [BZ + $64]                ; a toad / mini / jumping target: attack x 2, no defence
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            ld a, [hl]
            and $28
            jr nz, .t2
            ld c, $27
            ld a, $70
            call zpy
            ld a, [hl]
            and a
            jr z, .cr
.t2:        ld hl, BZ + $25
            sla [hl]
            ld hl, BZ + $2B
            rl [hl]
            xor a
            ld [BZ + $26], a
.cr:        ld a, 99                        ; crit
            call rnd_0a
            ld b, a
            ld a, [W7 + $7430]
            ld c, a
            ld a, b
            cp c
            jr nc, .cr1
            ld hl, BZ + $29
            inc [hl]
            ld hl, BZ + $CB
            inc [hl]
.cr1:       ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            ld a, [hl]
            and $28
            jr z, .dm
            xor a
            ld [BZ + $29], a
            ld [BZ + $CB], a
.dm:        call calc_dmg
            ld a, [BZ + $29]
            and a
            jr z, .jb
            ld a, [W7 + $78EE]              ; "Critical hit!"
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            ld [hl], $34
            ld hl, W7 + $78EE
            inc [hl]
.jb:        ld c, $27                       ; jump / buildup: damage x (counter + 1)
            ld a, $6E
            call zpy
            ld a, [hl]
            and a
            jr z, .mn
            inc a
            ld [BZ + $18], a
            ld [hl], 0
            xor a
            ld [BZ + $19], a
            ld a, [BZ + $1C]
            ld [BZ + $1A], a
            ld a, [BZ + $1D]
            ld [BZ + $1B], a
            call bmul16
.mn:        ld a, [BZ + $1C]                ; at least 1
            ld b, a
            ld a, [BZ + $1D]
            or b
            jr nz, .mn1
            ld hl, BZ + $1C
            inc [hl]
.mn1:       ld a, [BZ + $1C]
            ld [BZ + $78], a
            ld a, [BZ + $1D]
            ld [BZ + $79], a
            call tg_ptr
            ld a, [W7 + $7440]              ; a recovery (drain) weapon
            and 1
            jr z, .nd
            call undead
            jr c, .nd1
            call net_add
.nd1:       call tgt_flags
            and $87
            ld [BZ + $18], a
            call atk_flags
            and $87
            ld b, a
            ld a, [BZ + $18]
            cp b
            jr z, .sub
            call drain
            ld a, [BZ + $26]
            and a
            jr z, .alive
            bit 7, a
            jr nz, .adie
            jr .tdie
.nd:        xor a
            ld [BZ + $26], a
            call net_add
.sub:       call sub_hp
            jr c, .alive
.tdie:      ld a, [BZ + $64]
            ld e, a
            ld d, 0
            ld hl, BZ + $E0
            add hl, de
            set 7, [hl]
            jr fe_next
.adie:      ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, BZ + $F0
            add hl, de
            set 7, [hl]
            jr fe_next
.alive:     ld a, [W7 + $7ED8]
            bit 7, a
            jr nz, fe_next
            ld c, 1
            ld a, $6E
            call zpy
            ld a, [hl]
            and $28
            call z, atk_status
            jr fe_next
.wb:        ld a, [BZ + $25]                ; 31/A389: + the hand's bonus attack (msb $2B)
            add a, [hl]
            ld [BZ + $25], a
            ld a, [BZ + $2B]
            adc a, 0
            ld [BZ + $2B], a
            ret
fe_next:    ld hl, W7 + $741F               ; 31/A139: the other hand
            dec [hl]
            jr z, .end
            ld hl, W7 + $7425
            ld de, W7 + $7440
            ld bc, 5
            call memcpy
            ld a, [BZ + $7C]
            ld [BZ + $7D], a
            xor a
            ld [BZ + $7C], a
            ld [BZ + $78], a
            ld [BZ + $79], a
            jp fe_hand
.end:       ld a, [W7 + $741E]
            and a
            jr z, fe_show
            ld a, [BZ + $7C]
            ld b, a
            ld a, [BZ + $7D]
            ld [BZ + $7C], a
            ld a, b
            ld [BZ + $7D], a
fe_show:    ld a, [BZ + $64]                ; 31/A16C: the numerals
            ld e, a
            ld d, 0
            ld a, [BZ + $7C]
            ld [BZ + $BB], a
            ld b, a
            ld a, [BZ + $7D]
            or b
            jr nz, .h
            ld [BZ + $BC], a
            ld hl, W7 + $7E4F
            add hl, de
            ld [hl+], a
            ld [hl], $40                    ; (miss)
            jp fe_end
.h:         ld a, [BZ + $7D]
            ld [BZ + $BC], a
            ld c, 3                         ; the attacker's hp change
            ld a, $6E
            call zpy
            ld a, [hl+]
            ld [BZ + $78], a
            ld a, [hl]
            ld [BZ + $79], a
            call atk_flags
            and $87
            ld b, a
            call tgt_flags
            and $87
            cp b
            jp z, .ms
            ld a, [BZ + $62]
            ld e, a
            ld d, 0
            ld hl, W7 + $7E5F
            add hl, de
            ld a, [BZ + $78]                ; before - now
            ld b, a
            ld a, [BZ + $40]
            sub b
            ld c, a
            ld a, [BZ + $79]
            ld b, a
            ld a, [BZ + $41]
            sbc b
            jr c, .gain
            ld [hl], c                      ; (lost: the plain value)
            inc hl
            ld [hl], a
            ld c, $16
            ld a, $6E
            call zpy
            ld a, [hl]
            ld c, $1B
            push af
            ld a, $6E
            call zpy
            pop af
            or [hl]
            and 1
            jr z, .ms
            ld a, $27                       ; "HP drained!"
            call msg_q
            jr .ms
.gain:      ld a, [BZ + $78]                ; now - before, green
            ld b, a
            ld a, [BZ + $40]
            ld c, a
            ld a, b
            sub c
            ld [hl+], a
            ld a, [BZ + $41]
            ld c, a
            ld a, [BZ + $79]
            sbc c
            or $80
            ld [hl], a
            call atk_flags
            bit 7, a
            ld a, $25                       ; "Absorbed HP!" / "HP drained!"
            jr z, .g1
            ld a, $26
.g1:        call msg_q
.ms:        xor a
            ld [BZ + $43], a
            ld a, [W7 + $78EE]
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .m1
            ld hl, BZ + $43
            inc [hl]
            ld hl, W7 + $78EE
            inc [hl]
.m1:        ld a, [BZ + $62]                ; no attacker change: null (and its message out)
            ld e, a
            ld d, 0
            ld hl, W7 + $7E5F
            add hl, de
            ld a, [hl+]
            ld b, a
            ld a, [hl-]
            and $7F
            or b
            jr nz, .tg
            ld a, $FF
            ld [hl+], a
            ld [hl], a
            ld a, [BZ + $43]
            and a
            jr z, .tg
            ld hl, W7 + $78EE
            dec [hl]
            ld e, [hl]
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            ld [hl], $FF
.tg:        ld a, [BZ + $64]                ; the target's numeral: damage, or green if restored
            ld e, a
            ld d, 0
            ld hl, W7 + $7E4F
            add hl, de
            ld a, [BZ + $42]
            and a
            jr z, .t1
            push hl
            ld c, 3
            ld a, $70
            call zpy
            ld a, [BZ + $3C]
            ld b, a
            ld a, [hl+]
            sub b
            ld c, a
            ld a, [BZ + $3D]
            ld b, a
            ld a, [hl]
            sbc b
            or $80
            pop hl
            ld [hl], c
            inc hl
            ld [hl], a
            jr fe_end
.t1:        ld a, [BZ + $6A]
            ld [hl+], a
            ld a, [BZ + $6B]
            ld [hl], a
fe_end:     ld a, [BZ + $74]                ; 31/A264: running members can't defend
            and a
            jr z, .x
            call atk_flags
            bit 7, a
            jr z, .x
            call tgt_flags
            bit 7, a
            jr nz, .x
            ld c, $27
            ld a, $70
            call zpy
            dec [hl]                        ; (FF3: sbc #1 with the carry of its test: set)
            ld a, [BZ + $7C]
            and a
            jr z, .x
            ld a, $55                       ; "Defenceless"
            call msg_q
            ld hl, W7 + $78EE
            inc [hl]
.x:         call atk_flags
            bit 7, a
            ret nz
            ld c, $31                       ; (split monsters: later) the numbers of hits shown
            ld a, $6E
            call zpy
            ld a, [hl]
            bit 7, a
            jr nz, .s1
            and 1
            jr nz, .s2
.s1:        ld a, [BZ + $7D]
            and a
            jr nz, .s2
            ld a, [BZ + $7C]
            ld [BZ + $BC], a
            xor a
            ld [BZ + $BB], a
.s2:        ld c, $33
            ld a, $6E
            call zpy
            ld a, [hl]
            and 4
            ret z
            ld a, [BZ + $7C]
            ld b, a
            ld a, [BZ + $7D]
            add a, b
            ld [BZ + $BB], a
            ret

; a message A into the queue at $78DA + $78EE (the index not moved)
msg_q:      push af
            ld a, [W7 + $78EE]
            ld e, a
            ld d, 0
            ld hl, W7 + $78DA
            add hl, de
            pop af
            ld [hl], a
            ret
