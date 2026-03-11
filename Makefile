ifndef TRISTAN_ROOT
  $(error TRISTAN_ROOT is not set. Source sourceme.bash first: source sourceme.bash)
endif
ifndef WFG_ROOT
  $(error WFG_ROOT is not set. Source sourceme.bash first: source sourceme.bash)
endif

PYTHON ?= python3
TOOLCHAIN_PREFIX ?= riscv32-unknown-elf-
CORE ?= cv32e40x

# ── Source files ───────────────────────────────────────────────────────────────
CV32E40X_SRC_FILES += $(TRISTAN_ROOT)/core/cv32e40x_soc.f

# ── Testbench ──────────────────────────────────────────────────────────────────
TESTBENCH += $(TRISTAN_ROOT)/core/testbench/top_tb.sv


# ── Cocotb configuration ───────────────────────────────────────────────────────
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOPLEVEL = top_tb
MODULE = top_tb
export PYTHONPATH := $(PYTHONPATH):$(TRISTAN_ROOT)/core/testbench/


# ── Select Core to Use ─────────────────────────────────────────────────────────
ifeq ($(CORE),cv32e40x)
	SRC_FILES := $(CV32E40X_SRC_FILES)
endif

ifeq ($(SIM),verilator)
  COMPILE_ARGS  :=  -f $(SRC_FILES) $(TESTBENCH)
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
