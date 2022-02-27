.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
.exportzp player_x, player_y, player_dir

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

  ; update tiles  after DMA transfer
  JSR update_player
  JSR draw_player

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
  LDA PPUSTATUS ; small star upper left
  LDA #$20
  STA PPUADDR
  LDA #$e4
  STA PPUADDR
  LDX #$2d      ; store the tile once
  STX PPUDATA

  LDA PPUSTATUS ; small star upper right
  LDA #$21
  STA PPUADDR
  LDA #$74
  STA PPUADDR
  STX PPUDATA

  LDA PPUSTATUS ; small star lower left
  LDA #$23
  STA PPUADDR
  LDA #$64
  STA PPUADDR
  STX PPUDATA

  LDA PPUSTATUS ; small star lower right
  LDA #$22
  STA PPUADDR
  LDA #$f8
  STA PPUADDR
  STX PPUDATA

  LDA PPUSTATUS ; big star
  LDA #$20
  STA PPUADDR
  LDA #$bb
  STA PPUADDR
  LDX #$2e
  STX PPUDATA

  ; write attribute table
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$c9
  STA PPUADDR
  LDA #%00000000
  STA PPUDATA

  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$d5
  STA PPUADDR
  LDA #%00010000
  STA PPUDATA

  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$f1
  STA PPUADDR
  LDA #%00000000
  STA PPUDATA

  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$ee
  STA PPUADDR
  LDA #%00010000
  STA PPUDATA

  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$ee
  STA PPUADDR
  LDA #%00000000
  STA PPUDATA

  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$ce
  STA PPUADDR
  LDA #%00000100
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

.proc update_player
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA player_x
  CMP #$e0
  BCC not_at_right_edge
  ; if BCC is not taken, we are greater than $e0
  LDA #$00
  STA player_dir    ; start moving left
  JMP direction_set ; we already chose a direction so we can keep the left side check

not_at_right_edge:
  LDA player_x
  CMP #$10
  BCS direction_set
  ; if BCS not taken we are less than $10
  LDA #$01
  STA player_dir ; start moving right

direction_set:
  ; now actually update player_x
  LDA player_dir
  CMP #$01
  BEQ move_right
  ; if player_dir minus $01 is not zero that means player_dir was $00 and we
  ; need to move left
  DEC player_x
  JMP exit_subroutine

move_right:
  INC player_x

exit_subroutine:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_player
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; write player ship tile numbers
  LDA #$05
  STA $0201
  LDA #$06
  STA $0205
  LDA #$07
  STA $0209
  LDA #$08
  STA $020d

  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  ; store tile locations
  ; top left tile
  LDA player_y
  STA $0200
  LDA player_x
  STA $0203

  ; top right tile (x + 8)
  LDA player_y
  STA $0204
  LDA player_x
  CLC
  ADC #$08
  STA $0207

  ; bottom left tile (y + 8)
  LDA player_y
  CLC
  ADC #$08
  STA $0208
  LDA player_x
  STA $020b

  ; bootom right tile (x + 8, y + 8)
  LDA player_y
  CLC
  ADC #$08
  STA $020c
  LDA player_x
  CLC
  ADC #$08
  STA $020f

  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
palettes:
; first four palettes are background
.byte $0f, $12, $23, $31 ; blue star
.byte $0f, $16, $26, $37 ; red star
.byte $0f, $0f, $0f, $0f
.byte $0f, $0f, $0f, $0f
; next four palettes are sprites
.byte $0f, $21, $3d, $27
.byte $0f, $0f, $0f, $0f
.byte $0f, $0f, $0f, $0f
.byte $0f, $0f, $0f, $0f

.segment "CHR"
.incbin "graphics.chr"
