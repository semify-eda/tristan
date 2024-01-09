#include "util.h"
#include "csr.h"
#include "instr.h"
#include "cntb_test.h"
#include "rle_test.h"

void main(void);

#define CMD_LEN 16
char cmd_buffer[CMD_LEN];

void main(void)
{
    setLED(0);
    setLED(1);
    setLED(0);
    
    int bits = cntb_hard(0xFFFFFFFF, 7);
    setLED(1);
    print(bits);
    setLED(0);

    // TODO It seems like CSRs and our custom instructions
    //      don't work together
    //enable_mcycle();
    //enable_minstret();

    cntb_test();
    
    setLED(0);
    setLED(1);
    setLED(0);

    puts("----------------------------------------\n");
    puts("Bootup complete.\n");
    puts("----------------------------------------\n");
    puts("CV32E40X @ 25.00 MHz\n");
    puts("Total Memory: 16 kiB\n");
    puts("----------------------------------------\n");

    while (1) {
        puts("> ");
        
        if (gets(cmd_buffer, CMD_LEN))
        {
            puts("Command too long!\n");
        }
        puts(cmd_buffer);
        putc('\n');

        if (strcmp("help", cmd_buffer) == 0)
        {
            puts("hello ...... Welcome message\n");
            puts("rle ........ Start run length encoding\n");
            puts("cntb ........Test cntb\n");
            puts("blink ...... Blink the onboard LED\n");
            puts("hard ....... Enable custom instructions\n");
            puts("soft ....... Disable custom instructions\n");
            puts("help ....... This command\n");
        }
        else if (strcmp("hello", cmd_buffer) == 0)
        {
            puts("Hello World!\n");
        }
        else if (strcmp("rle", cmd_buffer) == 0)
        {
            setLED(1);
            rle_test();
            setLED(0);
        }
        else if (strcmp("cntb", cmd_buffer) == 0)
        {
            cntb_test();
        }
        else if (strcmp("hard", cmd_buffer) == 0)
        {
            g_custom_instructions = 1;
        }
        else if (strcmp("soft", cmd_buffer) == 0)
        {
            g_custom_instructions = 0;
        }
        else if (strcmp("blink", cmd_buffer) == 0)
        {
            for (int i=0; i<10; i++)
            {
                setLED(i+1);
                volatile int cnt = 0;
                while (cnt++ < 30000);
            }
            setLED(0);
        }
        else
        {
            puts("Invalid command! Type 'help' for a command overview.\n");
        }
    }
}
