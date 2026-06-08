/** rle.h
 *
 * Public interface for the run-length-encoded bit-stream decoder.
 */

#ifndef RLE_H
#define RLE_H

#include <stdint.h>
#include <stdbool.h>

#define GET_STREAM_BIT(stream, idx) (((stream->data[(idx)/8]) >> (((idx) % 8))) & 0x1)
#define COUNTER_SIZE 5
#define PACKET_SIZE  (1 << COUNTER_SIZE)
#define BLOCK_SIZE   128

/**
 * Binary stream of data.
 *   data        : raw bytes
 *   size        : byte length
 *   s_bits      : bit length (size * 8, unless byte-padded)
 *   num_signals : number of interleaved signals packed into the stream
 */
typedef struct stream_t
{
    volatile uint8_t* data;
    uint32_t          size;
    uint32_t          s_bits;
    uint32_t          num_signals;
} stream_t;

/**
 * @brief Decode an encoded stream.  Produces at most BLOCK_SIZE decoded bits
 *        per call; halts earlier if the encoded stream is exhausted.
 *
 * @return 0  OK
 * @return 1  estream too small
 * @return 2  encode_start_idx == NULL
 * @return 3  decoder hit ERROR state
 * @return 4  decoded stream not byte-aligned
 */
int decode_stream(const volatile stream_t* restrict const estream, stream_t* dstream, uint32_t* encode_start_idx);

/**
 * @brief Read up to 32 bits from a stream.
 * @return  the number of bits actually read
 */
uint8_t get_stream_bits(const volatile stream_t* const restrict stream, uint32_t* restrict read, const uint32_t sidx, uint8_t num_bits);

#ifdef CUSTOM_EXT
/** Hardware-accelerated read.  Loads num_bits into the ISE shadow register. */
uint8_t xget_stream_bits(const volatile stream_t* const restrict stream, const uint32_t sidx, uint8_t num_bits);
#endif

/**
 * @brief Write up to 32 bits to a stream.  Grows the stream's size / s_bits
 *        if the write extends past the current end.
 */
void set_stream_bits(stream_t* const restrict stream, uint32_t write, const uint32_t sidx, uint8_t num_bits);

#ifdef CUSTOM_EXT
/** Hardware-accelerated write.  Pulls from the ISE shadow register. */
void xset_stream_bits(stream_t* const restrict stream, const uint32_t sidx, uint8_t num_bits);
#endif

#endif
