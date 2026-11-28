; ---- events: talking to people (fix:EA26 / E494 / E9BB), their scripts (2C/8200, 2C/8400: a
; conditional list on event switches, then the dialogue ids -> $0740; 3C/92F3 / 9319) and the event
; scripts (2C/8600: one command a frame while the party stands still, fix:D219, 3B/A12B).
; Banks 2C / 2D are copied whole into EVT_BANK at build time (CPU $8000-$BFFF -> GB $4000-$7FFF).
; (EV_DLG, EV_TRIG: main.s)

section bank 0, $3000
; A pressed with the party standing: a person in front (fix:E494) -> its script
talk:       ld a, [px]                      ; the facing tile (fix:E4E9)
            ld e, a
            ld a, [py]
            ld d, a
            ld a, [facing]
            rrca
            jr nc, .f1
            inc e                           ; right
            jr .f
.f1:        rrca
            jr nc, .f2
            dec e                           ; left
            jr .f
.f2:        rrca
            jr nc, .f3
            inc d                           ; down
            jr .f
.f3:        dec d                           ; up
.f:         ld a, e
            and $3F
            ld e, a
            ld a, d
            and $3F
            ld d, a
            ld l, 0                         ; fix:E494
.l:         ld h, high(N_OB2)
            ld a, l
            add a, 6
            ld c, a
            ld b, h
            ld a, [bc]                      ; npc z: 0 / 3 always, else as the party's
            and a
            jr z, .z
            cp 3
            jr z, .z
            ld b, a
            ld a, [zlev]
            and a
            jr z, .z
            cp b
            jr nz, .n
.z:         ld h, high(N_OBJ)
            ld a, [hl]
            and a
            jr z, .n
            push hl
            ld a, l                         ; x + (subtile >= 8), y likewise
            add a, 4
            ld c, a
            ld b, h
            ld a, l
            add a, 6
            ld l, a
            ld a, [hl]
            cp 8
            ccf
            ld a, [bc]
            adc a, 0
            and $3F
            cp e
            jr nz, .n0
            inc l
            inc c
            ld a, [hl]
            cp 8
            ccf
            ld a, [bc]
            adc a, 0
            and $3F
            cp d
            jr nz, .n0
            pop hl
            ld a, [tk_b]                    ; (B: someone there, fix:EAD0)
            and a
            ret nz
            inc l                           ; type & $30 = 0: it turns to the party
            ld a, [hl]
            dec l
            and $30
            jr nz, .found
            ld a, l
            add a, $0D
            ld c, a
            ld b, h
            ld a, [bc]
            or $80
            ld [bc], a
            jr .found
.n0:        pop hl
.n:         ld a, l
            add a, 16
            ld l, a
            cp $C0
            jr c, .l
            ld a, [tk_b]                    ; (B, no one: the guest, fix:EA56)
            and a
            jp nz, g_talk
            jp treasure                     ; (no one: treasures, locked doors: fix:E917)
.found:     ld a, [hl]                      ; the npc's script: 2C/8200 (world 0) / 2C/8400
            ld [ev_npc], a
            ld c, a
            ld b, $42                       ; (GB: $4200 / $4400 + 2 id)
            ld a, [cur_world]
            and a
            jr z, .w0
            ld b, $44
.w0:        ld l, c
            ld h, 0
            add hl, hl
            ld a, h
            add a, b
            ld h, a
            ld a, EVT_BANK
            ld [MBC5_BANKL], a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call ev_trig                    ; -> EV_TRIG
            ld a, [ev_npc]                  ; (fix:E9D3: $E0- inns, shops, the fat chocobo)
            cp $E0
            jr nc, shop_npc
            ld hl, EV_TRIG                  ; 3C/92F3: past the conditionals (blocks end with
            ld c, 0                         ;   $FF id; the list with a block starting $FF)
.cl:        ld a, [hl]
            cp $FF
            jr z, .cd
.cs:        inc l
            ld a, [hl]
            cp $FF
            jr nz, .cs
            inc l
            inc l
            jr .cl
