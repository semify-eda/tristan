#include "rle.h"

#define MAX_CNT 5

uint8_t bits_rle_block_g;

//#ifdef CUSTOM_INSTRUCTIONS

uint8_t count_consecutive_accurences(uint8_t search_for_1, uint8_t start_pos,
                                     uint32_t curr_value,
                                     uint32_t previous_count) {
    (void)search_for_1; // TODO

    volatile uint8_t cnt = 0;

    /*__asm__ volatile ("cntb %0, %1, %2 \n"
                    : "=r"(cnt)
                    : "r"(curr_value), "r"(start_pos)
                    :
    );*/

    cnt = cntb(curr_value, start_pos);

    cnt += previous_count;

    if (cnt > MAX_CNT)
        cnt = MAX_CNT;

    return cnt;
}

/*#else

uint8_t count_consecutive_accurences(uint8_t search_for_1, uint8_t start_pos,
                                     uint32_t curr_value,
                                     uint32_t previous_count) {
    uint32_t compare_value = 0b10000000000000000000000000000000U;
    compare_value = (compare_value >> (31 - start_pos));

    uint8_t cnt = previous_count;

    if (search_for_1) {
        while ((compare_value & curr_value) != 0) {
            compare_value = (compare_value >> 1);
            cnt++;

            if (cnt == MAX_CNT)
                break;
        }
    } else {
        while ((compare_value & curr_value) == 0) {
            compare_value = compare_value >> 1;
            cnt++;

            if (compare_value == 0 || cnt == MAX_CNT)
                break;
        }
    }

    // PRINT("cnt = %u\n", cnt);

    return cnt;
}
#endif*/

void read_all_signals(uint8_t *data_in, bitstream *b_streams_uncomp_aligned) {
    uint32_t curr_32_bit = 0;

    uint32_t *d_32 = (uint32_t *)data_in;
    uint8_t bit32_blocks = SAMPLES / 32;
    uint8_t bits_of_one_sig_per32 = 32 / SIGNALS;

    uint32_t sigs_tmp[SIGNALS];

    for (uint8_t curr_block = 0; curr_block < bit32_blocks; curr_block++) {
        for (uint32_t curr_read_sig32 = 0; curr_read_sig32 < SIGNALS;
             curr_read_sig32++) {
            curr_32_bit = d_32[curr_read_sig32 + curr_block * SIGNALS];
            uint32_t mask = 0x1;
            for (uint8_t curr_shift = 0; curr_shift < (32 / SIGNALS);
                 curr_shift++) {

                for (uint8_t curr_sig = 0; curr_sig < SIGNALS; curr_sig++) {
                    // shift right ans store last bit in Signal
                    sigs_tmp[curr_sig] |=
                        ((curr_32_bit & mask) >>
                         (curr_sig + curr_shift * (SIGNALS - 1)));
                    mask = mask << 1;
                }
            }

            signals_uncomp_aligned[curr_read_sig32][curr_block] |=
                sigs_tmp[curr_read_sig32]
                << (curr_read_sig32 * bits_of_one_sig_per32);
        }

        for (uint8_t curr_sig = 0; curr_sig < SIGNALS; curr_sig++) {
            b_streams_uncomp_aligned[curr_sig].curr_size += 32;
        }
    }

    // print_bitstream(&b_streams_uncomp_aligned[0]);
}

uint32_t read_one_signal(uint8_t *data_in, uint8_t signal_select,
                         int8_t offset) {
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
            sig_tmp |=
                curr_sig_bit >> (signal_select + ((SIGNALS - 1) * curr_bit));

            mask = mask << (SIGNALS);
        }

        signal |= sig_tmp << (signals_per_32_bit * curr_block);
    }

    // print_bits(signal);

    return signal;
}

void write_digit_and_count_to_output(uint8_t digit, uint32_t count,
                                     bitstream *b_stream,
                                     uint8_t not_compressed, int8_t curr_bit,
                                     int8_t curr_32_bit_block) {
    uint32_t compressed_block;
    uint8_t num_bits_to_write = bits_rle_block_g;
    if (not_compressed) {
        compressed_block = count;

        // in case we are at the end of the signalblock and need
        // less bits to store than a rle_block_has
        if (curr_bit + 1 < bits_rle_block_g && curr_32_bit_block == 0)
            num_bits_to_write = curr_bit + 2;

    } else {
        compressed_block = digit; // block is zero or one now
        compressed_block = compressed_block | (count << VALUE_POSITION);
    }

    compressed_block |= not_compressed << (num_bits_to_write - 1);

    write(b_stream, num_bits_to_write, compressed_block);
}

