.include "constants.inc"
.include "header.inc"

.segment "RODATA"
palettes:
; first four palettes are background
.byte $0f, $0f, $0f, $0f
.byte $0f, $0f, $27, $37
.byte $0f, $0f, $0f, $0f
.byte $0f, $0f, $0f, $0f
; next four palettes are sprites
.byte $0f, $21, $3d, $27
.byte $0f, $0f, $0f, $0f
.byte $0f, $0f, $0f, $0f
.byte $0f, $0f, $0f, $0f
spaceship:
; four sprites
.byte $70, $05, $00, $80
.byte $70, $06, $00, $88
.byte $78, $07, $00, $80
.byte $78, $08, $00, $88

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
  ; write sprite data
  LDX #$00
load_sprites:
  LDA spaceship,X
  STA $0200,X
  INX
  CPX #$10
  BNE load_sprites
  ; write a nametable
  LDA PPUSTATUS ; big star upper left
  LDA #$20
  STA PPUADDR
  LDA #$84
  STA PPUADDR
  LDX #$29
  STX PPUDATA
  LDA PPUSTATUS ; big star upper right
  LDA #$20
  STA PPUADDR
  LDA #$85
  STA PPUADDR
  LDX #$2a
  STX PPUDATA
  LDA PPUSTATUS ; big star lower left
  LDA #$20
  STA PPUADDR
  LDA #$a4
  STA PPUADDR
  LDX #$2b
  STX PPUDATA
  LDA PPUSTATUS ; big star lower right
  LDA #$20
  STA PPUADDR
  LDA #$a5
  STA PPUADDR
  LDX #$2c
  STX PPUDATA
  ; write attribute table
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$c9
  STA PPUADDR
  LDA #%00000001
  STA PPUDATA
vblankwait:      ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait
  LDA #%10010000 ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  LDA #%00011110 ; turn on screen
  STA PPUMASK
forever:
  JMP forever
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"
