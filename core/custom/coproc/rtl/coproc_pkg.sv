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


// funct3 field of RMST opcode (0x2b).
// RMLD opcode (0x0b) ignores funct3; decoded separately as op_load.
// cfg = funct3[2]: values 4–7 are address-config (CFG) instructions.
typedef enum logic [2:0] {
  RMXR    = 3'b000,  // RLE extend zeros        (RMST opcode, cfg=0)
  RMXS    = 3'b001,  // RLE extend ones         (RMST opcode, cfg=0)
  RMCS    = 3'b010,  // copy stream             (RMST opcode, cfg=0)
  RMCC    = 3'b011,  // copy+rotate [untested]  (RMST opcode, cfg=0)
  CDSRM   = 3'b100,  // cfg: data+store addr    (RMST opcode, cfg=1)
  CASRM   = 3'b101,  // cfg: store addr only    (RMST opcode, cfg=1)
  CALRM   = 3'b110,  // cfg: load addr only     (RMST opcode, cfg=1)
  CASLRM  = 3'b111   // cfg: store+load addr    (RMST opcode, cfg=1)
} rmst_funct3_e;

  // Binary-sequential encoding (IDLE=0, CFG=1, MEM_RD1=2, …, KILL=10)
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
