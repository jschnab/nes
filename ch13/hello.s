.include "constants.inc"
.include "header.inc"

.segment "CODE"
.proc irq_handler
    RTI
.endproc

.proc nmi_handler
    LDA #$00
    STA OAMADDR
    LDA #$02
    STA OAMDMA
    LDA #$00
    STA $2005
    STA $2005
    RTI
.endproc

.import reset_handler

.export main
.proc main
    ; write a palette
    LDX PPUSTATUS
    LDX #$3f
    STX PPUADDR
    LDX #$00
    STX PPUADDR
load_palettes:
    LDA palettes,X
    STA PPUDATA
    INX
    CPX #$20
    BNE load_palettes

    ; write a nametable
    ; big stars first
    LDA PPUSTATUS
    LDA #$20
    STA PPUADDR
    LDA #$6b
    STA PPUADDR
    LDX #$2f
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$57
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$22
    STA PPUADDR
    LDA #$23
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$52
    STA PPUADDR
    STX PPUDATA

    ; medium stars
    LDA PPUSTATUS
    LDA #$20
    STA PPUADDR
    LDA #$74
    STA PPUADDR
    LDX #$2d
    STX PPUDATA
    
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$43
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$73
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$5d
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$22
    STA PPUADDR
    LDA #$2f
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$22
    STA PPUADDR
    LDA #$f7
    STA PPUADDR
    STX PPUDATA

    ; small stars
    LDA PPUSTATUS
    LDA #$20
    STA PPUADDR
    LDA #$f1
    STA PPUADDR
    LDX #$2e
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$a8
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$22
    STA PPUADDR
    LDA #$7a
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$44
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$7c
    STA PPUADDR
    STX PPUDATA

    ; attribute table
    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$C2
    STA PPUADDR
    LDX #%01000000
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$d5
    STA PPUADDR
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$e0
    STA PPUADDR
    LDX #%00000100
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$f4
    STA PPUADDR
    LDX #%01000000
    STX PPUDATA

    ; write sprite data
    LDX $00
load_sprites:
    LDA sprites,X
    STA $0200,X
    INX
    CPX $0f
    BNE load_sprites

vblankwait: ; wait for another vblank before continuing
    BIT PPUSTATUS
    BPL vblankwait
    LDA #%10010000 ; turn on NMIs, sprites use first pattern table
    STA PPUCTRL
    LDA #%00011110 ; turn on screen
    STA PPUMASK
forever:
    JMP forever
.endproc

.segment "RODATA"
palettes:
.byte $0f, $12, $23, $27
.byte $0f, $2b, $3c, $39
.byte $0f, $0c, $07, $13
.byte $0f, $19, $09, $29
.byte $0f, $21, $10, $15
.byte $0f, $19, $09, $29
.byte $0f, $19, $09, $29
.byte $0f, $19, $09, $29
sprites:
.byte $70, $05, $00, $80
.byte $70, $06, $00, $88
.byte $78, $07, $00, $80
.byte $78, $08, $00, $88

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "starfield.chr"
