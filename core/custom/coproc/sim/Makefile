#source files
SRC := ../rtl/rshifter32.sv
SRC += ../testbench/shifter_tb.sv



#defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
COMPILER_ARGS ?= -g2012

VERILOG_SOURCES += $(SRC)

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = shifter_tb

# MODULE is the basename of the Python test file
export PYTHONPATH := $(PYTHONPATH):../testbench/
MODULE = shifter_test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
