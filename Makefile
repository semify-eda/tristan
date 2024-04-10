TOOLCHAIN_PREFIX ?= riscv32-unknown-elf-
PYTHON ?= tabbypy3

FIRMWARE_SRCS := firmware/start.c \
                 firmware/main.c \
                 firmware/util.c \
                 firmware/instr.c \
				 firmware/rle/data.c \
				 firmware/obi_test.c \
				 firmware/cntb_test.c \
				 firmware/rle/rle.c \
				 firmware/rle_test.c \
				 firmware/hal.c


FIRMWARE_OBJS = $(patsubst %.c,%.o,$(FIRMWARE_SRCS))

GCC_WARNS  = -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic #-Wconversion -Werror

# Sources
INCLUDE = core/cv32e40x/rtl/include/cv32e40x_pkg.sv

RTL = 	$(wildcard core/cv32e40x/rtl/*.sv) \
	core/cv32e40x_top.sv

RTL_CUSTOM = $(wildcard core/custom/*.sv)

SRC = 	cv32e40x_yosys.v \
	core/cv32e40x_soc.sv \
	core/simpleuart.v \
   	core/core_sram.sv \
    core/custom/ram_arbiter/rtl/ram_arbiter.sv \
	core/custom/obi_wb_bridge/rtl/obi_wb_bridge.sv \
	core/custom/wb_ram_interface/rtl/wb_ram_interface.sv \
	../pkg/wfg_pkg.sv \
	../wfg/wfg_timer/rtl/wfg_timer_wishbone_reg.sv \
	../wfg/wfg_timer/rtl/wfg_timer.sv \
	../wfg/wfg_timer/rtl/wfg_timer_top.sv \
	core/testbench/top_tb.sv

TB = core/tb_top.sv

# --- Cocotb ---
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
COMPILE_ARGS := -I core/
COMPILER_ARGS ?= -g2012

VERILOG_SOURCES += $(SRC)

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = top_tb

# MODULE is the basename of the Python test file
export PYTHONPATH := $(PYTHONPATH):core/testbench/
MODULE = top_tb

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
# --- Preprocess ---

preprocessed.v: $(INCLUDE) $(RTL) $(RTL_CUSTOM)
	sv2v -v $(INCLUDE) $(RTL) $(RTL_CUSTOM) -w $@

# --- sim ---

# For the simulation
cv32e40x_yosys.v: core/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'read -sv core/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v; hierarchy -top cv32e40x_top; proc; flatten; opt; fsm; opt; write_verilog -noattr cv32e40x_yosys.v' 

all: firmware cv32e40x_yosys.v
	echo ""
	
# --- Firmware ---

firmware/%.o: firmware/%.c
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32i -O3 --std=gnu11 $(GCC_WARNS) -ffreestanding -nostdlib -o $@ $< -I firmware

firmware/start.o: firmware/start.S
	$(TOOLCHAIN_PREFIX)gcc -c -O3 -mabi=ilp32 -march=rv32i -ffreestanding -nostdlib -o $@ $<

firmware/firmware.elf: $(FIRMWARE_OBJS) firmware/sections.lds
	$(TOOLCHAIN_PREFIX)gcc -O3 -mabi=ilp32 -march=rv32i -ffreestanding -nostdlib -o $@ \
		-Wl,--build-id=none,-Bstatic,-T,firmware/sections.lds,-Map,firmware/firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) -lgcc

firmware/firmware.o: firmware/firmware.elf
	riscv32-unknown-elf-objdump -d firmware/firmware.elf > firmware/firmware.o

firmware/firmware.bin: firmware/firmware.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

firmware/firmware.mem: firmware/firmware.bin firmware/makehex.py
	$(PYTHON) firmware/makehex.py $< 4096 > $@

firmware: firmware/firmware.mem firmware/firmware.o

# --- General ---

.PHONY: all

cleanall:
	rm -r -f *.vvp *.fst *.fst.hier *.vcd *.log *.json *.asc *.bin *.bit firmware/rle/*.o firmware/*.o firmware/*.elf firmware/*.bin firmware/firmware.map preprocessed.v cv32e40x_yosys.v abc.history sim_build results.xml
