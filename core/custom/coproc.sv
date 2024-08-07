//! TODO: fix imports for icarus
// import coproc_pkg::*;

`default_nettype none
module coproc
#(
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
  input wire clk_i,
  input wire rst_ni,

  /* ====================== Compressed Interface ====================== */
  // logic
  input   wire                                      compressed_valid,
  output  logic                                     compressed_ready,
  // x_compressed_req
  input   wire  [          15: 0]                   compressed_req_instr,
  input   wire  [           1: 0]                   compressed_req_mode,
  input   wire  [X_ID_WIDTH-1: 0]                   compressed_req_id,
  // x_compressed_resp
  output  logic [          31: 0]                   compressed_resp_instr,
  output  logic                                     compressed_resp_accept,

  /* ====================== Issue Interface =========================== */
  // logic
  input   wire                                      issue_valid,
  output  logic                                     issue_ready,
  // x_issue_req_t
  input   wire  [          31: 0]                   issue_req_instr,
  input   wire  [           1: 0]                   issue_req_mode,
  input   wire  [X_ID_WIDTH-1: 0]                   issue_req_id,
  input   wire  [X_NUM_RS  -1: 0][X_RFR_WIDTH-1: 0] issue_req_rs,
  input   wire  [X_NUM_RS  -1: 0]                   issue_req_rs_valid,
  input   wire  [           5: 0]                   issue_req_ecs,
  input   wire                                      issue_req_ecs_valid,
  // x_issue_resp_t
  output  logic                                     issue_resp_accept,
  output  logic                                     issue_resp_writeback,
  output  logic                                     issue_resp_dualwrite,
  output  logic [ 2: 0]                             issue_resp_dualread,
  output  logic                                     issue_resp_loadstore,
  output  logic                                     issue_resp_ecswrite,
  output  logic                                     issue_resp_exc,
  
  /* ====================== Commit Interface ========================== */ 
  // logic
  input   wire                                      commit_valid,
  // x_commit_t
  input   wire  [X_ID_WIDTH-1: 0]                   commit_id,
  input   wire                                      commit_kill,
 
  /* ====================== Memory Req/Resp Interface ================= */
  // logic
  input   wire                                      mem_valid,
  output  logic                                     mem_ready,
  // x_mem_req_t
  output  logic  [X_ID_WIDTH   -1: 0]               mem_req_id,
  output  logic  [             31: 0]               mem_req_addr,
  output  logic  [              1: 0]               mem_req_mode,
  output  logic                                     mem_req_we,
  output  logic  [              2: 0]               mem_req_size,
  output  logic  [X_MEM_WIDTH/8-1: 0]               mem_req_be,
  output  logic  [              1: 0]               mem_req_attr,
  output  logic  [X_MEM_WIDTH  -1: 0]               mem_req_wdata,
  output  logic                                     mem_req_last,
  output  logic                                     mem_req_spec,
  // x_mem_resp_t
  input   wire                                      mem_resp_exc,
  input   wire  [ 5: 0]                             mem_resp_exccode,
  input   wire                                      mem_resp_dbg,

  /* ====================== Memory Result Interface =================== */
  // logic
  input   wire                                      mem_result_valid,
  // x_mem_result_t
  input   wire  [X_ID_WIDTH -1:0]                   mem_result_id,
  input   wire  [X_MEM_WIDTH-1:0]                   mem_result_rdata,
  input   wire                                      mem_result_err,
  input   wire                                      mem_result_dbg,
  
  /*======================= Result Interface ========================== */
  // logic
  output  logic                                     result_valid,
  input   wire                                      result_ready,
  // x_result_t
  output  logic [X_ID_WIDTH      -1:0]              result_id,
  output  logic [X_RFW_WIDTH     -1:0]              result_data,
  output  logic [                 4:0]              result_rd,
  output  logic [X_RFW_WIDTH/XLEN-1:0]              result_we,
  output  logic [                 5:0]              result_ecsdata,
  output  logic [                 2:0]              result_ecswe,
  output  logic                                     result_exc,
  output  logic [                 5:0]              result_exccode,
  output  logic                                     result_err,
  output  logic                                     result_dbg
);

  /**
  *   NOTES:
  *     - for now, do not pipeline the coprocessor. This means the input id, rs1, rs2, rd 
  *       will always be the output id, rs1, rs2, rd
  */
  logic [31:0] rs0, rs1, rd;
  logic [ 3:0] id;

  //! TODO: import this from the package
  typedef enum logic [6:0] {
    OPCODE_RMLD   = 7'h08,
    OPCODE_RMST   = 7'h09,
    OPCODE_TEST   = 7'h0a
  } coproc_opcode_e;

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      rs0               <= '0;
      rs1               <= '0;
      rd                <= '0;
      id                <= '0;
      issue_resp_accept <= '0;

      /* eXtension interface outputs */
      compressed_ready        <= '0;
      compressed_resp_instr   <= '0;
      compressed_resp_accept  <= '0;
      issue_ready             <= '0;
      issue_resp_accept       <= '0;
      issue_resp_writeback    <= '0;
      issue_resp_dualwrite    <= '0;
      issue_resp_dualread     <= '0;
      issue_resp_loadstore    <= '0;
      issue_resp_ecswrite     <= '0;
      issue_resp_exc          <= '0;
      mem_ready               <= '0;
      mem_req_id              <= '0;
      mem_req_addr            <= '0;
      mem_req_mode            <= '0;
      mem_req_we              <= '0;
      mem_req_size            <= '0;
      mem_req_be              <= '0;
      mem_req_attr            <= '0;
      mem_req_wdata           <= '0;
      mem_req_last            <= '0;
      mem_req_spec            <= '0;
      result_valid            <= '0;
      result_id               <= '0;
      result_data             <= '0;
      result_rd               <= '0;
      result_we               <= '0;
      result_ecsdata          <= '0;
      result_ecswe            <= '0;
      result_exc              <= '0;
      result_exccode          <= '0;
      result_err              <= '0;
      result_dbg              <= '0;


    end else begin
      if(issue_valid) begin
        rs0             <= issue_req_rs[0];
        rs1             <= issue_req_rs[1];
        rd              <= issue_req_instr[11:7];
        id              <= issue_req_id;
        
        case(issue_req_instr[6:0])
          OPCODE_RMLD: begin
            issue_ready           <= '0;
            issue_resp_accept     <= '0;
            issue_resp_writeback  <= '1;
            issue_resp_dualwrite  <= '0;
            issue_resp_dualread   <= '0;
            issue_resp_loadstore  <= '1;
            issue_resp_ecswrite   <= '0;
            issue_resp_exc        <= '1;  //! can cause an exception for 
                                          //  an incorrect mem address
          end
          OPCODE_RMST: begin
            issue_ready           <= '0;
            issue_resp_accept     <= '0;
            issue_resp_writeback  <= '0;
            issue_resp_dualwrite  <= '0;
            issue_resp_dualread   <= '0;
            issue_resp_loadstore  <= '1;
            issue_resp_ecswrite   <= '0;
            issue_resp_exc        <= '1;  //! can cause an exception for 
                                          //  an incorrect mem address
          end
          OPCODE_TEST: begin
            issue_ready           <= '0;
            issue_resp_accept     <= '0;
            issue_resp_writeback  <= '1;
            issue_resp_dualwrite  <= '0;
            issue_resp_dualread   <= '0;
            issue_resp_loadstore  <= '0;
            issue_resp_ecswrite   <= '0;
            issue_resp_exc        <= '0;
          end
          default: begin
            issue_ready           <= '0;
            issue_resp_accept     <= '0;
            issue_resp_writeback  <= '0;
            issue_resp_dualwrite  <= '0;
            issue_resp_dualread   <= '0;
            issue_resp_loadstore  <= '0;
            issue_resp_ecswrite   <= '0;
            issue_resp_exc        <= '0;
          end
        endcase
      end else if (result_valid) begin
        case(issue_req_instr[6:0])
          OPCODE_RMLD: begin
            //!TODO
          end
          OPCODE_RMST: begin
            //!TODO
          end
          OPCODE_TEST: begin
            result_id         <= id;
            result_data       <= 32'hDEADBEEF; // write a magic number to data
            result_rd         <= rd;
            result_we         <= '1;
            result_ecsdata    <= '0;
            result_ecswe      <= '0;
            result_exc        <= '0;
            result_exccode    <= '0;
            result_err        <= '0;
            result_dbg        <= '0;
          end
          default: begin 
            result_id         <= '0;
            result_data       <= '0;
            result_rd         <= '0;
            result_we         <= '0;
            result_ecsdata    <= '0;
            result_ecswe      <= '0;
            result_exc        <= '0;
            result_exccode    <= '0;
            result_err        <= '0;
            result_dbg        <= '0;
          end
        endcase
      end
    end
  end

endmodule
