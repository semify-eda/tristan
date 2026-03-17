module rshifter32
(
  input   wire  [31:0]  d,              // I: input data
  input   wire  [ 4:0]  shift_amount,   // I: value from 0-31 to shift right
  input   wire          rotate_en,      // I: enable circular rotation
  output  wire  [31:0]  q               // O: output value
);

  // Rotate-right idiom: {d,d} is a 64-bit mirror of d.
  // Extracting 32 bits starting at bit `shift_amount` gives the rotated result.
  // Named wire required: part-selects on parenthesized expressions are not
  // supported by verilator; the indexed part-select must target a signal.
  // _shift6: zero-extend the 5-bit shift_amount to 6 bits so the index width
  // matches the 64-bit _dbl_d vector and avoids a WIDTHEXPAND warning.
  wire [63:0] _dbl_d  = {d, d};
  wire [ 5:0] _shift6 = {1'b0, shift_amount};
  assign q = (rotate_en == 1'b1) ?
              _dbl_d[_shift6 +: 32] :
              (d >> shift_amount);

  // Old: Verilator issued a warning as 5'32 actually truncates to 5'b00000
  // The above solution is the 'idiomatic double-concatenation trick', the standard textbook rotate-right
  // assign q = (rotate_en == 1'b1) ?
  //           ((d >> shift_amount) | (d << (5'd32 - shift_amount))) :
  //           (d >> shift_amount);
endmodule
