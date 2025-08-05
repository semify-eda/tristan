
module cv32e40x_clock_gate
#(
  parameter LIB = 0
) (
  input  wire clk_i,
  input  wire en_i,
  input  wire scan_cg_en_i,
  output logic clk_o
);

  BUFR u_clkout_buf (
    .O   (clk_o),
    .I   (clk_i),
    .CLR (1'b0),
    .CE  (en_i | scan_cg_en_i)
  );

endmodule // cv32e40x_clock_gate
