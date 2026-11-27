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
            call npc_find                   ; HL = their slot (3F/E494)
            jp nc, treasure
            ld a, [hl]                      ; the person's id
            ld [ev_who], a
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
            ld a, [ev_who]                  ; inns, shops, the Fat Chocobo (3F/E9D3)
            cp $E0
            jp nc, shop_talk
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

; ---- A on a treasure or a locked door ($3F $E917): D, E = the cell ahead
treasure:   ld a, d
            ld [tr_x], a
            ld a, e
            ld [tr_y], a
            push de
            call map_mt
            pop de
            ld c, a
            ld b, W_PROP1
            ld a, [bc]
            bit 7, a
            ret z
            ld a, c
            cp $90
            ret c
            cp $A0
            jr c, .lock
            cp $D0
            ret c
            cp $F0
            ret nc
            ld [tr_tile], a                 ; $D0-$DF a chest, $E0-$EF another treasure
            inc b
            ld a, [bc]
            and 15
            ld l, a
            ld h, 0
            push de
            ld de, treas
            add hl, de
            pop de
            ld a, [hl]
            ld [tr_id], a
            call tr_switch                  ; Z when taken (not for chests: their tile tells)
            ld a, [tr_tile]
            cp $E0
            jr c, .give
            ld a, [hl]
            and c
            ret z
.give:      ld a, [tr_tile]                 ; a chest on a gil map: the item's price in gil
            cp $E0
            jr nc, .item
            ld a, [map_props + 1]
            and $20
            jr z, .item
            call tr_contents
            ld l, a                         ; price: NES 10/9E00 (B_EVENTS $5E00) + 2 * item
            ld h, 0
            add hl, hl
            ld bc, $5E00
            add hl, bc
            push de
            ld de, dlg_num
            ld bc, 2
            ld a, B_EVENTS
            call far_copy
            pop de
            xor a
            ld [dlg_num + 2], a
            ld hl, SR_GIL                   ; gil += price, at most 9999999 ($98967F)
            ld a, [dlg_num]
            add [hl]
            ld [hl+], a
            ld a, [dlg_num + 1]
            adc [hl]
            ld [hl+], a
            ld a, 0
            adc [hl]
            ld [hl], a
            call gil_cap
            call tr_take
            call tr_open
            ld c, $01                       ; "From inside the treasure chest, you got N Gil!"
            ld b, TB_SYSTEM
            jp dlg_open
.item:      call tr_contents
            ld [dlg_item], a
            ld b, 1                         ; arrows ($4F-$56) come 20 at a time
            cp $4F
            jr c, .q
            cp $57
            jr nc, .q
            ld b, 20
.q:         ld c, a
            call inv_add
            jr nc, .ok
            ld c, $50                       ; "Your inventory is full."
            ld b, TB_SYSTEM
            jp dlg_open
.ok:        call tr_take
            ld a, [tr_tile]
            cp $E0
            ld c, $76                       ; not a chest: "In a place like this, ...!"
            jr nc, .msg
            call tr_open
            ld c, $59                       ; "Inside the treasure chest there was ...!"
            ld a, [tr_id]
            cp $E0
            jr c, .msg
            ld c, $02                       ; (with a battle: the battle comes later)
.msg:       ld b, TB_SYSTEM
            jp dlg_open
.lock:      ld a, [SRAM_PAGE + $0E]         ; a locked door: the walking member a Thief (job 8)?
            add low(SRAM_PAGE + $100)
            ld l, a
            ld h, high(SRAM_PAGE + $100)
            ld a, [hl]
            cp 8
            ld c, $03                       ; "The door is locked!"
            jr nz, .lm
            ld a, [SRAM_PAGE + $21]
            or $40
            ld [SRAM_PAGE + $21], a
            ld c, $7A                       ; "With the Thief's special ability, the lock opened..."
.lm:        ld b, TB_SYSTEM
            jp dlg_open

; HL = the treasure switch byte, C = its mask, for treasure tr_id ($6040: id / 8 (+ 32 off
; world 0), bit id & 7); Z set when the switch is clear (taken)
tr_switch:  ld a, [tr_id]
            ld hl, SR_TREAS
            ld b, a
            ld a, [world]
            and a
            jr z, .w
            ld hl, SR_TREAS + 32
.w:         ld a, b
            call sw_bit
            ld a, [hl]
            and c
            ret
tr_take:    push de
            call tr_switch                  ; (the switch cleared: taken)
            ld a, c
            cpl
            and [hl]
            ld [hl], a
            pop de
            ret
; A = the contents of treasure tr_id (01/9C00 world 0, 01/9D00 others: B_NPCS $6A00 / $6B00)
tr_contents:
            ld a, [tr_id]
            ld l, a
            ld h, $6A
            ld a, [world]
            and a
            jr z, .w
            inc h
