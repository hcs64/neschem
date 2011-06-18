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
    ldy #18+(8*8)          // 2
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

interrupt.start main()
{
    vblank_wait_full()
    vblank_wait()

    vram_set_address_i(PAL_ADDRESS)

    ldx #4-1
    do {
        lda pal, X
        sta PPU.IO
        dex
    } while (not minus)

    vram_set_address_i(PATTERN_TABLE_0_ADDRESS)

    // low bits
    ldx #8-1
    do {
        lda Helium, X
        sta PPU.IO
        dex
    } while (not minus)

    // high bits
    ldx #8-1
    lda #0
    do {
        sta PPU.IO
        dex
    } while (not minus)

    // low bits
    ldx #8-1
    lda #0
    do {
        sta PPU.IO
        dex
    } while (not minus)

    // high bits
    ldx #8-1
    do {
        lda Helium, X
        sta PPU.IO
        dex
    } while (not minus)

    // low bits
    ldx #8-1
    do {
        lda Helium, X
        sta PPU.IO
        dex
    } while (not minus)

    // high bits
    ldx #8-1
    do {
        lda Helium, X
        sta PPU.IO
        dex
    } while (not minus)

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS)
    ldy #3
    do {
    // low bits
    ldx #8-1
    do {
        lda Helium, X
        eor #0xFF
        sta PPU.IO
        dex
    } while (not minus)

    // high bits
    ldx #8-1
    do {
        lda Helium, X
        eor #0xFF
        sta PPU.IO
        dex
    } while (not minus)
    dey
    } while (not minus)


    vram_set_address_i(NAME_TABLE_0_ADDRESS)

    ldy #NAMETABLE_HEIGHT/2
    lda #1
    do {
        ldx #NAMETABLE_WIDTH
        do {
            sta PPU.IO
            dex
        } while (not zero)
        dey
    } while (not zero)

    ldy #NAMETABLE_HEIGHT/2
    lda #2
    do {
        ldx #NAMETABLE_WIDTH
        do {
            sta PPU.IO
            dex
        } while (not zero)
        dey
    } while (not zero)

    ppu_ctl0_assign(#CR_NMI)
    ppu_ctl1_assign(#CR_BACKVISIBLE|CR_SPRITESVISIBLE|CR_BACKNOCLIP)

    enable_interrupts()

    do {
    } while (true)
}

// backwards!
byte pal[] = {0x12, 0x15, 0x20, 0x10}
Helium:
#incbin "element_He.bin"
