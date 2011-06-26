#ines.mapper        "none"
#ines.mirroring     "Horizontal"
#ines.battery       "no"
#ines.trainer       "no"
#ines.fourscreen    "no"

#rom.banksize 16K

#include "nes.h"
#include "std.h"

#ram.org 0x0, 0x30
pointer tmp_addr
byte    tmp_byte
shared byte _ppu_ctl0, _ppu_ctl1
shared byte _joypad0
byte last_joypad0
byte new_joypad0
#define HOLD_DELAY 12
#define REPEAT_DELAY 3
struct hold_count_joypad0
{
    byte RIGHT, LEFT, DOWN, UP, START, SELECT, A, B
}
struct repeat_count_joypad0
{
    byte RIGHT, LEFT, DOWN, UP, START, SELECT, A, B
}
byte test_idx
byte cursor_x, cursor_y
pointer current_command

#define PLAYFIELD_WIDTH     10
#define PLAYFIELD_HEIGHT    8
#define PLAYFIELD_X_START   6
#define PLAYFIELD_Y_START   4
#define CURSOR_X_LIMIT_HI_FLAG 0x01
#define CURSOR_X_LIMIT_LO_FLAG 0x81
#define CURSOR_Y_LIMIT_HI_FLAG 0x01
#define CURSOR_Y_LIMIT_LO_FLAG 0x81
byte cursor_x_limit_flag, cursor_y_limit_flag 

byte tile_buf_1[8]
byte tile_buf_0[8]
#ram.end

// shared pattern staging area
#ram.org 0x30, 144
shared word tile_stage_addr[8]
typedef struct tile_stage_s {
    byte tile_buf_1[8]
    byte tile_buf_0[8]
}
shared tile_stage_s tile_stage[8]

#ram.end

#ram.org 0x200, 0x100
OAM_ENTRY oam_buf[64]
#ram.end

#ram.org 0x300, 0x100
byte next_stage_index
// count on this not being in zero page
byte tile_stage_written // 0: nmi needs to write to ppu, nonzero: main thread is writing
byte oam_ready  // nonzero: nmi needs to do OAM DMA

byte blue_start_x
byte blue_start_y
byte blue_start_dir

// what display elements are displayed in each cell
// columns first to compute easier
byte playfield_blue_flags1[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]

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

byte playfield_blue_flags2[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]

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
byte playfield_blue_cmd[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]

#ram.end

#ram.org 0x400, 0x100
byte red_start_x
byte red_start_y
byte red_start_dir

byte playfield_red_flags1[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]
byte playfield_red_flags2[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]
byte playfield_red_cmd[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]
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

    ldx #162                // 2    

    lda oam_ready
    if (not zero)
    {
        vram_sprite_dma_copy(oam_buf)   // 4
        lda #0                          // 2
        sta oam_ready                   // 3 + 513
        // (162*5 - (4 + 2 + 3 + 513 + 2)) / 5 = 57.2
        ldx #57                         // 2
    }

    // initial delay
    do {
        dex                 // 2 * X
    } while (not zero)      // 3 * (X-1) + 2

    // 341/3 cycles per line + change (8 cycles)
    lda #0x20               // 2
    ldy #4+(8*12)          // 2
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
    
    // update controller once per frame
    reset_joystick()
    ldx #8
    do {
        lda JOYSTICK.CNT0
        lsr A
        if (carry)
        {
            php

            ldy hold_count_joypad0-1, X
            iny
            cpy #HOLD_DELAY
            if (not equal)
            {
                sty hold_count_joypad0-1, X
            }
            if (equal)
            {
                inc repeat_count_joypad0-1, X
                if (equal)
                {
                    // saturate at 255
                    dec repeat_count_joypad0-1, X
                }
            }

            plp
        }
        if (not carry)
        {
            lda #0
            sta hold_count_joypad0-1, X
            sta repeat_count_joypad0-1, X
        }
        rol _joypad0
        dex
    } while (not zero)

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
    sta  _joypad0
    sta  last_joypad0
    sta  oam_ready

    ldx #8
    do {
        dex
        sta  hold_count_joypad0, X
    } while (not zero)

    sta  PPU.BG_SCROLL
    sta  PPU.BG_SCROLL

    sta  PCM_CNT
    sta  PCM_VOLUMECNT
    sta  SND_CNT

    lda  #0xC0
    sta  joystick.cnt1

    // wait for PPU to turn on
    bit PPU.STATUS
vwait1:
    bit PPU.STATUS
    bpl vwait1
vwait2:
    bit PPU.STATUS
    bpl vwait2
}

