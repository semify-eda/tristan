
module wb_ram_tb;

    localparam RAM_ADDR_WIDTH = 12;
    localparam RAM_DATA_WIDTH = 32;

    logic [31 : 0]               wb2ram_addr; 
    logic [RAM_DATA_WIDTH-1 : 0] wb2ram_data;
    logic [RAM_DATA_WIDTH-1 : 0] iram2wb_data;
    logic [RAM_DATA_WIDTH-1 : 0] dram2wb_data;
    logic                        wb2iram_we;
    logic                        wb2dram_we;

    logic [31:0]    wb_addr_i;
    logic [31:0]    wb_rdata_o;
    logic [31:0]    wb_wdata_i;
    logic           wb_wr_en_i;
    logic           wb_stb_i;
    logic           wb_ack_o;
    logic           wb_cyc_i;

    logic clk_i;
    logic ram_clk_i;
    logic rst_ni;

    // allow fst dump
    initial begin
        $dumpfile("wb_ram.vcd");
        $dumpvars();
    end


    // ----------------------------------
    //         WB - RAM Interface
    // ----------------------------------
    wb_ram_interface #(
        .RAM_ADDR_WIDTH (12)
    ) i_wb_ram_interface (
        .ram_clk_i      (ram_clk_i      ),
        .wb_clk_i       (clk_i          ),
        .rst_ni         (rst_ni         ),

        // Wishbone input signals
        .wb_addr_i      (wb_addr_i      ),
        .wb_rdata_o     (wb_rdata_o     ),
        .wb_wdata_i     (wb_wdata_i     ),
        .wb_wr_en_i     (wb_wr_en_i     ),
        .wb_stb_i       (wb_stb_i       ),
        .wb_ack_o       (wb_ack_o       ),
        .wb_cyc_i       (wb_cyc_i       ),

        // RAM output signals
        .ram_addr_o     (wb2ram_addr    ),
        .ram_data_o     (wb2ram_data    ),
        .iram_data_i    (iram2wb_data   ),
        .dram_data_i    (dram2wb_data   ),
        .iram_we_o      (wb2iram_we     ),
        .dram_we_o      (wb2dram_we     )
    );

    // ----------------------------------
    //              IRAM
    // ----------------------------------
    soc_sram_dualport #(
        .INITFILEEN     (1),
        .DATAWIDTH      (RAM_DATA_WIDTH),
        .ADDRWIDTH      (RAM_ADDR_WIDTH),
        .BYTE_ENABLE    (1)
    ) instr_dualport (
        .clk      (clk_i),

        .addr_a   ('0),
        .we_a     ('0),
        .be_a     ('0),
        .d_a      ('0),

        .addr_b   (wb2ram_addr      ),
        .we_b     (wb2iram_we       ),
        .d_b      (wb2ram_data      ),
        .q_b      (iram2wb_data     )
    );

    // ----------------------------------
    //             DRAM
    // ----------------------------------
    
    logic [31:0] ram_rdata;
    
    soc_sram_dualport #(
        .INITFILEEN     (1),
        .DATAWIDTH      (RAM_DATA_WIDTH),
        .ADDRWIDTH      (RAM_ADDR_WIDTH),
        .BYTE_ENABLE    (1)
    ) data_dualport (
        .clk      (clk_i),

        .addr_a   ('0),
        .we_a     ('0),
        .be_a     ('0),
        .d_a      ('0),

        .addr_b   (wb2ram_addr      ),
        .we_b     (wb2dram_we       ),
        .d_b      (wb2ram_data      ),
        .q_b      (dram2wb_data     )
    );

endmodule