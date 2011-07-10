#ines.mapper        "none"
#ines.mirroring     "Horizontal"
#ines.battery       "no"
#ines.trainer       "no"
#ines.fourscreen    "no"

#rom.banksize 16K

#include "nes.h"
#include "std.h"

#define TS_SIZE 8
#define PLAYFIELD_WIDTH     10
#define PLAYFIELD_HEIGHT    8
#define PLAYFIELD_X_START   6
#define PLAYFIELD_Y_START   4
#define HOLD_DELAY 12
#define REPEAT_DELAY 3
#define CURSOR_X_LIMIT_HI_FLAG 1
#define CURSOR_X_LIMIT_LO_FLAG 0x80
#define CURSOR_Y_LIMIT_HI_FLAG 1
#define CURSOR_Y_LIMIT_LO_FLAG 0x80

enum pf_flag1 {
    // comefrom
    cf_left = 1,
    cf_right= 2,
    cf_top  = 4,
    cf_bot  = 8,
    cf_any  = 0xF,

    // control redirect
    redir_left  = 0x10,
    redir_right = 0x20,
    redir_up    = 0x40,
    redir_down  = 0x80,
    redir_any   = 0xF0,
}

enum pf_flag2 {
    // arrow
    ar_left = 1,
    ar_right= 2,
    ar_up   = 4,
    ar_down = 8,

    // several things assume arrow is the only value in flags2
}

enum rp_flags {
    go_left = 0x00,
    go_right= 0x02,
    go_up   = 0x04,
    go_down = 0x06,

    blue    = 0x08,

    set_mode    = 0x1
}

#include "mem.as"

#define Line_FringeTopBot %01111110

#rom.bank BANK_MAIN_ENTRY
#rom.org 0xC000

