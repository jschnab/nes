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
    LDA #$a0
    STA apple_x
    LDA #$40
    STA apple_y
    LDA #$80
    STA HEAD_X
    LDA #$88
    STA BODY_X
    LDA #$88
    STA HEAD_Y
    STA BODY_Y
    LDA #LEFT
    STA snake_dir
    LDA #$04  ; 4 bytes = 2 segments
    STA snake_length

    JMP main
.endproc

.segment "ZEROPAGE"
.importzp apple_x, apple_y, snake_x, snake_y, snake_dir, snake_length
