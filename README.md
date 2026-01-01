# picorv32_c5gx

This is a bare-metal implementaiton of [YosysHQ/picorv32](https://github.com/YosysHQ/picorv32) on the [Altera Cyclone V GX Starter Kit](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=830&PartNo=4). 

This project bridges the PicoRV32 RISC-V core with Altera's block memory architecture BRAM by implementing a bus wrapper. 

## Features

*   **Core:** PicoRV32 (RV32I Architecture) running at **50 MHz**.
*   **Memory:** 1KB On-Chip Block RAM (M10K) inferred via Verilog attributes.
*   **Bus Adapter:** used a single-cycle "wait state" to synch the native interface with synchronous FPGA memory.
*   **Debug:**
    *   **7-Segment Display:** Real-time Program Counter (PC) visualization.
    *   **LEDs:** Status monitors for Bus Activity (`mem_valid`) and CPU Traps/Crashes (`trap`) - LEDR <- `{8'b0, trap, mem_valid}`
*   Integrated Power-On Reset (POR) to hold the CPU for 256 counts to help guarantee stabilization

## Usage

### Requirements
*   Intel Quartus Prime (Lite or Standard)
*   RISC-V GCC Toolchain (`riscv64-unknown-elf-`)
*   ModelSim / Questa (Optional for simulation)

### Build & Flash
```bash
# 1. Clean previous builds
make clean

# 2. Build Firmware and Bitstream
make

# 3. Program the FPGA
make program
```

## Credits

- PicoRV32 Core: Clifford Wolf / YosysHQ

- Board: Terasic Cyclone V GX Starter Kit
