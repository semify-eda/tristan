# TRISTAN

This repository contains the `CV32E40X` core and all additional material for an FPGA prototype and ASIC implementation.

## Setup

To run simulation and perform synthesis you need to have the latest versions of the following open source tools:

##### OSS CAD Suite
- Install the latest build of the [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build).

##### SV2V
- You will need [sv2v](https://github.com/zachjs/sv2v). Either build the latest release or download the artifacts. Place the binary inside the `bin/` folder of your oss-cad-suite installation.

##### RISC-V Compiler Toolchain
- To compile the firmware you will need the RISC-V toolchain. Head over to [RISC-V GNU Compiler Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) and clone the latest release.
- After cloning the repo you must configure the cross-compiler for the RV32IA architecture. Run:
    > `sudo ./configure --prefix=/opt/riscv --with-arch=rv32ia`
- Build the compiler for the newlib target using `make` 

To enable all tools, add  `/opt/riscv/riscv32-unknown-elf/bin` and `/opt/riscv/bin` and `/usr/src/oss-cad-suite/bin` to your `PATH` variable


## Instructions

Run the simulation:

	make sim-ulx3s

View the waveforms:

	make view-ulx3s

---

Test the core on the `ULX3S` FPGA:

Synthesize the SoC:

	make synth-ulx3s

Run Place and Route:

	make build-ulx3s

Upload the bitstream:

	make upload-ulx3s

---

To cleanup the files:

	make clean
