; FF3 native port: the event system, written from what the everything8215/ff3 listing says FF3 does
; (build/ref/ff3: ff3j.asm and ff3j-event.txt). Our own code. FF3's state keeps FF3's layout: its
; zero page in Z (Z + $6C is FF3's $6C), its $0700 page in T07, its save page in SV (WRAM bank 1),
; its objects ($7000 / $7100) in O0 / O1, its trigger script buffer ($7B00) in TS7B.
; Scripts (NES banks 2C / 2D) are copied from the user's ROM into ROM bank SCRIPT at $4000 (NES
; $8000-$BFFF -> GB $4000-$7FFF: an NES address - $4000).

Z          = $CB00          ; FF3's zero page
O0         = $CC00          ; FF3 $7000: objects (12 x 16)
O1         = $CD00          ; FF3 $7100
T07        = $CE00          ; FF3 $0700: +$00 entrances, +$10 treasures, +$20 triggers, +$30 the
                            ;   map exit, +$40 npc dialogue / trigger counts, +$60 per type
TS7B       = $C980          ; FF3 $7B00: the trigger script being checked (64)
z17        = Z + $17        ; event repeat counter
z20        = Z + $20        ; FF3's joypad: A $80 B $40 Select $20 Start $10 U 8 D 4 L 2 R 1
z21        = Z + $21
z22        = Z + $22        ; Select / Start / A / B pressed (latched until used)
z23        = Z + $23
z24        = Z + $24
z25        = Z + $25
z33        = Z + $33        ; facing (right 1, left 2, down 4, up 8)
z43        = Z + $43        ; the layer priority
z44        = Z + $44        ; the tile's property bytes
z45        = Z + $45
z4A        = Z + $4A        ; the npc whose random movement is next
z4B        = Z + $4B        ; map title ($FF: none)
z50        = Z + $50        ; shop / prologue / epilogue request
z6A        = Z + $6A        ; battle id
z6C        = Z + $6C        ; event running
z70        = Z + $70        ; the event command and its argument
z71        = Z + $71
z72        = Z + $72        ; the event script pointer (GB address in bank SCRIPT)
z73        = Z + $73
z74        = Z + $74        ; wait counter / flag
z75        = Z + $75
z76        = Z + $76        ; dialogue pending (id)
z7D        = Z + $7D        ; an event dialogue (waits for A)
z7E        = Z + $7E        ; bit 7 the player hidden, bit 6 the guest hidden
z84        = Z + $84
z85        = Z + $85
z86        = Z + $86
z94        = Z + $94        ; the dialogue table (low, high: FF3's $8200 / $8400 / $8600)
z95        = Z + $95
zA5        = Z + $A5        ; z-level
zAB        = Z + $AB        ; the trigger stepped on
zF0        = Z + $F0        ; frame counter
zF4        = Z + $F4        ; random number index (npcs)

section bank 0, $0D00

; ---- FF3 execute event (3E/C72C): A = event id -> the script pointer (2C/8600), running
ev_start:   ld l, a
            ld h, 0
            add hl, hl
            ld de, $8600 - $4000
            add hl, de
            ld a, SCRIPT
            call sbank
            ld a, [hl+]
            ld [z72], a
            ld a, [hl]
            sub $40
            ld [z73], a
            ld a, 1
            ld [z6C], a
            xor a
            ld [z17], a
            ret

; ---- FF3 execute event script / update joypad input (3E/D219): one event command a call while an
; event runs, else the joypad into FF3's bytes
ev_step:    ld a, [z6C]
            and a
            jp z, joy_ff3
            ld a, [z17]                     ; a repeat: the same command again
            and a
            jr z, .rd
            dec a
            ld [z17], a
            jr ev_cmd
.rd:        ld a, SCRIPT
            call sbank
            ld a, [z72]
            ld l, a
            ld a, [z73]
            ld h, a
            ld a, [hl+]
            cp $FE                          ; $FE nn: repeat the next command nn times
            jr nz, .c
            ld a, [hl]
            dec a
            ld [z17], a
            ld de, 2
            jr .adv
.c:         ld [z70], a
            ld b, a
            ld a, [hl]
            ld [z71], a
            ld de, 1                        ; $00-$E3, $FD, $FF: one byte; $E4-$FC: two
            ld a, b
            cp $E4
            jr c, .a1
            cp $FD
            jr nc, .a1
            inc e
.a1:        ld a, [z72]
            add a, e
            ld [z72], a
            ld a, [z73]
            adc a, d
            ld [z73], a
            jr ev_cmd
.adv:       ld a, [z72]
            add a, e
            ld [z72], a
            ld a, [z73]
            adc a, d
            ld [z73], a
            ret

; FF3 execute event command (3B/A067): the buttons cleared, then by command
ev_cmd:     xor a
            ld [z24], a
            ld [z25], a
            ld [z23], a
            ld [z22], a
            ld [z20], a
            ld a, [z70]
            cp $C0
            jp c, npc_cmd                   ; $00-$BF: an object's command (npc.s)
            cp $D0
            jr nc, .hi
            and $0F                         ; $C0-$CF: the player
            cp 4
            jr nc, .face
            call ev_dbit                    ; $C0-$C3: a step (FF3: the joypad set)
            ld [z20], a
            ret
.face:      cp 8
            jr nc, .c8
            and 3
            call ev_dbit
            ld [z33], a
            ret
.c8:        jr nz, .c9
            ld hl, z7E                      ; show / hide the player
            res 7, [hl]
            ret
.c9:        cp 9
            jr nz, .cc
            ld hl, z7E
            set 7, [hl]
            ret
.cc:        cp $0C                          ; show / hide the guest
            jr nz, .cd
            ld hl, z7E
            res 6, [hl]
            ret
.cd:        cp $0D
            ret nz                          ; ($CA / $CB / $CE / $CF: vehicles, with the world map)
            ld hl, z7E
            set 6, [hl]
            ret
.hi:        sub $D0                         ; $D0-$FF by table
            ld l, a
            ld h, 0
            add hl, hl
            ld de, ev_tab
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            jp hl

; A = 0-3 -> FF3's direction bit (right 1, left 2, down 4, up 8: 3B/A1CA)
ev_dbit:    ld b, a
            ld a, 1
            inc b
.l:         dec b
            ret z
            add a, a
            jr .l

ev_tab:     dw ev_d0, ev_d1, ev_d2, ev_d3                   ; $D0-$D3 shake, flash, darken, restore
            dw ev_d4, ev_d5, ev_d6, ev_d7                   ; $D4-$D7
            dw ev_nop, ev_nop, ev_nop, ev_db                ; $D8-$DB reset, ship, dance, prologue
            dw ev_dc, ev_dd, ev_nop, ev_df                  ; $DC-$DF
            dw ev_e0, ev_e0, ev_e2, ev_nop                  ; $E0-$E3
            dw ev_nop, ev_nop, ev_nop, ev_e7                ; $E4-$E7
            dw ev_e8, ev_e9, ev_ea, ev_eb                   ; $E8-$EB
            dw ev_nop, ev_nop, ev_nop, ev_ef                ; $EC-$EF
            dw ev_f0, ev_f1, ev_f2, ev_f3                   ; $F0-$F3
            dw ev_f4, ev_f5, ev_f6, ev_f7                   ; $F4-$F7
            dw ev_f8, ev_f9, ev_fa, ev_fb                   ; $F8-$FB
            dw ev_fc, ev_fd, ev_nop, ev_ff                  ; $FC-$FF

ev_nop:     ret

; $D4 / $D5: every character's HP / MP to the maximum (3B/B881 / B862)
ev_d4:      ld hl, SV + $102                ; (not the dead or stone: $02 & $C0)
            ld b, 4
.l:         ld a, [hl]
            and $C0
            jr nz, .n
            push hl
            ld de, $0C
            add hl, de
            ld a, [hl+]                     ; max ($0E / $0F) -> current ($0C / $0D)
            ld e, a
            ld a, [hl]
            dec hl
            dec hl
            ld [hl-], a
            ld [hl], e
            pop hl
.n:         ld de, $40
            add hl, de
            dec b
            jr nz, .l
            ret
ev_d5:      ld hl, SV + $130                ; (8 levels: current = max)
            ld c, 4
.c:         push hl
            ld b, 8
.l:         inc hl
            ld a, [hl-]
            ld [hl+], a
            inc hl
            dec b
            jr nz, .l
            pop hl
            ld de, $40
            add hl, de
            dec c
            jr nz, .c
            ret

; $D6 / $D7: the passage opens: the tile in front becomes $5B / $5C (3B/B8A6)
ev_d6:      ld a, $5B
            jr ev_d67
ev_d7:      ld a, $5C
ev_d67:     push af
            ld a, [z33]
            call dir_dxy
            ld a, [px]
            add a, b
            and 63
            ld e, a
            ld a, [py]
            add a, c
            and 63
            ld d, a
            pop af
            push de
            call map_set
            pop de
            jp q_mt

; $DB / $DC: the prologue / epilogue (FF3 $50 = $80 / $81)
ev_db:      ld a, $80
            ld [z50], a
            ret
ev_dc:      ld a, $81
            ld [z50], a
            ret

; $DD: the ending (3B/B5E4: 1F/BFFD; the kept cutscene)
ev_dd:      call ev_ff
            ld hl, cut_end
            ld b, B_CUT
            jp full_run

; $DF: every character with 0 HP to 1 (3B/B5FC)
ev_df:      ld hl, SV + $10C
            ld b, 4
.l:         ld a, [hl+]
            or [hl]
            dec hl
            jr nz, .n
            ld [hl], 1
.n:         ld de, $40
            add hl, de
            dec b
            jr nz, .l
            ret

; $E0 / $E1: the map's palettes again
ev_e0:      jp load_pal

; $E7 nn: take item nn (3B/B673)
ev_e7:      ld a, [z71]
            call inv_find
            ret c
            ld hl, SV + $E0
            add hl, de
            ld a, [hl]
            and a
            ret z
            dec [hl]
            ret nz
            ld hl, SV + $C0
            add hl, de
            ld [hl], 0
            ret

; $E8 / $E9 nn: clear (AND nn) / set (OR nn) every character's status (3B/B7B0 / B7C2)
ev_e8:      ld hl, SV + $102
            ld b, 4
.l:         ld a, [z71]
            and [hl]
            ld [hl], a
            ld de, $40
            add hl, de
            dec b
            jr nz, .l
            jp ev_rechr
ev_e9:      ld hl, SV + $102
            ld b, 4
.l:         ld a, [z71]
            or [hl]
            ld [hl], a
            ld de, $40
            add hl, de
            dec b
            jr nz, .l
ev_rechr:   ret                             ; (the walking graphics again: with the reload)

; $EA nn: give nn gil (3B/B7D4: at most 9,999,999 = $98967F)
ev_ea:      ld hl, SV + $1D
            ld a, [z71]
            add a, [hl]
            ld [hl+], a
            ld a, [hl]
            adc a, 0
            ld [hl], a
            cp $98
            jr nc, .max
            ret
.max:       jr nz, .set                     ; (FF3 compares $1E >= $98 only: past $98xxxx)
.set:       ld a, $7F
            ld [SV + $1C], a
            ld a, $96
            ld [SV + $1D], a
            ld a, $98
            ld [SV + $1E], a
            ret
; $EB nn: take nn gil (3B/B80D): too little -> event dialogue 2, the event ends
ev_eb:      ld a, [SV + $1E]
            and a
            jr nz, .ok
            ld a, [SV + $1D]
            ld hl, z71
            cp [hl]
            jr nc, .ok
            call ev_ff
            ld a, 2
            ld [z71], a
            jp ev_f1
.ok:        ld hl, SV + $1D
            ld a, [z71]
            ld b, a
            ld a, [hl]
            sub b
            ld [hl+], a
            ld a, [hl]
            sbc a, 0
            ld [hl], a
            bit 7, a
            ret z
            xor a
            ld [SV + $1C], a
            ld [SV + $1D], a
            ld [SV + $1E], a
            ret

; $F0 nn: npc dialogue nn (3B/B6BF): the id from the npc's list, the world's table
ev_f0:      ld a, [z71]
            ld e, a
            ld d, 0
            ld hl, T07 + $40
            add hl, de
            ld a, [hl]
            ld [z76], a
ev_ftab:    ld a, [world]
            and a
            ld a, $84
            jr z, .w
            ld a, $86
.w:         ld [z95], a
            xor a
            ld [z94], a
            ret
; $F1 nn: event dialogue nn (waits for A)
ev_f1:      ld a, [z71]                     ; (3B/B6D5: the table $80, the A Button to close)
            ld [z76], a
            ld a, $80
            ld [z7D], a
            ld [z95], a
            xor a
            ld [z94], a
            ret

; $F2-$F5 nn: event / npc switches (3B/B983 ...)
ev_f2:      call ev_sw
            or [hl]
            ld [hl], a
            ret
ev_f3:      call ev_sw
            cpl
            and [hl]
            ld [hl], a
            ret
ev_f4:      call ev_nsw
            or [hl]
            ld [hl], a
            ret
ev_f5:      call ev_nsw
            cpl
            and [hl]
            ld [hl], a
            ret
; HL = the event switch byte for z71 (SV $20 + n / 8), A = its bit
ev_sw:      ld a, [z71]
            ld hl, SV + $20
            jr sw_at
; the npc switch byte (SV $80 + n / 8, + 32 off the floating continent: 3B/B51A)
ev_nsw:     ld a, [z71]
nsw_at:     ld hl, SV + $80
            ld c, a
            ld a, [world]
            and a
            ld a, c
            jr z, sw_at
            push af
            srl a
            srl a
            srl a
            add a, $20
            ld e, a
            ld d, 0
            add hl, de
            pop af
            jr sw_bit
sw_at:      push af                         ; HL + A / 8, A = 1 << (A & 7)
            srl a
            srl a
            srl a
            ld e, a
            ld d, 0
            add hl, de
            pop af
sw_bit:     and 7
            ld b, a
            ld a, 1
            inc b
.l:         dec b
            ret z
            add a, a
            jr .l

; $F6 nn: give item nn (3B/B6F4): "Can't carry anymore." ($90) when full
ev_f6:      ld a, [z71]
            call inv_find
            jr nc, .ok
            call ev_ff
            ld a, $90
            ld [z71], a
            jp ev_f1
.ok:        ld hl, SV + $C0
            add hl, de
            ld a, [z71]
            ld [hl], a
            ld hl, SV + $E0
            add hl, de
            inc [hl]
            ret
; FF3 check if item can be given (3B/B8F0 / 3C/937E): A = item -> DE = its slot (the item's own,
; else the first empty one); C: the inventory full
inv_find:   ld c, a
            ld hl, SV + $C0
            ld e, 0
.l:         ld a, [hl+]
            cp c
            jr z, .y
            inc e
            ld a, e
            cp $20
            jr c, .l
            ld hl, SV + $C0
            ld e, 0
.e:         ld a, [hl+]
            and a
            jr z, .y
            inc e
            ld a, e
            cp $20
            jr c, .e
            scf
            ret
.y:         ld d, 0
            and a
            ret

; $F7 nn: battle nn (3B/B70F): a battle trigger
ev_f7:      ld a, [z71]
            ld [z6A], a
            ld a, $20
            ld [zAB], a
            ld a, $40
            ld [z44], a
            ret

; $F8 nn: a song / sound effect (3B/B71C): $00-$7C play song nn, $7D fade out, $7E resume, $7F
; stop, $80+ sound effect nn
ev_f8:      ld a, [z71]
            bit 7, a
            jr nz, .sfx
            cp $7D
            jr c, .song
            ld b, $0C
            jr z, .c                        ; ($7D: song $37, fade)
            cp $7E
            ld b, 2
            jr z, .c
            ld b, 4
.c:         ld a, b
            ld [M_CTRL], a
            cp $0C
            ret nz
            ld a, $37
            ld [M_SONG], a
            ret
.song:      ld [M_SONG], a
            ld a, 1
            ld [M_CTRL], a
            ret
.sfx:       ld [M_SFX], a
            ret

; $F9 nn: exit nn to the world map; $FA nn: entrance to map nn; $FB nn: the map's entrance nn
ev_f9:      ld a, [z71]
            ld [T07 + $30], a
            xor a
            ld [z45], a
            ld a, $C0
            ld [zAB], a
            ret
ev_fa:      ld a, [z71]
            ld [T07 + $00], a
            xor a
            ld [z45], a
            ld a, $80
            ld [zAB], a
            ret
ev_fb:      ld a, [z71]
            ld [z45], a
            ld a, $80
            ld [z44], a
            ret

; $FC nn: wait nn frames (3B/B775: the command runs again until the count is out)
ev_fc:      ld a, [z75]
            bit 7, a
            jr nz, .c
            ld a, $80
            ld [z75], a
            ld a, [z71]
            ld [z74], a
.c:         ld a, [z74]
            sub 1
            ld [z74], a
            jr nc, .again
            xor a
            ld [z75], a
            ret
.again:     ld a, [z72]
            sub 2
            ld [z72], a
            ld a, [z73]
            sbc a, 0
            ld [z73], a
            ret

; $FD: exit to the previous map
ev_fd:      ld a, $40
            ld [zAB], a
            ret

; $FF: the end of the event
ev_ff:      xor a
            ld [z22], a
            ld [z23], a
            ld [z24], a
            ld [z25], a
            ld [z6C], a
            ret

; ---- trigger scripts (3F/EA04 / EA1B): A = script id, DE = the pointer table (NES $8200 / $8400 /
; $8880) -> 64 bytes into TS7B
ts_load:    ld l, a
            ld h, 0
            add hl, hl
            add hl, de
            ld de, -$4000
            add hl, de
            ld a, SCRIPT
            call sbank
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h
            sub $40
            ld h, a
            ld de, TS7B
            ld bc, 64
            jp memcpy

; FF3 event trigger (3F/E6C6): A = trigger id -> its script (2C/8880), the event if one applies
ev_trig:    ld de, $8880
            call ts_load
            call ts_check
            ld a, [z6C]
            and a
            ret z
            jp ev_start
; a trigger tile of type F (3F/E6BE): its map trigger (T07 $20 + id)
ev_trigF:   ld a, [z45]
            and $0F
            ld e, a
            ld d, 0
            ld hl, T07 + $20
            add hl, de
            ld a, [hl]
            jr ev_trig

; FF3 check npc script (3C/92F3): past the conditionals, the npc's dialogue list (32) into T07 $40;
; then the trigger script check
ts_npc:     ld hl, TS7B
.l:         ld a, [hl]
            cp $FF
            jr z, .d
.s:         inc hl
            ld a, [hl]
            cp $FF
            jr nz, .s
            inc hl
            inc hl
            jr .l
.d:         inc hl
            inc hl
            ld de, T07 + $40
            ld bc, 32
            call memcpy
; FF3 check trigger script (3C/9319): the first conditional met -> z6C = its event id
ts_check:   ld hl, TS7B
.l:         ld a, [hl+]
            cp $FF
            jr nz, .c
            ld a, [hl]
            ld [z6C], a
            ret
.c:         ld c, a
            push hl
            call ev_swchk
            pop hl
            ld b, a                         ; (B: the switch on)
            ld a, b
            and a
            jr z, .clr
            bit 7, c                        ; on: met if the condition's msb is set
            jr nz, .l
            jr .skip
.clr:       bit 7, c                        ; off: met if clear
            jr z, .l
.skip:      ld a, [hl+]                     ; (not met: past this conditional's $FF and event)
            cp $FF
            jr nz, .skip
            inc hl
            jr .l
; Z: event switch (C & $7F) clear
ev_swchk:   ld a, c
            and $7F
            ld hl, SV + $20
            call sw_at
            and [hl]
            ret

; FF3 joypad (3E/D27A / D29A): the GB pad into z20 (FF3's order), presses latched in z22-z25
joy_ff3:    ldh a, [pad]                    ; GB: 0 A, 1 B, 2 Select, 3 Start, 4 R, 5 L, 6 U, 7 D
            ld c, a
            xor a
            bit 0, c
            jr z, .a
            or $80
.a:         bit 1, c
            jr z, .b
            or $40
.b:         bit 2, c
            jr z, .s
            or $20
.s:         bit 3, c
            jr z, .t
            or $10
.t:         bit 6, c
            jr z, .u
            or $08
.u:         bit 7, c
            jr z, .d
            or $04
.d:         bit 5, c
            jr z, .l
            or $02
.l:         bit 4, c
            jr z, .r
            or $01
.r:         ld [z20], a
            ldh a, [pad_new]
            ld c, a
            ld hl, z24
            bit 0, c
            jr z, .na
            inc [hl]
.na:        inc hl                          ; z25
            bit 1, c
            jr z, .nb
            inc [hl]
.nb:        ld hl, z22
            bit 2, c
            jr z, .nsl
            inc [hl]
.nsl:       inc hl                          ; z23
            bit 3, c
            ret z
            inc [hl]
            ret

; ---- FF3 get random number (3E/C711): the field's random table, $F5 stepping up or down ($F6 bit 7),
; $F6 + $A0 each time it wraps
C_ENCRATE  = $7100          ; COMMON: 39/BE00 encounter rate by map (world 0), 39/BF00 (others)
C_ENCMAP   = $7300          ; 2E/92F0 battle group by map (world 0), 2E/93F0 (others)
C_ENCPROB  = $7500          ; 3D/BD78 which of a group's 8 battles (64)
C_ENCGRP   = $7600          ; 2E/94F0 battle groups (8 battles each)
zF5        = Z + $F5
zF6        = Z + $F6
zF7        = Z + $F7
zF8        = Z + $F8        ; this map's encounter rate

rnd_fld:    ld a, COMMON
            call sbank
            ld a, [zF6]
            bit 7, a
            jr nz, .dn
            ld hl, zF5
            inc [hl]
            jr nz, .g
            jr .w
.dn:        ld hl, zF5
            dec [hl]
            jr nz, .g
.w:         ld a, [zF6]
            add a, $A0
            ld [zF6], a
.g:         ld a, [zF5]
            ld l, a
            ld h, high(C_RND)
            ld a, [hl]
            ret

; FF3 check random battle, normal map (3D/BDB9): a random number below the map's rate -> a battle of
; the map's group (3D/BD4D), the trigger $20
enc_map:    ld a, [z6C]
            and a
            ret nz
            call rnd_fld
            ld b, a
            ld a, [zF8]
            ld c, a
            ld a, b
            cp c
            ret nc
            ld a, [cur_map]
            ld l, a
            ld h, high(C_ENCMAP)
            ld a, [world]
            and a
            jr z, .w
            inc h
.w:         ld a, [hl]
            call enc_grp
            ld a, $20
            ld [zAB], a
            ret
; FF3 choose from battle group (3D/BD4D): A = group -> z6A
enc_grp:    ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, C_ENCGRP
            add hl, de
            push hl
            ld hl, zF7
            inc [hl]
            ld l, [hl]
            ld h, high(C_RND)
            ld a, [hl]
            and $3F
            ld l, a
            ld h, high(C_ENCPROB)
            ld e, [hl]
            ld d, 0
            pop hl
            add hl, de
            ld a, [hl]
            ld [z6A], a
            ret

; ---- FF3 check treasures and locked doors (3F/E917): the tile ahead (tx / ty) -> C and A = the
; dialogue (table $82); a chest opened (tile $7D), its item given (3F/F549)
C_CHEST    = $5D00          ; COMMON: 01/9C00 chest contents (world 0), 01/9D00 (others)
C_PRICE    = $7E00          ; 10/9E00 item prices (2 bytes each)
z49        = Z + $49        ; the map's chests hold gil (map properties byte 1 & $20)
z80        = Z + $80
z81        = Z + $81
z82        = Z + $82
z8F        = Z + $8F
zBA        = Z + $BA
zBB        = Z + $BB        ; the item found (its name: text code $02)

chk_tres:   ld a, [tx]
            ld e, a
            ld a, [ty]
            ld d, a
            call map_at
            ld c, a                         ; C = the tile
            push bc
            ld a, [tx]
            ld e, a
            ld a, [ty]
            ld d, a
            call tile_props
            pop bc
            ld a, [z44]
            bit 7, a
            jr z, .no
            ld a, c
            cp $90
            jr c, .no
            cp $A0
            jr c, .lock
            cp $D0
            jr c, .no
            cp $F0
            jr nc, .no
            xor a                           ; $D0-$EF: a treasure ($E0-: not a chest, its switch)
            ld [zBA], a
            ld a, c
            cp $E0
            jr c, .give
            ld a, $FF
            ld [zBA], a
            call tr_sw
            and [hl]
            jr nz, .give
.no:        and a
            ret
.lock:      ld a, [SV + $0E]                ; a locked door: a Thief opens it
            ld e, a
            ld d, 0
            ld hl, SV + $100
            add hl, de
            ld a, [hl]
            cp 8
            ld a, 3                         ; ("Locked.")
            jr nz, .y
            ld hl, SV + $21
            set 6, [hl]
            ld a, $7A                       ; ("Unlocked by the Thief's ability!")
.y:         scf
            ret
.give:      ld a, $BF                       ; (sound effect $3F)
            ld [M_SFX], a
            call tr_give
            cp $50                          ; ("Can't carry anymore.": nothing changes)
            jr z, .y
            ld b, a
            ld a, [zBA]
            and a
            ld a, b
            jr nz, .y
            push af                         ; a chest: opened ($7D, drawn: 3F/E6F0)
            ld a, [tx]
            ld e, a
            ld a, [ty]
            ld d, a
            ld a, $7D
            call map_set
            ld a, [tx]
            ld e, a
            ld a, [ty]
            ld d, a
            call q_mt
            pop af
            scf
            ret

; HL = the treasure switch byte, A = its bit (3F/F640: the map's treasure id from T07 $10)
tr_sw:      ld a, [z45]
            and $0F
            ld e, a
            ld d, 0
            ld hl, T07 + $10
            add hl, de
            ld a, [hl]
            ld hl, SV + $40
            ld c, a
            ld a, [world]
            and a
            ld a, c
            jp z, sw_at
            push af
            srl a
            srl a
            srl a
            add a, $20
            ld e, a
            ld d, 0
            add hl, de
            pop af
            jp sw_bit

; FF3 give treasure (3F/F549) -> A = the dialogue
tr_give:    ld a, [z45]
            and $0F
            ld e, a
            ld d, 0
            ld hl, T07 + $10
            add hl, de
            ld a, [hl]
            ld [z8F], a
            ld e, a
            ld a, COMMON
            call sbank
            ld hl, C_CHEST                  ; the contents
            ld a, [world]
            and a
            jr z, .w
            inc h
.w:         add hl, de
            ld a, [hl]
            ld [zBB], a
            ld c, a
            ld a, [zBA]
            and a
            jr nz, .item
            ld a, [z49]
            and a
            jr nz, .gil
.item:      ld b, 1                         ; (arrows $4F-$56: 20)
            ld a, c
            cp $4F
            jr c, .q
            cp $57
            jr nc, .q
            ld b, 20
.q:         ld a, c
            push bc
            call inv_find
            pop bc
            ld a, $50                       ; (full)
            ret c
            ld hl, SV + $C0
            add hl, de
            ld [hl], c
            ld hl, SV + $E0
            add hl, de
            ld a, [hl]
            add a, b
            cp 99
            jr c, .m
            ld a, 99
.m:         ld [hl], a
            call tr_sw
            xor [hl]
            ld [hl], a
            ld a, [zBA]
            and a
            ld a, $76
            ret nz
            ld a, [z8F]
            cp $E0
            ld a, $59
            ret c
            ld a, $20                       ; (a chest with a battle)
            ld [zAB], a
            ld a, [z8F]
            ld [z6A], a
            ld a, 2
            ret
.gil:       ld l, c                         ; the item's price as gil (10/9E00)
            ld h, 0
            add hl, hl
            ld de, C_PRICE
            add hl, de
            ld a, [hl+]
            ld [z80], a
            ld a, [hl]
            ld [z81], a
            xor a
            ld [z82], a
            ld hl, SV + $1C
            ld a, [z80]
            add a, [hl]
            ld [hl+], a
            ld a, [z81]
            adc a, [hl]
            ld [hl+], a
            ld a, 0
            adc a, [hl]
            ld [hl], a
            cp $98
            jr c, .sw
            ld a, $7F
            ld [SV + $1C], a
            ld a, $96
            ld [SV + $1D], a
            ld a, $98
            ld [SV + $1E], a
.sw:        call tr_sw
            xor [hl]
            ld [hl], a
            ld a, 1
            ret