.cd:        inc l
            inc l
            ld de, EV_DLG                   ; 32 bytes of dialogue ids -> $0740
            ld b, 32
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .cp
            call ev_check                   ; -> event id
            and a
            ret z
            jp ev_start

; fix:E9E8: an inn ($E0-$E2), a shop ($E3-$FB) or the fat chocobo ($FC-), in bank CODE1
; (shop.s); after an inn its event (FF3 $7B01 -> $6C)
shop_npc:   ld hl, choc_open                ; ($FC-: the fat chocobo, 3D/B383)
            cp $FC
            jr nc, .f
            ld hl, shop_open
            cp $E3
            jr nc, .f
            ld hl, inn_open
.f:         ld a, CODE1
            call far_call
            ld a, [sh_ev]
            and a
            ret z
            jp ev_start

; fix:E917: the tile in front (E, D) is a locked door ($90-$9F) or a treasure ($D0-$DF chests,
; $E0-$EF hidden ones, only while their switch is on) -> fix:E982 / F549, a message
treasure:   push de
            call map_at
            pop de
            ld [tr_t], a
            ld l, a
            ld h, high(M_P1)
            bit 7, [hl]
            ret z
            inc h
            ld a, [hl]
            and $0F
            ld [tr_n2], a
            ld a, [tr_t]
            cp $90
            ret c
            cp $A0
            jr c, .locked
            cp $D0
            ret c
            cp $F0
            ret nc
            ld a, e
            ld [tr_x], a
            ld a, d
            ld [tr_y], a
            ld a, [tr_t]
            cp $E0
            jr c, .give
            ld a, [tr_n2]                   ; (hidden: only if still there)
            call tr_open
            ret nz
.give:      ld a, [tr_n2]                   ; the treasure id -> its contents (01/9C00 / 9D00)
            add a, low(M_TT)
            ld l, a
            ld h, high(M_TT)
            ld a, [hl]
            ld [tr_id2], a
            ld l, a
            ld h, $40
            ld a, [cur_world]
            and a
            jr z, .c0
            inc h
.c0:        ld a, GAME_BANK
            ld [MBC5_BANKL], a
            ld a, [hl]
            ld [t_item], a
            ld a, [tr_t]                    ; a chest on a map whose chests hold gil
            cp $E0
            jr nc, .item
            ld a, [M_ENT + 10]
            and $20
            jr z, .item
            ld a, [t_item]                  ; gil: the item's price (fix:F5B2)
            call item_price
            call gil_add
            call .toggle
            ld a, $01
            jr .msg
.item:      ld a, [t_item]                  ; an item: 1 (arrows $4F-$56: 20)
            ld [ev_par], a
            ld b, 1
            cp $4F
            jr c, .q
            cp $57
            jr nc, .q
            ld b, 20
.q:         ld a, b
            ld [tr_q], a
            call ev_find                    ; (3C/937E)
            ld a, $50                       ; "Can't carry anymore." (no change)
            jr c, .show
            ld a, [t_item]
            ld [hl], a
            ld a, l
            add a, $20
            ld l, a
            ld a, [tr_q]
            add a, [hl]
            cp 99
            jr c, .q99
            ld a, 99
.q99:       ld [hl], a
            call .toggle
            ld a, [tr_t]
            cp $E0
            ld a, $76                       ; (not a chest)
            jr nc, .show
            ld a, [tr_id2]
            cp $E0
            ld a, $59                       ; "Found ...!"
            jr c, .msg
            ld a, [tr_id2]                  ; (FF3 F5A1: the treasure id is the battle, after
            ld [act_id], a                  ;   "Found ...! A monster appeared!")
            ld a, $20
            ld [act], a
            ld a, $02
.msg:       push af                         ; a chest: opened ($7D) and redrawn
            ld a, [tr_x]
            ld e, a
            ld a, [tr_y]
            ld d, a
            push de
            call map_at
            ld [hl], $7D
            pop de
            call q_mt
            pop af
.show:      ld c, a
            ld a, 1
            jp dlg_show
.toggle:    ld a, [tr_id2]
            call tr_sw
            ld a, [hl]
            xor b
            ld [hl], a
            ret
