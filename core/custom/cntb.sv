module cntb import custom_instr_pkg::*;
   (
    input logic         clk_i,
    input logic         rst_ni,
    input logic [31:0]  rd_i,
    input logic         start_i,
    input logic [31:0]  rs0_i,
    input logic [31:0]  rs1_i,
    output logic [31:0] rd_o,
    output logic        cntb_done_o
   );    

  
  logic [31:0] top_bits_set [7:0];
  
  logic [6:0] right_shift_DP, right_shift_DN;
  logic [31:0] result_cntb [7:0];
  //logic        cntb_done_SN, cntb_done_SP;
  

  enum         logic [1:0]  {INIT, EXEC, DONE} state_SN, state_SP;
  

  // signal done if done state is reached
  assign cntb_done_o = (state_SP==DONE) ? 1'b1 : 1'b0;

  genvar       geni;
  generate
    for (geni = 0; geni < 7; geni = geni + 1) begin
      count_bits #(.top_many_bits (geni)) cb
                (
                 .rs0_i (rs0_i),
                 .right_shift_i (right_shift_DP),
                 .top_bits_set_i (top_bits_set[geni]),
                 .result_o (result_cntb[geni])
                 );
    end
  endgenerate


  integer     i;  
  //datapath
  always_comb begin
    top_bits_set[0] = 32'hFF000000;
    right_shift_DN = right_shift_DP;
    rd_o = 0;
    state_SN = state_SP;
    
    for (i = 0; i < 7; i = i + 1) begin
      top_bits_set[i + 1] = top_bits_set[0] << (i + 1);
    end

    case (state_SP)
      INIT: begin
        if (start_i) begin
          right_shift_DN = 31 - rs1_i;         

          state_SN = EXEC;
        end
      end
      

      EXEC: begin
        state_SN = DONE;
        if (rs0_i[rs1_i] == 1'b1) begin
          // count consecutive 1 bits
          if (result_cntb[0] == top_bits_set[0]>>right_shift_DP && (right_shift_DP < 25)) begin
            rd_o = 32'd8;
            right_shift_DN = right_shift_DP + 8;
            if (rs0_i[31-(rd_i+8)] == 1'b1) begin
              state_SN = EXEC;
            end else begin
              state_SN = DONE;
            end 
          end
          else if (result_cntb[1] == top_bits_set[1]>>right_shift_DP  && (right_shift_DP < 26))
            rd_o = 32'd7;
          else if (result_cntb[2] == top_bits_set[2]>>right_shift_DP  && (right_shift_DP < 27))
            rd_o = 32'd6;
          else if (result_cntb[3] == top_bits_set[3]>>right_shift_DP  && (right_shift_DP < 28))
            rd_o = 32'd5;
          else if (result_cntb[4] == top_bits_set[4]>>right_shift_DP  && (right_shift_DP < 29))
            rd_o = 32'd4;
          else if (result_cntb[5] == top_bits_set[5]>>right_shift_DP  && (right_shift_DP < 30))
            rd_o = 32'd3;
          else if (result_cntb[6] == top_bits_set[6]>>right_shift_DP  && (right_shift_DP < 31))
            rd_o = 32'd2;
          else if (right_shift_DP < 32)
            rd_o = 32'd1;    
          else    
            rd_o = 32'd0;
        end else if (rs0_i[rs1_i] == 1'b0) begin // if (rs0_i[rs1_i] == 1'b1)
          // count consecutive 0 bits
          if (result_cntb[0] == 32'd0 && (right_shift_DP < 25)) begin
            rd_o = 32'd8;
            right_shift_DN = right_shift_DP + 8;
            if (rs0_i[31-(rd_i+8)] == 1'b0) begin // check if problem cuz changed
              state_SN = EXEC;
            end else begin
              state_SN = DONE;
            end
          end
          else if (result_cntb[1] == 32'd0  && (right_shift_DP < 26))
            rd_o = 32'd7;
          else if (result_cntb[2] == 32'd0  && (right_shift_DP < 27))
            rd_o = 32'd6;
          else if (result_cntb[3] == 32'd0  && (right_shift_DP < 28))
            rd_o = 32'd5;
          else if (result_cntb[4] == 32'd0  && (right_shift_DP < 29))
            rd_o = 32'd4;
          else if (result_cntb[5] == 32'd0 && (right_shift_DP < 30))
            rd_o = 32'd3;
          else if (result_cntb[6] == 32'd0 && (right_shift_DP < 31))
            rd_o = 32'd2;
          else if (right_shift_DP < 32)
            rd_o = 32'd1; 
          else
            rd_o = 32'd0; 
        end // if (rs0_i[rs1_i] == 1'b0)
        
      end // case: EXEC

      DONE: begin
        state_SN = INIT;
      end
      
    endcase
      
  end // always_comb

  //state sequential logic
  always_ff @(posedge clk_i, negedge rst_ni) begin
     if (!rst_ni) begin
      state_SP <= INIT;
    end else begin
      state_SP <= state_SN;
    end
  end
  

   always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin   
      right_shift_DP <= 0;
    end else begin
      right_shift_DP <= right_shift_DN;
    end
  end

endmodule
