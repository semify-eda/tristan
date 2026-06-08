`ifndef WFG_PKG
`define WFG_PKG

package wfg_pkg;
  // Wishbone-bus parameters used by wfg_timer.  The upstream wfg_pkg
  // also defines a wider WFG address map (stim_mem, drivers,
  // recorders, ...); those are omitted here since Tristan only
  // instantiates the timer.
  parameter int BUSW               = 32;
  parameter int BLOCK_SEL_ADDRW    = 3;
  parameter int MODULE_SEL_ADDRW   = 12;
  parameter int REGISTER_SEL_ADDRW = 8;
  parameter int ADDRW              = MODULE_SEL_ADDRW + REGISTER_SEL_ADDRW;
endpackage

`endif
