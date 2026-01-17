# picorv32_c5gx SoC

A complete, bare-metal System-on-Chip (SoC) implementation of the [YosysHQ/picorv32](https://github.com/YosysHQ/picorv32) RISC-V core on the [Altera Cyclone V GX Starter Kit](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=830&PartNo=4).

This project bridges the PicoRV32 RISC-V core with the board's peripherals, creating a functional computer with a Boot ROM, External RAM, Storage (SD Card), and Serial Console.

---

## System Architecture

The design follows a "Clean Context" SoC architecture. The FPGA logic acts as the motherboard, connecting the CPU to peripherals via a custom memory-mapped bus.

### Hardware Modules (RTL)
*   **picorv32.v**: The CPU Core (RV32I). Configured for high performance (ENABLE_REGS_16_31, ENABLE_FAST_MUL).
*   **sram_controller.v**: A custom state machine that interfaces the 32-bit CPU bus with the board's 16-bit External SRAM chips. It automatically splits 32-bit reads/writes into two 16-bit physical transactions.
*   **uart_full.v**: A hardware UART controller (115200 Baud) with internal clock division and status registers.
*   **sd_spi_bridge.v**: A hardware bridge allowing the CPU to manually drive (bit-bang) the SPI signals for the SD Card slot.
*   **riscv_core_c5gx.v**: The SoC Wrapper. Handles address decoding, multiplexing, and reset logic.
*   **baseline_c5gx.v**: The Top-Level Board Wrapper. Maps internal signals to physical FPGA pins and IO standards.

### Memory Map

| Address Range | Device | Description |
| :--- | :--- | :--- |
| 0x0000_0000 | BRAM | Internal FPGA Block RAM (1KB). Contains the Bootloader. |
| 0x1000_0000 | SRAM | External IS61WV25616 SRAM (512KB). Main System Memory. |
| 0x2000_0000 | UART | Serial Console Data Register (TX/RX). |
| 0x2000_0004 | UART | Serial Console Status Register (Bit 0: RX_READY, Bit 1: TX_BUSY). |
| 0x3000_0000 | SD | SD Card GPIO Bridge (SCK, MOSI, CS, MISO). |

---

## The Boot Process

This system mimics a real embedded computer with a multi-stage boot process:

1.  **Hardware Reset**: The FPGA loads configurations. `riscv_core_c5gx.v` holds the CPU in reset for 256 cycles to stabilize voltage.
2.  **Stage 1 (Firmware)**: The CPU wakes up at 0x0000_0000. It executes the **Bootloader** (compiled from firmware/). This code initializes the SD card, reads the Operating System (Kernel) from Sector 1, and copies it into SRAM.
3.  **Stage 2 (Software)**: The CPU jumps to 0x1000_0000. It executes the **Kernel** (compiled from software/), running from high-capacity external memory.

---

## Usage

### Prerequisites
*   **Hardware**: Terasic Cyclone V GX Starter Kit.
*   **Synthesis**: Intel Quartus Prime (Lite or Standard) v21+.
*   **Simulation**: ModelSim / Questa (Starter Edition).
*   **Toolchain**: RISC-V GCC (riscv64-unknown-elf-gcc).
*   **Python 3**: For generating the boot ROM hex files.

### Build Instructions

The Makefile automates the dependency chain. It ensures the Firmware (Bootloader) is compiled *before* the Hardware, as the FPGA needs the firmware hex file to initialize the internal BRAM.

```bash
# 1. Clean previous artifacts
make clean

# 2. Build Firmware and Synthesis Hardware
#    This compiles firmware/main.c -> firmware.list
#    Then compiles the Verilog -> output_files/riscv_core_c5gx.sof
make

# 3. Program the FPGA (SRAM Mode)
make program
```

## Simulation

You can simulate the hardware logic without the physical board.

```
# Compile Verilog and run a batch simulation
make sim

# Open the GUI for waveform debugging
make sim-gui
```

## File Structure

- /): Verilog Hardware Source (.v) and Build Scripts.

- ./firmware: Source code for the internal Bootloader (runs at 0x0000_0000).

- ./software: Source code for the Kernel/OS (runs at 0x1000_0000).

- ./simulation: ModelSim/Questa work directories.

- ./output_files: Quartus synthesis artifacts (.sof bitstream).

## Credits

   - Core: PicoRV32 by Clifford Wolf (YosysHQ).

   - Board: Cyclone V GX Starter Kit by Terasic.