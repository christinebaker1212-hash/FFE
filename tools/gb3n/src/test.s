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
