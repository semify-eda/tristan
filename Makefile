TOOLCHAIN_PREFIX ?= riscv32-unknown-elf-
PYTHON ?= python3

FIRMWARE_OBJS = core/firmware/start.o \
                core/firmware/main.o \
                core/firmware/util.o \
                core/firmware/rle/data.o \
                core/firmware/rle/rle.o \
                core/firmware/rle/instr.o

GCC_WARNS  = -Werror -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual #-Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes #-pedantic # -Wconversion

# Sources
INCLUDE = core/cv32e40x/rtl/include/cv32e40x_pkg.sv core/custom/include/custom_instr_pkg.sv
RTL = $(wildcard core/cv32e40x/rtl/*.sv) core/cv32e40x_top.sv
RTL_CUSTOM = $(wildcard core/custom/*.sv)

SIM = cv32e40x_yosys.v core/cv32e40x_soc.sv core/dp_ram.sv core/simpleuart.v core/spi_flash/tb/spiflash.v

TB = core/tb_top.sv

# --- Preprocess ---

preprocessed.v: $(INCLUDE) $(RTL) $(RTL_CUSTOM)
	sv2v -v $(INCLUDE) $(RTL) $(RTL_CUSTOM) > preprocessed.v

# --- ULX3S ---

sim-ulx3s.vvp: $(SIM) $(TB)
	iverilog -Wall -o $@ -g2012 $(SIM) $(TB) -s tb_top #`yosys-config --datdir/ecp5/cells_sim.v`

sim-ulx3s: sim-ulx3s.vvp core/firmware/firmware.hex
	vvp $^ -fst +fst +verbose
	
view-ulx3s:
	gtkwave tb_top.fst --save tb_top.gtkw 

synth-ulx3s: ulx3s.json

build-ulx3s: ulx3s.bit

upload-ulx3s: ulx3s.bit
	openFPGALoader --board=ulx3s ulx3s.bit

ulx3s.json: core/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v fpga/ulx3s_top.sv core/cv32e40x_soc.sv core/dp_ram.sv core/simpleuart.v core/firmware/firmware.hex
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'synth_ecp5 -top ulx3s_top -json $@' core/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v fpga/ulx3s_top.sv core/cv32e40x_soc.sv core/dp_ram.sv core/simpleuart.v

cv32e40x_yosys.v: core/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'read -sv core/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v; hierarchy -top cv32e40x_top; proc; flatten; opt; fsm; opt; write_verilog -noattr cv32e40x_yosys.v' 

ulx3s.config: ulx3s.json fpga/ulx3s_v20.lpf
	nextpnr-ecp5 --85k --json $< \
		--package CABGA381 \
		--lpf fpga/ulx3s_v20.lpf \
		--textcfg $@

ulx3s.bit: ulx3s.config
	ecppack $< $@

# --- Firmware ---

core/firmware/%.o: core/firmware/%.c core/firmware/%.h
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32i -Os --std=gnu11 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $<

core/firmware/start.o: core/firmware/start.S
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32i -o $@ $<

core/firmware/firmware.elf: $(FIRMWARE_OBJS) core/firmware/sections.lds
	$(TOOLCHAIN_PREFIX)gcc  -Os -mabi=ilp32 -march=rv32i -ffreestanding -nostdlib -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,core/firmware/sections.lds,-Map,core/firmware/firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) -lgcc

core/firmware/firmware.bin: core/firmware/firmware.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

core/firmware/firmware.hex: core/firmware/firmware.bin core/firmware/makehex.py
	$(PYTHON) core/firmware/makehex.py $< 4096 > $@

# --- General ---

.PHONY: sim-ulx3s view-ulx3s synth-ulx3s build-ulx3s upload-ulx3s

clean:
	rm -f *.vvp *.fst *.fst.hier *.vcd *.log *.json *.asc *.bin *.bit core/firmware/*.o core/firmware/rle/*.o core/firmware/*.elf core/firmware/*.bin core/firmware/*.hex core/firmware/firmware.map ulx3s.config preprocessed.v cv32e40x_yosys.v
