SRC += ../../../include/soc_pkg.sv
SRC += $(wildcard ../rtl/*.sv)
SRC += $(wildcard ../testbench/*.sv)
SRC += ../../../core_sram.sv

#defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
COMPILE_ARGS := -I ../rtl/ -I ../testbench/ -I ../../../
COMPILER_ARGS ?= -g2012

VERILOG_SOURCES += $(SRC)

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = wb_ram_tb

# MODULE is the basename of the Python test file
export PYTHONPATH := $(PYTHONPATH):../testbench/
MODULE = wb_ram_test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

iram.hex:
	tabbypy3 generate_data.py 32 4096 > $@

dram.hex:
	tabbypy3 generate_data.py 32 4096 > $@

data: iram.hex dram.hex

cleanall:
	rm -r *.hex

.PHONY: cleanall data