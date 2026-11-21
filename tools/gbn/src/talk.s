; FF1 native engine: talking to map objects. Our own code, written from what FF1's talk
; routines do (disassembly bank 0E, TalkRoutines): each object id has a routine kind and four
; bytes of talk data (dialogue numbers, a condition's object or item) from the ROM.
; Common bank: $5800 talk data (4 x 208), $5C00 kind per object id.
C_TALKDAT  = $5800
C_TALKKIND = $5C00

section bank 0, $2000
; HL = slot -> A = the dialogue to print (and the routine's effects)
talk_obj:   ld a, [hl]                      ; object id
            ld [talk_id], a
            ld l, a                         ; talk data -> talk_d (4 bytes)
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, C_TALKDAT
            add hl, de
            ld a, COMMON
            ld [MBC_BANK], a
            ld de, talk_d
            ld b, 4
.c:         ld a, [hl+]
            ld [de], a
            inc de
            dec b
            jr nz, .c
            ld a, [talk_d + 1]              ; (Talk_norm until the routines are in)
            ret

section wram, $CCA0
talk_id:    ds 1
talk_d:     ds 4
