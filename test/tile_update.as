
function TU_setup0()
{
    txa
    asl A // *2
    pha

    tya
    asl A // *2
    pha

    TS_find_free()
    sta TU_buf_saved

    pla
    tax
    pla

    pos_to_nametable()
}

// needs TU_playfield_flags1, TU_playfield_flags2
// X: x coord
// Y: y coord
function TU_lines0()
{
    TU_setup0()

    ldx TU_buf_saved
    TS_clear_mono()

    TU_lines03()
    ldx TU_buf_saved
    ldy #(Tile_Grid0-Tile_BG)+7
    TS_mix_bg_mono_to_red()
    TS_finalize()
}

// X: x coord
// Y: y coord
function TU_command0()
{
    TU_setup0()

    lda current_command_tile+0
    sta tmp_addr+0
    lda current_command_tile+1
    sta tmp_addr+1

    ldx TU_buf_saved
    TS_clear()  // TODO: need an "init"
    ldx TU_buf_saved
    TS_set_ind_inv_red(tmp_addr)
    TS_finalize()
}

function TU_setup3()
{
    txa
    sec
    rol A // *2+1
    pha

    tya
    sec
    rol A // *2+1
    pha

    TS_find_free()
    sta TU_buf_saved

    pla
    tax
    pla

    pos_to_nametable()
}

// needs TU_playfield_flags1, TU_playfield_flags2
// X: x coord
// Y: y coord
function TU_lines3()
{
    TU_setup3()

    lda TU_buf_saved
    // adjust +8 for mono
    clc
    adc #8
    sta TU_buf_saved
    tax
    TS_clear_mono()

    TU_lines03()
    ldx TU_buf_saved
    ldy #(Tile_Grid3-Tile_BG)+7
    TS_mix_bg_mono_to_blue()
    TS_finalize()
}

// X: x coord
// Y: y coord
function TU_command3()
{
    TU_setup3()

    lda current_command_tile+0
    sta tmp_addr+0
    lda current_command_tile+1
    sta tmp_addr+1

    ldx TU_buf_saved
    TS_clear()  // TODO: need an "init"
    ldx TU_buf_saved
    TS_set_ind_inv_blue(tmp_addr)
    TS_finalize()
}

function TU_lines03()
{
    // a few common line cases
    ldx TU_buf_saved
    lda TU_playfield_flags2
    // only bits in flags2 are arrows
    bne tile03_lines_has_arrow

    // no arrow, could be straight through
    lda TU_playfield_flags1
    and #pf_flag1.cf_left|pf_flag1.cf_right
    beq tile03_no_straight_h
    TS_set_mid_hline_mono() // preserves X
tile03_no_straight_h:

    lda TU_playfield_flags1
    and #pf_flag1.cf_top|pf_flag1.cf_bot
    beq tile03_no_straight_v
    TS_set_mid_vline_mono()
tile03_no_straight_v:

tile03_lines_has_arrow:
    lda TU_playfield_flags1
    // redir is in high bits
    cmp #0x10
    // skip any other processing if we have no redir to make curves
    bpl tile03_some_redirs
    jmp tile03_lines_done   // TODO: try to avoid this trampoline

tile03_some_redirs:

    // ... there are some redirs
    eor #0xFF   // reverse bits in order to check which are *set* with beq

    bit cf_left_redir_right
    beq tile03_pushed_h

    bit cf_right_redir_left
    bne tile03_no_pushed_h

tile03_pushed_h:
    TS_set_mid_hline_mono() // preserves X and A

tile03_no_pushed_h:
    bit cf_top_redir_down
    beq tile03_pushed_v

    bit cf_bot_redir_up
    bne tile03_no_pushed_v

tile03_pushed_v:
    TS_set_mid_vline_mono()

tile03_no_pushed_v:

    lda TU_playfield_flags1
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
        ldx TU_buf_saved
        TS_set_mono(Tile_LoopDown)
    }
    asl tmp_byte
    if (carry)
    {
        ldx TU_buf_saved
        TS_set_mono(Tile_LoopUp)
    }
    asl tmp_byte
    if (carry)
    {
        ldx TU_buf_saved
        TS_set_mono(Tile_LoopRight)
    }
    lda tmp_byte
    if (minus)
    {
        ldx TU_buf_saved
        TS_set_mono(Tile_LoopLeft)
    }

