`timescale 1ns / 1ps

module tb;

    // 1. Inputs to DUT
    reg clk;
    reg reset_n;
    
    // 2. Outputs from DUT
    wire [6:0] hex0, hex1, hex2, hex3;
    wire tx, rx;

    // 3. Instantiate the Device Under Test (Wrapper)
    // NOTE: We simulate the logic wrapper, NOT the board top-level
    // because simulating physical pins requires complex board models.
    riscv_core_c5gx dut (
        .i_clk_50mhz (clk),
        .i_reset_n   (reset_n),
        .o_hex0      (hex0),
        .o_hex1      (hex1),
        .o_hex2      (hex2),
        .o_hex3      (hex3),
        .tx          (tx),
        .rx          (rx)
    );

    // 4. Clock Generation (50 MHz = 20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // 5. Test Sequence
    initial begin
        $display("--- Simulation Start ---");
        
        // Reset Logic
        reset_n = 1; 
        #50;
        reset_n = 0; // Press reset button (Active Low)
        #100;
        reset_n = 1; // Release reset button
        $display("--- Reset Released ---");

        // Let it run for a while
        #5000;
        
        $display("--- Simulation End ---");
        $finish;
    end

endmodule

