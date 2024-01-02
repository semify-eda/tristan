#include "rle.h"

#define MAX_CNT 5
#define MAX_CNT_VAL 31

uint8_t bits_rle_block_g;
uint64_t block_len[SIGNALS][64];


/*
 * Function: count_consecutive_occurrences
 * -------------------------
 * Returns the consecutive bit count of same value from the given starting position in the data block.
 */
uint8_t count_consecutive_occurrences(uint8_t start_pos, uint32_t curr_value, uint32_t previous_count) 
{
    volatile uint8_t cnt = 0;

    cnt = cntb(curr_value, start_pos);
    cnt += previous_count;

    return cnt;
}

/*
 * Function: read_all_signals
 * -------------------------
 * Reads the preproccessed data and stores it in a bitstream.
 *
 */
void read_all_signals(uint8_t *data_in, bitstream *b_streams_uncomp_aligned) {
    uint32_t curr_32_bit = 0;
    uint32_t *d_32 = (uint32_t *)data_in;
    uint8_t bit32_blocks = SAMPLES / 32;
    uint8_t bits_of_one_sig_per32 = 32 / SIGNALS;
    uint32_t sigs_tmp[SIGNALS];

    for (uint8_t curr_block = 0; curr_block < bit32_blocks; curr_block++) {
        for (uint32_t curr_read_sig32 = 0; curr_read_sig32 < SIGNALS; curr_read_sig32++) 
        {
            curr_32_bit = d_32[curr_read_sig32 + curr_block * SIGNALS];
            uint32_t mask = 0x1;
            for (uint8_t curr_shift = 0; curr_shift < (32 / SIGNALS); curr_shift++) 
            {
                for (uint8_t curr_sig = 0; curr_sig < SIGNALS; curr_sig++) 
                {
                    // shift right ans store last bit in Signal
                    sigs_tmp[curr_sig] |= ((curr_32_bit & mask) >> (curr_sig + curr_shift * (SIGNALS - 1)));
                    mask = mask << 1;
                }
            }
            signals_uncomp_aligned[curr_read_sig32][curr_block] |= sigs_tmp[curr_read_sig32] << (curr_read_sig32 * bits_of_one_sig_per32);
        }

        for (uint8_t curr_sig = 0; curr_sig < SIGNALS; curr_sig++) 
        {
            b_streams_uncomp_aligned[curr_sig].curr_size += 32;
        }
    }
}

/*
 * Function: read_one_signal
 * -------------------------
 * Returns a 32-bit data block of the original signal to be used for the rle compression.
 */
uint32_t read_one_signal(uint8_t *data_in, uint8_t signal_select, int8_t offset) {
    uint32_t signal = 0;
    uint32_t curr_sig_bit = 0;
    uint32_t curr_read_32bit = 0;

    uint32_t *d_32;
    uint8_t signals_per_32_bit;
    uint8_t num_blocks32_bit = SAMPLES >> 5;

    d_32 = (uint32_t *)data_in;

    if (offset != num_blocks32_bit) {
        signals_per_32_bit = 32 / SIGNALS;
    } else // last bits that are not a integer mutiple of 32 need to be read
    {
        signals_per_32_bit = SAMPLES % 32;
    }

    offset = offset * SIGNALS;

    for (uint8_t curr_block = 0; curr_block < SIGNALS; curr_block++) {
        uint32_t mask = 0b1 << signal_select;
        uint32_t sig_tmp = 0;

        curr_read_32bit = d_32[curr_block + offset];
        for (uint8_t curr_bit = 0; curr_bit < signals_per_32_bit; curr_bit++) {
            curr_sig_bit = curr_read_32bit & mask;
            sig_tmp |= curr_sig_bit >> (signal_select + ((SIGNALS - 1) * curr_bit));
            mask = mask << (SIGNALS);
        }

        signal |= sig_tmp << (signals_per_32_bit * curr_block);
    }

    return signal;
}

/*
 * Function: write_digit_and_count_to_output
 * -------------------------
 * This function prepares a "compressed_block" to be passed to the write function and stored in a bitstream.
 * The compressed block containes the not_compressed flag, count value and bit value.
 * 
 */