.locked:    ld a, [GS + $0E]                ; the showing character a Thief (job 8): unlocked
            ld l, a
            ld h, high(GS + $100)
            ld a, [hl]
            cp 8
            ld a, $03                       ; "Locked."
            jr nz, .show
            ld hl, GS + $21
            set 6, [hl]
            ld a, $7A
            jr .show

; CDE added to the party's gil (fix:F5FF: capped when the high byte reaches $98)
gil_add:    ld hl, GS + $1C
            ld a, [hl]
            add a, e
            ld [hl+], a
            ld a, [hl]
            adc a, d
            ld [hl+], a
            ld a, [hl]
            adc a, c
            ld [hl], a
            cp $98
            ret c
            ld [hl], $98
            dec hl
            ld [hl], $96
            dec hl
            ld [hl], $7F
            ret

; a trigger tile of type F stepped on (fix:E6BE): its event (2C/8880 + 2 trigger id)
trig_ev:    add a, low(M_TT + 16)
            ld l, a
            ld h, high(M_TT + 16)
            ld a, [hl]
            ld l, a
            ld h, 0
            add hl, hl
            ld de, $4880
            add hl, de
            ld a, EVT_BANK
            ld [MBC5_BANKL], a
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call ev_trig
            call ev_vsw
            call ev_check
            and a
            ret z
            jp ev_start

; 3C/9274: the toad / mini event switches from the party, the vehicle flags cleared
ev_vsw:     ld a, [GS + $102]
            ld b, a
            ld a, [GS + $142]
            and b
            ld b, a
            ld a, [GS + $182]
            and b
            ld b, a
            ld a, [GS + $1C2]
            and b
            ld b, a
            and $20
            add a, a
            ld c, a
            ld a, b
            and $08
            swap a
            or c
            ld c, a
            ld a, [GS + $2E]
            and $3F
            or c
            ld [GS + $2E], a
            ld hl, GS + $21
            res 7, [hl]
            ld a, [GS + $2F]
            and $C3
            ld [GS + $2F], a
            ret

; HL = CPU address of a trigger script -> 64 bytes to EV_TRIG (fix:EA1B)
ev_trig:    ld a, h
            sub $40
            ld h, a
            ld de, EV_TRIG
            ld bc, 64
            ld a, EVT_BANK
            ld [MBC5_BANKL], a
            jp memcpy

; 3C/9319: the first block whose switches hold: A = its event id
ev_check:   ld hl, EV_TRIG
.b:         ld a, [hl]
            cp $FF
            jr nz, .c
            inc l
            ld a, [hl]
            ret
.c:         ld [ev_tmp], a                  ; a switch: bit 7 = must be on, else off
            inc l
            push hl
            call ev_sw
            pop hl
            ld b, a
            ld a, [ev_tmp]
            bit 7, a
            ld a, b
            jr z, .off
            and a
            jr nz, .b
            jr .skip
.off:       and a
            jr z, .b
.skip:      ld a, [hl+]                     ; (the block fails: past its $FF and id)
            cp $FF
            jr nz, .skip
            inc l
            jr .b

; A = switch (bit 7 ignored) -> A = its bit in the event switches ($6020)
ev_sw:      and $7F
            ld c, a
            and 7
            ld b, a
            ld a, 1
            inc b
.m:         dec b
            jr z, .m1
            add a, a
            jr .m
.m1:        ld b, a
            ld a, c
            srl a
            srl a
            srl a
            add a, low(GS + $20)
            ld l, a
            ld h, high(GS + $20)
            ld a, [hl]
            and b
            ret

; A = event id -> the script (2C/8600 + 2 id) runs from the next frame (fix:C72C)
ev_start:   ld l, a
            ld h, 0
            add hl, hl
            ld a, h
            add a, $46
            ld h, a
            ld a, EVT_BANK
            ld [MBC5_BANKL], a
            ld a, [hl+]
            ld [ev_ptr], a
            ld a, [hl]
            ld [ev_ptr + 1], a
            ld a, 1
            ld [ev_on], a
            xor a
            ld [ev_rep], a
            ld [ev_w75], a
            ret

