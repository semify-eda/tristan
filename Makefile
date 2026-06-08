ifndef TRISTAN_ROOT
  $(error TRISTAN_ROOT is not set. Run: export TRISTAN_ROOT=$$(pwd)  (from the repo root))
endif

# WFG_ROOT defaults to the vendored mirror so this repo simulates standalone.
# When integrated into wfg-fpga, sourceme.bash sets WFG_ROOT explicitly and
# this default is overridden.  Must be exported — the .f filelist uses
# $(WFG_ROOT) which Verilator expands from the environment, not from Make.
export WFG_ROOT ?= $(TRISTAN_ROOT)/vendor/wfg

PYTHON ?= python3
CORE   ?= cv32a60x

# ── Source files ───────────────────────────────────────────────────────────────
CV32E40X_SRC_FILES += $(TRISTAN_ROOT)/core/cv32e40x_soc.f
CV32A60X_SRC_FILES += $(TRISTAN_ROOT)/core/cv32a60x_soc.f
# Print only when actually running a simulation target, not for clean/firmware.
# $(MAKECMDGOALS) is empty when the default target is invoked.
ifeq ($(filter clean firmware,$(MAKECMDGOALS)),)
  _ := $(info Running with Core: $(CORE))
endif

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
    EXTRA_ARGS    +=  -DCV32E40X
endif
ifeq ($(CORE),cv32a60x)
	SRC_FILES := $(CV32A60X_SRC_FILES)
	EXTRA_ARGS    +=  -DCV32A60X
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
# Build the minimum-working-example firmware.
# `make firmware` builds both variants + the dmem image (= `make all` inside
# firmware/) and stages the chosen variant as firmware/firmware.mem so the
# testbench's $readmemh picks it up.
#
#   make firmware                 # build all, stage base as firmware/firmware.mem
#   make firmware FW_VARIANT=ise  # build all, stage ise  as firmware/firmware.mem
#   make firmware FW_GOAL=base    # only build base
#   make firmware FW_GOAL=clean   # clean firmware/ (no staging)
FW_GOAL    ?= all
FW_VARIANT ?= base
firmware:
	$(MAKE) -C $(TRISTAN_ROOT)/firmware $(FW_GOAL)
	@if [ -f $(TRISTAN_ROOT)/firmware/build/$(FW_VARIANT)/firmware.mem ]; then \
		cp -f $(TRISTAN_ROOT)/firmware/build/$(FW_VARIANT)/firmware.mem $(TRISTAN_ROOT)/firmware/firmware.mem; \
		echo "Staged $(FW_VARIANT) build as firmware/firmware.mem"; \
	fi

# ── Cleanup ────────────────────────────────────────────────────────────────────
clean::
	rm -rf sim_build results.xml *.vcd *.fst *.fst.hier *.log *.dasm firmware.mem firmware/firmware.mem

.PHONY: firmware clean
