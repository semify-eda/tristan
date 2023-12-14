#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>

#include "rle.h"
#include "data.h"
#include "instr.h"

int main(void);
void rle_test(void);
void test_cntb(void);
int xorshift32(int x);
void prepare_sample(uint8_t *samp_data);
void prepare_byte(uint8_t *data, int *sample_data);

/*
 * Function: prepare_sample
 * -------------------------
 * Organizes the incoming signal into a 4-bit buffer
 * over the number of user defined samples
 * 
 * The default is, 64 samples over 4 signals (CLK, SYNC, DATA, CLR) 
 * 
 * sample_data: array to store the sampled signals 
*/
void prepare_sample(int* sample_data)
{
    // printf("\n --- Prepare Samples ---\n");
    //printf("-----------------------------\n");
    uint8_t start_of_sync = 5;
    uint8_t end_of_sync = start_of_sync + (32 / 2);
    uint64_t DATA[SAMPLES];   // TODO: Only used for random data generation
    
   /* 
    * Test Signals 
    * Generate a random Data signal for each iteration
    * The CLK, SYNC and CLR signals are the same for every test case
   */ 
    
    srand((unsigned int)time(NULL) * 1000 + clock() % 100);
    for (int num = 0; num < SAMPLES; num++)
    {
        DATA[num] = (rand() % 2);
    } 
    /*
    uint64_t DATA[] = {1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0,
                       0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1,
                       1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
                       1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0,
                       0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1};
    */
    /*
    // Simple ramp
    uint64_t DATA[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
                       0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1,
                       0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1,
                       0, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1};
    */
    /*
    //Sine with 4-bit ADC
    uint64_t DATA[] = {0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1,
                       0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1,
                       1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1,
                       1, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1};
    */
      
    uint64_t CLK[] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
                      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};

    uint64_t SYNC[] = {1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                       1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                       1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                       1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0};

    uint64_t CLR[] =  {1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                       1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                       1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                       1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0};
    

    for (uint8_t curr_samp = 0; curr_samp < SAMPLES; curr_samp++)
    {
        // Load CLK 
        sample_data[curr_samp] |= CLK[curr_samp] << 0;
        // printf("Data sample after CLK: 0x%.0x for sample: %0d\n", sample_data[curr_samp], curr_samp);
        // Load SNYC
        if ((start_of_sync >= 5) && (start_of_sync < end_of_sync))
            sample_data[curr_samp] |= SYNC[curr_samp] << 1;
        // printf("Data sample after SYNC: 0x%.0x for sample: %0d\n", sample_data[curr_samp], curr_samp);
        // Load DATA
        sample_data[curr_samp] |= DATA[curr_samp] << 2;
        // printf("Data sample after DATA: 0x%.0x for sample: %0d\n", sample_data[curr_samp], curr_samp);
        // Load CLR
        sample_data[curr_samp] |= CLR[curr_samp] << 3;
        // printf("Data sample after CLR: 0x%.0x for sample: %0d\n", sample_data[curr_samp], curr_samp);
        // printf("-----------------------------\n");
    }
}

/* 
 * Function: prepare_byte
 * -------------------------
*  Take the sampled data and store it as bytes
*/
void prepare_byte(uint8_t* data, int* sample_data)
{ 
    // printf("\n --- Store Samples in Byte format ---\n");
    // printf("-----------------------------\n");
    for (uint8_t sample = 0; sample < SAMPLES; sample++)
    {
        if (sample % 2 == 1)
        {
            // printf("First Sample: %d\tSecond Sample: %d\tData byte: %d\n", (sample/2)*2, sample, sample/2);
            data[sample / 2] |= sample_data[(sample / 2) * 2];
            // printf("Byte Data: 0x%.0x  Sampled data: 0x%.0x\n", data[sample / 2], sample_data[(sample / 2) * 2]);
            data[sample / 2] |= sample_data[sample] << 4;
            // printf("Byte Data: 0x%.0x  Sampled data: 0x%.0x\n", data[sample / 2], sample_data[sample]);
            // printf("-----------------------------\n");
        }
    }

}

void debug_print_rle_compressed_blocks(bitstream *compressed_b_stream, uint8_t sig) {
    uint32_t block_size = compressed_b_stream->curr_size;
    uint32_t curr_block = 0;

    for (uint32_t b_slice = 0; b_slice < block_size; b_slice++) {
        if (block_len[sig][b_slice] == 0)
            return 0;

        uint32_t not_compressed_mask = 0x1 << (block_len[sig][b_slice] - 1);
        uint32_t counter_mask = 0b10;
        uint32_t value_to_store = 0;

        for (uint8_t curr_bit = 1; curr_bit < (block_len[sig][b_slice] - 2); curr_bit++) {
            counter_mask |= counter_mask << 1;
        }

        uint32_t uncompressed_bits_mask = counter_mask | 0x1;
        uint32_t curr_rle_block = read(compressed_b_stream, curr_block, block_len[sig][b_slice]);
        uint32_t count = (curr_rle_block & counter_mask) >> 1;
        value_to_store = curr_rle_block & 0b1;

        if (curr_rle_block & not_compressed_mask) {
            printf("Uncompressed data: CNT_VAL: %d\tBIT_VAL: %d\n", count, value_to_store);
        } else {
            printf("Compressed data: CNT_VAL: %d\tBIT_VAL: %d\n", count, value_to_store);
        }
        curr_block += block_len[sig][b_slice];
    }
}

