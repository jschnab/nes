.include "constants.inc"
.include "header.inc"

.import reset_handler

.segment "ZEROPAGE"
ppuctrl_settings: .res 1
sleeping: .res 1
numbers: .res 8

.segment "CODE"
.proc irq_handler
    RTI
.endproc

.proc nmi_handler
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    ; copy sprite data to OAM
    LDA #$00
    STA OAMADDR
    LDA #$02
    STA OAMDMA

    ; set PPUCTRL
    LDA ppuctrl_settings
    STA PPUCTRL

    ; all done
    LDA #$00
    STA sleeping

    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
    RTI
.endproc

.proc draw_numbers
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    LDA PPUSTATUS
    LDA #$20
    STA PPUADDR
    LDX #$00
    STX PPUADDR
    INX
    LDY #$20
    STY PPUDATA

    STA PPUADDR
    STX PPUADDR
    INX
    LDY #$1e
    STY PPUDATA

    STA PPUADDR
    STX PPUADDR
    INX
    LDY #$1e
    STY PPUDATA

    STA PPUADDR
    STX PPUADDR
    INX
    LDY #$23
    STY PPUDATA

    STA PPUADDR
    STX PPUADDR
    INX
    LDY #$1f
    STY PPUDATA

    STA PPUADDR
    STX PPUADDR
    INX
    LDY #$27
    STY PPUDATA

    STA PPUADDR
    STX PPUADDR
    INX
    LDY #$26
    STY PPUDATA

    STA PPUADDR
    STX PPUADDR
    INX
    LDY #$24
    STY PPUDATA

    LDA #$23
    STA PPUADDR
    LDA #$c0
    STA PPUADDR
    LDA #$00
    STA PPUDATA


    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
    RTS
.endproc

.export main
.proc main
    ; save numbers
    LDX #$00
    LDA #$02
    STA numbers,X
    INX
    LDA #$00
    STA numbers,X
    INX
    LDA #$00
    STA numbers,X
    INX
    LDA #$05
    STA numbers,X
    INX
    LDA #$01
    STA numbers,X
    INX
    LDA #$09
    STA numbers,X
    INX
    LDA #$08
    STA numbers,X
    INX
    LDA #$06
    STA numbers,X

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

vblankwait: ; wait for another vblank before continuing
    BIT PPUSTATUS
    BPL vblankwait
    LDA #%10010000 ; turn on NMIs, sprites use first pattern table
    STA ppuctrl_settings
    STA PPUCTRL
    LDA #%00011110 ; turn on screen
    STA PPUMASK

mainloop:
    JSR draw_numbers

    ; done processing, wait for next vblank
    INC sleeping
sleep:
    LDA sleeping
    BNE sleep

    JMP mainloop
.endproc

.segment "RODATA"
palettes:
.byte $0f, $20, $23, $27
.byte $0f, $12, $23, $27
.byte $0f, $23, $23, $27
.byte $0f, $27, $23, $27

.byte $0f, $20, $20, $20
.byte $0f, $20, $20, $20
.byte $0f, $20, $20, $20
.byte $0f, $20, $20, $20

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"
