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

; ---- boot (LCD off, cart RAM on, bank 0; ROM bank DYN_BANK): the runtime's working cart RAM
; cleared: bank 1 (tile shadows) and bank 3 $A000-$B0FF (SGB packets, sprite / BG bookkeeping,
; buffers); not the suspend point (bank 2, bank 3 $B100-$BDFF) or the options (bank 3 $BF00),
; which persist. Then the save checked (see above).
save_boot:  ld a, 1
            ld [$4000], a
            ld hl, $A000
            ld bc, $2000
            call memclr
            ld a, 3
            ld [$4000], a
            ld hl, $A000
            ld bc, $1100
            call memclr
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
            jr nz, .ns
            ld a, 1
            ldh [save_sep], a
            call sv_boot
.ns:        call sp_boot                    ; the suspend point and the options, checked too
            jp op_boot
sv_boot:    ld a, SAVE_BANK
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
            call err_wait
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

; HL = message rows: shown (msg_show) until the A Button is pressed and released, then the LCD
; off in the V-Blank and VRAM cleared again (boot: the LCD was off).
err_wait:   call msg_show
.wa:        call .btn
            jr z, .wa
.wr:        call .btn
            jr nz, .wr
.wv:        ldh a, [$FF44]
            cp 144
            jr c, .wv
            xor a
            ldh [$FF40], a
            ld hl, $8000
            ld bc, $2000
            jp memclr
.btn:       ld a, $10                       ; NZ: the A Button held
            ldh [$FF00], a
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            cpl
            and $01
            ret

; ---- the suspend point (bank 5 + 6, or 3 + 2 without a save bank; ff1_native.s susp_w): its
; magic "SUSP" at SUSP_MAGIC, then the sum of its bytes and the sum's complement. A point
; whose sum does not match is reported (A Button) and erased.
sp_boot:    call .bank
            ld [$4000], a
            ld hl, SUSP_MAGIC
            ld a, [hl+]
            cp 'S'
            jr nz, .x
            ld a, [hl+]
            cp 'U'
            jr nz, .x
            ld a, [hl+]
            cp 'S'
            jr nz, .x
            ld a, [hl]
            cp 'P'
            jr nz, .x
            ld de, 0                        ; the sum: SUSP_RAM's $0C00 bytes, then the copy's 8 KB
            ld hl, SUSP_RAM
.a:         ld a, [hl+]
            add a, e
            ld e, a
            jr nc, .an
            inc d
.an:        ld a, h
            cp high(SUSP_RAM + $0C00)
            jr nz, .a
            ldh a, [save_sep]
            add a, a
            add a, a
            add a, 2
            ld [$4000], a
            ld hl, $A000
.b:         ld a, [hl+]
            add a, e
            ld e, a
            jr nc, .bn
            inc d
.bn:        ld a, h
            cp $C0
            jr nz, .b
            call .bank
            ld [$4000], a
            ld hl, SUSP_MAGIC + 4
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
            jr z, .x
.bad:       xor a
            ld [$4000], a
            ld hl, susperr_text
            call err_wait
            call .bank
            ld [$4000], a
            xor a
            ld [SUSP_MAGIC], a
.x:         xor a
            ld [$4000], a
            ret
.bank:      ldh a, [save_sep]
            add a, a
            add a, 3
            ret

; ---- the options (OPT_SAVE: BGM, SFX volume, $5A, check byte = ~(BGM + SFX + $5A); bank 4,
; or 3): marked valid but not matching their check byte, they are reported (A Button) and
; reset to 8 / 8 (then opt_load reads them).
op_boot:    ldh a, [save_sep]
            add a, 3
            ld [$4000], a
            ld hl, OPT_SAVE + 2
            ld a, [hl]
            cp $5A
            jr nz, .x
            ld a, [OPT_SAVE]
            ld b, a
            ld a, [OPT_SAVE + 1]
            add a, b
            add a, $5A
            cpl
            ld b, a
            ld a, [OPT_SAVE + 3]
            cp b
            jr z, .x
            xor a
            ld [$4000], a
            ld hl, opterr_text
            call err_wait
            ldh a, [save_sep]
            add a, 3
            ld [$4000], a
            ld a, 8
            ld [OPT_SAVE], a
            ld [OPT_SAVE + 1], a
            ld a, $95                       ; (~(8 + 8 + $5A))
            ld [OPT_SAVE + 3], a
            ld a, $5A
            ld [OPT_SAVE + 2], a
.x:         xor a
            ld [$4000], a
            ret