void write_digit_and_count_to_output(uint8_t digit, uint32_t count,
                                     bitstream *b_stream, uint8_t not_compressed, 
                                     int8_t signal, int8_t size_pos) {
    uint32_t compressed_block;
    uint8_t num_bits_to_write = bits_rle_block_g;
    compressed_block = digit;
    compressed_block |= count << VALUE_POSITION;
    if (count <= (uint32_t)bits_rle_block_g - 1) {
        num_bits_to_write = 5;
        if (not_compressed) {
            num_bits_to_write = count + 2;

            if (count == 0)
                num_bits_to_write += 1;
        }
    }
    compressed_block |= not_compressed << (num_bits_to_write-1);
    // printf("\nBits to write: %d", num_bits_to_write);
    block_len[signal][size_pos] = num_bits_to_write; // Save the number of bits used for compression
    // printf("\nData to store: 0x%.0x -> NOT_COMP: 0x%.0x CNT_VAL: 0x%.0X BIT: 0x%.0x", compressed_block, not_compressed, count, digit);
    write(b_stream, num_bits_to_write, compressed_block);
}

/*
 * Function: rle_compress
 * -------------------------
 * This function takes the preprocessed signals and performs the data compression.
 * For each signal, the consecutive bits are counted, and it is decided whether the block should 
 * be compressed or left uncompressed. The data is then stored in a bitstream.
 */
void rle_compress(uint8_t *dat, bitstream *b_streams_) {
    // set global variables for rle compression
    bits_rle_block_g = MAX_CNT + ADDITIONAL_BITS;
    uint8_t bit32_per_sig = SAMPLES >> 5;
    uint8_t samples_modulo_32 = SAMPLES % 32;
    uint8_t rounds_bit32_blocks = bit32_per_sig;
    int8_t curr_bit_next = 0;

    if (samples_modulo_32 != 0) {
        rounds_bit32_blocks += 1; // to loop one more round for rest of the bits
    }

    for (uint8_t curr_signal = 0; curr_signal < SIGNALS; curr_signal++) {
        int8_t size_pos = 0; 
        uint8_t previous_digit = 2;
        uint32_t count = 0;
        uint8_t not_compressed = 0;
        uint32_t read_sig_next = read_one_signal(dat, curr_signal, rounds_bit32_blocks - 1);
        // printf("\n\nRead signal: 0x%.0x, Block: %d", read_sig_next, rounds_bit32_blocks - 1);
        puts("\n\nRead signal: "); print(read_sig_next); puts(" Block: "); print(rounds_bit32_blocks - 1);
        int8_t bits_already_stored = 0;
        uint32_t previous_count = 0;
        int8_t block_flag = 0;

        for (int8_t curr_32_bit_block = (rounds_bit32_blocks - 1); curr_32_bit_block >= 0; curr_32_bit_block--) 
        {         
            uint32_t read_sig = read_sig_next; 
            if (curr_32_bit_block != 0) {
                read_sig_next = read_one_signal(dat, curr_signal, curr_32_bit_block - 1);
            }
            
            
            // Only used for debugging
            if (curr_32_bit_block == 0) {
                //printf("\n\nRead signal: 0x%.0x, Block: %d", read_sig_next, curr_32_bit_block);
                puts("\n\nRead signal: "); print(read_sig_next); puts(" Block: "); print(curr_32_bit_block);
            }
            

            int8_t curr_bit = 31 - bits_already_stored;
            bits_already_stored = 0; // reset it to zero again if once subtracted from former uncompressed block store

            if (curr_32_bit_block == bit32_per_sig) { // process the few bits that are not integer multiple of 32
                curr_bit = samples_modulo_32 - 1;
            }

            while (curr_bit >= 0) {
                uint8_t curr_digit = (read_sig & (0x1U << curr_bit)) >> curr_bit; 

                // If we finished processing the first block and the bit value of the second block is different, 
                // store the last count value in the bitstream.
                if (block_flag != 0 && previous_digit != curr_digit) 
                {
                    // printf("\nStore the last value of the first block: 0x%.0x", count);

                    write_digit_and_count_to_output(previous_digit, count, &(b_streams_[curr_signal]),
                                                    not_compressed, curr_signal, size_pos); 
                    size_pos += 1;
                    block_flag = 0;
                    count = 0;
                    not_compressed = 0;
                }
                
                previous_count = count; 

                // If there's a remainder from the first block, and the bit value of the second block is the same,
                // add the count value to the new block and continue counting the bits.
                if (previous_count != 0 || block_flag) 
                {
                    block_flag = 0;
                    not_compressed = 0;
                    previous_count += 1;    // +1 because we start counting from 0
                    // printf("\nAdd previous count value: 0x%.0x to next block", previous_count);     
                }
                
                count = count_consecutive_occurrences(curr_bit, read_sig, previous_count);
                // printf("\nStart position: %d\tConsecutive bits count: %d", curr_bit, count);
                puts("\nStart position: "); print(curr_bit); puts("\tConsecutive bits count: "); print(count);
                
                if (count == (uint32_t)MAX_CNT_VAL) {
                    curr_bit_next = -1;  
                } else
                    curr_bit_next = curr_bit - (count + 1) + previous_count;  

                if (count < ((uint32_t)bits_rle_block_g - 1)) {
                    not_compressed = 1;
                }

                if ((count != (uint32_t)MAX_CNT_VAL) && (curr_bit_next == -1) && ((curr_32_bit_block != 0))) 
                {
                    block_flag = 1;
                    previous_digit = curr_digit; 
                    break;
                }

                uint8_t all_bits = 0;
                if (not_compressed) 
                {
                    // printf("\nUncompressed signal bits: 0x%.0x", count);
                    if ((curr_bit == 0) && curr_32_bit_block == 0)    
                        all_bits = 1;
                }

                write_digit_and_count_to_output(curr_digit, count, &(b_streams_[curr_signal]), 
                                                not_compressed, curr_signal, size_pos);
                 
                curr_bit = curr_bit_next;
                if (all_bits) curr_bit = -1;
                count = 0;
                previous_digit = curr_digit;
                not_compressed = 0;
                size_pos += 1;
            }
        }
        // printf("Compressed size: %d for signal %d\n", b_streams_[curr_signal].curr_size, curr_signal);
    }
}

