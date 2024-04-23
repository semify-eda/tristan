`default_nettype none
`timescale 1ns/1ps
import soc_pkg::*;

module cv32e40x_soc
#(
    parameter SOC_ADDR_WIDTH    = 32,
    parameter SOC_DATA_WIDTH    = 32,
    parameter RAM_ADDR_WIDTH    = 12,
    parameter RAM_DATA_WIDTH    = 32,
    parameter BAUDRATE          = 115200,
    parameter BOOT_ADDR         = 32'h00020000,
    parameter DATA_START_ADDR   = 32'h00000000,
    parameter FIRMWARE_INITFILE = "firmware.mem"
)
(
    // Clock and reset
    input  wire  clk_i,
    input  wire  wfg_clk_i,
    input  wire  rst_ni,
    input  wire  gbl_rst_ni,

    //core control signals
    input  wire                         soc_fetch_enable_i,
    output logic                        soc_core_sleep_o,

    // WB output interface for external modules
    output logic [SOC_ADDR_WIDTH-1:0]   wb_addr_o,
    input  wire  [31 : 0]               wb_rdata_i,
    output logic [31 : 0]               wb_wdata_o,
    output logic                        wb_wr_en_o,
    output logic [3 : 0]                wb_byte_en_o,
    output logic                        wb_stb_o,
    input  wire                         wb_ack_i,
    output logic                        wb_cyc_o,

    // WB input interface to access SoC RAM
    input  wire  [SOC_ADDR_WIDTH-1:0]   wb_addr_i,
    output logic [31 : 0]               wb_rdata_o,
    input  wire  [31 : 0]               wb_wdata_i,
    input  wire                         wb_wr_en_i,
    input  wire  [3 : 0]                wb_byte_en_i,
    input  wire                         wb_stb_i,
    output logic                        wb_ack_o,
    input  wire                         wb_cyc_i
);

    // ----------------------------------
    //           CV32E40X Core
    // ----------------------------------

    logic cpu_instr_req;
    logic cpu_instr_gnt;
    logic cpu_instr_rvalid;
    logic [SOC_ADDR_WIDTH-1:0] cpu_instr_addr;
    logic [31: 0] cpu_instr_rdata;

    logic cpu_data_req;
    logic cpu_data_gnt;
    logic cpu_data_rvalid;
    logic [SOC_ADDR_WIDTH-1:0] cpu_data_addr;
    logic [3 : 0] cpu_data_be;
    logic         cpu_data_we;
    logic [31: 0] cpu_data_wdata;
    logic [31: 0] cpu_data_rdata;
    logic [SOC_ADDR_WIDTH-1:0] soc_addr;
    logic soc_req;
    logic soc_gnt;
    logic soc_rvalid;
    logic [3 : 0] soc_be;
    logic         soc_we;
    logic [31: 0] soc_wdata;
    logic [31: 0] soc_rdata;

    logic [31:0] instr_rdata;
    logic [31:0] ram_rdata;

    // ----------------------------------
    //            Multiplexer
    // ----------------------------------
    logic select_dram;
    logic select_iram;
    logic select_wb;

    // The alignment offset ensures that the RAM is addressed correctly regardless of its width.
    // This offset can change based on the width and depth of the RAM, and is calculated as:
    //          alignment offset = log2 (RAM Width / 8)
    // It is added to the beginning and end of the addr_width when addressing into the soc_addr, in order to use
    // the correct bits of soc_addr to index into the RAM, since larger width RAM means more bytes are packed together in a single row.
    localparam ALIGNMENT_OFFSET = $clog2( RAM_DATA_WIDTH / 8 );

    //TODO: move these to a package
    
    // ----------------------------------
    //           Communication Signals
    // ----------------------------------

    e_chip_sel  chip_sel;
    e_block_sel block_sel;

    assign chip_sel  = e_chip_sel'(soc_addr[20]);
    assign block_sel = e_block_sel'(soc_addr[19:17]);

    // standard OBI signals
    logic                       obi_req_o;
    logic                       obi_gnt_i;
    logic [SOC_ADDR_WIDTH-1:0]  obi_addr_o;
    logic                       obi_we_o;
    logic [3 : 0]               obi_be_o;
    logic [31 : 0]              obi_wdata_o;
    logic                       obi_rvalid_i;
    logic [31 : 0]              obi_rdata_i;

    assign obi_req_o    = soc_req;
    assign obi_addr_o   = soc_addr;
    assign obi_we_o     = soc_we;
    assign obi_be_o     = soc_be;
    assign obi_wdata_o  = soc_wdata;
    // ----------------------------------
    //            Grant Logic
    // ----------------------------------
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            soc_gnt <= 1'b0;
        end else begin
            // If communicating with an external module, wait for the module to respond
            if(select_wb) begin
                soc_gnt <= obi_gnt_i;
            end else begin
                // Grant if we have not already granted
                soc_gnt <= soc_req && !soc_gnt && !soc_rvalid;
            end
        end
    end

    // ----------------------------------
    //            Arbiter
    // ----------------------------------

    ram_arbiter i_ram_arbiter
    (
        .clk_i                  (clk_i),
        .rst_ni                 (rst_ni),

        // I RAM Signals
        .cpu_instr_addr_i       (cpu_instr_addr     ),
        .cpu_instr_req_i        (cpu_instr_req      ),
        .cpu_instr_gnt_o        (cpu_instr_gnt      ),
        .cpu_instr_rvalid_o     (cpu_instr_rvalid   ),
        .cpu_instr_rdata_o      (cpu_instr_rdata    ),

        // D RAM Signals
        .cpu_data_addr_i        (cpu_data_addr      ),
        .cpu_data_req_i         (cpu_data_req       ),
        .cpu_data_gnt_o         (cpu_data_gnt       ),
        .cpu_data_rvalid_o      (cpu_data_rvalid    ),
        .cpu_data_rdata_o       (cpu_data_rdata     ),
        .cpu_data_be_i          (cpu_data_be        ),
        .cpu_data_we_i          (cpu_data_we        ),
        .cpu_data_wdata_i       (cpu_data_wdata     ),

        // Unified Signals
        .soc_rvalid_i           (soc_rvalid         ),
        .soc_gnt_i              (soc_gnt            ),
        .soc_req_o              (soc_req            ),
        .soc_addr_o             (soc_addr           ),
        .soc_be_o               (soc_be             ),
        .soc_we_o               (soc_we             ),
        .soc_wdata_o            (soc_wdata          ),
        .soc_rdata_i            (soc_rdata          )
    );

    // ----------------------------------
    //               CPU
    // ----------------------------------

    cv32e40x_top #(
        //.BOOT_ADDR(BOOT_ADDR) // set in module because of yosys
    )
    cv32e40x_top_inst
    (
      // Clock and reset
      .clk_i        (clk_i ),
      .rst_ni       (rst_ni),

      // Instruction memory interface
      .instr_req_o      (cpu_instr_req      ),
      .instr_gnt_i      (cpu_instr_gnt      ),
      .instr_rvalid_i   (cpu_instr_rvalid   ),
      .instr_addr_o     (cpu_instr_addr     ),
      .instr_rdata_i    (cpu_instr_rdata    ),

      // Data memory interface
      .data_req_o       (cpu_data_req       ),
      .data_gnt_i       (cpu_data_gnt       ),
      .data_rvalid_i    (cpu_data_rvalid    ),
      .data_addr_o      (cpu_data_addr      ),
      .data_be_o        (cpu_data_be        ),
      .data_we_o        (cpu_data_we        ),
      .data_wdata_o     (cpu_data_wdata     ),
      .data_rdata_i     (cpu_data_rdata     ),

      // Cycle count
      .mcycle_o         (),

      // Debug interface
      .debug_req_i      (1'b0),

      // CPU control signals
      .fetch_enable_i   (soc_fetch_enable_i),
      .core_sleep_o     (soc_core_sleep_o)
    );

    // ----------------------------------
    //            Multiplexer
    // ----------------------------------

    // Data select signals
    assign select_wb           = chip_sel == EXTERNAL;
    assign select_dram         = chip_sel == INTERNAL & block_sel == DRAM;
    assign select_iram         = chip_sel == INTERNAL & block_sel == IRAM;

    always_comb begin
        soc_rdata = '0;
        case(1'b1)
            select_dram:
                soc_rdata = ram_rdata;
            select_iram:
                soc_rdata = instr_rdata;
            select_wb:
                soc_rdata = obi_rdata_i;
        endcase
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            soc_rvalid <= 1'b0;
        end else begin
            if(select_wb) begin
                soc_rvalid <= obi_rvalid_i;
            end else begin
                // Generally data is available one cycle after req
                soc_rvalid <= soc_gnt;
            end
        end
    end

    // ----------------------------------
    //          OBI - WB Bridge
    // ----------------------------------

    obi_wb_bridge i_obi_wb_bridge
    (
        .obi_clk_i      (clk_i     ),
        .wb_clk_i       (wfg_clk_i ),
        .soc_rst_ni     (rst_ni    ),
        .gbl_rst_ni     (gbl_rst_ni),

        /* OBI Signals */
        .obi_req_i      (obi_req_o & select_wb),
        .obi_gnt_o      (obi_gnt_i      ),
        .obi_addr_i     (obi_addr_o     ),
        .obi_wr_en_i    (obi_we_o       ),
        .obi_byte_en_i  (obi_be_o       ),
        .obi_wdata_i    (obi_wdata_o    ),
        .obi_rvalid_o   (obi_rvalid_i   ),
        .obi_rdata_o    (obi_rdata_i    ),

        /* Wishbone Signals */
        .wb_addr_o      (wb_addr_o      ),
        .wb_rdata_i     (wb_rdata_i     ),
        .wb_wdata_o     (wb_wdata_o     ),
        .wb_wr_en_o     (wb_wr_en_o     ),
        .wb_byte_en_o   (wb_byte_en_o   ),
        .wb_stb_o       (wb_stb_o       ),
        .wb_ack_i       (wb_ack_i       ),
        .wb_cyc_o       (wb_cyc_o       )
    );

    logic [RAM_ADDR_WIDTH-1 : 0] wb2ram_addr;
    logic [RAM_DATA_WIDTH-1 : 0] wb2ram_data;
    logic [RAM_DATA_WIDTH-1 : 0] iram2wb_data;
    logic [RAM_DATA_WIDTH-1 : 0] dram2wb_data;
    logic                        wb2iram_we;
    logic                        wb2dram_we;


    // ----------------------------------
    //         WB - RAM Interface
    // ----------------------------------
    wb_ram_interface #(
        .RAM_ADDR_WIDTH (RAM_ADDR_WIDTH ),
        .RAM_DATA_WIDTH (RAM_DATA_WIDTH )
    ) i_wb_ram_interface (
        .ram_clk_i      (clk_i          ),
        .wb_clk_i       (wfg_clk_i      ),
        .rst_ni         (gbl_rst_ni     ),

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
    //           DP BRAM - Instr
    // ----------------------------------
    soc_sram_dualport #(
        .INITFILEEN     (1),
        .INITFILE       (FIRMWARE_INITFILE),
        .DATAWIDTH      (RAM_DATA_WIDTH),
        .ADDRWIDTH      (RAM_ADDR_WIDTH),
        .BYTE_ENABLE    (1)
    ) instr_dualport_i (
        .clk      (clk_i),

        // 16kb
        // RAM_ADDR_WIDTH is directly tied to the DATAWIDTH. Having an addr width of 12 does not mean that you address the
        // 12 LSB of the address, since if the data width is 32, then the 2 LSB are omitted, and you therefore must address
        // bits 13 to 2, due to alignment since the 2 LSB correspond to (32/8) = 4 bytes.
        .addr_a   (soc_addr[RAM_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET]),
        .we_a     (soc_gnt && select_iram && soc_we ),
        .be_a     (soc_be                           ),
        .d_a      (soc_wdata                        ),
        .q_a      (instr_rdata                      ),

        .addr_b   (wb2ram_addr                      ),
        .we_b     (wb2iram_we                       ),
        .d_b      (wb2ram_data                      ),
        .q_b      (iram2wb_data                     )
    );

    // ----------------------------------
    //           DP BRAM - Data
    // ----------------------------------
    soc_sram_dualport #(
        .DATAWIDTH      (RAM_DATA_WIDTH),
        .ADDRWIDTH      (RAM_ADDR_WIDTH),
        .BYTE_ENABLE    (1)
    ) ram_dualport_i (
      .clk      (clk_i),

      .addr_a   (soc_addr[RAM_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET]),
      .we_a     (soc_gnt && select_dram && soc_we   ),
      .be_a     (soc_be                             ),
      .d_a      (soc_wdata                          ),
      .q_a      (ram_rdata                          ),

      .addr_b   (wb2ram_addr                        ),
      .we_b     (wb2dram_we                         ),
      .d_b      (wb2ram_data                        ),
      .q_b      (dram2wb_data                       )
    );
    

endmodule
