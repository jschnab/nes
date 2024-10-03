.include "constants.inc"
.include "header.inc"
.include "macros.s"

.import read_controller1

.segment "CODE"
.proc wait_frame
; wait for next NMI to finish
    inc nmi_ready
@loop:
    lda nmi_ready
    bne @loop
    rts
.endproc

.proc ppu_update
; wait until next NMI finishes and turn rendering on
    lda ppuctrl
    ora #%10000000
    sta ppuctrl
    sta PPUCTRL
    lda ppumask
    ora #%00011110
    sta ppumask
    sta PPUMASK
    jsr wait_frame
    rts
.endproc

.proc ppu_off
; wait until screen is rendered then turn rendering off
; now it's safe to write to PPU
    jsr wait_frame
    lda ppuctrl
    and #%01111111
    sta ppuctrl
    sta PPUCTRL
    lda ppumask
    and #%11100001
    sta ppumask
    sta PPUMASK
    rts
.endproc

.proc write_text
; writes zero-terminated string to screen
; assumes that text address is stored in paddr
; and that the PPU address was initialized
    ldy #0
@loop:
    lda (paddr), Y
    beq @end
    sta PPUDATA
    iny
    jmp @loop
@end:
    rts
.endproc

.proc irq_handler
    rti
.endproc


.proc nmi_handler
    php
    pha
    txa
    pha
    tya
    pha

    ; transfer OAM using DMA
    lda #$00
    sta OAMADDR
    lda #$02
    sta OAMDMA

    ; write palette
    vram_set_address $3F00
    ldx #0
@loop:
    lda palettes, x
    sta PPUDATA
    inx
    cpx #32
    bcc @loop

    ; write scroll and PPU control settings
    lda #0
    sta PPUSCROLL
    sta PPUSCROLL
    lda ppuctrl
    sta PPUCTRL
    lda ppumask
    sta PPUMASK

    lda #GAME_SCREEN
    bit active_screen
    beq @skip_draw_snake_apple
    jsr draw_apple
    jsr draw_snake

@skip_draw_snake_apple:
    lda #1
    bit update_score
    beq @skip_update_score
    jsr display_score
    ; reset update_score flag
    lda #%11111110
    and update_score
    sta update_score

@skip_update_score:
    lda #0
    sta sleeping

    ; flag PPU update as completed
    ldx #0
    stx nmi_ready

    pla
    tay
    pla
    tax
    pla
    plp
    rti
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

    vram_set_address (NAME_TABLE_ADDR + $27)
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
    lda PPUSTATUS
    lda apple_high
    sta PPUADDR
    lda apple_low
    sta PPUADDR
    lda #APPLE_TILE
    sta PPUDATA

    lda #$00
    sta PPUSCROLL
    sta PPUSCROLL

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

.proc draw_welcome_screen
; wait for player to press start button
    jsr ppu_off

    ; clear screen tiles
    vram_set_address $2000
    lda #$01  ; tile
    ldx #30  ; rows
@loop_clear_tiles_rows:
    ldy #32  ; columns
@loop_clear_tiles_cols:
    sta PPUDATA
    dey
    bne @loop_clear_tiles_cols
    dex
    bne @loop_clear_tiles_rows

    ; clear screen attributes
    vram_set_address $23C0
    lda #%01010101  ; palettes
    ldx #0
@loop_clear_attr:
    sta PPUDATA
    inx
    cpx #64
    bne @loop_clear_attr

    ; print title
    vram_set_address $20EB
    assign_16i paddr, title_txt
    jsr write_text

    ; print 'press start'
    vram_set_address $22EA
    assign_16i paddr, press_start_txt
    jsr write_text

    jsr ppu_update
    rts
.endproc

.proc draw_game_screen
    jsr ppu_off

    ; draw header background tiles
    vram_set_address $2000
    lda #$01 ; tile
    ldx #0
@loop_header_tiles:
    sta PPUDATA
    inx
    cpx #$40
    bne @loop_header_tiles

    ; draw 'score' word + initial score
    vram_set_address $2021
    assign_16i paddr, score_txt
    jsr write_text

    ; set header attribute table
    vram_set_address $23C0
    lda #%00000101
    ldx #0
