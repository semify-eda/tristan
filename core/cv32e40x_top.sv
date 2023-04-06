module cv32e40x_top import cv32e40x_pkg::*;
#(
    parameter INSTR_RDATA_WIDTH = 32,
              RAM_ADDR_WIDTH    = 20,
              BOOT_ADDR         = 'h0,//'h80,
              DM_HALTADDRESS    = 32'h1A11_0800,
              HART_ID           = 32'h0000_0000,
              NUM_MHPMCOUNTERS  = 1
)
(
    // Clock and reset
    input  logic                          clk_i,
    input  logic                          rst_ni,

    // Instruction memory interface
    output logic                          instr_req_o,
    input  logic                          instr_gnt_i,
    input  logic                          instr_rvalid_i,
    output logic [31:0]                   instr_addr_o,
    input  logic [31:0]                   instr_rdata_i,

    // Data memory interface
    output logic                          data_req_o,
    input  logic                          data_gnt_i,
    input  logic                          data_rvalid_i,
    output logic [31:0]                   data_addr_o,
    output logic [3:0]                    data_be_o,
    output logic                          data_we_o,
    output logic [31:0]                   data_wdata_o,
    input  logic [31:0]                   data_rdata_i,

    // Cycle count
    output logic [63:0]                   mcycle_o,

    // eXtension interface
    //if_xif.cpu_compressed                 xif_compressed_if,
    //if_xif.cpu_issue                      xif_issue_if,
    //if_xif.cpu_commit                     xif_commit_if,
    //if_xif.cpu_mem                        xif_mem_if,
    //if_xif.cpu_mem_result                 xif_mem_result_if,
    //if_xif.cpu_result                     xif_result_if,

    // Debug interface
    input  logic                          debug_req_i,

    // CPU control signals
    input  logic                          fetch_enable_i,
    output logic                          core_sleep_o
);

    localparam X_NUM_RS = 2;

    if_xif #(
        .X_NUM_RS    ( X_NUM_RS ),
        .X_MEM_WIDTH ( 32 ),
        .X_RFR_WIDTH ( 32 ),
        .X_RFW_WIDTH ( 32 ),
        .X_MISA      ( '0 )
    ) ext_if();
    
    /*typedef ext_if.x_compressed_req_t x_compressed_req_t;
    typedef ext_if.x_compressed_resp_t x_compressed_resp_t;
    typedef ext_if.x_issue_req_t x_issue_req_t;
    typedef ext_if.x_issue_resp_t x_issue_resp_t;
    typedef ext_if.x_commit_t x_commit_t;
    typedef ext_if.x_mem_req_t x_mem_req_t;
    typedef ext_if.x_mem_resp_t x_mem_resp_t;
    typedef ext_if.x_mem_result_t x_mem_result_t;
    typedef ext_if.x_result_t x_result_t;*/

    coproc coproc_inst
    (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .xif_compressed (ext_if.coproc_compressed),
        .xif_issue      (ext_if.coproc_issue),
        .xif_commit     (ext_if.coproc_commit),
        .xif_mem        (ext_if.coproc_mem),
        .xif_mem_result (ext_if.coproc_mem_result),
        .xif_result     (ext_if.coproc_result)
    );

    /*
    // Compressed interface
    logic               compressed_valid;
    logic               compressed_ready;
    x_compressed_req_t  compressed_req;
    x_compressed_resp_t compressed_resp;

    // Issue interface
    logic               issue_valid;
    logic               issue_ready;
    x_issue_req_t       issue_req;
    x_issue_resp_t      issue_resp;

    // Commit interface
    logic               commit_valid;
    x_commit_t          commit;

    // Memory (request/response) interface
    logic               mem_valid;
    logic               mem_ready;
    x_mem_req_t         mem_req;
    x_mem_resp_t        mem_resp;

    // Memory result interface
    logic               mem_result_valid;
    x_mem_result_t      mem_result;

    // Result interface
    logic               result_valid;
    logic               result_ready;
    x_result_t          result;

    assign compressed_valid = ext_if.coproc_compressed.compressed_valid;
    assign ext_if.coproc_compressed.compressed_ready = compressed_ready;
    assign compressed_req = ext_if.coproc_compressed.compressed_req;
    assign ext_if.coproc_compressed.compressed_resp = compressed_resp;

    assign issue_valid = ext_if.coproc_issue.issue_valid;
    assign ext_if.coproc_issue.issue_ready = issue_ready;
    assign issue_req = ext_if.coproc_issue.issue_req;
    assign ext_if.coproc_issue.issue_resp = issue_resp;

    assign commit_valid = ext_if.coproc_commit.commit_valid;
    assign commit = ext_if.coproc_commit.commit;

    assign ext_if.coproc_mem.mem_valid = mem_valid;
    assign mem_ready = ext_if.coproc_mem.mem_ready;
    assign ext_if.coproc_mem.mem_req = mem_req;
    assign mem_resp = ext_if.coproc_mem.mem_resp;

    assign mem_result_valid = ext_if.coproc_mem_result.mem_result_valid;
    assign mem_result = ext_if.coproc_mem_result.mem_result;
    
    assign ext_if.coproc_result.result_valid = result_valid;
    assign result_ready = ext_if.coproc_result.result_ready;
    assign ext_if.coproc_result.result = result;
    */

    cv32e40x_core
    #(
        .NUM_MHPMCOUNTERS (NUM_MHPMCOUNTERS),
        .B_EXT (ZBA_ZBB_ZBC_ZBS), //ZBA_ZBB_ZBC_ZBS
        .X_EXT (1'b1), // enable xtension interface
        .X_NUM_RS (X_NUM_RS)
    )
    cv32e40x_core_inst
    (
      // Clock and reset
      .clk_i                 ( clk_i                 ),
      .rst_ni                ( rst_ni                ),
      .scan_cg_en_i          ( '0                    ),

      // Static configuration
     .boot_addr_i            ( BOOT_ADDR             ),
     .dm_exception_addr_i    ( '0                    ),
     .dm_halt_addr_i         ( DM_HALTADDRESS        ),
     .mhartid_i              ( HART_ID               ),
     .mimpid_patch_i         ( '0                    ),
     .mtvec_addr_i           ( '0                    ),

      // Instruction memory interface
     .instr_req_o            ( instr_req_o           ),
     .instr_gnt_i            ( instr_gnt_i           ),
     .instr_rvalid_i         ( instr_rvalid_i        ),
     .instr_addr_o           ( instr_addr_o          ),
     .instr_memtype_o        (                       ),
     .instr_prot_o           (                       ),
     .instr_dbg_o            (                       ),
     .instr_rdata_i          ( instr_rdata_i         ),
     .instr_err_i            ( 1'b0                  ),

      // Data memory interface
     .data_req_o             ( data_req_o            ),
     .data_gnt_i             ( data_gnt_i            ),
     .data_rvalid_i          ( data_rvalid_i         ),
     .data_addr_o            ( data_addr_o           ),
     .data_be_o              ( data_be_o             ),
     .data_we_o              ( data_we_o             ),
     .data_wdata_o           ( data_wdata_o          ),
     .data_memtype_o         (                       ),
     .data_prot_o            (                       ),
     .data_dbg_o             (                       ),
     .data_atop_o            (                       ),
     .data_rdata_i           ( data_rdata_i          ),
     .data_err_i             ( 1'b0                  ),
     .data_exokay_i          ( 1'b1                  ),

      // Cycle count
      .mcycle_o              (mcycle_o               ),

      // eXtension interface
      .xif_compressed_if     (ext_if                 ),
      .xif_issue_if          (ext_if                 ),
      .xif_commit_if         (ext_if                 ),
      .xif_mem_if            (ext_if                 ),
      .xif_mem_result_if     (ext_if                 ),
      .xif_result_if         (ext_if                 ),

      // Basic interrupt architecture
      .irq_i                 ( {32{1'b0}}            ),

      // Event wakeup signal
      .wu_wfe_i              ( 1'b0                  ),

      // Smclic interrupt architecture
      .clic_irq_i            ( 1'b0                  ),
      .clic_irq_id_i         ( '0                    ),
      .clic_irq_level_i      ( 8'h0                  ),
      .clic_irq_priv_i       ( 2'h0                  ),
      .clic_irq_shv_i        ( 1'b0                  ),

     // Fencei flush handshake
     .fencei_flush_req_o     (                       ),
     .fencei_flush_ack_i     ( 1'b0                  ),

     .debug_req_i            ( debug_req_i           ),
     .debug_havereset_o      (                       ),
     .debug_running_o        (                       ),
     .debug_halted_o         (                       ),

     // CPU Control Signals
     .fetch_enable_i         ( fetch_enable_i        ),
     .core_sleep_o           ( core_sleep_o          )
    );

endmodule
