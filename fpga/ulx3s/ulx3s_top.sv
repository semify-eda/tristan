// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps
`default_nettype none

module ulx3s_top (
    input clk_25mhz,

    input  ftdi_txd,
    output ftdi_rxd,

    input  [6:0] btn,
    output [7:0] led,
    
    output [27:0] gp
);

    logic clk;
    logic reset_n;

    assign clk = clk_25mhz;
    assign reset_n = btn[0];

    logic [23-1:0] counter;

    // Health indicator
    always_ff @(posedge clk, negedge reset_n) begin
        if (!reset_n) begin
            counter <= '0;
        end else begin
            counter <= counter + 1;
        end
    end
    
    assign led[1] = counter[23-1];
    assign led[0] = blinky;
    
    // For measurements
    logic blinky;
    assign gp = {blinky, 27'b0};

    localparam CLK_FREQ = 25_000_000;
    localparam BAUDRATE = 115200;
    localparam SOC_ADDR_WIDTH    =  32;
    localparam RAM_ADDR_WIDTH    =  14;
    localparam INSTR_RDATA_WIDTH =  32;
    localparam BOOT_ADDR         = 32'h02000000 + 24'h200000; // TODO set inside cv32e40x_top

    // wrapper for CV32E40X, the memory system and stdout peripheral
    cv32e40x_soc
    #(
        .SOC_ADDR_WIDTH    (SOC_ADDR_WIDTH),
        .RAM_ADDR_WIDTH    (RAM_ADDR_WIDTH),
        .INSTR_RDATA_WIDTH (INSTR_RDATA_WIDTH),
        .CLK_FREQ          (CLK_FREQ),
        .BAUDRATE          (BAUDRATE),
        .BOOT_ADDR         (BOOT_ADDR)
     )
    cv32e40x_soc_inst
    (
        .clk_i          ( clk          ),
        .rst_ni         ( reset_n      ),

        .led            ( blinky       ),

        .ser_tx         ( ftdi_rxd     ),
        .ser_rx         ( ftdi_txd     )
    );

endmodule
