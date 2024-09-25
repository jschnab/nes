.include "constants.inc"
.include "header.inc"
.include "macros.s"

.segment "CODE"
.proc irq_handler
    RTI
.endproc

.import read_controller1

.proc nmi_handler
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    LDA #$00
    STA OAMADDR
    LDA #$02
    STA OAMDMA

    JSR draw_apple
    JSR draw_snake

    LDA #1
    BIT update_score
    BEQ @skip_update_score
    JSR display_score
    ; reset update_score flag
    LDA #%11111110
    AND update_score
    STA update_score

@skip_update_score:
    LDA #0
    STA sleeping

    LDA #$00
    STA $2005
    STA $2005

    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
    RTI
.endproc

.proc add_score
    ; expects value to add to be stored in A
    CLC
    ADC score
    STA score
    ; if score <= 99 then we're done
    CMP #99
    BCC @skip
    ; if score > 100 then reset it and carry
    SEC
    SBC #100
    STA score
    INC score+1
    LDA score+1
    ; if score+1 <= 99 then we're done
    CMP #99
    BCC @skip
    ; otherwise reset it and carry
    SEC
    SBC #100
    STA score+1
    INC score+2
    LDA score+2
    ; if score+2 <= 99 then we're done
    CMP #99
    BCC @skip
    ; otherwise reset it and discard carry
    SEC
    SBC #100
    STA score+2

@skip:
    LDA #1
    ORA update_score
    STA update_score

    RTS
.endproc

.proc dec99_to_bytes
    ; function assumes number in range 0-99 is stored in A
    LDX #0
    CMP #50
    BCC try20
    SBC #50
    LDX #5
    BNE try20

div20:
    INX
    INX
    SBC #20
try20:
    CMP #20
    BCS div20

try10:
    CMP #10
    BCC @finished
    SBC #10
    INX

@finished:
    RTS            
.endproc

.proc display_score
    vram_set_address (NAME_TABLE_ADDR + $27)
    LDA score+2
    JSR dec99_to_bytes
    STX temp
    STA temp+1
    LDA score+1
    JSR dec99_to_bytes
    STX temp+2
    STA temp+3
    LDA score
    JSR dec99_to_bytes
    STX temp+4
    STA temp+5

    LDX #0
@loop:
    LDA temp,x
    CLC
    ADC #$60
    STA PPUDATA
    INX
    CPX #6
    BNE @loop
    LDA #$60
    STA PPUDATA

    vram_clear_address
    RTS
.endproc

.proc draw_snake
    ; if there's a collision, do not re-draw the snake
    ; because we check collision after updating the snake position
    LDA #1
    BIT collision
    BEQ @continue
    JMP @done

@continue:
    ; erase old tail
    ; important to do it first to avoid creating a hole in the snake
    LDA PPUSTATUS
    LDX snake_length
    LDA HEAD_HIGH,X
    STA PPUADDR
    LDA HEAD_LOW,X
    STA PPUADDR
    LDA #BACKGROUND_TILE
    STA PPUDATA

    ; draw body
    ; important to do to avoid drawing the body with head tiles
    ; do first to avoid overwriting the tail with a body tile
    LDA PPUSTATUS
    LDA BODY_START+1
    STA PPUADDR
    LDA BODY_START
    STA PPUADDR
    LDA #SNAKE_BODY_TILE
    STA PPUDATA

    ; draw new tail
    LDA PPUSTATUS
    LDX snake_length
    ; HEAD + snake_length points after snake
    ; so decrement to get last segment
    DEX
    DEX
    LDA HEAD_HIGH,X
    STA PPUADDR
    LDA HEAD_LOW,X
    STA PPUADDR
    ; select appropriate tail tile for snake direction
    ; compare the tail segment with the preceding segment
    LDY snake_length
    DEY
    DEY
    DEY
    DEY
    LDA HEAD_HIGH,X
    CMP HEAD_HIGH,Y
    BEQ @tail_compare_low_byte
    BPL @tail_down
    ; tail is pointing up
    JMP @tail_up
