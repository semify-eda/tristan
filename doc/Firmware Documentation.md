# Writing RISC-V Firmware to Smartwave

To program the RISC-V SoC on Smartwave, you need three components:

#### SoC HAL
To access WFG modules such as the pinmux or the I2CT from the SoC when writing your firmware, use the generated Hardware Abstraction Layer (HAL) files. To do so, `#include hal.h` in the main file, and reference each module and its registers through the predefined structs.

#### RISC-V Compiler Toolchain
To compile your firmware, you must first download and install the RISC-V Compiler Toolchain.

- Head over to [RISC-V GNU Compiler Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) and clone the latest release with the `--recurse-submodules` flag.
- After cloning the repo you must configure the cross-compiler for the RV32IA architecture. Run:
    > `sudo ./configure --prefix=/opt/riscv --with-arch=rv32ia`
- Build the compiler for the newlib target using `make`
- Enable the tools by adding  `/opt/riscv/riscv32-unknown-elf/bin` and `/opt/riscv/bin` to your `PATH` variable

When the toolchain is installed, navigate to the firmware folder, and run `make` in the terminal to compile the firmware.

Three useful firmware files will be generated, with different file extensions:

- `firmware.map` is the generated from the linker (using sections.lds as an input) which breaks out where each function is mapped in the memory address space

- `firmware.o` is the auto-annotated assembly file with the address of each instruction and markers showing where functions start

- `firmware.mem` is the pure hex file. __This is the file you must write to Smawave__

#### Smartwave Firmware Flashing Script
Lastly, you must flash the firmware file using the `load_firmware.py` script. Call the script, and pass in the `firmware.mem` file that you compiled as an argument by calling:
> `python load_firmware.py firmware.mem`

If all is successful, you should have a Smartwave loaded with the new firmware.