; ---- Nintendo Lot Check items (docs/gb-release-checks.md): the Color boot set-up (moved out
; of bank 0), soft reset (A + B + Select + Start), the boot message screen, and the save in a
; cart RAM bank of its own.
;
; The save: FF1 keeps its save at NES $6400-$67FF (cart RAM bank 0 $A400-$A7FF, with the NES
; work RAM and the runtime's data around it, so cart RAM has to stay enabled while the game
; runs). The committed copy lives in SAVE_BANK: its bytes at $A400-$A7FF, then a 16-bit sum
; and its complement at $A008-$A00B and the magic SV_MAGIC at $A000-$A007, written last. The
; bank is mapped only while the boot checks / loads it and while save_commit copies FF1's new
; save into it (after FF1's own SaveGame, b14:ABCE). At boot: a sealed copy whose sum matches
; is loaded into bank 0; a damaged one is reported on screen (the player presses the A Button)
; before it is erased; with no magic yet, a save FF1 left in bank 0 ($55 / $AA marks) is taken
; over, else an empty one is sealed. On a Game Pak whose RAM has no separate bank SAVE_BANK
; (32 KB) the save stays in bank 0 only (save_sep = 0).
SAVE_BANK  = 4
SV_DATA    = $A400
SV_END     = $A8
SV_SUM     = $A008

section bank DYN_BANK, $5000
cgb_boot:
            ld a, 1
            ldh [is_cgb], a
            ld a, 1                         ; VRAM bank 1 (attributes) cleared too
            ldh [$FF4F], a
            ld hl, $8000
            ld bc, $2000
            call memclr
            ld hl, $9C00                    ; window map (the mask): tile 0 of VRAM bank 1
            ld bc, $400                     ;   (cleared above), palette 7: black
.wm:        ld a, $0F
            ld [hl+], a
            dec bc
            ld a, b
            or c
            jr nz, .wm
            xor a
            ldh [$FF4F], a
            ld a, $B8                       ; BG palette 7 (the mask): black
            ldh [$FF68], a
            xor a
            ld b, 8
.p7:        ldh [$FF69], a
            dec b
            jr nz, .p7
            ldh a, [$FF4D]                  ; double speed (KEY1 + STOP, interrupts off), unless
            bit 7, a                        ;   already on (a soft reset)
            ret nz
            ld a, 1
            ldh [$FF4D], a
            xor a
            ldh [$FFFF], a
            ld a, $30
            ldh [$FF00], a
            stop
            ret

; A + B + Select + Start (read_buttons through sreset0): interrupts off, sound off (NR52 = 0
; clears every sound register), cart RAM bank 0 and RAM off, then (once the four buttons are
; no longer all held) the boot code again, which waits for the V-Blank before it turns the
; LCD off and sets up everything. Never reached inside a save copy (no joypad read there).
soft_reset: di
            xor a
            ldh [$FFFF], a
            ldh [$FF0F], a
            ldh [$FF26], a
            ld [$4000], a
            ld [$0000], a
            inc a
            ldh [$FF70], a                  ; (Color: WRAM bank 1)
.rel:       ld a, $10
            ldh [$FF00], a
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            cpl
            and $0F
            cp $0F
            jr z, .rel
            ld a, $30
            ldh [$FF00], a
            ldh a, [is_cgb]
            and a
            ld a, $01
            jr z, .go
            ld a, $11
.go:        jp boot

; ---- boot (LCD off, cart RAM on, bank 0; ROM bank DYN_BANK): the runtime's cart RAM banks
; 1-3 cleared (working memory), then the save checked (see above).
save_boot:  ld d, 1
.cb:        ld a, d
            ld [$4000], a
            ld hl, $A000
            ld bc, $2000
            push de
            call memclr
            pop de
            inc d
            ld a, d
            cp 4
            jr nz, .cb
            xor a
            ldh [save_sep], a
            ld [$4000], a
            ld hl, $BFF0                    ; SAVE_BANK separate from bank 0?
            ld b, [hl]
            ld a, SAVE_BANK
            ld [$4000], a
            ld c, [hl]
            ld [hl], $A5
            xor a
            ld [$4000], a
            ld [hl], $5A
            ld a, SAVE_BANK
            ld [$4000], a
            ld e, [hl]
            ld [hl], c
            xor a
            ld [$4000], a
            ld [hl], b
            ld a, e
            cp $A5
            ret nz
            ld a, 1
            ldh [save_sep], a
            ld a, SAVE_BANK
            ld [$4000], a
            call sv_magic
            jr nz, .new
            call sv_sum
            ld hl, SV_SUM
            ld a, [hl+]
            cp e
            jr nz, .bad
            ld a, [hl+]
            cp d
            jr nz, .bad
            ld a, [hl+]
            cpl
            cp e
            jr nz, .bad
            ld a, [hl]
            cpl
            cp d
            jr nz, .bad
            ld hl, SV_DATA                  ; sealed and whole: into bank 0
.ld:        ld a, SAVE_BANK
            ld [$4000], a
            ld b, [hl]
            xor a
            ld [$4000], a
            ld [hl], b
            inc hl
            ld a, h
            cp SV_END
            jr nz, .ld
            ret
.bad:       xor a                           ; damaged: say so, wait for the A Button
            ld [$4000], a
            ld hl, saverr_text
            call msg_show
.wa:        call .btn
            jr z, .wa
.wr:        call .btn
            jr nz, .wr
.wv:        ldh a, [$FF44]                  ; LCD off in the V-Blank, VRAM cleared again
            cp 144
            jr c, .wv
            xor a
            ldh [$FF40], a
            ld hl, $8000
            ld bc, $2000
            call memclr
            ld hl, SV_DATA                  ; then erased: an empty save in both banks
            ld bc, $400
            call memclr
.empty:     ld a, SAVE_BANK
            ld [$4000], a
            ld hl, SV_DATA
            ld bc, $400
            call memclr
            call sv_seal
            xor a
            ld [$4000], a
            ret
.new:       xor a                           ; no copy yet: FF1's save in bank 0 taken over
            ld [$4000], a
            ld a, [SV_DATA + $FE]
            cp $55
            jr nz, .empty
            ld a, [SV_DATA + $FF]
            cp $AA
            jr nz, .empty
            ld hl, SV_DATA
.st:        ld b, [hl]
            ld a, SAVE_BANK
            ld [$4000], a
            ld [hl], b
            xor a
            ld [$4000], a
            inc hl
            ld a, h
            cp SV_END
            jr nz, .st
            ld a, SAVE_BANK
            ld [$4000], a
            call sv_seal
            xor a
            ld [$4000], a
            ret
.btn:       ld a, $10                       ; NZ: the A Button held
            ldh [$FF00], a
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            cpl
            and $01
            ret

sv_magic:   ld hl, $A000                    ; Z: SAVE_BANK holds the magic
            ld de, SV_MAGIC
            ld b, 8
.l:         ld a, [de]
            cp [hl]
            ret nz
            inc de
            inc hl
            dec b
            jr nz, .l
            ret
sv_sum:     ld hl, SV_DATA                  ; DE = the 16-bit sum of SV_DATA's $400 bytes
            ld de, 0
.l:         ld a, [hl+]
            add a, e
            ld e, a
            jr nc, .n
            inc d
.n:         ld a, h
            cp SV_END
            jr nz, .l
            ret
sv_seal:    call sv_sum                     ; (SAVE_BANK mapped) the sum, then the magic
            ld hl, SV_SUM
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, e
            cpl
            ld [hl+], a
            ld a, d
            cpl
            ld [hl], a
            ld hl, $A000
            ld de, SV_MAGIC
            ld b, 8
.m:         ld a, [de]
            ld [hl+], a
            inc de
            dec b
            jr nz, .m
            ret
SV_MAGIC:   db "FF1GBSV1"

; ---- boot message screen: HL = rows (map offset lo, hi, length, font codes; 0, 0 ends), the
; LCD off and VRAM clear. The font to tiles 0.., the rows to the map, black on white... (as
; the RAM check's message), LCD on.
msg_show:   push hl
            ld hl, ramchk_font
            ld de, $8000
            ld bc, ramchk_font_end - ramchk_font
.ft:        ld a, [hl+]
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .ft
            pop hl
.ln:        ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            or e
            jr z, .shown
            ld a, [hl+]
            ld b, a
.ch:        ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .ch
            jr .ln
.shown:     ldh a, [is_cgb]
            and a
            jr z, .dmg
            ld a, $80                       ; CGB BG palette 0: black, -, -, white
            ldh [$FF68], a
            ld hl, .pal
            ld b, 8
.pl:        ld a, [hl+]
            ldh [$FF69], a
            dec b
            jr nz, .pl
            jr .on
.dmg:       ld a, $03                       ; colour 0 black, colour 3 white
            ldh [$FF47], a
.on:        xor a
            ldh [$FF42], a
            ldh [$FF43], a
            ld a, %10010001                 ; LCD on, BG tiles $8000, map $9800
            ldh [$FF40], a
            ret
.pal:       db $00, $00, $00, $00, $00, $00, $FF, $7F

; ---- b14:ABCE (after FF1's SaveGame wrote and summed the save at $6400-$67FF): its new save
; copied into SAVE_BANK, 32 bytes at a time with interrupts off, summed on the way, then the
; sum and the magic (last). Out as FF1's LDA #$56 there: A = $56, N = 0, Z = 0; BC, DE kept.
section bank PF_BANK, $6E58
save_commit: ldh a, [save_sep]
            and a
            jr z, .x
            push bc
            push de
            ld hl, SV_DATA
            ld de, 0
.k:         ld b, 32
            di
.c:         ld c, [hl]
            ld a, c
            add a, e
            ld e, a
            jr nc, .n
            inc d
.n:         ld a, SAVE_BANK
            ld [$4000], a
            ld [hl], c
            xor a
            ld [$4000], a
            inc hl
            dec b
            jr nz, .c
            ei
            ld a, h
            cp SV_END
            jr nz, .k
            di
            ld a, SAVE_BANK
            ld [$4000], a
            ld hl, SV_SUM
            ld a, e
            ld [hl+], a
            ld a, d
            ld [hl+], a
            ld a, e
            cpl
            ld [hl+], a
            ld a, d
            cpl
            ld [hl], a
            ld hl, $A000
            ld de, sc_magic
            ld b, 8
.m:         ld a, [de]
            ld [hl+], a
            inc de
            dec b
            jr nz, .m
            xor a
            ld [$4000], a
            ei
            pop de
            pop bc
.x:         ld a, $56
            ldh [nzv], a
            and a
            ret
sc_magic:   db "FF1GBSV1"
