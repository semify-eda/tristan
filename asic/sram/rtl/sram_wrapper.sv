// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`default_nettype none

module sram_wrapper #(
    parameter NUM_WMASKS = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 11,
    parameter ADDR_WIDTH_DEFAULT = 9,
    parameter ADDR_UPPER_BITS = ADDR_WIDTH - ADDR_WIDTH_DEFAULT,
    parameter NUM_INSTANCES = 2**ADDR_UPPER_BITS
) (

    // --- Connections to SoC ---

    // Port 0: RW
    input                    soc_clk0,
    input                    soc_csb0,
    input                    soc_web0,
    input  [NUM_WMASKS-1:0]  soc_wmask0,
    input  [ADDR_WIDTH-1:0]  soc_addr0,
    input  [DATA_WIDTH-1:0]  soc_din0,
    output [DATA_WIDTH-1:0]  soc_dout0,

    // Port 1: R
    input                    soc_clk1,
    input                    soc_csb1,
    input  [ADDR_WIDTH-1:0]  soc_addr1,
    output [DATA_WIDTH-1:0]  soc_dout1,
    
    // --- Connections to SRAM macros ---

    // Port 0: RW
    output [NUM_INSTANCES-1:0]                          clk0,
    output [NUM_INSTANCES-1:0]                          csb0,
    output [NUM_INSTANCES-1:0]                          web0,
    output [(NUM_INSTANCES*NUM_WMASKS)-1:0]             wmask0,
    output [(NUM_INSTANCES*ADDR_WIDTH_DEFAULT)-1:0]     addr0,
    output [(NUM_INSTANCES*DATA_WIDTH)-1:0]             din0,
    input  [(NUM_INSTANCES*DATA_WIDTH)-1:0]             dout0,

    // Port 1: R
    output [NUM_INSTANCES-1:0]                          clk1,
    output [NUM_INSTANCES-1:0]                          csb1,
    output [(NUM_INSTANCES*ADDR_WIDTH_DEFAULT)-1:0]     addr1,
    input  [(NUM_INSTANCES*DATA_WIDTH)-1:0]             dout1
);

    // Extract the upper part of the address used for enabling individual macros
    // and for receiving the correct dout
    logic [ADDR_UPPER_BITS-1:0] upper_addr_port0;
    logic [ADDR_UPPER_BITS-1:0] upper_addr_port1;

    assign upper_addr_port0 = soc_addr0[ADDR_WIDTH-1:ADDR_WIDTH_DEFAULT];
    assign upper_addr_port1 = soc_addr1[ADDR_WIDTH-1:ADDR_WIDTH_DEFAULT];

    // Delay address signals to output correct dout one cycle later
    logic [ADDR_UPPER_BITS-1:0] upper_addr_port0_d;
    logic [ADDR_UPPER_BITS-1:0] upper_addr_port1_d;

    always_ff @(posedge soc_clk0) begin
        upper_addr_port0_d <= upper_addr_port0;
    end

    always_ff @(posedge soc_clk1) begin
        upper_addr_port1_d <= upper_addr_port1;
    end
    
    // Enable the individual ports of the SRAM macros based on the address
    logic [NUM_INSTANCES-1:0] enable_port0;
    logic [NUM_INSTANCES-1:0] enable_port1;

    generate
    
        // Forward signals to each SRAM macro
        for (genvar i=0; i<NUM_INSTANCES; i++) begin
        
            assign enable_port0[i] = upper_addr_port0 == i;
            assign enable_port1[i] = upper_addr_port1 == i;
        
            assign clk0[i]   = soc_clk0;
            assign csb0[i]   = soc_csb0 || !enable_port0;
            assign web0[i]   = soc_web0;
            assign wmask0[i * NUM_WMASKS+:NUM_WMASKS] = soc_wmask0;
            assign addr0[i * ADDR_WIDTH_DEFAULT+:ADDR_WIDTH_DEFAULT]  = soc_addr0;
            assign din0[i * DATA_WIDTH+:DATA_WIDTH]   = soc_din0;
            
            assign clk1[i]   = soc_clk1;
            assign csb1[i]   = soc_csb1 || !enable_port1;
            assign addr1[i * ADDR_WIDTH_DEFAULT+:ADDR_WIDTH_DEFAULT]  = soc_addr1;
        end
    
    endgenerate
    
    assign soc_dout0 = dout0[upper_addr_port0_d * DATA_WIDTH+:DATA_WIDTH];
    assign soc_dout1 = dout1[upper_addr_port1_d * DATA_WIDTH+:DATA_WIDTH];

endmodule
