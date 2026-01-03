module sd_spi_bridge (
    input  wire        clk,
    input  wire        resetn,
    // CPU Interface
    input  wire        mem_valid,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output reg         mem_ready,
    output reg  [31:0] mem_rdata,
    // Physical SD Pins
    output reg         sck,
    output reg         mosi,
    input  wire        miso,
    output reg         cs_n
);
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            mem_ready <= 0;
            mem_rdata <= 0;
            // Default Idle State: SCK=0, MOSI=1, CS=1
            sck <= 0; mosi <= 1; cs_n <= 1;
        end else begin
            mem_ready <= 0;
            if (mem_valid && !mem_ready) begin
                if (|mem_wstrb) begin
                    // Write to 0x30000000: Update Pins
                    // Bit 0: SCK
                    // Bit 1: MOSI
                    // Bit 2: CS_n
                    sck  <= mem_wdata[0];
                    mosi <= mem_wdata[1];
                    cs_n <= mem_wdata[2];
                end else begin
                    // Read from 0x30000000: Sample MISO
                    // Bit 0: MISO status
                    mem_rdata <= {31'b0, miso};
                end
                mem_ready <= 1;
            end
        end
    end
endmodule
