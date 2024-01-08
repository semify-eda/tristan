#include "rle_test.h"

void prepare_sample(uint64_t *sample_data) {
    puts("\n --- Prepare Samples ---\n");
    puts("-----------------------------\n");
    uint8_t start_of_sync = 5;
    uint8_t end_of_sync = start_of_sync + (32 / 2);
    /*
     * Test Signals
     * Generate a random Data signal for each iteration
     * The CLK, SYNC and CLR signals are the same for every test case
     */
    uint8_t DATA[] = {1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1,
                    1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
                    1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0};
    
 
    uint8_t CLK[] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
                    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};

    uint8_t SYNC[] = {1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                      1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

    uint8_t CLR[] = {0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                     0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

    for (uint8_t curr_samp = 0; curr_samp < SAMPLES; curr_samp++) {
        // Load CLK
        sample_data[curr_samp] = CLK[curr_samp];
        puts("CLK: ");print(CLK[curr_samp]);putc('\n');
        puts("Data sample after CLK: ");print(sample_data[curr_samp]);puts(" for sample: ");print(curr_samp);putc('\n');
        // Load SNYC
        if ((start_of_sync >= 5) && (start_of_sync < end_of_sync))
            sample_data[curr_samp] |= SYNC[curr_samp] << 1;
        puts("SYNC: ");print(SYNC[curr_samp]);putc('\n');
        puts("Data sample after SYNC: ");print(sample_data[curr_samp]);puts(" for sample: ");print(curr_samp);putc('\n');
        // Load DATA
        sample_data[curr_samp] |= DATA[curr_samp] << 2;
        puts("DATA: ");print(DATA[curr_samp]);putc('\n');
        puts("Data sample after DATA: ");print(sample_data[curr_samp]);puts(" for sample: ");print(curr_samp);putc('\n');
        // Load CLR
        sample_data[curr_samp] |= CLR[curr_samp] << 3;
        puts("CLR: ");print(CLR[curr_samp]);putc('\n');
        puts("Data sample after CLR: ");print(sample_data[curr_samp]);puts(" for sample: ");print(curr_samp);putc('\n');
        puts("-----------------------------\n");
    }
}

/* 
 * Function: prepare_byte
 * -------------------------
 *  Take the sampled data and store it as bytes
 */
void prepare_byte(uint8_t *data, uint64_t *sample_data) {
    puts("\n --- Store Samples in Byte format ---\n");
    puts("-----------------------------\n");
    for (uint8_t sample = 0; sample < SAMPLES; sample++) {
        if (sample % 2 == 1) {
            puts("First Sample: ");print((sample/2)*2);puts("\tSecond Sample: ");print(sample);puts("\tData byte: ");print(sample/2);putc('\n');
            
            data[sample / 2] |= sample_data[(sample / 2) * 2];
            puts("Byte Data:  ");print(data[sample / 2]);puts("\tSampled data: ");print( sample_data[(sample / 2) * 2]);putc('\n');
            
            data[sample / 2] |= sample_data[sample] << 4;
            puts("Byte Data:  ");print(data[sample / 2]);puts("\tSampled data: ");print( sample_data[sample]);putc('\n');
            puts("-----------------------------\n");
        }
    }
}

void debug_print_rle_compressed_blocks(bitstream *compressed_b_stream, uint8_t sig) {
    uint32_t block_size = compressed_b_stream->curr_size;
    uint32_t curr_block = 0;

    for (uint32_t b_slice = 0; b_slice < block_size; b_slice++) {
        if (block_len[sig][b_slice] == 0)
            return;

        uint32_t counter_mask = 2;  // 0b10
        uint32_t value_to_store = 0;

        for (uint8_t curr_bit = 1; curr_bit < (block_len[sig][b_slice] - 1); curr_bit++) {
            counter_mask |= counter_mask << 1;
        }

        uint32_t curr_rle_block = read(compressed_b_stream, curr_block, block_len[sig][b_slice]);
        uint32_t count = (curr_rle_block & counter_mask) >> 1;
        value_to_store = curr_rle_block & 1;  // 0b1

        if (count < ((uint32_t)bits_rle_block_g - 1)){
            puts("Uncompressed data: CNT_VAL: ");print(count);puts("\tBIT_VAL: ");print(value_to_store);putc('\n');
        } else {
            puts("Compressed data: CNT_VAL: ");print(count);puts("\tBIT_VAL: ");print(value_to_store);putc('\n');
        }
        curr_block += block_len[sig][b_slice];
    }
}

void uart_print_compressed(bitstream* b_streams)
{
  puts("\n--- Compressed Signals ---\n");
   for (uint8_t i = 0; i < SIGNALS; i++)
  {
    puts("[Signal: "); print(i); puts("]\n");
    debug_print_rle_compressed_blocks(&(b_streams[i]), i);
    puts("\n-------------------------------\n");
  }
}


void rle_test(void)
{
    // Sample the incoming signals
    uint64_t sample_data[SAMPLES];
    prepare_sample(sample_data);

    // Organise the samples in a byte
    uint8_t data[DATA_BYTE_SIZE];
    prepare_byte(data, sample_data);

    // Print preprocessed data from buffer
    puts("\n--- Print Data from buffer ---\n");
    for (int i=0; i<DATA_BYTE_SIZE; i+=4)
    {
        print(i); puts(":\t");
        print(data[i]); putc('\t');
        print(data[i+1]); putc('\t');
        print(data[i+2]); putc('\t');
        print(data[i+3]); putc('\t'); putc('\n');
    }
    putc('\n');

    // bitstream of compressed data
    bitstream b_streams[SIGNALS];

    // bitstream of uncompressed data
    bitstream b_streams_uncomp[SIGNALS];
    
    // bitstream of uncompressed aligned data
    bitstream b_streams_uncomp_aligned[SIGNALS];

    // stores bits of signals aligned in bitsreams
    read_all_signals(data, b_streams_uncomp_aligned);
    
    init_global_bitstreams(b_streams, b_streams_uncomp, b_streams_uncomp_aligned);

    puts("\n--- Start RLE Compression ---\n");
    rle_compress(data, b_streams);
    puts("\n--- RLE Compression Completed ---\n");
    // Print compressed data from bitstream
    uart_print_compressed(b_streams);

    rle_decompress(&(b_streams[0]), &(b_streams_uncomp[0]), 0);
    rle_decompress(&(b_streams[1]), &(b_streams_uncomp[1]), 1);
    rle_decompress(&(b_streams[2]), &(b_streams_uncomp[2]), 2);
    rle_decompress(&(b_streams[3]), &(b_streams_uncomp[3]), 3);

    // array where data is stored in SIGNAL blocks of for example 4 bit
    uint8_t data_after_decomp[DATA_BYTE_SIZE];

    // Write bitstream to data
    write_data_in_blocks(data_after_decomp, b_streams_uncomp, 1);

    puts("\n--- Print Decompressed Data ---\n");
    for (int i=0; i<DATA_BYTE_SIZE; i+=4)
    {
        print(i); puts(":\t");
        print(data_after_decomp[i]); putc('\t');
        print(data_after_decomp[i+1]); putc('\t');
        print(data_after_decomp[i+2]); putc('\t');
        print(data_after_decomp[i+3]); putc('\t'); putc('\n');
    }
    putc('\n');

    uint8_t test_passed = test_comp_equal_uncomp(data, data_after_decomp);
    
    if (test_passed) puts("\nTest passed.\n");
    else puts("\nTest failed.\n");
}