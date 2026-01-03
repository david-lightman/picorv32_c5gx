module riscv_core_c5gx (
    input  wire         i_clk_50mhz,
    input  wire         i_reset_n,
    // 7-seg for memory address display
    output wire [6:0]   o_hex0,
    output wire [6:0]   o_hex1,
    output wire [6:0]   o_hex2,
    output wire [6:0]   o_hex3,
    // trap and LEDs
    output wire [9:0]   o_trap,
    // UART
    output wire         o_tx,
    input  wire         i_rx,
    // SD Card SPI Interface
    output wire         o_sd_clk,
    output wire         o_sd_mosi,
    input  wire         i_sd_miso,
    output wire         o_sd_cs_n,
    // SRAM Interface
    output wire [17:0]  SRAM_A,
    inout  wire [15:0]  SRAM_D,
    output wire         SRAM_CE_n,
    output wire         SRAM_OE_n,
    output wire         SRAM_WE_n,
    output wire         SRAM_LB_n,
    output wire         SRAM_UB_n
);

    // Reset Logic
    reg [7:0] r_reset_cnt = 8'h00;
    reg       r_system_reset;
    always @(posedge i_clk_50mhz) begin
        if (r_reset_cnt < 255) begin
            r_reset_cnt <= r_reset_cnt + 1;
            r_system_reset <= 1'b1;
        end else begin
            r_system_reset <= ~i_reset_n;
        end
    end

    // PicoRV32 Signals
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;
    wire        cpu_trap;

    // Address Decoding
    wire is_ram  = (mem_addr[31:24] == 8'h00); // Internal BRAM (Boot)
    wire is_sram = (mem_addr[31:24] == 8'h10); // External SRAM (0x10000000)
    wire is_uart = (mem_addr[31:24] == 8'h20); // UART (0x20000000)
    wire is_spi  = (mem_addr[31:24] == 8'h30); // SPI (0x30000000)

    // --- Internal RAM ---
    `ifdef ALTERA_RESERVED_QIS
        (* ramstyle = "M10K" *) 
    `endif
    reg [31:0] mem[0:255];
    initial begin
        $readmemb("firmware.list", mem);
    end
    
    reg [31:0] ram_rdata;
    reg        ram_ready;
    always @(posedge i_clk_50mhz) begin
        ram_ready <= 0;
        if (mem_valid && is_ram) begin
            if (|mem_wstrb) begin
                if (mem_wstrb[0]) mem[mem_addr[9:2]][ 7: 0] <= mem_wdata[ 7: 0];
                if (mem_wstrb[1]) mem[mem_addr[9:2]][15: 8] <= mem_wdata[15: 8];
                if (mem_wstrb[2]) mem[mem_addr[9:2]][23:16] <= mem_wdata[23:16];
                if (mem_wstrb[3]) mem[mem_addr[9:2]][31:24] <= mem_wdata[31:24];
            end else begin
                ram_rdata <= mem[mem_addr[9:2]];
            end
            ram_ready <= 1; // 1 cycle wait
        end
    end

    // --- SRAM Controller ---
    wire        sram_ready;
    wire [31:0] sram_rdata;
    sram_controller u_sram (
        .clk        (i_clk_50mhz),
        .resetn     (~r_system_reset),
        // Connect to PicoRV32 only if address matches SRAM
        .mem_valid  (mem_valid && is_sram), 
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_ready  (sram_ready),
        .mem_rdata  (sram_rdata),
        // Physical Pins
        .SRAM_A     (SRAM_A),
        .SRAM_D     (SRAM_D),
        .SRAM_CE_n  (SRAM_CE_n),
        .SRAM_OE_n  (SRAM_OE_n),
        .SRAM_WE_n  (SRAM_WE_n),
        .SRAM_LB_n  (SRAM_LB_n),
        .SRAM_UB_n  (SRAM_UB_n)
    );

    // SD Card SPI Controller
    wire        spi_ready;
    wire [31:0] spi_rdata;
    sd_spi_bridge u_spi (
        .clk        (i_clk_50mhz),
        .resetn     (~r_system_reset),
        // Connect memory interface only when address matches 0x30...
        .mem_valid  (mem_valid && is_spi),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_ready  (spi_ready),
        .mem_rdata  (spi_rdata),
        // Physical Pins
        .sck        (o_sd_clk),
        .mosi       (o_sd_mosi),
        .miso       (i_sd_miso),
        .cs_n       (o_sd_cs_n)
    );

    // --- UART ---
    wire        uart_ready;
    wire [31:0] uart_rdata;
    uart_full #(
        .SYS_CLK    (50_000_000),
        .BAUDRATE   (115_200)
    ) u_uart (
        .clk         (i_clk_50mhz),
        .resetn      (~r_system_reset),
        // Connect memory interface
        .mem_valid   (mem_valid && is_uart),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_ready   (uart_ready),
        .mem_rdata   (uart_rdata),
        // Physical Pins
        .uart_tx     (o_tx),
        .uart_rx     (i_rx)
    );

    // --- Memory Mux ---
    // Combine Ready signals
    // Note: All peripherals must provide a ready signal to the mux to prevent CPU hang.
    assign mem_ready = (is_ram  ? ram_ready  : 0) | 
                       (is_sram ? sram_ready : 0) | 
                       (is_spi  ? spi_ready  : 0) | 
                       (is_uart ? uart_ready : 0);

    assign mem_rdata = is_ram  ? ram_rdata  : 
                       is_sram ? sram_rdata : 
                       is_spi  ? spi_rdata  : 
                       is_uart ? uart_rdata :
                       32'h0000_0000;

    // --- CPU ---
    picorv32 #(
        .STACKADDR(32'h0000_0400),
        .PROGADDR_RESET(32'h0000_0000),
        .ENABLE_COUNTERS(0),
        .ENABLE_REGS_16_31(1)
    ) u0 (
        .clk         (i_clk_50mhz),
        .resetn      (~r_system_reset),
        .mem_valid   (mem_valid),
        .mem_instr   (mem_instr),
        .mem_ready   (mem_ready),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_rdata   (mem_rdata),
        .trap        (cpu_trap),
        .irq(32'b0), .pcpi_ready(0), .pcpi_wr(0), .pcpi_wait(0),
        .mem_la_read(), .mem_la_write(), .mem_la_addr(), .mem_la_wdata(), .mem_la_wstrb(),
        .trace_valid(), .trace_data()
    );

    // Debug
    hex_decoder hex0_u (.in(mem_addr[3:0]),   .out(o_hex0));
    hex_decoder hex1_u (.in(mem_addr[7:4]),   .out(o_hex1));
    hex_decoder hex2_u (.in(mem_addr[11:8]),  .out(o_hex2));
    hex_decoder hex3_u (.in(mem_addr[15:12]), .out(o_hex3));
    
    assign o_trap = {8'b0, cpu_trap, mem_valid};

endmodule
