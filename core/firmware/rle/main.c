#include <stdio.h>
#include <string.h>

#include "rle.h"
#include "data.h"
#include "instr.h"

int main(void);

void rle_test(void);

void prepare_data(uint8_t* data);

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
}

void debug_print_rle_compressed_blocks(bitstream* compressed_b_stream)
{
  uint32_t blocks_to_read = compressed_b_stream->curr_size / bits_rle_block_g;
  uint32_t not_compressed_mask = 0x1 << (bits_rle_block_g - 1);
  uint32_t counter_mask = 0b10;

  uint32_t value_to_store = 0;
  for(uint8_t curr_bit = 1; curr_bit < (bits_rle_block_g - 2); curr_bit++)
  {
    counter_mask |= counter_mask << 1;
  }
  //selects only the bits of uncompressed block to store
  uint32_t uncompressed_bits_mask = counter_mask | 0x1;
  
  for(uint32_t curr_block = 0; curr_block < blocks_to_read; curr_block++)
  {
   
    uint32_t curr_rle_block = read(compressed_b_stream, curr_block*bits_rle_block_g,
                                   bits_rle_block_g);
    //printf("\n RLE block stored = ");
    //uart_w_32bit_binary(curr_rle_block, 1);
    
     if (curr_rle_block & not_compressed_mask)
     {
       value_to_store = curr_rle_block & uncompressed_bits_mask;
       printf("uncomp value = ");
       printf("%d\n", value_to_store);
     }
     else
     {
       uint32_t count = (curr_rle_block & counter_mask) >> 1;
       value_to_store = curr_rle_block & 0b1;
       printf("counted = ");
       printf("%d", count);
       printf(" value = ");
       printf("%d\n", value_to_store);
     }
    
  }
  
  uint8_t remainder_bits = compressed_b_stream->curr_size % bits_rle_block_g;
  if (remainder_bits != 0)
  {
    value_to_store = read(compressed_b_stream, compressed_b_stream->curr_size - remainder_bits,
                          remainder_bits);
    printf("uncompressed remainder bits: ");
    printf("%d\n", value_to_store);
  }
}

void uart_print_compressed(bitstream* b_streams)
{
  printf("--- Compressed Signals ---\n");
   for (uint8_t i = 0; i < SIGNALS; i++)
  {
    printf("[Signal %d]\n", i);
    debug_print_rle_compressed_blocks(&(b_streams[i]));
    printf("\n-------------------------------\n");
  }
}

void rle_test(void)
{
    // Our data we want to compress
    uint8_t data[DATA_BYTE_SIZE];

    // Fill buffer with example data
    prepare_data(data);
    
    strcpy((char*)data, "Hello World!");
    
    // Print data
    for (int i=0; i<DATA_BYTE_SIZE; i+=4)
    {
        printf("%2d: %3d %3d %3d %3d\n", i, data[i],data[i+1],data[i+2],data[i+3]);
    }
    printf("\n");

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

    uart_print_compressed(b_streams);

    rle_decompress(&(b_streams[0]), &(b_streams_uncomp[0]));
    rle_decompress(&(b_streams[1]), &(b_streams_uncomp[1]));
    rle_decompress(&(b_streams[2]), &(b_streams_uncomp[2]));
    rle_decompress(&(b_streams[3]), &(b_streams_uncomp[3]));

    // signal start compression

    // array where data is stored in SIGNAL blocks of for example 4 bit
    uint8_t data_after_decomp[DATA_BYTE_SIZE];

    // Write bitstream to data
    write_data_in_blocks(data_after_decomp, b_streams_uncomp, 1);

    // Print data
    for (int i=0; i<DATA_BYTE_SIZE; i+=4)
    {
        printf("%2d: %3d %3d %3d %3d\n", i, data_after_decomp[i],data_after_decomp[i+1],data_after_decomp[i+2],data_after_decomp[i+3]);
    }
    printf("\n");

    uint8_t test_passed = test_comp_equal_uncomp(data, data_after_decomp);
    
    if (test_passed) printf("Test passed.\n");
    else printf("Test failed.\n");
}

int main(void)
{
    rle_test();
    return 0;
}
