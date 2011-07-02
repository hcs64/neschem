.include "ppu.inc"

.zeropage

_ppu_ctl0: .byte 0
_ppu_ctl1: .byte 0

.segment "OAM_BUF"
oam_buf:
.res 256
