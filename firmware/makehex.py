#!/usr/bin/env python3
import sys

# Usage: python3 makehex.py firmware.bin 256 > firmware.list

if len(sys.argv) < 3:
    print("Usage: makehex.py <bin_file> <num_words>")
    sys.exit(1)

bin_file = sys.argv[1]
num_words = int(sys.argv[2])

with open(bin_file, "rb") as f:
    bindata = f.read()

# Pad with zeros
needed_bytes = num_words * 4
if len(bindata) < needed_bytes:
    bindata += b'\x00' * (needed_bytes - len(bindata))

# Process 4 bytes at a time (32-bit word)
for i in range(0, num_words * 4, 4):
    w = bindata[i:i+4]
    val = int.from_bytes(w, byteorder='little')
    # Print 32 bits of 0s and 1s
    print(f"{val:032b}")