uint32_t get_uncompressed_signal_bits(uint32_t read_sig, uint32_t count,
                                      uint8_t digit, uint8_t curr_bit,
                                      int8_t curr_32_bit_block,
                                      uint32_t read_sig_next,
                                      int8_t *bits_already_stored,
                                      uint32_t previous_count) {
    uint8_t mask = 0x1;
    uint8_t num_bits_to_get = bits_rle_block_g - 1;
    uint8_t need_bits_from_next_sig = 0;
    curr_bit += 1; // to start counting form 1

    if (curr_bit < bits_rle_block_g) {
        num_bits_to_get = curr_bit;

        if (curr_32_bit_block != 0)
            need_bits_from_next_sig = 1;
    }

    uint32_t block_to_store = digit << (num_bits_to_get - count);
    for (uint8_t curr_digit = 1; curr_digit < count; curr_digit++) {
        block_to_store |= block_to_store << 1;
    }

    uint8_t free_bits = num_bits_to_get - count;
    for (uint8_t curr_digit = 1; curr_digit < free_bits; curr_digit++) {
        mask |= mask << 1;
    }

    // previous count add to not shift to far rigth because count couled also be
    // from last 32 bit signal block
    block_to_store |=
        (read_sig >> (curr_bit - num_bits_to_get + previous_count)) & mask;

    if (need_bits_from_next_sig) {
        // get most sicinificant bits from next 32 bit block of signal
        num_bits_to_get = bits_rle_block_g - 1 - num_bits_to_get;
        block_to_store = block_to_store << num_bits_to_get;
        block_to_store |= read_sig_next >> (32 - num_bits_to_get);
        *bits_already_stored = num_bits_to_get;
    }

    return block_to_store;
}

void rle_compress(uint8_t *dat, bitstream *b_streams_) {
    // set global variables for rle compression
    bits_rle_block_g = MAX_CNT + ADDITIONAL_BITS;

    uint8_t bit32_per_sig = SAMPLES >> 5;
    uint8_t samples_modulo_32 = SAMPLES % 32;
    uint8_t rounds_bit32_blocks = bit32_per_sig;

    if (samples_modulo_32 != 0)
        rounds_bit32_blocks += 1; // to loop one more round for rest of the bits

    // PRINT("starting to compress %u blocks of 32 bit \n", bit32_per_sig);

    for (uint8_t curr_signal = 0; curr_signal < SIGNALS; curr_signal++) {
        uint8_t previous_digit = 2;
        uint32_t count = 0;
        uint8_t not_compressed = 0;
        // read first block of data
        uint32_t read_sig_next =
            read_one_signal(dat, curr_signal, rounds_bit32_blocks - 1);
        int8_t bits_already_stored = 0;
        uint32_t previous_count = 0;

        for (int8_t curr_32_bit_block = (rounds_bit32_blocks - 1);
             curr_32_bit_block >= 0; curr_32_bit_block--) {

            uint32_t read_sig = read_sig_next;
            if (curr_32_bit_block != 0)
                read_sig_next =
                    read_one_signal(dat, curr_signal, curr_32_bit_block - 1);

            int8_t curr_bit = 31 - bits_already_stored;
            bits_already_stored =
                0; // restet it to zero agien if once substracted from former
                   // uncompressed block store

            if (curr_32_bit_block ==
                bit32_per_sig) // processess the few bits that are not integer
                               // mutliple of 32
                curr_bit = samples_modulo_32 - 1;

            while (curr_bit >= 0) {
                uint8_t curr_digit =
                    (read_sig & (0x1U << curr_bit)) >> curr_bit;

                if (count != 0 &&
                    previous_digit !=
                        curr_digit) { // if 32 bit done and next 32 bit block is
                                      // checked and bit is not the same
                    if (not_compressed) { // maybe last 32bit block should not
                                          // be encoded
                        curr_bit -= bits_rle_block_g - 1 - count;
                        count = get_uncompressed_signal_bits(
                            read_sig, count, previous_digit, 0,
                            curr_32_bit_block, read_sig_next,
                            &bits_already_stored, previous_count);
                    }

                    write_digit_and_count_to_output(
                        previous_digit, count, &(b_streams_[curr_signal]),
                        not_compressed, curr_bit, curr_32_bit_block);
                    count = 0;
                    not_compressed = 0;
                }
                previous_count = count; // uint32_t
                count = count_consecutive_accurences(curr_digit, curr_bit,
                                                     read_sig, count);
                int8_t curr_bit_next = curr_bit - count + previous_count;

                if (count < bits_rle_block_g &&
                    ((curr_bit_next != -1) || (curr_32_bit_block == 0)))
                    not_compressed = 1;

                if ((count != MAX_CNT) && (curr_bit_next == -1) &&
                    ((curr_32_bit_block != 0))) {
                    previous_digit = curr_digit;
                    break;
                }

                uint8_t all_bits = 0;
                if (not_compressed) {
                    count = get_uncompressed_signal_bits(
                        read_sig, count, curr_digit, curr_bit,
                        curr_32_bit_block, read_sig_next, &bits_already_stored,
                        previous_count);
                    if ((curr_bit < bits_rle_block_g - 1) &&
                        curr_32_bit_block == 0)
                        all_bits = 1; // to store end of bits not
                                      // rle_block_length_alligned
                    else
                        curr_bit_next =
                            curr_bit - bits_rle_block_g + 1 + previous_count;
                }

                write_digit_and_count_to_output(
                    curr_digit, count, &(b_streams_[curr_signal]),
                    not_compressed, curr_bit, curr_32_bit_block);

                curr_bit = curr_bit_next;

                if (all_bits)
                    curr_bit = -1;

                count = 0;
                previous_digit = curr_digit;
                not_compressed = 0;
            }
        }
    }
}

