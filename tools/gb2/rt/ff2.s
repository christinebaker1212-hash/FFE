; FF2-specific runtime routines (the rest of tools/gb2/rt is adapted from FF1's runtime).
; Register contract as in runtime.s: A = 6502 A, E = X (D = 0), C = Y (B = 0), HL scratch.

; ------------------------------------------------------------------ frame waits
; FF2 points its NMI vector at $0100 (RAM). The waits fix:FA2A / fix:FEAD write JMP $FA3C /
; JMP $FEA1 there and spin; at the NMI that stub writes RTI ($40) back to $0100, reads
; $2002 and drops the interrupt frame (PLA x3: A = $FA / $FE, N = 1, Z = 0; C, V kept),
; returning to the waiter's caller. Same RAM effects here, around the runtime's frame wait.
rt_wait_fa2a:
            push af
            ld a, $3C
            ld [NES_RAM + $101], a
            ld a, $FA
            ld [NES_RAM + $102], a
            ld a, $4C                       ; JMP
            ld [NES_RAM + $100], a
            pop af
            call rt_frame
            push af
            ld a, $40
            ld [NES_RAM + $100], a
            call rt_ppu_r2
            pop af
            ld a, $FA
            jr wait_nz
rt_wait_fead:
            push af
            ld a, $A1
            ld [NES_RAM + $101], a
            ld a, $FE
            ld [NES_RAM + $102], a
            ld a, $4C                       ; JMP
            ld [NES_RAM + $100], a
            pop af
            call rt_frame
            push af
            ld a, $40
            ld [NES_RAM + $100], a
            call rt_ppu_r2
            pop af
            ld a, $FE
wait_nz:    ldh [nzv], a                    ; N = 1
            inc a                           ; Z = 0, carry kept
            dec a
            ret

; ------------------------------------------------------------------ jump (long)
; fix:FA91: PHA #$FA / PHA #$99 / JMP ($0040): a call through the pointer at $40 (the
; target's RTS returns to $FA9A, where the translated code resumes after this call).
rt_call_ind40:
            ld hl, NES_RAM + $40
            jp rt_jmp_ind

; ------------------------------------------------------------------ TSX / TXS
; X = $FF - (GB stack depth) / 2. Every GB stack entry is 2 bytes (PHA too), so this is
; >= the NES S (deeper NES stacks need more nesting to reach a stack-depth check), and
; rt_txs maps it back to exactly the GB stack pointer TSX saw. A, F, BC kept.
rt_tsx:     push af
            ld hl, sp + 4                   ; the caller's SP
            ld a, low(STACK_TOP)
            sub l
            ld l, a
            ld a, high(STACK_TOP)
            sbc h
            srl a
            rr l
            ld a, $FF
            sub l
            ld e, a
            pop af
            ret
rt_txs:     push af                         ; SP = STACK_TOP - 2 * ($FF - X); A, F, BC, DE kept
            pop hl
            ld a, h
            ldh [sv_a], a
            ld a, l
            ldh [uw_f], a
            pop hl                          ; return address
            ld a, l
            ldh [uw_ret], a
            ld a, h
            ldh [uw_ret + 1], a
            ld a, $FF
            sub e
            ld l, a
            ld h, 0
            add hl, hl
            ld a, low(STACK_TOP)
            sub l
            ld l, a
            ld a, high(STACK_TOP)
            sbc h
            ld h, a
            ld sp, hl
            ldh a, [uw_ret + 1]
            ld h, a
            ldh a, [uw_ret]
            ld l, a
            push hl
            ldh a, [sv_a]
            ld h, a
            ldh a, [uw_f]
            ld l, a
            push hl
            pop af
            ret

; ------------------------------------------------------------------ sprite 0
; BIT $2002 / BVS (wait for the sprite-0 flag to clear) and BVC (wait for the hit) loops:
; no wait on the GB (translate.py idioms); V as each loop leaves it. A, C kept.
rt_s0_clear:
            push hl
            ld hl, vfl
            res 6, [hl]
            pop hl
            ret
rt_s0_hit:
            push hl
            ld hl, vfl
            set 6, [hl]
            pop hl
            ret

; ------------------------------------------------------------------ battle NMI
; FF2's battle points the NMI ($0100) at its own handlers (b12:9A79, b05:A9A2: sprite-0
; split, music, $AC = 0) while the main code computes (monster actions, the actions). The
; vblank ISR only notes that one is due (nmi_check); the translated handler then runs at
; the next safe point (ROM data reads, cross-bank returns, the $AC waits), with the whole
; runtime context saved; its RTI is a ret (translate.py), and its music update restores
; the NES bank through $3E as on the Famicom.
nmi_check:                                  ; (vblank ISR; A, HL free)
            ld hl, NES_RAM + $100
            ld a, [hl+]
            cp $4C                          ; JMP
            ret nz
            ld a, [hl+]
            cp $3C                          ; not the waits' stubs ($FA3C, $FEA1)
            jr z, .w1
            cp $A1
            jr nz, .due
            ld a, [hl]
            cp $FE
            ret z
            jr .due
.w1:        ld a, [hl]
            cp $FA
            ret z
.due:       ldh a, [ppu_ctrl]               ; NMI enabled
            bit 7, a
            ret z
            ldh a, [in_nmi]
            and a
            ret nz
            ld a, 1
            ldh [nmi_req], a
            ret

