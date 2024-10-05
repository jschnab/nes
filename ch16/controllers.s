.include "constants.inc"

.segment "ZEROPAGE"
.importzp pad1

.segment "CODE"
.export read_controller1
.proc read_controller1
    PHA
    TXA
    PHA
    PHP

    ; write 1, then 0, to CONTROLLER1
    ; to latch button states
    LDA #$01
    STA CONTROLLER1
    LDA #$00
    STA CONTROLLER1

    LDA #%00000001
    STA pad1

get_buttons:
    LDA CONTROLLER1  ; read next button's state
    LSR A            ; shift button state into carry flag
    ROL pad1         ; rotate button state from carry flag
                     ; onto right side of pad1
                     ; and leftmost bit of pad1 into carry flag
    BCC get_buttons  ; continue until original '1' is in carry flag

    PLP
    PLA
    TAX
    PLA
    RTS
.endproc
