module spi_controller (
    input  wire        clk,
    input  wire        resetn,

    // CPU Interface
    input  wire        mem_valid,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output reg         mem_ready,
    output reg  [31:0] mem_rdata,

    // SPI Interface
    output reg         sck,
    output reg         mosi,
    input  wire        miso,
    output reg         cs_n
);

    // State
    reg [7:0] shift_reg;
    reg [3:0] bit_count;
    reg       busy;
    
    // Clock Divider (Simplistic)
    // 0 = Fast (Divide by 2: 25MHz)
    // 124 = Slow (Divide by 250: 200kHz for Init)
    reg [7:0] clk_div_setting; 
    reg [7:0] clk_counter;
    reg       spi_clk_en;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            mem_ready <= 0;
            mem_rdata <= 0;
            sck <= 0;
            mosi <= 1;
            cs_n <= 1;
            busy <= 0;
            shift_reg <= 0;
            bit_count <= 0;
            clk_div_setting <= 8'd124; // Default slow
            clk_counter <= 0;
        end else begin
            mem_ready <= 0;
            
            // --- SPI Clock Generation ---
            spi_clk_en <= 0;
            if (busy) begin
                if (clk_counter == clk_div_setting) begin
                    clk_counter <= 0;
                    spi_clk_en <= 1; // Pulse to toggle SCK
                end else begin
                    clk_counter <= clk_counter + 1;
                end
            end

            // --- SPI Shift Logic ---
            if (busy && spi_clk_en) begin
                sck <= ~sck; // Toggle Clock
                if (sck) begin // Falling Edge (Output change)
                    mosi <= shift_reg[7];
                    shift_reg <= {shift_reg[6:0], 1'b1};
                end else begin // Rising Edge (Input sample)
                    shift_reg[0] <= miso;
                    if (bit_count == 7) begin
                        busy <= 0;
                        bit_count <= 0;
                    end else begin
                        bit_count <= bit_count + 1;
                    end
                end
            end

            // --- CPU Interface ---
            if (mem_valid && !mem_ready) begin
                // Decode Registers
                case (mem_addr[3:0])
                    4'h0: begin // DATA Register
                        if (|mem_wstrb) begin // Write
                            if (!busy) begin
                                shift_reg <= mem_wdata[7:0];
                                busy <= 1;
                                sck <= 0;
                                mosi <= mem_wdata[7]; // Setup MSB immediately
                                bit_count <= 0;
                                clk_counter <= 0;
                            end
                        end else begin // Read
                            mem_rdata <= {24'b0, shift_reg};
                        end
                        mem_ready <= 1;
                    end
                    
                    4'h4: begin // STATUS / DIVIDER Register
                        if (|mem_wstrb) begin
                            clk_div_setting <= mem_wdata[7:0];
                        end else begin
                            mem_rdata <= {31'b0, busy};
                        end
                        mem_ready <= 1;
                    end

                    4'h8: begin // CS Register
                        if (|mem_wstrb) begin
                            cs_n <= mem_wdata[0];
                        end else begin
                            mem_rdata <= {31'b0, cs_n};
                        end
                        mem_ready <= 1;
                    end
                    default: mem_ready <= 1;
                endcase
            end
        end
    end
endmodule
