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
