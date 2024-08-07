package coproc_pkg;

/**
*   Reference table:
*   https://five-embeddev.com/riscv-user-isa-manual/Priv-v1.12/opcode-map.html#opcodemap
*/
typedef enum logic [6:0] {
  OPCODE_RMLD   = 7'h0b,
  OPCODE_RMST   = 7'h1b,
  OPCODE_TEST   = 7'h6b
} coproc_opcode_e;

endpackage