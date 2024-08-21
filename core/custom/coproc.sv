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


  typedef enum logic [3:0] {
    IDLE          = 4'b0001,
    EXECUTE       = 4'b0010,
    MEM_RESP      = 4'b0100,
    RETIRE        = 4'b1000
  } coproc_state_e;

  /**
  *   NOTES:
  *     - for now, do not pipeline the coprocessor. This means the input id, rs1, rs2, rd
  *       will always be the output id, rs1, rs2, rd
  */
  logic [31:0]    rs1, rs2, rd;
  logic [ 3:0]    id;
  logic           issue_valid_ff;
  logic           commit_valid, commit_valid_ff;
  logic           commit_kill;

  // memory signals
  logic [31:0]    mem_rdata;
  logic           mem_err, mem_dbg;

  coproc_opcode_e opcode;
  // FSM
  coproc_state_e state_ff, state_next;

  assign opcode = coproc_opcode_e'(xif_issue_if.issue_req.instr[6:0]);
  assign commit_kill = xif_commit_if.commit.commit_kill;

  // sticky signals
  assign commit_valid = commit_valid_ff | xif_commit_if.commit_valid;
  always_ff @(posedge clk_i, negedge rst_ni) begin : commit_monitor
    if(~rst_ni) begin
      commit_valid_ff <= '0;
      issue_valid_ff  <= '0;
    end else begin
      if(xif_commit_if.commit_valid) begin
        commit_valid_ff <= '1;
      end else if(xif_result_if.result_valid) begin
        commit_valid_ff <= '0;
      end
      if(xif_issue_if.issue_valid) begin
        issue_valid_ff  <= '1;
      end else if(xif_result_if.result_valid) begin
        issue_valid_ff  <= '0;
      end
    end
  end : commit_monitor

  // Combinational Signals
  assign xif_issue_if.issue_resp.accept     = (opcode == OPCODE_RMLD | opcode == OPCODE_RMST | opcode == OPCODE_TEST);
  assign xif_issue_if.issue_resp.writeback  = (opcode == OPCODE_TEST | opcode == OPCODE_RMST);


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
          if(issue_valid_ff) begin
            state_next = EXECUTE;
          end
        EXECUTE:
          if(commit_valid) begin
            if(opcode == OPCODE_RMST | opcode == OPCODE_RMLD) begin
              state_next = xif_mem_if.mem_ready ? MEM_RESP : EXECUTE;
            end else begin
              state_next = RETIRE;
            end
          end
        MEM_RESP:
          if(xif_mem_result_if.mem_result_valid) begin
            state_next = RETIRE;
          end
        RETIRE:
          if(xif_result_if.result_ready) begin
              state_next = IDLE;
          end
        default:
          state_next = IDLE;
      endcase
    end
  end : next_state_logic


  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      /* local variables */
      rs1                                       <= '0;
      rs2                                       <= '0;
      rd                                        <= '0;
      id                                        <= '0;

      /* eXtension interface outputs */
      xif_compressed_if.compressed_ready        <= '0;
      xif_compressed_if.compressed_resp.instr   <= '0;
      xif_compressed_if.compressed_resp.accept  <= '0;
      xif_issue_if.issue_ready                  <= '1;
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
      xif_result_if.result_valid                <= '0;
      xif_mem_if.mem_valid                      <= '0;
      case(state_ff)
        IDLE: begin
          rs1 <= xif_issue_if.issue_req.rs[0];
          rs2 <= xif_issue_if.issue_req.rs[1];
          rd  <= xif_issue_if.issue_req.instr[11:7];
          id  <= xif_issue_if.issue_req.id;
        end
      endcase
      case(state_next)
        EXECUTE: begin
          xif_issue_if.issue_resp.dualwrite   <= '0;
          xif_issue_if.issue_resp.dualread    <= '0;
          xif_issue_if.issue_resp.loadstore   <= '0;
          xif_issue_if.issue_resp.ecswrite    <= '0;
          xif_issue_if.issue_resp.exc         <= '0;
          xif_issue_if.issue_ready            <= '0;
          case(opcode)
            OPCODE_RMLD: begin
              //! wiggle these signals
              xif_issue_if.issue_resp.loadstore   <= '1;
              xif_issue_if.issue_resp.exc         <= '1; //! can cause an exception for
                                                        //  an incorrect mem address

            end
            OPCODE_RMST: begin
              //! wiggle these signals
              xif_mem_if.mem_valid                <= '1;
              xif_mem_if.mem_req.id               <= xif_issue_if.issue_req.id;
              xif_mem_if.mem_req.addr             <= xif_issue_if.issue_req.rs[0];
              xif_mem_if.mem_req.mode             <= '1;    // set to machine level for now
              xif_mem_if.mem_req.we               <= '1;
              xif_mem_if.mem_req.size             <= 3'h2;  // set to a word (32b)
              xif_mem_if.mem_req.be               <= '1;    // enable all bytes
              xif_mem_if.mem_req.attr[1]          <= '1;    // set as modifiable
              xif_mem_if.mem_req.attr[0]          <= '0;    // set as aligned
              xif_mem_if.mem_req.wdata            <= xif_issue_if.issue_req.rs[1];
              xif_mem_if.mem_req.last             <= '1;    // declare the memory transaction to be the last for the offloaded instruction
              xif_mem_if.mem_req.spec             <= '0;    // memory trasnaction is not speculative


              xif_issue_if.issue_resp.loadstore   <= '1;
              xif_issue_if.issue_resp.exc         <= '1; //! can cause an exception for
                                                        //  an incorrect mem address
            end
            OPCODE_TEST: begin
              //! wiggle these signals
            end
          endcase
        end
        RETIRE: begin
          xif_issue_if.issue_ready        <= '1;
          xif_result_if.result_valid      <= '1;
          xif_result_if.result.id         <= id;

          xif_result_if.result.data       <= '0;
          xif_result_if.result.rd         <= '0;
          xif_result_if.result.we         <= '0;
          xif_result_if.result.ecsdata    <= '0;
          xif_result_if.result.ecswe      <= '0;
          xif_result_if.result.exc        <= '0;
          xif_result_if.result.exccode    <= '0;
          xif_result_if.result.err        <= '0;
          xif_result_if.result.dbg        <= '0;

          case(opcode)
            OPCODE_RMLD: begin
              //! wiggle these signals
            end
            OPCODE_RMST: begin
              //! wiggle these signals
              mem_rdata                       <= xif_mem_result_if.mem_result.rdata;
              mem_dbg                         <= xif_mem_result_if.mem_result.dbg;
              mem_err                         <= xif_mem_result_if.mem_result.err;
            end
            OPCODE_TEST: begin
              xif_result_if.result.data       <= 32'hDEADBEEF; // write a magic number to data
              xif_result_if.result.rd         <= rd;
              xif_result_if.result.we         <= '1;
            end
          endcase
        end
      endcase
    end
  end

endmodule
