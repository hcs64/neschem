.include "ppu.inc"
.include "nmi.inc"
.include "common.inc"
.include "tiles.inc"
.include "images.inc"
.include "joy.inc"

.export main
.import nmi_vector

.code

.proc main
    jsr system_initialize
    jsr clear_vram
    jsr clear_sprites
    jsr init_ingame_vram
    ;jsr init_playfiled
    jsr init_tile_stage

    lda #<flip_bg_nametable_nmi
    sta nmi_vector+0
    lda #>flip_bg_nametable_nmi
    sta nmi_vector+1

    vblank_wait
    vram_clear_address
    ppu_ctl0_assign PPU_C0_NMI
    ppu_ctl1_assign PPU_C1_BACKVISIBLE|PPU_C1_SPRITESVISIBLE|PPU_C1_BACKNOCLIP|PPU_C1_SPRNOCLIP

    jmp *
.endproc

.proc system_initialize
    ; clear the registers
    lda  #0

    sta  PPU_C0
    sta  PPU_C1

    sta  _ppu_ctl0
    sta  _ppu_ctl1
    sta  _joypad0
    sta  last_joypad0
    sta  oam_ready

    ldx #8
@clear_button_hold_loop:
    dex
    sta  hold_count_joypad0, X
    sta  repeat_count_joypad0, X
    bne @clear_button_hold_loop

    sta  PPU_SCROLL
    sta  PPU_SCROLL

    ;sta  PCM_CNT
    ;sta  PCM_VOLUMECNT
    ;sta  SND_CNT
    sta $4010
    sta $4011
    sta $4015

    lda  #$C0
    sta  JOYSTICK_CNT1

    ; wait for PPU to turn on
    bit PPU_STATUS
@vwait1:
    bit PPU_STATUS
    bpl @vwait1
@vwait2:
    bit PPU_STATUS
    bpl @vwait2

    rts
.endproc

; ******************************************************************************

.proc clear_vram
    vram_clear_address

    lda #0
    ldy #$30
half_page_loop:
        ldx #$80
inner_loop:
            sta PPU_IO
            sta PPU_IO
            dex
            bne inner_loop
        dey
        bne half_page_loop
    rts
.endproc

; ******************************************************************************

.proc clear_sprites
    ldx #0
    lda #$FF
sprite_loop:
        dex
        sta oam_buf, X
        bne sprite_loop
    rts
.endproc

; ******************************************************************************

.proc init_ingame_vram
    jsr init_ingame_palette
    jsr init_ingame_fixed_patterns
    jsr init_ingame_unique_names

    rts
.endproc

.proc init_ingame_palette
    ; Setup palette
    vram_set_address_i(PAL_0_ADDRESS)

    ldx #4-1
pal_0_loop:
        lda bg_palette, X
        sta PPU_IO
        dex
        bpl pal_0_loop

    vram_set_address_i(PAL_1_ADDRESS)
    ldx #4-1
pal_1_loop:
        lda bg_palette, X
        sta PPU_IO
        dex
        bpl pal_1_loop

    rts
.endproc

.export init_ingame_fixed_patterns
.proc init_ingame_fixed_patterns
    ; will probably want to break this out once we do have
    ; bg tiles shared common between pat tbls

    ; Setup pattern table 0

    ; 0: empty bg tile
    vram_set_address_i PATTERN_TABLE_0_ADDRESS
    write_tile_red_bg Tile_Cmds+8

    vram_set_address_i PATTERN_TABLE_0_ADDRESS+(16*96)
    init_tile_red Tile_ArrowLeft
    jsr write_tile_buf

    ; Setup pattern table 1

    vram_set_address_i PATTERN_TABLE_1_ADDRESS
    ; 0: empty bg tile
    write_tile_blue_bg Tile_Cmds+8

    vram_set_address_i PATTERN_TABLE_1_ADDRESS+(16*96)
    init_tile_blue Tile_ArrowRight
    jsr write_tile_buf

    rts
.endproc

.proc init_ingame_unique_names
    ppu_ctl0_set PPU_C0_ADDRINC32

    ; main body, starting from (6,4), 20x16

    ; (6,4)-(25,11) 20x8, are numbered 96-255, column first
    ; (6,12)-(25,19) 20x8, are numbered 96-255, column first

    lda #<(NAME_TABLE_0_ADDRESS+6+(4*NAME_TABLE_WIDTH))
    sta tmp_addr+0
    lda #>(NAME_TABLE_0_ADDRESS+6+(4*NAME_TABLE_WIDTH))
    sta tmp_addr+1

    ldx #2

half_screen_loop:
        txa
        pha

        ldy #96
col_loop:
            vram_set_address tmp_addr

            dey

            lda #0
            ldx #8
row_loop:
                iny
                sty PPU_IO
                dex
                bne row_loop

            inc tmp_addr+0 ; should not need carry

            iny
            bne col_loop

        ; skip down to lower half
        lda tmp_addr+0
        sec
        sbc #20
        sta tmp_addr+0
        inc tmp_addr+1

        pla
        tax
        dex
        bne half_screen_loop

    ; temp
    ppu_ctl0_clear PPU_C0_ADDRINC32
.if 0
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
            sty PPU_IO
            sta PPU_IO
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
            sta PPU_IO
            sty PPU_IO
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
        sty PPU_IO
        sta PPU_IO
        iny
        dex
    } while (not zero)

    // bottom border, (7,20)-(26,20) (inc 2) are numbered 78-87
    vram_set_address_i(NAME_TABLE_0_ADDRESS+6+(20*NAMETABLE_WIDTH))
    ldx #10
    ldy #78
    lda #0
    do {
        sta PPU_IO
        sty PPU_IO
        iny
        dex
    } while (not zero)
.endif

    rts
.endproc

.rodata
bg_palette:
    .byte $20 ; 11: white
    .byte $12 ; 10: blue
    .byte $16 ; 01: red
    .byte $10 ; 00: gray (bg)
