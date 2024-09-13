.include "constants.inc"

.export random_high
.export random_low


.proc galois16
    LDA seed
    LDY #8

:
    ASL
    ROL seed+1
    BCC :+
    EOR #$39

:
    DEY
    BNE :--
    STA seed
    CMP #0
    RTS
.endproc


; generates a random number between 0 and 255
; to be used for the apple low byte
.proc random_low
loop_random_lo:
    JSR galois16
    RTS
.endproc


; generates a random number between 0 and 3
; to be used for a random y-coordinate
.proc random_high
loop_random_hi:
    JSR galois16
    AND #$03

    RTS
.endproc

.segment "ZEROPAGE"
.importzp seed
