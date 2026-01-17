#include <stdint.h>

// --- Hardware Map ---
#define SD_PORT   (*(volatile int*)0x30000000)
#define UART      (*(volatile int*)0x20000000)
#define SRAM_BASE ((volatile uint8_t*)0x10000000)

// --- Constants ---
#define PIN_SCK  1
#define PIN_MOSI 2
#define PIN_CS   4

// --- Helpers ---
void putc(char c) {
    UART = c;
    for (volatile int i = 0; i < 2000; i++);
}

void print_hex(uint8_t v) {
    static const char h[] = "0123456789ABCDEF";
    putc(h[v >> 4]); putc(h[v & 0xF]);
}

uint8_t spi_byte(uint8_t out) {
    uint8_t in = 0;
    for (int i = 7; i >= 0; i--) {
        int bit = (out >> i) & 1;
        int mosi_mask = bit ? PIN_MOSI : 0;
        SD_PORT = mosi_mask;            
        SD_PORT = mosi_mask | PIN_SCK;  
        if (SD_PORT & 1) in |= (1 << i);
    }
    SD_PORT = PIN_MOSI;
    return in;
}

uint8_t sd_cmd(uint8_t cmd, uint32_t arg, uint8_t crc) {
    SD_PORT = PIN_MOSI; 
    spi_byte(cmd | 0x40);
    spi_byte(arg >> 24); spi_byte(arg >> 16); spi_byte(arg >> 8); spi_byte(arg);
    spi_byte(crc);
    uint8_t r = 0xFF;
    for (int i = 0; i < 16; i++) {
        r = spi_byte(0xFF);
        if ((r & 0x80) == 0) break;
    }
    return r;
}

int main() {
    putc('>'); putc(' ');

    // 1. Wakeup
    SD_PORT = PIN_CS | PIN_MOSI;
    for (int i = 0; i < 10; i++) spi_byte(0xFF);

    // 2. Init Sequence (CMD0 -> CMD8 -> ACMD41)
    if (sd_cmd(0, 0, 0x95) != 0x01) goto fail;
    
    sd_cmd(8, 0x1AA, 0x87); // Optional, ignore result
    spi_byte(0xFF); spi_byte(0xFF); spi_byte(0xFF); spi_byte(0xFF); // Flush R7

    int retries = 20000;
    while (retries--) {
        sd_cmd(55, 0, 0xFF);
        if (sd_cmd(41, 0x40000000, 0xFF) == 0x00) break;
    }
    if (retries <= 0) goto fail;

    // 3. Load Kernel
    // We read 128 Sectors (128 * 512 bytes = 64KB)
    // Starting at Sector 1 (Offset 512) to protect the Partition Table at Sector 0
    putc('L'); putc('O'); putc('A'); putc('D'); putc('\r'); putc('\n');
    
    volatile uint8_t *ram = SRAM_BASE;
    
    // skip first sector (MBR)
    //  512 bytes per sector
    for (int sec = 1; sec <= 128; sec++) {
        // CMD17: Read a block (512 bytes)
        if (sd_cmd(17, sec, 0xFF) != 0x00) goto fail;
        
        // Wait for Data Token (0xFE) = READY
        while (spi_byte(0xFF) != 0xFE);
        
        // data token is ready, next block on the wire
        // is your data
        for (int i = 0; i < 512; i++) {
            *ram++ = spi_byte(0xFF); // 0xFF = dummy byte
                                     //  keps MOSI high and shifts in data from MISO
        }
        
        // Read CRC (Discard)
        spi_byte(0xFF); spi_byte(0xFF);
        
        // Progress indicator every 16 sectors
        if ((sec & 15) == 0) putc('.');
    }

    // 4. Jump
    putc('\r'); putc('\n');
    putc('B'); putc('O'); putc('O'); putc('T'); putc('!'); putc('\r'); putc('\n');
    
    // Cast integer 0x10000000 to a function pointer and call it
    //  or - create a variable named kernel that points to a function
    //  located at address 0x10000000 and call it.
    // (void*) - "trust me" that this is a valid function pointer
    void (*kernel)(void) = (void*)0x10000000;
    kernel();

    // Dead loop if kernel returns
    while(1);

fail:
    putc('E'); putc('R'); putc('R');
    while(1);
    return 0;
}
