.include "constants.inc"

.segment "ZEROPAGE"
.importzp player_x, player_y, player_dir

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
  STA $0200,X ; set sprite y-positions off screen
  INX
  INX
  INX
  INX
  BNE clear_oam

vblankwait2:
  BIT PPUSTATUS
  BPL vblankwait2
  LDA #$80
  STA player_x
  LDA #$a0
  STA player_y
  LDA #$01
  STA player_dir
  JMP main
.endproc
