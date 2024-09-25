PPU_CONTROL        = $2000
PPU_MASK           = $2001
PPU_STATUS         = $2002
PPU_SPRRAM_ADDRESS = $2003
PPU_SPRAM_IO       = $2004
PPU_VRAM_ADDRESS1  = $2005
PPU_VRAM_ADDRESS2  = $2006
PPU_VRAM_IO        = $2007
SPRITE_DMA         = $4014

APU_DM_CONTROL = $4010
APU_CLOCK      = $4015

JOYPAD1 = $4016
JOYPAD2 = $4017

PAD_A      = $01
PAD_B      = $02
PAD_SELECT = $04
PAD_START  = $08
PAD_U      = $10
PAD_D      = $20
PAD_L      = $40
PAD_R      = $80

.segment "HEADER"
INES_MAPPER = 0
INES_MIRROR = 0
INES_SRAM   = 0

.byte 'N', 'E', 'S', $1A
.byte $02
.byte $01
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0

.segment "VECTORS"
.word nmi
.word reset
.word irq

.segment "ZEROPAGE"
nmi_ready: .res 1
gamepad: .res 1
d_x: .res 1
d_y: .res 1

.segment "OAM"
oam: .res 256

.segment "RODATA"
default_palette:
.byte $0F, $15, $26, $37
.byte $0F, $09, $19, $29
.byte $0F, $01, $11, $21
.byte $0F, $00, $10, $30
.byte $0F, $18, $28, $38
.byte $0F, $14, $24, $34
.byte $0F, $1B, $2B, $3B
.byte $0F, $12, $22, $32

welcome_txt:
.byte 'W','E','L','C','O','M','E',0

.segment "TILES"
.incbin "example.chr"

.segment "BSS"
palette: .res 32

.segment "CODE"
irq:
    rti

.segment "CODE"
.proc reset
    sei                ; disable interrupts
    lda #0
    sta PPU_CONTROL    ; disable NMI
    sta PPU_MASK       ; disable rendering
    sta APU_DM_CONTROL ; disable DMC IRQ
    lda #$40           ; disable APU frame IRQ
    sta JOYPAD2

    cld
    ldx #$FF
    txs ; initializes stack pointer

    bit PPU_STATUS
wait_vblank:
    bit PPU_STATUS
    bpl wait_vblank

    lda #0
    ldx #0
clear_ram:
    sta $0000,x
    sta $0100,x
    sta $0200,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne clear_ram

    ; place all sprites offscreen at Y = 255
    lda #255
    ldx #0
clear_oam:
    sta oam,x
    inx
    inx
    inx
    inx
    bne clear_oam

wait_vblank2:
    bit PPU_STATUS
    bpl wait_vblank2

    ; sprites use the second pattern table
    ; start generating NMI
    lda #%10001000
    sta PPU_CONTROL

    jmp main
.endproc

.segment "CODE"
.proc nmi
    pha
    txa
    pha
    tya
    pha

    ; 0: skip writing to PPU memory
    ; 1: perform normal NMI routine
    ; 2: turn off rendering and reset nmi_ready to 0
    lda nmi_ready
    bne :+
    jmp ppu_update_end
:
    ; turn rendering off if nmi_ready == 2
    cmp #2
    bne cont_render
    lda #0
    sta PPU_MASK
    ldx #0
    stx nmi_ready
    jmp ppu_update_end
cont_render:
    ldx #0
    stx PPU_SPRRAM_ADDRESS
    lda #>oam
    sta SPRITE_DMA

    ; transfer the current palette to PPU
    lda #%10001000
    sta PPU_CONTROL
    lda PPU_STATUS
    lda #$3F
    sta PPU_VRAM_ADDRESS2
    stx PPU_VRAM_ADDRESS2
    ldx #0
loop:
    lda palette, x
    sta PPU_VRAM_IO
    inx
    cpx #32
    bcc loop

    ; enable rendering
    lda #%00011110
    sta PPU_MASK

    ; flag PPU update as complete
    ldx #0
    stx nmi_ready

