
module cv32e40x_clock_gate
#(
  parameter LIB = 0
) (
  input  logic clk_i,
  input  logic en_i,
  input  logic scan_cg_en_i,
  output logic clk_o
);

  BUFR u_clkout_buf (
    .O   (clk_o),
    .I   (clk_i),
    .CLR (1'b0),
    .CE  (en_i | scan_cg_en_i)
  );

endmodule // cv32e40x_clock_gate
