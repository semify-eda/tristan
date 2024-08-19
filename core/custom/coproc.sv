//! TODO: fix imports for icarus

`default_nettype none
module coproc import coproc_pkg::*;
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


  /* ====================== eXtension Interface ====================== */
  cv32e40x_if_xif.coproc_compressed        xif_compressed_if,
  cv32e40x_if_xif.coproc_issue             xif_issue_if,
  cv32e40x_if_xif.coproc_commit            xif_commit_if,
  cv32e40x_if_xif.coproc_mem               xif_mem_if,
  cv32e40x_if_xif.coproc_mem_result        xif_mem_result_if,
  cv32e40x_if_xif.coproc_result            xif_result_if
);


  typedef enum logic [2:0] {
    IDLE          = 3'b001,
    EXECUTE       = 3'b010,
    RETIRE        = 3'b100
  } coproc_state_e;

  /**
  *   NOTES:
  *     - for now, do not pipeline the coprocessor. This means the input id, rs1, rs2, rd
  *       will always be the output id, rs1, rs2, rd
  */
  logic [31:0]    rs1, rs2, rd;
  logic [ 3:0]    id;
  logic           operation_complete;
  logic           commit_valid, commit_valid_ff;
  logic           commit_kill;
  
  coproc_opcode_e opcode;
  // FSM
  coproc_state_e state_ff, state_next;

  assign opcode = coproc_opcode_e'(xif_issue_if.issue_req.instr[6:0]);
  assign commit_kill = xif_commit_if.commit.commit_kill;

  always_ff @(posedge clk_i, negedge rst_ni) begin : next_state_assign
    if (~rst_ni) begin
      state_ff <= IDLE;
    end else begin
      state_ff <= state_next;
    end
  end : next_state_assign

  always_comb begin : next_state_logic
    state_next = state_ff;
    if(commit_kill) begin
      state_next = IDLE;
    end else begin
      unique case(state_ff)
        IDLE:
          if(xif_issue_if.issue_valid)
            state_next = EXECUTE;
        EXECUTE:
          if(operation_complete & commit_valid)
            state_next = RETIRE;
        RETIRE:
          if(xif_result_if.result_ready)
            state_next = IDLE;
        default:
          state_next = IDLE;
      endcase
    end

  end : next_state_logic

  assign commit_valid = commit_valid_ff | xif_commit_if.commit_valid;
  always_ff @(posedge clk_i, negedge rst_ni) begin : commit_monitor
    if(~rst_ni) begin
      commit_valid_ff <= '0;
    end else begin
      if(xif_commit_if.commit_valid) begin
        commit_valid_ff <= '1;
      end else if(state_ff == RETIRE) begin
        commit_valid_ff <= '0;
      end
    end
  end : commit_monitor

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      /* local variables */
      rs1                                       <= '0;
      rs2                                       <= '0;
      rd                                        <= '0;
      id                                        <= '0;
      operation_complete                        <= '1;

      /* eXtension interface outputs */
      xif_compressed_if.compressed_ready        <= '0;
      xif_compressed_if.compressed_resp.instr   <= '0;
      xif_compressed_if.compressed_resp.accept  <= '0;
      xif_issue_if.issue_ready                  <= '1;
      xif_issue_if.issue_resp.accept            <= '0;
      xif_issue_if.issue_resp.writeback         <= '0;
      xif_issue_if.issue_resp.dualwrite         <= '0;
      xif_issue_if.issue_resp.dualread          <= '0;
      xif_issue_if.issue_resp.loadstore         <= '0;
      xif_issue_if.issue_resp.ecswrite          <= '0;
      xif_issue_if.issue_resp.exc               <= '0;
      xif_mem_if.mem_valid                      <= '0;
      xif_mem_if.mem_req.id                     <= '0;
      xif_mem_if.mem_req.addr                   <= '0;
      xif_mem_if.mem_req.mode                   <= '0;
      xif_mem_if.mem_req.we                     <= '0;
      xif_mem_if.mem_req.size                   <= '0;
      xif_mem_if.mem_req.be                     <= '0;
      xif_mem_if.mem_req.attr                   <= '0;
      xif_mem_if.mem_req.wdata                  <= '0;
      xif_mem_if.mem_req.last                   <= '0;
      xif_mem_if.mem_req.spec                   <= '0;
      xif_result_if.result_valid                <= '0;
      xif_result_if.result.id                   <= '0;
      xif_result_if.result.data                 <= '0;
      xif_result_if.result.rd                   <= '0;
      xif_result_if.result.we                   <= '0;
      xif_result_if.result.ecsdata              <= '0;
      xif_result_if.result.ecswe                <= '0;
      xif_result_if.result.exc                  <= '0;
      xif_result_if.result.exccode              <= '0;
      xif_result_if.result.err                  <= '0;
      xif_result_if.result.dbg                  <= '0;

    end else begin
      case(state_next)
        EXECUTE: begin
          rs1 <= xif_issue_if.issue_req.rs[0];
          rs2 <= xif_issue_if.issue_req.rs[1];
          rd  <= xif_issue_if.issue_req.instr[11:7];
          id  <= xif_issue_if.issue_req.id;

          xif_issue_if.issue_resp.accept     <= '0;
          xif_issue_if.issue_resp.writeback  <= '0;
          xif_issue_if.issue_resp.dualwrite  <= '0;
          xif_issue_if.issue_resp.dualread   <= '0;
          xif_issue_if.issue_resp.loadstore  <= '0;
          xif_issue_if.issue_resp.ecswrite   <= '0;
          xif_issue_if.issue_resp.exc        <= '0;

          // keep issue_ready high for the first cycle in the the EXECUTE state
          xif_issue_if.issue_ready           <= state_ff == EXECUTE ? '0 : '1;
          case(opcode)
            OPCODE_RMLD: begin
              //! wiggle these signals
              xif_issue_if.issue_resp.writeback  <= '1;
              xif_issue_if.issue_resp.loadstore  <= '1;
              xif_issue_if.issue_resp.exc        <= '1; //! can cause an exception for
                                                        //  an incorrect mem address
            end
            OPCODE_RMST: begin
              //! wiggle these signals
              xif_issue_if.issue_resp.loadstore  <= '1;
              xif_issue_if.issue_resp.exc        <= '1; //! can cause an exception for
                                                        //  an incorrect mem address
            end
            OPCODE_TEST: begin
              //! wiggle these signals
              xif_issue_if.issue_resp.accept     <= '1;
              xif_issue_if.issue_resp.writeback  <= '1;
            end
          endcase
        end
        RETIRE: begin

          xif_issue_if.issue_ready        <= '1;
          xif_result_if.result_valid      <= '1;

          xif_result_if.result.id         <= 'x;
          xif_result_if.result.data       <= 'x;
          xif_result_if.result.rd         <= 'x;
          xif_result_if.result.we         <= 'x;
          xif_result_if.result.ecsdata    <= 'x;
          xif_result_if.result.ecswe      <= 'x;
          xif_result_if.result.exc        <= 'x;
          xif_result_if.result.exccode    <= 'x;
          xif_result_if.result.err        <= 'x;
          xif_result_if.result.dbg        <= 'x;

          case(opcode)
            OPCODE_RMLD: begin
              //! wiggle these signals
            end
            OPCODE_RMST: begin
              //! wiggle these signals
            end
            OPCODE_TEST: begin
              xif_result_if.result.id         <= id;
              xif_result_if.result.data       <= 32'hDEADBEEF; // write a magic number to data
              xif_result_if.result.rd         <= rd;
              xif_result_if.result.we         <= '1;
              xif_result_if.result.ecsdata    <= '0;
              xif_result_if.result.ecswe      <= '0;
              xif_result_if.result.exc        <= '0;
              xif_result_if.result.exccode    <= '0;
              xif_result_if.result.err        <= '0;
              xif_result_if.result.dbg        <= '0;
            end
          endcase
        end
      endcase

    end
  end

endmodule
