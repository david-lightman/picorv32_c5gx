# Custom RISC-V System - Software & Boot Documentation

This directory contains the Operating System / Kernel software for the Cyclone V GX RISC-V Computer. Unlike the `firmware/` directory, the code here is **not** baked into the FPGA. It is loaded dynamically from the SD Card into SRAM at runtime.

## 1. System Memory Map

The custom PicoRV32 processor sees the following address space:

| Address Range | Size | Description | Notes |
| :--- | :--- | :--- | :--- |
| `0x00000000` - `0x000003FF` | 1 KB | **Internal Boot ROM** | FPGA Block RAM. Read-only from SW perspective. |
| `0x10000000` - `0x1007FFFF` | 512 KB | **External SRAM** | Main System Memory. Volatile. |
| `0x20000000` | 4 Bytes | **UART Data** | R/W. Write to TX, Read from RX. |
| `0x20000004` | 4 Bytes | **UART Status** | Read Only. Bit 0: RX_Ready, Bit 1: TX_Busy. |
| `0x30000000` | 4 Bytes | **SD GPIO** | Write to drive SCK/MOSI/CS. Read to sample MISO. |

---

## 2. The Boot Process (Step-by-Step)

When you press the Power button or the Reset Key (KEY4), the following sequence occurs:

### Stage 1: Hardware Power-Up
1.  **FPGA Configuration:** The Cyclone V loads the hardware bitstream from the onboard flash.
2.  **Reset Release:** The hardware releases the `resetn` signal to the PicoRV32 core.
3.  **Entry Point:** The CPU Program Counter (PC) starts at `0x00000000`.

### Stage 2: The Bootloader (Firmware)
The CPU executes the instructions located in the internal Block RAM (the code in `firmware/`).
1.  **Stack Setup:** `sp` is set to `0x400` (Top of Internal RAM).
2.  **SD Initialization:** The bootloader bit-bangs the SPI protocol to wake up the SD card (`CMD0` -> `CMD8` -> `ACMD41`).
3.  **Sector Reading:**
    *   The Bootloader sends `CMD17` to read **Sector 1** (Offset 512 bytes) of the SD Card.
    *   *Note: Sector 0 is skipped to preserve the PC-compatible MBR/Partition Table.*
4.  **Memory Copy:**
    *   Bytes read from the SD card are written sequentially to SRAM starting at `0x10000000`.
    *   It loads 64KB (128 Sectors) total.

### Stage 3: The Handoff
Once the loading loop finishes:
1.  The Bootloader creates a function pointer to address `0x10000000`.
2.  It performs a jump (Call) to that address.
3.  Execution leaves the Internal RAM and enters the SRAM.

### Stage 4: The Kernel (Software)
The CPU is now executing your code from this directory (`software/`).
1.  **Entry (`start.S`):**
    *   The Kernel ignores the old stack pointer.
    *   `sp` is set to `0x10080000` (Top of **SRAM**).
2.  **Main:**
    *   Execution jumps to `main()` in `main.c`.
    *   The Kernel now has full control of the UART and system.

---

## How to Build & Deploy

### Prerequisites
*   RISC-V GCC Toolchain (`riscv64-unknown-elf-gcc`)
*   An SD Card formatted as FAT32 (MBR scheme recommended to keep Mac/Windows happy).

### Compilation
From this directory (`software/`), run:
```bash
make

This generates `kernel.bin`

## Deployment -- FIXME

- Identify disk

```shell
diskutil list
```

- Unmount

```shell
diskutil unmountDisk [force] /dev/disk\<N\>
```

-- dd - write to sector 1 to match bootloader expectation

```shell
sudo dd if=kernel.bin of=/dev/rdisk\<Ni\> seek=1 bs=512 conv=notrunc
```

## Writing Software

Writing Software

- No standard libs: at this time there is no libc (printf, memcpy, malloc are unavailable). You must implement helpers yourself or link a small embedded library.

- Interrupts: Currently disabled. All hardware interaction (UART/SD) must be done via Polling.

- Linker Script: sections.lds ensures code is linked to run at 0x10000000. Do not change the origin unless you change the Bootloader.