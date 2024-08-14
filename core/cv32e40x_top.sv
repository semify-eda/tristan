`timescale 1ns/1ps
`default_nettype none 

module cv32e40x_top import cv32e40x_pkg::*;
#(
  parameter INSTR_RDATA_WIDTH = 32,
  parameter BOOT_ADDR         = 32'h00020000,
  parameter DM_HALTADDRESS    = 32'h1A11_0800,
  parameter HART_ID           = 32'h0000_0000,
  parameter NUM_MHPMCOUNTERS  = 1,
  parameter A_EXT             = A,
  parameter B_EXT             = B_NONE, //ZBA_ZBB_ZBC_ZBS
  parameter M_EXT             = M_NONE,
  parameter DEBUG             = 1'b0,

  // eXtension interface params
  parameter int unsigned X_NUM_RS        =  2,  // Number of register file read ports that can be used by the eXtension interface
  parameter int unsigned X_ID_WIDTH      =  4,  // Width of ID field.
  parameter int unsigned X_MEM_WIDTH     =  32, // Memory access width for loads/stores via the eXtension interface
  parameter int unsigned X_RFR_WIDTH     =  32, // Register file read access width for the eXtension interface
  parameter int unsigned X_RFW_WIDTH     =  32, // Register file write access width for the eXtension interface
  parameter logic [31:0] X_MISA          =  '0, // MISA extensions implemented on the eXtension interface
  parameter logic [ 1:0] X_ECS_XS        =  '0, // Default value for mstatus.XS
  parameter int XLEN                     = 32,
  parameter int FLEN                     = 32
)
(
  // Clock and reset
  input   wire          clk_i,
  input   wire          rst_ni,

  // Instruction memory interface
  output  wire          instr_req_o,
  input   wire          instr_gnt_i,
  input   wire          instr_rvalid_i,
  output  wire [31: 0]  instr_addr_o,
  input   wire [31: 0]  instr_rdata_i,

  // Data memory interface
  output  wire          data_req_o,
  input   wire          data_gnt_i,
  input   wire          data_rvalid_i,
  output  wire [31: 0]  data_addr_o,
  output  wire [ 3: 0]  data_be_o,
  output  wire          data_we_o,
  output  wire [31: 0]  data_wdata_o,
  input   wire [31: 0]  data_rdata_i,

  // Cycle count
  output  wire [63:0]   mcycle_o,

  // Debug interface
  input   wire          debug_req_i,

  // CPU control signals
  input   wire          fetch_enable_i,
  output  wire          core_sleep_o,

  /** 
  *   Coprocessor eXtension interface signals
  */
  /* ====================== Compressed Interface ====================== */
  // logic
  output  logic                                     compressed_valid,
  input   wire                                      compressed_ready,
  // x_compressed_req
  output  logic [          15: 0]                   compressed_req_instr,
  output  logic [           1: 0]                   compressed_req_mode,
  output  logic [X_ID_WIDTH-1: 0]                   compressed_req_id,
  // x_compressed_resp
  input   wire  [          31: 0]                   compressed_resp_instr,
  input   wire                                      compressed_resp_accept,

  /* ====================== Issue Interface =========================== */
  // logic
  output  logic                                     issue_valid,
  input   wire                                      issue_ready,
  // x_issue_req_t
  output  logic [          31: 0]                   issue_req_instr,
  output  logic [           1: 0]                   issue_req_mode,
  output  logic [X_ID_WIDTH-1: 0]                   issue_req_id,
  output  logic [X_NUM_RS  -1: 0][X_RFR_WIDTH-1: 0] issue_req_rs,
  output  logic [X_NUM_RS  -1: 0]                   issue_req_rs_valid,
  output  logic [           5: 0]                   issue_req_ecs,
  output  logic                                     issue_req_ecs_valid,
  // x_issue_resp_t
  input   wire                                      issue_resp_accept,
  input   wire                                      issue_resp_writeback,
  input   wire                                      issue_resp_dualwrite,
  input   wire  [ 2: 0]                             issue_resp_dualread,
  input   wire                                      issue_resp_loadstore,
  input   wire                                      issue_resp_ecswrite,
  input   wire                                      issue_resp_exc,
  
  /* ====================== Commit Interface ========================== */ 
  // logic
  output  logic                                     commit_valid,
  // x_commit_t
  output  logic [X_ID_WIDTH-1: 0]                   commit_id,
  output  logic                                     commit_kill,
 
  /* ====================== Memory Req/Resp Interface ================= */
  // logic
  output  logic mem_valid,
  input   wire  mem_ready,
  // x_mem_req_t
  input   wire   [X_ID_WIDTH   -1: 0]               mem_req_id,
  input   wire   [             31: 0]               mem_req_addr,
  input   wire   [              1: 0]               mem_req_mode,
  input   wire                                      mem_req_we,
  input   wire   [              2: 0]               mem_req_size,
  input   wire   [X_MEM_WIDTH/8-1: 0]               mem_req_be,
  input   wire   [              1: 0]               mem_req_attr,
  input   wire   [X_MEM_WIDTH  -1: 0]               mem_req_wdata,
  input   wire                                      mem_req_last,
  input   wire                                      mem_req_spec,
  // x_mem_resp_t
  output  logic                                     mem_resp_exc,
  output  logic [ 5: 0]                             mem_resp_exccode,
  output  logic                                     mem_resp_dbg,

  /* ====================== Memory Result Interface =================== */
  // logic
  output  logic                                     mem_result_valid,
  // x_mem_result_t
  output  logic [X_ID_WIDTH -1:0]                   mem_result_id,
  output  logic [X_MEM_WIDTH-1:0]                   mem_result_rdata,
  output  logic                                     mem_result_err,
  output  logic                                     mem_result_dbg,
  
  /*======================= Result Interface ========================== */
  // logic
  input   wire  result_valid,
  output  logic result_ready,
  // x_result_t
  input   wire  [X_ID_WIDTH      -1:0]              result_id,
  input   wire  [X_RFW_WIDTH     -1:0]              result_data,
  input   wire  [                 4:0]              result_rd,
  input   wire  [X_RFW_WIDTH/XLEN-1:0]              result_we,
  input   wire  [                 5:0]              result_ecsdata,
  input   wire  [                 2:0]              result_ecswe,
  input   wire                                      result_exc,
  input   wire  [                 5:0]              result_exccode,
  input   wire                                      result_err,
  input   wire                                      result_dbg
);

  localparam X_EXT = 1'b1; // enable xtension interface
  cv32e40x_if_xif #(
    .X_NUM_RS    ( X_NUM_RS ),
    .X_MEM_WIDTH ( 32 ),
    .X_RFR_WIDTH ( 32 ),
    .X_RFW_WIDTH ( 32 ),
    .X_MISA      ( '0 )
  ) ext_if();

  /** =================================================================
  *   eXtension Interface
  * =================================================================== */

  /* ====================== Compressed Interface ====================== */
  assign compressed_valid                         = ext_if.compressed_valid; 
  assign ext_if.compressed_ready                  = compressed_ready;
  assign compressed_req_instr                     = ext_if.compressed_req.instr;
  assign compressed_req_mode                      = ext_if.compressed_req.mode;
  assign compressed_req_id                        = ext_if.compressed_req.id;
  assign ext_if.compressed_resp.instr             = compressed_resp_instr;
  assign ext_if.compressed_resp.accept            = compressed_resp_accept;

  /* ====================== Issue Interface =========================== */
  assign issue_valid                              = ext_if.issue_valid;
  assign ext_if.issue_ready                       = issue_ready;
  assign issue_req_instr                          = ext_if.issue_req.instr;
  assign issue_req_mode                           = ext_if.issue_req.mode;
  assign issue_req_id                             = ext_if.issue_req.id;
  assign issue_req_rs                             = ext_if.issue_req.rs;
  assign issue_req_rs_valid                       = ext_if.issue_req.rs_valid;
  assign issue_req_ecs                            = ext_if.issue_req.ecs;
  assign issue_req_ecs_valid                      = ext_if.issue_req.ecs_valid;
  assign ext_if.issue_resp.accept                 = issue_resp_accept;
  assign ext_if.issue_resp.writeback              = issue_resp_writeback;
  assign ext_if.issue_resp.dualwrite              = issue_resp_dualwrite;
  assign ext_if.issue_resp.dualread               = issue_resp_dualread;
  assign ext_if.issue_resp.loadstore              = issue_resp_loadstore;
  assign ext_if.issue_resp.ecswrite               = issue_resp_ecswrite;
  assign ext_if.issue_resp.exc                    = issue_resp_exc;

  /* ====================== Commit Interface ========================== */ 
  assign commit_valid                             = ext_if.commit_valid;
  assign commit_id                                = ext_if.commit.id;
  assign commit_kill                              = ext_if.commit.commit_kill;

  /* ====================== Memory Req/Resp Interface ================= */
  assign mem_valid                                = ext_if.mem_valid;
  assign ext_if.mem_ready                         = mem_ready;
  assign ext_if.mem_req.id                        = mem_req_id;
  assign ext_if.mem_req.addr                      = mem_req_addr;
  assign ext_if.mem_req.mode                      = mem_req_mode;
  assign ext_if.mem_req.we                        = mem_req_we;
  assign ext_if.mem_req.size                      = mem_req_size;
  assign ext_if.mem_req.be                        = mem_req_be;
  assign ext_if.mem_req.attr                      = mem_req_attr;
  assign ext_if.mem_req.wdata                     = mem_req_wdata;
  assign ext_if.mem_req.last                      = mem_req_last;
  assign ext_if.mem_req.spec                      = mem_req_spec;
  assign mem_resp_exc                             = ext_if.mem_resp.exc;
  assign mem_resp_exccode                         = ext_if.mem_resp.exccode;
  assign mem_resp_dbg                             = ext_if.mem_resp.dbg;

  /* ====================== Memory Result Interface =================== */
  assign mem_result_valid                         = ext_if.mem_result_valid;
  assign mem_result_id                            = ext_if.mem_result_valid;
  assign mem_result_rdata                         = ext_if.mem_result_valid;
  assign mem_result_err                           = ext_if.mem_result_valid;
  assign mem_result_dbg                           = ext_if.mem_result_valid;
  
  /*======================= Result Interface - Writeback to rd ======== */
  assign ext_if.result_valid                      = result_valid;
  assign result_ready                             = ext_if.result_ready;
  assign ext_if.result.id                         = result_id;
  assign ext_if.result.data                       = result_data;
  assign ext_if.result.rd                         = result_rd;
  assign ext_if.result.we                         = result_we;
  assign ext_if.result.ecsdata                    = result_ecsdata;
  assign ext_if.result.ecswe                      = result_ecswe;
  assign ext_if.result.exc                        = result_exc;
  assign ext_if.result.exccode                    = result_exccode;
  assign ext_if.result.err                        = result_err;
  assign ext_if.result.dbg                        = result_dbg;
  
  /*=================================================================== */ 
  
  cv32e40x_core
  #(
    .NUM_MHPMCOUNTERS       (NUM_MHPMCOUNTERS       ), 
    .A_EXT                  (A                      ),
    .B_EXT                  (B_NONE                 ), //ZBA_ZBB_ZBC_ZBS
    .M_EXT                  (M_NONE                 ),
    .X_EXT                  (1'b1                   ), // enable xtension interface
    .X_NUM_RS               (X_NUM_RS               ),
    .DEBUG                  (1'b0                   )
  )
  cv32e40x_core_inst
  (
    // Clock and reset
    .clk_i                  ( clk_i                 ),
    .rst_ni                 ( rst_ni                ),
    .scan_cg_en_i           ( '0                    ),

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
    .mcycle_o               ( mcycle_o              ),
    .time_i                 ( 64'b0                 ),

    // eXtension interface
    .xif_compressed_if      ( ext_if.cpu_compressed ),
    .xif_issue_if           ( ext_if.cpu_issue      ),
    .xif_commit_if          ( ext_if.cpu_commit     ),
    .xif_mem_if             ( ext_if.cpu_mem        ),
    .xif_mem_result_if      ( ext_if.cpu_mem_result ),
    .xif_result_if          ( ext_if.cpu_result     ),

    // Basic interrupt architecture
    .irq_i                  ( {32{1'b0}}            ),

    // Event wakeup signal
    .wu_wfe_i               ( 1'b0                  ),

    // Smclic interrupt architecture
    .clic_irq_i             ( 1'b0                  ),
    .clic_irq_id_i          ( '0                    ),
    .clic_irq_level_i       ( 8'h0                  ),
    .clic_irq_priv_i        ( 2'h0                  ),
    .clic_irq_shv_i         ( 1'b0                  ),

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
`default_nettype wire 