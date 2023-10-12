TOOLCHAIN_PREFIX ?= riscv32-unknown-elf-
PYTHON ?= python3

FIRMWARE_OBJS = firmware/start.o \
                firmware/main.o \
                firmware/util.o \
                firmware/rle/data.o \
                firmware/rle/rle.o \
                firmware/rle/instr.o

GCC_WARNS  = -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual #-Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes #-pedantic # -Wconversion

# Sources
INCLUDE = common/cv32e40x/rtl/include/cv32e40x_pkg.sv \
	common/custom/include/custom_instr_pkg.sv

RTL = 	$(wildcard common/cv32e40x/rtl/*.sv) \
	common/cv32e40x_top.sv

RTL_CUSTOM = $(wildcard common/custom/*.sv)

RTL_FPGA = fpga/ulx3s/ulx3s_top.sv \
           fpga/sp_ram.sv \
           preprocessed.v \
           common/tech/rtl/cv32e40x_clock_gate.sv \
           common/cv32e40x_soc.sv \
           common/simpleuart.v \
           common/spi_flash/rtl/spi_flash.sv

SIM = 	cv32e40x_yosys.v \
	common/cv32e40x_soc.sv \
	common/simpleuart.v \
	common/spi_flash/rtl/spi_flash.sv \
	common/spi_flash/tb/spiflash.v \
        fpga/sp_ram.sv \

TB = common/tb_top.sv

# --- Preprocess ---

preprocessed.v: $(INCLUDE) $(RTL) $(RTL_CUSTOM)
	sv2v -v $(INCLUDE) $(RTL) $(RTL_CUSTOM) > preprocessed.v

# --- ULX3S ---

# For the simulation
cv32e40x_yosys.v: common/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'read -sv common/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v; hierarchy -top cv32e40x_top; proc; flatten; opt; fsm; opt; write_verilog -noattr cv32e40x_yosys.v' 

sim-ulx3s.vvp: $(SIM) $(TB)
	iverilog -Wall -o $@ -g2012 $(SIM) $(TB) -s tb_top #`yosys-config --datdir/ecp5/cells_sim.v`

sim-ulx3s: sim-ulx3s.vvp firmware/firmware.hex
	vvp $^ -fst +fst +verbose
	
view-ulx3s:
	gtkwave tb_top.fst --save tb_top.gtkw 

synth-ulx3s: ulx3s.json

build-ulx3s: ulx3s.bit

upload-ulx3s: ulx3s.bit firmware/firmware.bin
	openFPGALoader --board=ulx3s -f ulx3s.bit
	openFPGALoader --board=ulx3s -f -o 0x200000 firmware/firmware.bin

ulx3s.json: $(RTL_FPGA)
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'synth_ecp5 -top ulx3s_top -json $@' $(RTL_FPGA)

ulx3s.config: ulx3s.json fpga/ulx3s/ulx3s_v20.lpf
	nextpnr-ecp5 --85k --json $< \
		--package CABGA381 \
		--lpf fpga/ulx3s/ulx3s_v20.lpf \
		--textcfg $@

ulx3s.bit: ulx3s.config
	ecppack $< $@ --compress

# --- Firmware ---

firmware/%.o: firmware/%.c
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32i -Os --std=gnu11 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<

firmware/start.o: firmware/start.S
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32i -o $@ $<

firmware/firmware.elf: $(FIRMWARE_OBJS) firmware/sections.lds
	$(TOOLCHAIN_PREFIX)gcc  -Os -mabi=ilp32 -march=rv32i -ffreestanding -nostdlib -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,firmware/sections.lds,-Map,firmware/firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) -lgcc

firmware/firmware.bin: firmware/firmware.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

firmware/firmware.hex: firmware/firmware.bin firmware/makehex.py
	$(PYTHON) firmware/makehex.py $< 4096 > $@

# --- General ---

.PHONY: sim-ulx3s view-ulx3s synth-ulx3s build-ulx3s upload-ulx3s

clean:
	rm -f *.vvp *.fst *.fst.hier *.vcd *.log *.json *.asc *.bin *.bit firmware/*.o firmware/rle/*.o firmware/*.elf firmware/*.bin firmware/*.hex firmware/firmware.map ulx3s.config preprocessed.v cv32e40x_yosys.v
