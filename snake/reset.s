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

    ; initialize seed for random values
    LDA #$01
    STA seed
    LDA #$b7
    STA seed+1

    ; initial snake position
    LDA #$20
    STA HEAD_HIGH
    STA BODY_START+1
    STA BODY_START+3
    LDA #$ee
    STA HEAD_LOW
    LDA #$ef
    STA BODY_START
    LDA #$f0
    STA BODY_START+2

    ; intial snake attributes
    LDA #LEFT
    STA snake_dir
    LDA #$04 ; 2 segments = 4 memory addresses
    STA snake_length

    ; reset score
    LDA #0
    STA score
    STA score+1
    STA score+2
    LDA #1
    STA update_score

    JMP main
.endproc

.segment "ZEROPAGE"
.importzp snake_dir, snake_length, seed, score, update_score
