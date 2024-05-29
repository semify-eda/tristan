`ifndef SOC_PKG
`define SOC_PKG
package soc_pkg;

    typedef enum logic{
        INTERNAL = 1'b0,
        EXTERNAL = 1'b1
    } e_chip_sel;

    typedef enum logic[2:0] {
        DRAM = 3'h0,
        IRAM = 3'h1,
        UART = 3'h2
    } e_block_sel;

endpackage
`endif