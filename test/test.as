#ines.mapper        "none"
#ines.mirroring     "Horizontal"
#ines.battery       "no"
#ines.trainer       "no"
#ines.fourscreen    "no"

#rom.banksize 16K

#include "nes.h"
#include "std.h"

#ram.org 0x0
shared byte _ppu_ctl0, _ppu_ctl1

byte tile_buf_1[8]
byte tile_buf_0[8]
#ram.end

#rom.bank BANK_MAIN_ENTRY
#rom.org 0xC000

#interrupt.start    main
#interrupt.irq      int_irq
#interrupt.nmi      int_nmi

interrupt.irq int_irq()
{
}

interrupt.nmi int_nmi()
{
    ppu_ctl0_clear(CR_BACKADDR1000)

    // initial delay (51 cycles) to get sync'd with hsyncs
    ldx #10                 // 2    
    do {
        dex                 // 2 * 10
    } while (not zero)      // 3 * 9 + 2

    // 341/3 cycles per line + change (8 cycles)
    lda #0x20               // 2
    ldy #20+(8*10)          // 2
waitloop:
        ldx #20             // 2 * lines
        do {
            dex             // 2 * 20 * lines
        } while (not zero)  // (3 * 19 + 2) * lines
        nop                 // 2 * lines
        asl A               // 2 * lines
        bcs extra           // (1/3 * 3 + 2/3 * 2) * lines
        dey                 // 2 * lines
        bne waitloop        // 3 * (lines-1) + 2
extra:
        bcc done            // 1/3 * 2 * lines + 2/3 * 3
        lda #0x20           // 1/3 * 2 * lines
        dey                 // (counted above)
        bne waitloop        // (counted above)
done:

    ppu_ctl0_set(CR_BACKADDR1000)

}

inline system_initialize_custom()
{
    disable_interrupts()
    disable_decimal_mode()
    reset_stack()

    // clear the registers
    lda  #0

    sta  PPU.CNT0
    sta  PPU.CNT1

    sta  PPU.BG_SCROLL
    sta  PPU.BG_SCROLL

    sta  PCM_CNT
    sta  PCM_VOLUMECNT
    sta  SND_CNT

    lda  #0xC0
    sta  joystick.cnt1
}

interrupt.start noreturn main()
{
    system_initialize_custom()

    ppu_ctl0_assign(#0)
    ppu_ctl1_assign(#0)

    vblank_wait_full()
    vblank_wait()

    // Setup palette
    vram_set_address_i(PAL_0_ADDRESS)

    ldx #4-1
    do {
        lda pal, X
        sta PPU.IO
        dex
    } while (not minus)

    // Setup pattern table 0
    vram_set_address_i(PATTERN_TABLE_0_ADDRESS)

    // pattern 0
    init_tile_blue(Tile_ElementHe)
    write_tile_buf()

    // pattern 1
    overlay_tile_red(Tile_ArrowUp)
    write_tile_buf()

    // pattern 2
    overlay_tile_white(Tile_ArrowDown)
    write_tile_buf()

    vram_set_address_i(PATTERN_TABLE_0_ADDRESS+(96*16))

    // pattern 96
    write_tile_white(Tile_CmdAlpha)

    vram_set_address_i(PATTERN_TABLE_0_ADDRESS+((96+(2*20)+2)*16))
    write_tile_red_bg(Tile_CmdAlpha)

    // Setup pattern table 1
    vram_set_address_i(PATTERN_TABLE_1_ADDRESS)

    // pattern 0
    init_tile_red(Tile_ElementHe)
    write_tile_buf()

    // pattern 1
    init_tile_blue(Tile_ElementHe)
    write_tile_buf()

    // pattern 2
    init_tile_white(Tile_ElementHe)
    write_tile_buf()

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS+(96*16))

    // pattern 96
    write_tile_white(Tile_CmdBeta)

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS+((96+(1*20)+2)*16))
    init_tile_blue(Tile_VLine)
    add_tile_blue(tile_FringeBot)
    write_tile_buf()

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS+((96+(2*20)+1)*16))
    init_tile_blue(Tile_HLine)
    add_tile_blue(tile_FringeRight)
    write_tile_buf()

    write_tile_blue_bg(Tile_CmdAlpha)

    init_tile_blue(Tile_HLine)
    add_tile_blue(tile_FringeLeft)
    write_tile_buf()

    init_tile_blue(Tile_LineBotLeft)
    write_tile_buf()

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS+((96+(3*20)+2)*16))
    init_tile_blue(Tile_VLine)
    add_tile_blue(tile_FringeTop)
    add_tile_blue(tile_HLine)
    write_tile_buf()

    write_tile_red_bg(Tile_CmdStart)

    init_tile_blue(Tile_VLine)
    write_tile_buf()

    // Setup name table 0

    // background
    vram_set_address_i(NAME_TABLE_0_ADDRESS)
    ldy #NAMETABLE_HEIGHT
    lda #0
    do {
        ldx #NAMETABLE_WIDTH
        do {
            sta PPU.IO
            dex
        } while (not zero)
        dey
    } while (not zero)

    // attribute table
    vram_set_address_i(ATTRIBUTE_TABLE_0_ADDRESS)

    ldy #ATTRIBUTE_TABLE_SIZE
    lda #0
    do {
        sta PPU.IO
        dey
    } while (not zero)

    // unique tiles

    // starting from (6,2), 20x16
    vram_set_address_i(NAME_TABLE_0_ADDRESS+6+(2*NAMETABLE_WIDTH))

    // (6,2)-(25,9) 20x8, are numbered 96-255
    // (6,10)-(25,17) 20x8, are numbered 96-255

    ldx #2

    do {
        txa
        pha

        ldy #96
        lda #0
        do {
            dey
            ldx #20
            do {
                iny
                sty PPU.IO
                dex
            } while (not zero)

            // skip to next row
            ldx #NAMETABLE_WIDTH-20
            do {
                sta PPU.IO
                dex
            } while (not zero)
            iny
        } while (not zero)

        pla
        tax
        dex
    } while (not zero)

    vram_clear_address()

    ppu_ctl0_assign(#CR_NMI)
    ppu_ctl1_assign(#CR_BACKVISIBLE|CR_SPRITESVISIBLE|CR_BACKNOCLIP)

    enable_interrupts()

    forever {}
}

byte pal[4] = {0x20, // 11: white
               0x12, // 10: blue
               0x16, // 01: red
               0x10} // 00: gray (bg)
#include "tiles.as"
