module count_bits #(parameter top_many_bits = 4)
  ( 
    input logic [31:0] rs0_i,
    input logic [6:0]  right_shift_i,
    input logic [31:0] top_bits_set_i,
    output logic [31:0] result_o
    );
  
  always_comb begin
    result_o = (rs0_i & ((top_bits_set_i)>>right_shift_i));
  end

endmodule
                    
