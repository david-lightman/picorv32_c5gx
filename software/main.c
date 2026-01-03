/* software/main.c */
#define UART_ADDR 0x20000000

void putc(char c) {
    *(volatile int*)UART_ADDR = c;
    for (volatile int i = 0; i < 5000; i++);
}

void print(const char *str) {
    while (*str) putc(*str++);
}

void main() {
    print("\r\n--- HELLO FROM THE SD CARD OS ---\r\n");
    print("This code is running entirely in SRAM.\r\n");
    
    int i = 0;
    while(1) {
        print("Uptime: ");
        putc('0' + i); // Print digit
        print(" seconds\r\n");
        
        i++;
        if (i > 9) i = 0; // Manual modulo (saves 500 bytes of code!)
        
        for (volatile int d = 0; d < 2000000; d++);
    }
}