; one command (fix:D219): $FE n repeats the next command n times; $E4-$FC take a parameter
ev_step:    ld a, [ev_rep]
            and a
            jr z, .fetch
            dec a
            ld [ev_rep], a
            jr .exec
.fetch:     ld a, EVT_BANK
            ld [MBC5_BANKL], a
            ld a, [ev_ptr]
            ld l, a
            ld a, [ev_ptr + 1]
            sub $40
            ld h, a
            ld a, [hl+]
            ld b, a
            ld a, [hl]
            ld c, a
            ld a, b
            cp $FE
            jr nz, .one
            ld a, c                         ; $FE n
            dec a
            ld [ev_rep], a
            ld a, 2
            jr .adv
.one:       ld [ev_cmd], a
            ld a, c
            ld [ev_par], a
            ld a, b
            cp $E4
            ld a, 1
            jr c, .adv1
            ld a, b
            cp $FD
            ld a, 1
            jr nc, .adv1
            inc a
.adv1:      call .add
            jr .exec
.adv:
.add:       ld hl, ev_ptr
            add a, [hl]
            ld [hl+], a
            ret nc
            inc [hl]
            ret
.exec:      ld a, [ev_cmd]
            cp $C0
            jp c, ev_npc_cmd
            cp $D0
            jp c, ev_pl_cmd
            cp $E4
            jp c, ev_misc
            sub $E4                         ; $E4-$FF: the table
            add a, a
            ld l, a
            ld h, 0
            ld de, ev_tab
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
ev_tab:     dw ev_none, ev_none, ev_none, ev_take    ; E4-E7
            dw ev_stclr, ev_stset, ev_gil, ev_tgil   ; E8-EB
            dw ev_gcp, ev_tcp, ev_guest, ev_spec     ; EC-EF
            dw ev_ndlg, ev_edlg, ev_esw1, ev_esw0    ; F0-F3
            dw ev_nsw1, ev_nsw0, ev_give, ev_btl     ; F4-F7
            dw ev_f8, ev_xexit, ev_xent, ev_xmap     ; F8-FB
            dw ev_wait, ev_exit, ev_none, ev_end     ; FC-FF
ev_none:    ret
; $EB take gil (3B/B80D: the parameter from the middle byte; too little: dialogue 2)
ev_tgil:    ld a, [GS + $1E]
            and a
            jr nz, .t
            ld a, [ev_par]
            ld b, a
            ld a, [GS + $1D]
            cp b
            jr nc, .t
            call ev_end
            ld a, 0
            ld c, 2
            jp dlg_show
.t:         ld a, [ev_par]
            ld b, a
            ld a, [GS + $1D]
            sub b
            ld [GS + $1D], a
            ld a, [GS + $1E]
            sbc 0
            ld [GS + $1E], a
            ret nc
            xor a
            ld [GS + $1C], a
            ld [GS + $1D], a
            ld [GS + $1E], a
            ret
; $EC / $ED give / take capacity (255 at most; too little: dialogue 3)
ev_gcp:     ld a, [ev_par]
            ld b, a
            ld a, [GS + $1B]
            add a, b
            jr nc, .s
            ld a, $FF
.s:         ld [GS + $1B], a
            ret
ev_tcp:     ld a, [ev_par]
            ld b, a
            ld a, [GS + $1B]
            sub b
            jr nc, ev_gcp.s
            call ev_end
            ld a, 0
            ld c, 3
            jp dlg_show
; $EE set guest npc ($600B; its sprite: later)
ev_spec:    ld a, CODE5                     ; $EF special animation (fx.s)
            ld hl, fx_special
            jp far_call
; 3B/A9BA / 3A/901F metatile C <- metatile B (its four tiles, palette, properties)
mt_copy:    ld h, high(M_TL)
            ld d, h
            ld l, b
            ld e, c
            ld b, 7
.c:         ld a, [hl]
            ld [de], a
            inc h
            inc d
            dec b
            jr nz, .c
            ret
