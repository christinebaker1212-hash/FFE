; FF1 native engine: Super Game Boy. Our own code (packets as in the recompiled build's
; rt/sgb.s, which is ours too). On a Super Game Boy the DMG picture's shades (0 brightest ..
; 3 darkest, BGP straight) are SGB colour numbers: each screen sends palettes whose colour n is
; the NES colour its shade n stands for (data: tools/gbn/sgb.py and the map banks' $73A0),
; and an attribute block. Packets wait in a queue and go out from the frame wait, four frames
; apart; a screen change is masked (black) until its palettes are in.

SGB_BANK   = 98
SG_CHR     = $4000          ; the border (sgb.py)
SG_PCT     = $5000
SG_ENEMY   = $5880          ; per formation: colours 1-3 of the enemies' palette
SG_FIXED   = $5B80          ; menus, battle windows, party column, world map (4 colours each)
M_SGB      = $73A0          ; map bank: the map's palette (4 colours)
SGB_GAP    = 4

section bank 0, $3600

; ---- boot (not a Color; LCD off, interrupts off): a Super Game Boy answers MLT_REQ
sgb_detect: xor a
            ld [sgb_on], a
            ld [sgb_qn], a
            ld [sgb_qi], a
            ld [sgb_gap], a
            ld b, 6
            call sgb_delay
            ld hl, SG_MLT2
            call sgb_send
            ld b, 4
            call sgb_delay
            ld c, 4                         ; two players: the joypad ID changes when P15 pulses
.try:       ld a, $20
            ldh [rP1], a
            ld a, $30
            ldh [rP1], a
            ld a, $10
            ldh [rP1], a
            ld a, $30
            ldh [rP1], a
            ldh a, [rP1]
            ldh a, [rP1]
            and 3
            cp 3
            jr nz, .sgb
            dec c
            jr nz, .try
            ret
.sgb:       ld a, 1
            ld [sgb_on], a
            ld hl, SG_MLT1
            call sgb_send
            ld b, 4
            call sgb_delay
; the border: frozen screen; tiles (CHR_TRN), then map and palettes (PCT_TRN), each shown as
; BG tiles for the SGB to read
            ld hl, SG_FRZ
            call sgb_send
            ld b, 2
            call sgb_delay
            ld hl, SG_CHR
            ld bc, $1000
            ld de, SG_CHRTRN
            call .trn
            ld hl, SG_PCT
            ld bc, $0880
            ld de, SG_PCTTRN
            call .trn
            ld hl, SG_UNM
            jp sgb_send
.trn:       push de
            push bc
            push hl
            ld hl, $8000                    ; tiles cleared
            ld bc, $1800
.cl:        xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .cl
            pop hl
            pop bc
            ld a, SGB_BANK                  ; the data from the SGB bank
            ld [MBC_BANK], a
            ld de, $8000
.cp:        ld a, [hl+]
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .cp
            ldh a, [rombank]
            ld [MBC_BANK], a
            ld hl, $9800                    ; the map: tiles 0-255 in order, 20 a row
            ld d, 0
            ld b, 13
.r:         ld c, 20
.c:         ld a, d
            ld [hl+], a
            inc d
            dec c
            jr nz, .c
            ld a, l
            add a, 12
            ld l, a
            jr nc, .nh
            inc h
.nh:        dec b
            jr nz, .r
            ld a, %11100100
            ldh [rBGP], a
            ld a, %10010001                 ; LCD on, BG tiles $8000, map $9800
            ldh [rLCDC], a
            ld b, 2
            call sgb_delay
            pop hl
            call sgb_send
            ld b, 4
            call sgb_delay
.wv:        ldh a, [rLY]
            cp 144
            jr c, .wv
            xor a
            ldh [rLCDC], a
            ld hl, $8000
            ld bc, $2000
.c2:        xor a
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .c2
            ret

; B frames of busy waiting
sgb_delay:  push bc
.f:         ld de, 2508
.l:         dec de
            ld a, d
            or e
            jr nz, .l
            dec b
            jr nz, .f
            pop bc
            ret

; HL = a 16-byte packet, sent bit by bit through P1. Keeps BC, DE. Every pulse (the reset,
; each bit, the stop bit) held low for 6 cycles and high for 8 or more: the SGB wants about
; 5 us each; at 2 us (one load between the writes) a real SGB / an exact emulator can miss a
; bit and drop the packet (owner: the field kept a battle's colours, its text unreadable)
sgb_send:   push bc
            push de
            xor a
            ldh [rP1], a
            nop
            nop
            nop
            nop
            ld a, $30
            ldh [rP1], a
            nop
            nop
            nop
            nop
            ld b, 16
.byte:      ld e, [hl]
            inc hl
            ld c, 8
.bit:       ld a, $10
            rr e
            jr c, .one
            ld a, $20
.one:       ldh [rP1], a
            nop
            nop
            nop
            nop
            ld a, $30
            ldh [rP1], a
            nop
            nop
            dec c
            jr nz, .bit
            dec b
            jr nz, .byte
            ld a, $20
            ldh [rP1], a
            nop
            nop
            nop
            nop
            ld a, $30
            ldh [rP1], a
            pop de
            pop bc
            ret

; the frame wait's turn: the next queued packet, SGB_GAP frames apart
sgb_tick:   ld a, [sgb_on]
            and a
            ret z
            ld a, [sgb_gap]
            and a
            jr z, .s
            dec a
            ld [sgb_gap], a
            ret
.s:         ld a, [sgb_qi]
            ld hl, sgb_qn
            cp [hl]
            ret nc
            inc a
            ld [sgb_qi], a
            dec a
            swap a
            add a, low(sgb_q)
            ld l, a
            ld h, high(sgb_q)
            call sgb_send
            ld a, SGB_GAP
            ld [sgb_gap], a
            ret

; a new screen's packets: the queue restarted with the mask (black); returns HL = the next
; packet's place
sgb_new:    xor a
            ld [sgb_qi], a
            ld a, 1
            ld [sgb_qn], a
            ld hl, SG_BLK
            ld de, sgb_q
            ld b, 16
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ret
; HL -> the next queue slot (DE), counted
sgb_slot:   ld a, [sgb_qn]
            inc a
            ld [sgb_qn], a
            dec a
            swap a
            add a, low(sgb_q)
            ld e, a
            ld d, high(sgb_q)
            ret
; a 16-byte packet from HL (this bank / RAM) queued
sgb_put:    call sgb_slot
            ld b, 16
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ret
; PAL01 / PAL23 (A = $01 / $09) from 7 colours at HL (colour 0, then three, three; RGB555)
; read from bank C (0: RAM / bank 0)
sgb_pal:    push af
            call sgb_slot
            pop af
            ld [de], a
            inc de
            ld b, 14
.c:         ld a, c
            and a
            jr z, .r
            push bc
            push de
            ld [fc_bank], a
            call far_byte
            pop de
            pop bc
            inc hl
            jr .w
.r:         ld a, [hl+]
.w:         ld [de], a
            inc de
            dec b
            jr nz, .c
            xor a
            ld [de], a
            ret
; the mask off, last
sgb_end:    ld hl, SG_UNM
            jp sgb_put

; menus (every scr_open screen): FF1's blue windows, palette 0 everywhere
sgb_menu:   ld hl, SG_FIXED
sgb_one:    ld a, [sgb_on]
            and a
            ret z
            push hl
            call sgb_new
            pop hl
            ld a, $01                       ; PAL01: palette 0 (and 1) the same four colours
            ld c, SGB_BANK
            call sgb_pal
            ld hl, SG_ALL0
            call sgb_put
            jp sgb_end
; the field: the map's own palette (its bank's $73A0)
sgb_map:    ld a, [sgb_on]
            and a
            ret z
            call sgb_new
            ld hl, M_SGB
            ld a, [map_bank]
            ld c, a
            ld a, $01
            call sgb_pal
            ld hl, SG_ALL0
            call sgb_put
            jp sgb_end
; the world map
sgb_mini:   ld hl, SG_FIXED + 24
            jr sgb_one
; battle: windows palette 0, the formation's enemies 1 (enemy area), the party 2 (its column)
sgb_battle: ld a, [sgb_on]
            and a
            ret z
            call sgb_new
            ld hl, SG_FIXED + 8             ; colours: white, the windows' three
            ld de, sgb_tmp
            ld bc, 8
            ld a, SGB_BANK
            call far_copy
            ld a, [btl_fid]                 ; the enemies' three
            and $7F
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de                      ; x 6
            ld de, SG_ENEMY
            add hl, de
            ld de, sgb_tmp + 8
            ld bc, 6
            ld a, SGB_BANK
            call far_copy
            ld a, $01
            ld hl, sgb_tmp
            ld c, 0
            call sgb_pal
            ld hl, SG_FIXED + 16            ; PAL23: the party's two palettes (FF1's battle
            ld de, sgb_tmp                  ;   sprite palettes 1 and 0)
            ld bc, 8
            ld a, SGB_BANK
            call far_copy
            ld hl, SG_FIXED + 34
            ld de, sgb_tmp + 8
            ld bc, 6
            ld a, SGB_BANK
            call far_copy
            ld a, $09
            ld hl, sgb_tmp
            ld c, 0
            call sgb_pal
            call sgb_slot                   ; ATTR_BLK, two packets: the enemy area 1, each
            push de                         ;   member's rows (3 m .. 3 m + 2 of the party
            call sgb_slot                   ;   column) 2 or 3 by the job's palette
            pop de
            ld hl, SG_BTL2
            ld b, 8
