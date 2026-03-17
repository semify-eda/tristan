module rshifter32
(
  input   wire  [31:0]  d,              // I: input data
  input   wire  [ 4:0]  shift_amount,   // I: value from 0-31 to shift right
  input   wire          rotate_en,      // I: enable circular rotation
  output  wire  [31:0]  q               // O: output value
);

  assign q = (rotate_en == 1'b1) ?
              ({d, d} >> shift_amount)[31:0] :
              (d >> shift_amount);

  // Old: Verilator issued a warning as 5'32 actually truncates to 5'b00000
  // The above solution is the 'idiomatic double-concatenation trick', the standard textbook rotate-right
  // assign q = (rotate_en == 1'b1) ?
  //           ((d >> shift_amount) | (d << (5'd32 - shift_amount))) :
  //           (d >> shift_amount);
endmodule
