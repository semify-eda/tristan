`default_nettype none

module sky130_top #(
    parameter SRAM_NUM_INSTANCES = 8,
    parameter NUM_WMASKS = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH_DEFAULT = 9
)(
    // Clock and reset
    input  logic clk_i,
    input  logic rst_ni,
    
    // Blinky
    output logic led,
    
    // Uart
    output logic ser_tx,
    input  logic ser_rx,
    
    // SPI signals
    output logic sck,
    output logic sdo,
    input  logic sdi,
    output logic cs,

    // Port 0: RW
    output [SRAM_NUM_INSTANCES-1:0]                          sram_clk0,
    output [SRAM_NUM_INSTANCES-1:0]                          sram_csb0,
    output [SRAM_NUM_INSTANCES-1:0]                          sram_web0,
    output [(SRAM_NUM_INSTANCES*NUM_WMASKS)-1:0]             sram_wmask0,
    output [(SRAM_NUM_INSTANCES*ADDR_WIDTH_DEFAULT)-1:0]     sram_addr0,
    output [(SRAM_NUM_INSTANCES*DATA_WIDTH)-1:0]             sram_din0,
    input  [(SRAM_NUM_INSTANCES*DATA_WIDTH)-1:0]             sram_dout0,

    // Port 1: R
    output [SRAM_NUM_INSTANCES-1:0]                          sram_clk1,
    output [SRAM_NUM_INSTANCES-1:0]                          sram_csb1,
    output [(SRAM_NUM_INSTANCES*ADDR_WIDTH_DEFAULT)-1:0]     sram_addr1,
    input  [(SRAM_NUM_INSTANCES*DATA_WIDTH)-1:0]             sram_dout1
);

    localparam SOC_ADDR_WIDTH    = 32;
    localparam RAM_ADDR_WIDTH    = ADDR_WIDTH_DEFAULT + $clog2(SRAM_NUM_INSTANCES);
    localparam CLK_FREQ          = 25_000_000;
    localparam BAUDRATE          = 115200;

    // Single port RAM
    logic                       ram_en_o;
    logic [RAM_ADDR_WIDTH-1:0]  ram_addr_o;
    logic [31:0]                ram_wdata_o;
    logic [31:0]                ram_rdata_i;
    logic                       ram_we_o;
    logic [3:0]                 ram_be_o;
    
    sram_wrapper #(
        .ADDR_WIDTH         (RAM_ADDR_WIDTH),
        .NUM_INSTANCES      (SRAM_NUM_INSTANCES)
    ) sram_wrapper_inst (

        // --- Connections to SoC ---

        // Port 0: RW
        .soc_clk0    (clk_i),
        .soc_csb0    (!ram_en_o),
        .soc_web0    (!ram_we_o),
        .soc_wmask0  (ram_be_o),
        .soc_addr0   (ram_addr_o),
        .soc_din0    (ram_wdata_o),
        .soc_dout0   (ram_rdata_i),

        // Port 1: R
        .soc_clk1   (1'b0),
        .soc_csb1   (1'b1),
        .soc_addr1  ('0),
        .soc_dout1  (),
        
        // --- Connections to SRAM macros ---

        // Port 0: RW
        .clk0       (sram_clk0),
        .csb0       (sram_csb0),
        .web0       (sram_web0),
        .wmask0     (sram_wmask0),
        .addr0      (sram_addr0),
        .din0       (sram_din0),
        .dout0      (sram_dout0),

        // Port 1: R
        .clk1       (sram_clk1),
        .csb1       (sram_csb1),
        .addr1      (sram_addr1),
        .dout1      (sram_dout1)
    );

    cv32e40x_soc
    #(
        .SOC_ADDR_WIDTH    (SOC_ADDR_WIDTH),
        .RAM_ADDR_WIDTH    (RAM_ADDR_WIDTH),
        .CLK_FREQ          (CLK_FREQ),
        .BAUDRATE          (BAUDRATE)
    )
    cv32e40x_soc_inst
    (
        // Clock and reset
        .clk_i,
        .rst_ni,
        
        // Blinky
        .led,
        
        // Uart
        .ser_tx,
        .ser_rx,
        
        // SPI signals
        .sck,
        .sdo,
        .sdi,
        .cs,
        
        // Single port RAM
        .ram_en_o,
        .ram_addr_o,
        .ram_wdata_o,
        .ram_rdata_i,
        .ram_we_o,
        .ram_be_o
    );

endmodule
