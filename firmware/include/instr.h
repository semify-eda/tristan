#ifndef INSTR_H
#define INSTR_H

#include <stdint.h>

#define HARD_ACC 1

/* =========================================================================
 * Custom RISC-V Co-Processor Instruction Set
 *
 * Two custom opcodes are used:
 *   0x0b  (custom-0)  —  R-type instructions
 *   0x2b  (custom-1)  —  S-type instructions
 *
 * Instruction summary:
 *
 *  S-type  opcode=0x2b:
 *   func3   Mnemonic   Operands                  Description
 *   ------  ---------  ------------------------  ----------------------------
 *   0b000   RMXR       (bit_idx, num_bits)        Stream extend: write 0-bits
 *   0b001   RMXS       (bit_idx, num_bits)        Stream extend: write 1-bits
 *   0b010   RMCS       (bit_idx, num_bits)        Stream copy from shadow reg
 *   0b011   RMCC       (bit_idx, num_bits)        Stream copy from data reg
 *   0b100   CDSRM      (data)                     Configure data register
 *   0b101   CASRM      (store_addr)               Configure store address
 *   0b110   CALRM      (load_addr)                Configure load address
 *   0b111   CASLRM     (store_addr, load_addr)    Configure store + load addr
 *
 *  R-type  opcode=0x0b:
 *   func3   Mnemonic   Operands                  Description
 *   ------  ---------  ------------------------  ----------------------------
 *   0b000   RMLD       (bit_idx, num_bits, rd)    Load from memory into shadow
 *
 * S-type encoding:   .insn s opcode7, func3, rs2, simm12(rs1)
 *   31..25        24..20  19..15  14..12  11..7         6..0
 *   simm12[11:5]  rs2     rs1     func3   simm12[4:0]   opcode7
 *
 * R-type encoding:   .insn r opcode7, func3, func7, rd, rs1, rs2
 *   31..25  24..20  19..15  14..12  11..7  6..0
 *   func7   rs2     rs1     func3   rd     opcode7
 *
 * Reference: https://nitish2112.github.io/post/adding-instruction-riscv/
 * ========================================================================= */

typedef enum {
    OPCODE_RMLD = 0x0b,   /* custom-0: R-type */
    OPCODE_RMST = 0x2b    /* custom-1: S-type */
} opcodes_t;

/* -------------------------------------------------------------------------
 * S-type: Configuration instructions  (opcode = 0x2b)
 * ------------------------------------------------------------------------- */

/* CDSRM — Configure Data Register
 * Sets the data register to `data`. Used as operand source for RMCC. */
#define CDSRM(data) \
    do { __asm__ volatile (".insn s 0x2b, 0b100, x0, 0x0(%0)" :: "r"(data)); } while (0)

/* CASRM — Configure Store Address Register
 * Sets the SRAM address that stream-write instructions (RMCS/RMCC/RMXR/RMXS)
 * will read from and write back to. */
#define CASRM(store_addr) \
    do { __asm__ volatile (".insn s 0x2b, 0b101, x0, 0x0(%0)" :: "r"(store_addr)); } while (0)

/* CALRM — Configure Load Address Register
 * Sets the SRAM address that RMLD will read from into the shadow register. */
#define CALRM(load_addr) \
    do { __asm__ volatile (".insn s 0x2b, 0b110, %0, 0x0(x0)" :: "r"(load_addr)); } while (0)

/* CASLRM — Configure Store Address + Load Address Registers (combined)
 * Equivalent to CASRM + CALRM in a single instruction. */
#define CASLRM(store_addr, load_addr) \
    do { __asm__ volatile (".insn s 0x2b, 0b111, %0, 0x0(%1)" :: "r"(load_addr), "r"(store_addr)); } while (0)

/* -------------------------------------------------------------------------
 * S-type: Stream write instructions  (opcode = 0x2b)
 *
 * All take (bit_idx, num_bits): operate on `num_bits` bits starting at
 * position `bit_idx` within the stream at the configured store address.
 * The hardware encodes num_bits as (num_bits - 1) in the instruction word.
 * ------------------------------------------------------------------------- */

/* RMXR — Stream Extend Reset: write `num_bits` zero-bits at `bit_idx`. */
#define RMXR(bit_idx, num_bits) \
    do { __asm__ volatile (".insn s 0x2b, 0b000, %0, 0x0(%1)" :: "r"(num_bits-1), "r"(bit_idx)); } while (0)

/* RMXS — Stream Extend Set: write `num_bits` one-bits at `bit_idx`. */
#define RMXS(bit_idx, num_bits) \
    do { __asm__ volatile (".insn s 0x2b, 0b001, %0, 0x0(%1)" :: "r"(num_bits-1), "r"(bit_idx)); } while (0)

/* RMCS — Stream Copy Shadow: copy `num_bits` bits from shadow register
 * (loaded by RMLD) into the stream at `bit_idx`. */
#define RMCS(bit_idx, num_bits) \
    do { __asm__ volatile (".insn s 0x2b, 0b010, %0, 0x0(%1)" :: "r"(num_bits-1), "r"(bit_idx)); } while (0)

/* RMCC — Stream Copy Data: copy `num_bits` bits from data register
 * (set by CDSRM) into the stream at `bit_idx`. */
#define RMCC(bit_idx, num_bits) \
    do { __asm__ volatile (".insn s 0x2b, 0b011, %0, 0x0(%1)" :: "r"(num_bits-1), "r"(bit_idx)); } while (0)

/* -------------------------------------------------------------------------
 * R-type: Memory load instruction  (opcode = 0x0b)
 * ------------------------------------------------------------------------- */

/* RMLD — Load from memory into shadow register.
 * Reads `num_bits` bits starting at `bit_idx` from the SRAM address
 * configured by CALRM/CASLRM. Writes the loaded value into the shadow
 * register for later use by RMCS. Returns the bit count in `rd`.
 *
 * OBI timing note: wdata is presented one cycle after req is asserted
 * (OBI-compliant — data must be stable at gnt, not at req). */
#define RMLD(bit_idx, num_bits, rd) \
    do { __asm__ volatile (".insn r 0x0b, 0, 0, %0, %1, %2" : "=r"(rd) : "r"(bit_idx), "r"(num_bits-1)); } while (0)

#endif /* INSTR_H */
