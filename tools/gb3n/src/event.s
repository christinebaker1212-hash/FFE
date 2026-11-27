; FF3's events on normal maps: talking to people ($3F $EA26, $E9BB), the conditional scripts
; ($3C $92F3 / $9319: switch tests, then $FF and an event id; a person's dialogue list after the
; last block), and the event runner ($3E $D219: one command a frame; $3B $A12B commands).
; Scripts are in B_SCRIPT (NES banks $2C/$2D as one bank: NES $8000-$BFFF -> $4000-$7FFF).

SR_EVSW    = SRAM_PAGE + $20            ; event switches ($6020)
SR_ITEMS   = SRAM_PAGE + $C0            ; inventory ids ($60C0) and counts ($60E0)
SR_GIL     = SRAM_PAGE + $1C            ; (gil: 3 bytes at $601C)

section bank B_FIELD, $6C00
; ---- A pressed while standing: a person ahead? run their script
talk:       call dest_cell
            call npc_at                     ; HL = their slot
            ret nc
            ld a, [hl]                      ; the person's id
            ld [ev_who], a
            cp $E0                          ; (inns, shops, the fat chocobo: later)
            ret nc
            ld c, a
            ld b, 0
            ld hl, $4200                    ; trigger scripts: NES 2C/8200 (world 0) / 2C/8400
            ld a, [world]
            and a
            jr z, .w0
            ld hl, $4400
.w0:        add hl, bc
            add hl, bc
            call scr_ptr
            ld de, scr_buf                  ; 64 bytes of it
            ld bc, 64
            ld a, B_SCRIPT
            call far_copy
            ld hl, scr_buf                  ; the dialogue list: after the first unconditional
.f:         ld a, [hl]                      ;   block ($FF, event)
            cp $FF
            jr z, .fd
.fs:        inc hl
            ld a, [hl]
            cp $FF
            jr nz, .fs
            inc hl
            inc hl
            jr .f
.fd:        inc hl
            inc hl
            ld de, dlg_list
            ld bc, 32
            call memcpy
            call scr_event                  ; A = the event chosen by the switch tests
            jp ev_start

; the NES pointer at HL in B_SCRIPT -> HL = its address in B_SCRIPT
scr_ptr:    ld de, ev_tmp
            ld bc, 2
            ld a, B_SCRIPT
            call far_copy
            ld a, [ev_tmp]
            ld l, a
            ld a, [ev_tmp + 1]
            ld h, a
scr_addr:   ld a, h
            and $3F
            or $40
            ld h, a
            ret

; the conditional script in scr_buf: the first block whose switch tests all pass -> its event
scr_event:  ld hl, scr_buf
.b:         ld a, [hl+]
            cp $FF
            jr z, .ev
            ld b, a
            call ev_switch
            ld a, 0
            jr z, .z
            inc a                           ; A = 1: the switch is on
.z:         bit 7, b
            jr z, .off
            and a                           ; msb set: needs the switch on
            jr nz, .b
            jr .skip
.off:       and a                           ; msb clear: needs it off
            jr z, .b
.skip:      ld a, [hl+]
            cp $FF
            jr nz, .skip
            inc hl
            jr .b
.ev:        ld a, [hl]
            ret

; Z clear when event switch B & $7F is on (SR_EVSW bit field)
ev_switch:  push hl
            ld a, b
            and 7
            ld c, a
            ld a, 1
            inc c
.m:         dec c
            jr z, .g
            add a
            jr .m
.g:         ld c, a
            ld a, b
            and $7F
            srl a
            srl a
            srl a
            add low(SR_EVSW)
            ld l, a
            ld h, high(SR_EVSW)
            ld a, [hl]
            and c
            pop hl
            ret

; event switch (A) on / off; npc switch on / off (as $3B $B983 / $B999 / $B9B1 / $B9E1)
sw_bit:     ld b, a                         ; HL = byte, C = mask for bit A of the field at HL
            and 7
            ld c, a
            ld a, 1
            inc c
.m:         dec c
            jr z, .g
            add a
            jr .m
.g:         ld c, a
            ld a, b
            srl a
            srl a
            srl a
            add l
            ld l, a
            ret nc
            inc h
            ret