@loop_header_attr:
    sta PPUDATA
    inx
    cpx #8
    bne @loop_header_attr

    ; draw grass tiles
    vram_set_address $2040
    lda #0  ; tile
    ldx #28  ; rows
@loop_grass_tiles_rows:
    ldy #32  ; columns
@loop_grass_tiles_cols:
    sta PPUDATA
    dey
    bne @loop_grass_tiles_cols
    dex
    bne @loop_grass_tiles_rows

    ; draw grass attribute table
    vram_set_address $23C8
    lda #0  ; palette
    ldx #0
@loop_grass_attr:
    sta PPUDATA
    inx
    cpx #56  ; number of attribute addresses in screen minus in header
    bne @loop_grass_attr

    jsr ppu_update
    rts
.endproc

.import random_low
.import random_high
.import reset_handler

.export main
.proc main
    lda #%10001000 ; turn on NMIs, sprites use first pattern table
    sta ppuctrl
    sta PPUCTRL
    lda #%00011110 ; turn on screen
    sta ppumask
    sta PPUMASK

    lda #WELCOME_SCREEN
    sta active_screen
    jsr draw_welcome_screen
@welcomeloop:
    jsr read_controller1
    lda #BTN_STA
    bit pad1
    beq @welcomeloop

    lda #GAME_SCREEN
    sta active_screen
    jsr draw_game_screen

    lda #0
    sta collision
    jsr spawn_apple

@gameloop:
    jsr read_controller1
    jsr update_direction
    jsr update_game_state

    inc sleeping
@sleep:
    lda sleeping
    bne @sleep

    jmp @gameloop
.endproc

.proc gameover
    JSR ppu_off

    ; we are changing the palette for just the part of the screen where
    ; 'gameover' is written, so reset tiles in this area to avoid game screen
    ; looking weird
    ldx #$01 ; tile number
    vram_set_address $2188
    ldy #0
@loop_tiles1:
    stx PPUDATA
    iny
    cpy #$10
    bne @loop_tiles1
    vram_set_address $21A8
    ldy #0
@loop_tiles2:
    stx PPUDATA
    iny
    cpy #$10
    bne @loop_tiles2
    vram_set_address $21C8
    ldy #0
@loop_tiles3:
    stx PPUDATA
    iny
    cpy #$10
    bne @loop_tiles3
    vram_set_address $21E8
    ldy #0
@loop_tiles4:
    stx PPUDATA
    iny
    cpy #$10
    bne @loop_tiles4

    ; write gameover text
    vram_set_address $21CB
    assign_16i paddr, gameover_txt
    jsr write_text

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

    jsr ppu_update

gameover_loop:
    jmp gameover_loop
.endproc

.segment "RODATA"
palettes:
.byte $2A, $19, $06, $16  ; light green, dark green, brown, red
.byte $2A, $0f, $10, $20  ; greys
.byte $2A, $09, $19, $29  ; greens
.byte $2A, $01, $21, $31  ; blues

.byte $2A, $00, $10, $30  ; greys
.byte $2A, $06, $16, $26  ; reds
.byte $2A, $09, $19, $29  ; greens
.byte $2A, $01, $21, $31  ; blues

gameover_txt:
.byte $46, $40, $4C, $44, $01, $01, $4E, $55, $44, $51, 0

score_txt:
.byte $52, $42, $4E, $51, $44, $01, $60, $60, $60, $60, $60, $60, $60, 0

title_txt:
.byte $42, $01, $4E, $01, $41, $01, $51, $01, $40, 0

press_start_txt:
.byte $4F, $51, $44, $52, $52, $01, $01, $52, $53, $40, $51, $53, 0

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
ppuctrl: .res 1
ppumask: .res 1
nmi_ready: .res 1
paddr: .res 2
active_screen: .res 1
.exportzp apple_low, apple_high, snake_dir, snake_length, pad1, seed, score, update_score

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"
