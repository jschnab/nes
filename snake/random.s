.include "constants.inc"

.export random_x
.export random_y


.proc galois16
    LDA SEED
    LDY #8

:
    ASL
    ROL SEED+1
    BCC :+
    EOR #$39

:
    DEY
    BNE :--
    STA SEED
    CMP #0
    RTS
.endproc


; generates a random number between 8 and 232
; to be used for a random x-coordinate
.proc random_x
loop_random_x:
    JSR galois16
    CMP #$e8  ; we will add 8
    BPL loop_random_x

    ; add 8 to be between 8 and 232
    CLC
    ADC #$08

    ; truncate the result to multiples of 8
    LSR
    LSR
    LSR
    ASL
    ASL
    ASL

    RTS
.endproc


; generates a random number between 8 and 208
; to be used for a random y-coordinate
.proc random_y
loop_random_y:
    JSR galois16
    CMP #$c8  ; we will add 8
    BPL loop_random_y

    ; add 8 to be between 8 and 208
    CLC
    ADC #$08

    ; truncate the result to multiples of 8
    LSR
    LSR
    LSR
    ASL
    ASL
    ASL

    RTS
.endproc
