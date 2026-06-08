# Tristan — RISC-V Subsystem

This directory contains the CV32E40X RISC-V core and all custom extensions.

## Setup

### Simulation tools (Verilator)

Verilator is installed as part of the SmartWave toolchain:

```bash
./setup/install.sh    # from repo root — installs Verilator + Python
```

Fetch the core submodules (CV32E40X and CVA6):

```bash
git submodule update --init --recursive
```

Source the environment to set `$WFG_ROOT` and `$TRISTAN_ROOT`:

```bash
source sourceme.bash  # from repo root
```

### RISC-V Compiler Toolchain

To compile firmware you need the RISC-V GNU toolchain configured for `rv32ia`:

```bash
git clone https://github.com/riscv-collab/riscv-gnu-toolchain
cd riscv-gnu-toolchain
sudo ./configure --prefix=/opt/riscv --with-arch=rv32ia
make
```

Add `/opt/riscv/bin` and `/opt/riscv/riscv32-unknown-elf/bin` to your `PATH`.

## Instructions

Compile firmware:

    make firmware

Run the simulation (Verilator):

    cd design/tristan
    make

Run a specific test:

    make TESTCASE=<test_function_name>

Clean simulation artifacts:

    make clean

## Verification

### Testbench

The top-level cocotb testbench at `core/testbench/top_tb.{sv,py}` instantiates the
full `tristan_soc` (CV32E40X or CVA6 variant, selected by `CORE=`), drives the
two SoC clocks (25 MHz `core_clk`, 100 MHz `wfg_clk`), and lets the firmware
run while a cocotb-driven Wishbone slave answers any peripheral access from
the core. A `wfg_timer_top` is wired in as a real peripheral so that
firmware-issued MMIO writes traverse the OBI → Wishbone bridge end-to-end.

Three module-level cocotb testbenches cover the custom blocks in isolation:

| Module                 | Directory                            |
|------------------------|--------------------------------------|
| ISE (shifter)          | `core/custom/ise/sim/`               |
| OBI ↔ Wishbone bridge  | `core/custom/obi_wb_bridge/sim/`     |
| Wishbone RAM interface | `core/custom/wb_ram_interface/sim/`  |

Each is invoked the same way as the top-level:

    cd core/custom/<module>/sim
    make
    make clean

### Test results

All bundled testbenches (top-level + the three module sims) pass on
Verilator 5.046 with the default `CORE=cv32a60x` configuration.

### Benchmark

The custom ISE has been benchmarked as part of a larger verification and
demo framework. The workload is an RLE-decompression loop running on a
16-sample sine signal: the firmware decodes a stream of compressed sine
samples, drives them out through the WFG pipeline, and measures decode
throughput on hardware. Two firmware variants are compared — a pure
software implementation (baseline) and one that uses the custom ISE
instructions for the bit-packing inner loops.

Hardware-measured on a Xilinx FPGA (100 MHz peripheral clock,
25 MHz CV32A60X SoC clock, 2026-05-07):

| Metric                                      | Result                       |
|---------------------------------------------|------------------------------|
| Decompression throughput (ISE vs software)  | ~2.0×                        |
| Decode firmware `.text` size (ISE)          | ~64 % of software (~36 % smaller) |
| Compression ratio (raw / encoded)           | 2.3× on this signal          |

### Functional coverage

Functional coverage was collected as part of the larger verification
framework that integrates Tristan with the host SoC. The results below
are taken from that flow.

![Functional coverage — CV32A60X](functional_coverage_results_cv32a60x.png)

![Functional coverage — CV32E40X](functional_coverage_results_cv32e40x.png)

*Coverage focussed on the cv32a60x core; not all tests are written for
the cv32e40x core as well.*
