.include "constants.inc"
.include "header.inc"

.segment "CODE"
.proc irq_handler
    RTI
.endproc

.import read_controller1

.proc nmi_handler
    LDA #$00
    STA OAMADDR
    LDA #$02
    STA OAMDMA

    LDA #0
    STA sleeping

    LDA #$00
    STA $2005
    STA $2005
    RTI
.endproc

.proc draw_sprites
    ; save registers
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    ; write apple data
    LDA apple_y
    STA $0200
    LDA #$02  ; use sprite 2
    STA $0201
    LDA #$01  ; use palette 1
    STA $0202
    LDA apple_x
    STA $0203

    LDA #0
    STA snake_index
draw_snake_loop:
    JSR draw_snake_segment
    INC snake_index
    LDA snake_index
    CMP snake_length
    BNE draw_snake_loop

exit_subroutine:
    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
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

    JSR check_collision
    JSR update_snake_position

done_updating_state:
    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
    RTS
.endproc

.proc draw_snake_segment
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    ; write snake tile number and attributes
    LDA #$04  ; OAM memory offset
    LDX snake_index
    BEQ oam_address_found

find_address:
    CLC
    ADC #$04
    DEX
    BNE find_address

oam_address_found:
    TAY  ; use Y to hold OAM address offset
    LDX snake_index

    LDA snake_y, X
    STA $0200, Y
    LDA #$02
    STA $0201, Y
    LDA #$02
    STA $0202, Y
    LDA snake_x, X
    STA $0203, Y

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
    ; Y register stores source index
    ; X register stores destination index
    LDY snake_length
    DEY
    DEY
    LDX snake_length
    DEX
update_loop:
    LDA snake_x, Y
    STA snake_x, X
    LDA snake_y, Y
    STA snake_y, X
    DEX
    DEY
    BPL update_loop

    LDA #UP
    BIT snake_dir
    BEQ check_down
    LDA snake_y
    CMP #$09
    BCC done_updating_snake_position
    LDA snake_y
    SEC
    SBC #$08
    STA snake_y

check_down:
    LDA #DOWN
    BIT snake_dir
    BEQ check_left
    LDA snake_y
    CMP #$df
    BCS done_updating_snake_position
    LDA snake_y
    CLC
    ADC #$08
    STA snake_y

check_left:
    LDA #LEFT
    BIT snake_dir
    BEQ check_right
    LDA snake_x
    CMP #$09
    BCC done_updating_snake_position
    LDA snake_x
    SBC #$08
    STA snake_x

check_right:
    LDA #RIGHT
    BIT snake_dir
    BEQ done_updating_snake_position
    LDA snake_x
    CMP #$f0
    BCS done_updating_snake_position
    LDA snake_x
    CLC
    ADC #$08
    STA snake_x

done_updating_snake_position:
    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
    RTS
.endproc

.proc check_collision
    PHP
    PHA
    TXA
    PHA
    TYA
    PHA

    LDA snake_x
    CMP apple_x
    BNE done_checking_collision
    LDA snake_y
    CMP apple_y
    BNE done_checking_collision
    JSR spawn_apple
    LDA #MAX_SNAKE_SIZE
    CMP snake_length
    BEQ done_checking_collision
    INC snake_length

done_checking_collision:
    PLA
    TAY
    PLA
    TAX
    PLA
    PLP
    RTS
.endproc

.import random_x
.import random_y

.proc spawn_apple
    LDA SEED
    JSR random_x
    LSR
    LSR
    LSR
    ASL
    ASL
    ASL
    STA apple_x

    LDA SEED
    JSR random_y
    LSR
    LSR
    LSR
    ASL
    ASL
    ASL
    STA apple_y
    RTS
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
    JSR draw_sprites

    INC sleeping
sleep:
    LDA sleeping
    BNE sleep

    JMP mainloop
.endproc

.segment "RODATA"
palettes:
.byte $0f, $00, $10, $30  ; greys
.byte $0f, $06, $16, $26  ; reds
.byte $0f, $09, $19, $29  ; greens
.byte $0f, $01, $21, $31  ; blues

.byte $0f, $00, $10, $30  ; greys
.byte $0f, $06, $16, $26  ; reds
.byte $0f, $09, $19, $29  ; greens
.byte $0f, $01, $21, $31  ; blues

.segment "ZEROPAGE"
apple_x: .res 1
apple_y: .res 1
snake_x: .res MAX_SNAKE_SIZE
snake_y: .res MAX_SNAKE_SIZE
snake_dir: .res 1
snake_length: .res 1
snake_index: .res 1
pad1: .res 1
sleeping: .res 1
timer: .res 1
.exportzp apple_x, apple_y, snake_x, snake_y, snake_dir, snake_length, pad1

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"
