.include "constants.inc"

.segment "ZEROPAGE"
.importzp pad1

.segment "CODE"
.export read_controller1
.proc read_controller1
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    ; write a 1 then a 0 to CONTROL1 to latch button states
    LDA #$01
    STA CONTROL1
    LDA #$00
    STA CONTROL1

    ; used to detect when we read all button states in pad1
    ; when this '1' goes into carry with ROL
    LDA #$01
    STA pad1

get_buttons:
    LDA CONTROL1
    LSR A
    ROL pad1

    BCC get_buttons

    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
    RTS
.endproc