.w:         ld a, B_NPCS
            jp far_byte
; the chest at (tr_x, tr_y) shown open: metatile $7D in the map and on screen
tr_open:    ld a, [tr_x]
            ld d, a
            ld a, [tr_y]
            ld e, a
            and 31
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, d
            and 31
            add l
            ld l, a
            ld a, h
            adc high(W_MAP)
            ld h, a
            ld a, $7D
            ld [hl], a
            ld hl, line_buf
            call cell_buf
            ld a, 1
            ld [line_n], a
            ret
gil_cap:    ld hl, SR_GIL + 2               ; at most 9999999 ($98967F)
            ld a, [hl]
            cp $98
            ret c
            jr nz, .cap
            dec hl
            ld a, [hl]
            cp $96
            ret c
            jr nz, .cap2
            dec hl
            ld a, [hl]
            cp $80
            ret c
            jr .cap3
.cap:       dec hl
.cap2:      dec hl
.cap3:      ld hl, SR_GIL
            ld a, $7F
            ld [hl+], a
            ld a, $96
            ld [hl+], a
            ld a, $98
            ld [hl], a
            ret
; add B of item C to the inventory ($3C $9362: the item's slot or the first empty one, at most
; 99); carry set when full
inv_add:    ld hl, SR_ITEMS
            ld e, 32
.f:         ld a, [hl]
            cp c
            jr z, .add
            inc l
            dec e
            jr nz, .f
            ld hl, SR_ITEMS
            ld e, 32
.e:         ld a, [hl]
            and a
            jr z, .new
            inc l
            dec e
            jr nz, .e
            scf
            ret
.new:       ld [hl], c
.add:       ld a, l
            add 32
            ld l, a
            ld a, [hl]
            add b
            cp 99
            jr c, .s
            ld a, 99
.s:         ld [hl], a
            and a
            ret

; the map's event trigger A (index into its trigger list) -> its script ($3F $E6BE / $E6C6:
; 2C/8880 pointers, the vehicle / status switches first) -> the event
trig_event: ld e, a
            ld d, 0
            ld hl, trigs
            add hl, de
            ld a, [hl]
trig_script:                                ; (trigger script A: world map triggers use it)
            ld c, a
            ld b, 0
            ld hl, $4880
            add hl, bc
            add hl, bc
            call scr_ptr
            ld de, scr_buf
            ld bc, 64
            ld a, B_SCRIPT
            call far_copy
            call ev_vsw
            call scr_event
            jp ev_start

; FF3's vehicle / status switches before a trigger script ($3C $9274): $602E bits 6 / 7 all
; members toad / mini, $6021 bit 7 the chocobo, $602F bits 2-5 the vehicles (on foot: none)
ev_vsw:     ld a, [SRAM_PAGE + $102]
            ld b, a
            ld a, [SRAM_PAGE + $142]
            and b
            ld b, a
            ld a, [SRAM_PAGE + $182]
            and b
            ld b, a
            ld a, [SRAM_PAGE + $1C2]
            and b
            ld b, a
            and $20
            add a
            ld c, a
            ld a, b
            and $08
            swap a
            add a
            or c
            ld c, a
            ld a, [SRAM_PAGE + $2E]
            and $3F
            or c
            ld [SRAM_PAGE + $2E], a
            ld a, [SRAM_PAGE + $21]
            and $7F
            ld [SRAM_PAGE + $21], a
            ld a, [SRAM_PAGE + $2F]
            and $C3
            ld [SRAM_PAGE + $2F], a
            ret

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
            jr nc, .e4
            sub $D0                         ; $D0-$E3 (3B/B567, no argument)
            add a
            ld e, a
            ld d, 0
            ld hl, evd_table
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl
.e4:        sub $E4
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

evd_table:  dw ev_shake, ev_flash, ev_dark, ev_undark    ; D0-D3 (src/evfx.s)
            dw ev_hpall, ev_mpall, ev_pfloor, ev_pwall   ; D4-D7
            dw ev_reset, ev_chain, ev_dance, ev_prol     ; D8-DB
            dw ev_epi, ev_ending, ev_surf, ev_hp1        ; DC-DF
            dw ev_repal, ev_repal, ev_flash2, ev_none    ; E0-E3
evc_table:  dw ev_none, ev_none, ev_none, ev_take        ; E4-E7
            dw ev_stclr, ev_stset, ev_gil, ev_ungil      ; E8-EB
            dw ev_cp, ev_uncp, ev_guest, ev_none         ; EC-EF (special animation: later)
            dw ev_npcdlg, ev_evdlg, ev_seton, ev_setoff  ; F0-F3
            dw ev_npcon, ev_npcoff, ev_give, ev_battle   ; F4-F7
            dw ev_sound, ev_exit, ev_enter, ev_enterm    ; F8-FB
            dw ev_wait, ev_prev, ev_none, ev_end         ; FC-FF
