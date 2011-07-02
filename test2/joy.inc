
JOYSTICK_CNT0 = $4016
JOYSTICK_CNT1 = $4017

.global update_joypad
.globalzp _joypad0
.globalzp last_joypad0, new_joypad0
.globalzp hold_count_joypad0, repeat_count_joypad0