#include "images.as"

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

    TS_write()

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
    TS_init()

    vblank_wait()
    vram_clear_address()
    ppu_ctl0_assign(#CR_NMI)
    ppu_ctl1_assign(#CR_BACKVISIBLE|CR_SPRITESVISIBLE|CR_BACKNOCLIP|CR_SPRNOCLIP)

    //enable_interrupts()

    //some_tests()
    //TS_flush()

    lda #0
    sta cursor_x
    sta cursor_y
    lda cursor_x_limit_lookup
    sta cursor_x_limit_flag
    lda cursor_y_limit_lookup
    sta cursor_y_limit_flag

    lda #1
    sta current_command
    update_current_command_tile()
    lda #0
    sta current_color

    init_cursor_sprites()
    update_cursor_sprites()

    refresh_playfield()

    forever
    {
        lda _joypad0
        tax
        eor last_joypad0
        stx last_joypad0
        and _joypad0
        sta new_joypad0

        lda #BUTTON_SELECT
        bit new_joypad0
        php

        // A
        bpl no_place
        lda #1
        bit current_color
        if (zero)
        {
            place_red_command()
        }
        else
        {
            place_blue_command()
        }
        TS_flush()
        jmp no_clear

no_place:
        // B
        bvc no_clear
        lda #1
        bit current_color
        if (equal)
        {
            clear_red_command()
        }
        else
        {
            clear_blue_command()
        }
        TS_flush()

no_clear:
        plp
        if (not zero)
        {
            inc current_color

            update_cursor_sprites()
        }

        cursor_test()
    }
}

/******************************************************************************/

function calc_cell_offset()
{
    lda cursor_x
    asl A
    asl A
    asl A
    sta tmp_byte
    lda cursor_y
    adc tmp_byte
    tax
}

function update_current_command_tile()
{
    lda #0
    sta current_command_tile+1

    lda current_command
    asl A
    rol current_command_tile+1
    asl A
    rol current_command_tile+1
    asl A
    rol current_command_tile+1
    sta current_command_tile+0

    clc
    lda #lo(Tile_Cmds)
    adc current_command_tile+0
    sta current_command_tile+0
    lda #hi(Tile_Cmds)
    adc current_command_tile+1
    sta current_command_tile+1
}


inline setup_blue_command_playfield_addr()
{
    TS_find_free()
    pha
    lda cursor_y
    asl A
    tax
    inx
    lda cursor_x
    asl A
    adc #1
    pos_to_nametable()
}

inline setup_red_command_playfield_addr()
{
    TS_find_free()
    pha
    lda cursor_y
    asl A
    tax
    lda cursor_x
    asl A
    pos_to_nametable()
}

function blue_command_update_surroundings()
{
    pha

    // left
    ldx cursor_x
    ldy cursor_y
    TU_2()

    // up
    ldx cursor_x
    ldy cursor_y
    pla
    pha
    TU_1()

    // right
    ldx cursor_x
    ldy cursor_y
    lda cursor_x_limit_lookup, X
    beq place_blue_no_right_limit
    bmi place_blue_no_right_limit

    pla
    pha
    TU_right_edge()
    jmp place_blue_skip_right

place_blue_no_right_limit:
    inx
    pla
    pha
    clc
    adc #PLAYFIELD_HEIGHT // right 1 cell
    TU_2()

place_blue_skip_right:

    // down
    ldx cursor_x
    ldy cursor_y
    lda cursor_y_limit_lookup, Y
    beq place_blue_no_down_limit
    bmi place_blue_no_down_limit

    pla
    TU_bottom_edge()
    jmp place_blue_skip_down

place_blue_no_down_limit:
    iny
    pla
    clc
    adc #1 // down 1 cell
    TU_1()

place_blue_skip_down:
    
}

function red_command_update_surroundings()
{
    pha

    // right
    ldx cursor_x
    ldy cursor_y
    pla
    pha
    TU_1()

    // down
    ldx cursor_x
    ldy cursor_y
    pla
    pha
    TU_2()

    // left
    ldx cursor_x
    ldy cursor_y
    lda cursor_x_limit_lookup, X
    bpl place_red_no_left_limit

    pla
    pha
    TU_left_edge()
    jmp place_red_skip_left

place_red_no_left_limit:
    dex
    pla
    pha
    sec
    sbc #PLAYFIELD_HEIGHT // left 1 cell
    TU_1()

place_red_skip_left:

    // up
    ldx cursor_x
    ldy cursor_y
    lda cursor_y_limit_lookup, Y
    bpl place_red_no_up_limit

    pla
    TU_top_edge()
    jmp place_red_skip_up

place_red_no_up_limit:
    dey
    pla
    sec
    sbc #1 // up 1 cell
    TU_2()

place_red_skip_up:
    
}

function place_blue_command()
{
    calc_cell_offset()
    lda current_command
    sta playfield_blue_cmd, X

    txa
    pha

    ldx cursor_x
    ldy cursor_y
    TU_command3()

    pla
    blue_command_update_surroundings()
}

function place_red_command()
{
    calc_cell_offset()
    lda current_command
    sta playfield_red_cmd, X

    txa
    pha

    ldx cursor_x
    ldy cursor_y
    TU_command0()

    pla
    red_command_update_surroundings()
}

function clear_blue_command()
{
    calc_cell_offset()
    lda #0
    sta playfield_blue_cmd, X

    txa
    pha

    lda playfield_blue_flags1, X
    sta TU_playfield_flags1
    lda playfield_blue_flags2, X
    sta TU_playfield_flags2
    ldx cursor_x
    ldy cursor_y
    TU_lines3()

    pla
    blue_command_update_surroundings()
}

function clear_red_command()
{
    calc_cell_offset()
    lda #0
    sta playfield_red_cmd, X

    txa
    pha

    lda playfield_red_flags1, X
    sta TU_playfield_flags1
    lda playfield_red_flags2, X
    sta TU_playfield_flags2
    ldx cursor_x
    ldy cursor_y
    TU_lines0()

    pla
    red_command_update_surroundings()
}

/******************************************************************************/

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
    do {
        lda oam_ready
    } while (not zero)

    lda cursor_x
    asl A   // each logical block is 2x2
    clc
    adc #PLAYFIELD_X_START
    asl A
    asl A
    asl A
    sta oam_buf[0].x
    sta oam_buf[2].x
    clc
    adc #8
    sta oam_buf[1].x
    sta oam_buf[3].x

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
    stx oam_buf[1].y
    txa
    clc
    adc #8
    sta oam_buf[2].y
    sta oam_buf[3].y

    lda #0
    sta oam_buf[0].attributes
    sta oam_buf[1].attributes
    sta oam_buf[3].attributes
    lda #%11000000 // h&v flip
    sta oam_buf[2].attributes
    ldx #2
    stx oam_buf[0].tile
    inx
    stx oam_buf[1].tile
    stx oam_buf[2].tile
    inx
    stx oam_buf[3].tile

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

    lda #rp_flags.go_left|rp_flags.set_mode
    sta red_start_dir
    sta blue_start_dir

    lda #pf_flag1.cf_left|pf_flag1.redir_up
    sta playfield_blue_flags1[2*8+2]

    lda #pf_flag1.cf_bot|pf_flag1.redir_left
    sta playfield_blue_flags1[2*8+1]
    lda #pf_flag2.ar_left
    sta playfield_blue_flags2[2*8+1]

    lda #pf_flag1.cf_top|pf_flag1.cf_bot|pf_flag1.redir_right
    sta playfield_red_flags1[2*8+2]
    lda #pf_flag2.ar_right
    sta playfield_red_flags2[2*8+2]

    lda #pf_flag1.cf_top|pf_flag1.redir_down
    sta playfield_red_flags1[2*8+1]
    lda #pf_flag2.ar_down
    sta playfield_red_flags2[2*8+1]

    //
    lda #pf_flag1.cf_left|pf_flag1.redir_up
    sta playfield_blue_flags1[2*8+6]

    lda #pf_flag1.cf_bot|pf_flag1.redir_left
    sta playfield_blue_flags1[2*8+5]
    lda #pf_flag2.ar_left
    sta playfield_blue_flags2[2*8+5]

    lda #pf_flag1.cf_top|pf_flag1.cf_bot|pf_flag1.redir_right
    sta playfield_red_flags1[2*8+6]
    lda #pf_flag2.ar_right
    sta playfield_red_flags2[2*8+6]

    lda #pf_flag1.cf_top|pf_flag1.redir_down
    sta playfield_red_flags1[2*8+5]
    lda #pf_flag2.ar_down
    sta playfield_red_flags2[2*8+5]
}

