
function init_tile_stage()
{
    ldx #sizeof(tile_stage_addr)-2
    // start with full buffer
    stx next_stage_index
    // nmi doesn't need to do anything yet (nonzero)
    stx tile_stage_written
}

function find_free_tile_stage()
{
    ldx next_stage_index

    if (minus) {
        // next index is negative, need to wait for nmi to process buffer
        do {
            ldx tile_stage_written
        } while (zero)

        ldx #sizeof(tile_stage_addr)-2
    }

    txa
    tay // save free entry's address offset

    // decrement for next time
    dex
    dex
    stx next_stage_index

    tax

    inx // move to next index
    inx

    // X is the free entry's address offset, convert to staging buffer offset
    txa
    asl A
    asl A
    asl A
    tax
    dex // move back to penultimate byte
    tya
}

inline write_1_tile_stage(index)
{
    // 126 cycles
    ldx tile_stage_addr[index]              // 3
    lda tile_stage_addr[index]+1            // 3

    sta PPU.ADDRESS                         // 4
    stx PPU.ADDRESS                         // 4

    lda tile_stage[index].tile_buf_0[7]     // 3
    sta PPU.IO                              // 4
    lda tile_stage[index].tile_buf_0[6]
    sta PPU.IO
    lda tile_stage[index].tile_buf_0[5]
    sta PPU.IO
    lda tile_stage[index].tile_buf_0[4]
    sta PPU.IO
    lda tile_stage[index].tile_buf_0[3]
    sta PPU.IO
    lda tile_stage[index].tile_buf_0[2]
    sta PPU.IO
    lda tile_stage[index].tile_buf_0[1]
    sta PPU.IO
    lda tile_stage[index].tile_buf_0[0]
    sta PPU.IO

    lda tile_stage[index].tile_buf_1[7]
    sta PPU.IO
    lda tile_stage[index].tile_buf_1[6]
    sta PPU.IO
    lda tile_stage[index].tile_buf_1[5]
    sta PPU.IO
    lda tile_stage[index].tile_buf_1[4]
    sta PPU.IO
    lda tile_stage[index].tile_buf_1[3]
    sta PPU.IO
    lda tile_stage[index].tile_buf_1[2]
    sta PPU.IO
    lda tile_stage[index].tile_buf_1[1]
    sta PPU.IO
    lda tile_stage[index].tile_buf_1[0]
    sta PPU.IO
}

function write_tile_stages()
{
    ppu_clean_latch()

    lda tile_stage_written
    beq do_write_tile_stages
    // 2 + 2 + 202*2 + 201*3 + 2 + 3 = 1016 cycles

    lda #202            // 2
    tax                 // 2

    do {
        dex             // 2*202
    } while (not zero)  // 3*201 + 2

    jmp skip_tile_stages// 3

do_write_tile_stages:
    // 3 + 126*8 + 2 + 3 = 1016 cycles
    write_1_tile_stage(7)
    write_1_tile_stage(6)
    write_1_tile_stage(5)
    write_1_tile_stage(4)
    write_1_tile_stage(3)
    write_1_tile_stage(2)
    write_1_tile_stage(1)
    write_1_tile_stage(0)

    lda #1  // 2
    sta tile_stage_written  // 3

skip_tile_stages:

    vram_clear_address()
}

function finalize_tile_stage()
{
    lda next_stage_index
    if (minus) {
        ldx #0
        stx tile_stage_written // nmi needs to write
    }
}

// must be called after finalize_tile_stage
function flush_tile_stage()
{
    // if next_stage_index is minus, buffer is full, and was just sent
    ldx next_stage_index
    if (not minus)
    {
        // otherwise, it has at least one entry, fill the rest
        // with writes to pattern 1
        lda #0  // junk pattern 1
        ldy #16 // junk pattern 1
        do {
            sty tile_stage_addr, X
            sta tile_stage_addr+1, X
            dex
            dex
        } while (not minus)

        // and pass off control to the nmi
        sta tile_stage_written // nmi needs to write
    }
}

/******************************************************************************/

// X holds offset
inline init_tile_stage_red(tile_addr)
{
    txa
    pha

    ldy #8-1
    do {
        lda tile_addr, Y
        sta tile_stage, X
        lda #0
        sta tile_stage-8, X
        dex
        dey
    } while (not minus)

    pla
    tax
}

/******************************************************************************/

inline init_tile_red(tile_addr)
{
    ldx #8-1
    ldy #0
    do {
        lda tile_addr, X
        sta tile_buf_0, X
        sty tile_buf_1, X
        dex
    } while (not minus)
}

