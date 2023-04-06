#ifndef RLE_H
#define RLE_H

#include <stdint.h>

#ifdef DEBUG
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#endif

#include "data.h"
#include "instr.h"

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

uint32_t read_one_signal(uint8_t* data_in, uint8_t signal_select, int8_t offset);

uint8_t count_consecutive_accurences(uint8_t search_for_1, uint8_t start_pos,
                                     uint32_t curr_value, uint32_t previous_count);

void rle_compress(uint8_t* dat, bitstream* b_streams_);

void write_digit_and_count_to_output(uint8_t digit, uint32_t count, bitstream* bitstream_o,
                                     uint8_t not_compressed, int8_t curr_bit,
                                     int8_t curr_32_bit_block);

uint32_t get_uncompressed_signal_bits(uint32_t read_sig, uint32_t count, uint8_t digit,
                                      uint8_t curr_bit, int8_t curr_32_bit_block,
                                      uint32_t read_sig_next, int8_t* bits_already_stored,
                                      uint32_t previous_count);

void rle_decompress(bitstream* b_stream, bitstream* b_stream_uncompressed);

void read_all_signals(uint8_t* data_in, bitstream* b_streams_uncomp_aligned);

#endif
