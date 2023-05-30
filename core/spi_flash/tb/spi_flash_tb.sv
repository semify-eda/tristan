// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns/1ps

module spi_flash_tb;
    
    logic reset = 1;
    
    initial begin
        $dumpfile("spi_flash_tb.fst");
        $dumpvars(0, spi_flash_tb);
    end
    
    initial begin
        reset = 1'b1;
        #100;
        reset = 1'b0;
        addr_in = 24'h000005;
        strobe = 1'b1;
        #1000;
        strobe = 1'b0;
        #5000;
        addr_in = 24'h000009;
        strobe = 1'b1;
        #1000;
        strobe = 1'b0;
        #5000;
        addr_in = 24'h000002;
        strobe = 1'b1;
        #1000;
        strobe = 1'b0;
        #5000;
        $finish;
    end
    
    logic clk = 1'b0;
    
    always begin
        #10 clk = !clk;
    end

    logic [23:0] addr_in;
    logic [31:0] data_out;
    logic strobe;
    logic done;
    
    logic sck;
    logic sdo;
    logic sdi;
    logic cs;
    
    spi_flash spi_flash_inst (
        .reset,
        .clk,

        .addr_in,
        .data_out,
        .strobe,
        .done,
        
        .sck,
        .sdo,
        .sdi,
        .cs
    );
    
    spiflash #(
        .INIT_F("spi_flash/tb/spiflash.hex")
    ) spiflash_inst (
        .csb    (cs),
        .clk    (sck),
        .io0    (sdo), // MOSI
        .io1    (sdi), // MISO
        .io2    (),
        .io3    ()
    );

endmodule