rt_nmi_run:                                 ; all registers kept
            push af
            xor a
            ldh [nmi_req], a
            ldh a, [in_nmi]
            and a
            jr nz, .busy
            inc a
            ldh [in_nmi], a
            push bc
            push de
            push hl
            ldh a, [nzv]
            ld h, a
            ldh a, [vfl]
            ld l, a
            push hl
            ldh a, [sv_a]
            ld h, a
            ldh a, [wtmp]
            ld l, a
            push hl
            ldh a, [tmp_lo]
            ld h, a
            ldh a, [fc_bank]
            ld l, a
            push hl
            ld a, [NES_RAM + $101]
            ld l, a
            ld a, [NES_RAM + $102]
            ld h, a
            call rt_dyn_call
            pop hl
            ld a, h
            ldh [tmp_lo], a
            ld a, l
            ldh [fc_bank], a
            pop hl
            ld a, h
            ldh [sv_a], a
            ld a, l
            ldh [wtmp], a
            pop hl
            ld a, h
            ldh [nzv], a
            ld a, l
            ldh [vfl], a
            pop hl
            pop de
            pop bc
            xor a
            ldh [in_nmi], a
.busy:      pop af
            ret

; STA $AC / LDA $AC / BNE (battle: wait until the NMI handler has run): wait here for the
; handler (run at once when due). Out: A = 0, Z = 1, N = 0; carry kept.
rt_ac_wait:
            push af
.lp:        ld a, [NES_RAM + $AC]
            and a
            jr z, .done
            ldh a, [nmi_req]
            and a
            jr nz, .run
            halt
            jr .lp
.run:       call rt_nmi_run
            jr .lp
.done:      ldh [nzv], a                    ; N = 0
            pop af                          ; carry back
            ld a, 0
            inc a
            dec a                           ; Z = 1
            ret

; ------------------------------------------------------------------ cameras
; NES writes (GB layout code, tools/gb2/layout.py; nothing on the NES): $5800 / $5801
; camera X / Y in tiles (runtime.s), $5802 fine X (pixels 0-7, after $5800), $5803 the GB
; line where a second camera starts (0: none), $5804 / $5805 its X / Y in tiles (absolute:
; the NES scroll is not added). A, F kept.
rt_mmc_w5802:
            push af
            push bc
            and 7
            ld b, a
            ldh a, [cam_x]
            and $F8
            or b
            ldh [cam_x], a
            pop bc
            pop af
            ret
rt_mmc_w5803:
            ld [CAM2_LINE], a
            ret
rt_mmc_w5804:
            push af
            add a, a
            add a, a
            add a, a
            ld [CAM2_X], a
            pop af
            ret
rt_mmc_w5805:
            push af
            add a, a
            add a, a
            add a, a
            ld [CAM2_Y], a
            pop af
            ret

; OAM conversion (A = CAM2_LINE, E = end of the GB sprites): sprites at or below the line
; are shown with the second camera: GB x += cam_x - CAM2_X, GB y += cam_y - CAM2_Y.
spr_cam2:   push bc
            push de
            push hl
            add a, 16
            ld b, a                         ; B = OAM y of the line
            ldh a, [cam_x]
            ld hl, CAM2_X
            sub [hl]
            ld c, a                         ; C = x delta
            ldh a, [cam_y]
            ld hl, CAM2_Y
            sub [hl]
            ld d, a                         ; D = y delta
            ld a, e
            and a
            jr z, .done
            ld hl, OAM_SH
.lp:        ld a, [hl]
            cp b
            jr c, .nx
            add a, d
            ld [hl+], a
            ld a, [hl]
            add a, c
            ld [hl-], a
.nx:        inc l
            inc l
            inc l
            inc l
            ld a, l
            cp e
            jr c, .lp
.done:      pop hl
            pop de
            pop bc
            ret

; ------------------------------------------------------------------ native CHR copy
; fix:FD6F "copy data to ppu": LDA $2002 / ($01,$00) -> $2006 / LDY #0 / loop LDA ($02),Y /
; STA $2007 / INY / DEX / BNE. Exit: A = last byte, X = 0, Y = count (mod 256), Z = 1, N = 0,
; carry kept. Fast path (battle / map graphics): whole tiles from $8000-$BFFF into a pattern
; table, +1 increment; BG or sprite table by $2000 bit 4 (as rt_ppu_w7); else per byte.
hle_ppucopy:
            push af                         ; caller's carry
            call rt_ppu_r2
            ld a, [NES_RAM + $01]
            call rt_ppu_w6
            ld a, [NES_RAM + $00]
            call rt_ppu_w6
            ld c, 0                         ; Y = 0
            ld l, $02
            call cp_core
cp_tail:    xor a
            ldh [nzv], a
            pop af                          ; carry back
            ldh a, [tmp_lo]
            ld l, 0
            inc l
            dec l                           ; Z = 1
            ret

; fix:E69E-E6A5 (map / tileset graphics load): LDA ($80),Y / STA $2007 / INY / BNE: the
; rest of a page. Exit: A = last byte, Y = 0, Z = 1, N = 0, X and carry kept.
hle_chrpg:  push af
            push de
            ld a, c
            cpl
            inc a
            ld e, a                         ; 256 - Y bytes (Y = 0: 256)
            ld l, $80
            call cp_core
            pop de
            jr cp_tail

