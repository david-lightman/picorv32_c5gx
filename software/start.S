/* software/start.S */
.section .text.start
.global _start

_start:
    # Set stack pointer to 0x10000000 + 512KB
    li sp, 0x10080000
    call main
    # Trap if main returns
    ebreak
loop:
    j loop
