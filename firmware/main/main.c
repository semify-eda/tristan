/* Minimum-working-example firmware for the Tristan SoC.
 *
 * Decodes a single BRLE-encoded stream from DMEM, then writes the first
 * three 16-bit decoded words to a single Wishbone-mapped sink address so
 * a testbench (or anyone watching the bus) can observe them.  Halts after
 * the three writes.
 *
 * The build system compiles this file twice:
 *   - `make base` -> build/base/firmware.mem
 *       Compiled without `-DCUSTOM_EXT`.  rle.c falls back to a pure-software
 *       implementation of its inner helpers (extend_value, copy_segment).
 *   - `make ise`  -> build/ise/firmware.mem
 *       Compiled with `-DCUSTOM_EXT`.  rle.c's helpers emit the custom-opcode
 *       instructions (RMXS / RMXR / RMLD / ...) defined in include/instr.h,
 *       which the Tristan ISE co-processor executes.
 *
 * The main.c source is identical for both builds; the difference lives in
 * rle.c via #ifdef CUSTOM_EXT.  See README.md for the disassembly diff.
 */

#include <stdint.h>
#include "../include/rle.h"
#ifdef CUSTOM_EXT
#include "../include/instr.h"
#endif

/* Where the encoded stream's stream_t header is placed by generate_dmem.py.
 * For a single-signal buffer with the default --start-offset 0x3E00, the
 * header lives at DMEM byte offset 0x3E00 (CPU virtual address 0x00003E00). */
#define ENCODED_ADDR    0x00003E00

/* Wishbone-mapped sink address.  Any address with bit[20]=1 routes through
 * the OBI->WB bridge to the external Wishbone bus, where the testbench slave
 * (or any scope watching the bus) can capture the transaction. */
#define MMIO_SINK_ADDR  0x00100000

/* Bit-to-byte ordering assumed by the BRLE decoder:
 *   First decoded bit  -> MSB of decoded_buf[0]
 *   Bit  7             -> LSB of decoded_buf[0]
 *   Bit  8             -> MSB of decoded_buf[1]
 *   ...
 * The example encoded.txt in signals/ must be authored so that the resulting
 * 48-bit decoded stream is, in order:
 *
 *   00000000 11111111    10101010 10101010    10000000 00000000
 *   (= 0x00FF)           (= 0xAAAA)           (= 0x8000)
 */

int main(void)
{
    volatile stream_t* const encoded = (volatile stream_t*)(ENCODED_ADDR);

    /* BLOCK_SIZE = 128 bits = 16 bytes; +4 slop. */
    uint8_t  decoded_buf[20];

    stream_t decoded = {
        .data        = decoded_buf,
        .s_bits      = 0,
        .size        = 0,
        .num_signals = 1,
    };
    uint32_t idx = 0;

#ifdef CUSTOM_EXT
    /* Tell the ISE co-processor where the encoded bitstream lives (load
     * address) and where to write decoded bits (store address). */
    CASLRM((uint32_t)decoded_buf, (uint32_t)encoded->data);
#endif

    /* Decode the stream.  Exits when the encoded bitstream is exhausted
     * (HALT state) or after producing BLOCK_SIZE=128 decoded bits. */
    decode_stream(encoded, &decoded, &idx);

    /* Emit the first three 16-bit words to the MMIO sink.  Big-endian
     * byte-pair packing: byte 0 is high, byte 1 is low. */
    volatile uint32_t* const sink = (volatile uint32_t*)MMIO_SINK_ADDR;
    *sink = ((uint32_t)decoded_buf[0] << 8) | decoded_buf[1];
    *sink = ((uint32_t)decoded_buf[2] << 8) | decoded_buf[3];
    *sink = ((uint32_t)decoded_buf[4] << 8) | decoded_buf[5];

    /* Done. */
    while (1);
}
