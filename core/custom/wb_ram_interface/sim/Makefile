ifndef TRISTAN_ROOT
  $(error TRISTAN_ROOT is not set. Run: export TRISTAN_ROOT=$$(pwd)  (from the repo root))
endif

PYTHON ?= python3

# ── Source files ───────────────────────────────────────────────────────────────
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/include/soc_pkg.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/wb_ram_interface/rtl/wb_ram_interface.sv
VERILOG_SOURCES += $(wildcard $(TRISTAN_ROOT)/core/custom/wb_ram_interface/testbench/*.sv)
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/core_sram.sv

# ── Include directories ────────────────────────────────────────────────────────
INCLUDE_DIRS := $(TRISTAN_ROOT)/core/include/

# ── Cocotb configuration ───────────────────────────────────────────────────────
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = wb_ram_tb
MODULE = wb_ram_test
export PYTHONPATH := $(PYTHONPATH):$(TRISTAN_ROOT)/core/custom/wb_ram_interface/testbench/

ifeq ($(SIM),verilator)
  COMPILE_ARGS  := $(addprefix +incdir+,$(INCLUDE_DIRS))
  EXTRA_ARGS    += --no-timing --trace --Wno-fatal
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

iram.hex:
	$(PYTHON) $(TRISTAN_ROOT)/core/custom/wb_ram_interface/sim/generate_data.py 32 4096 > $@

dram.hex:
	$(PYTHON) $(TRISTAN_ROOT)/core/custom/wb_ram_interface/sim/generate_data.py 32 4096 > $@

data: iram.hex dram.hex

clean::
	rm -rf sim_build results.xml *.vcd *.fst *.fst.hier *.log *.hex

.PHONY: data
