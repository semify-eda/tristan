`default_nettype none

module sky130_top (
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
    output                                sram0_clk0,
    output                                sram0_csb0,
    output                                sram0_web0,
    output [4-1:0]                        sram0_wmask0,
    output [9-1:0]                        sram0_addr0,
    output [32-1:0]                       sram0_din0,
    input  [32-1:0]                       sram0_dout0,

    // Port 1: R
    output                                sram0_clk1,
    output                                sram0_csb1,
    output [9-1:0]                        sram0_addr1,
    input  [32-1:0]                       sram0_dout1,
    
    // Port 0: RW
    output                                sram1_clk0,
    output                                sram1_csb0,
    output                                sram1_web0,
    output [4-1:0]                        sram1_wmask0,
    output [9-1:0]                        sram1_addr0,
    output [32-1:0]                       sram1_din0,
    input  [32-1:0]                       sram1_dout0,

    // Port 1: R
    output                                sram1_clk1,
    output                                sram1_csb1,
    output [9-1:0]                        sram1_addr1,
    input  [32-1:0]                       sram1_dout1
);

    localparam SOC_ADDR_WIDTH    = 32;
    localparam RAM_ADDR_WIDTH    = 10; // TODO 14
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
        .ADDR_WIDTH         (RAM_ADDR_WIDTH)
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
        .clk0       ({sram1_clk0, sram0_clk0}),
        .csb0       ({sram1_csb0, sram0_csb0}),
        .web0       ({sram1_web0, sram0_web0}),
        .wmask0     ({sram1_wmask0, sram0_wmask0}),
        .addr0      ({sram1_addr0, sram0_addr0}),
        .din0       ({sram1_din0, sram0_din0}),
        .dout0      ({sram1_dout0, sram0_dout0}),

        // Port 1: R
        .clk1       ({sram1_clk1, sram0_clk1}),
        .csb1       ({sram1_csb1, sram0_csb1}),
        .addr1      ({sram1_addr1, sram0_addr1}),
        .dout1      ({sram1_dout1, sram0_dout1})
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
