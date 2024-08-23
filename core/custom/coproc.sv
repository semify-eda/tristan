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


  // onehot encoding of states
  typedef enum {
    IDLE,
    CFG,
    MEM_RD1,
    MEM_RD2,
    UPDATE,
    MEM_WR1,
    MEM_WR2,
    STALL,
    RETIRE,
    INVALID,
    KILL
  } coproc_state_e;

  /* ====================== Control Registers ====================== */
  logic [31:0] ld_addr;             // address of start of read (load) stream
  logic [31:0] st_addr;             // address of start of write (store) stream
  logic [31:0] shadow_reg;          // shadow data register
  logic [31:0] data_load_reg;       // custom data register
  logic [63:0] rbuf;                // read data buffer

  /* ====================== Control Signals ====================== */
  logic cfg;
  assign cfg = funct3[2];
  /**
  *   NOTES:
  *     - for now, do not pipeline the coprocessor. This means the input id, rs1, rs2, rd
  *       will always be the output id, rs1, rs2, rd
  */
  logic [31:0]    rs1, rs2, rd;
  logic [ 3:0]    id;
  logic           issue_valid_ff;
  logic           commit_valid,     commit_valid_ff;

  /* ====================== Memory Signals ====================== */
  logic [31:0]    mem_rdata;
  logic           mem_err, mem_dbg;

  coproc_opcode_e opcode;
  rmst_funct3_e   funct3;
  // FSM
  coproc_state_e state_ff, state_next;

  assign opcode = coproc_opcode_e'(xif_issue_if.issue_req.instr[ 6: 0]);
  assign funct3 =  rmst_funct3_e'(xif_issue_if.issue_req.instr[14:12]);

  // sticky signals
  /* ====================== Sticky Signals ====================== */
  assign commit_valid     = commit_valid_ff     | xif_commit_if.commit_valid;
  always_ff @(posedge clk_i, negedge rst_ni) begin : commit_monitor
    if(~rst_ni) begin
      commit_valid_ff     <= '0;
      issue_valid_ff      <= '0;
    end else begin
      if(xif_commit_if.commit_valid) begin
        commit_valid_ff     <= '1;
      end else if(xif_result_if.result_valid) begin
        commit_valid_ff     <= '0;
      end
      if(xif_issue_if.issue_valid) begin
        issue_valid_ff      <= '1;
      end else if(xif_result_if.result_valid) begin
        issue_valid_ff      <= '0;
      end
    end
  end : commit_monitor

  /* ================== Combinational Handshake Signals ====================== */
  assign xif_issue_if.issue_resp.accept     = opcode == OPCODE_RMLD | opcode == OPCODE_RMST;
  assign xif_issue_if.issue_resp.writeback  = opcode == OPCODE_RMST;


  /* ================== State Machine ====================== */
  always_ff @(posedge clk_i, negedge rst_ni) begin : next_state_assign
    if (~rst_ni) begin
      state_ff <= IDLE;
    end else begin
      state_ff <= state_next;
    end
  end : next_state_assign

  always_comb begin : next_state_logic
    state_next = state_ff;
    if(xif_commit_if.commit.commit_kill) begin
      state_next = KILL;
    end else begin
      unique case(state_ff)
        IDLE:
          if(issue_valid_ff) begin
            if(opcode == OPCODE_RMST | opcode == OPCODE_RMLD) begin
              state_next = cfg ? CFG : MEM_RD1;
            end else begin
              state_next = INVALID;
            end
          end
        CFG:
          if(commit_valid) begin
            state_next = RETIRE;
          end
        MEM_RD1:
          if(xif_mem_result_if.mem_result_valid) begin
            state_next = MEM_RD2;
          end
        MEM_RD2:
          if(xif_mem_result_if.mem_result_valid) begin
            state_next = UPDATE;
          end
        UPDATE:
          if(commit_valid) begin
            state_next = opcode == OPCODE_RMLD ? RETIRE : MEM_WR1;
          end
        MEM_WR1:
          if(xif_mem_result_if.mem_result_valid) begin
            state_next = MEM_WR2;
          end
        MEM_WR2:
          if(xif_mem_result_if.mem_result_valid) begin
            state_next = STALL;
          end
        STALL:
          state_next = RETIRE;
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
      /* Control registers */
      ld_addr                                   <= '0;
      st_addr                                   <= '0;
      shadow_reg                                <= '0;
      data_load_reg                             <= '0;
      rbuf                                      <= '0;

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
      case(state_next)
        IDLE: begin
          xif_issue_if.issue_ready            <= '1;
          xif_mem_if.mem_valid                <= '0;
          xif_result_if.result_valid          <= '0;
        end
        CFG: begin
          // set issue ready low
          xif_issue_if.issue_ready            <= '0;
          xif_issue_if.issue_resp.dualwrite   <= '0;
          xif_issue_if.issue_resp.dualread    <= '0;
          xif_issue_if.issue_resp.loadstore   <= '0;
          xif_issue_if.issue_resp.ecswrite    <= '0;
          xif_issue_if.issue_resp.exc         <= '0;

          if(commit_valid) begin
            case(funct3)
              CDSRM: begin
                data_load_reg <= rs1;
              end
              CASRM: begin
                st_addr       <= rs1;
              end
              CALRM: begin
                ld_addr       <= rs2;
              end
              CASLRM: begin
                st_addr       <= rs1;
                ld_addr       <= rs2;
              end
            endcase
          end
        end
        MEM_RD1: begin
          // set issue ready low
          xif_issue_if.issue_ready            <= '0;
          xif_issue_if.issue_resp.dualwrite   <= '0;
          xif_issue_if.issue_resp.dualread    <= '0;
          xif_issue_if.issue_resp.loadstore   <= '1;
          xif_issue_if.issue_resp.ecswrite    <= '0;
          xif_issue_if.issue_resp.exc         <= '1;

          // request read from the CPU
          xif_mem_if.mem_valid                <= '1;
          xif_mem_if.mem_req.id               <= xif_issue_if.issue_req.id;
          xif_mem_if.mem_req.addr             <= ld_addr;
          xif_mem_if.mem_req.mode             <= '1;    // set to machine level for now
          xif_mem_if.mem_req.we               <= '0;
          xif_mem_if.mem_req.size             <= 3'h2;  // set to a word (32b)
          xif_mem_if.mem_req.be               <= '1;    // enable all bytes
          xif_mem_if.mem_req.attr[1]          <= '1;    // set as modifiable
          xif_mem_if.mem_req.attr[0]          <= '0;    // set as aligned
          xif_mem_if.mem_req.last             <= opcode == OPCODE_RMLD;    // declare the memory transaction to be last if its a read instruction
          xif_mem_if.mem_req.spec             <= '0;    // memory transaction is not speculative

          xif_issue_if.issue_resp.loadstore   <= '1;
          xif_issue_if.issue_resp.exc         <= '1; //! can cause an exception for
                                                      //  an incorrect mem address
        end
        MEM_RD2: begin
          if(xif_mem_result_if.mem_result_valid) begin
            rbuf                              <= xif_mem_result_if.mem_result.rdata;
            xif_mem_if.mem_req.addr           <= xif_mem_if.mem_req.addr + 3'b100;
          end
        end
        UPDATE: begin
          if(xif_mem_result_if.mem_result_valid) begin
            //TODO: determine how much to shift rbuf when loading it into shadow register
            shadow_reg                        <= {{xif_mem_result_if.mem_result.rdata[15:0]}, {rbuf}};
          end
          xif_mem_if.mem_valid                <= '0;

        end
        MEM_WR1: begin
          xif_mem_if.mem_valid                <= '1;
          xif_mem_if.mem_req.addr             <= st_addr;
          xif_mem_if.mem_req.we               <= '1;
          xif_mem_if.mem_req.size             <= 3'h2;  // set to a word (32b)
          xif_mem_if.mem_req.attr[0]          <= '0;    // set as aligned
          xif_mem_if.mem_req.last             <= '0;    // declare the memory transaction to not be the last
          xif_mem_if.mem_req.spec             <= '0;    // memory trasnaction is not speculative
          case(funct3)
            RMCS:
              //TODO: update this value
              xif_mem_if.mem_req.wdata        <= {{16'b0}, {shadow_reg[31:16]}};
            RMCC:
              xif_mem_if.mem_req.wdata        <= data_load_reg;
            RMXR:
              //TODO: update this value
              xif_mem_if.mem_req.wdata        <= '0;
            RMXS:
              //TODO: update this value
              xif_mem_if.mem_req.wdata        <= '1;
          endcase
        end
        MEM_WR2: begin
          if(xif_mem_result_if.mem_result_valid) begin
            xif_mem_if.mem_req.addr             <= st_addr + 3'b100;
            xif_mem_if.mem_req.last             <= '1;    // declare the memory transaction to be the last
          end
          case(funct3)
            RMCS:
              //TODO: update this value
              xif_mem_if.mem_req.wdata        <= {{shadow_reg[15:0]}, 16'b0};
            RMCC:
              xif_mem_if.mem_req.wdata        <= data_load_reg;
            RMXR:
              //TODO: update this value
              xif_mem_if.mem_req.wdata        <= '0;
            RMXS:
              //TODO: update this value
              xif_mem_if.mem_req.wdata        <= '1;
          endcase
        end
        STALL: begin
          xif_mem_if.mem_valid            <= '0;
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
            OPCODE_RMST: begin
              mem_rdata   <= xif_mem_result_if.mem_result.rdata;
              mem_dbg     <= xif_mem_result_if.mem_result.dbg;
              mem_err     <= xif_mem_result_if.mem_result.err;
            end
          endcase
        end
      endcase
      case(state_ff)
        IDLE: begin
          rs1 <= xif_issue_if.issue_req.rs[0];
          rs2 <= xif_issue_if.issue_req.rs[1];
          rd  <= xif_issue_if.issue_req.instr[11:7];
          id  <= xif_issue_if.issue_req.id;
        end
      endcase
    end
  end

endmodule
