#include "csr.h"

void enable_mcycle(void)
{
    int mask = 1; // Clear bit 0

    __asm__ volatile ("csrrc    zero, mcountinhibit, %0"  
                          : /* output: none */ 
                          : "r" (mask)  /* input : register */
                          : /* clobbers: none */);
}

void enable_minstret(void)
{
    int mask = 4; // Clear bit 2

    __asm__ volatile ("csrrc    zero, mcountinhibit, %0"  
                          : /* output: none */ 
                          : "r" (mask)  /* input : register */
                          : /* clobbers: none */);
}

int get_cycle(void)
{
    int cycle;
    __asm__ volatile ("rdcycle %0" : "=r"(cycle));
    return cycle;
}
