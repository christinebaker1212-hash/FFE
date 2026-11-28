; ---- 34/8074 battle main: the turns (monster actions, the members' commands, the attack order,
; each action and its script, poison) until one side is out; then FF3's end message.
; (Victory rewards, defeat, the cannon blast: next.)
btl_loop:   call turn_start                 ; 34/81C3
            ld a, [W7 + $78BA]
            and 1
            call z, mon_think
            call def_restore                ; 34/81A0
            call get_actions                ; 34/986C
            xor a
            ld [W7 + $7BE1], a
            call inv_run                    ; 34/8374
            ld a, [W7 + $78BA]
            bit 7, a
            call z, cmd_count               ; 34/8271
            call atk_order                  ; 34/9777
            call cur_hide
            call type_msg                   ; 34/82CE
            ld a, $FF
            ld hl, W7 + $78CF
            ld [hl+], a
            ld [hl+], a
            ld [hl+], a
            ld [hl], a
.act:       call act_reset                  ; 34/8213
            call hp_win
            call btl_over
            ld a, [W7 + $78D3]
            and a
            jr nz, .over
            call mon_rows                   ; 34/8295
            call exec_action                ; 34/9DE4
            call mag_msg                    ; 35/A56F
            ld a, [W7 + $7ED8]
            and $DF
            ld [W7 + $7ED8], a
            call act_script                 ; 34/8FF7
            ld hl, W7 + $7AC2
            inc [hl]
            ld e, [hl]
            ld d, 0
            ld hl, W7 + $7ACB
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .end
            ld a, e
            cp $0C
            jr nz, .act
.end:       ld a, [W7 + $78D3]
            and 2
            call z, poison                  ; 35/BA41
            call btl_over
            ld a, [W7 + $78D3]
            and a
            jr nz, .over
            ld a, [W7 + $78BA]
            and 8
            ld [W7 + $78BA], a
            jp btl_loop
.over:      call hp_win                     ; 34/811C
            ld a, [W7 + $78D3]
            and 2
            jr nz, .save                    ; (ran away)
            ld a, 2                         ; action script $02: Victory! / Annihilated...
            ld [W7 + $7EC2], a
            ld [W7 + $78D5], a
            ld a, [W7 + $78D3]
            bit 7, a
            ld a, $1D
            jr z, .v
            ld a, $1C
.v:         ld [W7 + $78DA], a
            cp $1C
            jr z, .say
            ld a, [W7 + $7CED]              ; (battles $78 / $73 with $7CEE: no message)
            cp $78
            jr z, .sp
            cp $73
            jr nz, .say
.sp:        ld a, [W7 + $7CEE]
            and a
            jr nz, .save
