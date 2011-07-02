.include "nmi.inc"
.include "ppu.inc"
.include "tiles.inc"
.include "joy.inc"

.bss
oam_ready:   .byte 0

.code
.proc flip_bg_nametable_nmi
    pha
    txa
    pha
    tya
    pha

    ppu_ctl0_clear PPU_C0_BACKADDR1000

    jsr write_tile_stages

    ldx #162                ; 2

    lda oam_ready
    beq after_oam
    lda #>oam_buf
    sta PPU_SPR_DMA                 ; 4
    lda #0                          ; 2
    sta oam_ready                   ; 3 + 513
    ; (162*5 - (4 + 2 + 3 + 513 + 2)) / 5 = 57.2
    ldx #57                         ; 2
after_oam:

initial_delay:
    dex                 ; 2 * X
    bne initial_delay   ; 3 * (X-1) + 2

    ; 341/3 cycles per line + change (8 cycles)
    lda #$20                ; 2
    ldy #4+(8*12)           ; 2
waitloop:
        ldx #20             ; 2 * lines
inner_waitloop:
        dex                 ; 2 * 20 * lines
        bne inner_waitloop  ; (3 * 19 + 2) * lines
        nop                 ; 2 * lines
        asl A               ; 2 * lines
        bcs extra           ; (1/3 * 3 + 2/3 * 2) * lines
        dey                 ; 2 * lines
        bne waitloop        ; 3 * (lines-1) + 2
extra:
        bcc waitdone        ; 1/3 * 2 * lines + 2/3 * 3
        lda #$20            ; 1/3 * 2 * lines
        dey                 ; (counted above)
        bne waitloop        ; (counted above)
waitdone:

    ppu_ctl0_set PPU_C0_BACKADDR1000
    
    ; update controller once per frame
    jsr update_joypad

    pla
    tay
    pla
    tax
    pla

    rti
.endproc
