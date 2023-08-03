# TRISTAN

This repository contains the `CV32E40X` core and all additional material for an FPGA prototype and ASIC implementation.

## Setup

To run the simulation and perform the synthesis you need to make sure to have the latest of the open source tools.

The easiest way is to install the latest build of the [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build).

Additionally you will need [sv2v](https://github.com/zachjs/sv2v). Either build the latest release or download the artifacts. Place the binary inside the `bin/` folder of your oss-cad-suite installation.

Now to enable all tools you need to source `environment` of your oss-cad-suite installation.

	> source /path/to/oss-cad-suite/environment

To compile the firmware you will need a RISC-V toolchain. Head over to [RISC-V GNU Compiler Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) and build the compiler for `riscv32i`. Finally install it or add it to your `PATH` variable.

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