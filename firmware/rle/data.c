#include "data.h"

uint8_t rle_signals[SIGNALS][EXPECTED_COMPRESSED_DATA_SIZE];
uint8_t sig_uncomp[SIGNALS][(SAMPLES >> 3) + 1];
uint8_t signals_uncomp_aligned[SIGNALS][(SAMPLES >> 3) + 1];
uint8_t test_aligned_sigs[SIGNALS][(SAMPLES >> 3) + 1];

uint32_t read(bitstream* b_stream, uint32_t start_bit, uint8_t num_bits_to_read) 
{
    uint32_t read_block = 0;
    uint32_t end_bit = start_bit + num_bits_to_read;
    uint8_t start_byte = start_bit >> 3;        
    uint8_t bits_not_read = num_bits_to_read;

    uint8_t left_bytes_of_block = num_bits_to_read >> 3;

    uint8_t mask = 1;
    uint8_t bits_last_block = start_bit % 8;
    uint8_t bits_curr_block = 8 - bits_last_block;
    for (uint8_t curr_bit = 1; curr_bit < bits_curr_block; curr_bit++) {
        mask |= mask << 1;
    }

    uint8_t read_byte = b_stream->d_out[start_byte];   
    uint8_t byte_offset = start_byte;
    if (start_bit % 8 != 0) {
        if (bits_curr_block >= num_bits_to_read) {
            bits_not_read = 0;
            left_bytes_of_block = 0;
            uint8_t bits_not_occupied_by_curr_block = bits_curr_block - num_bits_to_read;
            mask = mask >> bits_not_occupied_by_curr_block;
            read_block = (read_byte >> bits_not_occupied_by_curr_block) & mask;
        } else {
            read_block = read_byte & mask;
            bits_not_read = num_bits_to_read - bits_curr_block; 
            read_block = read_block << bits_not_read;   
            left_bytes_of_block = (bits_not_read) >> 3;
            byte_offset += 1;
        }
    }

    for (uint8_t curr_byte = 0; curr_byte < left_bytes_of_block; curr_byte++) 
    {
        read_byte = b_stream->d_out[curr_byte + byte_offset];
        bits_not_read -= 8;
        read_block |= read_byte << ((left_bytes_of_block - curr_byte - 1) * 8 + bits_not_read);
    }

    if (bits_not_read != 0) {
        read_byte = b_stream->d_out[end_bit >> 3];
        read_byte = read_byte >> (8 - bits_not_read);
        read_block |= read_byte;
    }
    // printf("Block Read: 0x%.0x\t", read_block);
    return read_block;
}

// TODO this is the working implementation
void write_data_in_blocks(uint8_t *dest, bitstream *source_bs, uint8_t reverse_bits) 
{
    // data neds to be written in reversed order because it was compressed that
    // way to prevent bit reversal

    // uint32_t* d_32 = (uint32_t*)(d_8 + (data_size_mod_32 >> 3));
    uint32_t *d_32 = (uint32_t *)dest;
    // TODO: Let pre-processor calculate this
    uint32_t n32_over_signals = 32 / SIGNALS;
    uint8_t data_size_over_32 = DATA_SIZE >> 5;
    uint32_t curr_sample_to_read;

    for (uint8_t curr_bit32_offset = 0; curr_bit32_offset < data_size_over_32; curr_bit32_offset++) 
    {
        d_32[curr_bit32_offset] = 0; // TODO: check if needed set zero, if dest reused is is needed
        // the following for loops store 32bit of all Signals
        for (uint8_t curr_sample = 0; curr_sample < n32_over_signals; curr_sample++) 
        {
            for (uint8_t curr_bstream = 0; curr_bstream < SIGNALS; curr_bstream++) 
            {
                // read form highest addr to lowest addr out of bitstreams
                // because stored inversed to avoid having to do bit reversal
                if (reverse_bits)
                    curr_sample_to_read = SAMPLES - curr_sample - 1 -
                                          curr_bit32_offset * n32_over_signals;
                else
                    curr_sample_to_read = curr_sample + curr_bit32_offset * n32_over_signals;

                d_32[curr_bit32_offset] |= read(&(source_bs[curr_bstream]), curr_sample_to_read, 1) << (curr_sample * SIGNALS + curr_bstream);
            }
        }
    }

    uint8_t data_size_mod_32 = DATA_SIZE % 32;
    if (data_size_mod_32) 
    {
        uint8_t *d_8 = (uint8_t *)(d_32 + data_size_over_32);
        uint32_t n8_over_signals = 8 / SIGNALS; // how many time have the signals to be stored to get 8 bit

        for (uint8_t curr_bit8_offset = 0; curr_bit8_offset < (data_size_mod_32 >> 3); curr_bit8_offset++) 
        {
            d_8[curr_bit8_offset] = 0; // TODO: check if needed set zero, if dest reused is is needed
            // the following for loops store 8bit of all Signals
            for (uint8_t curr_sample = 0; curr_sample < n8_over_signals; curr_sample++) 
            {
                for (uint8_t curr_bstream = 0; curr_bstream < SIGNALS; curr_bstream++) 
                {
                    // read form highest addr to lowest addr out of bitstreams because stored inversed to
                    //  avoid having to do bit reversal
                    if (reverse_bits)
                        curr_sample_to_read =
                            (SAMPLES % 32) - curr_sample - 1 - curr_bit8_offset * n8_over_signals;
                    else
                        curr_sample_to_read =
                            (SAMPLES % 32) + curr_bit8_offset * n8_over_signals;

                    d_8[curr_bit8_offset] |=
                        read(&(source_bs[curr_bstream]), curr_sample_to_read, 1) << (curr_sample * SIGNALS + curr_bstream);
                }
            }
        }
    }
}