tile03_no_loops:
    
    lda TU_playfield_flags1
    eor #0xFF
    sta TU_playfield_flags1
    lda #8-1
    sta tmp_byte
    do {
        ldx tmp_byte
        lda corner_masks, X
        and TU_playfield_flags1
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

        ldx TU_buf_saved
        TS_set_ind_mono(tmp_addr)

tile03_skip_corner:
        dec tmp_byte
    } while (not minus)
tile03_lines_done:
}

// A: precomputed cell table offset
// X: x coord
// Y: y coord
function TU_1()
{
    sta TU_playfield_offset
    stx TU_x
    sty TU_y

    TS_find_free()
    sta TU_buf_saved

    lda TU_y
    asl A   // *2
    tax

    lda TU_x
    sec
    rol A   // *2+1

    pos_to_nametable()

    ldx TU_buf_saved
    TS_clear()

    // 1. vertical blue line
    // blue comefrom above OR (any comefrom AND redir up) OR (comefrom below AND no arrows but maybe up)
    ldy TU_playfield_offset
    ldx playfield_blue_flags1, Y
    txa
    and #pf_flag1.cf_any
    beq skip_vertical_blue_line // no comefrom
    and #pf_flag1.cf_top
    bne do_vertical_blue_line   // comefrom top
    txa
    and #pf_flag1.redir_up
    bne do_vertical_blue_line   // redir up
    txa
    and #pf_flag1.cf_bot
    beq skip_vertical_blue_line // no comefrom below
    lda playfield_blue_flags2, Y
    bne skip_vertical_blue_line // some arrow (up arrow handled by redir up above)

do_vertical_blue_line:
    ldx TU_buf_saved
    TS_set_mid_vline_blue()

skip_vertical_blue_line:

    // 2. blue down arrow from above
    // check Y limit
    ldx TU_y
    lda cursor_y_limit_lookup, X
    bmi update_tile1_4  // low Y limit, skip looking up

    ldx TU_playfield_offset
    lda playfield_blue_flags2-1, X  // above
    and #pf_flag2.ar_down
    beq update_tile1_3

    ldx TU_buf_saved
    TS_set_blue(Tile_ArrowDown)

    // skip corresponding fringe
    jmp update_tile1_4

update_tile1_3:
    // 3. blue fringe from above
    //ldx TU_playfield_offset
    lda playfield_blue_cmd-1, X // above
    beq update_tile1_4

    ldx TU_buf_saved
    TS_set_blue(Tile_FringeTop) // TODO: one line, can be cheaper

update_tile1_4:
    // 4. blue up arrow from current
    ldx TU_playfield_offset
    lda playfield_blue_flags2, X
    and #pf_flag2.ar_up
    beq update_tile1_5

    ldx TU_buf_saved
    TS_set_blue(Tile_ArrowDown)

    // skip corresponding fringe
    jmp update_tile1_6

update_tile1_5:
    // 5. blue bottom fringe from current
    //ldx TU_playfield_offset
    lda playfield_blue_cmd, X
    beq update_tile1_6

    ldx TU_buf_saved
    TS_set_blue(Tile_FringeBot) // TODO: one line, can be cheaper

update_tile1_6:
    // 6. horizontal red line
    // red comefrom right OR (any comefrom and redir right) OR (comefrom left AND no arrows but maybe right)
    ldy TU_playfield_offset

    ldx playfield_red_flags1, Y
    txa
    and #pf_flag1.cf_any
    beq skip_update_tile1_6     // no comefrom
    and #pf_flag1.cf_right
    bne do_update_tile1_6       // comefrom right
    txa
    and #pf_flag1.redir_right
    bne do_update_tile1_6       // redir right
    txa
    and #pf_flag1.redir_left
    beq skip_update_tile1_6     // no comefrom left
    lda playfield_red_flags2, Y
    bne skip_update_tile1_6     // some arrow (right handled by redir right above)

do_update_tile1_6:
    ldx TU_buf_saved
    TS_set_mid_hline_red()

skip_update_tile1_6:
update_tile1_7:
    // 7. red left arrow from right
    // check X limit
    ldx TU_x
    lda cursor_x_limit_lookup, X
    beq update_tile1_look_right // no limit, look right
    bpl update_tile1_9      // high X limit, skip looking right

update_tile1_look_right:
    ldx TU_playfield_offset
    lda playfield_red_flags2+PLAYFIELD_HEIGHT, X    // right
    and #pf_flag2.ar_left
    beq update_tile1_8

    ldx TU_buf_saved
    TS_set_red(Tile_ArrowLeft)

    // skip corresponding fringe
    jmp update_tile1_9

update_tile1_8:
    // 8. red fringe from right
    //ldx TU_playfield_offset
    lda playfield_red_cmd+PLAYFIELD_HEIGHT, X   // right
    beq update_tile1_9

    ldx TU_buf_saved
    TS_set_red(Tile_FringeRight)    // TODO: can probably be cheaper (INC?)

update_tile1_9:
    // 9. red right arrow from current
    ldx TU_playfield_offset
    lda playfield_red_flags2, X
    and #pf_flag2.ar_right
    beq update_tile1_10

    ldx TU_buf_saved
    TS_set_red(Tile_ArrowRight)

    // skip corresponding fringe
    jmp update_tile1_done

update_tile1_10:
    // 10. red right fringe from current
    //ldx TU_playfield_offset
    lda playfield_red_cmd, X
    beq update_tile1_done

    ldx TU_buf_saved
    TS_set_red(Tile_FringeLeft) // TODO: can probably be cheaper

update_tile1_done:
    ldx TU_buf_saved
    ldy #(Tile_Grid1-Tile_BG)+7
    TS_mix_down_bg()
    TS_finalize()
}

