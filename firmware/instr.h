#ifndef INSTR_H
#define INSTR_H

#include <stdint.h>

extern uint8_t g_custom_instructions;

#define OPCODE_CNTB 0x6B

int cntb(unsigned int value, unsigned int start_pos);
int cntb_soft(unsigned int value, unsigned int start_pos);
int cntb_hard(unsigned int value, unsigned int start_pos);

#endif
