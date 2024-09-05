.include "constants.inc"
.include "header.inc"

NUM_ENEMIES = 5

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
scroll: .res 1
ppuctrl_settings: .res 1
pad1: .res 1
; enemy object pool
enemy_x_pos: .res NUM_ENEMIES
enemy_y_pos: .res NUM_ENEMIES
enemy_x_vels: .res NUM_ENEMIES
enemy_y_vels: .res NUM_ENEMIES
enemy_flags: .res NUM_ENEMIES 
; track entity number in use
; for various subroutines
current_enemy: .res 1
current_enemy_type: .res 1

; timer for spawning enemies
enemy_timer: .res 1

; player bullet pool
bullet_xs: .res 3
bullet_ys: .res 3

sleeping: .res 1

.exportzp player_x, player_y, pad1
.exportzp enemy_x_pos, enemy_y_pos
.exportzp enemy_x_vels, enemy_y_vels
.exportzp enemy_flags, current_enemy, current_enemy_type
.exportzp enemy_timer

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

  ; set scroll values
  LDA #$00 ; X scroll first
  STA PPUSCROLL
  LDA scroll
  STA PPUSCROLL

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

.import read_controller1
.import reset_handler
.import draw_starfield, draw_objects
.import update_player, draw_player
.import update_enemy, process_enemies
.import draw_enemy

.export main
.proc main
	LDA #239	 ; Y is only 240 lines tall!
	STA scroll

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

	; write nametables
	LDX #$20
	JSR draw_starfield

	LDX #$28
	JSR draw_starfield

	JSR draw_objects

	; set up enemy slots
	LDA #$00
	STA current_enemy
	STA current_enemy_type

	LDX #$00
turtle_data:
	LDA #$00 ; turtle
	STA enemy_flags,X
	LDA #$01
	STA enemy_y_vels,X
	INX
	CPX #$03
	BNE turtle_data
	; X is now $03, no need to reset
snake_data:
	LDA #$01
	STA enemy_flags,X
	LDA #$02
	STA enemy_y_vels,X
	INX
	CPX #$05
	BNE snake_data

	LDX #$00
	LDA #$10
setup_enemy_x:
	STA enemy_x_pos,X
	CLC
	ADC #$20
	INX
	CPX #NUM_ENEMIES
	BNE setup_enemy_x

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
	STA ppuctrl_settings
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

mainloop:
	; Read controllers.
	JSR read_controller1

	; Update the player and prep to draw
	JSR update_player
	JSR draw_player

	; Process all enemies
	JSR process_enemies

	; Draw all enemies
	LDA #$00
	STA current_enemy
enemy_drawing:
	JSR draw_enemy
	INC current_enemy
	LDA current_enemy
	CMP #NUM_ENEMIES
	BNE enemy_drawing

	; Check if PPUCTRL needs to change
	LDA scroll ; did we reach the end of a nametable?
	BNE update_scroll
  ; if yes,
  ; Update base nametable
  LDA ppuctrl_settings
  EOR #%00000010 ; flip bit 1 to its opposite
  STA ppuctrl_settings
	; Reset scroll to 240
  LDA #240
  STA scroll

update_scroll:
	DEC scroll

	; Done processing; wait for next Vblank
	INC sleeping
sleep:
	LDA sleeping
	BNE sleep

	JMP mainloop
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
palettes:
.byte $0f, $12, $23, $27
.byte $0f, $2b, $3c, $39
.byte $0f, $0c, $07, $13
.byte $0f, $19, $09, $29

.byte $0f, $2d, $10, $15
.byte $0f, $09, $1a, $2a
.byte $0f, $01, $11, $31
.byte $0f, $19, $09, $29

.segment "CHR"
.incbin "objectpools.chr"
