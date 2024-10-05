.include "constants.inc"

.segment "CODE"
.import main
.export reset_handler
.proc reset_handler
    SEI
    CLD
    LDX #$00
    STX PPUCTRL
    STX PPUMASK

vblankwait:
    BIT PPUSTATUS
    BPL vblankwait

    LDX #$00
    LDA #$ff
clear_oam:
    STA $200,X  ; set sprite y-positions off the screen
    INX
    INX
    INX
    INX
    BNE clear_oam

    ; initialize zero-page values
    LDA #$80
    STA player_x
    LDA #$a0
    STA player_y

    JMP main
.endproc

.segment "ZEROPAGE"
.importzp player_x, player_y