// A: precomputed cell table offset
// X: x coord
// Y: y coord
function TU_2()
{
    sta TU_playfield_offset
    stx TU_x
    sty TU_y

    TS_find_free()
    sta TU_buf_saved

    lda TU_y
    sec
    rol A   // *2+1
    tax

    lda TU_x
    asl A   // *2

    pos_to_nametable()

    ldx TU_buf_saved
    TS_clear()


    // 1. horizontal blue line
    // blue comefrom left OR (any comefrom AND redir left) OR (comefrom right AND no arrows but maybe left)
    ldy TU_playfield_offset
    ldx playfield_blue_flags1, Y
    txa
    and #pf_flag1.cf_any
    beq skip_horizontal_blue_line   // no comefrom
    txa
    and #pf_flag1.cf_left
    bne do_horizontal_blue_line     // comefrom left
    txa
    and #pf_flag1.redir_left
    bne do_horizontal_blue_line     // redir left
    txa
    and #pf_flag1.cf_right
    beq skip_horizontal_blue_line   // no comefrom right
    lda playfield_blue_flags2, Y
    bne skip_horizontal_blue_line   // some arrow (left handled by redir left above)

do_horizontal_blue_line:
    ldx TU_buf_saved
    TS_set_mid_hline_blue()

skip_horizontal_blue_line:

    // 2. blue right arrow from left
    // check X limit
    ldx TU_x
    lda cursor_x_limit_lookup, X
    bmi update_tile2_4  // low X limit, skip looking left

    ldx TU_playfield_offset
    lda playfield_blue_flags2-PLAYFIELD_HEIGHT, X   // left
    and #pf_flag2.ar_right
    beq update_tile2_3

    ldx TU_buf_saved
    TS_set_blue(Tile_ArrowRight)

    // skip corresponding fringe
    jmp update_tile2_4

update_tile2_3:
    // 3. blue fringe from left
    //ldx TU_playfield_offset
    lda playfield_blue_cmd-PLAYFIELD_HEIGHT, X // left
    beq update_tile2_4

    ldx TU_buf_saved
    TS_set_blue(Tile_FringeLeft)    // TODO: can be cheaper

update_tile2_4:
    // 4. blue left arrow from current
    ldx TU_playfield_offset
    lda playfield_blue_flags2, X
    and #pf_flag2.ar_left
    beq update_tile2_5

    ldx TU_buf_saved
    TS_set_blue(Tile_ArrowLeft)

    // skip corresponding fringe
    jmp update_tile2_6

update_tile2_5:
    // 5. blue right fringe from current
    //ldx TU_playfield_offset
    lda playfield_blue_cmd, X
    beq update_tile2_6

    ldx TU_buf_saved
    TS_set_blue(Tile_FringeRight)   // TODO: can be cheaper

update_tile2_6:
    // 6. vertical red line
    // red comefrom below OR (any comefrom and redir down) OR (comefrom above and no arrows but maybe down)
    ldy TU_playfield_offset

    ldx playfield_red_flags1, Y
    txa
    and #pf_flag1.cf_any
    beq skip_update_tile2_6     // no comefrom
    and #pf_flag1.cf_bot
    bne do_update_tile2_6       // comefrom bottom
    txa
    and #pf_flag1.redir_down
    bne do_update_tile2_6       // redir down
    txa
    and #pf_flag1.cf_top
    beq skip_update_tile2_6     // not comefrom above
    lda playfield_red_flags2, Y
    bne skip_update_tile2_6     // some arrow (down handled by redir down above)

do_update_tile2_6:
    ldx TU_buf_saved
    TS_set_mid_vline_red()

skip_update_tile2_6:
update_tile2_7:
    // 7. red up arrow from below
    // check Y limit
    ldx TU_y
    lda cursor_y_limit_lookup, X
    beq update_tile2_look_down // no limit, look down
    bpl update_tile2_9      // high Y limit, skip looking down

update_tile2_look_down:
    ldx TU_playfield_offset
    lda playfield_red_flags2+1, X   // below
    and #pf_flag2.ar_up
    beq update_tile2_8

    ldx TU_buf_saved
    TS_set_red(Tile_ArrowUp)

    // skip corresponding fringe
    jmp update_tile2_9

update_tile2_8:
    // 8. red fringe from below
    //ldx TU_playfield_offset
    lda playfield_red_cmd+1, X // below
    beq update_tile2_9

    ldx TU_buf_saved
    TS_set_red(Tile_FringeBot)  // TODO: one line, can be cheaper

update_tile2_9:
    // 9. red down arrow from current
    ldx TU_playfield_offset
    lda playfield_red_flags2, X
    and #pf_flag2.ar_down
    beq update_tile2_10

    ldx TU_buf_saved
    TS_set_red(Tile_ArrowDown)

    // skip corresponding fringe
    jmp update_tile2_done

update_tile2_10:
    // 10. red bottom fringe from current
    //ldx TU_playfield_offset
    lda playfield_red_cmd, X
    beq update_tile2_done

    ldx TU_buf_saved
    TS_set_red(Tile_FringeTop)  // TODO: one line, can be cheaper

update_tile2_done:
    ldx TU_buf_saved
    ldy #(Tile_Grid2-Tile_BG)+7
    TS_mix_down_bg()
    TS_finalize()
}

