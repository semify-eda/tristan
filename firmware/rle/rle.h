#ifndef RLE_H
#define RLE_H

#include "data.h"

// how many bits are used besides the counter bits
// to store one rle compressed block
#define ADDITIONAL_BITS 2
//Specifies at which position of the compressed rle block
// the counted value 0 or 1 is stored
#define VALUE_POSITION 1

// global variables for counter and counter length
// so they do not have to be handed over to every function
extern uint32_t max_cnt_g;
//how many bits one compressed block of rle has
extern uint8_t bits_rle_block_g;
// save the number of bits that were used for compressing the signals
extern uint8_t block_len[SIGNALS][64];

uint32_t read_one_signal(uint8_t* data_in, uint8_t signal_select, int8_t offset);

uint8_t count_consecutive_occurrences(uint8_t start_pos, uint32_t curr_value, uint32_t previous_count);

void rle_compress(uint8_t* dat, bitstream* b_streams_);

void write_digit_and_count_to_output(uint8_t digit, uint32_t count, bitstream* bitstream_o,
                                     uint8_t not_compressed, int8_t signal, int8_t size_pos);

void rle_decompress(bitstream* b_stream, bitstream* b_stream_uncompressed, int8_t sig);
void read_all_signals(uint8_t* data_in, bitstream* b_streams_uncomp_aligned);

#endif
