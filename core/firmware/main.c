#include "util.h"
#include "rle/data.h"
#include "rle/rle.h"
#include "rle/instr.h"

void main(void);

void rle_test(void);

#define CMD_LEN 16
char cmd_buffer[CMD_LEN];

void prepare_data(uint8_t* data);

void test_cntb(void);

int xorshift32(int x);

void prepare_data(uint8_t* data)
{

  uint8_t start_of_sync = 5;
  uint8_t end_of_sync = start_of_sync + (32/2);
  uint16_t data_bits = 0b101011101111101;
  uint8_t cmd_and_addr = 0b00010000;
  uint32_t dac_data = 0;
  dac_data |=  (data_bits << 4) | (cmd_and_addr << 20);//0b00000001000000000000000000010000;
  // init clock
  for (uint8_t curr_byte = 0; curr_byte < DATA_BYTE_SIZE; curr_byte++)
  {
    // clock signal
    data[curr_byte] = 0b10001U;

    // to test count and uncpompressed signal gen
    // over 32 bit block
    if (curr_byte == 33) 
         data[curr_byte] = 0b10000;

    // sync
    if ((start_of_sync >= 5) && (start_of_sync < end_of_sync))
      data[curr_byte] |= 0b100010;

    data[curr_byte] |= ((dac_data & 0b1) << 2);
    data[curr_byte] |= ((dac_data & 0b10) << 5);
    dac_data = dac_data >> 2;

    // set clear signal
    data[curr_byte] |= 0b10001000;
  }

  //bitstream inited_data = {data, 0, DATA_SIZE};

  //print_bitstream(&inited_data);
}

void rle_test(void)
{
    // Our data we want to compress
    uint8_t data[DATA_BYTE_SIZE];

    // Fill buffer with example data
    prepare_data(data);

    // bitstream of compressed data
    bitstream b_streams[SIGNALS];

    // bitstream of uncompressed data
    bitstream b_streams_uncomp[SIGNALS];
    
    // bitstream of uncompressed aligned data
    bitstream b_streams_uncomp_aligned[SIGNALS];

    // stores bits of signals alligned in bitsreams
    read_all_signals(data, b_streams_uncomp_aligned);
    
    init_global_bitstreams(b_streams, b_streams_uncomp, b_streams_uncomp_aligned);


    rle_compress(data, b_streams);

    rle_decompress(&(b_streams[0]), &(b_streams_uncomp[0]));
    rle_decompress(&(b_streams[1]), &(b_streams_uncomp[1]));
    rle_decompress(&(b_streams[2]), &(b_streams_uncomp[2]));
    rle_decompress(&(b_streams[3]), &(b_streams_uncomp[3]));

    // signal start compression

    // array where data is stored in SIGNAL blocks of for example 4 bit
    uint8_t data_after_decomp[DATA_BYTE_SIZE];

    // Write bitstream to data
    write_data_in_blocks(data_after_decomp, b_streams_uncomp, 1);

    uint8_t test_passed = test_comp_equal_uncomp(data, data_after_decomp);
    
    if (test_passed) puts("Test passed.\n");
    else puts("Test failed.\n");
}

int xorshift32(int x) {
    x |= x == 0;   // if x == 0, set x = 1 instead
    x ^= (x & 0x0007ffff) << 13;
    x ^= x >> 17;
    x ^= (x & 0x07ffffff) << 5;
    return x & 0xffffffff;
}

void test_cntb(void)
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
        
        int bits = cntb_hard(value, start_pos);
        int bits_soft = cntb_soft(value, start_pos);
    
        // Print summary
        print(value);
        putc('\t');
        print(start_pos);
        putc('\t');
        print(bits);
        putc('\t');
        print(bits_soft);
        putc('\t');
        
        if (bits == bits_soft)
        {
            puts("OK\n");
        }
        else
        {
            puts("ERROR\n");
        }
    }
}

void main(void)
{
    setLED(0);
    setLED(1);
    setLED(0);

    puts("----------------------------------------\n");
    puts("Bootup complete.\n");
    puts("----------------------------------------\n");
    puts("CV32E40X @ 25.00 MHz\n");
    puts("Total Memory: 4 kiB\n");
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
            puts("help ....... This command\n");
        }
        else if (strcmp("hello", cmd_buffer) == 0)
        {
            puts("Hello World!\n");
        }
        else if (strcmp("rle", cmd_buffer) == 0)
        {
            rle_test();
        }
        else if (strcmp("cntb", cmd_buffer) == 0)
        {
            test_cntb();
        }
        else if (strcmp("blink", cmd_buffer) == 0)
        {
            for (int i=0; i<10; i++)
            {
                setLED(i+1);
                volatile int cnt = 0;
                while (cnt++ < 300000);
            }
            setLED(0);
        }
        else
        {
            puts("Invalid command! Type 'help' for a command overview.\n");
        }
    }
}
