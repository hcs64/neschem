
#define TS_bit0_offset (TS_buf.bit0 - TS_buf)
#define TS_bit1_offset (TS_buf.bit1 - TS_buf)

function TS_init()
{
    ldx #sizeof(TS_addr)-2
    // start with full buffer
    stx TS_next_index
    // nmi doesn't need to do anything yet (nonzero)
    stx TS_written
}

function TS_find_free()
{
    ldx TS_next_index

    if (minus) {
        // next index is negative, need to wait for nmi to process buffer
        do {
            ldx TS_written
        } while (zero)

        ldx #sizeof(TS_addr)-2
    }

    txa
    tay // save free entry's address offset in Y

    // decrement for next time
    dex
    dex
    stx TS_next_index

    // A is the free entry's address offset, convert to staging buffer offset (end)
    clc
    adc #1 // move halfway to next index

    asl A
    asl A
    asl A
    // carry will be clear
    adc #0xFF // move back to penultimate byte, where writing starts

    // result: A has staging buffer offset, Y has address offset
}

inline TS_write_1(index)
{
    // 126 cycles
    ldx TS_addr[index]                      // 3
    lda TS_addr[index]+1                    // 3

    sta PPU.ADDRESS                         // 4
    stx PPU.ADDRESS                         // 4

    lda TS_buf[index].bit0[7]               // 3
    sta PPU.IO                              // 4
    lda TS_buf[index].bit0[6]
    sta PPU.IO
    lda TS_buf[index].bit0[5]
    sta PPU.IO
    lda TS_buf[index].bit0[4]
    sta PPU.IO
    lda TS_buf[index].bit0[3]
    sta PPU.IO
    lda TS_buf[index].bit0[2]
    sta PPU.IO
    lda TS_buf[index].bit0[1]
    sta PPU.IO
    lda TS_buf[index].bit0[0]
    sta PPU.IO

    lda TS_buf[index].bit1[7]
    sta PPU.IO
    lda TS_buf[index].bit1[6]
    sta PPU.IO
    lda TS_buf[index].bit1[5]
    sta PPU.IO
    lda TS_buf[index].bit1[4]
    sta PPU.IO
    lda TS_buf[index].bit1[3]
    sta PPU.IO
    lda TS_buf[index].bit1[2]
    sta PPU.IO
    lda TS_buf[index].bit1[1]
    sta PPU.IO
    lda TS_buf[index].bit1[0]
    sta PPU.IO
}

function TS_write()
{
    ppu_clean_latch()

    lda TS_written
    beq TS_do_write
    // 2 + 2 + 202*2 + 201*3 + 2 + 3 = 1016 cycles

    lda #202            // 2
    tax                 // 2

    do {
        dex             // 2*202
    } while (not zero)  // 3*201 + 2

    jmp TS_skip_write // 3

TS_do_write:
    // 3 + 126*8 + 2 + 3 = 1016 cycles
    TS_write_1(7)
    TS_write_1(6)
    TS_write_1(5)
    TS_write_1(4)
    TS_write_1(3)
    TS_write_1(2)
    TS_write_1(1)
    TS_write_1(0)

    lda #1  // 2
    sta TS_written  // 3

TS_skip_write:

    vram_clear_address()
}

function TS_finalize()
{
    lda TS_next_index
    if (minus) {
        ldx #0
        stx TS_written // nmi needs to write
    }
}

// must be called after finalize_tile_stage
function TS_flush()
{
    // if TS_next_index is minus, buffer is full, and was just sent
    ldx TS_next_index
    if (not minus)
    {
        // otherwise, it has at least one entry, fill the rest
        // with writes to pattern 1
        lda #0  // junk pattern 1
        ldy #16 // junk pattern 1
        do {
            sty TS_addr+0, X
            sta TS_addr+1, X
            dex
            dex
        } while (not minus)

        // store the now-negative index
        stx TS_next_index

        // and pass off control to the nmi
        sta TS_written // nmi needs to write
    }
}

/******************************************************************************/

inline TS_clear()
{
    ldy #8-1
    lda #0
    do {
        sta TS_buf.bit0, X
        sta TS_buf.bit1, X
        dex
    } while (not minus)
}

inline TS_clear_mono()
{
    ldy #8-1
    lda #0
    do {
        sta TS_buf, X
        dex
    } while (not minus)
}

/******************************************************************************/

inline TS_set_white(tile_addr)
{
    TS_set_bits01(tile_addr)
}

/******************************************************************************/

inline TS_set_mid_hline_blue()
{
    TS_set_mid_hline_bit0()
}

inline TS_set_mid_vline_blue()
{
    TS_set_mid_vline_bit0()
}

inline TS_set_blue(tile_addr)
{
    TS_set_bit0(tile_addr)
}

inline TS_set_ind_blue(tile_ind_addr)
{
    TS_set_ind_bit0(tile_ind_addr)
}

inline TS_set_inv_blue(tile_addr)
{
    TS_set_inv_bit0(tile_addr)
}

inline TS_set_ind_inv_blue(tile_ind_addr)
{
    TS_set_ind_inv_bit0(tile_ind_addr)
}

inline TS_mix_bg_mono_to_blue()
{
    TS_mix_bit0_bg()
}

/******************************************************************************/

inline TS_set_mid_hline_red()
{
    TS_set_mid_hline_bit1()
}

inline TS_set_mid_vline_red()
{
    TS_set_mid_vline_bit1()
}

inline TS_set_red(tile_addr)
{
    TS_set_bit1(tile_addr)
}

inline TS_set_ind_red(tile_ind_addr)
{
    TS_set_ind_bit1(tile_ind_addr)
}

inline TS_set_inv_red(tile_addr)
{
    TS_set_inv_bit1(tile_addr)
}

