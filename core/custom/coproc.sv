import cv32e40x_pkg::*;

`default_nettype none

module coproc
#(
    parameter logic [6:0] OPCODE_CNTB = 7'h6b
)
(
    input clk_i,
    input rst_ni,

    // eXtension interface
    cv32e40x_if_xif.coproc_compressed   xif_compressed_if,
    cv32e40x_if_xif.coproc_issue        xif_issue_if,
    cv32e40x_if_xif.coproc_commit       xif_commit_if,
    cv32e40x_if_xif.coproc_mem          xif_mem_if,
    cv32e40x_if_xif.coproc_mem_result   xif_mem_result_if,
    cv32e40x_if_xif.coproc_result       xif_result_if
);
    // Compressed instructions - not used
    assign xif_compressed_if.compressed_ready          = 1'b0;
    assign xif_compressed_if.compressed_resp.accept    = 1'b0;
    assign xif_compressed_if.compressed_resp.instr     = 1'b0;

    assign xif_issue_if.issue_ready            = issue_accept; // Always ready when accepted
    assign xif_issue_if.issue_resp.accept      = issue_accept;
    assign xif_issue_if.issue_resp.writeback   = 1'b1; // Always writeback
    assign xif_issue_if.issue_resp.dualwrite   = '0;
    assign xif_issue_if.issue_resp.dualread    = '0;
    assign xif_issue_if.issue_resp.loadstore   = '0;
    assign xif_issue_if.issue_resp.ecswrite    = '0;
    assign xif_issue_if.issue_resp.exc         = '0;

    // Memory requests - not used
    assign xif_mem_if.mem_valid        = 1'b0;
    assign xif_mem_if.mem_req.id       = '0;
    assign xif_mem_if.mem_req.addr     = '0;
    assign xif_mem_if.mem_req.mode     = '0;
    assign xif_mem_if.mem_req.we       = '0;
    assign xif_mem_if.mem_req.size     = '0;
    assign xif_mem_if.mem_req.be       = '0;
    assign xif_mem_if.mem_req.attr     = '0;
    assign xif_mem_if.mem_req.wdata    = '0;
    assign xif_mem_if.mem_req.last     = '0;
    assign xif_mem_if.mem_req.spec     = '0;

    assign xif_result_if.result_valid      = cntb_done;
    assign xif_result_if.result.id         = id;
    assign xif_result_if.result.data       = {27'b0, cntb_result};
    assign xif_result_if.result.rd         = rd;
    assign xif_result_if.result.we         = '0;
    assign xif_result_if.result.ecsdata    = '0;
    assign xif_result_if.result.ecswe      = '0;
    assign xif_result_if.result.exc        = '0;
    assign xif_result_if.result.exccode    = '0;
    assign xif_result_if.result.err        = '0;
    assign xif_result_if.result.dbg        = '0;

    logic cntb_start;
    logic cntb_done;

    logic [31:0] rs0, rs1, rd;
    logic [3:0] id;

    logic issue_accept;

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            rs0 <= '0;
            rs1 <= '0;
            rd  <= '0;
            id  <= '0;
            cntb_start <= 1'b0;
            issue_accept <= 1'b0;
        end else begin
            // Clear done flag
            if (xif_result_if.result_ready) cntb_start <= 1'b0;
            issue_accept <= 1'b0;
            if (xif_issue_if.issue_valid && xif_issue_if.issue_req.instr[6:0] == OPCODE_CNTB) begin
                issue_accept <= 1'b1;
            
                rs0 <= xif_issue_if.issue_req.rs[0];
                rs1 <= xif_issue_if.issue_req.rs[1];
                rd  <= xif_issue_if.issue_req.instr[11:7];
                id  <= xif_issue_if.issue_req.id;
                cntb_start <= 1'b1;
            end
        end
    end

    logic [4:0] cntb_result;

    cntb cntb_inst
    (
        .clk_i      (clk_i      ),
        .rst_ni     (rst_ni     ),
        .start_i    (cntb_start ),
        .word_i     (rs0        ),
        .index_i    (rs1[4:0]   ),
        .result_o   (cntb_result),
        .done_o     (cntb_done  )
    );
  
endmodule