; boot: the volumes kept with the options (else 8, 8)
opt_load:   ldh a, [save_sep]
            add a, 3
            ld [$4000], a
            ld a, 8
            ld [VOL_BGM], a
            ld [VOL_SFX], a
            ld a, [OPT_SAVE + 2]
            cp $5A
            jr nz, .x
            ld a, [OPT_SAVE]
            cp 9
            jr nc, .x
            ld [VOL_BGM], a
            ld a, [OPT_SAVE + 1]
            cp 9
            jr nc, .x
            ld [VOL_SFX], a
.x:         xor a
            ld [$4000], a
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

; ---- suspend points (moved from ff1_native.s; rt_mmc_r5802 / rt_mmc_w5802 map DYN_BANK)
section bank DYN_BANK, $5800
susp_r:
            push af
            call sb_ram
            ld [$4000], a
            ld hl, SUSP_MAGIC
            ld a, [hl+]
            cp 'S'
            jr nz, .no
            ld a, [hl+]
            cp 'U'
            jr nz, .no
            ld a, [hl+]
            cp 'S'
            jr nz, .no
            ld a, [hl]
            cp 'P'
            jr nz, .no
            ld l, 1
            jr .x
.no:        ld l, 0
.x:         xor a
            ld [$4000], a
            pop af
            ret
susp_w:
            push af
            push bc
            push de
            push hl
            cp $A5
            jr z, .save
            cp $5A
            jr z, .load
            cp $E0
            jr z, .erase
            jr .x
.save:      call sb_ram                     ; NES RAM and ExRAM -> SUSP_RAM (bank 5, or 3)
            ld [$4000], a
            ld hl, NES_RAM
            ld de, SUSP_RAM
            ld bc, $0C00
            call .cp
            ld a, 2                         ; save RAM (bank 0) -> bank 2 through QV (the
            ld b, 32                        ;   VRAM queue is empty while the LCD is off)
            ld hl, $A000
.sv:        push bc
            xor a
            ld [$4000], a
            push hl
            ld de, QV
            ld bc, 256
            call .cp
            pop hl
            call sb_wram
            ld [$4000], a
            ld d, h
            ld e, l
            ld hl, QV
            ld bc, 256
            call .cp
            ld h, d
            ld l, e
            pop bc
            dec b
            jr nz, .sv
            call sp_sum                     ; the sum, then the magic (Lot Check 2.3)
            call sb_ram
            ld [$4000], a
            ld hl, SUSP_MAGIC + 4
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
            ld hl, SUSP_MAGIC
            ld a, 'S'
            ld [hl+], a
            ld a, 'U'
            ld [hl+], a
            ld a, 'S'
            ld [hl+], a
            ld [hl], 'P'
            jr .x
.load:      call sb_ram                     ; SUSP_RAM -> NES RAM (not page 1: the GB stack)
            ld [$4000], a
            ld hl, SUSP_RAM
            ld de, NES_RAM
            ld bc, $0100
            call .cp
            ld hl, SUSP_RAM + $0200
            ld de, NES_RAM + $0200
            ld bc, $0A00
            call .cp
            ld b, 32                        ; bank 2 -> save RAM
            ld hl, $A000
.ld:        push bc
            call sb_wram
            ld [$4000], a
            push hl
            ld de, QV
            ld bc, 256
            call .cp
            pop hl
            xor a
            ld [$4000], a
            ld d, h
            ld e, l
            ld hl, QV
            ld bc, 256
            call .cp
            ld h, d
            ld l, e
            pop bc
            dec b
            jr nz, .ld
.erase:     call sb_ram
            ld [$4000], a
            xor a
            ld [SUSP_MAGIC], a
.x:         xor a
            ld [$4000], a
            pop hl
            pop de
            pop bc
            pop af
            ret
.cp:        ld a, [hl+]                     ; HL -> DE, BC bytes
            ld [de], a
            inc de
            dec bc
            ld a, b
            or c
            jr nz, .cp
            ret

sb_ram:     ldh a, [save_sep]               ; the suspend point's banks: 5 / 6 with a save bank
            add a, a                        ;   of its own (64 KB), else 3 / 2
            add a, 3
            ret
sb_wram:    ldh a, [save_sep]
            add a, a
            add a, a
            add a, 2
            ret
sp_sum:     call sb_ram                     ; DE = the 16-bit sum of the suspend point (SUSP_RAM
            ld [$4000], a                   ;   $0C00 bytes, then the save RAM copy's 8 KB)
            ld de, 0
            ld hl, SUSP_RAM
.a:         ld a, [hl+]
            add a, e
            ld e, a
            jr nc, .an
            inc d
.an:        ld a, h
            cp high(SUSP_RAM + $0C00)
            jr nz, .a
            call sb_wram
            ld [$4000], a
            ld hl, $A000
.b:         ld a, [hl+]
            add a, e
            ld e, a
            jr nc, .bn
            inc d
.bn:        ld a, h
            cp $C0
            jr nz, .b
            xor a
            ld [$4000], a
            ret
