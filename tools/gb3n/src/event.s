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
            jp treasure                     ; (no one: treasures, locked doors: fix:E917)
.found:     ld a, [hl]                      ; the npc's script: 2C/8200 (world 0) / 2C/8400
            ld [ev_npc], a
            cp $E0
            ret nc                          ; (inns, shops, the fat chocobo: later)
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
            ld a, $02                       ; (with a battle: later)
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
            dw ev_none, ev_none, ev_gil, ev_none     ; E8-EB (status: later; take gil later)
            dw ev_none, ev_none, ev_none, ev_none    ; EC-EF (cp, guest npc, animations: later)
            dw ev_ndlg, ev_edlg, ev_esw1, ev_esw0    ; F0-F3
            dw ev_nsw1, ev_nsw0, ev_give, ev_none    ; F4-F7 (battle: later)
            dw ev_f8, ev_xexit, ev_xent, ev_xmap     ; F8-FB
            dw ev_wait, ev_exit, ev_none, ev_end     ; FC-FF
ev_none:    ret
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
            ret nz                          ; (A / B jumps, E / F circles: later)
            inc l                           ; D: off (and $B0)
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
.x:         ret                             ; (show / hide, vehicles, guest: later)
.dirs:      db $10, $20, $80, $40           ; (pad bits: right, left, down, up)
.face:      db 1, 2, 4, 8

; $D0-$E3 (3B/B555): restores and passage tiles now, the rest later
ev_misc:    cp $D4
            jr z, ev_hp
            cp $D5
            jr z, ev_mp
            ret
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
ev_xexit:   ld a, $C0
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
