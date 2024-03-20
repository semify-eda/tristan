// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Wed Mar 20 14:13:53 2024
// Host        : Chris-Semify running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/git/tristan/risc_v_subsystem/risc_v_subsystem.gen/sources_1/ip/vio_reset_1/vio_reset_stub.v
// Design      : vio_reset
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a15tftg256-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "vio,Vivado 2023.2" *)
module vio_reset(clk, probe_out0)
/* synthesis syn_black_box black_box_pad_pin="probe_out0[0:0]" */
/* synthesis syn_force_seq_prim="clk" */;
  input clk /* synthesis syn_isclock = 1 */;
  output [0:0]probe_out0;
endmodule
