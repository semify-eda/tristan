#include "instr.h"

uint8_t g_custom_instructions = 0;

/*
    Example:
    value = 00011100
    start_pos = 3
    counted_concurrent_bits = 2
    Note: Counts to LSB
*/

int cntb(unsigned int value, unsigned int start_pos) {
    // TODO: remove line below, and uncomment section for HW implementation
    // return cntb_soft(value, start_pos);
    
    if (g_custom_instructions)
    {
        return cntb_hard(value, start_pos);
    }
    else
    {
        return cntb_soft(value, start_pos);
    }
    
}

int cntb_soft(unsigned int value, unsigned int start_pos) {
    unsigned int counted_concurrent_bits = 0;
    unsigned int bit = (value & (1 << start_pos)) >> start_pos; 

    while (start_pos-- > 0)
    {
        unsigned int cur_bit = (value & (1 << start_pos)) >> start_pos;
        if (cur_bit != bit) break;
        counted_concurrent_bits++;
    }

    return counted_concurrent_bits;
}


int cntb_hard(unsigned int value, unsigned int start_pos)
{
    int counted_concurrent_bits;
    __asm__ volatile (".insn r 0x6b, 0, 0, %0, %1, %2" : "=r" (counted_concurrent_bits)
                                                       : "r" (value),
                                                         "r" (start_pos));
    return counted_concurrent_bits;
}


int wbits(uint8_t* d_8_src, int offset)
{
    int result;

    __asm__ volatile (".insn r 0x07, 0, 0, %0, %1, %2\n"
              : "=r" (result)
              : "r"(d_8_src), "r"(offset)
              : 
      );

    return result;
}
