.section .text
.global _start

_start:
    # 1. Initialize Stack Pointer
    # Set SP to the top of Internal RAM (0x400 = 1KB)
    # The stack grows DOWN from here.
    li sp, 0x400

    # 2. Jump to C Code
    call main

    # 3. Trap Loop (If main returns)
    ebreak
loop:
    j loop