; ---- start event A (2C/8600 pointers)
ev_start:   and a
            ret z
            ld c, a
            ld b, 0
            ld hl, $4600
            add hl, bc
            add hl, bc
            call scr_ptr
            ld a, l
            ld [ev_ptr], a
            ld a, h
            ld [ev_ptr + 1], a
            xor a
            ld [ev_rep], a
            ld [ev_wcnt], a
            inc a
            ld [ev_on], a
            ret

; ---- one event command (a frame; not while the dialogue box is open)
ev_step:    ld a, [ev_rep]                  ; a repeated command again
            and a
            jr z, .rd
            dec a
            ld [ev_rep], a
            jp ev_exec
.rd:        ld a, [ev_ptr]                  ; (the next 2 bytes from B_SCRIPT)
            ld l, a
            ld a, [ev_ptr + 1]
            ld h, a
            push hl
            ld de, ev_tmp
            ld bc, 2
            ld a, B_SCRIPT
            call far_copy
            pop hl
            inc hl
            ld a, [ev_tmp]
            cp $FE                          ; repeat: the command before (count - 1) more times
            jr nz, .one
            inc hl
            ld a, [ev_tmp + 1]
            dec a
            ld [ev_rep], a
            jr .sv
.one:       ld [ev_cmd], a
            ld b, a
            ld a, [ev_tmp + 1]
            ld [ev_arg], a
            ld a, b
            cp $E4                          ; $E4-$FC take an argument
            jr c, .sv
            cp $FD
            jr nc, .sv
            inc hl
.sv:        ld a, l
            ld [ev_ptr], a
            ld a, h
            ld [ev_ptr + 1], a
            ld a, [ev_cmd]
            cp $FE
            ret z

ev_exec:    ld a, [ev_cmd]
            cp $C0
            jp c, ev_npc
            cp $D0
            jp c, ev_player
            cp $E4
            ret c                           ; ($D0-$E3: screen effects, healing: later)
            sub $E4
            add a
            ld e, a
            ld d, 0
            ld hl, evc_table
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, [ev_arg]
            jp hl

evc_table:  dw ev_none, ev_none, ev_none, ev_take        ; E4-E7
            dw ev_none, ev_none, ev_none, ev_none        ; E8-EB (status, gil: later)
            dw ev_none, ev_none, ev_none, ev_none        ; EC-EF (cp, guest, animation)
            dw ev_npcdlg, ev_evdlg, ev_seton, ev_setoff  ; F0-F3
            dw ev_npcon, ev_npcoff, ev_give, ev_none     ; F4-F7 (battle: later)
            dw ev_none, ev_exit, ev_enter, ev_enterm     ; F8-FB (sound: later)
            dw ev_wait, ev_prev, ev_none, ev_end         ; FC-FF
ev_none:    ret

ev_npcdlg:  ld e, a                         ; $F0: the person's dialogue (their list, entry A)
            ld d, 0
            ld hl, dlg_list
            add hl, de
            ld c, [hl]
            jr ev_dlg
ev_evdlg:   ld c, a                         ; $F1: an event dialogue
ev_dlg:     ld b, TB_DLG1                   ; dialogue tables 18/8400 (world 0) / 18/8600
            ld a, [world]
            and a
            jr z, .w
            ld b, TB_DLG2
.w:         jp dlg_open
ev_seton:   ld hl, SR_EVSW
            call sw_bit
            ld a, [hl]
            or c
            ld [hl], a
            ret
ev_setoff:  ld hl, SR_EVSW
            call sw_bit
            ld a, c
            cpl
            and [hl]
            ld [hl], a
            ret
ev_npcon:   call npc_swaddr
            ld a, [hl]
            or c
            ld [hl], a
            ret
ev_npcoff:  call npc_swaddr
            ld a, c
            cpl
            and [hl]
            ld [hl], a
            ret
npc_swaddr: ld hl, SR_NPCSW             ; (+ 32 bytes off world 0)
            ld b, a
            ld a, [world]
            and a
            ld a, b
            jr z, sw_bit
            ld hl, SR_NPCSW + 32
            jr sw_bit
ev_give:    ld b, a                         ; $F6: an item (no room: "Can't carry anymore.")
            ld hl, SR_ITEMS
            ld c, 32