; 3A/8FD8 world 3 loaded: the statues destroyed ($602E bits 1-4: metatiles $40-$43 <- 0) and
; Saronia's gate ($602E bit 5: $4A <- 3)
w3_fix:     ld a, [cur_world]
            cp 3
            ret nz
            ld a, [GS + $2E]
            ld [ev_tmp], a
            ld bc, $0040
.s:         ld a, [ev_tmp]
            srl a
            ld [ev_tmp], a
            bit 0, a
            jr z, .n
            push bc
            call mt_copy
            pop bc
.n:         inc c
            ld a, c
            cp $44
            jr nz, .s
            ld a, [GS + $2E]
            bit 5, a
            ret z
            ld bc, $034A
            jp mt_copy
ev_guest:   ld a, [ev_par]                  ; $EE set the guest (3B/B6A5: init, its graphics)
            ld [GS + $0B], a
            and a
            ret z
            call g_init
            jp g_gfx
ev_btl:     ld a, [ev_par]                  ; $F7 battle (3B/B703: after the event)
            ld [act_id], a
            ld a, $20
            ld [act], a
            ret
ev_f8:      ld a, [ev_par]                  ; $F8 song / sound effect (snd.s)
            jp snd_f8

; $00-$BF: object (cmd & $F0) commands; a moving object makes the command wait (3B/ACD1)
ev_npc_cmd: ld a, [ev_cmd]
            and $F0
            ld l, a
            ld h, high(N_OBJ)
            push hl
            ld a, l
            add a, $0C
            ld l, a
            ld a, [hl]
            pop hl
            and a
            jr z, .go
            ld a, [ev_rep]
            inc a
            ld [ev_rep], a
            ret
.go:        ld a, [ev_cmd]
            and $0F
            cp 4
            jr nc, .face
            ld b, a                         ; 0-3 move right / left / down / up (L3B_AFDD)
            ld a, 1
            ld [n_ev], a
            ld a, b
            call npc_dir
            xor a
            ld [n_ev], a
            ret
.face:      cp 8
            jr nc, .s8
            and 3                           ; 4-7: face right / left / down / up
            swap a
            ld b, a
            ld a, l
            add a, $0E
            ld l, a
            ld [hl], b
            ret
.s8:        jr nz, .s9
            ld a, l                         ; 8: show
            add a, $0A
            ld e, a
            ld d, h
            ld a, [de]
            ld [hl], a
            ret
.s9:        cp 9
            jr nz, .sc
            ld [hl], 0                      ; 9: hide
            ret
.sc:        cp $0C
            jr nz, .sd
            inc l                           ; C: continuous animation on
            set 6, [hl]
            ret
.sd:        cp $0D
            jr z, .sd1
            ld b, a                         ; A / B jumps, E circle, F spin (fx.s)
            ld a, l
            ld [fx_slot], a
            ld a, b
            ld hl, fx_jumpl
            cp $0A
            jr z, .fx
            ld hl, fx_jumpr
            cp $0B
            jr z, .fx
            ld hl, fx_circle
            cp $0E
            jr z, .fx
            ld hl, fx_spin
.fx:        ld a, CODE5
            jp far_call
.sd1:       inc l                           ; D: off (and $B0)
            ld a, [hl]
            and $B0
            ld [hl], a
            ret

; $C0-$CF: the party (3B/A13B)
ev_pl_cmd:  and $0F
            cp 4
            jr nc, .f
            ld c, a                         ; C0-C3: a step right / left / down / up
            ld b, 0
            ld hl, .dirs
            add hl, bc
            ld a, [hl]
            ld [ev_pad], a
            ret
.f:         cp 8
            jr nc, .x
            and 3                           ; C4-C7: face
            ld c, a
            ld b, 0
            ld hl, .face
            add hl, bc
            ld a, [hl]
            ld [facing], a
            ret
