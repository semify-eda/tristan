// Copyright (C) 2013-2018 ETH Zurich, University of Bologna
// Licensed under the Solderpad Hardware License, Version 0.51.
//
// Vivado-compatible replacement for
//   vendor/pulp-platform/common_cells/src/popcount.sv
//
// The upstream file uses recursive module instantiation (a module
// instantiating itself inside a generate block). Vivado 2023.2 cannot
// elaborate recursive instantiations and reports [filemgmt 20-644]
// "Circular Reference Found".
//
// This version is functionally identical but uses a for-loop inside
// always_comb instead of recursion. Vivado synthesises it to the same
// balanced adder tree.
//
// Used ONLY for Vivado synthesis (vivado_add_sources.tcl).
// Simulation continues to use the upstream recursive version via the
// .f file lists.

module popcount #(
    parameter int unsigned INPUT_WIDTH   = 256,
    localparam int unsigned PopcountWidth = $clog2(INPUT_WIDTH) + 1
) (
    input  logic [INPUT_WIDTH-1:0]    data_i,
    output logic [PopcountWidth-1:0]  popcount_o
);

  always_comb begin
    popcount_o = '0;
    for (int unsigned i = 0; i < INPUT_WIDTH; i++) begin
      popcount_o = popcount_o + PopcountWidth'(data_i[i]);
    end
  end

endmodule : popcount