@tail_compare_low_byte:
    LDA HEAD_LOW,X
    CMP HEAD_LOW,Y
    BPL @tail_down_or_right
    ; tail is pointing up or left
    LDA HEAD_LOW,Y
    SEC
    SBC HEAD_LOW,X
    CMP #1
    BEQ @tail_left
@tail_up:
    LDA #TAIL_UP_TILE
    JMP @store_tail
@tail_left:
    LDA #TAIL_LEFT_TILE
    JMP @store_tail
@tail_down_or_right:
    SEC
    SBC HEAD_LOW,Y
    CMP #1
    BEQ @tail_right
    JMP @tail_down
@tail_right:
    LDA #TAIL_RIGHT_TILE
    JMP @store_tail
@tail_down:
    LDA #TAIL_DOWN_TILE
@store_tail:
    STA PPUDATA

    ; draw head
    LDA PPUSTATUS
    LDA HEAD_HIGH
    STA PPUADDR
    LDA HEAD_LOW
    STA PPUADDR
    ; select appropriate head tile for snake direction
    LDA snake_dir
    LSR
    BCS @up
    LSR
    BCS @down
    LSR
    BCS @left
    LSR
    BCS @right
@up:
    LDA #HEAD_UP_TILE
    JMP @store_head
@down:
    LDA #HEAD_DOWN_TILE
    JMP @store_head
@left:
    LDA #HEAD_LEFT_TILE
    JMP @store_head
@right:
    LDA #HEAD_RIGHT_TILE
@store_head:
    STA PPUDATA

@done:
    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL

    RTS
.endproc

.proc spawn_apple
@loop:
    LDA apple_high
    JSR random_high
    CLC
    ADC #$20
    STA apple_high
    LDA apple_low
    JSR random_low
    STA apple_low

    ; check if apple is in playable part of the screen (not in header)
    ; if apple is in header ($2000 to $203f) then loop
    LDA apple_high
    CMP #$21
    BCS @check_bottom
    LDA apple_low
    CMP #$40
    BCC @loop

@check_bottom:
    ; if apple if below bottom line (beyond $23bf) then loop
    LDA apple_high
    CMP #$23
    BNE @done
    LDA apple_low
    CMP #$c0
    BCS @loop

@done:
    RTS
.endproc

.proc draw_apple
    ; write apple data
    LDA PPUSTATUS
    LDA apple_high
    STA PPUADDR
    LDA apple_low
    STA PPUADDR
    LDA #APPLE_TILE
    STA PPUDATA

    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL

    RTS
.endproc

.proc update_game_state
    ; update snake only if timer is zero
    LDA timer
    BEQ @do_update
    DEC timer
    JMP @done

@do_update:
    ; reset timer
    LDA #TIMER_DURATION  ; this value controls game speed
    STA timer

    JSR update_snake_position
    JSR check_body_collision
    JSR check_apple_collision

@done:
    RTS
.endproc

.proc update_direction
    LDA #BTN_LEFT
    BIT pad1
    BNE left_key
    LDA #BTN_RIGHT
    BIT pad1
    BNE right_key
    LDA #BTN_UP
    BIT pad1
    BNE up_key
    LDA #BTN_DOWN
    BIT pad1
    BNE down_key
    JMP done_updating_direction

left_key:
    LDA #RIGHT
    BIT snake_dir
    BNE done_updating_direction
    LDA #LEFT
    STA snake_dir
    JMP done_updating_direction

right_key:
    LDA #LEFT
    BIT snake_dir
    BNE done_updating_direction
    LDA #RIGHT
    STA snake_dir
    JMP done_updating_direction

up_key:
    LDA #DOWN
    BIT snake_dir
    BNE done_updating_direction
    LDA #UP
    STA snake_dir
    JMP done_updating_direction

down_key:
    LDA #UP
    BIT snake_dir
    BNE done_updating_direction
    LDA #DOWN
    STA snake_dir

done_updating_direction:
    RTS
.endproc

.proc update_snake_position
    ; shift coordinates down the snake
    LDX snake_length
    DEX
update_snake_position_loop:
    LDA HEAD_LOW,X
    STA BODY_START,X
    DEX
    BPL update_snake_position_loop

    ; update head position
    LDA snake_dir
    LSR
    BCS up
    LSR
    BCS down
    LSR
    BCS left
    LSR
    BCS right