.say:       call act_script
            call end_anim                   ; (graphics $11: the battle's end)
            ld a, [W7 + $78D3]
            bit 7, a
            jr nz, .cons                    ; (defeated)
            call victory                    ; 35/BB49
.save:      call btl_save                   ; 34/8306
            ld a, [W7 + $78BA]
            and 8
            call nz, rows_flip              ; 34/88A4
.cons:      call consol                     ; 34/8032 (31/BEBF)
            ld a, [W7 + $7CED]
            cp $79
            ret nz
            ld a, [W7 + $7CEE]
            and a
            ret z
            xor a
            ld [W7 + $78D3], a
            ret

; 35/A458 check if battle is over: all members dead / stone $80, no monsters left $40
btl_over:   ld a, [W7 + $78D3]
            and 2
            ret nz
            xor a
            ld [BZ + $52], a
.m:         call chr_ofs
            inc a
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            and $C0
            jr z, .mon
            ld a, [BZ + $52]
            inc a
            ld [BZ + $52], a
            cp 4
            jr nz, .m
            ld a, $80
            jr .set
.mon:       ld a, [W7 + $7DD2]
            and a
            ret nz
            ld a, $40
.set:       ld [W7 + $78D3], a
            ret

; 34/8295 update monster rows (34/86B9: the front ones are those within 2 rows of the
; frontmost, counted from slot 7 down to the first in the back row)
mon_rows:   xor a
            ld [BZ + $18], a
            ld c, 7                         ; 34/86EA: the frontmost
.f:         call mon_row
            jr nc, .f1
            ld [BZ + $1A], a
            sub 2
            ld [BZ + $1B], a
            jr .s
.f1:        dec c
            bit 7, c
            jr z, .f
.s:         ld c, 7
.l:         call mon_row
            jr nc, .n
            ld b, a
            ld a, [BZ + $1B]
            cp b
            jr z, .set
            ld a, c
            call bitmask
            ld b, a
            ld a, [BZ + $18]
            or b
            ld [BZ + $18], a
.n:         dec c
            bit 7, c
            jr z, .l
.set:       ld hl, W7 + $7675 + $33         ; each monster's +$33 bit 0: back row
            ld a, l
            ld [BZ + $1A], a
            ld a, h
            ld [BZ + $1B], a
            ld a, [BZ + $18]
            ld b, 8
.m:         add a, a
            push af
            jr nc, .back
            res 0, [hl]
            jr .nx
.back:      set 0, [hl]
.nx:        ld de, $40
            add hl, de
            pop af
            dec b
            jr nz, .m
            ld de, -$33
            add hl, de
            ld a, l
            ld [BZ + $1A], a
            ld a, h
            ld [BZ + $1B], a
            ret

; 34/8705 get monster row: slot C -> A (0-3), carry set; carry clear if the slot is empty
mon_row:    ld a, c
            ld [BZ + $7F], a
            ld e, a
            ld d, 0
            ld hl, W7 + $7DA7
            add hl, de
            ld a, [hl]
            cp $FF
            jr z, .no
            ld a, [W7 + $7D7B]              ; 34/8739 + 2 id: two bits a slot, slot 0 first
            add a, a
            add a, low(ROWTAB)
            ld l, a
            ld h, high(ROWTAB)
            call bd_rd
            ld d, a
            call bd_rd
            ld e, a
            ld b, c
            inc b
            ld a, [BZ + $7E]
.r:         sla e
            rl d
            rla
            sla e
            rl d
            rla
            dec b
            jr nz, .r
            push af
            ld a, d
            ld [BZ + $80], a
            ld a, e
            ld [BZ + $81], a
            pop af
            ld [BZ + $7E], a
            and 3
            scf
            ret
.no:        and a
            ret

; 34/8374 update inventory and run flag: the items picked returned to the inventory (31/A65E
; takes them when used), $74 = run / escape chosen
inv_run:    xor a
            ld [BZ + $52], a
            ld [BZ + $74], a
.m:         call ret_item
            call chr_ofs
            add a, $2E
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            cp 6
            jr z, .r
            cp 7
            jr nz, .n
.r:         ld hl, BZ + $74
            inc [hl]
.n:         ld a, [BZ + $52]
            inc a
            ld [BZ + $52], a
            cp 4
            jr nz, .m
            ret

; 34/8271 update number of times commands were used ($78F0 + 4 member + slot)
cmd_count:  xor a
            ld [BZ + $52], a
.m:         ld a, [BZ + $52]
            ld e, a
            ld d, 0
            ld hl, W7 + $7AC3
            add hl, de
            ld a, [hl]
            ld [BZ + $18], a
            cp $FF
            jr z, .n
            ld b, a
            ld a, e
            add a, a
            add a, a
            add a, b
            ld e, a
            ld hl, W7 + $78F0
            add hl, de
            inc [hl]
.n:         ld a, [BZ + $52]
            inc a
            ld [BZ + $52], a
            cp 4
            jr nz, .m
            ret

; 34/82CE display battle type message (strike first, ambushed, back attack)
type_msg:   ld a, [W7 + $78BA]
            and a
            jr z, .x
            bit 7, a
            jr nz, .amb
            and 8
            jr nz, .x
            ld a, $17
            jr .show
.amb:       and 8
            ld a, $18
            jr z, .show
            ld a, $19
.show:      ld [W7 + $78DA], a
            ld a, 2
            ld [W7 + $78D5], a
            ld [W7 + $7EC2], a
            call act_script
.x:         ld a, [W7 + $78BA]
            and 9
            ld [W7 + $78BA], a
            ret

; 35/BA41 do poison damage: max hp / 16 to each poisoned one (members, then monsters), the
; numerals, "Damaged by poison", the deaths
poison:     ld hl, W7 + $7400
            ld a, $FF
            ld b, $20
.c:         ld [hl+], a
            dec b
            jr nz, .c
            xor a
            ld [BZ + $64], a
            ld a, 8
            ld [BZ + $24], a
            ld hl, W7 + $7575
.m:         call psn_one
            ld de, $40
            add hl, de
            ld a, [BZ + $24]
            inc a
            ld [BZ + $24], a
            cp $0C
            jr nz, .m
            call stat_disp_all
            xor a
            ld [BZ + $24], a
            ld hl, W7 + $7675
.k:         call psn_one
            inc hl
            ld a, [hl-]
            push hl
            ld e, a
            ld a, [BZ + $24]
            ld c, a
            ld b, 0
            ld hl, W7 + $7EC4
            add hl, bc
            ld [hl], e
            pop hl
            ld de, $40
            add hl, de
            ld a, [BZ + $24]
            inc a
            ld [BZ + $24], a
            cp 8
            jr nz, .k
            ld a, l
            ld [BZ + $28], a
            ld a, h
            ld [BZ + $29], a
            ld a, [BZ + $64]
            and a
            ret z
            ld hl, W7 + $7400
            ld de, W7 + $7E4F
            ld bc, $20
            call memcpy
            ld a, $80
            ld [W7 + $7E98], a
            ld [W7 + $7E99], a
            srl a
            ld [W7 + $7E9A], a
            ld a, 5
            ld [W7 + $78D5], a
            ld a, $41
            ld [W7 + $78DA], a
            ld a, $17
            ld [W7 + $7EC2], a
            call act_script
            call mon_deaths
            jp btl_over

; 35/BADC calculate poison damage: the record at HL ($28), index $24 (HL kept)
psn_one:    ld a, l
            ld [BZ + $28], a
            ld a, h
            ld [BZ + $29], a
            push hl
            inc hl
            ld a, [hl]
            bit 1, a
            jr z, .z
            and $C0
            jr nz, .z
            ld a, [BZ + $64]
            inc a
            ld [BZ + $64], a
            ld a, [BZ + $24]
            add a, a
            ld [BZ + $62], a
            pop hl
            push hl
            ld de, 5                        ; max / 16
            add hl, de
            ld a, [hl+]
            ld e, a
            ld d, [hl]
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            ld a, e
            ld [BZ + $26], a
            ld a, d
            ld [BZ + $27], a
            push de
            ld a, [BZ + $62]
            ld c, a
            ld b, 0
            ld hl, W7 + $7400
            add hl, bc
            ld [hl], e
            inc hl
            ld [hl], d
            pop de
            pop hl
            push hl
            inc hl
            inc hl
            inc hl
            ld a, [hl]
            sub e
            ld [hl+], a
            ld a, [hl]
            sbc d
            ld [hl], a
            jr c, .dead
.z:         pop hl                          ; 35/BB3F: zero hp -> dead
            push hl
            inc hl
            inc hl
            inc hl
            ld a, [hl+]
            or [hl]
            jr z, .dead
            pop hl
            ret
.dead:      pop hl
            push hl
            inc hl
            inc hl
            inc hl
            xor a
            ld [hl+], a
            ld [hl], a
            pop hl
            push hl
            inc hl
            ld a, [hl]
            or $80
            and $FE
            ld [hl], a
            pop hl
            ret

; 34/9AE7 return member $52's used item (+$3F) to the inventory (not one from a hand, +$3E)
ret_item:   call chr_ofs
            add a, $3F
            ld c, a
            ld a, $5B
            call zpy
            ld a, [hl]
            and a
            ret z
            ld [BZ + $18], a
            ld b, a
            ld [hl], 0
            dec hl
            ld a, [hl]
            ld [hl], 0
            and a
            ret nz
            ld hl, GS + $C0
            ld c, $20
.f:         ld a, [hl+]
            cp b
            jr z, .inc
            inc hl
            dec c
            jr nz, .f
            ld hl, GS + $C0
.e:         ld a, [hl+]
            and a
            jr z, .new
            inc hl
            jr .e
.new:       dec hl
            ld [hl], b
            inc hl
.inc:       inc [hl]
            ret

; 2F/B261 battle graphics $11: defeat: "The Requiem", A to go on (not battle $179); victory:
; "Fanfare" and the members' cheer (128 frames: the cheer frame / frame 2 every 32), 21 more
end_anim:   ld a, [W7 + $78D3]
            bit 7, a
            jr z, .v
            ld a, $13
            call snd_song
.d:         ld a, [W7 + $7CEE]
            and a
            jr z, .w
            ld a, [W7 + $7CED]
            cp $79
            ret z
.w:         call b_keys
            ld a, [btl_new]
            bit 0, a
            jr z, .d
            ret
.v:         ld a, 7
            call snd_song
            call ba_vgfx                    ; (2F/A963: the cheer tiles)
            xor a
            ld [BZ + $B6], a
.f:         ld c, 0
.m:         ld a, [W7 + $7D8B]
            cp $FF
            jr z, .n
            ld b, 0
            ld hl, W7 + $7D9B
            add hl, bc
            add hl, bc
            ld a, [hl]
            and $C0
            jr nz, .n
            ld a, [BZ + $B6]
            and $20
            ld d, a
            ld a, [hl]
            and 5
            jr z, .p
            ld a, d
            and a
            ld a, $0B
            jr nz, .s
            ld a, $0E
            jr .s
.p:         ld a, d
            and a
            ld a, 2
            jr nz, .s
            ld a, c
            add a, $11
.s:         ld hl, W7 + $7D83
            add hl, bc
            ld [hl], a
.n:         inc c
            ld a, c
            cp 4
            jr nz, .m
            call chr_draw
            call wait_vbl
            ld hl, BZ + $B6
            inc [hl]
            bit 7, [hl]
            jr z, .f
            ld b, 21
.z:         call wait_vbl
            dec b
            jr nz, .z
            ret
