
function noreturn compute_blue_path()
{
    lda blue_start_x
    sta render_x
    lda blue_start_y
    sta render_y

    lda render_x
    asl A
    asl A
    asl A
    adc render_y
    tax

    ldy blue_start_dir
    sty render_dir

blue_redirect:
    txa
    // TODO: this should be a jump table
    // TODO: handle recursion for split paths
    cpy #pf_flag2.redir_left
    beq blue_left
    cpy #pf_flag2.redir_right
    beq blue_right
    cpy #pf_flag2.redir_up
    beq blue_up
    bne blue_down

    // one of others will return on their own
}

function blue_left()
{
    forever {
        // go left
        sec
        sbc #8

        ldx render_x
        dex
        stx render_x
        if (minus)
        {
            return // hit edge
        }

        // we come from the right!
        // TODO: this will be a good place to check for loops
        tax
        lda playfield_blue_disp, X
        ora #pf_flag1.cf_right
        sta playfield_blue_disp, X

        // redirected?
        lda playfield_blue_disp2, X
        and #pf_flag2.redir_right|pf_flag2.redir_up|pf_flag2.redir_down
        bne blue_redirect
    }
}

function blue_right()
{
    forever {
        // go right
        clc
        adc #8

        ldx render_x
        inx
        stx render_x
        cmp #10
        if (equal)
        {
            return // hit edge
        }

        // we come from the left!
        // TODO: this will be a good place to check for loops
        tax
        lda playfield_blue_disp, X
        ora #pf_flag1.cf_left
        sta playfield_blue_disp, X

        // redirected?
        lda playfield_blue_dir, X
        and #pf_flag2.redir_left|pf_flag2.redir_up|pf_flag2.redir_down
        bne blue_redirect
    }
}

function blue_down()
{
    forever {
        // go down
        clc
        adc #1

        ldx render_y
        dex
        stx render_y
        cmp #8
        if (equal)
        {
            return // hit edge
        }

        // we come from above!
        // TODO: this will be a good place to check for loops
        tax
        lda playfield_blue_disp, X
        ora #pf_flag1.cf_top
        sta playfield_blue_disp, X

        // redirected?
        lda playfield_blue_dir, X
        and #pf_flag2.redir_left|pf_flag2.redir_right|pf_flag2.redir_up
        bne blue_redirect
    }
}

function blue_up()
{
    forever {
        // go up
        sec
        sbc #1

        ldx render_y
        dex
        stx render_y
        if (minus)
        {
            return // hit edge
        }

        // we come from below!
        // TODO: this will be a good place to check for loops
        tax
        lda playfield_blue_disp, X
        ora #pf_flag1.cf_bot
        sta playfield_blue_disp, X

        // redirected?
        lda playfield_blue_dir, X
        and #pf_flag2.redir_left|pf_flag2.redir_right|pf_flag2.redir_down
        bne blue_redirect
    }
}

function render_blue()
{
    lda #0
    ldy #10

    do {
        lda #8
        do {
            pha

            pla
        } while (not zero)
        dey
    } while (not zero)

}

/*
function fixed_tiles()
{

    // 1-12: red commands

    ldx #sizeof(Tile_Cmds)/8
    lda #lo(Tile_Cmds)
    sta tmp_ind
    lda #hi(Tile_Cmds)
    sta tmp_ind+1
    //write_red_bg_set()

    // 13-24: blue commands
    ldx #sizeof(Tile_Cmds)/8
    lda #lo(Tile_Cmds)
    sta tmp_ind
    lda #hi(Tile_Cmds)
    sta tmp_ind+1
    //write_blue_bg_set()
}
*/

/*
// uses tmp_ind as source, X as count
function write_blue_bg_set()
{
    do {
        ldy #8-1
        do {
            lda (tmp_ind), Y
            sta PPU.IO
            dey
        } while (not minus)

        ldy #8-1
        lda #0xFF
        do {
            sta PPU.IO
            dey
        } while (not minus)

        lda #8
        clc
        adc tmp_ind
        sta tmp_ind
        lda #0
        adc tmp_ind+1
        sta tmp_ind+1

        dex
    } while (not zero)
}
*/
/*
// uses tmp_ind as source, X as count
function write_red_bg_set()
{
    do {
        ldy #8-1
        lda #0xFF
        do {
            sta PPU.IO
            dey
        } while (not minus)

        ldy #8-1
        do {
            lda (tmp_ind), Y
            sta PPU.IO
            dey
        } while (not minus)

        lda #8
        clc
        adc tmp_ind
        sta tmp_ind
        lda #0
        adc tmp_ind+1
        sta tmp_ind+1

        dex
    } while (not zero)
}
*/

