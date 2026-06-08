#!/usr/bin/env python3
"""Pack a one-bit-per-line BRLE-encoded stream into a dmem .mem file.

Layout written:
  byte 0x3E00       stream_t header (4 words):
                      [0] data_ptr     -> 0x3E10 (start of payload)
                      [1] size         -> payload size in bytes
                      [2] s_bits       -> payload size in bits
                      [3] num_signals  -> 1
  byte 0x3E10       packed bitstream (LSB-first within each byte)
  elsewhere         zeros

Usage:
    python generate_dmem.py <outfile.mem> <encoded.txt>
"""
import sys

HEADER_BYTE_OFFSET = 0x3E00
HEADER_WORDS       = 4
DMEM_WORDS         = 0x1000   # 4096 words = 16 KB


def main():
    outfile, encoded_path = sys.argv[1], sys.argv[2]

    # 1) read encoded.txt -> bit list
    with open(encoded_path) as f:
        bits = [int(c) for c in f.read() if c in "01"]
    s_bits = len(bits)
    size_b = (s_bits + 7) // 8

    # 2) pack bits LSB-first into bytes
    data = bytearray(size_b)
    for i, b in enumerate(bits):
        if b:
            data[i // 8] |= 1 << (i % 8)

    # 3) layout: header at 0x3E00, payload immediately after at 0x3E10
    header_word  = HEADER_BYTE_OFFSET // 4
    payload_byte = HEADER_BYTE_OFFSET + HEADER_WORDS * 4
    payload_word = payload_byte // 4

    mem = [0] * DMEM_WORDS
    mem[header_word + 0] = payload_byte    # data_ptr
    mem[header_word + 1] = size_b          # size
    mem[header_word + 2] = s_bits          # s_bits
    mem[header_word + 3] = 1               # num_signals

    # 4) pack data bytes into 32-bit little-endian words at payload offset
    for i, byte in enumerate(data):
        mem[payload_word + i // 4] |= byte << ((i % 4) * 8)

    # 5) write .mem
    with open(outfile, "w") as f:
        for w in mem:
            f.write(f"{w:08x}\n")


if __name__ == "__main__":
    main()
