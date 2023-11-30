#include "cntb_test.h"

void cntb_test(void)
{
    static int random_value = 0;

    for (int i=0; i<30; i++)
    {
        // Get new random value
        random_value = xorshift32(random_value);
        int value = random_value;
        
        // Get new random value
        random_value = xorshift32(random_value);
        int start_pos = ((unsigned int)random_value) % 32;
        
        // Run both implementations
        int bits_hard = cntb_hard(value, start_pos);
        int bits_soft = cntb_soft(value, start_pos);
    
        // Print summary
        print(value);
        putc('\t');
        print(start_pos);
        putc('\t');
        print(bits_hard);
        putc('\t');
        print(bits_soft);
        putc('\t');
        
        if (bits_hard == bits_soft)
        {
            puts("OK\n");
        }
        else
        {
            puts("ERROR\n");
        }
    }
}
