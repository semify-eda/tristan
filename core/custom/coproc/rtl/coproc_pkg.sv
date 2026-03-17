package coproc_pkg;

/**
*   Reference table:
*   https://five-embeddev.com/riscv-user-isa-manual/Priv-v1.12/opcode-map.html#opcodemap
*/

// Coprocessor OPCODES
typedef enum logic [6:0] {
  OPCODE_RMLD   = 7'h0b,
  OPCODE_RMST   = 7'h2b
} coproc_opcode_e;


// func3 field of RMST OPCODE
// RMLD has only OPCODE also called RMLD (3'b000)
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

  // onehot encoding of coprocessor states
  typedef enum {
    IDLE,
    CFG,
    MEM_RD1,
    MEM_RD2,
    UPDATE,
    MEM_WR1,
    MEM_WR2,
    STALL,
    RETIRE,
    INVALID,
    KILL
  } coproc_state_e;

endpackage