inline init_tile_blue(tile_addr)
{
    ldx #8-1
    ldy #0
    do {
        lda tile_addr, X
        sty tile_buf_0, X
        sta tile_buf_1, X
        dex
    } while (not minus)
}

inline init_tile_white(tile_addr)
{
    ldx #8-1
    do {
        lda tile_addr, X
        sta tile_buf_0, X
        sta tile_buf_1, X
        dex
    } while (not minus)
}

inline overlay_tile_red(tile_addr)
{
    ldx #8-1
    do {
        lda tile_addr, X
        tay
        ora tile_buf_0, X
        sta tile_buf_0, X
        tya
        eor #0xFF
        and tile_buf_1, X
        sta tile_buf_1, X
        dex
    } while (not minus)
}

inline add_tile_blue(tile_addr)
{
    ldx #8-1
    do {
        lda tile_addr, X
        ora tile_buf_1, X
        sta tile_buf_1, X
        dex
    } while (not minus)
}

inline overlay_tile_white(tile_addr)
{
    ldx #8-1
    do {
        lda tile_addr, X
        tay
        ora tile_buf_0, X
        sta tile_buf_0, X
        tya
        ora tile_buf_1, X
        sta tile_buf_1, X
        dex
    } while (not minus)
}

inline write_tile_white(tile_addr)
{
    ldy #1
    do {
        ldx #8-1
        do {
            lda tile_addr, X
            sta PPU.IO
            dex
        } while (not minus)
        dey
    } while (not minus)
}

inline write_tile_red_bg(tile_addr)
{
    ldx #8-1
    lda #0xFF
    do {
        sta PPU.IO
        dex
    } while (not minus)
    ldx #8-1
    do {
        lda tile_addr, X
        sta PPU.IO
        dex
    } while (not minus)
}

inline write_tile_blue_bg(tile_addr)
{
    ldx #8-1
    do {
        lda tile_addr, X
        sta PPU.IO
        dex
    } while (not minus)
    ldx #8-1
    lda #0xFF
    do {
        sta PPU.IO
        dex
    } while (not minus)
}


function write_tile_buf()
{
    // tile_buf_1 comes before tile_buf_0 in mem
    ldx #16-1
    do {
        lda tile_buf_1, X
        sta PPU.IO
        dex
    } while (not minus)
}

// 8 byte tiles, monochrome, reverse rows

MonoTiles:
byte Tile_Clear[8] = {0,0,0,0,0,0,0,0}

Tile_ArrowDown:
#incbin "arrowdown.imgbin"

Tile_ArrowLeft:
#incbin "arrowleft.imgbin"

Tile_ArrowRight:
#incbin "arrowright.imgbin"

Tile_ArrowUp:
#incbin "arrowup.imgbin"

Tile_FringeBot:
#incbin "fringebot.imgbin"

Tile_FringeLeft:
#incbin "fringeleft.imgbin"

Tile_FringeRight:
#incbin "fringeright.imgbin"

Tile_FringeTop:
#incbin "fringetop.imgbin"

Tile_LineBotLeft:
#incbin "linebotleft.imgbin"

Tile_LineBotRight:
#incbin "linebotright.imgbin"

Tile_HLine:
#incbin "lineh.imgbin"

Tile_LineTopLeft:
#incbin "linetopleft.imgbin"

Tile_LineTopRight:
#incbin "linetopright.imgbin"

Tile_VLine:
#incbin "linev.imgbin"

Tile_Cmds:
struct Tile_Cmds_s
{
#incbin "cmd_alpha.imgbin"  // 1
#incbin "cmd_beta.imgbin"   // 2
#incbin "cmd_bondadd.imgbin"// 3
#incbin "cmd_bondsub.imgbin"// 4
#incbin "cmd_d.imgbin"      // 5
#incbin "cmd_ff.imgbin"     // 6
#incbin "cmd_gd.imgbin"     // 7
#incbin "cmd_g.imgbin"      // 8
#incbin "cmd_omega.imgbin"  // 9
#incbin "cmd_psi.imgbin"    // 10
#incbin "cmd_start.imgbin"  // 11
}

Tile_Elements:
struct Tile_Elements_s
{
#incbin "element_H.imgbin"  // 1
#incbin "element_He.imgbin" // 2
#incbin "element_Li.imgbin" // 3
#incbin "element_Be.imgbin" // 4
#incbin "element_B.imgbin"  // 5
#incbin "element_C.imgbin"  // 6
#incbin "element_N.imgbin"  // 7
#incbin "element_O.imgbin"  // 8
#incbin "element_F.imgbin"  // 9
#incbin "element_Ne.imgbin" // 10
}
