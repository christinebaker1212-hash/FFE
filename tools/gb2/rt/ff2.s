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
