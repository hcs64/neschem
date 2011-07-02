.include "common.inc"
.include "ppu.inc"
.include "tiles.inc"

.zeropage

    .define tile_stage_count 8

    ; shared pattern staging area

    .struct tile_stage_addr_s
        .word tile_stage_count
    .endstruct

tile_stage_addr:
    .tag tile_stage_addr_s

    .struct tile_stage_s
        tile_buf_1 .byte 8
        tile_buf_0 .byte 8
    .endstruct

    .define tile_stage_addr_idx(index) tile_stage_addr+2*(index)

tile_stage: 
    .repeat tile_stage_count
        .tag tile_stage_s
    .endrepeat

    .define tile_stage_idx(index, line) tile_stage_addr+.sizeof(tile_stage_s)*(index)+(line)

tile_buf:
    .tag tile_stage_s

.bss

next_stage_index:
    .byte 0
tile_stage_written:
    .byte 0

.code
.proc init_tile_stage
    ldx #.sizeof(tile_stage_addr_s)-2
    ; start with full buffer
    stx next_stage_index
    ; nmi doesn't need to do anything yet (nonzero)
    stx tile_stage_written
    rts
.endproc

.proc find_free_tile_stage
    ldx next_stage_index

    bpl wait_done
    ; next index is negative, need to wait for nmi to process buffer
wait_loop:
    ldx tile_stage_written
    beq wait_loop

    ldx #.sizeof(tile_stage_addr_s)-2
wait_done:

    txa
    tay ; save free entry's address offset in Y

    ; decrement for next time
    dex
    dex
    stx next_stage_index

    ; A is the free entry's address offset, convert to staging buffer offset (end)
    clc
    adc #2 ; move to next index

    asl A
    asl A
    asl A
    ; carry will be clear
    adc #$FF ; move back to penultimate byte, where writing starts

    ; result: A has staging buffer offset, Y has address offset
    rts
.endproc

.macro write_1_tile_stage   index
    ; 126 cycles
    ldx tile_stage_addr_idx(index)+0        ; 3
    lda tile_stage_addr_idx(index)+1        ; 3

    sta PPU_ADDRESS                         ; 4
    stx PPU_ADDRESS                         ; 4

    .repeat 8,line
    lda tile_stage_idx(index, 7-line)+tile_stage_s::tile_buf_0  ; 3
    sta PPU_IO                              ; 4
    .endrepeat

    .repeat 8,line
    lda tile_stage_idx(index, 7-line)+tile_stage_s::tile_buf_1  ; 3
    sta PPU_IO                              ; 4
    .endrepeat
.endmacro

.proc write_tile_stages
    ppu_clean_latch

    lda tile_stage_written
    beq do_write_tile_stages
    ; 2 + 2 + 202*2 + 201*3 + 2 + 3 = 1016 cycles

    lda #202            ; 2
    tax                 ; 2

cycle_burner:
    dex                 ; 2*202
    bne cycle_burner    ; 3*201 + 2

    jmp skip_tile_stages; 3

do_write_tile_stages:
    ; 3 + 126*8 + 2 + 3 = 1016 cycles
    .repeat 8, index
    write_1_tile_stage 7-index
    .endrepeat

    lda #1                  ; 2
    sta tile_stage_written  ; 3

skip_tile_stages:

    vram_clear_address

    rts
.endproc

.proc finalize_tile_stage
    lda next_stage_index
    bpl end
    ldx #0
    stx tile_stage_written ; nmi needs to write
end:
    rts
.endproc

; must be called after finalize_tile_stage
.proc flush_tile_stage
    ; if next_stage_index is minus, buffer is full, and was just sent
    ldx next_stage_index
    bpl nothing_to_skip
    ; otherwise, it has at least one entry, fill the rest with throwaway
    lda #0  ; junk pattern 1
    ldy #16 ; junk pattern 1
flush_fill_loop:
    sty tile_stage_addr+0, X
    sta tile_stage_addr+1, X
    dex
    dex
    bpl flush_fill_loop

    ; store the now-negative index
    stx next_stage_index

    ; and pass off control to the nmi
    sta tile_stage_written ; nmi needs to write

nothing_to_skip:
    rts
.endproc

; ******************************************************************************

; X holds offset
.proc set_tile_stage_blue_bg_ind
    ldy #8-1
loop:
    lda (tmp_addr), Y
    sta tile_stage, X
    lda #$ff
    sta tile_stage-8, X
    dex
    dey
    bpl loop

    rts
.endproc

.proc set_tile_stage_red_bg_ind
    ldy #8-1
loop:
    lda #$ff
    sta tile_stage, X
    lda (tmp_addr), Y
    sta tile_stage-8, X
    dex
    dey
    bpl loop

    rts
.endproc

.proc set_tile_stage_clear
    ldy #8-1
    lda #0
loop:
    sta tile_stage, X
    sta tile_stage-8, X
    dex
    dey
    bpl loop

    rts
.endproc

.proc overlay_tile_stage_blue_ind
    ldy #8-1
loop:
    lda (tmp_addr), Y
    pha
    ora tile_stage-8, X
    sta tile_stage-8, X
    pla
    eor #$FF
    and tile_stage, X
    sta tile_stage, X
    dex
    dey
    bpl loop

    rts
.endproc

.proc overlay_tile_stage_red_ind
    ldy #8-1
loop:
    lda (tmp_addr), Y
    pha
    ora tile_stage, X
    sta tile_stage, X
    pla
    eor #$FF
    and tile_stage-8, X
    sta tile_stage-8, X
    dex
    dey
    bpl loop

    rts
.endproc

.proc overlay_mono_tile_stage_ind
    ldy #8-1
loop:
    lda (tmp_addr), Y
    ora tile_stage, X
    sta tile_stage, X
    dex
    dey
    bpl loop

    rts
.endproc

.proc write_tile_buf
    ldx #16-1
loop:
    lda tile_buf, X
    sta PPU_IO
    dex
    bpl loop

    rts
.endproc
