// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

module ulx3s_top (
    input clk_25mhz,

    input  ftdi_txd,
    output ftdi_rxd,

    input  [6:0] btn,
    output [7:0] led
);
    localparam FREQUENCY = 25_000_000;
    localparam SOC_ADDR_WIDTH    =  24;
    localparam RAM_ADDR_WIDTH    =  14;
    localparam INSTR_RDATA_WIDTH =  32;
    localparam BOOT_ADDR         = 'h0;

    // wrapper for CV32E40X, the memory system and stdout peripheral
    cv32e40x_soc
        #(
          .INSTR_RDATA_WIDTH (INSTR_RDATA_WIDTH),
          .SOC_ADDR_WIDTH    (SOC_ADDR_WIDTH),
          .RAM_ADDR_WIDTH    (RAM_ADDR_WIDTH),
          .BOOT_ADDR         (BOOT_ADDR)
         )
    cv32e40x_soc
        (
         .clk_i          ( clk_25mhz    ),
         .rst_ni         ( btn[0]       ),
         .led            ( led[0]       ),
         .ser_tx         ( ftdi_rxd     ),
         .ser_rx         ( ftdi_txd     )
        );
        
        // TODO debouncing

endmodule
