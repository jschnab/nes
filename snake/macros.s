.macro vram_set_address address
    LDA PPUSTATUS
    LDA #>address
    STA PPUADDR
    LDA #<address
    STA PPUADDR
.endmacro

.macro vram_clear_address
    LDA #0
    STA PPUADDR
    STA PPUADDR
.endmacro

.macro assign_16i dest, value
; 'dest' is location in zeropage memory where to write 16-bit address
; 'value' is 16-bit address
    lda #<value
    sta dest+0
    lda #>value
    sta dest+1
.endmacro
