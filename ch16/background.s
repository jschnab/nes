.include "constants.inc"

.segment "CODE"

.export draw_starfield
.proc draw_starfield
    ; X register stores high byte of nametable
    ; write nametables
    ; bit stars first
    LDA PPUSTATUS
    TXA
    STA PPUADDR
    LDA #$6b
    STA PPUADDR
    LDY #$2f
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$01 
    STA PPUADDR
    LDA #$57
    STA PPUADDR
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$02
    STA PPUADDR
    LDA #$23
    STA PPUADDR
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$03
    STA PPUADDR
    LDA #$52
    STA PPUADDR
    STY PPUDATA

    ; small star 1
    LDA PPUSTATUS
    TXA
    STA PPUADDR
    LDA #$74
    STA PPUADDR
    LDY #$2d
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$01
    STA PPUADDR
    LDA #$43
    STA PPUADDR
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$01
    STA PPUADDR
    LDA #$5d
    STA PPUADDR
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$01
    STA PPUADDR
    LDA #$73
    STA PPUADDR
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$02
    STA PPUADDR
    LDA #$2f
    STA PPUADDR
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$02
    STA PPUADDR
    LDA #$f7
    STA PPUADDR
    STY PPUDATA

    ; small start 2
    LDA PPUSTATUS
    TXA
    STA PPUADDR
    LDA #$f1
    STA PPUADDR
    LDY #$2e
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$01
    STA PPUADDR
    LDA #$a8
    STA PPUADDR
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$01
    STA PPUADDR
    LDA #$7a
    STA PPUADDR
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$03
    STA PPUADDR
    LDA #$44
    STA PPUADDR
    STY PPUDATA

    LDA PPUSTATUS
    TXA
    ADC #$03
    STA PPUADDR
    LDA #$7c
    STA PPUADDR
    STY PPUDATA

    ; attribute table
    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$c2
    STA PPUADDR
    LDA #%01000000
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$e0
    STA PPUADDR
    LDA #%00001100
    STA PPUDATA

    RTS
.endproc

.export draw_objects
.proc draw_objects
    ; draw objects in the starfield
    ; and update attribute tables
    ; galaxy and planet
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$90
    STA PPUADDR
    LDX #$30
    STX PPUDATA
    LDX #$31
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$b0
    STA PPUADDR
    LDX #$32
    STX PPUDATA
    LDX #$33
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$20
    STA PPUADDR
    LDA #$42
    STA PPUADDR
    LDX #$38
    STX PPUDATA
    LDX #$39
    STX PPUDATA

    LDA PPUSTATUS
    LDA #$20
    STA PPUADDR
    LDA #$62
    STA PPUADDR
    LDX #$3a
    STX PPUDATA
    LDX #$3b
    STX PPUDATA

    ; nametable 2 additions: big galaxy, space station
    LDA PPUSTATUS
    LDA #$28
    STA PPUADDR
    LDA #$c9
    STA PPUADDR
    LDA #$41
    STA PPUDATA
    LDA #$42
    STA PPUDATA
    LDA #$43
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$28
    STA PPUADDR
    LDA #$e8
    STA PPUADDR
    LDA #$50
    STA PPUDATA
    LDA #$51
    STA PPUDATA
    LDA #$52
    STA PPUDATA
    LDA #$53
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$29
    STA PPUADDR
    LDA #$08
    STA PPUADDR
    LDA #$60
    STA PPUDATA
    LDA #$61
    STA PPUDATA
    LDA #$62
    STA PPUDATA
    LDA #$63
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$29
    STA PPUADDR
    LDA #$28
    STA PPUADDR
    LDA #$70
    STA PPUDATA
    LDA #$71
    STA PPUDATA
    LDA #$72
    STA PPUDATA

    ; space station
    LDA PPUSTATUS
    LDA #$29
    STA PPUADDR
    LDA #$f2
    STA PPUADDR
    LDA #$44
    STA PPUDATA
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$29
    STA PPUADDR
    LDA #$f6
    STA PPUADDR
    LDA #$44
    STA PPUDATA
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$2a
    STA PPUADDR
    LDA #$12
    STA PPUADDR
    LDA #$54
    STA PPUDATA
    STA PPUDATA
    LDA #$45
    STA PPUDATA
    LDA #$46
    STA PPUDATA
    LDA #$54
    STA PPUDATA
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$2a
    STA PPUADDR
    LDA #$32
    STA PPUADDR
    LDA #$44
    STA PPUDATA
    STA PPUDATA
    LDA #$55
    STA PPUDATA
    LDA #$56
    STA PPUDATA
    LDA #$44
    STA PPUDATA
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$2a
    STA PPUADDR
    LDA #$52
    STA PPUADDR
    LDA #$44
    STA PPUDATA
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$2a
    STA PPUADDR
    LDA #$56
    STA PPUADDR
    LDA #$44
    STA PPUDATA
    STA PPUDATA

    ; attribute tables
    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    LDA #$dc
    STA PPUADDR
    LDA #%00000001
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$2b
    STA PPUADDR
    LDA #$ca
    STA PPUADDR
    LDA #%10100000
    STA PPUDATA

    LDA PPUSTATUS
    LDA #$2b
    STA PPUADDR
    LDA #$d2
    STA PPUADDR
    LDA #%00001010
    STA PPUDATA

    RTS
.endproc
