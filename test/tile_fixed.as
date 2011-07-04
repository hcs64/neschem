
/******************************************************************************/

inline init_tile_red(tile_addr)
{
    ldx #8-1
    do {
        lda #0
        sta tile_buf_1, X
        lda tile_addr, X
        sta tile_buf_0, X
        dex
    } while (not minus)
}

inline init_tile_blue(tile_addr)
{
    ldx #8-1
    do {
        lda #0
        sta tile_buf_0, X
        lda tile_addr, X
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

