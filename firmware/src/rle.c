/** rle.c
 *
 * Run-length-encoded bit-stream decoder.
 *
 * Two code paths share the same state machine:
 *   - base build  (no -DCUSTOM_EXT) — pure-software inner helpers
 *   - ise  build  (-DCUSTOM_EXT)    — inner helpers emit custom-opcode
 *                                     instructions (RMLD / RMCS / RMXR / RMXS)
 *                                     defined in include/instr.h, executed by
 *                                     the Tristan ISE co-processor.
 */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../include/rle.h"

#ifdef CUSTOM_EXT
#include "../include/instr.h"
#endif

/************************************* Private Declarations *************************************/

static bool end_of_stream(const uint32_t* const bit_idx, const volatile stream_t* const estream);

/* State machine states */
typedef enum enum_decode_states_t {
  DETERMINE_COMPRESSION = 0,
  READ_COUNTER_VALUE    = 1,
  COPY_SEGMENT          = 2,
  EXTEND_VALUE          = 3,
  HALT                  = 4,
  ERROR                 = 5
} enum_decode_states_t;

/* State function prototypes */
static enum_decode_states_t determine_compression(const volatile stream_t* const restrict estream, stream_t* const dstream, uint32_t* const bit_idx);
static enum_decode_states_t read_counter_value   (const volatile stream_t* const restrict estream, stream_t* const dstream, uint32_t* const bit_idx);
static enum_decode_states_t copy_segment         (const volatile stream_t* const restrict estream, stream_t* const dstream, uint32_t* const bit_idx);
static enum_decode_states_t extend_value         (const volatile stream_t* const restrict estream, stream_t* const dstream, uint32_t* const bit_idx);

/* State machine table entry */
typedef struct decode_state_node_t {
  enum_decode_states_t (*state_function)(const volatile stream_t* const restrict estream, stream_t* const dstream, uint32_t* const bit_idx);
} decode_state_node_t;

/* Mealy-machine signals shared by read_counter_value -> {copy_segment, extend_value} */
static bool     compressed;
static uint32_t count_value;

/*************************************************************************************************/

/**
 * @brief Decode an encoded stream.  Runs the state machine until either the
 *        encoded data is exhausted (HALT) or BLOCK_SIZE decoded bits have
 *        been produced.
 *
 * @param estream            encoded input stream
 * @param dstream            output decoded stream
 * @param encode_start_idx   starting bit index in estream; updated on exit
 *                           to the index where decoding stopped
 *
 * @return 0  OK
 * @return 1  estream too small
 * @return 2  encode_start_idx == NULL
 * @return 3  decoder hit ERROR state
 * @return 4  decoded stream not byte-aligned
 */
int decode_stream(const volatile stream_t* restrict const estream, stream_t* dstream, uint32_t* encode_start_idx)
{
    if (estream->size <= 1)       return 1;
    if (encode_start_idx == NULL) return 2;

    decode_state_node_t decode_state_machine[] = {
        {determine_compression},
        {read_counter_value   },
        {copy_segment         },
        {extend_value         }
    };

    enum_decode_states_t cur_state = DETERMINE_COMPRESSION;
    uint32_t bit_idx = *encode_start_idx;

    while (cur_state != HALT && cur_state != ERROR && (dstream->s_bits != BLOCK_SIZE))
    {
        cur_state = (*decode_state_machine[cur_state].state_function)(estream, dstream, &bit_idx);
    }

    dstream->num_signals = estream->num_signals;
    *encode_start_idx    = bit_idx;

    if (cur_state == ERROR)        return 3;
    if (dstream->s_bits % 8 != 0)  return 4;
    return 0;
}

/**
 * @brief Read up to 32 bits from a stream.  Crosses byte/word boundaries.
 *        Reads stop at the end of the stream regardless of num_bits.
 *
 * @param stream    input stream
 * @param read      output: the packed bits
 * @param sidx      starting bit index
 * @param num_bits  number of bits to read (max 32)
 * @return          actual number of bits read
 */
