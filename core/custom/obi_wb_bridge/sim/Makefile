#source files
# SRC := ../../../../pkg/wfg_pkg.sv 
SRC += $(wildcard ../rtl/*.sv)
SRC += ../testbench/obi_wb_bridge_tb.sv
SRC += ../../../include/soc_pkg.sv
SRC += ../../wb_ram_interface/rtl/wb_ram_interface.sv
SRC += ../../../../../pkg/wfg_pkg.sv
SRC += ../../../../../wfg/wfg_timer/rtl/wfg_timer_wishbone_reg.sv
SRC += ../../../../../wfg/wfg_timer/rtl/wfg_timer.sv
SRC += ../../../../../wfg/wfg_timer/rtl/wfg_timer_top.sv
SRC += ../../../../../semify_common/wishbone/arbiter/rtl/wb_arbiter_2.sv


# SoC modules
SRC +=  ../../../cv32e40x_yosys.v \
		../../../cv32e40x_soc.sv \
		../../../simpleuart.v \
		../../../core_sram.sv \
		../../ram_arbiter/rtl/ram_arbiter.sv \


#defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
COMPILE_ARGS := -I ../rtl/ -I ../testbench/ -I ../../../../ -I ../../../
COMPILER_ARGS ?= -g2012

VERILOG_SOURCES += $(SRC)

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = obi_wb_bridge_tb

# MODULE is the basename of the Python test file
export PYTHONPATH := $(PYTHONPATH):../testbench/
MODULE = obi_wb_bridge_test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
