#include <stdint.h>

// --- Hardware Map ---
#define UART_DATA   (*(volatile int*)0x20000000)
#define UART_STATUS (*(volatile int*)0x20000004)

// --- Status Bits ---
#define RX_READY 0x01
#define TX_BUSY  0x02

// --- Driver Functions ---
void putc(char c) {
    // HW FLOW CONTROL: Wait until UART is not busy.
    // This perfectly fixes the text glitching.
    while (UART_STATUS & TX_BUSY);
    UART_DATA = c;
}

char getc() {
    // Wait until a character is available
    while (!(UART_STATUS & RX_READY));
    return (char)UART_DATA;
}

void print(const char *str) {
    while (*str) putc(*str++);
}

// --- Main Shell ---
void main() {
    // ANSI Escape Code to Clear Screen
    print("\033[2J\033[H"); 
    
    print("==================================\r\n");
    print("   Cyclone V RISC-V Interactive   \r\n");
    print("==================================\r\n");
    print("Hardware: UART RX/TX + Status Reg\r\n");
    print("Memory:   512KB SRAM\r\n");
    print("\r\n");
    print("Ready. Type commands below:\r\n");
    print("> ");

    char buffer[64];
    int idx = 0;

    while (1) {
        char c = getc(); // Blocking read from keyboard

        // Handle Enter (Execute)
        if (c == '\r') {
            putc('\r'); putc('\n');
            
            // Null-terminate string
            buffer[idx] = 0;
            
            if (idx == 0) {
                // Empty line
            } 
            else if (buffer[0] == 'h' && buffer[1] == 'e' && buffer[2] == 'l' && buffer[3] == 'p') {
                print("Available commands:\r\n");
                print("  help   - Show this list\r\n");
                print("  reboot - Jump back to Bootloader\r\n");
                print("  clear  - Clear screen\r\n");
            }
            else if (buffer[0] == 'r' && buffer[1] == 'e' && buffer[2] == 'b') {
                print("Rebooting system...\r\n");
                // Jump to Internal ROM (0x00000000)
                void (*boot)(void) = (void*)0x00000000;
                boot();
            }
            else if (buffer[0] == 'c' && buffer[1] == 'l' && buffer[2] == 'e') {
                print("\033[2J\033[H");
            }
            else {
                print("Unknown command: ");
                print(buffer);
                print("\r\n");
            }

            // Reset prompt
            idx = 0;
            print("> ");
        } 
        // Handle Backspace (127)
        else if (c == 127) {
            if (idx > 0) {
                idx--;
                putc('\b'); putc(' '); putc('\b'); // Visual backspace
            }
        }
        // Handle Regular Characters
        else {
            if (idx < 63) {
                buffer[idx++] = c;
                putc(c); // Echo back to user
            }
        }
    }
}

