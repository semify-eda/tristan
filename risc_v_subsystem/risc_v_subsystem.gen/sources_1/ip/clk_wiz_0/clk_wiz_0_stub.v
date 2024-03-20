// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Wed Mar 20 14:15:20 2024
// Host        : Chris-Semify running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/git/tristan/risc_v_subsystem/risc_v_subsystem.gen/sources_1/ip/clk_wiz_0/clk_wiz_0_stub.v
// Design      : clk_wiz_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a15tftg256-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clk_wiz_0(clk_25MHz, reset, locked, osc_100MHz_i)
/* synthesis syn_black_box black_box_pad_pin="reset,locked,osc_100MHz_i" */
/* synthesis syn_force_seq_prim="clk_25MHz" */;
  output clk_25MHz /* synthesis syn_isclock = 1 */;
  input reset;
  output locked;
  input osc_100MHz_i;
endmodule