interrupt.start noreturn main()
{
    system_initialize_custom()

    clear_vram()
    clear_sprites()
    init_ingame_vram()
    init_playfield()
    init_tile_stage()

    vblank_wait()
    vram_clear_address()
    ppu_ctl0_assign(#CR_NMI)
    ppu_ctl1_assign(#CR_BACKVISIBLE|CR_SPRITESVISIBLE|CR_BACKNOCLIP|CR_SPRNOCLIP)

    //enable_interrupts()

    //some_tests()
    //flush_tile_stage()

    lda #0
    sta cursor_x
    sta cursor_y
    lda cursor_x_limit_lookup
    sta cursor_x_limit_flag
    lda cursor_y_limit_lookup
    sta cursor_y_limit_flag

    lda #0
    sta current_command+0
    lda #0
    sta current_command+1

    forever
    {
        lda _joypad0
        tax
        eor last_joypad0
        stx last_joypad0
        and _joypad0
        sta new_joypad0


        bit new_joypad0

        bvc no_test
        place_red_command()
        flush_tile_stage()
        jmp no_clear
no_test:
        bpl no_clear
        clear_red_command()
        flush_tile_stage()
no_clear:

        cursor_test()
    }
}

/******************************************************************************/

inline setup_blue_command_addr()
{
    find_free_tile_stage()
    pha
    lda cursor_y
    asl A
    tax
    inx
    lda cursor_x
    asl A
    clc
    adc #1
    pos_to_nametable()
}

inline setup_red_command_addr()
{
    find_free_tile_stage()
    pha
    lda cursor_y
    asl A
    tax
    lda cursor_x
    asl A
    pos_to_nametable()
}

function place_blue_command()
{
    setup_blue_command_addr()

    clc
    lda #lo(Tile_Cmds)
    adc current_command+0
    sta tmp_addr+0
    lda #hi(Tile_Cmds)
    adc current_command+1
    sta tmp_addr+1

    pla
    tax
    set_tile_stage_blue_bg_ind()
    finalize_tile_stage()
}

function place_red_command()
{
    setup_red_command_addr()

    clc
    lda #lo(Tile_Cmds)
    adc current_command+0
    sta tmp_addr+0
    lda #hi(Tile_Cmds)
    adc current_command+1
    sta tmp_addr+1

    pla
    tax
    set_tile_stage_red_bg_ind()
    finalize_tile_stage()
}

function clear_blue_command()
{
    setup_blue_command_addr()

    pla
    tax
    set_tile_stage_clear()
    finalize_tile_stage()
}

function clear_red_command()
{
    setup_red_command_addr()

    pla
    tax
    set_tile_stage_clear()
    finalize_tile_stage()
}

function some_clears()
{
    ldx #20
    ldy #0
    sty test_idx
    do {
        txa
        pha

        find_free_tile_stage()
        pha
        ldx #1
        lda test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_Clear)
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        ldx #2
        lda test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_Clear)
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        ldx #3
        lda test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_Clear)
        finalize_tile_stage()

        inc test_idx

        pla
        tax
        dex
    } while (not zero)

    ldx #16
    ldy #0
    sty test_idx
    do {
        txa
        pha

        find_free_tile_stage()
        pha
        lda #5
        ldx test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_Clear)
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        lda #6
        ldx test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_Clear)
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        lda #7
        ldx test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_Clear)
        finalize_tile_stage()

        inc test_idx

        pla
        tax
        dex
    } while (not zero)
}

function some_tests()
{
    ldx #20
    ldy #0
    sty test_idx
    do {
        txa
        pha

        find_free_tile_stage()
        pha
        ldx #1
        lda test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_ArrowRight)
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        ldx #2
        lda test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_ArrowLeft)
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        ldx #3
        lda test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_ArrowRight)
        finalize_tile_stage()

        inc test_idx

        pla
        tax
        dex
    } while (not zero)

    ldx #16
    ldy #0
    sty test_idx
    do {
        txa
        pha

        find_free_tile_stage()
        pha
        lda #5
        ldx test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_ArrowUp)
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        lda #6
        ldx test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_ArrowDown)
        finalize_tile_stage()

        find_free_tile_stage()
        pha
        lda #7
        ldx test_idx
        pos_to_nametable()
        pla
        tax
        init_tile_stage_red(Tile_ArrowUp)
        finalize_tile_stage()

        inc test_idx

        pla
        tax
        dex
    } while (not zero)
}

inline process_X_button(button_mask, button_repeat_count, delta)
{
    lda new_joypad0
    and #button_mask
    bne do_X_button

    lda button_repeat_count
    cmp #REPEAT_DELAY
    bmi skip_X_button

do_X_button:
    ldx #delta
    lda #0
    sta button_repeat_count

skip_X_button:
}

inline process_Y_button(button_mask, button_repeat_count, delta)
{
    lda new_joypad0
    and #button_mask
    bne do_Y_button

    lda button_repeat_count
    cmp #REPEAT_DELAY
    bmi skip_Y_button

do_Y_button:
    ldy #delta
    lda #0
    sta button_repeat_count

skip_Y_button:
}

function process_left_button()
{
    process_X_button(BUTTON_LEFT, repeat_count_joypad0.LEFT, -1)
}

function process_right_button()
{
    process_X_button(BUTTON_RIGHT, repeat_count_joypad0.RIGHT, 1)
}

function process_up_button()
{
    process_Y_button(BUTTON_UP, repeat_count_joypad0.UP, -1)
}

function process_down_button()
{
    process_Y_button(BUTTON_DOWN, repeat_count_joypad0.DOWN, 1)
}

function cursor_test()
{
    ldx #0
    ldy #0

    lda cursor_x_limit_flag
    beq no_limit_x
    bmi at_x_low_limit
    
    process_left_button()
    jmp check_limit_y

no_limit_x:
    process_left_button()
at_x_low_limit:
    process_right_button()

check_limit_y:
    lda cursor_y_limit_flag
    beq no_limit_y
    bmi at_y_low_limit

    process_up_button()
    jmp process_new_coords

no_limit_y:
    process_up_button()
at_y_low_limit:
    process_down_button()

process_new_coords:
    stx tmp_byte
    lda cursor_x
    clc
    adc tmp_byte
    sta cursor_x

    tax
    lda cursor_x_limit_lookup, X
    sta cursor_x_limit_flag

process_new_coords_y:
    sty tmp_byte
    lda cursor_y
    clc
    adc tmp_byte
    sta cursor_y

    tay
    lda cursor_y_limit_lookup, Y
    sta cursor_y_limit_flag

    // update cursor sprite pos

    lda cursor_x
    asl A   // each logical block is 2x2
    clc
    adc #PLAYFIELD_X_START
    asl A
    asl A
    asl A
    sta oam_buf[0].x

    lda cursor_y
    asl A
    clc
    adc #PLAYFIELD_Y_START
    asl A
    asl A
    asl A
    tax
    dex
    stx oam_buf[0].y

    lda #0
    sta oam_buf[0].attributes
    lda #2
    sta oam_buf[0].tile

    ldx #01
    stx oam_ready
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

function clear_sprites()
{
    ldx #0
    lda #0xFF
    do {
        dex
        sta oam_buf, X
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
        lda bg_palette, X
        sta PPU.IO
        dex
    } while (not minus)

    vram_set_address_i(PAL_1_ADDRESS)
    ldx #4-1
    do {
        lda bg_palette, X
        sta PPU.IO
        dex
    } while (not minus)

}

function init_ingame_fixed_patterns()
{
    // will probably want to break this out once we do have
    // bg tiles shared common between pat tbls

    // Setup pattern table 0

    // 0: empty bg tile
    vram_set_address_i(PATTERN_TABLE_0_ADDRESS)
    write_tile_red_bg(Tile_Cmds)

    // 2: temp cursor
    vram_set_address_i(PATTERN_TABLE_0_ADDRESS+(16*2))
    write_tile_red_bg(Tile_Elements)

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

// In: A = x, X = y, Y = tile stage address offset
function pos_to_nametable()
{
    asl A
    asl A
    asl A
    clc
    adc #96
    stx tmp_byte
    adc tmp_byte

    cpx #8
    if (plus)
    {
        ldx #0x1
        sec
        sbc #8
    }
    else
    {
        ldx #0
    }
    stx tmp_byte

    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte

    sta tile_stage_addr, Y
    ldx tmp_byte
    stx tile_stage_addr+1, Y
}

/******************************************************************************/

byte cursor_x_limit_lookup[PLAYFIELD_WIDTH] = {
    CURSOR_X_LIMIT_LO_FLAG, // X = 0 
    0, 0, 0, 0, 0, 0, 0, 0, // X = 1, 2, 3, 4, 5, 6, 7, 8
    CURSOR_X_LIMIT_HI_FLAG} // X = 9

byte cursor_y_limit_lookup[PLAYFIELD_HEIGHT] = {
    CURSOR_Y_LIMIT_LO_FLAG, // X = 0 
    0, 0, 0, 0, 0, 0,       // X = 1, 2, 3, 4, 5, 6,
    CURSOR_Y_LIMIT_HI_FLAG} // X = 7

byte bg_palette[4] = {
                0x20, // 11: white
                0x12, // 10: blue
                0x16, // 01: red
                0x10} // 00: gray (bg)

#include "tiles.as"
