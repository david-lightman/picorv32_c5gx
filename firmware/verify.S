# verify.S - Corrected with Stack Management
.section .text
.global _start

_start:
    li sp, 1024

main_loop:
    # ---------------------------------------------------------
    # State 0: Low Memory
    # ---------------------------------------------------------
    jal ra, delay_loop   # Leaf call (safe)

    # ---------------------------------------------------------
    # State 1: High Memory (0x100)
    # ---------------------------------------------------------
    jal ra, function_at_100
    
    # ---------------------------------------------------------
    # State 2: Higher Memory (0x200)
    # ---------------------------------------------------------
    jal ra, function_at_200

    j main_loop

# -------------------------------------------------------------
# Leaf Function: Does not call anyone else.
# No stack manipulation needed.
# -------------------------------------------------------------
delay_loop:
    li t0, 20000000 
1:  addi t0, t0, -1
    bnez t0, 1b
    ret

# -------------------------------------------------------------
# Non-Leaf Function: Calls another function.
# MUST save 'ra' to stack!
# -------------------------------------------------------------
.org 0x100
function_at_100:
    addi sp, sp, -4      # 1. Grow Stack
    sw ra, 0(sp)         # 2. Save Return Address (Back to main)
    
    jal ra, delay_loop   # 3. Call delay (Clobbers ra)
    
    lw ra, 0(sp)         # 4. Restore Return Address
    addi sp, sp, 4       # 5. Shrink Stack
    ret                  # 6. Return to main

.org 0x200
function_at_200:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    jal ra, delay_loop
    
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
