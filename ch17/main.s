.include "constants.inc"
.include "header.inc"

.import reset_handler
.import draw_starfield
.import draw_objects
.import read_controller1
.import draw_enemy
.import process_enemies

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
scroll: .res 1
ppuctrl_settings: .res 1
pad1: .res 1

; enemy object pool
enemy_x_pos: .res NUM_ENEMIES
enemy_y_pos: .res NUM_ENEMIES
enemy_x_vel: .res NUM_ENEMIES
enemy_y_vel: .res NUM_ENEMIES

; enemy status:
; bit 0-3 is enemy type
; bit 7 is active if set, else inactive
enemy_flags: .res NUM_ENEMIES

current_enemy: .res 1
current_enemy_type: .res 1
enemy_timer: .res 1

; player bullet pool
bullet_xs: .res 3
bullet_ys: .res 3

sleeping: .res 1

.exportzp player_x, player_y, pad1
.exportzp enemy_x_pos, enemy_y_pos
.exportzp enemy_x_vel, enemy_y_vel
.exportzp enemy_flags, current_enemy, current_enemy_type, enemy_timer

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

    ; write tile locations
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
    ; bottom right tile (x + 8, y + 8)
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

.proc update_player
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    LDA pad1        ; load button presses
    AND #BTN_LEFT   ; filter out all but left
    BEQ check_right ; if result is zero, left not pressed
    DEC player_x    ; if the branch is not taken, move player left

check_right:
    LDA pad1
    AND #BTN_RIGHT
    BEQ check_up
    INC player_x

check_up:
    LDA pad1
    AND #BTN_UP
    BEQ check_down
    DEC player_y

check_down:
    LDA pad1
    AND #BTN_DOWN
    BEQ done_checking
    INC player_y

done_checking:
    PLA  ; done with updates, restore registers
    TAY
    PLA
    TAX
    PLA
    PLP
    RTS
.endproc

.export main
.proc main

    LDA #239  ; Y is only 240 lines tall
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
    STA enemy_flags, X
    LDA #$01
    STA enemy_y_vel, X
    INX
    CPX #$03
    BNE turtle_data

    ; X is now $03, no need to reset
snake_data:
    LDA #$01
    STA enemy_flags, X
    LDA #$02
    STA enemy_y_vel, X
    INX
    CPX #$05
    BNE snake_data

    LDX #$00
    LDA #$01
setup_enemy_x:
    STA enemy_x_pos, X
    CLC
    ADC #$20
    INX
    CPX #NUM_ENEMIES
    BNE setup_enemy_x

vblankwait: ; wait for another vblank before continuing
    BIT PPUSTATUS
    BPL vblankwait
    LDA #%10010000 ; turn on NMIs, sprites use first pattern table
    STA ppuctrl_settings
    STA PPUCTRL
    LDA #%00011110 ; turn on screen
    STA PPUMASK

mainloop:
    ; read controllers
    JSR read_controller1

    ; update the player and prep to draw
    JSR update_player
    JSR draw_player

    ; process all enemies and draw them
    JSR process_enemies
    LDA #$00
    STA current_enemy
enemy_drawing:
    JSR draw_enemy
    INC current_enemy
    LDA current_enemy
    CMP #NUM_ENEMIES
    BNE enemy_drawing

    ; check if PPUCTRL needs to change
    LDA scroll ; did we reach the end of a nametable?
    BNE update_scroll
    ; if yes, update base nametable
    LDA ppuctrl_settings
    EOR #%00000010 ; flip bit 1 to its opposite
    STA ppuctrl_settings
    ; reset scroll to 240
    LDA #240
    STA scroll

update_scroll:
    DEC scroll

    ; done processing, wait for next vblank
    INC sleeping
sleep:
    LDA sleeping
    BNE sleep

    JMP mainloop
.endproc

.segment "RODATA"
palettes:
.byte $0f, $12, $23, $27
.byte $0f, $2b, $3c, $39
.byte $0f, $0c, $07, $13
.byte $0f, $19, $09, $29

.byte $0f, $21, $10, $15
.byte $0f, $09, $1a, $2a
.byte $0f, $01, $11, $31
.byte $0f, $19, $09, $29

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"
