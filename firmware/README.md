# Firmware (Stage 1 Bootloader)

This directory contains the code that runs immediately after the FPGA powers up. It resides in the 1KB internal Block RAM (BRAM) at address `0x0000_0000`.

Because the internal memory is extremely small (1024 bytes), this firmware must be minimal. Its primary job is to initialize the main system memory (SRAM) and load the larger Operating System (Kernel) from the SD card.

---

## Files

### Core Components
*   **start.S**: The entry point. It sets the stack pointer to the top of the 1KB internal RAM (`0x400`) and jumps to `main()`.
*   **sections.lds**: The Linker Script. It ensures the code is linked to run at `0x0000_0000` and enforces the 1KB size limit.
*   **makehex.py**: A utility script that converts the compiled binary (`.bin`) into a Verilog-readable hex string file (`firmware.list`).

### Applications
You can compile one of the following C files depending on what you need to do:

1.  **main.c (The Bootloader)**:
    *   Initializes the SD Card via bit-banged SPI.
    *   Reads the Kernel from Sector 1 of the SD Card.
    *   Copies 64KB of data into External SRAM (`0x1000_0000`).
    *   Jumps to `0x1000_0000` to start the Kernel.

2.  **sram_test.c (Hardware Verification)**:
    *   A diagnostic tool to verify the custom SRAM Controller.
    *   Writes byte patterns to SRAM and reads them back as 32-bit words.
    *   Verifies 16-bit half-word write integrity.
    *   Prints PASS/FAIL status to the UART.

3.  **verify.S (CPU Verification)**:
    *   A pure Assembly test to verify the RISC-V core's stack pointer and function call (JAL/JALR) mechanics.

---

## How to Build

The parent `Makefile` in the root directory handles the build process. By default, it compiles `main.c`.

### Switching Applications
To switch between the Bootloader and the SRAM Test, you must edit the root `Makefile`.

**To build the Bootloader (Default):**
```makefile
FW_SRCS := $(FW_DIR)/start.S $(FW_DIR)/main.c
#FW_SRCS := $(FW_DIR)/start.S $(FW_DIR)/sram_test.c
```

To build the SRAM Test:
```Makefile
#FW_SRCS := $(FW_DIR)/start.S $(FW_DIR)/main.c
FW_SRCS := $(FW_DIR)/start.S $(FW_DIR)/sram_test.c
```

Compilation Steps

After modifying the Makefile:

```
# 1. Clean old firmware
make clean

# 2. Compile new firmware and update the FPGA bitstream
make

# 3. Program the FPGA
make program
```

## Technical Details

### Memory Constraint

The firmware has a hard limit of 1024 bytes.

    Do not use standard C library functions (printf, memcpy, malloc).

    Avoid large stack allocations.

    The sections.lds script will cause the build to fail if the binary exceeds this limit.

### Boot Sequence

- Reset: PC = 0x0000_0000.

- SPI Init: Bit-bangs generic SPI commands to wake the SD card.

- Load: Reads 128 sectors (64KB) from SD Offset 512 (Sector 1).

- Copy: Writes data to 0x1000_0000 (External SRAM).

- Jump: Executes a function pointer to 0x1000_0000.