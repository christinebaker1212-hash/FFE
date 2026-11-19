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
