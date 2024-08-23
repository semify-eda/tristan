package coproc_pkg;

/**
*   Reference table:
*   https://five-embeddev.com/riscv-user-isa-manual/Priv-v1.12/opcode-map.html#opcodemap
*/
typedef enum logic [6:0] {
  OPCODE_RMLD   = 7'h0b,
  OPCODE_RMST   = 7'h2b,
  OPCODE_TEST   = 7'h6b
} coproc_opcode_e;


typedef enum logic [2:0] {
  RMXR    = 3'b000,
  RMXS    = 3'b001,
  RMCS    = 3'b010,
  RMCC    = 3'b011,
  CDSRM   = 3'b100,
  CASRM   = 3'b101,
  CALRM   = 3'b110,
  CASLRM  = 3'b111
} rmst_funct3_e;

endpackage
