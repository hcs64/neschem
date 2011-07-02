PPU_C0      = $2000
PPU_C1      = $2001
PPU_STATUS  = $2002
PPU_SCROLL  = $2005
PPU_ADDRESS = $2006
PPU_IO      = $2007
PPU_SPR_DMA = $4014

PPU_C0_NMI          = %10000000
PPU_C0_PPUSLAVE     = %01000000
PPU_C0_SPRITE8x16   = %00100000
PPU_C0_BACKADDR1000 = %00010000
PPU_C0_SPRADDR1000  = %00001000
PPU_C0_ADDRINC32    = %00000100
PPU_C0_NAMETABLEBITS= %00000011

PPU_C1_PALETTEINTENSITY = %11100000
PPU_C1_SPRITESVISIBLE   = %00010000
PPU_C1_BACKVISIBLE      = %00001000
PPU_C1_SPRNOCLIP        = %00000100
PPU_C1_BACKNOCLIP       = %00000010
PPU_C1_MONOCHROME       = %00000001

PPU_ST_VBLANK           = %10000000
PPU_ST_SPRITE0          = %01000000
PPU_ST_SCANSPROVERFLOW  = %00100000
PPU_ST_VRAM_NOWRITE     = %00010000

PATTERN_TABLE_0_ADDRESS = $0000
PATTERN_TABLE_1_ADDRESS = $1000

PAL_0_ADDRESS   = $3F00
PAL_1_ADDRESS   = $3F10

NAME_TABLE_0_ADDRESS = $2000
NAME_TABLE_1_ADDRESS = $2400
NAME_TABLE_2_ADDRESS = $2800
NAME_TABLE_3_ADDRESS = $2C00

NAME_TABLE_WIDTH    = 32
NAME_TABLE_HEIGHT   = 30

.globalzp _ppu_ctl0, _ppu_ctl1
.global oam_buf

.macro ppu_clean_latch
    lda PPU_STATUS
.endmacro

.macro ppu_ctl0_clear mask
    lda _ppu_ctl0
    and #~(mask)
    sta PPU_C0
    sta _ppu_ctl0
.endmacro

.macro ppu_ctl0_set mask
    lda _ppu_ctl0
    ora #(mask)
    sta PPU_C0
    sta _ppu_ctl0
.endmacro

.macro ppu_ctl0_assign val
    lda #val
    sta PPU_C0
    sta _ppu_ctl0
.endmacro

.macro ppu_ctl1_clear mask
    lda _ppu_ctl1
    and #~(mask)
    sta PPU_C1
    sta _ppu_ctl1
.endmacro

.macro ppu_ctl1_set mask
    lda _ppu_ctl1
    ora #(mask)
    sta PPU_C1
    sta _ppu_ctl1
.endmacro

.macro ppu_ctl1_assign val
    lda #val
    sta PPU_C1
    sta _ppu_ctl1
.endmacro

.macro vram_clear_address
    lda #0
    sta PPU_ADDRESS
    sta PPU_ADDRESS
.endmacro

.macro vram_set_address address
    ppu_clean_latch
    lda address+1
    sta PPU_ADDRESS
    lda address+0
    sta PPU_ADDRESS
.endmacro

.macro vram_set_address_i address
    ppu_clean_latch
    lda #>(address)
    sta PPU_ADDRESS
    lda #<(address)
    sta PPU_ADDRESS
.endmacro

.macro vblank_wait
.scope
loop:
    lda PPU_STATUS
    bpl loop
.endscope
.endmacro
