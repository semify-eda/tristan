`timescale 1ns / 1ps

module simple_timer_tb;

    localparam WIDTH = 8;
    
    logic clk_i, rst_n_i, load_i, en_i;
	logic [WIDTH - 1:0] d_i;
    logic tick_o;
    logic [WIDTH - 1:0] q_o;
    
    simple_timer #(
        .WIDTH  (WIDTH)         
    )simple_timer(
        .clk_i      (clk_i),
        .rst_n_i    (rst_n_i),
		.load_i		(load_i),
		.d_i		(d_i),
        .en_i       (en_i),
        
        .tick_o     (tick_o),
        .q_o        (q_o)    
    );

    // Dump waves
    `ifndef VERILATOR
        initial begin
        $dumpfile("simple_timer.vcd");
        $dumpvars();
        end
    `endif

endmodule