.h:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .h
            ld c, 0
.m:         ld a, $03
            ld [de], a
            inc de
            push de
            ld a, c
            call ch_rec
            ld a, [hl]
            ld e, a
            ld d, 0
            ld hl, cls_pal
            add hl, de
            ld a, [hl]
            pop de
            and a
            ld a, $0A                       ; (palette 1 jobs: SGB palette 2)
            jr nz, .r
            ld a, $0F                       ; (palette 0 jobs: SGB palette 3)
.r:         ld [de], a
            inc de
            ld a, 15
            ld [de], a
            inc de
            ld a, c
            add a, a
            add a, c
            ld [de], a
            inc de
            ld a, 19
            ld [de], a
            inc de
            ld a, c
            add a, a
            add a, c
            add a, 2
            ld [de], a
            inc de
            inc c
            ld a, c
            cp 4
            jr c, .m
            jp sgb_end

section bank 0, $1700                       ; (the packets)
SG_MLT2:    db $89, $01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
SG_MLT1:    db $89, $00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
SG_FRZ:     db $B9, $01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
SG_BLK:     db $B9, $03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
SG_UNM:     db $B9, $00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
SG_CHRTRN:  db $99, $00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
SG_PCTTRN:  db $A1, $00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; ATTR_BLK: the whole screen palette 0
SG_ALL0:    db $21, $01, $07, $00, 0, 0, 19, 17, 0, 0, 0, 0, 0, 0, 0, 0
; battle: the enemy area (1-14, 0-11) palette 1, else 0; the party column (15-19, 0-11) 2
SG_BTLATR:  db $21, $02, $07, $05, 1, 0, 14, 11, $03, $0A, 15, 0, 19, 11, 0, 0
SG_BTL2:    db $22, $05, $07, $05, 1, 0, 14, 11     ; (+ the four members' blocks)

section wram, $C980
sgb_on:     ds 1
sgb_qn:     ds 1
sgb_qi:     ds 1
sgb_gap:    ds 1
sgb_tmp:    ds 14
section wram, $C9A0
sgb_q:      ds 6 * 16                       ; (6 slots, in one page)
