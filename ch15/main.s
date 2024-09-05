.include "constants.inc"
.include "header.inc"

.import reset_handler
.import draw_starfield
.import draw_objects

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
scroll: .res 1
ppuctrl_settings: .res 1
.exportzp player_x, player_y

.segment "CODE"
.proc irq_handler
    RTI
.endproc

.proc nmi_handler
    LDA #$00
    STA OAMADDR
    LDA #$02
    STA OAMDMA

    ; update tiles *after* DMA transfer
    JSR update_player
    JSR draw_player

    LDA scroll
    CMP #$00  ; did we scroll to the end of a nametable?
    BNE set_scroll_positions
    ; if yet, update base nametable
    LDA ppuctrl_settings
    EOR #%00000010  ; flip bit #1 to its opposite
    STA ppuctrl_settings
    STA PPUCTRL
    LDA #240
    STA scroll

set_scroll_positions:
    LDA #$00    ; X scroll first
    STA PPUSCROLL
    DEC scroll
    LDA scroll  ; then Y scroll
    STA PPUSCROLL

    ;LDA #$00
    ;STA $2005
    ;STA $2005
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

    LDA player_x
    CMP #$e0
    BCC not_at_right_edge
    ; if BCC is not taken, player_x is greater than $e0
    LDA #$00
    STA player_dir    ; start moving left
    JMP direction_set ; we already chose a direction, skip left side check

not_at_top_edge:
    LDA player_y
    CMP #$e0
    BCC direction_set
not_at_right_edge:
    LDA player_x
    CMP #$10
    BCS direction_set
    ; if BCS is not taken, player_x is less than #$10
    LDA #$01
    STA player_dir ; start moving right

direction_set:
    ; now, update player_x
    LDA player_dir
    CMP #$01
    BEQ move_right
    ; if player_dir minus #$01 is not zero, that means player_dir was $00
    ; and we need to move left
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

vblankwait: ; wait for another vblank before continuing
    BIT PPUSTATUS
    BPL vblankwait
    LDA #%10010000 ; turn on NMIs, sprites use first pattern table
    STA ppuctrl_settings
    STA PPUCTRL
    LDA #%00011110 ; turn on screen
    STA PPUMASK
forever:
    JMP forever
.endproc

.segment "RODATA"
palettes:
.byte $0f, $12, $23, $27
.byte $0f, $2b, $3c, $39
.byte $0f, $0c, $07, $13
.byte $0f, $19, $09, $29

.byte $0f, $21, $10, $15
.byte $0f, $19, $09, $29
.byte $0f, $19, $09, $29
.byte $0f, $19, $09, $29

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"
