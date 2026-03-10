ifndef TRISTAN_ROOT
  $(error TRISTAN_ROOT is not set. Source sourceme.bash first: source sourceme.bash)
endif

# ── Source files ───────────────────────────────────────────────────────────────
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/coproc/rtl/rshifter32.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/coproc/testbench/shifter_tb.sv

# ── Cocotb configuration ───────────────────────────────────────────────────────
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = shifter_tb
MODULE = shifter_test
export PYTHONPATH := $(PYTHONPATH):$(TRISTAN_ROOT)/core/custom/coproc/testbench/

ifeq ($(SIM),icarus)
  COMPILER_ARGS ?= -g2012
endif

ifeq ($(SIM),verilator)
  EXTRA_ARGS += --no-timing --trace --Wno-fatal
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf sim_build results.xml *.vcd *.fst *.fst.hier *.log
