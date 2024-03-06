// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps
`default_nettype none

module sw_top (
    input wire osc_100MHz_i,

//    input wire ftdi_txd,
//    output wire ftdi_rxd,
    
    // SPI Flash
    output wire flash_clk,
    output wire flash_csn,
    output wire flash_mosi,
    input wire flash_miso
//    output wire flash_holdn,
//    output wire flash_wpn
);

    logic clk;
    logic reset_n;
    
   vio_reset reset_instance
   (
    .clk(clk),                // input wire clk
    .probe_out0(reset_n)      // output wire [0 : 0] probe_out0
    );
    
    clk_wiz_0 osc_25MHz
   (
    .clk_25MHz(clk),
    .reset(reset_n),
    .locked(),
    .osc_100MHz_i(osc_100MHz_i)
    );
    
    localparam CLK_FREQ = 25_000_000;
    localparam BAUDRATE = 115200;
    localparam SOC_ADDR_WIDTH    =  32;
    localparam RAM_ADDR_WIDTH    =  14;
    localparam INSTR_RDATA_WIDTH =  32;
    localparam BOOT_ADDR         = 32'h02000000 + 24'h200000; // TODO set inside cv32e40x_top
    
    logic                       ram_en;
    logic [RAM_ADDR_WIDTH-1:0]  ram_addr;
    logic [31:0]                ram_wdata;
    logic [31:0]                ram_rdata;
    logic                       ram_we;
    logic [3:0]                 ram_be;

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

//        .ser_tx         ( ftdi_rxd     ),
//        .ser_rx         ( ftdi_txd     ),

        .sck            (flash_clk),
        .sdo            (flash_mosi),
        .sdi            (flash_miso),
        .cs             (flash_csn),
        
        .ram_en_o       (ram_en),
        .ram_addr_o     (ram_addr),
        .ram_wdata_o    (ram_wdata),
        .ram_rdata_i    (ram_rdata),
        .ram_we_o       (ram_we),
        .ram_be_o       (ram_be)
    );
    
    sp_ram
    #(
        .ADDR_WIDTH  (RAM_ADDR_WIDTH)
    ) sp_ram_i
    (
        .clk_i      (clk),

        .en_i       (ram_en),
        .addr_i     (ram_addr),
        .wdata_i    (ram_wdata),
        .rdata_o    (ram_rdata),
        .we_i       (ram_we),
        .be_i       (ram_be)
    );
    
//    assign flash_wpn = 1'b0;    // Write Protect
//    assign flash_holdn = 1'b1;  // No reset

endmodule
`default_nettype wire