uint8_t get_stream_bits(const volatile stream_t* const restrict stream, uint32_t* restrict read, const uint32_t sidx, uint8_t num_bits)
{
    if (num_bits == 0)  return 0;
    if (num_bits > 32)  num_bits = 32;

    if (sidx + num_bits > stream->s_bits - 1)
    {
        num_bits = stream->s_bits - sidx;
    }

    uint32_t eidx     = sidx + num_bits - 1;
    uint8_t  nibble;
    uint8_t  mask;
    uint8_t  bmask;
    uint8_t  emask;
    uint8_t  overflow = 0x00;

    *read = 0x00;

    uint32_t byte_eidx = eidx / 8;
    uint32_t byte_sidx = sidx / 8;

    for (uint32_t idx = byte_eidx;; idx--)
    {
        nibble = stream->data[idx];
        bmask  = 0xff;
        emask  = 0xff;

        if (idx == byte_eidx)
        {
            emask = 0x00;
            for (uint32_t j = 0; j <= eidx % 8; j++)
            {
                emask = (emask << 1) + 0x01;
            }
        }
        if (idx == byte_sidx)
        {
            bmask = 0x00;
            for (uint32_t j = 0; j < 8 - (sidx % 8); j++)
            {
                bmask = (bmask >> 1) + 0x80;
            }
        }
        mask   = bmask & emask;
        nibble = nibble & mask;

        if ((byte_eidx - byte_sidx) == 4 && idx == byte_eidx)
        {
            overflow = nibble;
        }
        else
        {
            *read = (*read << 8) + nibble;
        }
        if (idx == byte_sidx) break;
    }
    *read = *read >> (sidx % 8);

    /* if the bits copied span across 5 bytes */
    if (overflow != 0x00)
    {
        ((uint8_t*)read)[3] |= (overflow << (8 - (sidx % 8)));
    }

    return num_bits;
}

/**
 * @brief Hardware-accelerated read.  Loads num_bits starting at sidx into the
 *        ISE co-processor's shadow register (not into a CPU register — the
 *        XIF writeback into rd is not currently reliable, so the value is
 *        consumed by a subsequent RMCS).
 */
#ifdef CUSTOM_EXT
uint8_t xget_stream_bits(const volatile stream_t* const restrict stream, const uint32_t sidx, uint8_t num_bits)
{
    if (num_bits == 0)  return 0;
    if (num_bits > 32)  num_bits = 32;

    if (sidx + num_bits > stream->s_bits - 1)
    {
        num_bits = stream->s_bits - sidx;
    }

    uint32_t r;
    RMLD(sidx, num_bits, r);    /* result stored in coproc shadow register */
    return num_bits;
}
#endif

/**
 * @brief Write up to 32 bits to a stream.  Crosses byte/word boundaries.
 *        Grows the stream's size / s_bits if needed.
 *
 * @param stream    output stream (modified in place)
 * @param write     value whose low num_bits will be written
 * @param sidx      starting bit index
 * @param num_bits  number of bits to write (max 32)
 */
void set_stream_bits(stream_t* const restrict stream, uint32_t write, uint32_t sidx, uint8_t num_bits)
{
    uint32_t eidx   = sidx + num_bits - 1;
    uint32_t bmask;
    uint8_t  emask;
    uint8_t  mask;
    uint32_t aligned_wdata;
    uint8_t  overflow = 0x00;
    uint8_t  nibble;

    uint32_t byte_eidx = eidx / 8;
    uint32_t byte_sidx = sidx / 8;

    if (sidx > stream->s_bits) return;

    if (byte_eidx >= stream->size)
    {
        stream->size = byte_eidx + 1;
    }
    if (eidx >= stream->s_bits)
    {
        stream->s_bits = eidx + 1;
    }

    aligned_wdata = write << (sidx % 8);

    if ((byte_eidx - byte_sidx) == 4)
    {
        overflow = ((uint8_t*)&write)[3] >> (8 - ((eidx + 1) % 8));
    }

    for (uint32_t idx = byte_eidx;; idx--)
    {
        bmask = 0xff;
        emask = 0xff;

        if (idx == byte_eidx)
        {
            emask = 0x00;
            for (uint32_t j = 0; j <= eidx % 8; j++)
            {
                emask = (emask << 1) + 0x01;
            }
        }
        if (idx == byte_sidx)
        {
            bmask = 0x00;
            for (uint32_t j = 0; j < 8 - (sidx % 8); j++)
            {
                bmask = (bmask >> 1) + 0x80;
            }
        }
        mask   = bmask & emask;

        nibble = stream->data[idx];
        nibble = nibble & ~(mask);

        if ((byte_eidx - byte_sidx) == 4 && idx == byte_eidx)
        {
            nibble |= overflow;
        }
        else
        {
            nibble |= ((uint8_t*)&aligned_wdata)[idx - byte_sidx];
        }

        stream->data[idx] = nibble;

        if (idx == byte_sidx) break;
    }
}

/**
 * @brief Hardware-accelerated write.  Copies num_bits from the shadow
 *        register (populated by a prior RMLD) into the stream at sidx.
 */
#ifdef CUSTOM_EXT
void xset_stream_bits(stream_t* const restrict stream, uint32_t sidx, uint8_t num_bits)
{
    uint32_t eidx      = sidx + num_bits - 1;
    uint32_t byte_eidx = eidx / 8;

    if (sidx > stream->s_bits) return;

    if (byte_eidx >= stream->size)
    {
        stream->size = byte_eidx + 1;
    }
    if (eidx >= stream->s_bits)
    {
        stream->s_bits = eidx + 1;
    }

    RMCS(sidx, num_bits);
}
#endif

/***************************************** State Actions *****************************************/

/**
 * @brief Read the 1-bit "compressed" marker. transitions to READ_COUNTER_VALUE.
 */
static enum_decode_states_t determine_compression(const volatile stream_t* const restrict estream, stream_t* const dstream, uint32_t* const bit_idx)
{
    (void)dstream;

    if (end_of_stream(bit_idx, estream)) return HALT;

    compressed = GET_STREAM_BIT(estream, *bit_idx);
    (*bit_idx)++;

    return READ_COUNTER_VALUE;
}

/**
 * @brief Read the 5-bit count field (MSB-first), then transition to either
 *        EXTEND_VALUE (compressed) or COPY_SEGMENT (literal).
 */
static enum_decode_states_t read_counter_value(const volatile stream_t* const restrict estream, stream_t* const dstream, uint32_t* const bit_idx)
{
    (void)dstream;

    if (end_of_stream(bit_idx, estream)) return ERROR;

    uint32_t cnt_f;
    if (get_stream_bits(estream, &cnt_f, *bit_idx, COUNTER_SIZE) != COUNTER_SIZE) return ERROR;
    *bit_idx += COUNTER_SIZE;

    count_value = 0;
    for (uint8_t i = 0; i < COUNTER_SIZE; i++)
    {
        count_value = (count_value << 1) + (cnt_f & 0x1);
        cnt_f >>= 1;
    }
    count_value += 1;

    if (count_value > 32 || count_value < 1) return ERROR;
    if (compressed)                          return EXTEND_VALUE;

    return COPY_SEGMENT;
}

/**
 * @brief Copy count_value literal bits from estream into dstream.
 */
static enum_decode_states_t copy_segment(const volatile stream_t* const restrict estream, stream_t* const dstream, uint32_t* const bit_idx)
{
    if (end_of_stream(bit_idx, estream)) return ERROR;

    if (dstream->size == 0)
    {
        dstream->size = 1;
    }

    uint8_t num_copied_bits;

#ifdef CUSTOM_EXT
    num_copied_bits = xget_stream_bits(estream, *bit_idx, count_value);
    xset_stream_bits(dstream, dstream->s_bits, num_copied_bits);
#else
    uint32_t copied_bits;
    num_copied_bits = get_stream_bits(estream, &copied_bits, *bit_idx, count_value);
    set_stream_bits(dstream, copied_bits, dstream->s_bits, num_copied_bits);
#endif

    *bit_idx += count_value;
    return DETERMINE_COMPRESSION;
}

/**
 * @brief Write a single value bit count_value times to dstream.
 */
static enum_decode_states_t extend_value(const volatile stream_t* const restrict estream, stream_t* const dstream, uint32_t* const bit_idx)
{
    if (end_of_stream(bit_idx, estream)) return ERROR;

    uint8_t value = GET_STREAM_BIT(estream, *bit_idx);
    (*bit_idx)++;

#ifdef CUSTOM_EXT
    /* TODO: replace with xset_stream_bits() once that is wired up. */
    uint32_t dbit_idx  = dstream->s_bits;
    uint32_t eidx      = dbit_idx + count_value - 1;
    uint32_t byte_eidx = eidx / 8;

    if (dbit_idx > dstream->s_bits) return DETERMINE_COMPRESSION;

    if (byte_eidx >= dstream->size)
    {
        dstream->size = byte_eidx + 1;
    }
    if (eidx >= dstream->s_bits)
    {
        dstream->s_bits = eidx + 1;
    }

    if (count_value > 0)
    {
        if (value == 1) RMXS(dbit_idx, count_value);
        else            RMXR(dbit_idx, count_value);
    }
#else
    uint32_t write = 0x00;
    /* binary-to-unary: build a register full of `value` bits */
    if (value) for (uint8_t i = 0; i < count_value; i++, write = (write << 1) + 1);

    set_stream_bits(dstream, write, dstream->s_bits, count_value);
#endif

    return DETERMINE_COMPRESSION;
}

/***************************************** Helper Functions *****************************************/

static bool end_of_stream(const uint32_t* const bit_idx, const volatile stream_t* const estream)
{
    return *bit_idx >= estream->s_bits;
}

/*************************************************************************************************/
