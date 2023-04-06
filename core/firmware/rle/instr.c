#include "instr.h"

/*
    Example:
    value = 00011100
    start_pos = 3
    counted_concurrent_bits = 2
    Note: Counts to LSB
*/

#if (CUSTOM_INSTRUCTIONS == 1)
inline int cntb(int value, int start_pos)
{
    return cntb_hard(value, start_pos);
}
#else
inline int cntb(int value, int start_pos)
{
    return cntb_soft(value, start_pos);
}
#endif

int cntb_soft(int value, int start_pos)
{
    int counted_concurrent_bits = 1;
    int bit = (value & (1<<start_pos)) >> start_pos;

    while (start_pos-- > 0)
    {
        int cur_bit = (value & (1<<start_pos)) >> start_pos;
        if (cur_bit != bit) break;
        counted_concurrent_bits++;
    }

    return counted_concurrent_bits;
}

int cntb_hard(int value, int start_pos)
{
    int counted_concurrent_bits;
    __asm__ volatile (".insn r 0x6b, 0, 0, %0, %1, %2" : "=r" (counted_concurrent_bits)
                                                       : "r" (value),
                                                         "r" (start_pos));
    return counted_concurrent_bits;
}


#if (CUSTOM_INSTRUCTIONS == 1)
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
#else

/*
    You get a stream of unaligned signal bits like this:
    | s0 s1 s2 s3 | s0 s1 s2 s3 | s0 s1 s2 s3 | ...
    And you want to write all s0 into one stream, all s2 into one etc.
*/
int wbits(uint8_t* d_8_src, int offset)
{
    /*int return_value;

    // the following for loops store 32bit of all Signals
    for (uint8_t curr_sample = 0; curr_sample < n32_over_signals;
         curr_sample++) {
        for (uint8_t curr_bstream = 0; curr_bstream < SIGNALS;
             curr_bstream++) {
            // read form highest addr to lowest addr out of bitstreams
            // becasue stored inversed to
            //  avoid having to do bit reversal
            if (reverse_bits)
                curr_sample_to_read = SAMPLES - curr_sample - 1 -
                                      curr_bit32_offset * n32_over_signals;
            else
                curr_sample_to_read =
                    curr_sample + curr_bit32_offset * n32_over_signals;

            return_value |=
                read(&(source_bs[curr_bstream]), curr_sample_to_read, 1)
                << (curr_sample * SIGNALS + curr_bstream);
        }
    }
    
    return return_value;*/
    
    (void)d_8_src;
    (void)offset;
    
    return 42;
}
#endif
