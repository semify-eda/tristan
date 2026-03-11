# Tristan — RISC-V Subsystem

This directory contains the CV32E40X RISC-V core and all custom extensions.

## Setup

### Simulation tools (Verilator)

Verilator is installed as part of the SmartWave toolchain:

```bash
./setup/install.sh    # from repo root — installs Verilator + Python
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

Apply the patch:

/*

TBD, nothing to do yet...
core/csr_regfile_patched.sv needs to replace core/cv6/core/csr_regfile.sv (CVA6) 

*/


Compile firmware:

    make firmware

Run the simulation (Verilator):

    cd design/tristan
    make

Run a specific test:

    make TESTCASE=<test_function_name>

Clean simulation artifacts:

    make clean

## Simulation

Top-level testbench for tristan is under `core/testbench` and simulation is ran in the root of the tristan module with:

    make


Each custom module has its own `sim/` directory:

| Module | Directory |
|---|---|
| Co-processor (shifter) | `core/custom/coproc/sim/` |
| OBI→Wishbone bridge | `core/custom/obi_wb_bridge/sim/` |
| Wishbone RAM interface | `core/custom/wb_ram_interface/sim/` |

Run any of these the same way:

    cd core/custom/<module>/sim
    make