; b11:9DB1-9DB8 (battle intro, the enemies' dissolve: 128 bytes of tiles from $7700 per
; frame): LDA ($02),Y / STA $2007 / INY / BPL. Exit: A = last byte, Y = $80, N = 1, Z = 0, X
; and carry kept.
hle_chr128: push af
            ld a, c
            cp $80
            jr nc, .odd
            push de
            cpl
            add a, $81                      ; $80 - Y bytes
            ld e, a
            ld l, $02
            call cp_core
            pop de
.t:         ld a, $80
            ldh [nzv], a
            pop af
            ldh a, [tmp_lo]
            ld l, 1
            inc l                           ; Z = 0
            ret
.odd:       ld l, $02                       ; Y >= $80 on entry: as the NES, byte by byte
            call rt_izy_rd                  ;   while bit 7 of Y is clear after INY
            ld a, l
            ldh [tmp_lo], a
            call rt_ppu_w7
            inc c
            bit 7, c
            jr z, .odd
            jr .t

; L = zero-page address of the source pointer, E = count (0 = 256), C = Y: LDA (zp),Y /
; STA $2007 / INY, E times (source $6000-$BFFF, tiles: whole tiles at once). Out: tmp_lo = last byte, C += count, B = D = E = 0.
cp_core:    ld d, l                         ; (D = zp for the byte path)
            ld a, c
            and a
            jp nz, .slow
            ld a, e
            and $0F
            jp nz, .slow
            ldh a, [ppu_ctrl]
            and 4
            jp nz, .slow
            ldh a, [ppu_vh]
            cp $20
            jp nc, .slow
            ldh a, [ppu_vl]
            and $0F
            jp nz, .slow
            ld h, high(NES_RAM)             ; HL = the pointer
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld a, h                         ; source: $8000-$BFFF (ROM data bank) or
            cp $60                          ;   $6000-$7FFF (cart RAM bank 0)
            jp c, .slow
            cp $C0
            jp nc, .slow
            ld a, e                         ; tiles: X / 16 (X = 0: 256 bytes)
            swap a
            and $0F
            jr nz, .tn
            ld a, 16
.tn:        ldh [uw_y], a
            ld a, h
            cp $80
            jr c, .sram
            sub $40                         ; source HL = GB $4000 + ptr - $8000 (data bank)
            ld h, a
            ldh a, [data_bank8]
            ld [$2000], a
            xor a
            jr .src
.sram:      add a, $40                      ; NES $6000-$7FFF = GB $A000-$BFFF
            ld h, a
            ld a, 1
.src:       ld [CP_SRAM], a
            push de
.tile:      ldh a, [ppu_vl]
            and $F0
            ld e, a
            ldh a, [ppu_vh]
            ld d, a
            and $10
            ld b, a
            ldh a, [ppu_ctrl]
            and $10
            xor b
            ld a, d                         ; (flags kept)
            jr nz, .spr
            and $0F
            ld d, a
            ldh a, [is_cgb]
            and a
            ld a, d
            jr nz, .bgv
            add a, high(BG_SHADOW)          ; DMG: BG tile to the shadow, re-coded later
            ld d, a
            ld a, 1
            ld [$4000], a
            jr .copy
.bgv:       ld d, a
            ldh a, [lcd_on]
            and a
            ld a, d
            jr nz, .bgs
            cp $08                          ; CGB, LCD off: VRAM (tiles 0-127 $9000, 128-255 $8800)
            ld d, $90
            jr c, .bg0
            ld d, $80
.bg0:       and $0F
            add a, d
            ld d, a
            jr .copy
.bgs:       add a, $D0                      ; CGB, LCD on: the tile copy (WRAM bank 2), marked
            ld d, a
            ld a, 2
            ldh [$FF70], a
            jr .copy
.spr:       and $0F                         ; sprite table: the shadow (cart RAM bank 1)
            add a, high(SPR_SHADOW)
            ld d, a
            ld a, 1
            ld [$4000], a
.copy:      ld a, d                         ; source and destination both in cart RAM
            cp $A0                          ;   (banks 0 / 1): the bank switched per byte
            jr c, .cr
            cp $C0
            jr nc, .cr
            ld a, [CP_SRAM]
            and a
            jr nz, .cs
.cr:        ld b, 0                         ; (16 bytes unrolled: plane 0 rows to the
                                            ;   even bytes, plane 1 to the odd ones)
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, e
            sub 15
            ld e, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            jr .cd
.cs:        call .pl                        ; a plane at a time through CP_BUF (bank 0 ->
            ld a, e                         ;   buffer, bank 1 -> shadow): plane 0 to the
            sub 15                          ;   even bytes, plane 1 to the odd ones
            ld e, a
            call .pl
            jr .cd
.pl:        push de                         ; (unrolled)
            xor a
            ld [$4000], a
            ld de, CP_BUF
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            pop de
            ld a, 1                         ; bank 1 for the shadow
            ld [$4000], a
            push hl
            ld hl, CP_BUF
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            pop hl
            ret
.cd:        ldh [tmp_lo], a                 ; last byte
            ld a, d
            cp $D0
            jr c, .nst
            ld a, 1                         ; tile copy: WRAM bank 1 again, mark the tile
            ldh [$FF70], a
            push hl
            ld a, e
            sub 17
            swap a
            and $0F
            ld e, a
            ld a, d
            sub $D0
            swap a
            or e
            ld hl, BG_DIRTY
            call hd_mark
            pop hl
            jr .nx
.nst:       cp $80
            jr c, .nvr
            cp $A0                          ; (VRAM $80-$97: nothing to mark)
            jr c, .nx
.nvr:       cp high(BG_SHADOW)
            jr c, .spm
            call ff2_bg_tile
            jr .nx
.spm:       call ff2_spr_tile
.nx:        ldh a, [ppu_vl]                 ; v += 16, Y += 16
            add a, 16
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            ld a, c
            add a, 16
            ld c, a
            ldh a, [uw_y]
            dec a
            ldh [uw_y], a
            jr nz, .tile
            pop de
            ldh a, [code_bank]
            ld [$2000], a
            ld b, 0
            ld d, b
            ld e, b
            ret
.slow:      ld l, d                         ; generic: LDA (zp),Y / STA $2007 / INY / DEX
            call rt_izy_rd
            ld a, l
            ldh [tmp_lo], a
            call rt_ppu_w7
            inc c
            dec e
            jr nz, .slow
            ld d, 0
            ret


; b11:9D68 "fill ppu" (STA $2007 / DEX / BNE: A = value, X = count, 0 = 256): whole tiles of a
; pattern table go in at once (both planes the constant: every GB byte = the value), marked
; as hle_ppucopy marks them; anything else byte by byte through rt_ppu_w7. Returns X = 0,
; Z = 1, N = 0, A and C kept, Y kept.
hle_fill:   ldh [tmp_lo], a
            push af                         ; caller's carry
            ld a, e
            and $0F
            jp nz, .slow
            ldh a, [ppu_ctrl]
            and 4
            jp nz, .slow
            ldh a, [ppu_vh]
            cp $20
            jp nc, .slow
            ldh a, [ppu_vl]
            and $0F
            jp nz, .slow
            ld a, e                         ; tiles: X / 16 (X = 0: 16) (DMG with the LCD
                                            ;   on too: shadow + one re-coding mark per tile)
            swap a
            and $0F
            jr nz, .tn
            ld a, 16
.tn:        ldh [uw_y], a
.tile:      ldh a, [ppu_vl]
            and $F0
            ld e, a
            ldh a, [ppu_vh]
            ld d, a
            and $10
            ld b, a
            ldh a, [ppu_ctrl]
            and $10
            xor b
            ld a, d                         ; (flags kept)
            jr nz, .spr
            and $0F
            ld d, a
            ldh a, [is_cgb]
            and a
            ld a, d
            jr nz, .bgv
            add a, high(BG_SHADOW)          ; DMG: BG tile to the shadow, re-coded later
            ld d, a
            ld a, 1
            ld [$4000], a
            jr .fill
.bgv:       ld d, a
            ldh a, [lcd_on]
            and a
            ld a, d
            jr nz, .bgs
            cp $08                          ; CGB, LCD off: VRAM (tiles 0-127 $9000, 128-255 $8800)
            ld d, $90
            jr c, .bg0
            ld d, $80
.bg0:       and $0F
            add a, d
            ld d, a
            jr .fill
.bgs:       add a, $D0                      ; CGB, LCD on: the tile copy (WRAM bank 2), marked
            ld d, a
            ld a, 2
            ldh [$FF70], a
            jr .fill
.spr:       and $0F                         ; sprite table: the shadow (cart RAM bank 1)
            add a, high(SPR_SHADOW)
            ld d, a
            ld a, 1
            ld [$4000], a
.fill:      ldh a, [tmp_lo]                 ; (16 bytes, unrolled)
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            ld [de], a
            inc e
            inc e                           ; DE = start + 17 (as hle_ppucopy's marks)
            ld a, d
            cp $D0
            jr c, .nst
            ld a, 1                         ; tile copy: WRAM bank 1 again, mark the tile
            ldh [$FF70], a
            ld a, e
            sub 17
            swap a
            and $0F
            ld e, a
            ld a, d
            sub $D0
            swap a
            or e
            ld hl, BG_DIRTY
            call hd_mark
            jr .nx
.nst:       cp $80
            jr c, .nvr
            cp $A0                          ; (VRAM $80-$97: nothing to mark)
            jr c, .nx
.nvr:       cp high(BG_SHADOW)
            jr c, .spm
            call ff2_bg_tile
            jr .nx
.spm:       call ff2_spr_tile
.nx:        ldh a, [ppu_vl]                 ; v += 16
            add a, 16
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            ldh a, [uw_y]
            dec a
            ldh [uw_y], a
            jr nz, .tile
            ld e, 0                         ; X = 0
            jr .done
.slow:      ldh a, [lcd_on]                 ; nametable cells (no attribute byte) with the LCD
            and a                           ;   off: in bulk (hle_fill_nt), else byte by byte
            jr nz, .gen
            ldh a, [ppu_ctrl]
            and 4
            jr nz, .gen
            ldh a, [ppu_vh]
            cp $20
            jr c, .gen
            cp $30
            jr nc, .gen
            and 3
            ld d, a                         ; last offset = (vh & 3) * 256 + vl + count - 1
            ldh a, [ppu_vl]
            ld l, a
            ld a, e
            dec a
            add a, l
            ld h, a                         ; (low byte of the last offset)
            ld a, d
            adc a, 0
            cp 3
            jr c, .ntok
            jr nz, .gen
            ld a, h
            cp $C0
            jr nc, .gen
.ntok:      call hle_fill_nt
            jr .done
.gen:       ldh a, [tmp_lo]
            call rt_ppu_w7
            dec e
            jr nz, .gen
.done:      ld b, 0
            ld d, 0
            xor a
            ldh [nzv], a
            pop af                          ; carry back
            ldh a, [tmp_lo]
            ld l, 0
            inc l
            dec l                           ; Z = 1
            ret

; hle_fill's nametable run (LCD off; E = count, 0 = 256; D = offset high, L = offset low;
; value in tmp_lo): NES shadow, GB map, owner bits (own1 count kept) per cell; CGB: the
; run's cells take their palette from their (new) nametable's attributes if an owner
; changed; DMG: the map scan when the LCD goes on. PPU address advanced. Keeps C (Y).
F_ADD      = $D839          ; high(NT_SH) - $98 + nametable * 4 (shadow page from map page)
F_CHG      = $D83A          ; an owner changed
F_D0       = $D83B          ; start: map page, offset low, count
F_L0       = $D83C
F_CNT      = $D83D
hle_fill_nt:
            push bc
            ldh a, [ppu_vh]
            and 4
            ldh [sh_nt], a
            add a, high(NT_SH) - $98
            ld [F_ADD], a
            xor a
            ld [F_CHG], a
            ld a, d
            add a, $98
            ld d, a                         ; D:L = GB map cell
            ld [F_D0], a
            ld a, l
            ld [F_L0], a
            ld a, e
            ld [F_CNT], a
            ldh a, [tmp_lo]                 ; GB map (LCD off), then the NES shadow
            ld h, d
            ld b, e
.fm:        ld [hl+], a
            dec b
            jr nz, .fm
            ld a, [F_ADD]
            add a, d
            ld h, a
            ld a, [F_L0]
            ld l, a
            ldh a, [tmp_lo]
            ld b, e
.fs:        ld [hl+], a
            dec b
            jr nz, .fs
            ld a, d                         ; owner bits: cell n = (page - $98) * 256 + low;
            sub $98                         ;   byte n / 8, bit n & 7; C = cells left
            ld b, a
            ld a, [F_L0]
            ld l, a
            ld c, e
.ob:        ld a, l                         ; byte index B * 32 + L / 8
            rrca
            rrca
            rrca
            and $1F
            ld h, a
            ld a, b
            swap a
            add a, a
            or h
            ld e, a                         ; E = owner byte index
            ld a, l
            and 7
            jr nz, .obit                    ; not at a byte start: one cell
            ld a, c
            cp 8
            jr c, .obit                     ; fewer than 8 left: one cell
            ld h, high(OWN)                 ; 8 cells: the whole byte
            push hl
            ld l, e
            ldh a, [sh_nt]
            and a
            ld a, $FF
            jr nz, .o8
            xor a
.o8:        ld d, [hl]
            ld [hl], a
            xor d                           ; changed bits -> own1 count
            jr z, .o8x
            ld e, a                         ; (E: changed bits; D: old byte)
            ld a, 1
            ld [F_CHG], a
            ld d, 0                         ; D = number of changed bits
.pop:       inc d
            ld a, e
            dec a
            and e
            ld e, a
            jr nz, .pop
            ldh a, [sh_nt]
            and a
            jr z, .pdec
            ldh a, [own1_lo]                ; own1 += D (nametable 1) / -= D
            add a, d
            ldh [own1_lo], a
            ldh a, [own1_hi]
            adc a, 0
            ldh [own1_hi], a
            jr .o8x
.pdec:      ldh a, [own1_lo]
            sub d
            ldh [own1_lo], a
            ldh a, [own1_hi]
            sbc a, 0
            ldh [own1_hi], a
.o8x:       pop hl
            ld a, l
            add a, 8
            ld l, a
            jr nc, .o8n
            inc b
.o8n:       ld a, c
            sub 8
            ld c, a
            jr nz, .ob
            jr .odone
.obit:      ld a, l                         ; one cell: mask 1 << (low & 7)
            and 7
            ld d, a
            ld a, 1
            jr z, .m0
.ms:        add a, a
            dec d
            jr nz, .ms
.m0:        ld d, a
            push hl
            ld h, high(OWN)
            ld l, e
            ld a, [hl]
            and d
            ld e, a                         ; old bit
            ldh a, [sh_nt]
            and a
            jr z, .clr
            ld a, [hl]
            or d
            ld [hl], a
            ld a, e
            and a
            jr nz, .same                    ; 1 -> 1
            ldh a, [own1_lo]
            add a, 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            adc a, 0
            ldh [own1_hi], a
            jr .chg
.clr:       ld a, d
            cpl
            and [hl]
            ld [hl], a
            ld a, e
            and a
            jr z, .same                     ; 0 -> 0
            ldh a, [own1_lo]
            sub 1
            ldh [own1_lo], a
            ldh a, [own1_hi]
            sbc a, 0
            ldh [own1_hi], a
.chg:       ld a, 1
            ld [F_CHG], a
.same:      pop hl
            inc l
            jr nz, .on
            inc b
.on:        dec c
            jr nz, .ob
.odone:
            ldh a, [is_cgb]
            and a
            jr nz, .cgb
            ld a, 1                         ; DMG: shaded when the LCD goes on
            ldh [dmg_scan], a
            jr .adv
.cgb:       ld a, [F_CHG]
            and a
            jr z, .adv
            ld a, [F_D0]                    ; CGB: palettes of the run's cells (VRAM bank 1)
            ld d, a
            ld a, [F_L0]
            ld l, a
            ld a, [F_CNT]
            ld c, a
            ld a, 1
            ldh [$FF4F], a
.pc:        ld a, l
            and 31
            ld e, a                         ; col
            ld a, d
            sub $98
            add a, a
            add a, a
            add a, a
            ld b, a
            ld a, l
            swap a
            rrca
            and 7
            or b                            ; row
            call cell_pal
            ld h, d
            ld [hl], a
            inc l
            jr nz, .pn
            inc d
.pn:        dec c
            jr nz, .pc
            xor a
            ldh [$FF4F], a
.adv:       ld a, [F_CNT]                   ; v += count (0 = 256)
            ld e, a
            ldh a, [ppu_vl]
            add a, e
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            adc a, 0
            ld b, a
            ld a, e
            and a
            jr nz, .a1
            inc b
.a1:        ld a, b
            and $3F
            ldh [ppu_vh], a
            ld e, 0                         ; X = 0
            pop bc
            ret

; fix:E50E "copy large data to ppu" (Y = 0; X pages of 256 bytes from ($80), INC $81 per
; page) and fix:E51E "copy data to ppu" (X bytes from ($80),Y): through copy_core. Exits as
; the NES loops leave things: A = last byte, X = 0, Z = 1, N = 0, C kept; E50E: Y = 0 and
; $81 advanced; E51E: Y advanced (8 bits).
hle_copy_e50e:
            push af                         ; caller's carry
.pg:        ld a, [NES_RAM + $81]
            ld h, a
            ld a, [NES_RAM + $80]
            ld l, a
            push de
            ld e, 0                         ; 256 bytes
            call copy_core
            pop de
            ld hl, NES_RAM + $81
            inc [hl]
            dec e
            jr nz, .pg
            ld c, 0                         ; Y = 0
            jr hle_copy_x
hle_copy_e51e:
            push af
            ld a, c                         ; byte by byte if Y would wrap
            add a, e
            jr c, .w
            jr z, .w2
            jr .nw
.w2:        ld a, e                         ; (Y + X = 256: no wrap unless X = 0)
            and a
            jr z, .w
.nw:        ld a, [NES_RAM + $81]
            ld h, a
            ld a, [NES_RAM + $80]
            ld l, a
            ld b, 0
            add hl, bc                      ; source = ($80) + Y
            ld a, c
            add a, e
            ld c, a                         ; Y += X
            call copy_core
            ld b, 0
            jr hle_copy_x
.w:         ld l, $80                       ; generic: LDA ($80),Y / STA $2007 / INY / DEX
            call rt_izy_rd
            ld a, l
            ldh [tmp_lo], a
            call rt_ppu_w7
            inc c
            dec e
            jr nz, .w
hle_copy_x: ld b, 0
            ld d, 0
            ld e, 0                         ; X = 0
            xor a
            ldh [nzv], a
            pop af                          ; carry back
            ldh a, [tmp_lo]                 ; A = last byte
            ld l, 0
            inc l
            dec l                           ; Z = 1
            ret

; HL = NES source, E = count (0 = 256) -> the PPU at its address (tmp_lo = last byte).
; Whole tiles of a pattern table from ROM $8000-$BEFF in one go each (as hle_ppucopy),
; else byte by byte. Keeps C; B, D, E, HL clobbered.
copy_core:  ld a, e
            and $0F
            jp nz, .slow
            ldh a, [ppu_ctrl]
            and 4
            jp nz, .slow
            ldh a, [ppu_vh]
            cp $20
            jp nc, .slow
            ldh a, [ppu_vl]
            and $0F
            jp nz, .slow
            ld a, h
            cp $80
            jp c, .slow
            cp $BF
            jp nc, .slow
            ldh a, [lcd_on]                 ; LCD on: CGB only (tile copy + DMA marks)
            and a
            jr z, .lok
            ldh a, [is_cgb]
            and a
            jp z, .slow
.lok:       ld a, e
            swap a
            and $0F
            jr nz, .tn
            ld a, 16
.tn:        ldh [uw_y], a
            ld a, h                         ; GB $4000 + source - $8000 (data bank)
            sub $40
            ld h, a
            ldh a, [data_bank8]
            ld [$2000], a
.tile:      ldh a, [ppu_vl]
            and $F0
            ld e, a
            ldh a, [ppu_vh]
            ld d, a
            and $10
            ld b, a
            ldh a, [ppu_ctrl]
            and $10
            xor b
            ld a, d                         ; (flags kept)
            jr nz, .spr
            and $0F
            ld d, a
            ldh a, [is_cgb]
            and a
            ld a, d
            jr nz, .bgv
            add a, high(BG_SHADOW)          ; DMG: BG tile to the shadow, re-coded later
            ld d, a
            ld a, 1
            ld [$4000], a
            jr .copy
.bgv:       ld d, a
            ldh a, [lcd_on]
            and a
            ld a, d
            jr nz, .bgs
            cp $08                          ; CGB, LCD off: VRAM (tiles 0-127 $9000, 128-255 $8800)
            ld d, $90
            jr c, .bg0
            ld d, $80
.bg0:       and $0F
            add a, d
            ld d, a
            jr .copy
.bgs:       add a, $D0                      ; CGB, LCD on: the tile copy (WRAM bank 2), marked
            ld d, a
            ld a, 2
            ldh [$FF70], a
            jr .copy
.spr:       and $0F                         ; sprite table: the shadow (cart RAM bank 1)
            add a, high(SPR_SHADOW)
            ld d, a
            ld a, 1
            ld [$4000], a
.copy:      ld b, 0                         ; (16 bytes unrolled: plane 0 rows to the
                                            ;   even bytes, plane 1 to the odd ones)
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, e
            sub 15
            ld e, a
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ld a, [hl+]
            ld [de], a
            inc e
            inc e
            ldh [tmp_lo], a                 ; last byte
            ld a, d
            cp $D0
            jr c, .nst
            ld a, 1                         ; tile copy: WRAM bank 1 again, mark the tile
            ldh [$FF70], a
            push hl
            ld a, e
            sub 17
            swap a
            and $0F
            ld e, a
            ld a, d
            sub $D0
            swap a
            or e
            ld hl, BG_DIRTY
            call hd_mark
            pop hl
            jr .nx
.nst:       cp $80
            jr c, .nvr
            cp $A0                          ; (VRAM $80-$97: nothing to mark)
            jr c, .nx
.nvr:       cp high(BG_SHADOW)
            jr c, .spm
            call ff2_bg_tile
            jr .nx
.spm:       call ff2_spr_tile
.nx:        ldh a, [ppu_vl]                 ; v += 16
            add a, 16
            ldh [ppu_vl], a
            ldh a, [ppu_vh]
            adc a, 0
            and $3F
            ldh [ppu_vh], a
            ldh a, [uw_y]
            dec a
            ldh [uw_y], a
            jr nz, .tile
            ldh a, [code_bank]
            ld [$2000], a
            ret
.slow:      push hl
            call nes_rd
            ld a, l
            ldh [tmp_lo], a
            call rt_ppu_w7
            pop hl
            inc hl
            dec e
            jr nz, .slow
            ret

; FF2's multiply / divide (rt/ff2_banked.s, bank HLE_BANK): tail calls through rt_fcs
; (A and flags kept both ways)
hle_mul8:   call rt_fcs
            db HLE_BANK
            dw hle_mul8_b
hle_mul16:  call rt_fcs
            db HLE_BANK
            dw hle_mul16_b
hle_div16:  call rt_fcs
            db HLE_BANK
            dw hle_div16_b
hle_objspr: call rt_fcs                    ; b03:A902 draw object sprite (native)
            db HLE_BANK
            dw hle_objspr_b
hle_water: call rt_fcs                     ; fix:C2F3 world-map water animation (native)
            db HLE_BANK
            dw hle_water_b
hle_ntclr0: call rt_fcs                    ; fix:F321 clear nametable 0 (native)
            db HLE_BANK
            dw hle_ntclr0_b
hle_bspr:   call rt_fcs                     ; b11:A43A draw battle character sprite (native)
            db HLE_BANK
            dw hle_bspr_b
hle_palup:  call rt_fcs                     ; b11:9D82 battle palette upload (native)
            db HLE_BANK
            dw hle_palup_b
hle_bfill:  call rt_fcs                     ; b11:9D24 battle OAM fill (native)
            db HLE_BANK
            dw hle_bfill_b
hle_bcopy:  call rt_fcs                     ; b11:9D4A battle 16-byte copy (native)
            db HLE_BANK
            dw hle_bcopy_b
hle_vtile:  call rt_fcs                    ; layout's vtile (banks 23 / 24: small-font tile upload)
            db HLE_BANK
            dw hle_vtile_b
hle_mapupd: call rt_fcs                    ; fix:D21B update map background (native)
            db HLE_BANK
            dw hle_mapupd_b
hle_initrng:
            call rt_fcs
            db HLE_BANK
            dw hle_initrng_b

ff2_bg_tile:                                ; DMG BG tile in the shadow (DE = start + 17, cart
            xor a                           ;   RAM bank 1 on): queue its re-coding; RAM bank 0
            ld [$4000], a
            ld a, e
            sub 17
            swap a
            and $0F
            ld e, a
            ld a, d
            sub high(BG_SHADOW)
            swap a
            or e
            jp dmg_markw
ff2_spr_tile:                               ; sprite tile in the shadow: its slot reloaded if
            push bc                         ;   resident; RAM bank 0. Keeps BC, HL.
            push hl
            ld a, e
            sub 17
            ld e, a
            ld a, d
            sub high(SPR_SHADOW)
            swap a
            ld b, a
            ld a, e
            swap a
            and $0F
            or b
            ld l, a
            ld h, high(SPR_SLOT)
            ld a, [hl]
            cp $FF
            jr z, .x
            add a, low(SLOT_KEY)
            ld l, a
            ld h, high(SLOT_KEY)
            ld [hl], $FF
.x:         xor a
            ld [$4000], a
            pop hl
            pop bc
            ret


