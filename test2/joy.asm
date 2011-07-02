.include "joy.inc"

.zeropage
_joypad0:       .byte 0
last_joypad0:   .byte 0
new_joypad0:    .byte 0

HOLD_DELAY = 12
REPEAT_DELAY = 3
.struct joypad_buttons_s
    .byte 8
.endstruct

hold_count_joypad0:
    .tag joypad_buttons_s
repeat_count_joypad0:
    .tag joypad_buttons_s

.code

.proc update_joypad
    ; reset

    ldx #1
    sta JOYSTICK_CNT0
    dex
    sta JOYSTICK_CNT0

    ldx #8
read_button_loop:
        lda JOYSTICK_CNT0
        lsr A
        bcc not_pressed
            php

            ldy hold_count_joypad0-1, X
            iny
            cpy #HOLD_DELAY
            beq held_enough
                sty hold_count_joypad0-1, X
held_enough:
            bne skip_repeat_count
                inc repeat_count_joypad0-1, X
                bne skip_repeat_count
                    ; saturate at 255
                    dec repeat_count_joypad0-1, X
skip_repeat_count:

            plp
not_pressed:

        bcs pressed
            lda #0
            sta hold_count_joypad0-1, X
            sta repeat_count_joypad0-1, X
pressed:
        rol _joypad0
        dex
    bne read_button_loop

    rts
.endproc