// A: precomputed offset of the adjacent main cell
// Y: y coord of both
function TU_left_edge()
{
    sta TU_playfield_offset
    sty TU_y

    TS_find_free()
    sta TU_buf_saved

    lda TU_y
    and #4
    lsr A
    lsr A
    sta tmp_byte
    lda TU_y
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

    sta TS_addr+0, Y
    lda tmp_byte
    sta TS_addr+1, Y

    ldx TU_buf_saved
    TS_clear_mono()

    // 7. red left arrow from right
    ldx TU_playfield_offset
    lda playfield_red_flags2, X
    and #pf_flag2.ar_left
    beq update_tile_left_edge_8

    ldx TU_buf_saved
    TS_set_mono(Tile_ArrowLeft)

    // skip corresponding fringe
    jmp update_tile_left_edge_done

update_tile_left_edge_8:
    // 8. red fringe from right
    //ldx TU_playfield_offset
    lda playfield_red_cmd, X
    beq update_tile_left_edge_done

    ldx TU_buf_saved
    TS_set_mono(Tile_FringeRight)   // TODO: can be cheaper

update_tile_left_edge_done:
    ldx TU_buf_saved
    ldy #(Tile_Filled-Tile_BG)+7
    TS_mix_bg_mono_to_red()
    TS_finalize()
}