/*
 * Function: rle_decompress
 * -------------------------
 * This function reads the compressed data stored in the bitstream. The length of the block of that is read 
 * is defined by the block length, stored in the block_len array.
 * The data is then stored in a bitstream.
 */
void rle_decompress(bitstream *b_stream, bitstream *b_stream_uncompressed, int8_t sig) {
    uint32_t block_size = b_stream->curr_size;
    uint32_t curr_block = 0;

    for (uint32_t b_slice = 0; b_slice < block_size; b_slice++) {
        if (block_len[sig][b_slice] == 0){
            return;
        }
        // uint32_t not_compressed_mask = 0x1 << (block_len[sig][b_slice] - 1); // Used only for debugging
        uint32_t counter_mask = 0b10;

        uint32_t value_to_store = 0;
        for (uint8_t curr_bit = 1; curr_bit < (block_len[sig][b_slice] - 2); curr_bit++) {
            counter_mask |= counter_mask << 1;
        }

        uint32_t curr_rle_block = read(b_stream, curr_block, block_len[sig][b_slice]);
        uint32_t count = (curr_rle_block & counter_mask) >> 1;
        value_to_store = curr_rle_block & 0b1;

        /*
        // Used for debugging only
        if (curr_rle_block & not_compressed_mask) {
            printf("Uncompressed data: CNT_VAL: %d\tBIT_VAL: %d\n", count, value_to_store);
        } else {
            printf("Compressed data: CNT_VAL: %d\tBIT_VAL: %d\n", count, value_to_store);
        }
        */

        for (uint8_t curr_bit = 0; curr_bit < count; curr_bit++) {
            value_to_store |= value_to_store << 1; // Could add exception for signals that are all 1's or 0's to speed up the process
        }
        write(b_stream_uncompressed, (count + 1), value_to_store);
        
        curr_block += block_len[sig][b_slice];
    }
}
