// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps
`default_nettype none

module sw_top (
    input wire osc_100MHz_i,

    input wire ftdi_txd,
    output logic ftdi_rxd
);

    logic clk;
    logic reset_n;
    
   vio_reset reset_instance
   (
    .clk        ( clk     ),     // input wire clk
    .probe_out0 ( reset_n )      // output wire [0 : 0] probe_out0
    );
    
    clk_wiz_0 osc_25MHz
   (
    .clk_25MHz      ( clk           ),
    .reset          ( reset_n       ),
    .locked         (               ),
    .osc_100MHz_i   ( osc_100MHz_i  )
    );
    
    localparam CLK_FREQ = 25_000_000;
    localparam BAUDRATE = 115200;
    localparam SOC_ADDR_WIDTH    =  32;
    localparam RAM_ADDR_WIDTH    =  14;
    localparam INSTR_RDATA_WIDTH =  32;
    localparam BOOT_ADDR         = 32'h02000000 + 24'h200000; 
    
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
        .clk_i      ( clk           ),
        .rst_ni     ( reset_n       ),

        .ser_tx     ( ftdi_rxd      ),
        .ser_rx     ( ftdi_txd      )
    );
    
endmodule
`default_nettype wire