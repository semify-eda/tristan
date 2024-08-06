package coproc_pkg;

/**
*   Reference table:
*   https://five-embeddev.com/riscv-user-isa-manual/Priv-v1.12/opcode-map.html#opcodemap
*/
typedef enum logic [6:0] {
  OPCODE_RMLD   = 7'h08,
  OPCODE_RMST   = 7'h09,
  OPCODE_TEST   = 7'h0a
} coproc_opcode_e;

endpackage