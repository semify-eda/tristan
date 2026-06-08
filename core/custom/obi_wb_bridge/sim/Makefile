ifndef TRISTAN_ROOT
  $(error TRISTAN_ROOT is not set. Run: export TRISTAN_ROOT=$$(pwd)  (from the repo root))
endif

# WFG_ROOT defaults to the vendored mirror so this sim runs standalone.
# When integrated into wfg-fpga, sourceme.bash sets WFG_ROOT explicitly.
# Must be exported — Verilator expands $(WFG_ROOT) from the environment.
export WFG_ROOT ?= $(TRISTAN_ROOT)/vendor/wfg

PYTHON ?= python3

# ── Source files (packages first) ─────────────────────────────────────────────

# Packages
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/cv32e40x/rtl/include/cv32e40x_pkg.sv
VERILOG_SOURCES += $(WFG_ROOT)/design/pkg/wfg_pkg.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/include/soc_pkg.sv

# CV32E40X RTL + behavioral clock gate
VERILOG_SOURCES += $(wildcard $(TRISTAN_ROOT)/core/cv32e40x/rtl/*.sv)
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/cv32e40x/bhv/cv32e40x_sim_clock_gate.sv

# SoC RTL
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/core_sram.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/cv32e40x_soc.sv

# Custom extensions
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/ise/rtl/ise_pkg.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/ise/rtl/coproc.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/ise/rtl/rshifter32.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/obi_wb_bridge/rtl/obi_wb_bridge.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/ram_arbiter/rtl/ram_arbiter.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/wb_ram_interface/rtl/wb_ram_interface.sv

# WFG Timer
VERILOG_SOURCES += $(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer_wishbone_reg.sv
VERILOG_SOURCES += $(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer.sv
VERILOG_SOURCES += $(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer_top.sv

# Wishbone arbiter
VERILOG_SOURCES += $(WFG_ROOT)/design/semify_common/wishbone/arbiter/rtl/wb_arbiter_2.sv

# Testbench
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/obi_wb_bridge/testbench/obi_wb_bridge_tb.sv

# ── Include directories ────────────────────────────────────────────────────────
INCLUDE_DIRS := $(TRISTAN_ROOT)/core/cv32e40x/rtl/include/
INCLUDE_DIRS += $(TRISTAN_ROOT)/core/include/
INCLUDE_DIRS += $(WFG_ROOT)/design/pkg/

# ── Cocotb configuration ───────────────────────────────────────────────────────
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = obi_wb_bridge_tb
MODULE = obi_wb_bridge_test
export PYTHONPATH := $(PYTHONPATH):$(TRISTAN_ROOT)/core/custom/obi_wb_bridge/testbench/

ifeq ($(SIM),verilator)
  COMPILE_ARGS  := $(addprefix +incdir+,$(INCLUDE_DIRS))
  EXTRA_ARGS    += --no-timing --trace --Wno-fatal
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf sim_build results.xml *.vcd *.fst *.fst.hier *.log
