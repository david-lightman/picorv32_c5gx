# Software (The Kernel)

This directory contains the Operating System / Kernel software. Unlike the `firmware/`, which is baked into the FPGA, this code lives on the SD Card and is loaded into the main system memory (SRAM) at runtime.

This separation allows you to update your software by simply swapping the file on the SD card, without needing to re-synthesize the FPGA bitstream.

---

## Technical Overview

### Memory Layout
*   **Load Address**: `0x1000_0000` (Start of External SRAM).
*   **Stack Pointer**: `0x1008_0000` (Top of External SRAM, giving 512KB of stack space).
*   **Execution**: The Bootloader jumps here after copying the first 64KB from the SD Card.

### Capabilities
*   **Standard Library**: None (Bare metal). You must implement your own string/memory functions.
*   **Drivers**:
    *   **UART**: Polled I/O via memory-mapped registers at `0x2000_0000`.
    *   **SD Card**: Not yet implemented in the kernel (only available in Bootloader).

---

## Files

*   **start.S**: The kernel entry point. It sets up the new stack pointer (at the top of SRAM) and jumps to `main()`.
*   **main.c**: The main C application. Currently implements a simple interactive Serial Shell.
*   **sections.lds**: The Linker Script. It sets the origin to `0x1000_0000` so memory references are correct.
*   **Makefile**: Automates the compilation of `kernel.bin`.

---

## How to Build & Deploy

### 1. Compile the Kernel
Run `make` inside this directory to produce `kernel.bin`.

```bash
cd software
make
```

## 2. Deploy to SD Card

The Bootloader expects the kernel to be located at Sector 1 (Offset 512 bytes) of the SD Card.

WARNING: Be extremely careful with the dd command. Writing to the wrong disk identifier will erase your computer's hard drive.

macOS:

```
# 1. Identify your SD Card (e.g., /dev/disk4)
diskutil list

# 2. Unmount the disk
diskutil unmountDisk /dev/disk4

# 3. Write the kernel to Sector 1
sudo dd if=kernel.bin of=/dev/rdisk4 seek=1 bs=512 conv=notrunc
```

Linux:

```
# 1. Identify your SD Card (e.g., /dev/sdb)
lsblk

# 2. Unmount the partitions
sudo umount /dev/sdb*

# 3. Write the kernel to Sector 1
sudo dd if=kernel.bin of=/dev/sdb seek=1 bs=512 conv=notrunc
```

### 3. Run

- Insert the SD Card into the FPGA board.

- Press the RESET button (KEY4) on the FPGA.

- Open your serial terminal (115200 baud).

- You should see the bootloader messages, followed by the Kernel Shell:

```
> LOAD
...
BOOT!
==================================
   Cyclone V RISC-V Interactive
==================================
> 
```