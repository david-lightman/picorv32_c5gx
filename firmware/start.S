.section .text.start
.global _start

_start:
    /* PicoRV32 includes built-in SP initialization if parameters are set, 
       but we force it here to be safe. Top of RAM = 1024 (0x400) */
    li sp, 0x400
    
    /* Jump to main C function */
    call main

    /* Trap if main returns */
    ebreak
loop:
    j loop

