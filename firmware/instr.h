#ifndef INSTR_H
#define INSTR_H

#include <stdint.h>

extern uint8_t g_custom_instructions;

#define OPCODE_CNTB 0x6B

int cntb(int value, int start_pos);
int cntb_soft(int value, int start_pos);
int cntb_hard(int value, int start_pos);

#endif
