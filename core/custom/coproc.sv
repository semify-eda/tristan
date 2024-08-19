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


  /* ====================== eXtension Interface ====================== */
  cv32e40x_if_xif.coproc_compressed        xif_compressed_if,
  cv32e40x_if_xif.coproc_issue             xif_issue_if,
  cv32e40x_if_xif.coproc_commit            xif_commit_if,
  cv32e40x_if_xif.coproc_mem               xif_mem_if,
  cv32e40x_if_xif.coproc_mem_result        xif_mem_result_if,
  cv32e40x_if_xif.coproc_result            xif_result_if
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

      /* eXtension interface outputs */
      xif_compressed_if.compressed_ready        <= '0;
      xif_compressed_if.compressed_resp.instr   <= '0;
      xif_compressed_if.compressed_resp.accept  <= '0;
      xif_issue_if.issue_ready                  <= '0;
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
      if(xif_issue_if.issue_valid) begin
        rs0 <= xif_issue_if.issue_req.rs[0];
        rs1 <= xif_issue_if.issue_req.rs[1];
        rd  <= xif_issue_if.issue_req.instr[11:7];
        id  <= xif_issue_if.issue_req.id;

        case(xif_issue_if.issue_req.instr[6:0])
          OPCODE_RMLD: begin
            xif_issue_if.issue_ready           <= '0;
            xif_issue_if.issue_resp.accept     <= '0;
            xif_issue_if.issue_resp.writeback  <= '1;
            xif_issue_if.issue_resp.dualwrite  <= '0;
            xif_issue_if.issue_resp.dualread   <= '0;
            xif_issue_if.issue_resp.loadstore  <= '1;
            xif_issue_if.issue_resp.ecswrite   <= '0;
            xif_issue_if.issue_resp.exc        <= '1;  //! can cause an exception for 
                                                        //  an incorrect mem address
          end
          OPCODE_RMST: begin
            xif_issue_if.issue_ready           <= '0;
            xif_issue_if.issue_resp.accept     <= '0;
            xif_issue_if.issue_resp.writeback  <= '0;
            xif_issue_if.issue_resp.dualwrite  <= '0;
            xif_issue_if.issue_resp.dualread   <= '0;
            xif_issue_if.issue_resp.loadstore  <= '1;
            xif_issue_if.issue_resp.ecswrite   <= '0;
            xif_issue_if.issue_resp.exc        <= '1;  //! can cause an exception for 
                                                        //  an incorrect mem address
          end
          OPCODE_TEST: begin
            xif_issue_if.issue_ready           <= '0;
            xif_issue_if.issue_resp.accept     <= '0;
            xif_issue_if.issue_resp.writeback  <= '1;
            xif_issue_if.issue_resp.dualwrite  <= '0;
            xif_issue_if.issue_resp.dualread   <= '0;
            xif_issue_if.issue_resp.loadstore  <= '0;
            xif_issue_if.issue_resp.ecswrite   <= '0;
            xif_issue_if.issue_resp.exc        <= '0;
          end
          default: begin
            xif_issue_if.issue_ready           <= '0;
            xif_issue_if.issue_resp.accept     <= '0;
            xif_issue_if.issue_resp.writeback  <= '0;
            xif_issue_if.issue_resp.dualwrite  <= '0;
            xif_issue_if.issue_resp.dualread   <= '0;
            xif_issue_if.issue_resp.loadstore  <= '0;
            xif_issue_if.issue_resp.ecswrite   <= '0;
            xif_issue_if.issue_resp.exc        <= '0;
          end
        endcase
      end else if (xif_result_if.result_valid) begin
        case(xif_issue_if.issue_req.instr[6:0])
          OPCODE_RMLD: begin
            //!TODO
          end
          OPCODE_RMST: begin
            //!TODO
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
          default: begin
            xif_result_if.result.id         <= '0;
            xif_result_if.result.data       <= '0;
            xif_result_if.result.rd         <= '0;
            xif_result_if.result.we         <= '0;
            xif_result_if.result.ecsdata    <= '0;
            xif_result_if.result.ecswe      <= '0;
            xif_result_if.result.exc        <= '0;
            xif_result_if.result.exccode    <= '0;
            xif_result_if.result.err        <= '0;
            xif_result_if.result.dbg        <= '0;
          end
        endcase
      end
    end
  end

endmodule
