// Address of the UART in our Verilog memory map
#define UART_ADDR 0x20000000

// Function to send one character
void putc(char c) {
    // Write the character to the Memory Mapped address
    *(volatile int*)UART_ADDR = c;
    
    // Software Delay:
    // The UART takes ~4340 cycles to send a byte at 115200 baud.
    // The CPU is much faster. We must wait before sending the next one.
    // (A better way is to poll a status register, but we haven't built that yet).
    for (volatile int i = 0; i < 2000; i++);
}

// Function to send a string
void print(const char *str) {
    while (*str) {
        putc(*str++);
    }
}

int main() {
    while (1) {
        print("Hello RISC-V on Cyclone V!\r\n");
        
        // Long delay between messages
        for (volatile int i = 0; i < 500000; i++);
    }
    return 0;
}
