; Test builds only (GB3N_TEST=1, never a release): the boot waits here instead of starting the
; game; tools/gb3n/test/batdiff.py pokes a battle state into BZ and work RAM bank 1 (staging: the
; emulator shell reaches bank 1 only), writes a routine number to T_CMD and reads the result back
; from bank 1 when T_CMD is 0 again. The routine runs with bank 2 mapped, as in a battle.
T_CMD      = $C5F0
T_TMP      = $C700

section bank 0, $2000
test_loop:  xor a
            ld [T_CMD], a
            ld a, B_BAT
            call sbank
.w:         ld a, 1
            ldh [rSVBK], a
            ld a, [T_CMD]
            and a
            jr z, .w
            ld c, 1                         ; bank 1 -> bank 2
            call t_copy
            ld a, 2
            ldh [rSVBK], a
            ld a, [T_CMD]
            dec a
            ld c, a
            ld b, 0
            ld hl, t_banks
            add hl, bc
            ld a, [hl]
            call sbank
            ld a, c
            add a
            ld l, a
            ld h, 0
            ld de, t_table
            add hl, de
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            call .go
            ld c, 2                         ; bank 2 -> bank 1
            call t_copy
            ld a, 1
            ldh [rSVBK], a
            xor a
            ld [T_CMD], a
            jr .w
.go:        jp hl
; $D000-$DEFF from bank C to the other (1 <-> 2), 256 bytes at a time through T_TMP
t_copy:     ld d, $D0
.p:         ld a, c
            ldh [rSVBK], a
            ld h, d
            ld l, 0
            ld e, l
            push de
            ld d, high(T_TMP)
            ld b, 0
.a:         ld a, [hl+]
            ld [de], a
            inc e
            dec b
            jr nz, .a
            pop de
            ld a, c
            xor 3
            ldh [rSVBK], a
            ld h, high(T_TMP)
            ld l, 0
            push de
            ld e, 0
.b:         ld a, [hl+]
            ld [de], a
            inc e
            jr nz, .b
            pop de
            inc d
            ld a, d
            cp $DF
            jr nz, .p
            ret
t_table:    dw fe_A400, fe_AA16, fe_A732, fe_9E8A, fe_AF77, fe_A65E, fe_BEBF, fe_BF17, fe_A2E9
            dw fe_9777, fe_9DE4, fe_A458, fe_A487, fe_BA41, fe_BB49, fe_9D06
            dw fe_81C3, fe_8213, fe_8271, fe_8295, fe_82CE, fe_8306, fe_8374, fe_9CE3, fe_81A0
            dw t_setup, fe_A56F, t_rng
t_banks:    db B_BAT, B_BAT, B_BAT, B_BAT, B_BAT, B_BAT, B_BAT, B_BAT, B_BAT
            db B_BAT2, B_BAT2, B_BAT2, B_BAT2, B_BAT2, B_BAT2, B_BAT2
            db B_BAT2, B_BAT2, B_BAT2, B_BAT2, B_BAT2, B_BAT2, B_BAT2, B_BAT2, B_BAT2
            db B_BAT2, B_BAT2, B_BAT2

section bank B_BAT2, $7A00
t_setup:    call fe_A02A                    ; (FF3's 2E/9F2B-9F34 order)
            call fe_9FAA
            call fe_A31F
            jp fe_B909
t_rng:      ld a, [BZ + $00]                ; (the seed in BZ + 0 for the test)
            jp fe_FC27
