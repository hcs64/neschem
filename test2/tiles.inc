
.global init_tile_stage, find_free_tile_stage, write_tile_stages, finalize_tile_stage, flush_tile_stage
.global set_tile_stage_blue_bg_ind, set_tile_stage_red_bg_ind, set_tile_stage_clear
.global overlay_tile_stage_blue_ind, overlay_tile_stage_red_ind, overlay_mono_tile_stage_ind
.global write_tile_buf
.globalzp tile_stage, tile_buf

tile_buf_0 = tile_buf + 8
tile_buf_1 = tile_buf

; X holds offset
.macro set_tile_stage_white tile_addr
.scope
    ldy #8-1
loop:
    lda tile_addr, Y
    sta tile_stage, X
    sta tile_stage-8, X
    dex
    dey
    bpl loop
.endscope
.endmacro

.macro overlay_tile_stage_blue_hline tile_immed, line
    lda #tile_immed
    ora (tile_stage-8)-line, X
    sta (tile_stage-8)-line, X
    lda #$FF^tile_immed
    and tile_stage-line, X
    sta tile_stage-line, X
.endmacro

.macro overlay_tile_stage_red_hline tile_immed, line
    lda #tile_immed
    ora tile_stage-line, X
    sta tile_stage-line, X
    lda #$FF^tile_immed
    and (tile_stage-8)-line, X
    sta (tile_stage-8)-line, X
.endmacro

.macro overlay_mono_tile_stage_midhline
    ldy #$FF
    sty tile_stage-3, X
    sty tile_stage-4, X
.endmacro

.macro overlay_mono_tile_stage_midvline
.scope
    ldy #8-1
loop:
    lda tile_stage, X
    ora #$18
    sta tile_stage, X
    dex
    dey
    bpl loop
.endscope
.endmacro

.macro overlay_mono_tile_stage tile_addr
.scope
    ldy #8-1
loop:
    lda tile_addr, Y
    ora tile_stage, X
    sta tile_stage, X
    dex
    dey
    bpl loop
.endscope
.endmacro

.macro overlay_tile_stage_blue tile_addr
.scope
    ldy #8-1
loop:
    lda tile_addr, Y
    ora tile_stage-8, X
    sta tile_stage-8, X
    lda tile_addr, Y
    eor #$FF
    and tile_stage, X
    sta tile_stage, X
    dex
    dey
    bpl loop
.endscope
.endmacro

.macro overlay_tile_stage_red tile_addr
.scope
    ldy #8-1
loop:
    lda tile_addr, Y
    ora tile_stage, X
    sta tile_stage, X
    lda tile_addr, Y
    eor #$FF
    and tile_stage-8, X
    sta tile_stage-8, X
    dex
    dey
    bpl loop
.endscope
.endmacro

.macro set_tile_stage_red tile_addr
.scope
    ldy #8-1
loop:
    lda tile_addr, Y
    sta tile_stage, X
    lda #0
    sta tile_stage-8, X
    dex
    dey
    bpl loop
.endscope
.endmacro

.macro set_tile_stage_blue tile_addr
.scope
    ldy #8-1
loop:
    lda #0
    sta tile_stage, X
    lda tile_addr, Y
    sta tile_stage-8, X
    dex
    dey
    bpl loop
.endscope
.endmacro

; ******************************************************************************

.macro init_tile_red tile_addr
.scope
    ldx #8-1
    ldy #0
loop:
    lda tile_addr, X
    sta tile_buf_0, X
    sty tile_buf_1, X
    dex
    bpl loop
.endscope
.endmacro

.macro init_tile_blue tile_addr
.scope
    ldx #8-1
    ldy #0
loop:
    lda tile_addr, X
    sty tile_buf_0, X
    sta tile_buf_1, X
    dex
    bpl loop
.endscope
.endmacro

.macro init_tile_white tile_addr
.scope
    ldx #8-1
loop:
    lda tile_addr, X
    sta tile_buf_0, X
    sta tile_buf_1, X
    dex
    bpl loop
.endscope
.endmacro

.macro overlay_tile_red tile_addr
.scope
    ldx #8-1
loop:
    lda tile_addr, X
    tay
    ora tile_buf_0, X
    sta tile_buf_0, X
    tya
    eor #$FF
    and tile_buf_1, X
    sta tile_buf_1, X
    dex
    bpl loop
.endscope
.endmacro

.macro add_tile_blue tile_addr
.scope
    ldx #8-1
loop:
    lda tile_addr, X
    ora tile_buf_1, X
    sta tile_buf_1, X
    dex
    bpl loop
.endscope
.endmacro

.macro overlay_tile_white tile_addr
.scope
    ldx #8-1
loop:
    lda tile_addr, X
    tay
    ora tile_buf_0, X
    sta tile_buf_0, X
    tya
    ora tile_buf_1, X
    sta tile_buf_1, X
    dex
    bpl loop
.endscope
.endmacro

.macro write_tile_white tile_addr
.scope
    ldy #1
bitplane_loop:
    ldx #8-1
line_loop:
    lda tile_addr, X
    sta PPU_IO
    dex
    bpl line_loop
    dey
    bpl bitplane_loop
.endscope
.endmacro

.macro write_tile_red_bg tile_addr
.scope
    ldx #8-1
    lda #$FF
loop_0:
    sta PPU_IO
    dex
    bpl loop_0
    ldx #8-1

loop_1:
    lda tile_addr, X
    sta PPU_IO
    dex
    bpl loop_1
.endscope
.endmacro

.macro write_tile_blue_bg tile_addr
.scope
    ldx #8-1
loop_0:
    lda tile_addr, X
    sta PPU_IO
    dex
    bpl loop_0

    ldx #8-1
    lda #$FF
loop_1:
    sta PPU_IO
    dex
    bpl loop_1

.endscope
.endmacro

