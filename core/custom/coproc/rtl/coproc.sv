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
  parameter int XLEN                     =  32,
  parameter int FLEN                     =  32
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

  // ! TODO: custom data stores -- rotations

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

  /* ====================== Control API Registers ====================== */
  logic [31:0]  bld_addr;           // base address of start of read (load) stream
  logic [31:0]  bst_addr;           // address of start of write (store) stream
  logic [31:0]  data_load_reg;      // custom data register
  logic [31:0]  shadow_reg;         // shadow data register
  logic [31:0]  shadow_reg_spec;    // shadow register holding speculative data

  /* ====================== Internal Control Registers ====================== */
  logic [31:0]  ld_addr;            // computed address of start of read (load) stream
  logic [31:0]  st_addr;            // computed address of start of write (store) stream
  logic [63:0]  rbuf;               // read data buffer
  logic [63:0]  wbuf;               // write data buffer
  logic [31:0]  wmask;              // mask to apply to shadow_reg on loads, and base mask on stores
  logic [31:0]  wmask_left;         // mask applied to wbuf[63:32]
  logic [31:0]  wmask_right;        // mask applied to wbuf[31: 0]
  logic [ 4:0]  bit_idx;            // bit index to start operation at
  logic [ 5:0]  count;              // number of bits to operate on
  logic [31:0]  count_unary;        // Used to generate mask

  /* ====================== Shifter Signals ====================== */
  logic [31:0]  shift_input;
  logic [ 4:0]  shift_amount;
  logic         rotate_en;
  logic [31:0]  shift_output;
  logic [31:0]  shift_output_rev;
  logic         capture_cnt_unary;
  logic         capture_rbuf31_0;
  logic         capture_rbuf63_32;
  logic         capture_shadow_reg;

  logic         capture_cnt_unary_ff;
  logic         capture_rbuf31_0_ff;
  logic         capture_rbuf63_32_ff;
  logic         capture_shadow_reg_ff;

  /* ====================== Alias Signals ====================== */
  logic         cfg;
  logic         op_load;
  logic         op_store;
  logic         op_valid;

  assign cfg        = funct3[2];
  assign op_load    = opcode == OPCODE_RMLD;
  assign op_store   = opcode == OPCODE_RMST;
  assign op_valid   = op_load | op_store;

  assign shift_output_rev = {<<{shift_output}};

  /**
  *   NOTES:
  *     - for now, do not pipeline the coprocessor. This means the input id, rs1, rs2, rd
  *       will always be the output id, rs1, rs2, rd
  */
  logic [31:0]    instr;
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

  assign opcode = coproc_opcode_e'(xif_issue_if.issue_valid ? xif_issue_if.issue_req.instr[6: 0] : instr[6: 0]);
  assign funct3 =  rmst_funct3_e'(xif_issue_if.issue_valid ? xif_issue_if.issue_req.instr[14:12] : instr[14:12]);


  assign bit_idx      = rs1[4:0];
  assign count        = (rs2[4:0] + 1);
  assign count_unary  = 2**(count) - 1;

  rshifter32 rshifter32i (
    .d            (shift_input  ),
    .shift_amount (shift_amount ),
    .rotate_en    (rotate_en    ),
    .q            (shift_output )
  );


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
  assign xif_issue_if.issue_resp.accept     = op_valid;
  assign xif_issue_if.issue_resp.writeback  = op_store;


  /* ================== Write Masks ====================== */
  assign wmask_right    = wmask_left ^ wmask;
  assign wmask_left[0]  = wmask[0];
  generate
    for (genvar i = 1; i < 32; ++i) begin
      assign wmask_left[i] = wmask[i] & wmask_left[i-1];
    end
  endgenerate

  logic [63:0] wmask_store;
  logic [63:0] wmask_store32;   // the store write mask in the edge case that 32 bits will be copied
  logic [63:0] reg_rot;         // the register to source data from rotated and concatenated to its self
  logic        _32b_copy;

  assign _32b_copy = count == 6'b10_0000;
  assign wmask_store32  = {<<{{wmask}, {~wmask}}};
  assign wmask_store    = _32b_copy ? wmask_store32 : {{wmask_left}, {wmask_right}};

  always_comb begin
    unique case(funct3)
      RMXR: begin
        reg_rot = '0;
      end
      RMXS: begin
        reg_rot = '1;
      end
      RMCS: begin
        reg_rot = {{shadow_reg}, {shadow_reg}};
      end
      RMCC: begin
        //!TODO rotate data_load_reg
        //! this is not working yet
        reg_rot = {{data_load_reg}, {data_load_reg}};
      end
      default: begin
        reg_rot = '0;
      end
    endcase
  end

  generate
    for (genvar j = 0; j < 64; ++j) begin
      always_comb begin
        wbuf[j] = wmask_store[j] ? reg_rot[j] : rbuf[j];
      end
    end
  endgenerate

  /* ================== Shifter Signals ====================== */
  always_comb begin
    shift_input  = '0;
    shift_amount = '0;
    rotate_en    = '0;
    unique case(state_ff)
      MEM_RD1: begin
        shift_input   = count_unary;
        shift_amount  = op_load ? (7'b100_0000 - (count + bit_idx)) : (6'b10_0000 - bit_idx);
        rotate_en     = ~op_load & ~_32b_copy;
      end
      MEM_RD2: begin
        shift_input   = op_load ? rbuf[31:0] : shadow_reg;
        shift_amount  = op_load ? bit_idx : (6'b10_0000 - bit_idx);
        rotate_en     = ~op_load;
      end
      UPDATE: begin
        shift_input   = rbuf[63:32];
        shift_amount  = bit_idx;
        rotate_en     = '1;
      end
      default: begin
        shift_input   = '0;
        shift_amount  = '0;
        rotate_en     = '0;
      end
    endcase
  end

  // capture the shifted write mask only on the first cycle of MEM_RD1
  assign capture_cnt_unary  = state_ff != MEM_RD1 & state_next == MEM_RD1;

  // capture the shifted rbuf[31:0] value only on the first cycle of MEM_RD2 on a load
  assign capture_rbuf31_0   = state_ff != MEM_RD2 & state_next == MEM_RD2 & op_load;

  // capture the shifted rbuf[63:32] value only on the first cycle of UPDATE on a load
  assign capture_rbuf63_32  = state_ff != UPDATE & state_next == UPDATE & op_load;

  // capture the shifted shadow register only on the first cycle of MEM_RD2 on a store
  assign capture_shadow_reg = state_ff != MEM_RD2 & state_next == MEM_RD2 & op_store;

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if(~rst_ni) begin
      capture_cnt_unary_ff  <= '0;
      capture_rbuf31_0_ff   <= '0;
      capture_rbuf63_32_ff  <= '0;
      capture_shadow_reg_ff <= '0;
    end else begin
      capture_cnt_unary_ff  <= capture_cnt_unary;
      capture_rbuf31_0_ff   <= capture_rbuf31_0;
      capture_rbuf63_32_ff  <= capture_rbuf63_32;
      capture_shadow_reg_ff <= capture_shadow_reg;
    end
  end

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
            if(op_valid) begin
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
            state_next = op_load ? RETIRE : MEM_WR1;
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


  always_ff @(posedge clk_i, negedge rst_ni) begin : control_state_actions
    if (~rst_ni) begin
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
          xif_mem_if.mem_req.id               <= xif_issue_if.issue_req.id; // TODO: replace this with just the flopped id
          xif_mem_if.mem_req.addr             <= op_load ? ld_addr : st_addr;
          xif_mem_if.mem_req.mode             <= '1;      // set to machine level for now
          xif_mem_if.mem_req.we               <= '0;
          xif_mem_if.mem_req.size             <= 3'h2;    // set to a word (32b)
          xif_mem_if.mem_req.be               <= '1;      // enable all bytes
          xif_mem_if.mem_req.attr[1]          <= '1;      // set as modifiable
          xif_mem_if.mem_req.attr[0]          <= '0;      // set as aligned
          xif_mem_if.mem_req.last             <= '0;
          xif_mem_if.mem_req.spec             <= '0;      // memory transaction is not speculative

          xif_issue_if.issue_resp.loadstore   <= '1;
          xif_issue_if.issue_resp.exc         <= '1;      //! can cause an exception for an incorrect mem address
        end
        MEM_RD2: begin
          if(xif_mem_result_if.mem_result_valid) begin
            xif_mem_if.mem_req.last           <= op_load; // declare the memory transaction to be last if its a read instruction
            xif_mem_if.mem_req.addr           <= (op_load ? ld_addr : st_addr) + 3'b100;
          end
        end
        UPDATE: begin
          xif_mem_if.mem_valid                <= '0;
        end
        MEM_WR1: begin
          xif_mem_if.mem_valid                <= '1;
          xif_mem_if.mem_req.addr             <= st_addr;
          xif_mem_if.mem_req.we               <= '1;
          xif_mem_if.mem_req.size             <= 3'h2;    // set to a word (32b)
          xif_mem_if.mem_req.attr[0]          <= '0;      // set as aligned
          xif_mem_if.mem_req.last             <= '0;      // declare the memory transaction to not be the last
          xif_mem_if.mem_req.spec             <= '0;      // memory trasnaction is not speculative
        end
        MEM_WR2: begin
          if(xif_mem_result_if.mem_result_valid) begin
            xif_mem_if.mem_req.addr           <= st_addr + 3'b100;
            xif_mem_if.mem_req.last           <= '1;      // declare the memory transaction to be the last
          end
        end
        STALL: begin
          xif_mem_if.mem_valid                <= '0;
        end
        RETIRE: begin
          xif_issue_if.issue_ready            <= '1;
          xif_result_if.result_valid          <= '1;
          xif_result_if.result.id             <= id;

          xif_result_if.result.data           <= '0;
          xif_result_if.result.rd             <= '0;
          xif_result_if.result.we             <= '0;
          xif_result_if.result.ecsdata        <= '0;
          xif_result_if.result.ecswe          <= '0;
          xif_result_if.result.exc            <= '0;
          xif_result_if.result.exccode        <= '0;
          xif_result_if.result.err            <= '0;
          xif_result_if.result.dbg            <= '0;
        end
      endcase
    end
  end : control_state_actions

  always_ff @(posedge clk_i, negedge rst_ni)
  begin : data_state_actions
    if(~rst_ni)
    begin
      bld_addr                  <= '0;
      bst_addr                  <= '0;
      ld_addr                   <= '0;
      st_addr                   <= '0;
      shadow_reg                <= '0;
      shadow_reg_spec           <= '0;
      data_load_reg             <= '0;
      rbuf                      <= '0;
      wmask                     <= '0;
      instr                     <= '0;
      rs1                       <= '0;
      rs2                       <= '0;
      rd                        <= '0;
      id                        <= '0;
      mem_rdata                 <= '0;
      mem_dbg                   <= '0;
      mem_err                   <= '0;
      xif_mem_if.mem_req.wdata  <= '0;
    end else begin
      case(state_next)
        CFG: begin
          if(commit_valid) begin
            case(funct3)
              CDSRM: begin
                data_load_reg <= rs1;
              end
              CASRM: begin
                bst_addr      <= rs1;
              end
              CALRM: begin
                bld_addr      <= rs2;
              end
              CASLRM: begin
                bst_addr      <= rs1;
                bld_addr      <= rs2;
              end
            endcase
          end
        end
        MEM_RD1: begin

        end
        MEM_RD2: begin
          if(xif_mem_result_if.mem_result_valid) begin
            rbuf[31:0]                        <= xif_mem_result_if.mem_result.rdata;
          end
        end
        UPDATE: begin
          if(xif_mem_result_if.mem_result_valid) begin
            rbuf[63:32]                       <= xif_mem_result_if.mem_result.rdata;
          end
        end
        MEM_WR1: begin
          xif_mem_if.mem_req.wdata            <= wbuf[31:0];
        end
        MEM_WR2: begin
          xif_mem_if.mem_req.wdata            <= wbuf[63:32];
        end
        STALL: begin
        end
        RETIRE: begin
          case(opcode)
            OPCODE_RMST: begin
              mem_rdata   <= xif_mem_result_if.mem_result.rdata;
              mem_dbg     <= xif_mem_result_if.mem_result.dbg;
              mem_err     <= xif_mem_result_if.mem_result.err;
            end
          endcase
        end
        INVALID: begin
        end
        KILL: begin
        end
      endcase
      case(state_ff)
        IDLE: begin
          if(xif_issue_if.issue_valid) begin
            id                <= xif_issue_if.issue_req.id;
            instr             <= xif_issue_if.issue_req.instr;
            if(xif_issue_if.issue_req.rs_valid) begin
              rs1               <= xif_issue_if.issue_req.rs[0];
              rs2               <= xif_issue_if.issue_req.rs[1];
              rd                <= xif_issue_if.issue_req.instr[11:7];

              // dynamically calculate the load and store addresses from the base and bit offset
              ld_addr           <= bld_addr + xif_issue_if.issue_req.rs[0][31:5];
              st_addr           <= bst_addr + xif_issue_if.issue_req.rs[0][31:5];
            end
          end else if (~xif_issue_if.issue_valid & state_next == IDLE) begin
            //TODO: remove this block
            instr           <= '0;
          end
        end
        MEM_RD1: begin
          if(capture_cnt_unary_ff) begin
            wmask           <= op_load ? shift_output_rev : shift_output;
          end
        end
        MEM_RD2: begin
          // shadow reg should only be updated if the instruction was commited, and if the opcode is load. do not update shadow reg on a store.
          if(capture_rbuf31_0_ff) begin
            shadow_reg_spec <= shift_output; // shift_output = shifted( rbuf[31:0] )
          end
          if(capture_shadow_reg_ff) begin
            shadow_reg_spec <= shift_output; // shifted_output = op_load ? shifted( shadow_register ) : rotated( shadow_register )
          end
        end
        UPDATE: begin
          if(capture_rbuf63_32_ff) begin
            shadow_reg_spec <= shadow_reg_spec | (shift_output & wmask); // shifted_output = rotated( rbuf[63:32] )
          end
          if(commit_valid) begin
            if(capture_rbuf63_32_ff) begin
              shadow_reg    <= shadow_reg_spec | (shift_output & wmask);
            end else begin
              shadow_reg    <= shadow_reg_spec;
            end
          end
        end
      endcase
    end
  end : data_state_actions

endmodule