.x:         cp $0A                          ; CA: the Nautilus (6), CB: the Invincible (7)
            jr z, .v6
            cp $0B
            jr z, .v7
            cp $0F
            jr z, .v1                       ; CF: the chocobo
            cp $08                          ; C8 / C9 show / hide the party, CC / CD the guest
            jr z, .sh7
            cp $09
            jr z, .hd7
            cp $0C
            jr z, .sh6
            cp $0D
            jr z, .hd6
            cp $0E
            ret nz
            xor a                           ; CE: off the vehicle, the Invincible left here
            ld [GS + $0F], a
            ld a, [cur_world]
            ld [GS + $07], a
            ld a, [px]
            ld [GS + $05], a
            ld a, [py]
            ld [GS + $06], a
            ld a, 1
            ld [GS + $04], a
            ret
.sh7:       ld hl, pl_hide
            res 7, [hl]
            ret
.hd7:       ld hl, pl_hide
            set 7, [hl]
            ret
.sh6:       ld hl, pl_hide
            res 6, [hl]
            ret
.hd6:       ld hl, pl_hide
            set 6, [hl]
            ret
.v1:        ld a, 1
            jr .v
.v6:        ld a, 6
            jr .v
.v7:        ld a, 7
.v:         ld [GS + $0F], a
            ret
.dirs:      db $10, $20, $80, $40           ; (pad bits: right, left, down, up)
.face:      db 1, 2, 4, 8

; $D0-$E3 (3B/B555): restores and passage tiles now, the rest later
ev_misc:    ld hl, .fx                      ; D0-D3, DA, E0-E2: the field effects (fx.s)
            ld b, a
.f:         ld a, [hl+]
            and a
            jr z, .nf
            cp b
            jr z, .go
            inc hl
            inc hl
            jr .f
.go:        ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, CODE5
            jp far_call
.fx:        db $D0
            dw fx_shake
            db $D1
            dw fx_flashs
            db $D2
            dw fx_dark
            db $D3
            dw fx_light
            db $DA
            dw fx_dance
            db $E0
            dw fx_pal0
            db $E1
            dw fx_pal1
            db $E2
            dw fx_flash
            db 0
.nf:        ld a, b
            cp $D4
            jr z, ev_hp
            cp $D5
            jr z, ev_mp
            cp $D6
            ld b, $5B
            jr z, ev_pass
            cp $D7
            ld b, $5C
            jr z, ev_pass
            cp $D8
            jp z, start                     ; D8 reset the game
            cp $D9
            jr z, ev_chain
            cp $DB                          ; DB / DC the prologue / epilogue: at the next input
            jr z, ev_cut                    ;   check (fix:E2F8); DD the ending
            cp $DC
            jr z, ev_cut
            cp $DD
            jr z, ev_ending
            cp $DE
            jr z, ev_surf
            cp $DF
            jr z, ev_hp1
            cp $E8
            jr z, ev_stclr
            cp $E9
            jr z, ev_stset
            ret
; $D6 / $D7 open passage tile (3B/B8A6): the first $5B / $5C in the map becomes +2
ev_pass:    ld hl, M_LAY
            ld de, $0400
.s:         ld a, [hl]
            cp b
            jr z, .f
            inc hl
            dec de
            ld a, d
            or e
            jr nz, .s
            ret
.f:         add a, 2
            ld [hl], a
            ld a, l                         ; (x = offset & 31, y = offset / 32)
            and $1F
            ld e, a
            ld a, h
            sub high(M_LAY)
            ld d, a
            ld a, l
            rlca
            rlca
            rlca
            and 7
            ld b, a
            ld a, d
            add a, a
            add a, a
            add a, a
            or b
            ld d, a
            jp q_mt
; $DB / $DC (3B/B5BA): FF3's $50 = $80 / $81, run by the field when it next checks the input
ev_cut:     sub $DB - $80
            ld [cut_req], a
            ret
; $DD the ending (1F/B5B6, then the end credits: it does not return)
ev_ending:  ld a, CODE5
            ld hl, cut_end
            jp far_call
; fix:E2F8 a cutscene pending: it runs, then the map is loaded again (fix:E7F8)
cut_go:     ld b, a
            xor a
            ld [cut_req], a
            ld hl, cut_pro
            ld a, b
            cp $80
            jr z, .g
            ld hl, cut_epi
            cp $81
            jr z, .g
            ld hl, cut_end                  ; ($82: the ending, for tests)
