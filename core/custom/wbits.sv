module wbits import custom_instr_pkg::*;
  (
   input logic         clk_i,
   input logic         rst_ni,
   input logic         start_i,
   if_rmem.read_coproc read_if,
   input logic [31:0]  address_i, //rs0
   output logic [31:0] inc_addr_o,
   input logic [31:0]  offset, // rs1
   input logic [31:0]  rd_i,
   output logic [31:0] rd_o,
   output logic        done_o
   );



  enum                              logic [1:0] {INIT, READ, EXEC, DONE} state_SN, state_SP;

  logic                             start_read_SP, start_read_SN;

  logic [3:0][31:0]                 shift_4_sigs_o;
  logic [4:0]                       curr_signal_SP, curr_signal_SN; // stores which signal we currently read
  
  

  //assign read_if.addr = address_i;
  
  integer                           i;

  always_comb begin
    shift_4_sigs_o = 0; // default assignment
    
    for (i = 0; i < 8; i = i + 1) begin
      shift_4_sigs_o[0][(i*4)] = read_if.rdata[i];
      shift_4_sigs_o[1][(i*4)+1] = read_if.rdata[i];
      shift_4_sigs_o[2][(i*4)+2] = read_if.rdata[i];
      shift_4_sigs_o[3][(i*4)+3] = read_if.rdata[i];
    end
  end
                                                                                               
  always_comb begin
    state_SN = state_SP;
    start_read_SN = 1'b0;
    read_if.start = 1'b0;
    curr_signal_SN = curr_signal_SP;
    

    rd_o = 32'd0;
    done_o = 1'b0;
    inc_addr_o = 32'd0;
            
    case (state_SP)
      INIT: begin        
        if (start_i) begin
          state_SN = READ;
          start_read_SN = 1'b1;
          read_if.start = 1'b1;
        end
      end


      EXEC: begin
        // increase curr signal by one till all signals were fetched
        curr_signal_SN = curr_signal_SP + 1;
        rd_o = shift_4_sigs_o[curr_signal_SP];
        inc_addr_o = 32'd9;
        

        if (curr_signal_SP < 4-1) begin
          state_SN = READ;
           read_if.start = 1'b1;
        end
        else
          state_SN = DONE;
      end

      
      READ: begin
        if (read_if.done)
          state_SN = EXEC;
      end

      DONE: begin
        done_o = 1'b1;
        state_SN = INIT;
        curr_signal_SN = 5'd0;
      end
      
    endcase
  end // always_comb
  

  

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_SP <= INIT;
      start_read_SP <= 0;
      curr_signal_SP <= 0;
    end else begin
      state_SP <= state_SN;
      start_read_SP <= start_read_SN;
      curr_signal_SP <= curr_signal_SN;
    end
  end




endmodule