ev_none:    ret

; $DB / $DC: FF3's prologue / epilogue (src/cut.s), then the map again with its people
ev_prol:    %FAR B_CUT, cut_pro
            jr ev_cutx
ev_epi:     %FAR B_CUT, cut_epi
ev_cutx:    ld a, [pos_x]
            ld [enter_x], a
            ld a, [pos_y]
            ld [enter_y], a
            call keep_people
            jp map_change
; $DD: FF3's ending and end credits (src/cutend.s); it ends on The End (soft reset to leave)
ev_ending:  %FAR B_CUT, cut_end
            jr ev_ending
; $D4 / $D5: everyone's HP / MP to max (3B/B881 / B862)
ev_hpall:   ld hl, SRAM_PAGE + $10C
.m:         ld a, l
            add 2
            ld e, a
            ld d, h
            ld a, [de]
            ld [hl+], a
            inc e
            ld a, [de]
            ld [hl-], a
            ld a, l
            add $40
            ld l, a
            jr nc, .m
            ret
ev_mpall:   ld c, 4
            ld hl, SRAM_PAGE + $130
.c:         ld b, 8
.m:         inc l
            ld a, [hl-]
            ld [hl+], a
            inc l
            dec b
            jr nz, .m
            ld a, l
            add $30
            ld l, a
            dec c
            jr nz, .c
            ret
; $D6 / $D7: a passage opens (3B/B8A6: the first map tile $5B / $5C becomes + 2)
ev_pfloor:  ld a, $5B
            jr ev_pass
ev_pwall:   ld a, $5C
ev_pass:    ld b, a
            ld hl, W_MAP
.f:         ld a, [hl]
            cp b
            jr z, .t
            inc hl
            ld a, h
            cp high(W_MAP) + 4
            jr c, .f
            ret
.t:         add 2
            ld [hl], a
            ld a, l
            and 31
            ld d, a
            ld a, l
            and $E0
            ld e, a
            ld a, h
            sub high(W_MAP)
            ld b, 5
.y:         srl a                           ; E = the row: (HL - W_MAP) / 32
            rr e
            dec b
            jr nz, .y
            ld hl, line_buf
            call cell_buf
            ld a, 1
            ld [line_n], a
            ret
