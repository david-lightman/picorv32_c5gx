#include <stdint.h>

#define UART_ADDR 0x20000000
#define SRAM_BASE 0x10000000

void putc(char c) {
    *(volatile int*)UART_ADDR = c;
    for (volatile int i = 0; i < 2000; i++);
}

void print(const char *str) {
    while (*str) putc(*str++);
}

char to_hex(int v) {
    if (v < 10) return '0' + v;
    return 'A' + (v - 10);
}

void print_hex(unsigned int val) {
    for (int i = 7; i >= 0; i--) {
        putc(to_hex((val >> (i * 4)) & 0xF));
    }
}

int main() {
    volatile uint8_t  *sram_b = (volatile uint8_t*)SRAM_BASE;
    volatile uint16_t *sram_h = (volatile uint16_t*)SRAM_BASE;
    volatile uint32_t *sram_w = (volatile uint32_t*)SRAM_BASE;

    print("\r\n=== SRAM Byte/Half-Word Test ===\r\n");

    // Clear first word
    sram_w[0] = 0x00000000;

    // Test 1: Write Bytes [0xAA, 0xBB, 0xCC, 0xDD]
    // Memory should look like 0xDDCCBBAA (Little Endian)
    print("Writing Bytes...\r\n");
    sram_b[0] = 0xAA;
    sram_b[1] = 0xBB;
    sram_b[2] = 0xCC;
    sram_b[3] = 0xDD;

    uint32_t val = sram_w[0];
    if (val == 0xDDCCBBAA) {
        print("PASS: Byte Write / Word Read\r\n");
    } else {
        print("FAIL: Expected 0xDDCCBBAA, got 0x");
        print_hex(val);
        print("\r\n");
    }

    // Test 2: Half-Word Overwrite
    // Overwrite the upper half (0xDDCC) with 0x1234
    // Result should be 0x1234BBAA
    print("Writing Half-Word...\r\n");
    sram_h[1] = 0x1234; 

    val = sram_w[0];
    if (val == 0x1234BBAA) {
        print("PASS: Half-Word Write\r\n");
    } else {
        print("FAIL: Expected 0x1234BBAA, got 0x");
        print_hex(val);
        print("\r\n");
    }

    while(1);
    return 0;
}