// A: precomputed offset of the adjacent main cell
// X: x coord of both
function TU_top_edge()
{
    stx TU_x
    sta TU_playfield_offset

    TS_find_free()
    sta TU_buf_saved

    // top limit fringe can only be in name table 0
    lda TU_x
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

    sta TS_addr+0, Y
    lda tmp_byte
    sta TS_addr+1, Y

    ldx TU_buf_saved
    TS_clear_mono()

    // 7. red up arrow from below
    ldx TU_playfield_offset
    lda playfield_red_flags2, X
    and #pf_flag2.ar_up
    beq update_tile_top_edge_8

    ldx TU_buf_saved
    TS_set_mono(Tile_ArrowUp)

    // skip corresponding fringe
    jmp update_tile_top_edge_done

update_tile_top_edge_8:
    // 8. red fringe from below
    //ldx TU_playfield_offset
    lda playfield_red_cmd, X
    beq update_tile_top_edge_done

    ldx TU_buf_saved
    TS_set_mono(Tile_FringeBot)  // TODO: can be cheaper

update_tile_top_edge_done:
    ldx TU_buf_saved
    ldy #(Tile_Filled-Tile_BG)+7
    TS_mix_bg_mono_to_red()
    TS_finalize()
}


// A: precomputed offset of the adjacent main cell
// Y: y coord of both
function TU_right_edge()
{
    sta TU_y
    sta TU_playfield_offset

    TS_find_free()
    // adjust +8 for mono
    clc
    adc #8
    sta TU_buf_saved

    lda TU_y
    and #4
    lsr A
    lsr A
    sta tmp_byte
    lda TU_y
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

    sta TS_addr+0, Y
    lda tmp_byte
    sta TS_addr+1, Y

    ldx TU_buf_saved
    TS_clear_mono()

    // 2. blue right arrow from left
    ldx TU_playfield_offset
    lda playfield_blue_flags2, X
    and #pf_flag2.ar_right
    beq update_tile_right_edge_3

    ldx TU_buf_saved
    TS_set_mono(Tile_ArrowRight)

    // skip corresponding fringe
    jmp update_tile_right_edge_done

update_tile_right_edge_3:
    // 3. blue fringe from left
    //ldx TU_playfield_offset
    lda playfield_blue_cmd, X
    beq update_tile_right_edge_done

    ldx TU_buf_saved
    TS_set_mono(Tile_FringeLeft)    // TODO: can be cheaper

update_tile_right_edge_done:
    ldx TU_buf_saved
    ldy #(Tile_Grid_Edge_Right-Tile_BG)+7
    TS_mix_bg_mono_to_blue()
    TS_finalize()
}

// A: precomputed offset of the adjacent main cell
// X: x coord of both
function TU_bottom_edge()
{
    stx TU_x
    sta TU_playfield_offset

    TS_find_free()
    // adjust +8 for mono
    clc
    adc #8
    sta TU_buf_saved

    // bottom limit fringe can only be in name table 1
    lda TU_x
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

    sta TS_addr+0, Y
    lda tmp_byte
    sta TS_addr+1, Y

    ldx TU_buf_saved
    TS_clear_mono()

    // 2. blue down arrow from above
    ldx TU_playfield_offset
    lda playfield_blue_flags2, X
    and #pf_flag2.ar_down
    beq update_tile_bottom_edge_3

    ldx TU_buf_saved
    TS_set_mono(Tile_ArrowDown)

    // skip corresponding fringe
    jmp update_tile_bottom_edge_done

update_tile_bottom_edge_3:
    // 3. blue fringe from above
    //ldx TU_playfield_offset
    lda playfield_blue_cmd, X
    beq update_tile_bottom_edge_done

    ldx TU_buf_saved
    TS_set_mono(Tile_FringeTop) // TODO: one line, can be cheaper

update_tile_bottom_edge_done:
    ldx TU_buf_saved
    ldy #(Tile_Grid_Edge_Bot-Tile_BG)+7
    TS_mix_bg_mono_to_blue()
    TS_finalize()
}