/******************************************************************************/

function reset_paths()
{
    ldx #sizeof(playfield_blue_flags1)
    do {
        lda playfield_blue_flags1-1, X
        and #~pf_flag1.cf_any
        sta playfield_blue_flags1-1, X
        lda playfield_red_flags1-1, X
        and #~pf_flag1.cf_any
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

    lda #0
    sta PPU.SPR_ADDRESS
    vram_sprite_dma_copy(oam_buf)
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

    ldx #8-1
    do {
        lda bg_palette_1, X
        sta PPU.IO
        dex
    } while (not minus)

    vram_set_address_i(PAL_1_ADDRESS)
    ldx #4-1
    do {
        lda sp_palette, X
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
    write_tile_red_bg(Tile_CmdAlpha)

    vram_set_address_i(PATTERN_TABLE_0_ADDRESS+(16*96))
    init_tile_red(Tile_ArrowLeft)
    write_tile_buf()

    // 77: right border
    vram_set_address_i(PATTERN_TABLE_0_ADDRESS+(16*77))
    write_tile_white(Tile_Grid_Edge_Right)
    // Setup pattern table 1

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS)
    // 0: empty bg tile
    write_tile_blue_bg(Tile_CmdAlpha)

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS+(16*96))
    init_tile_blue(Tile_ArrowRight)
    write_tile_buf()

    // 76: bottom border
    vram_set_address_i(PATTERN_TABLE_1_ADDRESS+(16*76))
    write_tile_white(Tile_Grid_Edge_Bot)

    // 77: right border
    //vram_set_address_i(PATTERN_TABLE_1_ADDRESS+(16*77))
    write_tile_white(Tile_Grid_Edge_Right)
}

function init_ingame_unique_names()
{
    ppu_ctl0_set(CR_ADDRINC32)

    // main body, starting from (6,4), 20x16

    // (6,4)-(25,11) 20x8, are numbered 96-255, column first
    // (6,12)-(25,19) 20x8, are numbered 96-255, column first

    lda #lo(NAME_TABLE_0_ADDRESS+6+(4*NAMETABLE_WIDTH))
    sta tmp_addr+0
    lda #hi(NAME_TABLE_0_ADDRESS+6+(4*NAMETABLE_WIDTH))
    sta tmp_addr+1

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

    // borders for stuff reaching over the edges

    // left border, (5,4)-(5,10) (inc 2) are numbered 88-91
    // left border, (5,12)-(5,18) (inc 2) are numbered 88-91

    vram_set_address_i(NAME_TABLE_0_ADDRESS+5+(4*NAMETABLE_WIDTH))
    ldx #2
    do {
        txa
        pha

        ldx #4
        ldy #88
        lda #0
        do {
            sty PPU.IO
            sta PPU.IO
            iny
            dex
        } while (not zero)

        pla
        tax
        dex
    } while (not zero)

    // right border, (26,5)-(26,11) (inc 2) are numbered 92-95
    // right border, (26,13)-(26,19) (inc 2) are numbered 92-95
    vram_set_address_i(NAME_TABLE_0_ADDRESS+26+(4*NAMETABLE_WIDTH))
    ldx #2
    do {
        txa
        pha

        ldx #4
        ldy #92
        lda #77 // plain right grid
        do {
            sta PPU.IO
            sty PPU.IO
            iny
            dex
        } while (not zero)

        pla
        tax
        dex
    } while (not zero)

    ppu_ctl0_clear(CR_ADDRINC32)

    // top border, (6,3)-(24,3) (inc 2) are numbered 78-87
    vram_set_address_i(NAME_TABLE_0_ADDRESS+6+(3*NAMETABLE_WIDTH))
    ldx #10
    ldy #78
    lda #0
    do {
        sty PPU.IO
        sta PPU.IO
        iny
        dex
    } while (not zero)

    // bottom border, (7,20)-(26,20) (inc 2) are numbered 78-87
    vram_set_address_i(NAME_TABLE_0_ADDRESS+6+(20*NAMETABLE_WIDTH))
    ldx #10
    ldy #78
    lda #76 // plain bottom grid
    do {
        sta PPU.IO
        sty PPU.IO
        iny
        dex
    } while (not zero)

    // top half attribute tables
    vram_set_address_i(ATTRIBUTE_TABLE_0_ADDRESS+(8*1))
    ldx #2
    do {
        lda #%01010101
        sta PPU.IO
        sta PPU.IO
        sta PPU.IO
        lda #%00010001
        sta PPU.IO
        lda #%01000100
        sta PPU.IO
        lda #%01010101
        sta PPU.IO
        sta PPU.IO
        sta PPU.IO
        dex
    } while (not equal)
    // bottom half attribute tables
    vram_set_address_i(ATTRIBUTE_TABLE_0_ADDRESS+(8*3)+3)
    lda #%01000100
    sta PPU.IO
    lda #%00010001
    sta PPU.IO
    vram_set_address_i(ATTRIBUTE_TABLE_0_ADDRESS+(8*4)+3)
    lda #%01000100
    sta PPU.IO
    lda #%00010001
    sta PPU.IO
}

