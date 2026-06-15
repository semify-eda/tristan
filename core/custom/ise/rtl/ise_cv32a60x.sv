`default_nettype none
module ise_cv32a60x import ise_pkg::*;
#(
  // CVXIF struct types — passed as type parameters from the SoC wrapper.
  // All XIF capability parameters (X_NUM_RS, X_ID_WIDTH, X_MEM_WIDTH, XLEN, etc.) that
  // existed in the CV32E40X version are removed: their widths are now encoded in these structs.
  parameter type cvxif_req_t  = logic,
  parameter type cvxif_resp_t = logic
)
(
  input wire clk_i,
  input wire rst_ni,

  /* ====================== CVXIF ====================== */
  input  cvxif_req_t    cvxif_req_i,
  output cvxif_resp_t   cvxif_resp_o,

  /* ========== Sideband OBI to DRAM port B ============ */
  output logic          obi_ise_req,
  input  wire           obi_ise_gnt,
  output logic          obi_ise_we,
  output logic [31:0]   obi_ise_addr,
  output logic [31:0]   obi_ise_wdata,
  input  wire           obi_ise_rvalid,
  input  wire  [31:0]   obi_ise_rdata

// For reference, here is the translation from the old cv32e40x CVXIF:
// cv32e40x_if_xif.coproc_compressed   xif_compressed_if,
// cv32e40x_if_xif.coproc_issue        xif_issue_if,
// cv32e40x_if_xif.coproc_commit       xif_commit_if,
// cv32e40x_if_xif.coproc_mem          // NO equivalent in CVA6 CVXIF, moved to OBI sideband
// cv32e40x_if_xif.coproc_mem_result   // NO equivalent in CVA6 CVXIF, moved to OBI sideband
// cv32e40x_if_xif.coproc_result       xif_result_if
//
// xif_compressed_if.compressed_ready         -> cvxif_resp_o.compressed_ready
// xif_compressed_if.compressed_resp.instr    -> cvxif_resp_o.compressed_resp.instr
// xif_compressed_if.compressed_resp.accept   -> cvxif_resp_o.compressed_resp.accept
// xif_issue_if.issue_valid                   -> cvxif_req_i.issue_valid
// xif_issue_if.issue_req.instr               -> cvxif_req_i.issue_req.instr
// xif_issue_if.issue_req.id                  -> cvxif_req_i.issue_req.id
// xif_issue_if.issue_req.rs[0]               -> cvxif_req_i.register.rs[0]   // NOTE: register channel, NOT issue_req
// xif_issue_if.issue_req.rs_valid            -> cvxif_req_i.register.rs_valid // NOTE: register channel, NOT issue_req
// xif_issue_if.issue_ready                   -> cvxif_resp_o.issue_ready
// xif_issue_if.issue_resp.accept             -> cvxif_resp_o.issue_resp.accept
// xif_issue_if.issue_resp.writeback          -> cvxif_resp_o.issue_resp.writeback
// xif_issue_if.issue_resp.loadstore          -> REMOVED (no memory channel in CVA6 CVXIF)
// xif_issue_if.issue_resp.dualwrite          -> REMOVED (not in x_issue_resp_t)
// xif_issue_if.issue_resp.dualread           -> REMOVED (replaced by issue_resp.register_read)
// xif_issue_if.issue_resp.ecswrite           -> REMOVED (not in x_issue_resp_t)
// xif_issue_if.issue_resp.exc                -> REMOVED (not in x_issue_resp_t)
// xif_commit_if.commit_valid                 -> cvxif_req_i.commit_valid
// xif_commit_if.commit.commit_kill           -> cvxif_req_i.commit.commit_kill
// xif_result_if.result_valid                 -> cvxif_resp_o.result_valid
// xif_result_if.result_ready                 -> cvxif_req_i.result_ready
// xif_result_if.result.id                    -> cvxif_resp_o.result.id
// xif_result_if.result.rd                    -> cvxif_resp_o.result.rd
// xif_result_if.result.data                  -> cvxif_resp_o.result.data
// xif_result_if.result.we                    -> cvxif_resp_o.result.we
// xif_result_if.result.exc/exccode/err/dbg   -> REMOVED (not in x_result_t)
// xif_result_if.result.ecsdata/ecswe         -> REMOVED (not in x_result_t)
// xif_mem_if.* / xif_mem_result_if.*         -> obi_ise_req/gnt/we/addr/wdata/rvalid/rdata (OBI sideband)
);

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
  logic         capture_cnt_unary;
  logic         capture_rbuf31_0;
  logic         capture_rbuf63_32;
  logic         capture_shadow_reg;

  logic         capture_cnt_unary_ff;
  logic         capture_rbuf31_0_ff;
  logic         capture_rbuf63_32_ff;
  logic         capture_shadow_reg_ff;

  /* ====================== Alias Signals ====================== */
  // Declare opcode/funct3 here so they are in scope for the assigns below.
  // (Vivado requires declaration before first use; Verilator allows forward refs.)
  ise_opcode_e    opcode;
  rmst_funct3_e   funct3;

  logic         cfg;
  logic         op_load;
  logic         op_store;
  logic         op_valid;

  assign cfg        = funct3[2];
  assign op_load    = opcode == OPCODE_RMLD;
  assign op_store   = opcode == OPCODE_RMST;
  assign op_valid   = op_load | op_store;

  /**
  *   NOTES:
  *     - for now, do not pipeline the Instruction Set Extension. This means the input id, rs1, rs2, rd
  *       will always be the output id, rs1, rs2, rd
  */
  logic [31:0]    instr;
  logic [31:0]    rs1, rs2;
  logic [4:0]     rd; //! this doesnt work on the xif, problem with CV32E40X
  logic [ 3:0]    id;
  logic           issue_valid_ff;
  logic           register_valid_ff;  // sticky: register values have been captured
  logic           commit_valid,     commit_valid_ff;

  /* ====================== Memory Signals ====================== */
  logic [31:0]    mem_rdata;

  /* ====================== OBI Safety Guard ====================== */
  // OBI protocol: rvalid must always follow a prior gnt.  In this design
  // the arbiter's arb_busy flag prevents a second transaction from being
  // accepted between gnt and rvalid, so a spurious rvalid without a
  // preceding gnt cannot occur in practice.  gnt_received_ff makes that
  // invariant explicit and prevents the state machine from advancing on a
  // rvalid that was never preceded by a gnt (e.g. during reset glitches or
  // future arbiter changes).
  //
  // obi_ise_rvalid_guarded is used everywhere in the state machine
  // instead of the raw obi_ise_rvalid.  The extra term (|| obi_ise_gnt)
  // handles zero-wait-state targets where gnt and rvalid can arrive on the
  // same cycle, before gnt_received_ff has a chance to register.
  logic           gnt_received_ff;

  always_ff @(posedge clk_i, negedge rst_ni) begin : obi_gnt_tracker
    if (~rst_ni) begin
      gnt_received_ff <= '0;
    end else begin
      if (obi_ise_gnt) begin
        gnt_received_ff <= '1;
      end else if (obi_ise_rvalid) begin
        gnt_received_ff <= '0;
      end
    end
  end : obi_gnt_tracker

  wire obi_ise_rvalid_guarded = obi_ise_rvalid && (gnt_received_ff || obi_ise_gnt);


  /* ============== Submodule & Type Instatiations =============== */
  // FSM
  ise_state_e state_ff, next_state_ff;

  assign opcode = ise_opcode_e'(cvxif_req_i.issue_valid ? cvxif_req_i.issue_req.instr[6: 0] : instr[6: 0]);
  assign funct3 =  rmst_funct3_e'(cvxif_req_i.issue_valid ? cvxif_req_i.issue_req.instr[14:12] : instr[14:12]);

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
  assign commit_valid     = commit_valid_ff     | cvxif_req_i.commit_valid;
  always_ff @(posedge clk_i, negedge rst_ni) begin : commit_monitor
    if(~rst_ni) begin
      commit_valid_ff     <= '0;
      issue_valid_ff      <= '0;
      register_valid_ff   <= '0;
    end else begin
      if(cvxif_req_i.commit_valid) begin
        commit_valid_ff     <= '1;
      end else if(cvxif_resp_o.result_valid) begin
        commit_valid_ff     <= '0;
      end
      // Only latch when the instruction is accepted (op_valid=accept=1).
      // A non-accepted dispatch (spurious or non-custom opcode) must not
      // leave issue_valid_ff stuck high — result_valid is never asserted
      // for rejected instructions, so the sticky bit would never clear.
      if(cvxif_req_i.issue_valid && op_valid) begin
        issue_valid_ff      <= '1;
      end else if(cvxif_resp_o.result_valid ||
                  (cvxif_req_i.issue_valid && !op_valid)) begin
        issue_valid_ff      <= '0;
      end
      // Sticky flag: register values have been received on the register channel.
      // CVA6 CVXIF sends register_valid potentially one or more cycles after
      // issue_valid (unlike CV32E40X where rs arrive with issue_req).
      // We must not enter MEM_RD1 before ld_addr/st_addr are updated.
      if(cvxif_req_i.register_valid && &cvxif_req_i.register.rs_valid) begin
        register_valid_ff   <= '1;
      end else if(cvxif_resp_o.result_valid ||
                  (cvxif_req_i.issue_valid && !op_valid)) begin
        register_valid_ff   <= '0;
      end
    end
  end : commit_monitor

  /* ================== Combinational Handshake Signals ====================== */
  // Compressed channel: always ready, never accept (not used)
  assign cvxif_resp_o.compressed_ready       = 1'b1;
  assign cvxif_resp_o.compressed_resp.instr  = '0;
  assign cvxif_resp_o.compressed_resp.accept = 1'b0;

  assign cvxif_resp_o.issue_resp.accept        = op_valid;
  assign cvxif_resp_o.issue_resp.writeback     = op_load;  // only RMLD (R-type) writes to rd
  assign cvxif_resp_o.issue_resp.register_read = '1;   // always request both source registers
  assign cvxif_resp_o.register_ready           = '1;   // always ready to accept register values


  /* ================== Write Masks ====================== */
  assign wmask_right    = wmask_left ^ wmask;
  assign wmask_left[0]  = wmask[0];
  generate
    for (genvar i = 1; i < 32; ++i) begin
      assign wmask_left[i] = wmask[i] & wmask_left[i-1];
    end
  endgenerate

  logic        mirror_en;
  logic        addr_overflow;
  logic [63:0] wmask_store;
  logic [63:0] reg_rot;         // the register to source data from rotated and concatenated to its self
  logic        _32b_copy;

  assign _32b_copy              = count == 6'b10_0000;
  assign mirror_en              = bit_idx == '0;
  assign addr_overflow          = |shift_output;

  // Mask of the low result bits sourced from word0 (NOT word1): the low
  // (32 - bit_idx) bits.  Used to build the load word1-merge mask below.
  // Computed in 64-bit width so the (1 << 32) case for bit_idx==0 does not
  // truncate to 0 (which is the whole point — it must become all-ones there).
  logic [31:0] word1_lowmask;
  assign word1_lowmask          = (64'd1 << (6'd32 - {1'b0, bit_idx})) - 64'd1;

  always_comb begin
    wmask_store = {{wmask_left}, {wmask_right}};
    if(mirror_en) begin
      wmask_store = {{wmask_right}, {wmask_left}};
    end
    if(_32b_copy) begin
      wmask_store = {{wmask}, {~wmask}};
      if(mirror_en) begin
        wmask_store = {<<{{wmask}, {~wmask}}};
      end
    end
  end

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
        // NOT YET IMPLEMENTED: rotation of data_load_reg is unfinished.
        // Treat as identity (no rotation) until the rotate logic is completed and tested.
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
        shift_amount  = op_load ? (7'b100_0000 - bit_idx) : (6'b10_0000 - bit_idx);
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
  assign capture_cnt_unary  = state_ff != MEM_RD1 & next_state_ff == MEM_RD1;
  // capture the shifted rbuf[31:0] value only on the first cycle of MEM_RD2 on a load
  assign capture_rbuf31_0   = state_ff != MEM_RD2 & next_state_ff == MEM_RD2 & op_load;
  // capture the shifted rbuf[63:32] value only on the first cycle of UPDATE on a load
  assign capture_rbuf63_32  = state_ff != UPDATE & next_state_ff == UPDATE & op_load;
  // capture the shifted shadow register only on the first cycle of MEM_RD2 on a store
  assign capture_shadow_reg = state_ff != MEM_RD2 & next_state_ff == MEM_RD2 & op_store;

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
  // Clocked State Logic
  always_ff @(posedge clk_i or negedge rst_ni) begin : clocked_state_logic
    if (!rst_ni) begin
      state_ff <= IDLE;
    end else begin
      state_ff <= next_state_ff;
    end
  end : clocked_state_logic

  // Combinatorial State Logic
  always_comb begin : next_state_logic
    next_state_ff = state_ff;
    if(cvxif_req_i.commit.commit_kill) begin
      next_state_ff = KILL;
    end else begin
      unique case(state_ff)
        IDLE:
          if(issue_valid_ff && register_valid_ff) begin
            if(op_valid) begin
              next_state_ff = cfg ? CFG : MEM_RD1;
            end else begin
              next_state_ff = INVALID;
            end
          end
        CFG:
          if(commit_valid) begin
            next_state_ff = RETIRE;
          end
        MEM_RD1:
          if(obi_ise_rvalid_guarded) begin    // advance only when read response is valid (rvalid), not at gnt
            next_state_ff = MEM_RD2;
          end
        MEM_RD2:
          if(obi_ise_rvalid_guarded) begin    // advance only when second read response is valid
            next_state_ff = UPDATE;
          end
        UPDATE:
          if(commit_valid) begin
            next_state_ff = op_load ? RETIRE : MEM_WR1;
          end
        MEM_WR1:
          if(obi_ise_rvalid_guarded) begin    // advance only when first write response is valid (rvalid), not at gnt
            next_state_ff = MEM_WR2;
          end
        MEM_WR2:
          if(obi_ise_rvalid_guarded) begin    // advance only when second write response is valid
            next_state_ff = STALL;
          end
        STALL:
          next_state_ff = RETIRE;
        RETIRE:
          if(cvxif_req_i.result_ready) begin
            next_state_ff = IDLE;
          end
        default:
          next_state_ff = IDLE;
      endcase
    end
  end : next_state_logic

  // Clocked output Logic
  always_ff @(posedge clk_i, negedge rst_ni) begin : control_state_actions
    if (~rst_ni) begin
      /* issue channel */
      cvxif_resp_o.issue_ready             <= '1;
      /* result channel */
      cvxif_resp_o.result_valid            <= '0;
      cvxif_resp_o.result.id               <= '0;
      cvxif_resp_o.result.rd               <= '0;
      cvxif_resp_o.result.hartid           <= '0;  // single hart, always 0
      // cvxif_resp_o.result.we and cvxif_resp_o.result.data driven in data_state_actions
      /* OBI sideband */
      obi_ise_req                               <= '0;
      obi_ise_we                                <= '0;
      obi_ise_addr                              <= '0;
    end else begin
      case(next_state_ff)
        IDLE: begin
          cvxif_resp_o.issue_ready         <= '1;
          obi_ise_req                   <= '0;
          cvxif_resp_o.result_valid        <= '0;
        end
        CFG: begin
          cvxif_resp_o.issue_ready         <= '0;
        end
        MEM_RD1: begin
          cvxif_resp_o.issue_ready         <= '0;
          // initiate first OBI read (word 0)
          obi_ise_req                           <= '1;
          obi_ise_we                            <= '0;
          obi_ise_addr                          <= op_load ? ld_addr : st_addr;
          // no byte enable needed on the OBI sideband anymore
        end
        MEM_RD2: begin
          // first read complete (rvalid) — issue second read (word 1, addr+4)
          if(obi_ise_rvalid_guarded) begin
            obi_ise_addr                        <= (op_load ? ld_addr : st_addr) + 32'd4;
          end
        end
        UPDATE: begin
          obi_ise_req                           <= '0;          // both reads issued; stop OBI
        end
        MEM_WR1: begin
          // initiate first OBI write (word 0)
          obi_ise_req                           <= '1;
          obi_ise_we                            <= '1;
          obi_ise_addr                          <= st_addr;
        end
        MEM_WR2: begin
          // first write complete (rvalid) — set up second write address (word 1, addr+4)
          if(obi_ise_rvalid_guarded) begin
            obi_ise_addr                        <= st_addr + 32'd4;
          end
        end
        STALL: begin
          obi_ise_req                           <= '0;          // both writes issued; stop OBI
        end
        RETIRE: begin
          // Do NOT set issue_ready here. CVA6 pipelines aggressively: asserting
          // issue_ready in RETIRE causes it to issue the next instruction while
          // state_ff is still RETIRE, which means the data_state_actions IDLE
          // captures (rs1/rs2/ld_addr/st_addr/id/instr) never fire for that
          // instruction. issue_ready is set in the IDLE case below.
          cvxif_resp_o.result_valid        <= '1;
          cvxif_resp_o.result.id           <= id;
          cvxif_resp_o.result.rd           <= rd;
          // result.we is owned by data_state_actions (set in UPDATE; cleared in IDLE)
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
      obi_ise_wdata          <= '0;
      cvxif_resp_o.result.data  <= '0;
      cvxif_resp_o.result.we    <= '0;
    end else begin
      case(next_state_ff)
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
          // No transition-action needed here:
          // the OBI request is already driven in the next_state_ff clocked block above.
        end
        MEM_RD2: begin
          // first read response valid (rvalid) — capture word 0 read data
          if(obi_ise_rvalid_guarded) begin
            rbuf[31:0]              <= obi_ise_rdata;
          end
        end
        UPDATE: begin
          // second read response valid (rvalid) — capture word 1 read data
          if(obi_ise_rvalid_guarded) begin
            rbuf[63:32]             <= obi_ise_rdata;
          end
        end
        MEM_WR1: begin
          obi_ise_wdata                  <= wbuf[31:0];
        end
        MEM_WR2: begin
          // first write complete (rvalid) — load second word into wdata register
          if(obi_ise_rvalid_guarded) begin
            obi_ise_wdata                <= wbuf[63:32];
          end
        end
        STALL: begin
        end
        RETIRE: begin
          // latch last OBI read-back diagnostics (store path only, not used)
          case(opcode)
            OPCODE_RMST: begin
              mem_rdata   <= obi_ise_rdata;
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
          cvxif_resp_o.result.we    <= '0;
          // NOTE: In CVA6 CVXIF, register values (rs1/rs2) arrive via the register channel
          //       (cvxif_req_i.register), NOT via issue_req. The register channel fires
          //       after issue_channel with register_valid asserted. id/instr captured on issue_valid;
          //       rs1/rs2 captured when register_valid fires.
          if(cvxif_req_i.issue_valid) begin
            id                <= cvxif_req_i.issue_req.id;
            instr             <= cvxif_req_i.issue_req.instr;
            rd                <= cvxif_req_i.issue_req.instr[11:7];
          end
          if(cvxif_req_i.register_valid) begin
            if(&cvxif_req_i.register.rs_valid) begin // all [1:0] bits must be 1 (reduction AND Operator)
              rs1               <= cvxif_req_i.register.rs[0];
              rs2               <= cvxif_req_i.register.rs[1];

              // dynamically calculate the load and store addresses from the base and bit offset
              ld_addr           <= bld_addr + {{cvxif_req_i.register.rs[0][31:5]}, 2'b00};
              st_addr           <= bst_addr + {{cvxif_req_i.register.rs[0][31:5]}, 2'b00};
            end
          end
        end
        MEM_RD1: begin
          if(capture_cnt_unary_ff) begin
            // For a LOAD, `wmask` selects the result bits taken from the UPPER
            // source word (word1) in the UPDATE merge below — result positions
            // [32-bit_idx, count-1], i.e. count_unary with its low (32-bit_idx)
            // bits cleared.  This is 0 unless the read actually spans the 32-bit
            // word boundary (bit_idx + count > 32).
            //
            // BUGFIX: the old `count_unary << shift_amount` was wrong — shift_amount
            // is only 5 bits, so the intended (64-bit_idx) shift was truncated mod 32
            // and never shifted the mask fully out for a non-spanning read, leaving
            // wmask = count_unary.  That OR-ed word1's low bits into the shadow
            // register, corrupting copy_segment decodes (the ISE ramp ±sample bug:
            // sample 14 = 0xDEBB instead of 0xC0A3).  Build the high-word mask
            // directly instead so it is exactly 0 when the read does not span.
            wmask           <= op_load ? (count_unary & ~word1_lowmask) : shift_output;
          end
        end
        MEM_RD2: begin
          // shadow reg should only be updated if the instruction was commited, and if the opcode is load. do not update shadow reg on a store.
          if(capture_rbuf31_0_ff) begin
            shadow_reg_spec <= shift_output;
          end
          if(capture_shadow_reg_ff) begin
            shadow_reg_spec <= shift_output;
          end
        end
        UPDATE: begin
          if(capture_rbuf63_32_ff) begin
            shadow_reg_spec <= shadow_reg_spec | (shift_output & wmask); // shifted_output = rotated( rbuf[63:32] )
          end
          if(commit_valid) begin
            if(capture_rbuf63_32_ff) begin
              shadow_reg                   <= shadow_reg_spec | (shift_output & wmask);
              cvxif_resp_o.result.data     <= op_load ? (shadow_reg_spec | (shift_output & wmask)) : '0;
              cvxif_resp_o.result.we       <= op_load;
            end else begin
              shadow_reg                   <= shadow_reg_spec;
              cvxif_resp_o.result.data     <= op_load ? shadow_reg_spec & wmask : '0;
              cvxif_resp_o.result.we       <= op_load;
            end
          end
        end
      endcase
    end
  end : data_state_actions

endmodule
`default_nettype wire
