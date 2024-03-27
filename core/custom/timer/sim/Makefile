# source files
SRC := $(wildcard ../rtl/*.sv)
SRC += $(wildcard ../testbench/*.sv)


# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
COMPILER_ARGS := -I ../rtl/ -I ../testbench/
COMPILER_ARGS ?= -gc2012

VERILOG_SOURCES += $(SRC)

# TOPLEVEL is the name of teh toplevel module
TOPLEVEL = simple_timer_tb

# MODULE is the basename of the Python test file
export PYTHONPATH := $(PYTHONPATH):../testbench/
MODULE = test_simple_timer

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim