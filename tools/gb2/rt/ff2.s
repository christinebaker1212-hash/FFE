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
            ld a, [NES_RAM + $03]
            cp $80
            jp c, .slow
            cp $C0
            jp nc, .slow
            ldh a, [lcd_on]                 ; LCD on: CGB only (tile copy + DMA marks)
            and a
            jr z, .lok
            ldh a, [is_cgb]
            and a
            jp z, .slow
.lok:       ld a, e                         ; tiles: X / 16 (X = 0: 256 bytes)
            swap a
            and $0F
            jr nz, .tn
            ld a, 16
.tn:        ldh [uw_y], a
            ld a, [NES_RAM + $03]           ; source HL = GB $4000 + ptr - $8000 (data bank)
            sub $40
            ld h, a
            ld a, [NES_RAM + $02]
            ld l, a
            ldh a, [data_bank8]
            ld [$2000], a
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
.copy:      ld b, 8
.p0:        ld a, [hl+]
            ld [de], a
            inc e
            inc e
            dec b
            jr nz, .p0
            ld a, e
            sub 15
            ld e, a
            ld b, 8
.p1:        ld a, [hl+]
            ld [de], a
            inc e
            inc e
            dec b
            jr nz, .p1
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
            ld e, 0                         ; X = 0
            jr .done
.slow:      ld l, $02                       ; generic: LDA ($02),Y / STA $2007 / INY / DEX
            call rt_izy_rd
            ld a, l
            ldh [tmp_lo], a
            call rt_ppu_w7
            inc c
            dec e
            jr nz, .slow
.done:      xor a
            ldh [nzv], a
            pop af                          ; carry back
            ldh a, [tmp_lo]
            ld l, 0
            inc l
            dec l                           ; Z = 1
            ret

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
