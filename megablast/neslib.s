PPU_CONTROL        = $2000
PPU_MASK           = $2001
PPU_STATUS         = $2002
PPU_SPRRAM_ADDRESS = $2003
PPU_SPRRAM_IO      = $2004
PPU_VRAM_ADDRESS1  = $2005
PPU_VRAM_ADDRESS2  = $2006
PPU_VRAM_IO        = $2007
SPRITE_DMA         = $4014

; nametable location
NT_2000 = $00
NT_2400 = $01
NT_2800 = $02
NT_2C00 = $03

; increment VRAM pointer by row
VRAM_DOWN = $04

OBJ_0000 = $00
OBJ_1000 = $08
OBJ_8X16 = $20

BG_0000 = $00
BG_1000 = $10

; enables NMI
VBLANK_NMI = $80

BG_OFF   = $00
BG_CLIP  = $08
BG_ON    = $0A
OBJ_OFF  = $00
OBJ_CLIP = $10
OBJ_ON   = $14

APU_DM_CONTROL = $4010  ; delta modulation control (write)
APU_CLOCK      = $4015  ; sound/vertical clock signal (read/write)

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

; PPU_MEMORY_ADDRESSES
NAME_TABLE_0_ADDRESS      = $2000
NAME_TABLE_1_ADDRESS      = $2400
ATTRIBUTE_TABLE_0_ADDRESS = $23C0
ATTRIBUTE_TABLE_1_ADDRESS = $27C0

.segment "ZEROPAGE"
nmi_ready: .res 1
ppu_ctl0: .res 1  ; PPU control register 1 value
ppu_ctl1: .res 1  ; PPU control register 2 value
gamepad: .res 1
text_address: .res 2

.include "macros.s"

.segment "CODE"
.proc wait_frame
; set the nmi_update flag and wait for it to be reset at the end or NMI routine
    inc nmi_ready
@loop:
    lda nmi_ready
    bne @loop
    rts
.endproc

.proc ppu_update
; wait until the next NMI and turns rendering on if not already on
; which will upload OAM sprite data, palette settings, and any name table
; updates to the PPU
    lda ppu_ctl0
    ora #VBLANK_NMI
    sta ppu_ctl0
    sta PPU_CONTROL
    lda ppu_ctl1
    ora #OBJ_ON|BG_ON
    sta ppu_ctl1
    sta PPU_MASK  ; not in book but seems necessary
    jsr wait_frame
    rts
.endproc

.proc ppu_off
; wait for the screen to be rendered and then turn rendering off so that it is
; now safe to write to the PPU directly without causing corruption
    jsr wait_frame
    lda ppu_ctl0
    and #%01111111
    sta ppu_ctl0
    sta PPU_CONTROL
    lda ppu_ctl1
    and #%11100001
    sta ppu_ctl1
    sta PPU_MASK
    rts
.endproc

.proc clear_nametable
    lda PPU_STATUS
    lda #$20
    sta PPU_VRAM_ADDRESS2
    lda #$00
    sta PPU_VRAM_ADDRESS2

    lda #0
    ldy #30  ; 30 rows
rowloop:
    ldx #32  ; 32 columns
columnloop:
    sta PPU_VRAM_IO
    dex
    bne columnloop
    dey
    bne rowloop

    ; empty the attribute table
    ldx #64  ; bytes
loop:
    sta PPU_VRAM_IO
    dex
    bne loop
    rts
.endproc

.proc gamepad_poll
    lda #1
    sta JOYPAD1
    lda #0
    sta JOYPAD1
    ldx #8  ; read 8 bits from the interface
loop:
    pha
    lda JOYPAD1  ; combine low 2 bits and store them in the carry bit
    and #%00000011
    cmp #%00000001
    pla  ; rotate the carry into the gamepad variable
    ror
    dex
    bne loop
    sta gamepad
    rts
.endproc

.proc write_text
    ldy #0
loop:
    lda (text_address),y
    beq exit
    sta PPU_VRAM_IO
    iny
    jmp loop
exit:
    rts
.endproc