; ------------------------------------------------------------------ palette override
; GB-only (tools/gb2/layout.py; nothing on the NES): a rectangle of nametable-0 cells drawn
; with one palette whatever the NES attributes say (finer than the NES's 16 x 16 blocks).
; $5806 / $5807 first / last column, $5808 / $5809 first / last row, $580A palette (bits
; 0-1) + bit 7 on. Every per-cell palette lookup (cell_pal, the DMG scan, cell_fast, the SGB
; attribute map, CGB attr_apply) goes through ovr_*.
; (OVR_* addresses: runtime.s)
rt_mmc_w5806:
            ld [OVR_C0], a
            ret
rt_mmc_w5807:
            ld [OVR_C1], a
            ret
rt_mmc_w5808:
            ld [OVR_R0], a
            ret
rt_mmc_w580B:                               ; GB-only: a field tileset was loaded (b0:9D6E ->
            push af                         ;   stub after "load map properties"): the DMG
            ld a, 1                         ;   fixes tile palettes at the next LCD-on
            ld [TSET_PEND], a
            pop af
            ret
tset_fix:   ld a, HLE_BANK                  ; (rt_ppu_w1, LCD going on; DMG / SGB)
            ld [$2000], a
            call tset_fix_b
            jp hle_back
rt_mmc_w5809:
            ld [OVR_R1], a
            ret
rt_mmc_w580A:
            push af
            push bc
            push de
            push hl
            ld b, a
            and 3
            ld [OVR_P], a
            ld a, b
            and $80
            ld [OVR_ON], a
            ld a, 1                         ; SGB: the attribute map again
            ldh [sgb_dirty], a
            ldh [sgb_adirty], a
            ld a, [OVR_R0]                  ; every cell of the rectangle again
            ld d, a
.r:         ld a, [OVR_C0]
            ld e, a
.c:         call ovr_cell
            ld a, [OVR_C1]
            cp e
            jr z, .cn
            inc e
            jr .c
.cn:        ld a, [OVR_R1]
            cp d
            jr z, .x
            inc d
            jr .r
.x:         pop hl
            pop de
            pop bc
            pop af
            ret
ovr_cell:                                   ; D = row, E = col (nametable 0): its palette again
            push de
            ldh a, [is_cgb]
            and a
            jr z, .dmg
            xor a                           ; CGB: VRAM bank 1 = cell_pal (override included)
            ldh [sh_nt], a
            ld a, d
            call cell_pal
            ld b, a
            call ovr_addr
            ld a, b
            call vram_put1
            pop de
            ret
.dmg:       ldh a, [lcd_on]                 ; DMG: with the LCD off the map is scanned when it
            and a                           ;   goes on; else the cell's tile checked now
            jr nz, .on
            inc a
            ldh [dmg_scan], a
            pop de
            ret
.on:        call ovr_addr                   ; tile from the shadow
            ld a, h
            sub $98 - high(NT_SH)
            ld h, a
            ld a, [hl]
            ld d, a
            ld a, h
            sub high(NT_SH)
            ld b, a                         ; offset high
            ld c, 0
            ld a, d
            call dmg_cell
            pop de
            ret
ovr_addr:                                   ; D = row, E = col -> HL = $9800 + row * 32 + col
            ld a, d
            and 7
            swap a
            add a, a
            or e
            ld l, a
            ld a, d
            srl a
            srl a
            srl a
            add a, $98
            ld h, a
            ret
ovr_blk:                                    ; attr_apply's block OVR_I: its overridden cells
            ld a, [OVR_ON]
            and a
            ret z
            ld a, [OVR_R0]
            ld d, a
.r:         ld a, [OVR_C0]
            ld e, a
.c:         ld a, d                         ; in this block: (row >> 2) * 8 + (col >> 2) = I
            and $1C
            add a, a
            ld b, a
            ld a, e
            srl a
            srl a
            or b
            ld b, a
            ld a, [OVR_I]
            cp b
            jr nz, .n
            call ovr_addr
            ld a, [OVR_P]
            call vram_put1
.n:         ld a, [OVR_C1]
            cp e
            jr z, .cn
            inc e
            jr .c
.cn:        ld a, [OVR_R1]
            cp d
            ret z
            inc d
            jr .r
ovr_be:     push hl                         ; A = palette of (row B, col E) -> A, overridden
            ld h, b
            ld l, e
            call ovr_hl
            pop hl
            ret
ovr_de:     push hl                         ; (row D, col E)
            ld h, d
            ld l, e
            call ovr_hl
            pop hl
            ret
ovr_eb:     push hl                         ; (row E, col B)
            ld h, e
            ld l, b
            call ovr_hl
            pop hl
            ret
ovr_hl:     push bc                         ; A = palette, H = row, L = col -> A (HL clobbered)
            push de
            ld b, a
            ld a, [OVR_ON]
            and a
            jr z, .x
            ld d, h
            ld e, l
            ld hl, OVR_C0
            ld a, e
            cp [hl]
            jr c, .x                        ; col < C0
            inc hl
            ld a, [hl]
            cp e
            jr c, .x                        ; C1 < col
            inc hl
            ld a, d
            cp [hl]
            jr c, .x                        ; row < R0
            inc hl
            ld a, [hl]
            cp d
            jr c, .x                        ; R1 < row
            ld a, [OVR_P]
            ld b, a
.x:         ld a, b
            pop de
            pop bc
            ret