inline TS_set_ind_inv_red(tile_ind_addr)
{
    TS_set_ind_inv_bit1(tile_ind_addr)
}

inline TS_mix_bg_mono_to_red()
{
    TS_mix_bit1_bg()
}

/******************************************************************************/

inline TS_set_mid_hline_mono()
{
    TS_set_mid_hline_bit1()
}

inline TS_set_mid_vline_mono()
{
    TS_set_mid_vline_bit1()
}

inline TS_set_mono(tile_addr)
{
    TS_set_bit1(tile_addr)
}

inline TS_set_ind_mono(tile_ind_addr)
{
    TS_set_ind_bit1(tile_ind_addr)
}

inline TS_set_inv_mono(tile_addr)
{
    TS_set_inv_bit1(tile_addr)
}

inline TS_set_ind_inv_mono(tile_ind_addr)
{
    TS_set_ind_inv_bit1(tile_ind_addr)
}

/******************************************************************************/

inline TS_set_mid_hline_bit1()
{
    TS_set_mid_hline(TS_bit1_offset)
}

inline TS_set_mid_vline_bit1()
{
    TS_set_mid_vline(TS_bit1_offset)
}

inline TS_set_bit1(tile_addr)
{
    TS_set(tile_addr, TS_bit1_offset)
}

inline TS_set_ind_bit1(tile_addr)
{
    TS_set_ind(tile_addr, TS_bit1_offset)
}

inline TS_set_inv_bit1(tile_addr)
{
    TS_set_inv(tile_addr, TS_bit1_offset)
}

inline TS_set_ind_inv_bit1(tile_addr)
{
    TS_set_ind_inv(tile_addr, TS_bit1_offset)
}

inline TS_mix_bit1_bg()
{
    TS_mix_bg_mono(TS_buf.bit0 - TS_buf.bit1)
}

/******************************************************************************/

inline TS_set_mid_hline_bit0()
{
    TS_set_mid_hline(TS_bit0_offset)
}

inline TS_set_mid_vline_bit0()
{
    TS_set_mid_vline(TS_bit0_offset)
}

inline TS_set_bit0(tile_addr)
{
    TS_set(tile_addr, TS_bit0_offset)
}

inline TS_set_ind_bit0(tile_ind_addr)
{
    TS_set_ind(tile_ind_addr, TS_bit0_offset)
}

inline TS_set_inv_bit0(tile_addr)
{
    TS_set(tile_addr, TS_bit0_offset)
}

inline TS_set_ind_inv_bit0(tile_ind_addr)
{
    TS_set_ind_inv(tile_ind_addr, TS_bit0_offset)
}

inline TS_mix_bit0_bg()
{
    TS_mix_bg_mono(TS_buf.bit1-TS_buf.bit0)
}

/******************************************************************************/

inline TS_set_mid_hline(offset)
{
    ldy #0xFF
    sty TS_buf-3+(offset), X
    sty TS_buf-4+(offset), X
}


inline TS_set_mid_vline(offset)
{
    ldy #8-1
    do {
        lda TS_buf+(offset), X
        ora #0x18
        sta TS_buf+(offset), X
        dex
        dey
    } while (not minus)
}

inline TS_set(tile_addr, offset)
{
    ldy #8-1
    do {
        lda tile_addr, Y
        ora TS_buf+(offset), X
        sta TS_buf+(offset), X
        dex
        dey
    } while (not minus)
}

inline TS_set_bits01(tile_addr)
{
    ldy #8-1
    do {
        lda tile_addr, Y
        ora TS_buf.bit0, X
        sta TS_buf.bit0, X
        lda tile_addr, Y
        ora TS_buf.bit1, X
        sta TS_buf.bit1, X
        dex
        dey
    } while (not minus)
}

inline TS_set_ind(tile_ind_addr, offset)
{
    ldy #8-1
    do {
        lda [tile_ind_addr], Y
        ora TS_buf+(offset), X
        sta TS_buf+(offset), X
        dex
        dey
    } while (not minus)
}

inline TS_set_inv(tile_addr, offset)
{
    ldy #8-1
    do {
        lda tile_addr, Y
        eor #0xFF
        ora TS_buf+(offset), X
        sta TS_buf+(offset), X
        dex
        dey
    } while (not minus)
}

inline TS_set_ind_inv(tile_ind_addr, offset)
{
    ldy #8-1
    do {
        lda [tile_ind_addr], Y
        eor #0xFF
        ora TS_buf+(offset), X
        sta TS_buf+(offset), X
        dex
        dey
    } while (not minus)
}

/******************************************************************************/

/*
    X = fg offset
    Y = bg offset
*/
inline TS_mix_bg_mono(other_offset)
{
    lda #8
    sta tmp_byte
    do {
        lda TS_buf, X
        eor #0xFF
        and Tile_BG, Y
        sta TS_buf+(other_offset), X
        ora TS_buf, X
        sta TS_buf, X

        dex
        dey
        dec tmp_byte
    } while (not equal)
}

/*
    X = fg offset
    Y = bg offset
*/
function TS_mix_down_bg()
{
    lda #8
    sta tmp_byte3
    do {
        lda     TS_buf.bit1, X
        eor     #0xFF
        sta     tmp_byte    // ~bit1
        lda     TS_buf.bit0, X
        eor     #0xFF
        and     tmp_byte    // ~bit1
        and     Tile_BG, Y
        sta     tmp_byte2   // bg & ~bit0 & ~bit1
        ora     TS_buf.bit1, X
        sta     TS_buf.bit1, X
        lda     TS_buf.bit0, X
        and     tmp_byte    // ~bit1
        ora     tmp_byte2   // bg & ~bit0 & ~bit1
        sta     TS_buf.bit0, X
        dex
        dey
        dec     tmp_byte3
    } while (not equal)
}
