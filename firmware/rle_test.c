#include "rle_test.h"

void prepare_sample(int *sample_data) {
    uint8_t start_of_sync = 5;
    uint8_t end_of_sync = start_of_sync + (32 / 2);
    /*
     * Test Signals
     * Generate a random Data signal for each iteration
     * The CLK, SYNC and CLR signals are the same for every test case
     */
    uint64_t DATA[] = {1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0,
                       0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1,
                       1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
                       1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0,
                       0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1};
    
 
    uint64_t CLK[] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                      1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};

    uint64_t SYNC[] = {1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                       1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                       1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                       1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0};

    uint64_t CLR[] = {1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                      1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                      1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
                      1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0};

    for (uint8_t curr_samp = 0; curr_samp < SAMPLES; curr_samp++) {
        // Load CLK
        sample_data[curr_samp] |= CLK[curr_samp] << 0;
        if ((start_of_sync >= 5) && (start_of_sync < end_of_sync)) {
            sample_data[curr_samp] |= SYNC[curr_samp] << 1;
        }
        sample_data[curr_samp] |= DATA[curr_samp] << 2;
        sample_data[curr_samp] |= CLR[curr_samp] << 3;
    }
}

/*
 * Function: prepare_byte
 * -------------------------
 *  Take the sampled data and store it as bytes
 */
void prepare_byte(uint8_t *data, int *sample_data) {
    for (uint8_t sample = 0; sample < SAMPLES; sample++) {
        if (sample % 2 == 1) {
            data[sample / 2] |= sample_data[(sample / 2) * 2];
            data[sample / 2] |= sample_data[sample] << 4;
        }
    }
}


void rle_test(void)
{
    // Sample the incoming signals
    int sample_data[SAMPLES];
    // prepare_sample(sample_data);

    // Organise the samples in a byte
    uint8_t data[DATA_BYTE_SIZE];
    prepare_byte(data, sample_data);

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

    rle_decompress(&(b_streams[0]), &(b_streams_uncomp[0]), 0);
    rle_decompress(&(b_streams[1]), &(b_streams_uncomp[1]), 1);
    rle_decompress(&(b_streams[2]), &(b_streams_uncomp[2]), 2);
    rle_decompress(&(b_streams[3]), &(b_streams_uncomp[3]), 3);

    // signal start compression

    // array where data is stored in SIGNAL blocks of for example 4 bit
    uint8_t data_after_decomp[DATA_BYTE_SIZE];

    // Write bitstream to data
    write_data_in_blocks(data_after_decomp, b_streams_uncomp, 1);

    uint8_t test_passed = test_comp_equal_uncomp(data, data_after_decomp);
    
    if (test_passed) puts("Test passed.\n");
    else puts("Test failed.\n");
}