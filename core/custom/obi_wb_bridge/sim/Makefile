#source files
SRC := ../../../../pkg/wfg_pkg.sv 
SRC += $(wildcard ../rtl/*.sv)
SRC += ../testbench/obi_wb_bridge_tb.sv

# SoC modules
SRC +=  ../../../../soc_tristan/cv32e40x_yosys.v \
		../../../../soc_tristan/core/cv32e40x_soc.sv \
		../../../../soc_tristan/core/simpleuart.v \
		../../../../soc_tristan/core/core_sram.sv


#defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
COMPILE_ARGS := -I ../rtl/ -I ../testbench/ -I ../../../../soc_tristan/ -I ../../../../soc_tristan/core/
COMPILER_ARGS ?= -g2012

VERILOG_SOURCES += $(SRC)

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = obi_wb_bridge_tb

# MODULE is the basename of the Python test file
export PYTHONPATH := $(PYTHONPATH):../testbench/
MODULE = obi_wb_bridge_test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

firmware0:
	if ! [ -d firmware ]; then \
		mkdir firmware; \
	fi

firmware1: firmware0
	make -C ../../../../soc_tristan firmware/firmware.hex

firmware: firmware1
	cp ../../../../soc_tristan/firmware/firmware.hex firmware/firmware.hex

preprocessed:
	make -C ../../../../soc_tristan cv32e40x_yosys.v

asm1:
	make -C ../../../../soc_tristan firmware/firmware.o

asm: asm1
	cp ../../../../soc_tristan/firmware/firmware.o firmware/firmware.o

cleanall1:
	rm -r -f *.vcd *.fst sim_build results.xml firmware

cleanall: cleanall1
	make -C ../../../../soc_tristan clean

all: firmware preprocessed asm
	echo ""