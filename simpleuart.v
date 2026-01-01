/* 
 *
 * Simple UART Transmitter Module
 *
 * Copyright (C) 2024  Clifford Wolf <o
 */

module simpleuart (
    input clk,
    input resetn,

    // Bus Interface
    input  [7:0]  ser_tx,      // Data to send (bottom 8 bits used)
    input         ser_tx_we,   // Write Enable (Pulse high to send)
    output        ser_tx_busy, // High while sending
    output        ser_tx_done, // High for 1 cycle when done

    // Physical Pin
    output reg    uart_tx
);
    // Config: 50MHz Clock / 115200 Baud = ~434 cycles per bit
    parameter [31:0] CLK_DIV = 434;

    reg [31:0] send_div;
    reg [9:0]  send_pattern;
    reg [3:0]  send_bitcnt;
    reg        send_dummy;

    assign ser_tx_busy = (send_bitcnt != 0);
    assign ser_tx_done = (send_bitcnt == 0) && send_dummy;

    always @(posedge clk) begin
        if (!resetn) begin
            send_pattern <= ~0;
            send_bitcnt  <= 0;
            send_div     <= 0;
            send_dummy   <= 1;
            uart_tx      <= 1;
        end else begin
            send_dummy <= 0;
            if (ser_tx_we && !ser_tx_busy) begin
                // Start Bit (0) + Data + Stop Bit (1)
                send_pattern <= {1'b1, ser_tx[7:0], 1'b0};
                send_bitcnt  <= 10;
                send_div     <= CLK_DIV;
            end else if (send_div > 0) begin
                send_div <= send_div - 1;
            end else if (send_bitcnt > 0) begin
                send_div     <= CLK_DIV;
                send_bitcnt  <= send_bitcnt - 1;
                // Shift data out
                uart_tx      <= send_pattern[0];
                send_pattern <= {1'b1, send_pattern[9:1]};
            end else begin
                // Idle state: Line High
                uart_tx <= 1; 
            end
        end
    end
endmodule