void rle_decompress(bitstream *b_stream, bitstream *b_stream_uncompressed) {
    uint32_t blocks_to_read = b_stream->curr_size / bits_rle_block_g;
    uint32_t not_compressed_mask = 0x1 << (bits_rle_block_g - 1);
    uint32_t counter_mask = 0b10;

    uint32_t value_to_store = 0;
    for (uint8_t curr_bit = 1; curr_bit < (bits_rle_block_g - 2); curr_bit++) {
        counter_mask |= counter_mask << 1;
    }
    // selects only the bits of uncompressed block to store
    uint32_t uncompressed_bits_mask = counter_mask | 0x1;

    for (uint32_t curr_block = 0; curr_block < blocks_to_read; curr_block++) {
        uint32_t curr_rle_block =
            read(b_stream, curr_block * bits_rle_block_g, bits_rle_block_g);
        if (curr_rle_block & not_compressed_mask) {
            value_to_store = curr_rle_block & uncompressed_bits_mask;
            write(b_stream_uncompressed, bits_rle_block_g - 1, value_to_store);
        } else {
            uint32_t count = (curr_rle_block & counter_mask) >> 1;
            value_to_store = curr_rle_block & 0b1;

            // only 32bit can be stored at a time
            for (uint8_t curr_32_bit = 0; curr_32_bit < (count >> 5);
                 curr_32_bit++) {
                if (value_to_store)
                    write(b_stream_uncompressed, 32, 0xFFFFFFFF);
                else
                    write(b_stream_uncompressed, 32, 0x0);

                count -= 32;
            }

            if (value_to_store == 1) {
                for (uint8_t curr_bit = 1; curr_bit < count; curr_bit++) {
                    value_to_store |= value_to_store << 1;
                }
            }
            // if value is 0 we only need to store count many zeros
            write(b_stream_uncompressed, count, value_to_store);
        }
    }
    // print_bitstream(b_stream);
    //  store last uncompressed bits if not alligned with an interger
    //  multiple of blocklength
    uint8_t remainder_bits = b_stream->curr_size % bits_rle_block_g;
    if (remainder_bits != 0) {
        // uint8_t last_byte = b_stream->curr_size / bits_rle_block_g;
        uint32_t mask_remainder = (1<<(remainder_bits - 1)) - 1;

        value_to_store = read(b_stream, b_stream->curr_size - remainder_bits,
                              remainder_bits) &
                         mask_remainder;
        write(b_stream_uncompressed, remainder_bits - 1, value_to_store);
    }
    // print_bitstream(b_stream_uncompressed);
}
