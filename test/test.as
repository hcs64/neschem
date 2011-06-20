#ines.mapper        "none"
#ines.mirroring     "Horizontal"
#ines.battery       "no"
#ines.trainer       "no"
#ines.fourscreen    "no"

#rom.banksize 16K

#include "nes.h"
#include "std.h"

#ram.org 0x0, 0x20
pointer tmp_addr
shared byte _ppu_ctl0, _ppu_ctl1

byte tile_buf_1[8]
byte tile_buf_0[8]
#ram.end

// shared pattern staging area
#ram.org 0x20, 144
typedef struct tile_stage_s {
    word vaddr
    byte tile_buf_1[8]
    byte tile_buf_0[8]
}
tile_stage_s tile_stage[8]

#ram.end

#ram.org 0x300, 1024 // HACK: just made up a large numebr for now
byte red_start_x
byte red_start_y
byte red_start_dir

byte blue_start_x
byte blue_start_y
byte blue_start_dir

byte resume_render_color
byte resume_render_x
byte resume_render_y
byte resume_render_dir

// what display elements are displayed in each cell
// columns first to compute easier
byte playfield_blue_flags1[8*10]
byte playfield_red_flags1[8*10]

enum pf_flag1 {
    // comefrom
    cf_left = 1,
    cf_right= 2,
    cf_top  = 4,
    cf_bot  = 8,
    // arrow
    ar_left = 0x10,
    ar_right= 0x20,
    ar_up   = 0x40,
    ar_down = 0x80,
}

byte playfield_blue_flags2[8*10]
byte playfield_red_flags2[8*10]

enum pf_flag2 {
    // adjacent command
    cmd_left    = 1,
    cmd_right   = 2,
    cmd_top     = 4,
    cmd_bot     = 8,
    // control redirect
    redir_up    = 0x10,
    redir_down  = 0x20,
    redir_left  = 0x40,
    redir_right = 0x80,
}

// command in each cell
byte playfield_blue_cmd[8*10]
byte playfield_red_cmd[8*10]

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
    disable_decimal_mode()
    disable_interrupts()
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

    vblank_wait_full()
    vblank_wait()

    clear_vram()

    init_ingame_vram()

    init_playfield()

    vblank_wait()

    vram_clear_address()

    ppu_ctl0_assign(#CR_NMI)
    ppu_ctl1_assign(#CR_BACKVISIBLE|CR_SPRITESVISIBLE|CR_BACKNOCLIP)

    enable_interrupts()

    forever
    {
    }
}

/******************************************************************************/

function init_playfield()
{
    ldx #sizeof(playfield_blue_flags1)
    lda #0
    do {
        dex
        sta playfield_blue_flags1, X
        sta playfield_red_flags1, X
        sta playfield_blue_flags2, X
        sta playfield_red_flags2, X
        sta playfield_blue_cmd, X
        sta playfield_red_cmd, X
    } while (not zero)

    lda #4
    sta red_start_x
    sta blue_start_x
    sta red_start_y
    lda #6
    sta blue_start_y

    lda #pf_flag2.redir_left
    sta red_start_dir
    sta blue_start_dir
}

/******************************************************************************/

function render_paths()
{
    reset_paths()
}

function reset_paths()
{
    ldx #sizeof(playfield_blue_flags1)
    do {
        lda playfield_blue_flags1-1, X
        and #~(pf_flag1.cf_left | pf_flag1.cf_right | pf_flag1.cf_top | pf_flag1.cf_bot)
        sta playfield_blue_flags1-1, X
        lda playfield_red_flags1-1, X
        and #~(pf_flag1.cf_left | pf_flag1.cf_right | pf_flag1.cf_top | pf_flag1.cf_bot)
        sta playfield_red_flags1-1, X
        dex
    } while (not zero)
}

/******************************************************************************/

function clear_vram()
{
    vram_clear_address()

    lda #0
    ldy #0x30
    do {
        ldx #0x80
        do {
            sta PPU.IO
            sta PPU.IO
            dex
        } while (not zero)
        dey
    } while (not zero)
}


/******************************************************************************/

function init_ingame_vram()
{
    init_ingame_palette()
    init_ingame_fixed_patterns()
    init_ingame_unique_names()
}

function init_ingame_palette()
{
    // Setup palette
    vram_set_address_i(PAL_0_ADDRESS)

    ldx #4-1
    do {
        lda pal, X
        sta PPU.IO
        dex
    } while (not minus)
}

function init_ingame_fixed_patterns()
{
    // will probably want to break this out once we do have
    // bg tiles shared common between pat tbls

    // Setup pattern table 0

    vram_set_address_i(PATTERN_TABLE_0_ADDRESS)
    // 0: empty bg tile
    init_tile_blue(Tile_ArrowDown)
    overlay_tile_red(Tile_ArrowUp)
    write_tile_buf()

    vram_set_address_i(PATTERN_TABLE_0_ADDRESS+(16*96))
    init_tile_red(Tile_ArrowLeft)
    write_tile_buf()

    // Setup pattern table 1

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS)
    // 0: empty bg tile
    init_tile_blue(Tile_ArrowUp)
    overlay_tile_red(Tile_ArrowDown)
    write_tile_buf()

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS+(16*96))
    init_tile_blue(Tile_ArrowRight)
    write_tile_buf()
}

function init_ingame_unique_names()
{
    // starting from (6,2), 20x16

    // (6,2)-(25,9) 20x8, are numbered 96-255, column first
    // (6,10)-(25,17) 20x8, are numbered 96-255, column first

    lda #lo(NAME_TABLE_0_ADDRESS+6+(2*NAMETABLE_WIDTH))
    sta tmp_addr+0
    lda #hi(NAME_TABLE_0_ADDRESS+6+(2*NAMETABLE_WIDTH))
    sta tmp_addr+1

    ppu_ctl0_set(CR_ADDRINC32)

    ldx #2

    do {
        txa
        pha

        ldy #96
        do {
            vram_set_address(tmp_addr)

            dey

            lda #0
            ldx #8
            do {
                iny
                sty PPU.IO
                dex
            } while (not zero)

            inc tmp_addr+0 // should not need carry

            iny
        } while (not zero)

        // skip down to lower half
        lda tmp_addr+0
        sec
        sbc #20
        sta tmp_addr+0
        inc tmp_addr+1

        pla
        tax
        dex
    } while (not zero)

    ppu_ctl0_clear(CR_ADDRINC32)
}

/******************************************************************************/

byte pal[4] = {0x20, // 11: white
               0x12, // 10: blue
               0x16, // 01: red
               0x10} // 00: gray (bg)

#include "tiles.as"