uint8_t store_in_not_byte_aligned_output(bitstream *b_stream, uint8_t number_of_bits, uint32_t value_to_store, uint8_t unaligned_bits) 
{
    uint32_t offset = (b_stream->curr_size - unaligned_bits) >> 3;
    uint8_t free_bits = 8 - unaligned_bits;
    uint8_t byte_after_change;
    uint8_t stored_bits;

    if (free_bits >= (number_of_bits)) // all bits are stored in current byte
    {
        byte_after_change = value_to_store << (free_bits - (number_of_bits));
        stored_bits = number_of_bits;
    } else {
        byte_after_change = value_to_store >> (number_of_bits - free_bits);
        stored_bits = free_bits;
    }

    b_stream->d_out[offset] |= byte_after_change;
    b_stream->curr_size += stored_bits;
    // printf("\nStored unaligned bits: 0x%.0x", b_stream->d_out[offset]);

    return number_of_bits - stored_bits;
}

void write(bitstream *b_stream, uint8_t number_of_bits, uint32_t value_to_store) 
{
    // assert(number_of_bits <= 32 && "can only write 32 bit at a time");
    uint8_t not_bytealigned_bits = b_stream->curr_size % 8;
    uint8_t bits_to_store = number_of_bits;

    if (not_bytealigned_bits != 0) {
        bits_to_store = store_in_not_byte_aligned_output(b_stream, number_of_bits, value_to_store, not_bytealigned_bits);
    }

    uint8_t bytes_to_store = (bits_to_store) >> 3;
    uint32_t curr_byte_size = b_stream->curr_size >> 3;
    uint8_t shift_right = bits_to_store;
    for (uint8_t curr_byte = 0; curr_byte < bytes_to_store; curr_byte++) 
    {
        shift_right -= 8;
        b_stream->d_out[curr_byte + curr_byte_size] = (uint8_t)(value_to_store >> (shift_right));
        // printf("\nStored aligned byte  = 0x%.0x\n", b_stream->d_out[curr_byte + curr_byte_size]);
        b_stream->curr_size += 8; // 8bit were written to output
    }

    curr_byte_size = b_stream->curr_size >> 3;
    uint8_t remainder_bits = bits_to_store % 8;
    if (remainder_bits != 0) 
    {
        // Store compressed bits unaligned, MSB first 
        b_stream->d_out[curr_byte_size] = (uint8_t)(value_to_store << (8 - remainder_bits));
        // printf("\nStored aligned bits = 0x%.0x | remainder was 0x%.0x\n", b_stream->d_out[curr_byte_size], remainder_bits);
        
        // the rest of the bits are stored
        b_stream->curr_size += remainder_bits;
    }/* else {
        printf("\nNo remainder\n");    
    }
    */
}

uint8_t test_comp_equal_uncomp(uint8_t *data, uint8_t *data_after_decomp) {
    // uint32_t* d_32_before_comp_decomp = (uint32_t*)data;
    // uint32_t* d_32_after_comp_decompr = (uint32_t*)data_after_decomp;
    uint8_t equal = 1;
    uint8_t data_size_over_32 = DATA_SIZE >> 5;

    for (uint32_t curr_block32 = 0; curr_block32 < data_size_over_32 * 4; curr_block32++) 
    {
        if (data[curr_block32] != data_after_decomp[curr_block32]) {
            equal = 0;
        }
        puts("Test block:  ");print(curr_block32);putc('\n');
        puts("Data before compression:  ");print(data[curr_block32]);putc('\n');
        puts("Data after compression:  ");print(data_after_decomp[curr_block32]);putc('\n');
    }

    uint8_t data_size_mod_32 = DATA_SIZE % 32;
    if (data_size_mod_32) // only do this if data is no integer multiple of 8
    {
        uint8_t *d_8_before_comp_decomp = (data + data_size_over_32 * 4);
        uint8_t *d_8_after_comp_decompr = (data_after_decomp + data_size_over_32 * 4);
        // read last bytes of data
        for (uint32_t curr_block8 = 0; curr_block8 < ((data_size_mod_32) >> 3); curr_block8++) 
        {
            if (d_8_before_comp_decomp[curr_block8] != d_8_after_comp_decompr[curr_block8])
                equal = 0;
        }
    }
    return equal;
}

void init_global_bitstreams(bitstream *b_streams, bitstream *b_streams_uncomp, bitstream *b_streams_uncomp_aligned) 
{
    for (uint8_t curr_b_stream = 0; curr_b_stream < SIGNALS; curr_b_stream++) 
    {
        b_streams[curr_b_stream].d_out = rle_signals[curr_b_stream];
        b_streams[curr_b_stream].size = DATA_SIZE;
        b_streams[curr_b_stream].curr_size = 0;

        b_streams_uncomp[curr_b_stream].d_out = sig_uncomp[curr_b_stream];
        b_streams_uncomp[curr_b_stream].size = (SAMPLES >> 3) + (SAMPLES % 8);
        b_streams_uncomp[curr_b_stream].curr_size = 0;

        b_streams_uncomp_aligned[curr_b_stream].d_out = signals_uncomp_aligned[curr_b_stream];
        b_streams_uncomp_aligned[curr_b_stream].size = (SAMPLES >> 3) + (SAMPLES % 8);
        b_streams_uncomp_aligned[curr_b_stream].curr_size = 0;
    }
}
