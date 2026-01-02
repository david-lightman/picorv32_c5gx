module sram_controller (
    input  wire        clk,
    input  wire        resetn,

    // PicoRV32 Memory Interface
    input  wire        mem_valid,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output reg         mem_ready,
    output reg  [31:0] mem_rdata,

    // SRAM Physical Interface
    output reg  [17:0] SRAM_A,
    inout  wire [15:0] SRAM_D,
    output reg         SRAM_CE_n,
    output reg         SRAM_OE_n,
    output reg         SRAM_WE_n,
    output reg         SRAM_LB_n,
    output reg         SRAM_UB_n
);

    // Bi-directional data bus handling
    reg [15:0] sram_dq_out;
    reg        sram_dq_oe;
    assign SRAM_D = sram_dq_oe ? sram_dq_out : 16'bz;

    // Internal registers
    reg [15:0] data_latch_low;
    
    // State Machine
    reg [3:0] state;
    localparam S_IDLE       = 4'd0;
    localparam S_READ_1     = 4'd1;
    localparam S_READ_2     = 4'd2;
    localparam S_READ_3     = 4'd3;
    localparam S_WRITE_1    = 4'd4;
    localparam S_WRITE_2    = 4'd5;
    localparam S_WRITE_3    = 4'd6;
    localparam S_WRITE_4    = 4'd7;
    localparam S_DONE       = 4'd8;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= S_IDLE;
            mem_ready <= 0;
            mem_rdata <= 0;
            SRAM_CE_n <= 1;
            SRAM_OE_n <= 1;
            SRAM_WE_n <= 1;
            SRAM_LB_n <= 1;
            SRAM_UB_n <= 1;
            sram_dq_oe <= 0;
            SRAM_A <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    mem_ready <= 0;
                    sram_dq_oe <= 0;
                    SRAM_WE_n <= 1;
                    SRAM_OE_n <= 1;
                    SRAM_CE_n <= 1;
                    SRAM_LB_n <= 1;
                    SRAM_UB_n <= 1;

                    if (mem_valid) begin
                        // Map 32-bit byte address to 16-bit word address
                        SRAM_A <= mem_addr[18:1]; 
                        SRAM_CE_n <= 0; // Enable SRAM
                        
                        if (|mem_wstrb) begin
                            // Write Operation
                            // Check if we need to write the lower 16 bits
                            if (|mem_wstrb[1:0]) begin
                                sram_dq_out <= mem_wdata[15:0];
                                sram_dq_oe <= 1;
                                SRAM_LB_n <= ~mem_wstrb[0];
                                SRAM_UB_n <= ~mem_wstrb[1];
                                state <= S_WRITE_1; // Start Write Cycle for Low Word
                            end else begin
                                // Skip Low Word, setup for High Word
                                SRAM_A <= mem_addr[18:1] + 18'd1;
                                
                                // load high-word data and strobes
                                sram_dq_out <= mem_wdata[31:16]; 
                                sram_dq_oe <= 1;
                                SRAM_LB_n <= ~mem_wstrb[2];
                                SRAM_UB_n <= ~mem_wstrb[3];
                                
                                state <= S_WRITE_3; 
                            end
                        end else begin
                            // Read Operation
                            SRAM_OE_n <= 0;
                            SRAM_LB_n <= 0; 
                            SRAM_UB_n <= 0; 
                            state <= S_READ_1;
                        end
                    end
                end

                // --- READ SEQUENCE (2 Words) ---
                S_READ_1: begin
                    state <= S_READ_2;
                end

                S_READ_2: begin
                    // Latch Lower 16 bits
                    data_latch_low <= SRAM_D;
                    // Setup Address for Upper 16 bits
                    SRAM_A <= mem_addr[18:1] + 18'd1;
                    state <= S_READ_3;
                end

                S_READ_3: begin
                    // Latch Upper 16 bits and Finish
                    mem_rdata <= {SRAM_D, data_latch_low};
                    SRAM_CE_n <= 1;
                    SRAM_OE_n <= 1;
                    mem_ready <= 1;
                    state <= S_DONE;
                end

                // --- WRITE SEQUENCE (2 Words) ---
                // Write Low Word Pulse
                S_WRITE_1: begin
                    SRAM_WE_n <= 0; // Assert WE
                    state <= S_WRITE_2;
                end

                S_WRITE_2: begin
                    SRAM_WE_n <= 1; // Deassert WE
                    // Setup High Word
                    SRAM_A <= mem_addr[18:1] + 18'd1;
                    
                    if (|mem_wstrb[3:2]) begin
                        sram_dq_out <= mem_wdata[31:16];
                        SRAM_LB_n <= ~mem_wstrb[2];
                        SRAM_UB_n <= ~mem_wstrb[3];
                        state <= S_WRITE_3;
                    end else begin
                        // No high word to write
                        SRAM_CE_n <= 1;
                        mem_ready <= 1;
                        state <= S_DONE;
                    end
                end

                // Write High Word Pulse
                S_WRITE_3: begin
                    sram_dq_oe <= 1; // Ensure drive
                    SRAM_WE_n <= 0;  // Assert WE
                    state <= S_WRITE_4;
                end

                S_WRITE_4: begin
                    SRAM_WE_n <= 1;  // Deassert WE
                    SRAM_CE_n <= 1;
                    mem_ready <= 1;
                    state <= S_DONE;
                end

                S_DONE: begin
                    mem_ready <= 0;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
