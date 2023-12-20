#ifndef RLE_TEST_H
#define RLE_TEST_H

#include "rle/data.h"
#include "rle/rle.h"
#include "instr.h"
#include "util.h"

void rle_test(void);
void prepare_sample(int *samp_data);
void prepare_byte(uint8_t *data, int *sample_data);
void debug_print_rle_compressed_blocks(bitstream *compressed_b_stream, uint8_t sig);
void uart_print_compressed(bitstream* b_streams);

#endif