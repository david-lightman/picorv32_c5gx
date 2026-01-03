# software/Makefile
CC = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
CFLAGS = -march=rv32i -mabi=ilp32 -O2 -ffreestanding -nostdlib

all: kernel.bin

kernel.bin: main.c start.S sections.lds
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,sections.lds -o kernel.elf start.S main.c
	$(OBJCOPY) -O binary kernel.elf kernel.bin

clean:
	rm -f *.elf *.bin