.g:         ld a, CODE5
            call far_call
            ld a, $FF                       ; (no map title)
            ld [m_title], a
            ld [m_title2], a
            jp load_map
; $D9 the ship chained up at (169, 184) on world 3
ev_chain:   ld a, $A9
            ld [GS + $01], a
            ld a, $B8
            ld [GS + $02], a
            ld a, 1
            ld [GS + $00], a
            ld a, 3
            ld [GS + $03], a
            ld a, [GS + $20]
            or $20
            ld [GS + $20], a
            ret
; $DE the surface world emerges (the world 3 from now on)
ev_surf:    ld a, [GS + $11]
            or $80
            ld [GS + $11], a
            ld a, 3
            ld [cur_world], a
            ret
; $DF HP 1 for those at 0
ev_hp1:     ld hl, GS + $10C
            ld b, 4
.l:         ld a, [hl+]
            or [hl]
            dec hl
            jr nz, .n
            ld [hl], 1
.n:         ld a, l
            add a, $40
            ld l, a
            jr nc, .c
            inc h
.c:         dec b
            jr nz, .l
            ret
; $E8 / $E9 clear / set status (all members): $6102 and / or the parameter
ev_stclr:   ld c, 0
            jr ev_st
ev_stset:   ld c, 1
ev_st:      ld hl, GS + $102
            ld b, 4
.l:         ld a, [ev_par]
            ld e, a
            ld a, c
            and a
            ld a, [hl]
            jr z, .and
            or e
            jr .s
.and:       and e
.s:         ld [hl], a
            ld a, l
            add a, $40
            ld l, a
            jr nc, .c
            inc h
.c:         dec b
            jr nz, .l
            jp char_gfx
ev_hp:      ld hl, GS + $10C                ; max HP ($610E) -> HP ($610C), each character
            ld b, 4
.l:         ld a, l
            add a, 2
            ld e, a
            ld d, h
            ld a, [de]
            ld [hl+], a
            inc e
            ld a, [de]
            ld [hl-], a
            ld a, l
            add a, $40
            ld l, a
            jr nc, .n
            inc h
.n:         dec b
            jr nz, .l
            ret
ev_mp:      ld hl, GS + $130                ; MP: 8 levels, current / max pairs ($6130)
            ld b, 4
.c:         push hl
            ld c, 8
.v:         ld a, l
            inc a
            ld e, a
            ld d, h
            ld a, [de]
            ld [hl+], a
            inc l
            dec c
            jr nz, .v
            pop hl
            ld a, l
            add a, $40
            ld l, a
            jr nc, .n2
            inc h
.n2:        dec b
            jr nz, .c
            ret

; $E7 take item (one), $F6 give item (one; "Can't carry anymore." when full: t8000 $90)
ev_take:    call ev_find
            ret c
            ld a, l
            add a, $20
            ld l, a
            ld a, [hl]
            and a
            ret z
            dec [hl]
            ret nz
            ld a, l
            sub $20
            ld l, a
            ld [hl], 0
            ret
ev_give:    call ev_find
            jr nc, .ok
            call ev_end
            ld a, 0
            ld c, $90
            jp dlg_show
.ok:        ld a, [ev_par]
            ld [hl], a
            ld a, l
            add a, $20
            ld l, a
            inc [hl]
            ret
; (3B/B8F0) the item's slot, else the first empty one ($60C0 ids, $60E0 counts); C: none / 99
ev_find:    ld hl, GS + $C0
            ld a, [ev_par]
            ld b, a
.s:         ld a, [hl]
            cp b
            jr z, .have
            inc l
            ld a, l
            cp low(GS + $E0)
            jr nz, .s
            ld l, low(GS + $C0)
.e:         ld a, [hl]
            and a
            ret z                           ; (carry clear)
            inc l
            ld a, l
            cp low(GS + $E0)
            jr nz, .e
            scf
            ret
.have:      ld a, l
            add a, $20
            ld e, a
            ld d, h
            ld a, [de]
            cp 99
            ccf
            ret
