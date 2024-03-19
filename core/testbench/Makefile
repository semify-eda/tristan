# SoC modules
SRC := ../core_sram.sv
SRC += memory_test.sv

#defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
COMPILE_ARGS := -I ./ -I ../
COMPILER_ARGS ?= -g2012

VERILOG_SOURCES += $(SRC)

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = memory_test

# MODULE is the basename of the Python test file
export PYTHONPATH := $(PYTHONPATH):../testbench/
MODULE = memory_test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

tmp:
	make -C ../../ firmware/firmware.hex

all: tmp