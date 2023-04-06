import cv32e40x_pkg::*;

module coproc import custom_instr_pkg::*;
  (
   input clk_i,
   input rst_ni,
   if_xif.coproc_compressed xif_compressed,
   if_xif.coproc_issue xif_issue,
   if_xif.coproc_commit xif_commit,
   if_xif.coproc_mem xif_mem,
   if_xif.coproc_mem_result xif_mem_result,
   if_xif.coproc_result xif_result
   );

  enum   logic [2:0] {INIT, CNTB, WBITS, MEMORY, WRITEBACK,
                      READ_MEM, WRITE_MEM, WAIT_MEM_RESP} state_SN, state_SP;
  
  logic [31:0] rd_cntb_i, rd_wbits_i;

  logic        ld_op_SN, ld_op_SP;

  logic [31:0] rs0_DP, rs0_DN;
  logic [31:0] rs1_DP, rs1_DN;

  logic issue_ready_SP, issue_ready_SN;
  logic [31:0]          rd_DP, rd_DN;
  logic [4:0]           rd_addr_DP, rd_addr_DN;
 
  logic                 writeback_SP, writeback_SN;
  logic                 accept_SP, accept_SN;
  logic                 result_valid_SP, result_valid_SN;
 


  logic                 cntb_done_i, wbits_done_i;
  logic                 cntb_start_o, wbits_start_o;

  logic [3:0]           instr_id_DP, instr_id_DN;

  // r0 register is incresed by samples to read next signal bits
  logic [31:0]          inc_addr_i;
  
  

  assign xif_compressed.compressed_ready = 1'b0;
  assign xif_compressed.compressed_resp.accept = 1'b0;
  assign xif_compressed.compressed_resp.instr = 1'b0;

  assign xif_issue.issue_ready = issue_ready_SP;
  assign xif_issue.issue_resp.accept = accept_SP; //ready 1 and accept 0 to reject all offloaded in
  assign xif_issue.issue_resp.writeback = writeback_SP;
  assign xif_issue.issue_resp.dualwrite = 1'b0;
  assign xif_issue.issue_resp.dualread = 1'b0;
  assign xif_issue.issue_resp.loadstore = ld_op_SP;
  assign xif_issue.issue_resp.ecswrite = 1'b0;
  assign xif_issue.issue_resp.exc = 1'b0;

  assign xif_mem.mem_req.id = instr_id_DP;
  assign xif_mem.mem_req.addr = rs0_DP;
  assign xif_mem.mem_req.mode = 0;
  assign xif_mem.mem_req.we = 0;
  assign xif_mem.mem_req.be = 0;
  assign xif_mem.mem_req.wdata = 0;
  assign xif_mem.mem_req.spec = 0;

  assign xif_result.result.id = 0;
  assign xif_result.result.data = rd_DP;
  assign xif_result.result.rd = rd_addr_DP;
  assign xif_result.result.we = 0;
  assign xif_result.result.ecsdata = 0;
  assign xif_result.result.ecswe = 0;
  assign xif_result.result.exc = 0;
  assign xif_result.result.exccode = 0;

  assign xif_result.result_valid = result_valid_SP;
  
  // hardware for cntb instruction
  cntb cntb_i
    (
     .clk_i (clk_i),
     .rst_ni (rst_ni),
     .rd_o (rd_cntb_i),
     .rs0_i (rs0_DP),
     .rs1_i (rs1_DP),
     .rd_i (rd_DP),
     .start_i (cntb_start_o),
     .cntb_done_o (cntb_done_i)
     );

  // interface to memory intercation fsm
  if_rmem if_rmem_i(); 
  // hardware for stroing bits unaligned after decoding
  wbits wbits_i
    ( .clk_i (clk_i),
      .rst_ni (rst_ni),
      .start_i (wbits_start_o),
      .read_if (if_rmem_i),
      .address_i (rs0_DP),
      .inc_addr_o (inc_addr_i),
      .offset (rs1_DP),
      .rd_o (rd_wbits_i),
      .rd_i (rd_DP),
      .done_o (wbits_done_i)
     );

 
  read_mem read_mem_i ( .clk_i (clk_i),
                        .rst_ni (rst_ni),
                        .read_if (if_rmem_i),
                        .mem_req_last (xif_mem.mem_req.last),
                        .mem_valid (xif_mem.mem_valid),
                        .mem_result_valid (xif_mem_result.mem_result_valid),
                        .mem_result_rdata (xif_mem_result.mem_result.rdata)
                        );
  
  
  
  // next_state logic
  always_comb begin
    state_SN = state_SP;
    result_valid_SN = result_valid_SP;

    rs0_DN = rs0_DP;
    rs1_DN = rs1_DP;

    issue_ready_SN = issue_ready_SP;
    rd_DN = rd_DP;
    rd_addr_DN = rd_addr_DP;

    writeback_SN = writeback_SP;
    accept_SN = accept_SP;
    ld_op_SN = ld_op_SP;
    
    rd_DN = rd_DP;

    instr_id_DN = instr_id_DP;

    cntb_start_o = 1'b0;
    wbits_start_o = 1'b0;
    
    
    unique case (state_SP)
      INIT: begin
        rd_DN = 32'd0;
        result_valid_SN = 1'b0;
        if (xif_issue.issue_valid) begin
          rs0_DN = xif_issue.issue_req.rs[0] ;
          rs1_DN = xif_issue.issue_req.rs[1];
          rd_addr_DN = xif_issue.issue_req.instr[11:7];
          issue_ready_SN = 1'b1;
          instr_id_DN = xif_issue.issue_req.id;
          
          case (xif_issue.issue_req.instr[6:0])
            
            OPCODE_CNTB: begin
              state_SN = CNTB;
              ld_op_SN = 1'b0;
              accept_SN = 1'b1;
              writeback_SN = 1'b1; 
            end

            OPCODE_WBITS: begin
              state_SN = WBITS;
              ld_op_SN = 1'b1;
              accept_SN = 1'b1;
              writeback_SN = 1'b1;
            end
          endcase // case (xif_issue.issue_req.instr[6:0])
          
        end// if (xif_issue.issue_valid) 
      end // case: INIT
          
      CNTB: begin
        issue_ready_SN = 1'b0;
        cntb_start_o = 1'b1;
        rd_DN = rd_DP + rd_cntb_i;
        if (cntb_done_i)//exec stage is done
          state_SN = WRITEBACK;
      end
      

      WBITS: begin
        issue_ready_SN = 1'b0;
        wbits_start_o = 1'b1;
        rd_DN = rd_DP | rd_wbits_i;
        rs0_DN = rs0_DP + inc_addr_i; // to increase address by signals to read next signal
        if (wbits_done_i) begin
          state_SN = WRITEBACK;
        end
      end

      WRITEBACK: begin
        result_valid_SN = 1'b1;
        if (xif_result.result_ready)
          state_SN = INIT;
      end
    endcase
      
  end // always_comb
  
  //Datapath
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      state_SP <= INIT;
      ld_op_SP <= 0;
      rs0_DP <= 0;
      rs1_DP <= 0;
      
      issue_ready_SP <= 0;
      rd_DP <= 0;
      rd_addr_DP <= 0;
      writeback_SP <= 0;
      accept_SP <= 0;
      rd_DP <= 0;
      result_valid_SP <= 1'b0;
    end else begin
      state_SP <= state_SN;
      ld_op_SP <= ld_op_SN;
      rs0_DP <= rs0_DN;
      rs1_DP <= rs1_DN;
      
      rd_DP <= rd_DN;
      issue_ready_SP <= issue_ready_SN;
      rd_addr_DP <= rd_addr_DN;
      writeback_SP <= writeback_SN;
      accept_SP <= accept_SN;
      
      rd_DP <= rd_DN;
      result_valid_SP <= result_valid_SN;
    end
  end // always_ff @ (posedge clk_i, negedge rst_ni)

  // sequential logic for read write memory
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      instr_id_DP <= 1'b0;
    end else begin
      instr_id_DP <= instr_id_DN;
    end
      
  end

  
endmodule
