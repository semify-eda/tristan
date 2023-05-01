// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module sky130_sram_2kbyte_1rw1r_32x512_8 (
`ifdef USE_POWER_PINS
    vccd1,
    vssd1,
`endif
    // Port 0: RW
    clk0,
    csb0,
    web0,
    wmask0,
    addr0,
    din0,
    dout0,
    // Port 1: R
    clk1,
    csb1,
    addr1,
    dout1
);

    parameter NUM_WMASKS = 4;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 9;
    parameter RAM_DEPTH = 1 << ADDR_WIDTH;

`ifdef USE_POWER_PINS
    inout vccd1;
    inout vssd1;
`endif

    input clk0;  // clock
    input csb0;  // active low chip select
    input web0;  // active low write control
    input [NUM_WMASKS-1:0] wmask0;  // write mask
    input [ADDR_WIDTH-1:0] addr0;
    input [DATA_WIDTH-1:0] din0;
    output [DATA_WIDTH-1:0] dout0;
    input clk1;  // clock
    input csb1;  // active low chip select
    input [ADDR_WIDTH-1:0] addr1;
    output [DATA_WIDTH-1:0] dout1;

    reg [DATA_WIDTH-1:0] dout0;
    reg [DATA_WIDTH-1:0]  dout1;

    logic [DATA_WIDTH-1:0] mem [RAM_DEPTH];

    // Memory Write Block Port 0
    // Write Operation : When web0 = 0, csb0 = 0
    always_ff @(posedge clk0) begin
        if (!csb0 && !web0) begin
            if (wmask0[0]) mem[addr0][7:0] <= din0[7:0];
            if (wmask0[1]) mem[addr0][15:8] <= din0[15:8];
            if (wmask0[2]) mem[addr0][23:16] <= din0[23:16];
            if (wmask0[3]) mem[addr0][31:24] <= din0[31:24];
        end
    end

    // Memory Read Block Port 0
    // Read Operation : When web0 = 1, csb0 = 0
    always_ff @(posedge clk0) begin
        if (!csb0 && web0) begin
            dout0 <= mem[addr0];
        end
    end

    // Memory Read Block Port 1
    // Read Operation : When csb1 = 0
    always_ff @(posedge clk1) begin
        if (!csb1) begin
            dout1 <= mem[addr1];
        end
    end

endmodule

module sram #(
    parameter NUM_WMASKS = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 11,
    parameter INIT_F = ""
) (
    // Port 0: RW
    input clk0,
    input csb0,
    input web0,
    input [NUM_WMASKS-1:0] wmask0,
    input [ADDR_WIDTH-1:0] addr0,
    input [DATA_WIDTH-1:0] din0,
    output reg [DATA_WIDTH-1:0] dout0,

    // Port 1: R
    input clk1,
    input csb1,
    input [ADDR_WIDTH-1:0] addr1,
    output reg [DATA_WIDTH-1:0] dout1
);

//`define SKY130

`ifdef SKY130

    localparam OPENRAM_ADDR_WIDTH = 9;

    //11 - 9 = 2 -> 2^2 = 4 instances

    localparam NUM_INSTANCES = 2**(ADDR_WIDTH - OPENRAM_ADDR_WIDTH); //11 - 9 = 2 -> 2^2 = 4 instances

    initial begin
        $display("NUM_INSTANCES %d", NUM_INSTANCES);
    end

    logic [NUM_INSTANCES-1:0] select_instance_0;
    logic [NUM_INSTANCES-1:0] select_instance_1;

    logic [NUM_INSTANCES*DATA_WIDTH-1:0] select_dout0;
    logic [NUM_INSTANCES*DATA_WIDTH-1:0] select_dout1;


    generate
        if (ADDR_WIDTH > OPENRAM_ADDR_WIDTH) begin
            assign select_instance_0 = 1'b1 << (addr0[ADDR_WIDTH-1:OPENRAM_ADDR_WIDTH]);  // addr0[10:9]
            assign select_instance_1 = 1'b1 << (addr1[ADDR_WIDTH-1:OPENRAM_ADDR_WIDTH]);  // addr1[10:9]
        end else begin
            assign select_instance_0 = 1'b1;
            assign select_instance_1 = 1'b1;
        end
    endgenerate


    initial begin
        //$monitor("select_instance_0 %b address %b", select_instance_0, addr0);
        //$monitor("addr0[ADDR_WIDTH-1:OPENRAM_ADDR_WIDTH] %b", addr0[ADDR_WIDTH-1:OPENRAM_ADDR_WIDTH]);
    end

    generate
        genvar i;
        for (i = 0; i < NUM_INSTANCES; i++) begin : memory
            sky130_sram_2kbyte_1rw1r_32x512_8 sky130_sram_2kbyte_1rw1r_32x512_8 (

`ifdef USE_POWER_PINS
                .vccd1(vccd1),  // User area 1 1.8V power
                .vssd1(vssd1),  // User area 1 digital ground
`endif

                // Port 0: RW
                .clk0  (clk0),
                .csb0  (!select_instance_0[i] || csb0),
                .web0  (web0),
                .wmask0(wmask0),
                .addr0 (addr0[OPENRAM_ADDR_WIDTH-1:0]),
                .din0  (din0),
                .dout0 (select_dout0[i*DATA_WIDTH+:DATA_WIDTH]),

                // Port 1: R
                .clk1 (clk1),
                .csb1 (!select_instance_1[i] || csb1),
                .addr1(addr1[OPENRAM_ADDR_WIDTH-1:0]),
                .dout1(select_dout1[i*DATA_WIDTH+:DATA_WIDTH])
            );
        end
    endgenerate

    generate
        if (ADDR_WIDTH > OPENRAM_ADDR_WIDTH) begin
            assign dout0 = select_dout0[addr0[ADDR_WIDTH-1:OPENRAM_ADDR_WIDTH]*DATA_WIDTH+:DATA_WIDTH];
            assign dout1 = select_dout1[addr1[ADDR_WIDTH-1:OPENRAM_ADDR_WIDTH]*DATA_WIDTH+:DATA_WIDTH];
        end else begin
            assign dout0 = select_dout0[DATA_WIDTH:0];
            assign dout1 = select_dout1[DATA_WIDTH:0];
        end
    endgenerate

`else

    localparam RAM_DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem[RAM_DEPTH];

    initial begin
        if (INIT_F != 0) begin
            $display("Initializing BRAM with: '%s'", INIT_F);
            $readmemh(INIT_F, mem);
        end
    end

    // Memory Write Block Port 0
    // Write Operation : When web0 = 0, csb0 = 0
    always_ff @(posedge clk0) begin
        if (!csb0 && !web0) begin
            if (wmask0[0]) mem[addr0][7:0] <= din0[7:0];
            if (wmask0[1]) mem[addr0][15:8] <= din0[15:8];
            if (wmask0[2]) mem[addr0][23:16] <= din0[23:16];
            if (wmask0[3]) mem[addr0][31:24] <= din0[31:24];
        end
    end

    // Memory Read Block Port 0
    // Read Operation : When web0 = 1, csb0 = 0
    always_ff @(posedge clk0) begin
        if (!csb0 && web0) begin
            dout0 <= mem[addr0];
        end
    end

    // Memory Read Block Port 1
    // Read Operation : When csb1 = 0
    always_ff @(posedge clk1) begin
        if (!csb1) begin
            dout1 <= mem[addr1];
        end
    end

`endif

endmodule
