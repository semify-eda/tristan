ifndef TRISTAN_ROOT
  $(error TRISTAN_ROOT is not set. Source sourceme.bash first: source sourceme.bash)
endif
ifndef WFG_ROOT
  $(error WFG_ROOT is not set. Source sourceme.bash first: source sourceme.bash)
endif

PYTHON ?= python3
TOOLCHAIN_PREFIX ?= riscv32-unknown-elf-

# ── Source files (packages first, then modules) ───────────────────────────────

# 1. Packages (must come before any module that imports them)
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/cv32e40x/rtl/include/cv32e40x_pkg.sv
VERILOG_SOURCES += $(WFG_ROOT)/design/pkg/wfg_pkg.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/include/soc_pkg.sv

# 2. CV32E40X RTL (all 45 modules)
VERILOG_SOURCES += $(wildcard $(TRISTAN_ROOT)/core/cv32e40x/rtl/*.sv)

# 3. Behavioral clock gate (replaces ASIC/FPGA primitive for simulation)
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/cv32e40x/bhv/cv32e40x_sim_clock_gate.sv

# 4. SoC RTL
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/core_sram.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/cv32e40x_soc.sv

# 5. Custom extensions
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/coproc/rtl/coproc_pkg.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/coproc/rtl/coproc.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/coproc/rtl/rshifter32.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/obi_wb_bridge/rtl/obi_wb_bridge.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/ram_arbiter/rtl/ram_arbiter.sv
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/custom/wb_ram_interface/rtl/wb_ram_interface.sv

# 6. WFG Timer (peripheral connected via Wishbone)
VERILOG_SOURCES += $(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer_wishbone_reg.sv
VERILOG_SOURCES += $(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer.sv
VERILOG_SOURCES += $(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer_top.sv

# 7. Testbench
VERILOG_SOURCES += $(TRISTAN_ROOT)/core/testbench/top_tb.sv

# ── Include directories ────────────────────────────────────────────────────────
INCLUDE_DIRS := $(TRISTAN_ROOT)/core/cv32e40x/rtl/include/
INCLUDE_DIRS += $(TRISTAN_ROOT)/core/include/
INCLUDE_DIRS += $(WFG_ROOT)/design/pkg/

# ── Cocotb configuration ───────────────────────────────────────────────────────
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = top_tb
MODULE = top_tb
export PYTHONPATH := $(PYTHONPATH):$(TRISTAN_ROOT)/core/testbench/

ifeq ($(SIM),icarus)
  COMPILE_ARGS := $(addprefix -I,$(INCLUDE_DIRS))
  COMPILER_ARGS ?= -g2012
endif

ifeq ($(SIM),verilator)
  COMPILE_ARGS  := $(addprefix +incdir+,$(INCLUDE_DIRS))
  EXTRA_ARGS    +=  --no-timing\
									  --Wno-fatal\
										--trace\
										--trace-structs\
										-j 0
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

# ── Firmware ───────────────────────────────────────────────────────────────────
firmware:
	cd $(WFG_ROOT)/firmware && $(MAKE) riscv && cp riscv/firmware.mem $(TRISTAN_ROOT)/

# ── Cleanup ────────────────────────────────────────────────────────────────────
clean::
	rm -rf sim_build results.xml *.vcd *.fst *.fst.hier *.log firmware.mem

.PHONY: firmware
