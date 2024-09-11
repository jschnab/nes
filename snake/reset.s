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
    STA SEED
    LDA #$40
    STA apple_y
    STA SEED

    LDA #$80
    STA snake_x
    LDA #$88
    LDX #$01
    STA snake_x, X
    LDA #$88
    STA snake_y
    STA snake_y, X

    LDA #LEFT
    STA snake_dir
    LDA #$02
    STA snake_length

    JMP main
.endproc

.segment "ZEROPAGE"
.importzp apple_x, apple_y, snake_x, snake_y, snake_dir, snake_length