void uart_print_compressed(bitstream* b_streams)
{
  printf("\n--- Compressed Signals ---\n");
   for (uint8_t i = 0; i < SIGNALS; i++)
  {
    printf("[Signal %d]\n", i);
    debug_print_rle_compressed_blocks(&(b_streams[i]), i);
    printf("\n-------------------------------\n");
  }
}

void rle_test(void)
{
    // Sample the incoming signals
    int sample_data[SAMPLES];
    memset(sample_data, 0, SAMPLES * sizeof(sample_data[0]));
    prepare_sample(sample_data);
    
    // Organise the samples in a byte
    uint8_t data[DATA_BYTE_SIZE];
    memset(data, 0, DATA_BYTE_SIZE * sizeof(data[0]));
    prepare_byte(data, sample_data);
    
    // Print preprocessed data from buffer
    printf("\n--- Print Data from buffer ---\n");
    for (int i=0; i<DATA_BYTE_SIZE; i+=4)
    {
        printf("%2d: 0x%.0x 0x%.0x 0x%.0x 0x%.0x\n", i, data[i], data[i + 1], data[i + 2], data[i + 3]);
    }
    printf("\n");
    
    // bitstream of compressed data
    bitstream b_streams[SIGNALS];
    // bitstream of uncompressed data
    bitstream b_streams_uncomp[SIGNALS];    
    // bitstream of uncompressed aligned data
    bitstream b_streams_uncomp_aligned[SIGNALS];

    // stores bits of signals aligned in bitstreams
    printf("--- Read All Signals and Store Them Aligned in Bitstreams ---");
    read_all_signals(data, b_streams_uncomp_aligned);

    printf("\n--- Initialise Global Bitstreams ---");
    init_global_bitstreams(b_streams, b_streams_uncomp, b_streams_uncomp_aligned);

    printf("\n--- Start RLE Compression ---\n");
    rle_compress(data, b_streams);
    printf("\n--- RLE Compression Completed ---\n");

    // Print compressed data from bitstream
    uart_print_compressed(b_streams);

    printf("\n--- Start RLE Decompression ---\n");
    rle_decompress(&(b_streams[0]), &(b_streams_uncomp[0]), 0);   
    rle_decompress(&(b_streams[1]), &(b_streams_uncomp[1]), 1);
    rle_decompress(&(b_streams[2]), &(b_streams_uncomp[2]), 2);
    rle_decompress(&(b_streams[3]), &(b_streams_uncomp[3]), 3);    

    // array where data is stored in SIGNAL blocks of for example 4 bit
    uint8_t data_after_decomp[DATA_BYTE_SIZE];
    memset(data_after_decomp, 0, DATA_BYTE_SIZE * sizeof(data_after_decomp[0]));

    // Write bitstream to data
    write_data_in_blocks(data_after_decomp, b_streams_uncomp, 1);

    // Print decompressed data
    printf("\n\n--- Print Decompressed Data ---\n");
    for (int i=0; i<DATA_BYTE_SIZE; i+=4)
    {
        printf("%2d: 0x%.0x 0x%.0x 0x%.0x 0x%.0x\n", i, data_after_decomp[i],
               data_after_decomp[i + 1], data_after_decomp[i + 2],
               data_after_decomp[i + 3]);
    }
    printf("\n");

    // Unsure that the decompressed signals are matching the original data 
    uint8_t test_passed = test_comp_equal_uncomp(data, data_after_decomp);
    if (test_passed) printf("\nTest passed.\n");
    else printf("\nTest failed.\n");
}

int xorshift32(int x) {
    x |= x == 0; 
    x ^= (x & 0x0007ffff) << 13;
    x ^= x >> 17;
    x ^= (x & 0x07ffffff) << 5;
    return x & 0xffffffff;
}

void test_cntb(void) {
    static int random_value = 0;
    printf("\t---- CNTB test  ----\n");
    //printf("Value\t\tPos\tConsecutive Bits\n");

    for (int i = 0; i < 31; i++) {
        // Get new random data value
        random_value = xorshift32(random_value);
        int value = random_value;

        // Get new random value for start position
        random_value = xorshift32(random_value);
        int start_pos = ((unsigned int)random_value) % 32;

        // Fixed test data
        // value = 0xffffffff; 
        // start_pos = 1 + (1 * i);
        
        int bits = cntb_soft(value, start_pos);

        printf("Value\t\tPos\tConsecutive Bits\n");
        printf("0x%.0x\t%d\t%d\t\n", value, start_pos, bits);
    }
    printf("\n");
}

int main(void)
{
    //test_cntb();

    for (int i = 1; i < 2; i++) {
        printf("---- RLE test run: %d ----", i);
        rle_test();
        printf("\n---- Test Run %d has finished ----\n\n", i);
    }
    return 0;
}
