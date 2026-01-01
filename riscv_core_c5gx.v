/*
  RISC-V Core Module for C5GX 
    Copyright (C) 2024  github.com/david-lightman

    Based on PicoRV32 by Clifford Wolf; PicoRV32 - Copyright (C) 2021-2024  Clifford Wolf <clifford.wolf@example.com>

    RISC-V Core Module for C5GX is free software. You can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. 

    RISC-V Core Module for C5GX is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with RISC-V Core Module for C5GX.  If not, see <http://www.gnu.org/licenses/>.
*/

module riscv_core_c5gx (
    input  wire         i_clk_50mhz,
    input  wire         i_reset_n,

    // 7-seg for memory address display (active-low for terasic boards)
    output wire [6:0]   o_hex0,
    output wire [6:0]   o_hex1,
    output wire [6:0]   o_hex2,
    output wire [6:0]   o_hex3,     // upper nibble

    // trap
    output wire [9:0]   o_trap,

    // UART
    output wire o_tx,
    input  wire i_rx
);

    // reset handling -- POR to ensure stable reset on startup
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

    // picoRV32 CPU signals
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    wire cpu_trap;

    // address decoding
    wire is_ram      = (mem_addr[31:24] == 8'h00);
    wire is_uart     = (mem_addr[31:24] == 8'h20);

    // picoRV32 core instantiation
    picorv32 #(
        .STACKADDR(32'h0000_0400),
        .PROGADDR_RESET(32'h0000_0000),
        .ENABLE_COUNTERS(0),
        .ENABLE_REGS_16_31(1)
    ) cpu_u (
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

    // m10k RAM instantiation 
    `ifdef ALTERA_RESERVED_QIS
        (* ramstyle = "M10K" *) 
    `endif
    reg [31:0] mem[0:255];

    initial begin
        $readmemb("firmware.list", mem);
    end

    // RAM write logic
    wire [31:0] mem_rdata_out = mem[mem_addr[9:2]];
    always @(posedge i_clk_50mhz) begin
        if (mem_valid && is_ram && |mem_wstrb) begin
            if (mem_wstrb[0]) mem[mem_addr[9:2]][ 7: 0] <= mem_wdata[ 7: 0];
            if (mem_wstrb[1]) mem[mem_addr[9:2]][15: 8] <= mem_wdata[15: 8];
            if (mem_wstrb[2]) mem[mem_addr[9:2]][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) mem[mem_addr[9:2]][31:24] <= mem_wdata[31:24];
        end
    end

    // uart instantiation
    wire uart_busy;
    simpleuart u_uart (
        .clk         (i_clk_50mhz),
        .resetn      (~r_system_reset),
        .ser_tx      (mem_wdata[7:0]),
        .ser_tx_we   (mem_valid && is_uart && |mem_wstrb),
        .ser_tx_busy (uart_busy),
        .ser_tx_done (/*not used*/),
        .uart_tx     (o_tx)
    );

    reg r_mem_ready;
    // memory read/write logic
    // the intent of this is to handle RAM on the FPGA - picoRV32 expects a simple synchronous RAM
    // interface. This should "freeze" the CPU while memory operations are in progress.
    always @(posedge i_clk_50mhz) begin
        if (r_system_reset) begin
            r_mem_ready <= 0;
        end else begin
            r_mem_ready <= 0;
            if (mem_valid && !r_mem_ready) r_mem_ready <= 1; 
        end
    end

    assign mem_ready = r_mem_ready;

    // read data mux - uart not implemented yet
    assign mem_rdata = is_ram ? mem_rdata_out : 32'h0000_0000;


    // DEBUG OUTPUTS 

    // debug: pc -> 7seg
    // mem_addr is byte address. Shift by 2 to get word address.
    // HEX0 shows bits [3:0]
    hex_decoder hex0_u (
        .in  (mem_addr[3:0]),
        .out (o_hex0)
    );
    // HEX1 shows bits [7:4]
    hex_decoder hex1_u (
        .in  (mem_addr[7:4]),
        .out (o_hex1)
    );
    // HEX2 shows bits [11:8]
    hex_decoder hex2_u (
        .in  (mem_addr[11:8]),
        .out (o_hex2)
    );
    // HEX3 shows bits [15:12]
    hex_decoder hex3_u (
        .in  (mem_addr[15:12]),
        .out (o_hex3)
    );

    // LEDR[0] = TRAP (cpu halt)
    // LEDR[1] = MEM VALID (signal that memory access is requested)
    assign o_trap = {8'b0, cpu_trap, mem_valid};

endmodule