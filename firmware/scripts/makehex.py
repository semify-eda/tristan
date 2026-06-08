#!/usr/bin/env python3
"""Convert a binary firmware file to a hex .mem file for simulation or IRAM loading.

Outputs one word per line in little-endian hex format. In 'spi' mode, outputs
one byte per line instead.

Usage:
    python makehex.py <binary> <nwords> [spi]
"""

# This is free and unencumbered software released into the public domain.

import argparse


def convert(binfile: str, nwords: int, mode: str) -> None:
    with open(binfile, "rb") as f:
        bindata = f.read()

    assert len(bindata) < 4 * nwords, f"Binary too large: {len(bindata)} bytes > {4 * nwords - 1}"
    assert len(bindata) % 4 == 0, f"Binary size not a multiple of 4: {len(bindata)}"

    for i in range(nwords):
        if i < len(bindata) // 4:
            w = bindata[4*i : 4*i+4]
            if mode == "spi":
                print("%02x" % w[0])
                print("%02x" % w[1])
                print("%02x" % w[2])
                print("%02x" % w[3])
            else:
                print("%02x%02x%02x%02x" % (w[3], w[2], w[1], w[0]))
        else:
            print("0")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("binary", help="Input binary file")
    p.add_argument("nwords", type=int, help="Number of 32-bit words in output")
    p.add_argument("mode", nargs="?", default="", choices=["", "spi"],
                   help="Output mode: 'spi' for one byte per line, default for one word per line")
    args = p.parse_args()
    convert(args.binary, args.nwords, args.mode)


if __name__ == "__main__":
    main()