.f:         ld a, [hl]
            cp b
            jr z, .add
            inc l
            dec c
            jr nz, .f
            ld hl, SR_ITEMS
            ld c, 32
.e:         ld a, [hl]
            and a
            jr z, .new
            inc l
            dec c
            jr nz, .e
            call ev_end
            ld c, $90
            jr ev_dlg
.new:       ld [hl], b
.add:       ld a, l
            add 32
            ld l, a
            ld a, [hl]
            cp 99
            ret nc
            inc [hl]
            ret
ev_take:    ld b, a                         ; $E7: take an item
            ld hl, SR_ITEMS
            ld c, 32
.f:         ld a, [hl]
            cp b
            jr z, .t
            inc l
            dec c
            jr nz, .f
            ret
.t:         ld a, l
            add 32
            ld l, a
            dec [hl]
            ret nz
            ld a, l
            sub 32
            ld l, a
            ld [hl], 0
            ret
ev_exit:    ld a, TR_WORLD                  ; $F9 / $FD / $FA / $FB: map changes after the event
            jr ev_trig
ev_prev:    ld a, TR_PREV
            jr ev_trig
ev_enter:   ld [ents], a                    ; $FA: entrance to map A
            xor a
            ld [trig_id], a
            ld a, TR_ENTER
            jr ev_trig
ev_enterm:  ld [trig_id], a                 ; $FB: the map's entrance A
            ld a, TR_ENTER
ev_trig:    ld [trig], a
            ret
ev_wait:    ld a, [ev_wcnt]                 ; $FC: wait A frames
            and a
            jr nz, .w
            ld a, [ev_arg]
            inc a
            ld [ev_wcnt], a
.w:         dec a
            ld [ev_wcnt], a
            ret z
            jr ev_again
ev_end:     xor a                           ; $FF: the event's end
            ld [ev_on], a
            ret
ev_again:   ld a, [ev_ptr]                  ; run this command again next frame
            sub 2
            ld [ev_ptr], a
            ret nc
            ld hl, ev_ptr + 1
            dec [hl]
            ret

; $00-$BF: person (A >> 4) does A & 15: 0-3 move right / left / down / up, 4-7 face, 8 show,
; 9 hide ($3B $ACD1; jumps, circles, dances: later)
ev_npc:     ld a, [ev_cmd]
            and $F0
            ld l, a
            ld h, high(NPC1)
            ld a, l
            add 12
            ld e, a
            ld d, h
            ld a, [de]                      ; moving: this command again next frame
            and a
            jr z, .go
            ld a, 1
            ld [ev_rep], a
            ret
.go:        ld a, [ev_cmd]
            and 15
            cp 4
            jp c, npc_move
            cp 8
            jr nc, .sh
            and 3                           ; face: right, left, down, up -> pose offsets
            swap a
            ld e, a
            ld a, l
            add 14
            ld l, a
            ld [hl], e
            ret
.sh:        jr nz, .hi
            ld a, l                         ; 8: show (id from +10)
            add 10
            ld e, a
            ld d, h
            ld a, [de]
            ld [hl], a
            ret
.hi:        cp 9
            ret nz
            ld [hl], 0
            ret

; $C0-$CF: the party: $C0-$C3 move (as the pad), $C4-$C7 face, $C8 / $C9 show / hide
ev_player:  ld a, [ev_cmd]
            and 15
            cp 8
            jr nc, .sh
            and 3
            ld e, a
            ld d, 0
            ld hl, ev_dirs
            add hl, de
            ld a, [hl]
            ld b, a
            ld a, [ev_cmd]
            and 4
            jr nz, .face
            ld a, b                         ; a step, as if pressed
            ld [ev_pad], a
            ret
.face:      ld a, b
            ld [facing], a
            ret
.sh:        sub 8
            ret nz
            ret
ev_dirs:    db DIR_R, DIR_L, DIR_D, DIR_U

section wram, $C240
ev_on:      ds 1
ev_ptr:     ds 2
ev_cmd:     ds 1
ev_arg:     ds 1
ev_rep:     ds 1
ev_wcnt:    ds 1
ev_who:     ds 1
ev_pad:     ds 1
scr_buf:    ds 64
dlg_list:   ds 32
ev_tmp:     ds 2