up:
    SEC
    LDA HEAD_LOW
    SBC #$20
    STA HEAD_LOW
    BCC up_high_byte
    JMP check_top_wall_collision
up_high_byte:
    DEC HEAD_HIGH
check_top_wall_collision:
    LDA HEAD_HIGH
    CMP #$20
    BNE done_updating_snake_position
    LDA HEAD_LOW
    SEC
    SBC #$40
    BCC wall_collision
    JMP done_updating_snake_position

down:
    CLC
    LDA HEAD_LOW
    ADC #$20
    STA HEAD_LOW
    BCS down_high_byte
    JMP check_bottom_wall_collision
down_high_byte:
    INC HEAD_HIGH
check_bottom_wall_collision:
    LDA HEAD_HIGH
    CMP #$23
    BNE done_updating_snake_position
    LDA HEAD_LOW
    CMP #$c0
    BCS wall_collision
    JMP done_updating_snake_position

left:
    DEC HEAD_LOW
    LDA HEAD_LOW
    AND #$1f
    CMP #$1f
    BEQ wall_collision
    JMP done_updating_snake_position

right:
    INC HEAD_LOW
    LDA #$1f
    BIT HEAD_LOW
    BEQ wall_collision
    JMP done_updating_snake_position

wall_collision:
    LDA #1
    STA collision
    JMP gameover

done_updating_snake_position:
    RTS
.endproc

.proc check_body_collision
    LDX #2  ; start on first body segment
@loop:
    LDA HEAD_LOW,X
    CMP HEAD_LOW
    BNE @continue
    LDA HEAD_HIGH,X
    CMP HEAD_HIGH
    BEQ @body_collision
@continue:
    INX
    INX
    CPX snake_length
    BNE @loop
    RTS
@body_collision:
    LDA #1
    STA collision
    JMP gameover
.endproc

.proc check_apple_collision
    LDA apple_low
    CMP HEAD_LOW
    BNE done_check_apple_collision
    LDA apple_high
    CMP HEAD_HIGH
    BNE done_check_apple_collision
    LDA #2
    JSR add_score
    JSR spawn_apple
    LDA snake_length
    CMP #$fe
    BPL grow_snake
    JMP done_check_apple_collision

grow_snake:
    INC snake_length
    INC snake_length

done_check_apple_collision:
    RTS
.endproc

.proc start_screen
    ; P
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cb
    STA PPUADDR
    LDA #$13
    STA PPUDATA

    ; R
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cc
    STA PPUADDR
    LDA #$15
    STA PPUDATA

    ; E
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cd
    STA PPUADDR
    LDA #$08
    STA PPUDATA

    ; S
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$ce
    STA PPUADDR
    LDA #$16
    STA PPUDATA

    ; S
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cf
    STA PPUADDR
    LDA #$16
    STA PPUDATA

    ; S
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d1
    STA PPUADDR
    LDA #$16
    STA PPUDATA

    ; T
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d2
    STA PPUADDR
    LDA #$17
    STA PPUDATA

    ; A
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d3
    STA PPUADDR
    LDA #$04
    STA PPUDATA

    ; R
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d4
    STA PPUADDR
    LDA #$15
    STA PPUDATA

    ; T
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d5
    STA PPUADDR
    LDA #$17
    STA PPUDATA

start_screen_loop:
    INC seed
    JSR read_controller1 
    LDA #BTN_STA
    BIT pad1
    BEQ start_screen_loop

    ; erase start message
    LDX #$ff

    ; P
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cb
    STA PPUADDR
    STX PPUDATA

    ; R
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cc
    STA PPUADDR
    STX PPUDATA

    ; E
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cd
    STA PPUADDR
    STX PPUDATA

    ; S
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$ce
    STA PPUADDR
    STX PPUDATA

    ; S
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cf
    STA PPUADDR
    STX PPUDATA

    ; S
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d1
    STA PPUADDR
    STX PPUDATA

    ; T
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d2
    STA PPUADDR
    STX PPUDATA

    ; A
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d3
    STA PPUADDR
    STX PPUDATA

    ; R
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d4
    STA PPUADDR
    STX PPUDATA

    ; T
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d5
    STA PPUADDR
    STX PPUDATA

    RTS
