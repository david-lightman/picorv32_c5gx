module uart_full #(
    parameter SYS_CLK  = 50_000_000,
    parameter BAUDRATE = 115_200
) (
    input  wire        clk,
    input  wire        resetn,

    // CPU Interface
    input  wire        mem_valid,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output reg         mem_ready,
    output reg  [31:0] mem_rdata,

    // Physical Pins
    output reg         uart_tx,
    input  wire        uart_rx
);

    localparam CLK_DIV = SYS_CLK / BAUDRATE;

    // --- Transmit Logic ---
    reg [31:0] tx_div;
    reg [9:0]  tx_pattern;
    reg [3:0]  tx_bitcnt;
    wire       tx_busy = (tx_bitcnt != 0);

    // --- Receive Logic ---
    reg [31:0] rx_div;
    reg [3:0]  rx_bitcnt;
    reg [7:0]  rx_data;
    reg        rx_ready;
    reg [1:0]  rx_sync; // Metastability sync

    // Synchronize RX pin to local clock domain
    always @(posedge clk) rx_sync <= {rx_sync[0], uart_rx};

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            uart_tx <= 1;
            tx_bitcnt <= 0;
            rx_bitcnt <= 0;
            rx_ready <= 0;
            mem_ready <= 0;
        end else begin
            mem_ready <= 0;

            // --- Transmit State Machine ---
            if (tx_bitcnt > 0) begin
                if (tx_div > 0) tx_div <= tx_div - 1;
                else begin
                    tx_div <= CLK_DIV;
                    tx_bitcnt <= tx_bitcnt - 1;
                    uart_tx <= tx_pattern[0];
                    tx_pattern <= {1'b1, tx_pattern[9:1]};
                end
            end

            // --- Receive State Machine ---
            if (rx_bitcnt == 0) begin
                // Watch for start bit (falling edge)
                if (rx_sync == 2'b10) begin
                    rx_div <= CLK_DIV + (CLK_DIV/2); // Sample in middle of bit
                    rx_bitcnt <= 9;
                end
            end else begin
                if (rx_div > 0) rx_div <= rx_div - 1;
                else begin
                    rx_div <= CLK_DIV;
                    rx_bitcnt <= rx_bitcnt - 1;
                    if (rx_bitcnt > 1) // Bits 8-1 are data bits
                        rx_data <= {rx_sync[1], rx_data[7:1]};
                    else if (rx_bitcnt == 1) // Stop bit
                        rx_ready <= 1;
                end
            end

            // --- CPU Memory-Mapped Interface ---
            if (mem_valid && !mem_ready) begin
                case (mem_addr[3:0])
                    4'h0: begin // DATA Register
                        if (|mem_wstrb) begin // Write -> Send Char
                            if (!tx_busy) begin
                                tx_pattern <= {1'b1, mem_wdata[7:0], 1'b0};
                                tx_bitcnt <= 10;
                                tx_div <= CLK_DIV;
                            end
                        end else begin // Read -> Get Char
                            mem_rdata <= {24'b0, rx_data};
                            rx_ready <= 0; // Automatically clear flag when read
                        end
                        mem_ready <= 1;
                    end
                    4'h4: begin // STATUS Register
                        // Bit 0: RX Data Ready
                        // Bit 1: TX Buffer Busy
                        mem_rdata <= {30'b0, tx_busy, rx_ready};
                        mem_ready <= 1;
                    end
                    default: mem_ready <= 1;
                endcase
            end
        end
    end
endmodule
