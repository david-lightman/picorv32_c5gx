/*
  RISC-V Core Module for C5GX 
    Copyright (C) 2021-2024  Clifford Wolf <clifford.wolf@example.com>
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

  Modified for C5GX by github.com/david-lightman
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
    output wire tx,
    output wire rx
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

    // bus
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    wire cpu_trap;
    // picoRV32 core instantiation
    picorv32 #(
        .STACKADDR(32'h0000_0400),
        .ENABLE_COUNTERS(0),
        .ENABLE_REGS_16_31(1),
        .PROGADDR_RESET(32'h0000_0000)
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

        // tie down critical unused inputs
        .irq         (32'b0),
        .pcpi_ready  (1'b0),
        .pcpi_wr     (1'b0),
        .pcpi_wait   (1'b0),
        
        // others disconnected, but accounted for
        .mem_la_read (),
        .mem_la_write(),
        .mem_la_addr (),
        .mem_la_wdata(),
        .mem_la_wstrb(),
        .trace_valid (),
        .trace_data  (),
        .trap        (cpu_trap) // 
    );

    // m10k RAM instantiation 
    `ifdef ALTERA_RESERVED_QIS
        (* ramstyle = "M10K" *) 
    `endif
    reg [31:0] mem[0:255];

    initial begin
        $readmemb("firmware.list", mem);
    end

    reg r_mem_ready;
    assign mem_ready = r_mem_ready;
    wire [31:0] word_addr = mem_addr >> 2;

    // memory read/write logic
    // the intent of this is to handle RAM on the FPGA - picoRV32 expects a simple synchronous RAM
    // interface. This should "freeze" the CPU while memory operations are in progress.
    always @(posedge i_clk_50mhz) begin
        if (r_system_reset) begin
            r_mem_ready <= 0;
        end else begin
            r_mem_ready <= 0;
            if (mem_valid && !r_mem_ready) begin
                if (word_addr < 256) begin
                    if (|mem_wstrb) begin
                        if (mem_wstrb[0]) mem[word_addr][ 7: 0] <= mem_wdata[ 7: 0];
                        if (mem_wstrb[1]) mem[word_addr][15: 8] <= mem_wdata[15: 8];
                        if (mem_wstrb[2]) mem[word_addr][23:16] <= mem_wdata[23:16];
                        if (mem_wstrb[3]) mem[word_addr][31:24] <= mem_wdata[31:24];
                    end
                    r_mem_ready <= 1; 
                end else begin
                    r_mem_ready <= 1; // Ack bus error
                end
            end
        end
    end

    assign mem_rdata = (word_addr < 256) ? mem[word_addr] : 32'h0000_0000;


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
