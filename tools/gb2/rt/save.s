; FF2 save slots (Lot Check: save data checked at start-up; a damaged save is reported on
; screen before it is cleared). FF2's own rule (fix:DAC1): slot n (0-3) is NES $6300 + $300 n
; (cart RAM bank 0 $A300 + $300 n), valid if its 768 bytes sum to $FF and byte $2FE is $5A.
; FF2 shows an invalid slot as empty and never clears one, so a slot cut short by a power
; loss while saving would silently look empty. The runtime keeps a header in cart RAM bank 3
; at SV_HDR (never cleared at boot): "FF2S", the slots the game has saved to (bits 0-3) and
; that byte xor $A5. At boot (save_boot) every slot marked as saved that fails FF2's rule
; is reported with a message (own font) and the A Button, then cleared (zeros: an empty
; slot) and unmarked. Without a valid header (first use, or a ROM from before the header)
; the slots that are valid now are marked, nothing is cleared and nothing is shown.
SV_HDR     = $A100          ; cart RAM bank 3 (bank 3 $A000-$A0FF: test-runner pads)

section bank SGB_BANK, $6000
; b14:B27A, FF2's save (L0E_B262): LDA ($82),Y / STA ($80),Y / INY / BNE / INC $81 / INC $83 /
; DEX / BNE, X pages from ($82) to ($80) (NES RAM or work RAM). The same copy, byte for byte;
; then, if it was a whole slot (3 pages from Y = 0 to page $63 + 3n), slot n is marked as
; saved. Exit as the NES: A = the last byte, X = Y = 0, $81 / $83 + X, Z = 1, N = 0.
hle_savecp_b:
            ld a, [NES_RAM + $81]
            ld d, a                         ; D = the first destination page
            ld a, e                         ;   (a slot only if X = 3 and Y = 0)
            cp 3
            jr z, .x3
            ld d, 0                         ; (not 3 pages: no slot)
.x3:        ld a, c
            and a
            jr z, .y0
            ld d, 0
