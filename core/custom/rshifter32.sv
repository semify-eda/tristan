module rshifter32
(
  input   wire  [31:0]  d,              // I: input data
  input   wire  [ 4:0]  shift_amount,   // I: value from 0-31 to shift right
  input   wire          rotate_en,      // I: enable circular rotation
  output  logic [31:0]  q               // O: output value
);

always_comb begin
  if(rotate_en) begin
    //!TODO: this does not work in vivado
    // q = {d[shift_amount:0], d[31:shift_amount]};
    q = d >> shift_amount;
  end else begin
    q = d >> shift_amount;
  end
end

endmodule
