.include "constants.inc"
.include "header.inc"

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

.proc draw_snake
    ; draw head
    LDA PPUSTATUS
    LDA HEAD_HIGH
    STA PPUADDR
    LDA HEAD_LOW
    STA PPUADDR
    LDA #$03
    STA PPUDATA

    ; erase tail
    LDA PPUSTATUS
    LDX snake_length
    LDA HEAD_HIGH,X
    STA PPUADDR
    LDA HEAD_LOW,X
    STA PPUADDR
    LDA #$ff
    STA PPUDATA

    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL

    RTS
.endproc

.proc spawn_apple
    LDA apple_high
    JSR random_high
    CLC
    ADC #$20
    STA apple_high
    LDA apple_low
    JSR random_low
    STA apple_low

    RTS
.endproc

.proc draw_apple
    ; write apple data
    LDA PPUSTATUS
    LDA apple_high
    STA PPUADDR
    LDA apple_low
    STA PPUADDR
    LDA #$01
    STA PPUDATA

    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL

    RTS
.endproc

.proc update_game_state
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    ; update snake only if timer is zero
    LDA timer
    BEQ do_update
    DEC timer
    JMP done_updating_state

do_update:
    ; reset timer
    LDA #TIMER_DURATION  ; this value controls game speed
    STA timer

    JSR update_snake_position
    JSR check_apple_collision
    JSR check_wall_collision

done_updating_state:
    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
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
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    ; shift x and y coordinates down the snake
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
    JMP done_updating_snake_position
up_high_byte:
    DEC HEAD_HIGH
    JMP done_updating_snake_position

down:
    CLC
    LDA HEAD_LOW
    ADC #$20
    STA HEAD_LOW
    BCS down_high_byte
    JMP done_updating_snake_position
down_high_byte:
    INC HEAD_HIGH
    JMP done_updating_snake_position

left:
    DEC HEAD_LOW
    JMP done_updating_snake_position

right:
    INC HEAD_LOW

done_updating_snake_position:
    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
    RTS
.endproc

.proc check_apple_collision
    LDA apple_low
    CMP HEAD_LOW
    BNE done_check_apple_collision
    LDA apple_high
    CMP HEAD_HIGH
    BNE done_check_apple_collision
    INC snake_length
    INC snake_length
    JSR spawn_apple

done_check_apple_collision:
    RTS
.endproc

.proc check_wall_collision
    ; top wall, check if going up wraps around screen
    LDA HEAD_HIGH
    CMP #$20
    BNE check_collision_left_wall
    LDA HEAD_LOW
    SEC
    SBC #$20
    BCC did_collide

check_collision_left_wall:
    ; left wall, check if going left wraps around screen
    LDA HEAD_LOW
    SEC
    SBC #$01
    AND #$1f
    CMP #$1f
    BEQ did_collide

    ; right wall
    LDA HEAD_LOW
    AND #$1f
    CMP #$1f
    BEQ did_collide

    ; bottom wall
    ; check if going down 1 line of nametable goes above #$23bf
    LDA HEAD_HIGH
    CMP #$23
    BNE done_check_wall_collision
    LDA HEAD_LOW
    CMP #$a0
    BCS did_collide

done_check_wall_collision:
    RTS

did_collide:
    JMP gameover
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

    ; write nametable
    LDY #$00
    LDX #$02
loop_nametab_top:
    LDA PPUSTATUS
    LDA #$20
    STA PPUADDR
    STY PPUADDR
    STX PPUDATA
    INY
    CPY #$20
    BNE loop_nametab_top

    LDY #$a0
loop_nametab_bottom:
    LDA PPUSTATUS
    LDA #$23
    STA PPUADDR
    STY PPUADDR
    STX PPUDATA
    INY
    CPY #$c0
    BNE loop_nametab_bottom

    LDA #$20
loop_nametab_left1:
    LDY PPUSTATUS
    LDY #$20
    STY PPUADDR
    STA PPUADDR
    STX PPUDATA
    CLC
    ADC #$20
    BNE loop_nametab_left1

