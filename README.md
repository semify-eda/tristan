# TRISTAN

This repository contains the `CV32E40X` core and all additional material for an FPGA prototype and ASIC implementation.

## Instructions

Test the core on the `ULX3S` FPGA:

Run the simulation:

	make sim-ulx3s

View the waveforms:

	make view-ulx3s

Synthesize the SoC:

	make synth-ulx3s

Run Place and Route:

	make build-ulx3s

Upload the bitstream:

	make upload-ulx3s