.endproc

.proc init_game
    ; draw header background tiles
    LDX #$00
    LDY #$20
loop_header_1:
    LDA PPUSTATUS
    STY PPUADDR
    STX PPUADDR
    LDA #$01
    STA PPUDATA
    INX
    CPX #$40
    BNE loop_header_1

    ; draw 'score' word
    ; S
    LDY #$20
    LDA PPUSTATUS
    STY PPUADDR
    LDA #$21
    STA PPUADDR
    LDA #$52
    STA PPUDATA

    ; C
    LDA #$42
    STA PPUDATA

    ; O
    LDA #$4e
    STA PPUDATA

    ; R
    LDA #$51
    STA PPUDATA

    ; E
    LDA #$44
    STA PPUDATA

    ; set header attribute table
    LDX #$c0
    LDY #$23
loop_header_2:
    LDA PPUSTATUS
    STY PPUADDR
    STX PPUADDR
    LDA #%00000101
    STA PPUDATA
    INX
    CPX #$c8
    BNE loop_header_2

    ; draw grass tiles
    LDX #$40
    LDY #$20
loop_grass_1:
    LDA PPUSTATUS
    STY PPUADDR
    STX PPUADDR
    LDA #$00
    STA PPUDATA
    INX
    BNE loop_grass_1

    ; draw grass attribute table
    LDX #$c8
    LDY #$23
loop_grass_2:
    LDA PPUSTATUS
    STY PPUADDR
    STX PPUADDR
    LDA #$00
    STA PPUDATA
    INX
    BNE loop_grass_2
   
    ; draw snake initial position
    LDX #$03
    ; head
    LDA PPUSTATUS
    LDA HEAD_HIGH
    STA PPUADDR
    LDA HEAD_LOW
    STA PPUADDR
    STX PPUDATA
    ; body
    LDA PPUSTATUS
    LDA BODY_START+1
    STA PPUADDR
    LDA BODY_START
    STA PPUADDR
    STX PPUDATA

    RTS
.endproc

.import random_low
.import random_high
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

    JSR init_game

vblankwait: ; wait for vblank before continuing
    BIT PPUSTATUS
    BPL vblankwait
    LDA #%10001000 ; turn on NMIs, sprites use first pattern table
    STA PPUCTRL
    LDA #%00011110 ; turn on screen
    STA PPUMASK

    LDA #0
    STA collision
    JSR spawn_apple

mainloop:
    JSR read_controller1
    JSR update_direction
    JSR update_game_state

    INC sleeping
sleep:
    LDA sleeping
    BNE sleep

    JMP mainloop
.endproc

.proc gameover
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cb
    STA PPUADDR

    LDX #0
@loop:
    LDA gameover_txt,X
    STA PPUDATA
    INX
    CMP #0
    BNE @loop

    ; use black palette for text
    LDX #$da
    LDY #$23
loop_attributes:
    LDA PPUSTATUS
    STY PPUADDR
    STX PPUADDR
    LDA #%01010101
    STA PPUDATA
    INX
    CPX #$de
    BNE loop_attributes

    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL

gameover_loop:
    JMP gameover_loop
.endproc

.segment "RODATA"
palettes:
.byte $2a, $19, $06, $16  ; light green, dark green, brown, red
.byte $2a, $0f, $10, $20  ; greys
.byte $2a, $09, $19, $29  ; greens
.byte $2a, $01, $21, $31  ; blues

.byte $2a, $00, $10, $30  ; greys
.byte $2a, $06, $16, $26  ; reds
.byte $2a, $09, $19, $29  ; greens
.byte $2a, $01, $21, $31  ; blues

gameover_txt:
.byte $46, $40, $4c, $44, $01, $4e, $55, $44, $51, 0

.segment "ZEROPAGE"
apple_low: .res 1
apple_high: .res 1
snake_dir: .res 1
snake_length: .res 1
pad1: .res 1
sleeping: .res 1
timer: .res 1
seed: .res 2
score: .res 3
update_score: .res 1
temp: .res 6
collision: .res 1
.exportzp apple_low, apple_high, snake_dir, snake_length, pad1, seed, score, update_score

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"