loop_nametab_left2:
    LDY PPUSTATUS
    LDY #$21
    STY PPUADDR
    STA PPUADDR
    STX PPUDATA
    CLC
    ADC #$20
    BNE loop_nametab_left2

loop_nametab_left3:
    LDY PPUSTATUS
    LDY #$22
    STY PPUADDR
    STA PPUADDR
    STX PPUDATA
    CLC
    ADC #$20
    BNE loop_nametab_left3

loop_nametab_left4:
    LDY PPUSTATUS
    LDY #$23
    STY PPUADDR
    STA PPUADDR
    STX PPUDATA
    CLC
    ADC #$20
    CMP #$a0
    BNE loop_nametab_left4

    LDA #$1f
loop_nametab_right1:
    LDY PPUSTATUS
    LDY #$20
    STY PPUADDR
    STA PPUADDR
    STX PPUDATA
    CLC
    ADC #$20
    CMP #$1f
    BNE loop_nametab_right1

loop_nametab_right2:
    LDY PPUSTATUS
    LDY #$21
    STY PPUADDR
    STA PPUADDR
    STX PPUDATA
    CLC
    ADC #$20
    CMP #$1f
    BNE loop_nametab_right2

loop_nametab_right3:
    LDY PPUSTATUS
    LDY #$22
    STY PPUADDR
    STA PPUADDR
    STX PPUDATA
    CLC
    ADC #$20
    CMP #$1f
    BNE loop_nametab_right3

loop_nametab_right4:
    LDY PPUSTATUS
    LDY #$23
    STY PPUADDR
    STA PPUADDR
    STX PPUDATA
    CLC
    ADC #$20
    CMP #$bf
    BNE loop_nametab_right4

vblankwait: ; wait for another vblank before continuing
    BIT PPUSTATUS
    BPL vblankwait
    LDA #%10010000 ; turn on NMIs, sprites use first pattern table
    STA PPUCTRL
    LDA #%00011110 ; turn on screen
    STA PPUMASK

mainloop:
    JSR read_controller1
    JSR update_direction
    JSR update_game_state
    JSR draw_apple
    JSR draw_snake

    INC sleeping
sleep:
    LDA sleeping
    BNE sleep

    JMP mainloop
.endproc

.proc gameover
    ; G
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cb
    STA PPUADDR
    LDA #$0a
    STA PPUDATA

    ; A
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cc
    STA PPUADDR
    LDA #$04
    STA PPUDATA

    ; M
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$cd
    STA PPUADDR
    LDA #$10
    STA PPUDATA

    ; E
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$ce
    STA PPUADDR
    LDA #$08
    STA PPUDATA

    ; O
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d0
    STA PPUADDR
    LDA #$12
    STA PPUDATA

    ; V
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d1
    STA PPUADDR
    LDA #$19
    STA PPUDATA

    ; E
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d2
    STA PPUADDR
    LDA #$08
    STA PPUDATA

    ; R
    LDA PPUSTATUS
    LDA #$21
    STA PPUADDR
    LDA #$d3
    STA PPUADDR
    LDA #$15
    STA PPUDATA

    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL

gameover_loop:
    JMP gameover_loop
.endproc

.segment "RODATA"
palettes:
.byte $0f, $16, $10, $19  ; black, red, light grey, green
.byte $0f, $06, $16, $26  ; reds
.byte $0f, $09, $19, $29  ; greens
.byte $0f, $01, $21, $31  ; blues

.byte $0f, $00, $10, $30  ; greys
.byte $0f, $06, $16, $26  ; reds
.byte $0f, $09, $19, $29  ; greens
.byte $0f, $01, $21, $31  ; blues

.segment "ZEROPAGE"
apple_low: .res 1
apple_high: .res 1
snake_dir: .res 1
snake_length: .res 1
pad1: .res 1
sleeping: .res 1
timer: .res 1
seed: .res 2
.exportzp apple_low, apple_high, snake_dir, snake_length, pad1, seed

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"
