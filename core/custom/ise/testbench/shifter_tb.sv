
`timescale 1ns/1ps
module shifter_tb;


  logic [31:0]  d;              // I: input data
  logic [ 4:0]  shift_amount;   // I: value from 0-31 to shift right
  logic         rotate_en;      // I: enable circular rotation
  logic [31:0]  q;              // O: output value
    
  rshifter32 i_shifter
  (
    .d(d),
    .shift_amount(shift_amount),
    .rotate_en(rotate_en),
    .q(q)
  );


  // dump
  initial begin
    $dumpfile("shifter.vcd");
    $dumpvars();
  end

endmodule