function refresh_playfield()
{
    // TODO: edges
    ldy #0

    do {
        ldx #0
        do
        {
            txa
            pha
            tya
            pha

            refresh_tile0()
            refresh_tile1()
            refresh_tile2()
            refresh_tile3()

            // row end
            pla
            tay
            pla
            tax
            inx
            cpx #PLAYFIELD_WIDTH
        } while (not equal)
        iny
        cpy #PLAYFIELD_HEIGHT
    } while (not equal)

    TS_flush()
}

inline refresh_get_xy()
{
    tsx
    ldy 0x103, X
    lda 0x104, X
    tax
}

function refresh_calc_cell_offset()
{
    asl A
    asl A
    asl A
    sta tmp_byte
    tya
    adc tmp_byte
}

function refresh_tile0()
{
    // tile 0
    txa

    refresh_calc_cell_offset()
    tay
    lda playfield_red_cmd, Y
    if (zero) {
        lda playfield_red_flags1, Y
        sta TU_playfield_flags1
        lda playfield_red_flags2, Y
        sta TU_playfield_flags2

        refresh_get_xy()

        TU_lines0()
    }
    else
    {
        refresh_get_xy()

        TU_command0()
    }
}

function refresh_tile1()
{
    // tile 1
    refresh_get_xy()

    refresh_calc_cell_offset()

    TU_1()
}

function refresh_tile2()
{
    // tile 1
    refresh_get_xy()
    refresh_calc_cell_offset()
    TU_2()
}

function refresh_tile3()
{
    // tile 3
    refresh_get_xy()
    refresh_calc_cell_offset()
    tay
    lda playfield_blue_cmd, Y
    if (zero) {
        lda playfield_blue_flags1, Y
        sta TU_playfield_flags1
        lda playfield_blue_flags2, Y
        sta TU_playfield_flags2

        refresh_get_xy()

        TU_lines3()
    }
    else
    {
        refresh_get_xy()

        TU_command3()
    }
}


// In: A = x, X = y, Y = tile stage address offset
// uses tmp_byte heavily
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

    sta TS_addr, Y
    ldx tmp_byte
    stx TS_addr+1, Y
}

function init_cursor_sprites()
{
    // set the fixed parts of the cursor
    TS_find_free()

    // pattern 3, top right and bottom left
    ldx #16*3
    stx TS_addr+0, Y
    ldx #0
    stx TS_addr+1, Y

    tax
    stx tmp_byte
    TS_clear()  // TODO: need an "init"
    ldx tmp_byte
    TS_set_white(Tile_Cursor_TopRight_BotLeft)
    TS_finalize()
}

function update_cursor_sprites()
{
    // pattern 2, top left
    TS_find_free()

    ldx #16*2
    stx TS_addr+0, Y
    ldx #0
    stx TS_addr+1, Y

    tax
    stx tmp_byte
    TS_clear()

    lda #1
    bit current_color
    if (zero)
    {
        lda current_command_tile+0
        sta tmp_addr+0
        lda current_command_tile+1
        sta tmp_addr+1
        ldx tmp_byte
        TS_set_ind_red(tmp_addr)
    }

    ldx tmp_byte
    TS_set_white(Tile_Cursor_TopLeft)

    TS_finalize()

    // pattern 3, bottom right
    TS_find_free()

    ldx #16*4
    stx TS_addr+0, Y
    ldx #0
    stx TS_addr+1, Y

    tax
    stx tmp_byte
    TS_clear()

    lda #1
    bit current_color
    if (not zero)
    {
        lda current_command_tile+0
        sta tmp_addr+0
        lda current_command_tile+1
        sta tmp_addr+1
        ldx tmp_byte
        TS_set_ind_blue(tmp_addr)
    }

    ldx tmp_byte

    TS_set_white(Tile_Cursor_BotRight)

    TS_finalize()

    TS_flush()
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

byte times_16[16] = {
    0x00,0x10,0x20,0x30,0x40,0x50,0x60,0x70,
    0x80,0x90,0xA0,0xB0,0xC0,0xD0,0xE0,0xF0}

/*
byte times_8[16] = {
    0x00,0x08,0x10,0x18,0x20,0x28,0x30,0x38,
    0x40,0x48,0x50,0x58,0x60,0x68,0x70,0x78}
*/
/*
byte cf_to_op_redir[16] = {
  // 0000
    %00000000,
  // 0001
    %00100000,
  // 0010
    %00010000,
  // 0011
    %00110000,
  // 0100
    %10000000,
  // 0101
    %10100000,
  // 0110
    %10010000,
  // 0111
    %10110000,
  // 1000
    %01000000,
  // 1001
    %01100000,
  // 1010
    %01010000,
  // 1011
    %01110000,
  // 1100
    %11000000,
  // 1101
    %11100000,
  // 1110
    %11010000,
  // 1111
    %11110000}
*/

byte corner_masks[8] = {
    // bottom left
    pf_flag1.redir_left |   pf_flag1.cf_bot,
    pf_flag1.redir_down |   pf_flag1.cf_left,
    // bottom right
    pf_flag1.redir_right|   pf_flag1.cf_bot,
    pf_flag1.redir_down |   pf_flag1.cf_right,
    // top left
    pf_flag1.redir_left |   pf_flag1.cf_top,
    pf_flag1.redir_up   |   pf_flag1.cf_left,
    // top right
    pf_flag1.redir_right|   pf_flag1.cf_top,
    pf_flag1.redir_up   |   pf_flag1.cf_right}

byte cf_left_redir_right[] = {pf_flag1.cf_left|pf_flag1.redir_right}
byte cf_right_redir_left[] = {pf_flag1.cf_right|pf_flag1.redir_left}
byte cf_top_redir_down[] = {pf_flag1.cf_top|pf_flag1.redir_down}
byte cf_bot_redir_up[] = {pf_flag1.cf_bot|pf_flag1.redir_up}

/*
pointer render_path_jump_table[8] = {
    path_blue_left-1,
    path_blue_right-1,
    path_blue_up-1,
    path_blue_down-1,
    path_red_left-1,
    path_red_right-1,
    path_red_up-1,
    path_red_down-1}
*/

byte sp_palette[4] = {
    0x20, // 11: white
    0x16, // 10: red
    0x12, // 01: blue
    0x20, // 00: light gray
}

/*
byte bg_palette_1[4] = {
    0x3D, // 11: gray (fake bg)
    0x16, // 10: red
    0x12, // 01: blue
    0x20, // 00: light gray (true bg)
}
*/
/*
byte bg_palette_1[4] = {
    0x3D, // 11: gray (fake bg)
    0x16, // 10: red
    0x12, // 01: blue
    0x20, // 00: light gray (true bg)
}
*/
byte bg_palette_1[4] = {
    0x3D, // 11: gray (fake bg)
    0x16, // 10: red
    0x12, // 01: blue
    0x0D, // 00: light gray (true bg)
}

/*
byte bg_palette_0[4] = {
    0x2D, // 11: 
    0x26, // 10: red
    0x22, // 01: blue
    0x20, // 00: 
}
*/

/*
byte bg_palette_0[4] = {
    0x0D, // 11: black (fake bg)
    0x16, // 10: red
    0x12, // 01: blue
    0x20, // 00: light gray (true bg)
}
*/
byte bg_palette_0[4] = {
    0x3D, // 11: black (fake bg)
    0x16, // 10: red
    0x12, // 01: blue
    0x20, // 00: light gray (true bg)
}

#include "tile_update.as"
#include "tile_fixed.as"
#include "tile_stage.as"