; $D8: reset (3B/B5B7: the program's start)
ev_reset:   jp soft_reset
; $D9: the ship chained up (3B/B5BA: vehicle 1 at (169, 184) on world 3, switch $6020 bit 5)
ev_chain:   ld a, $A9
            ld [SRAM_PAGE + $01], a
            ld a, $B8
            ld [SRAM_PAGE + $02], a
            ld a, 1
            ld [SRAM_PAGE + $00], a
            ld a, 3
            ld [SRAM_PAGE + $03], a
            ld hl, SRAM_PAGE + $20
            set 5, [hl]
            ret
; $DE: the surface world emerges (3B/B5EF: $6011 bit 7, world 3)
ev_surf:    ld hl, SRAM_PAGE + $11
            set 7, [hl]
            ld a, 3
            ld [world], a
            ret
; $DF: HP 0 -> 1 for everyone (3B/B5FC)
ev_hp1:     ld hl, SRAM_PAGE + $10C
.m:         ld a, [hl+]
            or [hl]
            dec l
            jr nz, .n
            ld [hl], 1
.n:         ld a, l
            add $40
            ld l, a
            jr nc, .m
            ret
; $E8 / $E9: status off / on for everyone (3B/B7B0: AND A, B7C2: OR A)
ev_stclr:   ld b, a
            ld hl, SRAM_PAGE + $102
.m:         ld a, [hl]
            and b
            ld [hl], a
            ld a, l
            add $40
            ld l, a
            jr nc, .m
            ret
ev_stset:   ld b, a
            ld hl, SRAM_PAGE + $102
.m:         ld a, [hl]
            or b
            ld [hl], a
            ld a, l
            add $40
            ld l, a
            jr nc, .m
            ret
; $EA: gil + A x 256 (3B/B7D4: $601D / $601E, at most 9999999)
ev_gil:     ld hl, SR_GIL + 1
            add [hl]
            ld [hl+], a
            ld a, [hl]
            adc 0
            ld [hl], a
            jp gil_cap
; $EB: gil - A x 256; too little: the event ends with story text 2 (3B/B80D)
ev_ungil:   ld b, a
            ld a, [SR_GIL + 2]
            and a
            jr nz, .ok
            ld a, [SR_GIL + 1]
            cp b
            jr nc, .ok
            call ev_end
            ld a, 2
            jp ev_evdlg
.ok:        ld hl, SR_GIL + 1
            ld a, [hl]
            sub b
            ld [hl+], a
            ld a, [hl]
            sbc 0
            ld [hl], a
            ret nc
            xor a
            ld [SR_GIL], a
            ld [SR_GIL + 1], a
            ld [SR_GIL + 2], a
            ret
; $EC / $ED: CP + A (at most 255) / - A (too little: story text 3) (3B/B840, B84E)
ev_cp:      ld hl, SRAM_PAGE + $1B
            add [hl]
            jr nc, .s
            ld a, $FF
.s:         ld [hl], a
            ret
ev_uncp:    ld b, a
            ld a, [SRAM_PAGE + $1B]
            sub b
            jr nc, .s
            call ev_end
            ld a, 3
            jp ev_evdlg
.s:         ld [SRAM_PAGE + $1B], a
            ret
; $EE: the guest ($600B; their picture: later)
ev_guest:   ld [SRAM_PAGE + $0B], a
            ret

; $F7: a battle ($3B $B70F), the event going on after it
ev_battle:  ld [bs_id], a
            jp battle_run

; $F8: a song ($00-$7C), $7D fade out, $7E the song before, $7F stop; $80+: a sound effect ($3B $B71C)
ev_sound:   bit 7, a
            jr nz, .sfx
            cp $7D
            jp c, mus_play
            jr z, .fade
            cp $7E
            ld a, 2
            jr z, .c
            ld a, 4
.c:         ld [M_CTRL], a
            ret
.fade:      ld a, $37
            ld [M_SONG], a
            ld a, $0C
            jr .c
.sfx:       and $7F
            jp sfx_play

; ---- the map's song ($3F $E8CE: properties byte 10; bit 7: the conditional script $38 + (song & 7)
; at 2C/8870 gives it); the world map's by world and vehicle ($3B $A006)
map_song:   call enc_setrate
            ld a, [wmode]
            and a
            jr nz, .world
            ld a, [map_props + 10]
            bit 7, a
            jp z, mus_play
            and 7
            add $38
            ld c, a
            ld b, 0
            ld hl, $4870
            add hl, bc
            add hl, bc
            call scr_ptr
            ld de, scr_buf
            ld bc, 64
            ld a, B_SCRIPT
            call far_copy
            call scr_event
            jp mus_play
.world:     ld a, [world]
            and a
            jr z, .w
            dec a
.w:         add a
            add a
            ld e, a                         ; + the vehicle (3B/A006)
            ld a, [veh]
            add e
            ld e, a
            ld d, 0
            ld hl, w_songs
            add hl, de
            ld a, [hl]
            jp mus_play
w_songs:    ds 32                           ; (FF3's table 3B/A027, from the ROM at build time)

ev_npcdlg:  ld e, a                         ; $F0: the person's dialogue (their list, entry A)
            ld d, 0
            ld hl, dlg_list
            add hl, de
            ld c, [hl]
            jr ev_dlg
ev_evdlg:   ld c, a                         ; $F1: an event dialogue: the story table 18/8000
            ld b, TB_STORY                  ;   ($3B $B6D5 jumps past the world test with $80)
            jp dlg_open
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
            jp npc_unface
ev_again:   ld a, [ev_ptr]                  ; run this command again next frame
            sub 2
            ld [ev_ptr], a
            ret nc
            ld hl, ev_ptr + 1
            dec [hl]
            ret

; $00-$BF: person (A >> 4) does A & 15: 0-3 move right / left / down / up, 4-7 face, 8 show,
; 9 hide, A-F jumps, animation, circle, spin ($3B $ACD1)
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
            jp nz, ev_npcx                  ; ($0A-$0F: src/evfx.s)
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
.sh:        cp $0A                          ; $CA Nautilus, $CB Invincible, $CF chocobo, $CE
            ld b, 6                         ;   off the Invincible, parked here (3B/A16D-A1C8;
            jr z, .v                        ;   $C8 / $C9 show / hide: later)
            cp $0B
            ld b, 7
            jr z, .v
            cp $0F
            ld b, 1
            jr z, .v
            cp $0E
            ret nz
            ld a, [world]
            ld [SRAM_PAGE + $07], a
            ld a, [pos_x]
            ld [SRAM_PAGE + $05], a
            ld a, [pos_y]
            ld [SRAM_PAGE + $06], a
            ld a, 1
            ld [SRAM_PAGE + $04], a
            ld b, 0
.v:         ld a, b
            ld [veh], a
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
tr_tile:    ds 1
tr_id:      ds 1
tr_x:       ds 1
tr_y:       ds 1