; $EA give gil (3B/B7D4: 24 bits at $601C, at most 9999999)
ev_gil:     ld hl, GS + $1D                 ; (FF3 adds the parameter to the middle byte)
            ld a, [ev_par]
            add a, [hl]
            ld [hl+], a
            ld a, [hl]
            adc a, 0
            ld [hl], a
            ret

; $F0 a person's dialogue ($0740 + n; t8400 world 0, t8600), $F1 event dialogue (t8000; then
; the A button: fix:EC9A)
ev_ndlg:    ld a, [ev_par]
            add a, low(EV_DLG)
            ld l, a
            ld h, high(EV_DLG)
            ld c, [hl]
            ld a, [cur_world]
            and a
            ld a, 2
            jr z, .w
            inc a
.w:         jp dlg_show
ev_edlg:    ld a, [ev_par]
            ld c, a
            xor a
            jp dlg_show

; $F2 / $F3 event switches, $F4 / $F5 npc switches (+$20 off world 0)
ev_esw1:    ld a, [ev_par]
            call ev_sw
            ld a, [hl]
            or b
            ld [hl], a
            ret
ev_esw0:    ld a, [ev_par]
            call ev_sw
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ret
ev_nsw:     ld a, [ev_par]                  ; HL = byte, B = bit
            ld c, a
            and 7
            ld b, a
            ld a, 1
            inc b
.m:         dec b
            jr z, .m1
            add a, a
            jr .m
.m1:        ld b, a
            ld a, c
            srl a
            srl a
            srl a
            ld c, a
            ld a, [cur_world]
            and a
            ld a, c
            jr z, .w
            add a, $20
.w:         add a, low(GS + $80)
            ld l, a
            ld h, high(GS + $80)
            ret
ev_nsw1:    call ev_nsw
            ld a, [hl]
            or b
            ld [hl], a
            ret
ev_nsw0:    call ev_nsw
            ld a, b
            cpl
            and [hl]
            ld [hl], a
            ret

; $F9 exit (explicit), $FA entrance (explicit: map), $FB entrance (id), $FD exit to the
; previous map: as the trigger tiles (taken when the event ends: the party stands still)
ev_xexit:   ld a, [ev_par]                  ; (3B/B750: the exit id into $0730)
            ld [map_exit], a
            ld a, $C0
            jr ev_act
ev_xent:    ld a, [ev_par]                  ; (destination map in M_ENT + 48: the entrance 0)
            ld [M_ENT + 48], a
            xor a
            ld [act_id], a
            ld a, $80
            jr ev_act
ev_xmap:    ld a, [ev_par]
            ld [act_id], a
            ldh a, [is_world]
            and a
            ld a, $80
            jr z, ev_act
            ld a, $90
            jr ev_act
ev_exit:    ld a, $40
ev_act:     ld [act], a
            ret

; $FC n: wait n frames (3B/B778)
ev_wait:    ld a, [ev_w75]
            bit 7, a
            jr nz, .c
            ld a, $80
            ld [ev_w75], a
            ld a, [ev_par]
            ld [ev_w74], a
.c:         ld a, [ev_w74]
            sub 1
            ld [ev_w74], a
            jr nc, .again
            xor a
            ld [ev_w75], a
            ret
.again:     ld a, [ev_rep]                  ; (run again next frame)
            inc a
            ld [ev_rep], a
            ret

; $FF end of event
ev_end:     xor a
            ld [ev_on], a
            ret

section wram, $C380
cut_req:    ds 1
ev_on:      ds 1
ev_ptr:     ds 2
ev_rep:     ds 1
ev_cmd:     ds 1
ev_par:     ds 1
ev_w74:     ds 1
ev_w75:     ds 1
ev_pad:     ds 1
ev_npc:     ds 1
n_ev:       ds 1
ev_tmp:     ds 1
tr_t:       ds 1
tr_n2:      ds 1
tr_id2:     ds 1
tr_q:       ds 1
tr_x:       ds 1
tr_y:       ds 1                            ; (npc moves for an event: tile passability only)
