#ifndef data_h
#define data_h

#include "../instr.h"
#include "../util.h"

#define SAMPLES 64
#define SIGNALS 4
#define DATA_SIZE SAMPLES*SIGNALS
#define DATA_BYTE_SIZE DATA_SIZE>>3
// needed to allocate data at compile time
#define EXPECTED_COMPRESSED_DATA_SIZE 100

#define SYNC_LOW_LEN 8
#define DAC_DATA_LEN 32

typedef struct bitstream
{
  uint8_t* d_out;
  uint32_t size; // maximum size in bytes
  uint32_t curr_size; //in bits
} bitstream;

// compressed rle signals
extern uint8_t rle_signals[SIGNALS][EXPECTED_COMPRESSED_DATA_SIZE];

// signal after using decompress function on compressed signals
extern uint8_t sig_uncomp[SIGNALS][(SAMPLES>>3) + 1];

// bitstreams for the uncompressed signals after aligning the bits
// needs less computations than read every signal alone. all signals
// are read at once and stored in this bitstream
extern uint8_t signals_uncomp_aligned[SIGNALS][(SAMPLES>>3) + 1];

extern uint8_t test_aligned_sigs[SIGNALS][(SAMPLES>>3) + 1];

void init_global_bitstreams(bitstream* b_streams, bitstream* b_streams_uncomp, bitstream* b_streams_uncomp_aligned);

uint8_t store_in_not_byte_aligned_output(bitstream* b_stream, uint8_t number_of_bits, uint32_t value_to_store, uint8_t unaligned_bits);

void write(bitstream* b_stream, uint8_t number_of_bits, uint32_t value_to_store);

uint32_t read(bitstream* b_stream, uint32_t start_bit, uint8_t num_bits_to_read);

void write_data_in_blocks(uint8_t* dest, bitstream* source_bs, uint8_t resverse_bits);

uint8_t test_comp_equal_uncomp(uint8_t* data, uint8_t* data_after_decomp);

#endif
