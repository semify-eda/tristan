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

    // SPI Flash
    `ifndef SYNTHESIS
    output flash_clk,
    `endif
    output flash_csn,
    output flash_mosi,
    input  flash_miso,
    output flash_holdn,
    output flash_wpn
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

        .led            ( led[0]       ),

        .ser_tx         ( ftdi_rxd     ),
        .ser_rx         ( ftdi_txd     ),

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
    
    logic                       ram_en;
    logic [RAM_ADDR_WIDTH-1:0]  ram_addr;
    logic [31:0]                ram_wdata;
    logic [31:0]                ram_rdata;
    logic                       ram_we;
    logic [3:0]                 ram_be;
    
    dp_ram
    #(
        .ADDR_WIDTH  (RAM_ADDR_WIDTH)
    ) dp_ram_i
    (
        .clk_i      (clk),

        .en_i       (ram_en),
        .addr_i     (ram_addr),
        .wdata_i    (ram_wdata),
        .rdata_o    (ram_rdata),
        .we_i       (ram_we),
        .be_i       (ram_be)
     );
    
    `ifdef SYNTHESIS
    wire flash_clk;
    USRMCLK u1 (
        .USRMCLKI(flash_clk),
        .USRMCLKTS(1'b0) // no tristate
    );
    `endif

    assign flash_wpn = 1'b0; // Write Protect
    assign flash_holdn = 1'b1; // No reset

endmodule