.y0:        ld a, d
            push af                         ; (the slot's page, or 0)
.by:        ld a, [NES_RAM + $82]           ; ($82) + Y
            add a, c
            ld l, a
            ld a, [NES_RAM + $83]
            adc a, 0
            call sv_map
            ld h, a
            ld d, [hl]
            ld a, [NES_RAM + $80]           ; ($80) + Y
            add a, c
            ld l, a
            ld a, [NES_RAM + $81]
            adc a, 0
            call sv_map
            ld h, a
            ld [hl], d
            inc c
            jr nz, .by
            ld hl, NES_RAM + $81
            inc [hl]
            ld hl, NES_RAM + $83
            inc [hl]
            dec e
            jr nz, .by
            pop af                          ; a whole slot: mark it
            sub $63
            jr c, .nm
            ld b, $FF                       ; B = (page - $63) / 3 if a multiple of 3, < 4
.dv:        inc b
            sub 3
            jr nc, .dv
            add a, 3
            jr nz, .nm
            ld a, b
            cp 4
            jr nc, .nm
            ld b, 1
            and a
            jr z, .bm
.sh:        sla b
            dec a
            jr nz, .sh
.bm:        di                              ; (cart RAM bank 3 for a moment)
            ld a, 3
            ld [$4000], a
            call sv_hdr_ok
            ld a, 0
            jr nz, .nh                      ;   (no header yet: just this slot)
            ld a, [SV_HDR + 4]
.nh:        or b
            call sv_hdr_put
            xor a
            ld [$4000], a
            ei
.nm:        ld a, d                         ; exit: A = the last byte copied
            ld b, 0
            ld d, 0
            ld e, 0
            ld l, 0
            push af
            xor a
            ldh [nzv], a
            pop af
            inc l
            dec l                           ; Z = 1
            ret

; A = NES page -> GB page (RAM $00-$07: WRAM, $60-$7F: cart RAM bank 0). Keeps the rest.
sv_map:     cp $08
            jr c, .ram
            add a, $40
            ret
.ram:       add a, high(NES_RAM)
            ret

; cart RAM bank 3: Z = 1 if the header is valid
sv_hdr_ok:  push hl
            ld hl, SV_HDR
            ld a, [hl+]
            cp $46
            jr nz, .x
            ld a, [hl+]
            cp $46
            jr nz, .x
            ld a, [hl+]
            cp $32
            jr nz, .x
            ld a, [hl+]
            cp $53
            jr nz, .x
            ld a, [hl+]
            xor $A5
            cp [hl]
.x:         pop hl
            ret

; cart RAM bank 3: header with the slots in A
sv_hdr_put: push hl
            ld hl, SV_HDR
            ld [hl], $46
            inc hl
            ld [hl], $46
            inc hl
            ld [hl], $32
            inc hl
            ld [hl], $53
            inc hl
            ld [hl+], a
            xor $A5
            ld [hl], a
            pop hl
            ret

; slot C (0-3) in cart RAM bank 0 -> HL = its first byte
sv_slot:    ld a, c
            add a, a
            add a, c
            add a, $A3
            ld h, a
            ld l, 0
            ret

; cart RAM bank 0: Z = 1 if slot C passes FF2's check (fix:DAC1)
sv_valid:   call sv_slot
            ld b, 3
            xor a
.s:         add a, [hl]
            inc l
            jr nz, .s
            inc h
            dec b
            jr nz, .s
            inc a                           ; sum + 1 = 0
            ret nz
            dec h
            ld l, $FE
            ld a, [hl]
            cp $5A
            ret

; ---- boot (rt/runtime.s, LCD off, interrupts off, cart RAM enabled)
save_boot:  ld a, 3
            ld [$4000], a
            call sv_hdr_ok
            ld a, [SV_HDR + 4]
            ld d, a                         ; D = the slots marked as saved
            xor a
            ld [$4000], a
            ld e, 0                         ; E = the slots that pass the check
            ld c, 3
.v:         call sv_valid
            jr nz, .vn
            ld a, c
            call sv_bit
            or e
            ld e, a
.vn:        dec c
            bit 7, c
            jr z, .v
            ld a, 3
            ld [$4000], a
            call sv_hdr_ok
            jr z, .hdr
            ld a, e                         ; no header: mark the valid slots, nothing else
            call sv_hdr_put
            jr .x
.hdr:       ld c, 0                         ; damaged = marked and not valid
.d:         ld a, c
            call sv_bit
            ld b, a
            and d
            jr z, .dn
            ld a, b
            and e
            jr nz, .dn
            push bc
            push de
            call sv_msg                     ; slot C: the message, the A Button
            xor a
            ld [$4000], a
            call sv_slot                    ; cleared (an empty slot)
            ld bc, $300
            call memclr
            pop de
            pop bc
            ld a, b
            cpl
            and d
            ld d, a
            ld a, 3
            ld [$4000], a
            ld a, d
            call sv_hdr_put
.dn:        inc c
            ld a, c
            cp 4
            jr nz, .d
.x:         xor a
            ld [$4000], a
            ret

sv_bit:     ld b, 1                         ; A = 1 << A (A = 0-3). Keeps C, D, E.
            and a
            jr z, .x
.l:         sla b
            dec a
            jr nz, .l
.x:         ld a, b
            ret

; the message for slot C on a white screen (DMG / SGB: BGP; CGB: BG palette 0), until the
; A Button is pressed and released; the LCD off again (in the V-Blank) and VRAM cleared
sv_msg:     ld hl, SV_FONT                  ; font -> tiles 0..
            ld de, $8000
            ld b, (SV_FONT_END - SV_FONT) / 4
.f:         ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .f
            ld hl, SV_TEXT
.t:         ld a, [hl+]
            ld e, a
            ld a, [hl+]
            ld d, a
            or e
            jr z, .td
            ld b, [hl]
            inc hl
.tc:        ld a, [hl+]
            cp $FF
            jr nz, .tn
            ld a, c
            add a, $1C                      ; "1" + slot
.tn:        ld [de], a
            inc de
            dec b
            jr nz, .tc
            jr .t
.td:        ld a, %11100100                 ; DMG / SGB: colour 0 white, 3 black
            ldh [$FF47], a
            ldh a, [is_cgb]
            and a
            jr z, .on
            ld a, $80                       ; CGB: BG palette 0 white / - / - / black
            ldh [$FF68], a
            ld hl, SV_CGBPAL
            ld b, 8
.p:         ld a, [hl+]
            ldh [$FF69], a
            dec b
            jr nz, .p
.on:        xor a
            ldh [$FF42], a
            ldh [$FF43], a
            ld a, %10010001                 ; LCD on, BG tiles $8000, map $9800
            ldh [$FF40], a
.rel:       call sv_frame                   ; A Button released, pressed, released
            jr nz, .rel
.prs:       call sv_frame
            jr z, .prs
.rel2:      call sv_frame
            jr nz, .rel2
.wv:        ldh a, [$FF44]                  ; LCD off in the V-Blank (interrupts are off)
            cp 144
            jr c, .wv
            cp 152
            jr nc, .wv
            xor a
.lcdoff:    ldh [$FF40], a
            ld hl, $8000
            ld bc, $2000
            jp memclr

; one frame (LY 144 reached), then NZ if the A Button is down
sv_frame:
.a:         ldh a, [$FF44]
            cp 144
            jr z, .a
.b:         ldh a, [$FF44]
            cp 144
            jr nz, .b
            ld a, $10                       ; buttons
            ldh [$FF00], a
            ldh a, [$FF00]
            ldh a, [$FF00]
            ldh a, [$FF00]
            cpl
            and 1
            push af
            ld a, $30
            ldh [$FF00], a
            pop af
            ret

SV_CGBPAL:  dw $7FFF, $5294, $294A, $0000
SV_TEXT:                                    ; map address, length, tiles ($FF = the file number)
            dw $9862
            db 18, $14, $08, $05, $00, $13, $01, $16, $05, $00, $09, $0E, $00, $06, $09, $0C, $05, $00, $FF   ; THE SAVE IN FILE #
            dw $9882
            db 14, $09, $13, $00, $04, $01, $0D, $01, $07, $05, $04, $00, $01, $0E, $04   ; IS DAMAGED AND
            dw $98A2
            db 17, $03, $01, $0E, $0E, $0F, $14, $00, $02, $05, $00, $0C, $0F, $01, $04, $05, $04, $20   ; CANNOT BE LOADED.
            dw $9902
            db 18, $09, $14, $00, $17, $09, $0C, $0C, $00, $02, $05, $00, $05, $12, $01, $13, $05, $04, $20   ; IT WILL BE ERASED.
            dw $9981
            db 19, $10, $12, $05, $13, $13, $00, $14, $08, $05, $00, $01, $00, $02, $15, $14, $14, $0F, $0E, $20   ; PRESS THE A BUTTON.
            dw 0
SV_FONT:                                    ; tiles 0.. = " ABCDEFGHIJKLMNOPQRSTUVWXYZ01234." (2bpp, colour 3)
            db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00   ; ' '
            db $00, $00, $38, $38, $44, $44, $44, $44, $7C, $7C, $44, $44, $44, $44, $44, $44   ; 'A'
            db $00, $00, $78, $78, $44, $44, $44, $44, $78, $78, $44, $44, $44, $44, $78, $78   ; 'B'
            db $00, $00, $38, $38, $44, $44, $40, $40, $40, $40, $40, $40, $44, $44, $38, $38   ; 'C'
            db $00, $00, $78, $78, $44, $44, $44, $44, $44, $44, $44, $44, $44, $44, $78, $78   ; 'D'
            db $00, $00, $7C, $7C, $40, $40, $40, $40, $78, $78, $40, $40, $40, $40, $7C, $7C   ; 'E'
            db $00, $00, $7C, $7C, $40, $40, $40, $40, $78, $78, $40, $40, $40, $40, $40, $40   ; 'F'
            db $00, $00, $38, $38, $44, $44, $40, $40, $5C, $5C, $44, $44, $44, $44, $3C, $3C   ; 'G'
            db $00, $00, $44, $44, $44, $44, $44, $44, $7C, $7C, $44, $44, $44, $44, $44, $44   ; 'H'
            db $00, $00, $38, $38, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $38, $38   ; 'I'
            db $00, $00, $1C, $1C, $08, $08, $08, $08, $08, $08, $48, $48, $48, $48, $30, $30   ; 'J'
            db $00, $00, $44, $44, $48, $48, $50, $50, $60, $60, $50, $50, $48, $48, $44, $44   ; 'K'
            db $00, $00, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $7C, $7C   ; 'L'
            db $00, $00, $44, $44, $6C, $6C, $54, $54, $54, $54, $44, $44, $44, $44, $44, $44   ; 'M'
            db $00, $00, $44, $44, $64, $64, $54, $54, $4C, $4C, $44, $44, $44, $44, $44, $44   ; 'N'
            db $00, $00, $38, $38, $44, $44, $44, $44, $44, $44, $44, $44, $44, $44, $38, $38   ; 'O'
            db $00, $00, $78, $78, $44, $44, $44, $44, $78, $78, $40, $40, $40, $40, $40, $40   ; 'P'
            db $00, $00, $38, $38, $44, $44, $44, $44, $44, $44, $54, $54, $48, $48, $34, $34   ; 'Q'
            db $00, $00, $78, $78, $44, $44, $44, $44, $78, $78, $50, $50, $48, $48, $44, $44   ; 'R'
            db $00, $00, $3C, $3C, $40, $40, $40, $40, $38, $38, $04, $04, $04, $04, $78, $78   ; 'S'
            db $00, $00, $7C, $7C, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10   ; 'T'
            db $00, $00, $44, $44, $44, $44, $44, $44, $44, $44, $44, $44, $44, $44, $38, $38   ; 'U'
            db $00, $00, $44, $44, $44, $44, $44, $44, $44, $44, $44, $44, $28, $28, $10, $10   ; 'V'
            db $00, $00, $44, $44, $44, $44, $44, $44, $54, $54, $54, $54, $54, $54, $28, $28   ; 'W'
            db $00, $00, $44, $44, $44, $44, $28, $28, $10, $10, $28, $28, $44, $44, $44, $44   ; 'X'
            db $00, $00, $44, $44, $44, $44, $28, $28, $10, $10, $10, $10, $10, $10, $10, $10   ; 'Y'
            db $00, $00, $7C, $7C, $04, $04, $08, $08, $10, $10, $20, $20, $40, $40, $7C, $7C   ; 'Z'
            db $00, $00, $38, $38, $44, $44, $4C, $4C, $54, $54, $64, $64, $44, $44, $38, $38   ; '0'
            db $00, $00, $10, $10, $30, $30, $10, $10, $10, $10, $10, $10, $10, $10, $38, $38   ; '1'
            db $00, $00, $38, $38, $44, $44, $04, $04, $08, $08, $10, $10, $20, $20, $7C, $7C   ; '2'
            db $00, $00, $78, $78, $04, $04, $04, $04, $38, $38, $04, $04, $04, $04, $78, $78   ; '3'
            db $00, $00, $08, $08, $18, $18, $28, $28, $48, $48, $7C, $7C, $08, $08, $08, $08   ; '4'
            db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $30, $30, $30, $30   ; '.'
SV_FONT_END:
