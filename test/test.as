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
byte current_command
pointer current_command_tile

#define Line_FringeTopBot %01111110

#define PLAYFIELD_WIDTH     10
#define PLAYFIELD_HEIGHT    8
#define PLAYFIELD_X_START   6
#define PLAYFIELD_Y_START   4
#define CURSOR_X_LIMIT_HI_FLAG 1
#define CURSOR_X_LIMIT_LO_FLAG 0x80
#define CURSOR_Y_LIMIT_HI_FLAG 1
#define CURSOR_Y_LIMIT_LO_FLAG 0x80
byte cursor_x_limit_flag, cursor_y_limit_flag 
#ram.end

// fixed pattern setup
#ram.org 0x30, 0x10
byte tile_buf_1[8]
byte tile_buf_0[8]
#ram.end

// playfield tile update locals
#ram.org 0x30, 0x10
byte tile_update_buf_saved
byte tile_update_playfield_offset
byte tile_update_x
byte tile_update_y
#ram.end

// shared pattern staging area
#ram.org 0x40, 144
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
byte current_color

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
    cf_any  = 0xF,

    // control redirect
    redir_left  = 0x10,
    redir_right = 0x20,
    redir_up    = 0x40,
    redir_down  = 0x80,
    redir_any   = 0xF0,
}

byte playfield_blue_flags2[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]

enum pf_flag2 {
    // arrow
    ar_left = 1,
    ar_right= 2,
    ar_up   = 4,
    ar_down = 8,
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

#ram.org 0x500, 0x100

enum rp_flags {
    go_left = 0x00,
    go_right= 0x02,
    go_up   = 0x04,
    go_down = 0x06,

    blue    = 0x08,

    set_mode    = 0x1
}
// it is major overkill to reserve all this, but it is only used by one
// operation so we can reuse it for other large ops
render_path_stack:
byte render_path_stack_pointer :0x5FF
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

    lda #1
    sta current_command
    update_current_command_tile()
    lda #0
    sta current_color

    init_cursor_sprites()
    update_cursor_sprites()

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
        flush_tile_stage()
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
        flush_tile_stage()

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
    find_free_tile_stage()
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
    find_free_tile_stage()
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
    pla
    pha
    update_tile2()

    // up
    ldx cursor_x
    ldy cursor_y
    pla
    pha
    update_tile1()

    // right
    ldx cursor_x
    ldy cursor_y
    lda cursor_x_limit_lookup, X
    beq place_blue_no_right_limit
    bmi place_blue_no_right_limit

    pla
    pha
    update_tile_right_edge()
    jmp place_blue_skip_right

place_blue_no_right_limit:
    inx
    pla
    pha
    clc
    adc #PLAYFIELD_HEIGHT // right 1 cell
    update_tile2()

place_blue_skip_right:

    // down
    ldx cursor_x
    ldy cursor_y
    lda cursor_y_limit_lookup, Y
    beq place_blue_no_down_limit
    bmi place_blue_no_down_limit

    pla
    update_tile_bottom_edge()
    jmp place_blue_skip_down

place_blue_no_down_limit:
    iny
    pla
    clc
    adc #1 // down 1 cell
    update_tile1()

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
    update_tile1()

    // down
    ldx cursor_x
    ldy cursor_y
    pla
    pha
    update_tile2()

    // left
    ldx cursor_x
    ldy cursor_y
    lda cursor_x_limit_lookup, X
    bpl place_red_no_left_limit

    pla
    pha
    update_tile_left_edge()
    jmp place_red_skip_left

place_red_no_left_limit:
    dex
    pla
    pha
    sec
    sbc #PLAYFIELD_HEIGHT // left 1 cell
    update_tile1()

place_red_skip_left:

    // up
    ldx cursor_x
    ldy cursor_y
    lda cursor_y_limit_lookup, Y
    bpl place_red_no_up_limit

    pla
    update_tile_top_edge()
    jmp place_red_skip_up

place_red_no_up_limit:
    dey
    pla
    sec
    sbc #1 // up 1 cell
    update_tile2()

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
    update_tile3_command()

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
    update_tile0_command()

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
    ldx cursor_x
    ldy cursor_y
    update_tile3_lines()

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
    ldx cursor_x
    ldy cursor_y
    update_tile0_lines()

    pla
    red_command_update_surroundings()
}

/******************************************************************************/

function setup_tile0()
{
    txa
    asl A // *2
    pha

    tya
    asl A // *2
    pha

    find_free_tile_stage()
    sta tile_update_buf_saved

    pla
    tax
    pla

    pos_to_nametable()
}

// A: flags1
// X: x coord
// Y: y coord
function noreturn update_tile0_lines()
{
    sta tile_update_playfield_offset // used for flags1 here
    setup_tile0()

    ldx tile_update_buf_saved
    set_tile_stage_clear()

    jmp update_tile03_lines
}

function update_tile03_lines()
{
    // a few common line cases
    ldx tile_update_buf_saved
    lda tile_update_playfield_offset
    cmp #0x10   // redirect is in high bits
    bpl tile03_lines_has_redir

    // no redir, could be straight through
    and #pf_flag1.cf_left|pf_flag1.cf_right
    beq tile03_no_straight_h
    overlay_mono_tile_stage_midhline() // preserves X
tile03_no_straight_h:

    lda tile_update_playfield_offset
    and #pf_flag1.cf_top|pf_flag1.cf_bot
    beq tile03_no_straight_v
    overlay_mono_tile_stage_midvline()
tile03_no_straight_v:

    // skip any other processing since we have no redir to make curves
    jmp tile03_lines_done
    
tile03_lines_has_redir:

    eor #0xFF   // reverse bits in order to check which are *set* with beq

    bit cf_left_redir_right
    beq tile03_pushed_h

    bit cf_right_redir_left
    bne tile03_no_pushed_h

tile03_pushed_h:
    overlay_mono_tile_stage_midhline() // preserves X and A

tile03_no_pushed_h:
    bit cf_top_redir_down
    beq tile03_pushed_v

    bit cf_bot_redir_up
    bne tile03_no_pushed_v

tile03_pushed_v:
    overlay_mono_tile_stage_midvline()

tile03_no_pushed_v:

    lda tile_update_playfield_offset
    tax
    and #0xF
    tay
    txa
    and times_16, Y

    beq tile03_no_loops

    sta tmp_byte
    asl tmp_byte
    if (carry)
    {
        ldx tile_update_buf_saved
        overlay_mono_tile_stage(Tile_LoopDown)
    }
    asl tmp_byte
    if (carry)
    {
        ldx tile_update_buf_saved
        overlay_mono_tile_stage(Tile_LoopUp)
    }
    asl tmp_byte
    if (carry)
    {
        ldx tile_update_buf_saved
        overlay_mono_tile_stage(Tile_LoopRight)
    }
    lda tmp_byte
    if (minus)
    {
        ldx tile_update_buf_saved
        overlay_mono_tile_stage(Tile_LoopLeft)
    }

tile03_no_loops:
    
    lda tile_update_playfield_offset
    eor #0xFF
    sta tile_update_playfield_offset
    lda #8-1
    sta tmp_byte
    do {
        ldx tmp_byte
        lda corner_masks, X
        and tile_update_playfield_offset
        bne tile03_skip_corner

        lda tmp_byte
        and #~1
        asl A
        asl A
        clc
        adc #lo(Tile_LineCorners)
        sta tmp_addr+0
        lda #0
        adc #hi(Tile_LineCorners)
        sta tmp_addr+1

        ldx tile_update_buf_saved
        overlay_mono_tile_stage_ind()

tile03_skip_corner:
        dec tmp_byte
    } while (not minus)
tile03_lines_done:
    finalize_tile_stage()
}

// X: x coord
// Y: y coord
function update_tile0_command()
{
    setup_tile0()

    lda current_command_tile+0
    sta tmp_addr+0
    lda current_command_tile+1
    sta tmp_addr+1

    ldx tile_update_buf_saved
    set_tile_stage_red_bg_ind()
    finalize_tile_stage()
}

function setup_tile3()
{
    txa
    sec
    rol A // *2+1
    pha

    tya
    sec
    rol A // *2+1
    pha

    find_free_tile_stage()
    sta tile_update_buf_saved

    pla
    tax
    pla

    pos_to_nametable()
}

// A: flags1
// X: x coord
// Y: y coord
function noreturn update_tile3_lines()
{
    sta tile_update_playfield_offset
    setup_tile3()

    lda tile_update_buf_saved
    tax
    sec
    sbc #8
    sta tile_update_buf_saved
    set_tile_stage_clear()

    jmp update_tile03_lines
}

// X: x coord
// Y: y coord
function update_tile3_command()
{
    setup_tile3()

    lda current_command_tile+0
    sta tmp_addr+0
    lda current_command_tile+1
    sta tmp_addr+1

    ldx tile_update_buf_saved
    set_tile_stage_blue_bg_ind()
    finalize_tile_stage()
}

// A: precomputed cell table offset
// X: x coord
// Y: y coord
function update_tile1()
{
    sta tile_update_playfield_offset
    stx tile_update_x
    sty tile_update_y

    find_free_tile_stage()
    sta tile_update_buf_saved

    lda tile_update_y
    asl A   // *2
    tax

    lda tile_update_x
    sec
    rol A   // *2+1

    pos_to_nametable()

    ldx tile_update_buf_saved
    set_tile_stage_clear()

    // 1. vertical blue line
    // blue comefrom above OR (any comefrom AND redir up)
    ldy tile_update_playfield_offset
    ldx playfield_blue_flags1, Y
    txa
    and #pf_flag1.cf_top
    bne do_vertical_blue_line   // comefrom top
    txa
    and #pf_flag1.cf_any
    beq skip_vertical_blue_line // no comefrom
    txa
    and #pf_flag1.redir_up
    beq skip_vertical_blue_line // not redir up

do_vertical_blue_line:
    ldx tile_update_buf_saved
    set_tile_stage_blue(Tile_VLine)   // this will always be the first, so "set" is cheaper

skip_vertical_blue_line:

    // 2. blue down arrow from above
    // check Y limit
    ldx tile_update_y
    lda cursor_y_limit_lookup, X
    bmi update_tile1_4  // low Y limit, skip looking up

    ldx tile_update_playfield_offset
    lda playfield_blue_flags2-1, X  // above
    and #pf_flag2.ar_down
    beq update_tile1_3

    ldx tile_update_buf_saved
    overlay_tile_stage_blue(Tile_ArrowDown)

    // skip corresponding fringe
    jmp update_tile1_4

update_tile1_3:
    // 3. blue fringe from above
    //ldx tile_update_playfield_offset
    lda playfield_blue_cmd-1, X // above
    beq update_tile1_4

    ldx tile_update_buf_saved
    overlay_tile_stage_blue_hline(Line_FringeTopBot, 0)

update_tile1_4:
    // 4. blue up arrow from current
    ldx tile_update_playfield_offset
    lda playfield_blue_flags2, X
    and #pf_flag2.ar_up
    beq update_tile1_5

    ldx tile_update_buf_saved
    overlay_tile_stage_blue(Tile_ArrowDown)

    // skip corresponding fringe
    jmp update_tile1_6

update_tile1_5:
    // 5. blue bottom fringe from current
    //ldx tile_update_playfield_offset
    lda playfield_blue_cmd, X
    beq update_tile1_6

    ldx tile_update_buf_saved
    overlay_tile_stage_blue_hline(Line_FringeTopBot, 7)

update_tile1_6:
    // 6. horizontal red line
    // red comefrom right OR (any comefrom and redir right)
    ldy tile_update_playfield_offset

    ldx playfield_red_flags1, Y
    txa
    and #pf_flag1.cf_right
    bne do_update_tile1_6       // comefrom right
    txa
    and #pf_flag1.cf_any
    beq update_tile1_7          // no comefrom
    txa
    and #pf_flag1.redir_right
    beq update_tile1_7          // not redir right

do_update_tile1_6:
    ldx tile_update_buf_saved
    overlay_tile_stage_red(Tile_HLine)

update_tile1_7:
    // 7. red left arrow from right
    // check X limit
    ldx tile_update_x
    lda cursor_x_limit_lookup, X
    beq update_tile1_look_right // no limit, look right
    bpl update_tile1_9      // high X limit, skip looking right

update_tile1_look_right:
    ldx tile_update_playfield_offset
    lda playfield_red_flags2+PLAYFIELD_HEIGHT, X    // right
    and #pf_flag2.ar_left
    beq update_tile1_8

    ldx tile_update_buf_saved
    overlay_tile_stage_red(Tile_ArrowLeft)

    // skip corresponding fringe
    jmp update_tile1_9

update_tile1_8:
    // 8. red fringe from right
    //ldx tile_update_playfield_offset
    lda playfield_red_cmd+PLAYFIELD_HEIGHT, X   // right
    beq update_tile1_9

    ldx tile_update_buf_saved
    overlay_tile_stage_red(Tile_FringeRight)

update_tile1_9:
    // 9. red right arrow from current
    ldx tile_update_playfield_offset
    lda playfield_red_flags2, X
    and #pf_flag2.ar_down
    beq update_tile1_10

    ldx tile_update_buf_saved
    overlay_tile_stage_red(Tile_ArrowRight)

    // skip corresponding fringe
    jmp update_tile1_done

update_tile1_10:
    // 10. red right fringe from current
    //ldx tile_update_playfield_offset
    lda playfield_red_cmd, X
    beq update_tile1_done

    ldx tile_update_buf_saved
    overlay_tile_stage_red(Tile_FringeLeft)

update_tile1_done:
    finalize_tile_stage()
}

// A: precomputed cell table offset
// X: x coord
// Y: y coord
function update_tile2()
{
    sta tile_update_playfield_offset
    stx tile_update_x
    sty tile_update_y

    find_free_tile_stage()
    sta tile_update_buf_saved

    lda tile_update_y
    sec
    rol A   // *2+1
    tax

    lda tile_update_x
    asl A   // *2

    pos_to_nametable()

    ldx tile_update_buf_saved
    set_tile_stage_clear()


    // 1. horizontal blue line
    // blue comefrom left OR (any comefrom AND redir left)
    ldy tile_update_playfield_offset
    ldx playfield_blue_flags1, Y
    txa
    and #pf_flag1.cf_left
    bne do_horizontal_blue_line     // comefrom left
    txa
    and #pf_flag1.cf_any
    beq skip_horizontal_blue_line   // no comefrom
    txa
    and #pf_flag1.redir_left
    beq skip_horizontal_blue_line   // not redir left

do_horizontal_blue_line:
    ldx tile_update_buf_saved
    set_tile_stage_blue(Tile_HLine)   // this will always be the first, so "set" is cheaper

skip_horizontal_blue_line:

    // 2. blue right arrow from left
    // check X limit
    ldx tile_update_x
    lda cursor_x_limit_lookup, X
    bmi update_tile2_4  // low X limit, skip looking left

    ldx tile_update_playfield_offset
    lda playfield_blue_flags2-PLAYFIELD_HEIGHT, X   // left
    and #pf_flag2.ar_right
    beq update_tile2_3

    ldx tile_update_buf_saved
    overlay_tile_stage_blue(Tile_ArrowRight)

    // skip corresponding fringe
    jmp update_tile2_4

update_tile2_3:
    // 3. blue fringe from left
    //ldx tile_update_playfield_offset
    lda playfield_blue_cmd-PLAYFIELD_HEIGHT, X // left
    beq update_tile2_4

    ldx tile_update_buf_saved
    overlay_tile_stage_blue(Tile_FringeLeft)

update_tile2_4:
    // 4. blue left arrow from current
    ldx tile_update_playfield_offset
    lda playfield_blue_flags2, X
    and #pf_flag2.ar_left
    beq update_tile2_5

    ldx tile_update_buf_saved
    overlay_tile_stage_blue(Tile_ArrowLeft)

    // skip corresponding fringe
    jmp update_tile2_6

update_tile2_5:
    // 5. blue right fringe from current
    //ldx tile_update_playfield_offset
    lda playfield_blue_cmd, X
    beq update_tile2_6

    ldx tile_update_buf_saved
    overlay_tile_stage_blue(Tile_FringeRight)

update_tile2_6:
    // 6. vertical red line
    // red comefrom below OR (any comefrom and redir down)
    ldy tile_update_playfield_offset

    ldx playfield_red_flags1, Y
    txa
    and #pf_flag1.cf_bot
    bne do_update_tile2_6       // comefrom bottom
    txa
    and #pf_flag1.cf_any
    beq update_tile2_7          // no comefrom
    txa
    and #pf_flag1.redir_down
    beq update_tile2_7          // not redir down

do_update_tile2_6:
    ldx tile_update_buf_saved
    overlay_tile_stage_red(Tile_VLine)

update_tile2_7:
    // 7. red up arrow from below
    // check Y limit
    ldx tile_update_y
    lda cursor_y_limit_lookup, X
    beq update_tile2_look_down // no limit, look down
    bpl update_tile2_9      // high Y limit, skip looking down

update_tile2_look_down:
    ldx tile_update_playfield_offset
    lda playfield_red_flags2+1, X   // below
    and #pf_flag2.ar_up
    beq update_tile2_8

    ldx tile_update_buf_saved
    overlay_tile_stage_red(Tile_ArrowUp)

    // skip corresponding fringe
    jmp update_tile2_9

update_tile2_8:
    // 8. red fringe from below
    //ldx tile_update_playfield_offset
    lda playfield_red_cmd+1, X // below
    beq update_tile2_9

    ldx tile_update_buf_saved
    overlay_tile_stage_red_hline(Line_FringeTopBot, 7)

update_tile2_9:
    // 9. red down arrow from current
    ldx tile_update_playfield_offset
    lda playfield_red_flags2, X
    and #pf_flag2.ar_down
    beq update_tile2_10

    ldx tile_update_buf_saved
    overlay_tile_stage_red(Tile_ArrowDown)

    // skip corresponding fringe
    jmp update_tile2_done

update_tile2_10:
    // 10. red bottom fringe from current
    //ldx tile_update_playfield_offset
    lda playfield_red_cmd, X
    beq update_tile2_done

    ldx tile_update_buf_saved
    overlay_tile_stage_red_hline(Line_FringeTopBot, 0)

update_tile2_done:
    finalize_tile_stage()
}

// A: precomputed offset of the adjacent main cell
// Y: y coord of both
function update_tile_left_edge()
{
    sta tile_update_playfield_offset
    sty tile_update_y

    find_free_tile_stage()
    sta tile_update_buf_saved

    lda tile_update_y
    and #4
    lsr A
    lsr A
    sta tmp_byte
    lda tile_update_y
    and #3 // names repeat past the fold
    adc #88 // left start

    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte

    sta tile_stage_addr+0, Y
    lda tmp_byte
    sta tile_stage_addr+1, Y

    ldx tile_update_buf_saved
    set_tile_stage_clear()

    // 7. red left arrow from right
    ldx tile_update_playfield_offset
    lda playfield_red_flags2, X
    and #pf_flag2.ar_left
    beq update_tile_left_edge_8

    ldx tile_update_buf_saved
    set_tile_stage_red(Tile_ArrowLeft)

    // skip corresponding fringe
    jmp update_tile_left_edge_done

update_tile_left_edge_8:
    // 8. red fringe from right
    //ldx tile_update_playfield_offset
    lda playfield_red_cmd, X
    beq update_tile_left_edge_done

    ldx tile_update_buf_saved
    set_tile_stage_red(Tile_FringeRight)

update_tile_left_edge_done:
    finalize_tile_stage()
}

// A: precomputed offset of the adjacent main cell
// X: x coord of both
function update_tile_top_edge()
{
    stx tile_update_x
    sta tile_update_playfield_offset

    find_free_tile_stage()
    sta tile_update_buf_saved

    // top limit fringe can only be in name table 0
    lda tile_update_x
    clc
    adc #78 // top start
    ldx #0
    stx tmp_byte

    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte

    sta tile_stage_addr+0, Y
    lda tmp_byte
    sta tile_stage_addr+1, Y

    ldx tile_update_buf_saved
    set_tile_stage_clear()

    // 7. red up arrow from below
    ldx tile_update_playfield_offset
    lda playfield_red_flags2, X
    and #pf_flag2.ar_up
    beq update_tile_top_edge_8

    ldx tile_update_buf_saved
    set_tile_stage_red(Tile_ArrowUp)

    // skip corresponding fringe
    jmp update_tile_top_edge_done

update_tile_top_edge_8:
    // 8. red fringe from below
    //ldx tile_update_playfield_offset
    lda playfield_red_cmd, X
    beq update_tile_top_edge_done

    ldx tile_update_buf_saved
    overlay_tile_stage_red_hline(Line_FringeTopBot, 7)

update_tile_top_edge_done:
    finalize_tile_stage()
}


// A: precomputed offset of the adjacent main cell
// Y: y coord of both
function update_tile_right_edge()
{
    sta tile_update_y
    sta tile_update_playfield_offset

    find_free_tile_stage()
    sta tile_update_buf_saved

    lda tile_update_y
    and #4
    lsr A
    lsr A
    sta tmp_byte
    lda tile_update_y
    and #3 // names repeat past the fold
    adc #92 // right start

    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte

    sta tile_stage_addr+0, Y
    lda tmp_byte
    sta tile_stage_addr+1, Y

    ldx tile_update_buf_saved
    set_tile_stage_clear()

    // 2. blue right arrow from left
    ldx tile_update_playfield_offset
    lda playfield_blue_flags2, X
    and #pf_flag2.ar_right
    beq update_tile_right_edge_3

    ldx tile_update_buf_saved
    set_tile_stage_blue(Tile_ArrowRight)

    // skip corresponding fringe
    jmp update_tile_right_edge_done

update_tile_right_edge_3:
    // 3. blue fringe from left
    //ldx tile_update_playfield_offset
    lda playfield_blue_cmd, X
    beq update_tile_right_edge_done

    ldx tile_update_buf_saved
    set_tile_stage_blue(Tile_FringeLeft)

update_tile_right_edge_done:
    finalize_tile_stage()
}

// A: precomputed offset of the adjacent main cell
// X: x coord of both
function update_tile_bottom_edge()
{
    stx tile_update_x
    sta tile_update_playfield_offset

    find_free_tile_stage()
    sta tile_update_buf_saved

    // bottom limit fringe can only be in name table 1
    lda tile_update_x
    clc
    adc #78 // top start
    ldx #1
    stx tmp_byte

    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte
    asl A
    rol tmp_byte

    sta tile_stage_addr+0, Y
    lda tmp_byte
    sta tile_stage_addr+1, Y

    ldx tile_update_buf_saved
    set_tile_stage_clear()

    // 2. blue down arrow from above
    ldx tile_update_playfield_offset
    lda playfield_blue_flags2, X
    and #pf_flag2.ar_down
    beq update_tile_bottom_edge_3

    ldx tile_update_buf_saved
    set_tile_stage_blue(Tile_ArrowDown)

    // skip corresponding fringe
    jmp update_tile_bottom_edge_done

update_tile_bottom_edge_3:
    // 3. blue fringe from above
    //ldx tile_update_playfield_offset
    lda playfield_blue_cmd, X
    beq update_tile_bottom_edge_done

    ldx tile_update_buf_saved
    overlay_tile_stage_blue_hline(Line_FringeTopBot, 0)

update_tile_bottom_edge_done:
    finalize_tile_stage()
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

    //lda #pf_flag1.cf_left
    //sta playfield_blue_flags1[2*8+2]
    //lda #pf_flag1.cf_top|pf_flag1.cf_bot|pf_flag1.redir_right
    //sta playfield_red_flags1[2*8+2]
}

/******************************************************************************/

function render_paths()
{
    lda red_start_y
    sta render_path_stack+1
    lda red_start_x
    sta render_path_stack+0
    lda red_start_dir
    sta render_path_stack+2

    lda #3
    sta render_path_stack_pointer

    jmp path_reader_do_stack

path_render_continue:

    // generate the new directions based on what's currently on top of the stack
    // A should be flags1 of that cell

    sta tmp_byte
    and #pf_flags.redir_any
    beq path_reader_continue

    ldx render_path_stack_pointer
    lda render_path_stack+2, X


path_reader_do_stack:
    // process the top of the stack

    ldy render_path_stack_pointer
    beq render_paths_done
    dey
    dey
    dey
    sty render_path_stack_pointer

    lda render_path_stack+2, Y
    and #0x1E
    tax
    lda render_path_jump_table+1, X
    pha 
    lda render_path_jump_table+0, X
    pha

    // compute offset
    lda render_path_stack+0, Y
    asl A
    asl A
    asl A
    // carry clear
    adc render_path_stack+1, Y
    tax
    lda render_path_stack+2, Y
    and #rp_flags.set_mode
    tay

render_paths_done:
    // rts here both returns from render paths and does the jump table jump
}

// X has playfield offset, Y has "set" flag
function noreturn path_red_left()
{
    // going left, check for different comefrom right
    lda playfield_red_flags1, X
    cpy #rp_flags.set_mode
    if (equal)
    {
        // different would be 0
        eor #pf_flags1.cf_right
    }
    and #pf_flags1.cf_right
    beq path_reader_do_stack // don't bother following up on this

    txa
    pha

    // skip tile 0 if there is a command
    ldy playfield_red_cmd, X
    bne path_red_left_skip_0

    path_stack_tile0()

path_red_left_skip_0:

    pla
    pha

    // we're coming from the right, so possibly a new tile1
    path_stack_tile1()

    // if redir down there's possibly a new tile2
    pla
    pha

    tax
    lda playfield_red_flags1, X
    and #pf_flag1.redir_down
    beq path_red_left_skip_2

    txa
    path_stack_tile2()

path_red_left_skip_2:

    // make our mark
    pla
    tax
    ldy render_path_stack_pointer
    lda render_path_stack+2, Y
    tay

    lda playfield_red_flags1, X

    cpy #rp_flags.set_mode
    if (equal)
    {
        ora #pf_flags.cf_right
    }
    else
    {
        and #~pf_flags.cf_right
    }
    sta playfield_red_flags1, X

    jmp path_render_continue
}

// A already has playfield offset
function path_stack_tile0()
{
    ldx render_path_stack_pointer
    ldy render_path_stack+0, X
    sty tmp_byte
    ldy render_path_stack+1, X
    tax
    lda playfield_red_flags1, X
    ldx tmp_byte
    update_tile0_lines()
}

function path_stack_tile3()
{
    ldx render_path_stack_pointer
    ldy render_path_stack+0, X
    sty tmp_byte
    ldy render_path_stack+1, X
    tax
    lda playfield_blue_flags1, X
    ldx tmp_byte
    update_tile0_lines()
}

function path_stack_tile1()
{
    ldx render_path_stack_pointer
    ldy render_path_stack+0, X
    sty tmp_byte
    ldy render_path_stack+1, X
    ldx tmp_byte
    update_tile1()
}

function path_stack_tile2()
{
    ldx render_path_stack_pointer
    ldy render_path_stack+0, X
    sty tmp_byte
    ldy render_path_stack+1, X
    ldx tmp_byte
    update_tile2()
}

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
    write_tile_red_bg(Tile_CmdAlpha)

    vram_set_address_i(PATTERN_TABLE_0_ADDRESS+(16*96))
    init_tile_red(Tile_ArrowLeft)
    write_tile_buf()

    // Setup pattern table 1

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS)
    // 0: empty bg tile
    write_tile_blue_bg(Tile_CmdAlpha)

    vram_set_address_i(PATTERN_TABLE_1_ADDRESS+(16*96))
    init_tile_blue(Tile_ArrowRight)
    write_tile_buf()
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
        lda #0
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
    lda #0
    do {
        sta PPU.IO
        sty PPU.IO
        iny
        dex
    } while (not zero)
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

    sta tile_stage_addr, Y
    ldx tmp_byte
    stx tile_stage_addr+1, Y
}

function init_cursor_sprites()
{
    // set the fixed parts of the cursor
    find_free_tile_stage()

    // pattern 3, top right and bottom left
    ldx #16*3
    stx tile_stage_addr+0, Y
    ldx #0
    stx tile_stage_addr+1, Y

    tax
    set_tile_stage_white(Tile_Cursor_TopRight_BotLeft)
    finalize_tile_stage()
}

function update_cursor_sprites()
{
    // pattern 2, top left
    find_free_tile_stage()

    ldx #16*2
    stx tile_stage_addr+0, Y
    ldx #0
    stx tile_stage_addr+1, Y

    tax
    pha
    set_tile_stage_white(Tile_Cursor_TopLeft)
    pla
    tax

    lda #1
    bit current_color
    if (zero)
    {
        lda current_command_tile+0
        sta tmp_addr+0
        lda current_command_tile+1
        sta tmp_addr+1
        overlay_tile_stage_red_ind()
    }
    finalize_tile_stage()

    // pattern 3, bottom right
    find_free_tile_stage()

    ldx #16*4
    stx tile_stage_addr+0, Y
    ldx #0
    stx tile_stage_addr+1, Y

    pha
    tax
    set_tile_stage_white(Tile_Cursor_BotRight)
    pla
    tax

    lda #1
    bit current_color
    if (not zero)
    {
        lda current_command_tile+0
        sta tmp_addr+0
        lda current_command_tile+1
        sta tmp_addr+1
        overlay_tile_stage_blue_ind()
    }
    finalize_tile_stage()

    flush_tile_stage()
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

pointer render_path_jump_table[8] = {
    path_blue_left-1,
    path_blue_right-1,
    path_blue_up-1,
    path_blue_down-1,
    path_red_left-1,
    path_red_right-1,
    path_red_up-1,
    path_red_down-1}

byte bg_palette[4] = {
                0x20, // 11: white
                0x12, // 10: blue
                0x16, // 01: red
                0x10} // 00: gray (bg)

#include "tiles.as"
