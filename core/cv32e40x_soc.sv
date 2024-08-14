`default_nettype none
`timescale 1ns/1ps
import soc_pkg::*;

module cv32e40x_soc
#(
  parameter SOC_ADDR_WIDTH    = 32,
  parameter SOC_DATA_WIDTH    = 32,
  parameter RAM_ADDR_WIDTH    = 12,
  parameter RAM_DATA_WIDTH    = 32,
  parameter BOOT_ADDR         = 32'h00020000,
  parameter DATA_START_ADDR   = 32'h00000000,
  parameter FIRMWARE_INITFILE = "firmware.mem"
)
(
  // Clock and reset
  input  wire                         clk_i,
  input  wire                         wfg_clk_i,
  input  wire                         rst_ni,
  input  wire                         gbl_rst_ni,

  //core control signals
  input  wire                         soc_fetch_enable_i,
  output logic                        soc_core_sleep_o,

  // WB output interface for external modules
  output logic [SOC_ADDR_WIDTH-1:0]   wb_addr_o,
  input  wire  [31: 0]                wb_rdata_i,
  output logic [31: 0]                wb_wdata_o,
  output logic                        wb_wr_en_o,
  output logic [ 3: 0]                wb_byte_en_o,
  output logic                        wb_stb_o,
  input  wire                         wb_ack_i,
  output logic                        wb_cyc_o,

  // WB input interface to access SoC RAM
  input  wire  [SOC_ADDR_WIDTH-1:0]   wb_addr_i,
  output logic [31: 0]                wb_rdata_o,
  input  wire  [31: 0]                wb_wdata_i,
  input  wire                         wb_wr_en_i,
  input  wire  [ 3: 0]                wb_byte_en_i,
  input  wire                         wb_stb_i,
  output logic                        wb_ack_o,
  input  wire                         wb_cyc_i
);

  /* =====================================================================
  *                 cv32e40x instruction and data signals
  * ====================================================================== */
  logic                       cpu_instr_req;
  logic                       cpu_instr_gnt;
  logic                       cpu_instr_rvalid;
  logic [SOC_ADDR_WIDTH-1:0]  cpu_instr_addr;
  logic [31: 0]               cpu_instr_rdata;

  logic                       cpu_data_req;
  logic                       cpu_data_gnt;
  logic                       cpu_data_rvalid;
  logic [SOC_ADDR_WIDTH-1:0]  cpu_data_addr;
  logic [ 3: 0]               cpu_data_be;
  logic                       cpu_data_we;
  logic [31: 0]               cpu_data_wdata;
  logic [31: 0]               cpu_data_rdata;


  /* =====================================================================
  *                     cv32e40x unified signals
  * ====================================================================== */
  logic [SOC_ADDR_WIDTH-1:0]  addr;
  logic                       req;
  logic                       gnt;
  logic                       rvalid;
  logic [ 3: 0]               be;
  logic                       we;
  logic [31: 0]               wdata;
  logic [31: 0]               rdata;

  logic [31: 0]               instr_rdata;
  logic [31: 0]               ram_rdata;


  /* =====================================================================
  *                     cv32e40x peripheral signals
  * ====================================================================== */
  logic select_dram;
  logic select_iram;
  logic select_wb;

  e_chip_sel  chip_sel;
  e_block_sel block_sel;

  assign chip_sel  = e_chip_sel'(addr[20]);
  assign block_sel = e_block_sel'(addr[19:17]);
  
  // The alignment offset ensures that the RAM is addressed correctly regardless of its width.
  // This offset can change based on the width and depth of the RAM, and is calculated as:
  //          alignment offset = log2 (RAM Width / 8)
  // It is added to the beginning and end of the addr_width when addressing into the addr, in order to use
  // the correct bits of addr to index into the RAM, since larger width RAM means more bytes are packed together in a single row.
  localparam ALIGNMENT_OFFSET = $clog2( RAM_DATA_WIDTH / 8 );
 
  /* =====================================================================
  *                             OBI Signals
  * ====================================================================== */
  logic                       obi_req_o;
  logic                       obi_gnt_i;
  logic [SOC_ADDR_WIDTH-1:0]  obi_addr_o;
  logic                       obi_we_o;
  logic [3 : 0]               obi_be_o;
  logic [31 : 0]              obi_wdata_o;
  logic                       obi_rvalid_i;
  logic [31 : 0]              obi_rdata_i;

  assign obi_req_o    = req;
  assign obi_addr_o   = addr;
  assign obi_we_o     = we;
  assign obi_be_o     = be;
  assign obi_wdata_o  = wdata;


  /* =====================================================================
  *                cv32e40x - coprocessor eXtension interface
  * ====================================================================== */

  localparam int unsigned X_NUM_RS        =  2;  // Number of register file read ports that can be used by the eXtension interface
  localparam int unsigned X_ID_WIDTH      =  4;  // Width of ID field.
  localparam int unsigned X_MEM_WIDTH     =  32; // Memory access width for loads/stores via the eXtension interface
  localparam int unsigned X_RFR_WIDTH     =  32; // Register file read access width for the eXtension interface
  localparam int unsigned X_RFW_WIDTH     =  32; // Register file write access width for the eXtension interface
  localparam logic [31:0] X_MISA          =  '0; // MISA extensions implemented on the eXtension interface
  localparam logic [ 1:0] X_ECS_XS        =  '0; // Default value for mstatus.XS
  localparam int XLEN                     = 32;
  localparam int FLEN                     = 32;

  /* ====================== Compressed Interface ====================== */
  // logic
  logic                                     compressed_valid;
  logic                                     compressed_ready;
  // x_compressed_req
  logic [          15: 0]                   compressed_req_instr;
  logic [           1: 0]                   compressed_req_mode;
  logic [X_ID_WIDTH-1: 0]                   compressed_req_id;
  // x_compressed_resp
  logic [          31: 0]                   compressed_resp_instr;
  logic                                     compressed_resp_accept;

  /* ====================== Issue Interface =========================== */
  // logic
  logic                                     issue_valid;
  logic                                     issue_ready;
  // x_issue_req_t
  logic [          31: 0]                   issue_req_instr;
  logic [           1: 0]                   issue_req_mode;
  logic [X_ID_WIDTH-1: 0]                   issue_req_id;
  logic [X_NUM_RS  -1: 0][X_RFR_WIDTH-1: 0] issue_req_rs;
  logic [X_NUM_RS  -1: 0]                   issue_req_rs_valid;
  logic [           5: 0]                   issue_req_ecs;
  logic                                     issue_req_ecs_valid;
  // x_issue_resp_t
  logic                                     issue_resp_accept;
  logic                                     issue_resp_writeback;
  logic                                     issue_resp_dualwrite;
  logic [ 2: 0]                             issue_resp_dualread;
  logic                                     issue_resp_loadstore;
  logic                                     issue_resp_ecswrite;
  logic                                     issue_resp_exc;
  
  /* ====================== Commit Interface ========================== */ 
  // logic
  logic                                     commit_valid;
  // x_commit_t
  logic [X_ID_WIDTH-1: 0]                   commit_id;
  logic                                     commit_kill;
 
  /* ====================== Memory Req/Resp Interface ================= */
  // logic
  logic                                     mem_valid;
  logic                                     mem_ready;
  // x_mem_req_t
  logic  [X_ID_WIDTH   -1: 0]               mem_req_id;
  logic  [             31: 0]               mem_req_addr;
  logic  [              1: 0]               mem_req_mode;
  logic                                     mem_req_we;
  logic  [              2: 0]               mem_req_size;
  logic  [X_MEM_WIDTH/8-1: 0]               mem_req_be;
  logic  [              1: 0]               mem_req_attr;
  logic  [X_MEM_WIDTH  -1: 0]               mem_req_wdata;
  logic                                     mem_req_last;
  logic                                     mem_req_spec;
  // x_mem_resp_t
  logic                                     mem_resp_exc;
  logic [ 5: 0]                             mem_resp_exccode;
  logic                                     mem_resp_dbg;

  /* ====================== Memory Result Interface =================== */
  // logic
  logic                                     mem_result_valid;
  // x_mem_result_t
  logic [X_ID_WIDTH -1:0]                   mem_result_id;
  logic [X_MEM_WIDTH-1:0]                   mem_result_rdata;
  logic                                     mem_result_err;
  logic                                     mem_result_dbg;
  
  /*======================= Result Interface ========================== */
  // logic
  logic                                     result_valid;
  logic                                     result_ready;
  // x_result_t
  logic [X_ID_WIDTH      -1:0]              result_id;
  logic [X_RFW_WIDTH     -1:0]              result_data;
  logic [                 4:0]              result_rd;
  logic [X_RFW_WIDTH/XLEN-1:0]              result_we;
  logic [                 5:0]              result_ecsdata;
  logic [                 2:0]              result_ecswe;
  logic                                     result_exc;
  logic [                 5:0]              result_exccode;
  logic                                     result_err;
  logic                                     result_dbg;
 
  /* =====================================================================
  *                           Bus Grant Logic
  * ====================================================================== */
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      gnt <= 1'b0;
    end else begin
      // If communicating with an external module, wait for the module to respond
      if(select_wb) begin
        gnt <= obi_gnt_i;
      end else begin
        // Grant if we have not already granted
        gnt <= req && !gnt && !rvalid;
      end
    end
  end


  /* ================================================================
  *                         Arbiter
  * ================================================================= */
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
    .soc_rvalid_i           (rvalid         ),
    .soc_gnt_i              (gnt            ),
    .soc_req_o              (req            ),
    .soc_addr_o             (addr           ),
    .soc_be_o               (be             ),
    .soc_we_o               (we             ),
    .soc_wdata_o            (wdata          ),
    .soc_rdata_i            (rdata          )
  );


  /* ================================================================
  *                         CPU
  * ================================================================= */
  cv32e40x_top cv32e40x_top_inst
  (
    .clk_i                  (clk_i                    ),
    .rst_ni                 (rst_ni                   ),

    /* ================== Instruction Memory Interface ========== */
    .instr_req_o            (cpu_instr_req            ),
    .instr_gnt_i            (cpu_instr_gnt            ),
    .instr_rvalid_i         (cpu_instr_rvalid         ),
    .instr_addr_o           (cpu_instr_addr           ),
    .instr_rdata_i          (cpu_instr_rdata          ),

    /* ================== Data Memory Interface ================= */
    .data_req_o             (cpu_data_req             ),
    .data_gnt_i             (cpu_data_gnt             ),
    .data_rvalid_i          (cpu_data_rvalid          ),
    .data_addr_o            (cpu_data_addr            ),
    .data_be_o              (cpu_data_be              ),
    .data_we_o              (cpu_data_we              ),
    .data_wdata_o           (cpu_data_wdata           ),
    .data_rdata_i           (cpu_data_rdata           ),

    /* ================== Cycle Count =========================== */
    .mcycle_o               (                         ),

    /* ================== Debug Interface ======================= */
    .debug_req_i            (1'b0                     ),

    /* ================== CPU Control Signals =================== */
    .fetch_enable_i         (soc_fetch_enable_i       ),
    .core_sleep_o           (soc_core_sleep_o         ),

    /* ==========================================================
    *                     eXtension Interface
    * =========================================================== */
    /* ================== Compressed Interface ================== */
    .compressed_valid       (compressed_valid         ),
    .compressed_ready       (compressed_ready         ),
    .compressed_req_instr   (compressed_req_instr     ),
    .compressed_req_mode    (compressed_req_mode      ),
    .compressed_req_id      (compressed_req_id        ),
    .compressed_resp_instr  (compressed_resp_instr    ),
    .compressed_resp_accept (compressed_resp_accept   ),

    /* ================== Issue Interface ======================= */
    .issue_valid            (issue_valid              ),
    .issue_ready            (issue_ready              ),
    .issue_req_instr        (issue_req_instr          ),
    .issue_req_mode         (issue_req_mode           ),
    .issue_req_id           (issue_req_id             ),
    .issue_req_rs           (issue_req_rs             ),
    .issue_req_rs_valid     (issue_req_rs_valid       ),
    .issue_req_ecs          (issue_req_ecs            ),
    .issue_req_ecs_valid    (issue_req_ecs_valid      ),
    .issue_resp_accept      (issue_resp_accept        ),
    .issue_resp_writeback   (issue_resp_writeback     ),
    .issue_resp_dualwrite   (issue_resp_dualwrite     ),
    .issue_resp_dualread    (issue_resp_dualread      ),
    .issue_resp_loadstore   (issue_resp_loadstore     ),
    .issue_resp_ecswrite    (issue_resp_ecswrite      ),
    .issue_resp_exc         (issue_resp_exc           ),
    
    /* ================== Commit Interface ====================== */ 
    .commit_valid           (commit_valid             ),
    .commit_id              (commit_id                ),
    .commit_kill            (commit_kill              ),
  
    /* ================== Memory Req/Resp Interface ============= */
    .mem_valid              (mem_valid                ),
    .mem_ready              (mem_ready                ),
    .mem_req_id             (mem_req_id               ),
    .mem_req_addr           (mem_req_addr             ),
    .mem_req_mode           (mem_req_mode             ),
    .mem_req_we             (mem_req_we               ),
    .mem_req_size           (mem_req_size             ),
    .mem_req_be             (mem_req_be               ),
    .mem_req_attr           (mem_req_attr             ),
    .mem_req_wdata          (mem_req_wdata            ),
    .mem_req_last           (mem_req_last             ),
    .mem_req_spec           (mem_req_spec             ),
    .mem_resp_exc           (mem_resp_exc             ),
    .mem_resp_exccode       (mem_resp_exccode         ),
    .mem_resp_dbg           (mem_resp_dbg             ),

    /* ================== Memory Result Interface =============== */
    .mem_result_valid       (mem_result_valid         ),
    .mem_result_id          (mem_result_id            ),
    .mem_result_rdata       (mem_result_rdata         ),
    .mem_result_err         (mem_result_err           ),
    .mem_result_dbg         (mem_result_dbg           ),
    
    /* ================== Result Interface ====================== */
    .result_valid           (result_valid             ),
    .result_ready           (result_ready             ),
    .result_id              (result_id                ),
    .result_data            (result_data              ),
    .result_rd              (result_rd                ),
    .result_we              (result_we                ),
    .result_ecsdata         (result_ecsdata           ),
    .result_ecswe           (result_ecswe             ),
    .result_exc             (result_exc               ),
    .result_exccode         (result_exccode           ),
    .result_err             (result_err               ),
    .result_dbg             (result_dbg               )

  );


  /* ================================================================
  *                         Co-Processor
  * ================================================================= */
  coproc coproc_inst
  (
    .clk_i                  (clk_i                    ),
    .rst_ni                 (rst_ni                   ),

    /* ================== Compressed Interface ================== */
    .compressed_valid       (compressed_valid         ),
    .compressed_ready       (compressed_ready         ),
    .compressed_req_instr   (compressed_req_instr     ),
    .compressed_req_mode    (compressed_req_mode      ),
    .compressed_req_id      (compressed_req_id        ),
    .compressed_resp_instr  (compressed_resp_instr    ),
    .compressed_resp_accept (compressed_resp_accept   ),

    /* ================== Issue Interface ======================= */
    .issue_valid            (issue_valid              ),
    .issue_ready            (issue_ready              ),
    .issue_req_instr        (issue_req_instr          ),
    .issue_req_mode         (issue_req_mode           ),
    .issue_req_id           (issue_req_id             ),
    .issue_req_rs           (issue_req_rs             ),
    .issue_req_rs_valid     (issue_req_rs_valid       ),
    .issue_req_ecs          (issue_req_ecs            ),
    .issue_req_ecs_valid    (issue_req_ecs_valid      ),
    .issue_resp_accept      (issue_resp_accept        ),
    .issue_resp_writeback   (issue_resp_writeback     ),
    .issue_resp_dualwrite   (issue_resp_dualwrite     ),
    .issue_resp_dualread    (issue_resp_dualread      ),
    .issue_resp_loadstore   (issue_resp_loadstore     ),
    .issue_resp_ecswrite    (issue_resp_ecswrite      ),
    .issue_resp_exc         (issue_resp_exc           ),
    
    /* ================== Commit Interface ====================== */ 
    .commit_valid           (commit_valid             ),
    .commit_id              (commit_id                ),
    .commit_kill            (commit_kill              ),
  
    /* ================== Memory Req/Resp Interface ============= */
    .mem_valid              (mem_valid                ),
    .mem_ready              (mem_ready                ),
    .mem_req_id             (mem_req_id               ),
    .mem_req_addr           (mem_req_addr             ),
    .mem_req_mode           (mem_req_mode             ),
    .mem_req_we             (mem_req_we               ),
    .mem_req_size           (mem_req_size             ),
    .mem_req_be             (mem_req_be               ),
    .mem_req_attr           (mem_req_attr             ),
    .mem_req_wdata          (mem_req_wdata            ),
    .mem_req_last           (mem_req_last             ),
    .mem_req_spec           (mem_req_spec             ),
    .mem_resp_exc           (mem_resp_exc             ),
    .mem_resp_exccode       (mem_resp_exccode         ),
    .mem_resp_dbg           (mem_resp_dbg             ),

    /* ================== Memory Result Interface =============== */
    .mem_result_valid       (mem_result_valid         ),
    .mem_result_id          (mem_result_id            ),
    .mem_result_rdata       (mem_result_rdata         ),
    .mem_result_err         (mem_result_err           ),
    .mem_result_dbg         (mem_result_dbg           ),
    
    /* ================== Result Interface ====================== */
    .result_valid           (result_valid             ),
    .result_ready           (result_ready             ),
    .result_id              (result_id                ),
    .result_data            (result_data              ),
    .result_rd              (result_rd                ),
    .result_we              (result_we                ),
    .result_ecsdata         (result_ecsdata           ),
    .result_ecswe           (result_ecswe             ),
    .result_exc             (result_exc               ),
    .result_exccode         (result_exccode           ),
    .result_err             (result_err               ),
    .result_dbg             (result_dbg               )
  );


  /* ================================================================
  *                     Peripheral Multiplexer
  * ================================================================= */
  // Data select signals
  assign select_wb           = chip_sel == EXTERNAL;
  assign select_dram         = chip_sel == INTERNAL & block_sel == DRAM;
  assign select_iram         = chip_sel == INTERNAL & block_sel == IRAM;

  always_comb begin
    rdata = '0;
    case(1'b1)
      select_dram:
        rdata = ram_rdata;
      select_iram:
        rdata = instr_rdata;
      select_wb:
        rdata = obi_rdata_i;
    endcase
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      rvalid <= 1'b0;
    end else begin
      if(select_wb) begin
        rvalid <= obi_rvalid_i;
      end else begin
        // Generally data is available one cycle after req
        rvalid <= gnt;
      end
    end
  end


  /* ================================================================
  *                     OBI - Wishbone bridge
  * ================================================================= */
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


  /* ================================================================
  *                     Wishbone - RAM interface
  * ================================================================= */
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


  /* ================================================================
  *                     Dualport BRAM - Instr
  * ================================================================= */
  soc_sram_dualport #(
    .INITFILEEN     (1                  ),
    .INITFILE       (FIRMWARE_INITFILE  ),
    .DATAWIDTH      (RAM_DATA_WIDTH     ),
    .ADDRWIDTH      (RAM_ADDR_WIDTH     ),
    .BYTE_ENABLE    (1                  )
  ) instr_dualport_i (
    .clk      (clk_i                            ),

    // 16kb
    // RAM_ADDR_WIDTH is directly tied to the DATAWIDTH. Having an addr width of 12 does not mean that you address the
    // 12 LSB of the address, since if the data width is 32, then the 2 LSB are omitted, and you therefore must address
    // bits 13 to 2, due to alignment since the 2 LSB correspond to (32/8) = 4 bytes.
    .addr_a   (addr[RAM_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET]),
    .we_a     (gnt && select_iram && we         ),
    .be_a     (be                               ),
    .d_a      (wdata                            ),
    .q_a      (instr_rdata                      ),

    .addr_b   (wb2ram_addr                      ),
    .we_b     (wb2iram_we                       ),
    .d_b      (wb2ram_data                      ),
    .q_b      (iram2wb_data                     )
  );


  /* ================================================================
  *                     Dualport BRAM - Data
  * ================================================================= */
  soc_sram_dualport #(
    .DATAWIDTH      (RAM_DATA_WIDTH     ),
    .ADDRWIDTH      (RAM_ADDR_WIDTH     ),
    .BYTE_ENABLE    (1                  )
  ) data_dualport_i (
    .clk      (clk_i                      ),

    .addr_a   (addr[RAM_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET]),
    .we_a     (gnt && select_dram && we   ),
    .be_a     (be                         ),
    .d_a      (wdata                      ),
    .q_a      (ram_rdata                  ),

    .addr_b   (wb2ram_addr                ),
    .we_b     (wb2dram_we                 ),
    .d_b      (wb2ram_data                ),
    .q_b      (dram2wb_data               )
  );
    

endmodule
