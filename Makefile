TOOLCHAIN_PREFIX ?= riscv32-unknown-elf-
PYTHON ?= tabbypy3

GCC_WARNS  = -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual -Wcast-align -Wwrite-strings
GCC_WARNS += -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes -pedantic #-Wconversion -Werror

# Sources
INCLUDE = core/cv32e40x/rtl/include/cv32e40x_pkg.sv

RTL = 	$(wildcard core/cv32e40x/rtl/*.sv) \
	core/cv32e40x_top.sv

RTL_CUSTOM = $(wildcard core/custom/*.sv)

SRC = 	core/cv32e40x_yosys.v \
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
core/cv32e40x_yosys.v: core/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v
	yosys -l $(basename $@)-yosys.log -DSYNTHESIS -p 'read -sv core/tech/rtl/cv32e40x_clock_gate.sv preprocessed.v; hierarchy -top cv32e40x_top; proc; flatten; opt; fsm; opt; write_verilog -noattr core/cv32e40x_yosys.v' 

all: firmware core/cv32e40x_yosys.v
	echo ""

# --- General ---

.PHONY: all

cleanall:
	rm -r -f *.vvp *.fst *.fst.hier *.vcd *.log *.json *.asc *.bin *.bit preprocessed.v abc.history sim_build results.xml
