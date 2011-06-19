
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

function write_tile()
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

Tile_ArrowDown:
#incbin "arrowdown.imgbin"

Tile_ArrowUp:
#incbin "arrowup.imgbin"

Tile_ElementHe:
#incbin "element_He.imgbin"
