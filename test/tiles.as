
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

Tile_ArrowDown:
#incbin "arrowdown.imgbin"

Tile_ArrowLeft:
#incbin "arrowright.imgbin"

Tile_ArrowRight:
#incbin "arrowright.imgbin"

Tile_ArrowUp:
#incbin "arrowup.imgbin"

Tile_CmdAlpha:
#incbin "cmd_alpha.imgbin"

Tile_CmdBeta:
#incbin "cmd_beta.imgbin"

Tile_CmdBondAdd:
#incbin "cmd_bondadd.imgbin"

Tile_CmdBomSub:
#incbin "cmd_bondsub.imgbin"

Tile_CmdDrop:
#incbin "cmd_d.imgbin"

Tile_CmdFlipFlop:
#incbin "cmd_ff.imgbin"

Tile_CmdGrabDrop:
#incbin "cmd_gd.imgbin"

Tile_CmdGrab:
#incbin "cmd_g.imgbin"

Tile_CmdOmega:
#incbin "cmd_omega.imgbin"

Tile_CmdPsi:
#incbin "cmd_psi.imgbin"

Tile_CmdStart:
#incbin "cmd_start.imgbin"

Tile_ElementBe:
#incbin "element_Be.imgbin"

Tile_ElementB:
#incbin "element_B.imgbin"

Tile_ElementC:
#incbin "element_C.imgbin"

Tile_ElementF:
#incbin "element_F.imgbin"

Tile_ElementHe:
#incbin "element_He.imgbin"

Tile_ElementH:
#incbin "element_H.imgbin"

Tile_ElementLi:
#incbin "element_Li.imgbin"

Tile_ElementNe:
#incbin "element_Ne.imgbin"

Tile_ElementO:
#incbin "element_O.imgbin"

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
