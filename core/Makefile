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
INCLUDE = cv32e40x/rtl/include/cv32e40x_pkg.sv custom/include/custom_instr_pkg.sv
RTL = $(wildcard cv32e40x/rtl/*.sv) cv32e40x_top.sv
RTL_CUSTOM = $(wildcard custom/*.sv)

SIM = yosys_verilog.v cv32e40x_soc.sv dp_ram.sv simpleuart.v

TB = tb_top.sv

# --- Preprocess ---

preprocessed.v: $(INCLUDE) $(RTL) $(RTL_CUSTOM)
	sv2v -v $(INCLUDE) $(RTL) $(RTL_CUSTOM) > preprocessed.v

# --- ULX3S ---

sim-ulx3s.vvp: $(SIM) $(TB)
	iverilog -Wall -o $@ -g2012 $(SIM) $(TB) -s tb_top `yosys-config --datdir/ecp5/cells_sim.v`

sim-ulx3s: sim-ulx3s.vvp firmware/firmware.hex
	vvp $^ -fst +fst +verbose
	
view-ulx3s:
	gtkwave tb_top.fst

synth-ulx3s: ulx3s.json

build-ulx3s: ulx3s.bit

upload-ulx3s: ulx3s.bit
	openFPGALoader --board=ulx3s ulx3s.bit

ulx3s.json: tech/rtl/cv32e40x_clock_gate.sv preprocessed.v ulx3s_top.sv cv32e40x_soc.sv dp_ram.sv simpleuart.v firmware/firmware.hex
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'synth_ecp5 -top ulx3s_top -json $@' tech/rtl/cv32e40x_clock_gate.sv preprocessed.v ulx3s_top.sv cv32e40x_soc.sv dp_ram.sv simpleuart.v

yosys_verilog.v: tech/rtl/cv32e40x_clock_gate.sv preprocessed.v
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'read -sv tech/rtl/cv32e40x_clock_gate.sv preprocessed.v; hierarchy -top cv32e40x_top; proc; flatten; opt; fsm; opt; write_verilog -noattr yosys_verilog.v' 

ulx3s.config: ulx3s.json
	nextpnr-ecp5 --85k --json $< \
		--package CABGA381 \
		--lpf ulx3s_v20.lpf \
		--textcfg $@

ulx3s.bit: ulx3s.config
	ecppack $< $@

# --- Firmware ---

firmware/%.o: firmware/%.c
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32i -Os --std=gnu11 $(GCC_WARNS) -ffreestanding -nostdlib -flto -o $@ $<

firmware/start.o: firmware/start.S
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32i -o $@ $<

firmware/firmware.elf: $(FIRMWARE_OBJS) firmware/sections.lds
	$(TOOLCHAIN_PREFIX)gcc  -Os -mabi=ilp32 -march=rv32i -ffreestanding -nostdlib -flto -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,firmware/sections.lds,-Map,firmware/firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) -lgcc

firmware/firmware.bin: firmware/firmware.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

firmware/firmware.hex: firmware/firmware.bin firmware/makehex.py
	$(PYTHON) firmware/makehex.py $< 4096 > $@

# --- General ---

.PHONY: sim-ulx3s view-ulx3s synth-ulx3s build-ulx3s upload-ulx3s

clean:
	rm -f *.vvp *.fst *.vcd *.log *.json *.asc *.bin *.bit firmware/*.o firmware/rle/*.o firmware/*.elf firmware/*.bin firmware/*.hex firmware/firmware.map ulx3s.config preprocessed.v yosys_verilog.v
