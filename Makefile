# ==============================================================================
# FPGA Project Makefile for Altera Cyclone V GX Starter Kit
# ==============================================================================

PROJECT   := riscv_core_c5gx
TOP_LEVEL := baseline_c5gx
PART      := 5CGXFC5C6F27C7
OUT_DIR   := output_files
SOF_FILE  := $(OUT_DIR)/$(PROJECT).sof

# Tools
QUARTUS_SH  ?= quartus_sh
QUARTUS_PGM ?= quartus_pgm
VLOG        ?= vlog
VSIM        ?= vsim

# ------------------------------------------------------------------------------
# Firmware Configuration
# ------------------------------------------------------------------------------
FW_DIR      := firmware
RISCV_PREFIX ?= riscv64-unknown-elf-
GCC         := $(RISCV_PREFIX)gcc
OBJCOPY     := $(RISCV_PREFIX)objcopy
CFLAGS      := -march=rv32i -mabi=ilp32 -O2 -ffreestanding -nostdlib -lgcc

# Artifacts
ELF_FILE    := $(FW_DIR)/firmware.elf
BIN_FILE    := $(FW_DIR)/firmware.bin
LIST_FILE   := firmware.list

# Firmware Sources (Using verify.S for now)
FW_SRCS     := $(FW_DIR)/verify.S
# FW_SRCS   := $(FW_DIR)/start.S $(FW_DIR)/main.c  <-- Switch back to this later
LDSCRIPT    := $(FW_DIR)/sections.lds
MAKEHEX     := $(FW_DIR)/makehex.py

# ==============================================================================
# Targets
# ==============================================================================

.PHONY: all compile sim sim-gui program upload clean help

# Default: Build Firmware -> Then Hardware
all: $(LIST_FILE) compile

# ---------
# Firmware build
# ---------
$(LIST_FILE): $(FW_SRCS) $(LDSCRIPT) $(MAKEHEX)
	@echo "--- Compiling Firmware (Binary List) ---"
	$(GCC) $(CFLAGS) -Wl,-Bstatic,-T,$(LDSCRIPT) -o $(ELF_FILE) $(FW_SRCS)
	$(OBJCOPY) -O binary $(ELF_FILE) $(BIN_FILE)
	python3 $(MAKEHEX) $(BIN_FILE) 256 > $(LIST_FILE)
	@echo "Success! $(LIST_FILE) generated."

# ------------------------------------------------------------------------------
# Hardware Compilation 
# ------------------------------------------------------------------------------
compile: $(LIST_FILE)
	@echo "--- Configuring Output Directory ---"
	#$(QUARTUS_SH) --tcl_eval "project_open $(PROJECT); set_global_assignment -name PROJECT_OUTPUT_DIRECTORY $(OUT_DIR); export_assignments"
	@echo "--- Starting Quartus Compilation ---"
	$(QUARTUS_SH) --flow compile $(PROJECT)

# ------------------------------------------------------------------------------
# Programming
# ------------------------------------------------------------------------------
program:
	@echo "--- Programming FPGA ---"
	$(QUARTUS_PGM) -m jtag -o "p;$(SOF_FILE)@1"

upload: program

# ------------------------------------------------------------------------------
# Simulation
# ------------------------------------------------------------------------------
SRCS   := picorv32.v riscv_core_c5gx.v hex_decoder.v
TB_SRC := tb.v

work:
	vlib work

libs: work
	@echo "--- Compiling Simulation Sources ---"
	$(VLOG) $(SRCS) $(TB_SRC)

sim: libs
	@echo "--- Running Simulation (Batch Mode) ---"
	$(VSIM) -c -do "run 10 us; quit" tb

sim-gui: libs
	@echo "--- Opening Simulation GUI ---"
	$(VSIM) -gui -do "add wave -position insertpoint sim:/tb/dut/*; run 10 us" tb

# ------------------------------------------------------------------------------
#  Utilities
# ------------------------------------------------------------------------------
clean:
	@echo "--- make clean running ---"
	rm -rf db incremental_db $(OUT_DIR) simulation work transcript *.wlf
	rm -f $(ELF_FILE) $(BIN_FILE) $(LIST_FILE) firmware.hex
	mkdir -p $(OUT_DIR)

help:
	@echo "Targets: all, compile, program, sim, clean"