ppu_update_end:
    pla
    tay
    pla
    tax
    pla
    rti
.endproc

.segment "CODE"
.proc ppu_update
    ; wait until the next NMI and turn rendering on (if not already)
    lda #1
    sta nmi_ready
loop:
    lda nmi_ready
    bne loop
    rts
.endproc

.segment "CODE"
.proc ppu_off
    ; wait until the next NMI and turn rendering off
    ; now safe to write PPU directly via PPU_VRAM_IO
    lda #2
    sta nmi_ready
loop:
    lda nmi_ready
    bne loop
    rts
.endproc

.segment "CODE"
.proc clear_nametable
    lda PPU_STATUS
    lda #$20
    sta PPU_VRAM_ADDRESS2
    lda #$00
    sta PPU_VRAM_ADDRESS2

    lda #0
    ldy #30 ; clear 30 rows
rowloop:
    ldx #32 ; 32 columns
columnloop:
    sta PPU_VRAM_IO
    dex
    bne columnloop
    dey
    bne rowloop

    ; empty attribute table
    ldx #64 ; bytes
loop:
    sta PPU_VRAM_IO
    dex
    bne loop
    rts
.endproc

.segment "CODE"
.proc gamepad_poll
    lda #1
    sta JOYPAD1
    lda #0
    sta JOYPAD1

    ldx #8
loop:
    pha
    lda JOYPAD1

    and #%00000011
    cmp #%00000001
    pla

    ror
    dex
    bne loop
    sta gamepad
    rts
.endproc

.segment "CODE"
.proc main
    ldx #0
paletteloop:
    lda default_palette, x
    sta palette, x
    inx
    cpx #32
    bcc paletteloop
    jsr clear_nametable
    lda PPU_STATUS
    lda #$20
    sta PPU_VRAM_ADDRESS2
    lda #$8A
    sta PPU_VRAM_ADDRESS2

    ldx #0
textloop:
    lda welcome_txt, x
    sta PPU_VRAM_IO
    inx
    cmp #0
    beq :+
    jmp textloop
    :

    ; bat sprite
    lda #180
    sta oam
    lda #120
    sta oam + 3
    lda #1
    sta oam + 1
    lda #0
    sta oam + 2

    ; ball sprite
    lda #124
    sta oam + (1 * 4)
    sta oam + (1 * 4) + 3
    lda #2
    sta oam + (1 * 4) + 1
    lda #0
    sta oam + (1 * 4) + 2

    ; ball velocity
    lda #1
    sta d_x
    sta d_y

    jsr ppu_update

mainloop:
    lda nmi_ready
    cmp #0
    bne mainloop

    jsr gamepad_poll
    lda gamepad
    and #PAD_L
    beq NOT_GAMEPAD_LEFT
    lda oam + 3
    cmp #0
    beq NOT_GAMEPAD_LEFT
    sec
    sbc #1
    sta oam + 3
NOT_GAMEPAD_LEFT:
    lda gamepad
    and #PAD_R
    beq NOT_GAMEPAD_RIGHT
    lda oam + 3
    cmp #248
    beq NOT_GAMEPAD_RIGHT
    clc
    adc #1
    sta oam + 3
NOT_GAMEPAD_RIGHT:
    lda oam + (1 * 4) + 0
    clc
    adc d_y
    sta oam + (1 * 4) + 0
    cmp #0
    bne NOT_HITTOP
    lda #1
    sta d_y
NOT_HITTOP:
    lda oam + (1 * 4) + 0
    cmp #210
    bne NOT_HITBOTTOM
    lda #$FF
    sta d_y
NOT_HITBOTTOM:
    lda oam + (1 * 4) + 3
    clc
    adc d_x
    sta oam + (1 * 4) + 3
    cmp #0
    bne NOT_HITLEFT
    lda #1
    sta d_x
NOT_HITLEFT:
    lda oam + (1 * 4) + 3
    cmp #248
    bne NOT_HITRIGHT
    lda #$FF
    sta d_x
NOT_HITRIGHT:
    lda #1
    sta nmi_ready
    jmp mainloop
.endproc
