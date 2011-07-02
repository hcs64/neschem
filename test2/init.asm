.export reset_handler, nmi_handler, nmi_vector
.import main

.code

nmi_handler:
    jmp (nmi_vector)

reset_handler:
    ; initialization
    cld

    cli

    ldx #$FF
    txs

    jmp main

.bss
nmi_vector: .word 0
