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
byte    tmp_byte
shared byte _ppu_ctl0, _ppu_ctl1

byte tile_buf_1[8]
byte tile_buf_0[8]
#ram.end

// shared pattern staging area
#ram.org 0x20, 144
shared word tile_stage_addr[8]
typedef struct tile_stage_s {
    byte tile_buf_1[8]
    byte tile_buf_0[8]
}
shared tile_stage_s tile_stage[8]

#ram.end

#ram.org 0x300, 1024 // HACK: just made up a large number for now
byte next_stage_index
byte tile_stage_written // 0: nmi needs to write to ppu, nonzero: main thread is writing
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
    pha
    txa
    pha
    tya
    pha

    ppu_ctl0_clear(CR_BACKADDR1000)

    write_tile_stages()

    // initial delay to get sync'd with hsyncs
    ldx #48                 // 2    
    do {
        dex                 // 2 * 10
    } while (not zero)      // 3 * 9 + 2

    // 341/3 cycles per line + change (8 cycles)
    lda #0x20               // 2
    ldy #9+(8*12)          // 2
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

    pla
    tay
    pla
    tax
    pla
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

    sta  _ppu_ctl0
    sta  _ppu_ctl1

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
    init_tile_stage()

    vblank_wait()
    vram_clear_address()
    ppu_ctl0_assign(#CR_NMI)
    ppu_ctl1_assign(#CR_BACKVISIBLE|CR_SPRITESVISIBLE|CR_BACKNOCLIP)

    enable_interrupts()

    forever
    {
        some_tests()

        ldx #00
    }
}

/******************************************************************************/

function some_tests()
{
    ldx #20
    ldy #0
    do {
        txa
        pha

        tya
        pha

        find_free_tile_stage()
        pha
        init_tile_stage_red(Tile_ArrowRight)
        pla
        tax
        pla
        pha
        ldy #1
        pos_to_nametable()
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        init_tile_stage_red(Tile_ArrowLeft)
        pla
        tax
        pla
        pha
        ldy #2
        pos_to_nametable()
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        init_tile_stage_red(Tile_ArrowRight)
        pla
        tax
        pla
        pha
        ldy #3
        pos_to_nametable()
        finalize_tile_stage()

        pla
        tay
        iny

        pla
        tax
        dex
    } while (not zero)

    ldx #16
    ldy #0
    do {
        txa
        pha

        tya
        pha

        find_free_tile_stage()
        pha
        init_tile_stage_red(Tile_ArrowUp)
        pla
        tax
        pla
        pha
        tay
        lda #5
        pos_to_nametable()
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        init_tile_stage_red(Tile_ArrowDown)
        pla
        tax
        pla
        pha
        tay
        lda #6
        pos_to_nametable()
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        init_tile_stage_red(Tile_ArrowUp)
        pla
        tax
        pla
        pha
        tay
        lda #7
        pos_to_nametable()
        finalize_tile_stage()

        pla
        tay
        iny

        pla
        tax
        dex
    } while (not zero)
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
    write_tile_red_bg(Tile_Cmds)

    vram_set_address_i(PATTERN_TABLE_0_ADDRESS+(16*96))
    init_tile_red(Tile_ArrowLeft)
    write_tile_buf()

    // Setup pattern table 1

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS)
    // 0: empty bg tile
    write_tile_blue_bg(Tile_Cmds)

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS+(16*96))
    init_tile_blue(Tile_ArrowRight)
    write_tile_buf()
}

function init_ingame_unique_names()
{
    // starting from (6,4), 20x16

    // (6,4)-(25,11) 20x8, are numbered 96-255, column first
    // (6,12)-(25,19) 20x8, are numbered 96-255, column first

    lda #lo(NAME_TABLE_0_ADDRESS+6+(4*NAMETABLE_WIDTH))
    sta tmp_addr+0
    lda #hi(NAME_TABLE_0_ADDRESS+6+(4*NAMETABLE_WIDTH))
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

// In: A = x, Y = y, X = tile stage address offset
function pos_to_nametable()
{
    asl A
    asl A
    asl A
    clc
    adc #96
    sty tmp_byte
    adc tmp_byte

    cpy #8
    if (plus)
    {
        ldy #0x1
        sec
        sbc #8
    }
    else
    {
        ldy #0
    }
    sty tmp_byte

    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte

    sta tile_stage_addr, X
    ldy tmp_byte
    sty tile_stage_addr+1, X
}

/******************************************************************************/

byte pal[4] = {0x20, // 11: white
               0x12, // 10: blue
               0x16, // 01: red
               0x10} // 00: gray (bg)

#include "tiles.as"
