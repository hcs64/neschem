.segment "HEADER"
    .byte "NES", $1A
    .byte 1

.import nmi_handler, reset_handler

.segment "VECTORS"
    .word nmi_handler, reset_handler, irq_handler

.CODE
irq_handler:
    rti
