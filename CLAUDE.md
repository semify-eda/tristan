# CLAUDE.md — Tristan (RISC-V Subsystem)

This file provides guidance to Claude Code when working in the `design/tristan/` subdirectory.

> **Keep this file up to date.** Update it whenever the SoC structure, Makefile conventions, or simulation flow changes.

## Subsystem Overview

Tristan is a RISC-V SoC built around the **CV32E40X** 32-bit embedded core (RV32IA). It is integrated into SmartWave to run firmware that drives the WFG peripheral bus. The SoC connects to WFG peripherals (e.g. `wfg_timer`) via a Wishbone bus.

Key components:

| Component | Path | Description |
|---|---|---|
| CV32E40X core | `core/cv32e40x/rtl/` | 45-file RISC-V CPU RTL |
| SoC top | `core/cv32e40x_soc.sv` | Integrates core + SRAM + co-processor + bridge |
| SRAM | `core/core_sram.sv` | Shared instruction/data memory |
| Co-processor | `core/custom/coproc/rtl/` | XIF custom RLE compression co-processor |
| OBI→WB bridge | `core/custom/obi_wb_bridge/rtl/` | Connects core data bus to Wishbone peripherals |
| RAM arbiter | `core/custom/ram_arbiter/rtl/` | Arbitrates CPU vs. Wishbone access to SRAM |
| WB RAM interface | `core/custom/wb_ram_interface/rtl/` | Wishbone slave for SRAM access |
| SoC package | `core/include/soc_pkg.sv` | Address map, type definitions |
| Core package | `core/cv32e40x/rtl/include/cv32e40x_pkg.sv` | Core parameters, enums |
| Testbench top | `core/testbench/top_tb.sv` | Connects SoC + WFG timer for sim |

## Environment Setup

```bash
source sourceme.bash    # sets $WFG_ROOT and $TRISTAN_ROOT
```

Both variables are required by all Makefiles. If they are unset, make will abort with an error message.

## Simulation

### Root-level simulation (full SoC)

```bash
cd design/tristan
make              # Verilator (default)
make SIM=icarus   # Icarus Verilog
make TESTCASE=<fn>  # single test
make clean
```

The Python testbench module is `top_tb` in `core/testbench/`.

### Module-level simulations

```bash
# Co-processor shifter
cd design/tristan/core/custom/coproc/sim
make

# OBI → Wishbone bridge (full SoC context)
cd design/tristan/core/custom/obi_wb_bridge/sim
make

# Wishbone RAM interface
cd design/tristan/core/custom/wb_ram_interface/sim
make
```

### Firmware

```bash
cd design/tristan
make firmware   # builds RISC-V firmware and copies firmware.mem here
```

This invokes `$(WFG_ROOT)/firmware/Makefile` (`make riscv`). The RISC-V GNU toolchain must be on `PATH` (see README.md).

## Architecture

### Memory Map (from `core/include/soc_pkg.sv`)

The SoC boot address is `0x0200_0000`. Wishbone peripherals (including WFG) are mapped above the SRAM range.

### Clock domains

- `core_clk` — CV32E40X and SRAM (25 MHz in testbench)
- `wfg_clk` — WFG Wishbone peripherals (same clock in testbench)

### XIF Co-processor Interface

The CV32E40X connects to the co-processor via the **eXtension Interface (XIF)**. The `coproc.sv` module implements a right-shift accelerator used for RLE compression in firmware. Custom instructions reduce code size by ~33% and improve throughput by ~50%.

## Makefile Conventions

All Makefiles follow the same pattern as `design/wfg/*/sim/Makefile`:

- `SIM ?= verilator` — Verilator is the default
- `EXTRA_ARGS += --no-timing --trace --Wno-fatal` — required; see Known Issues below
- `COMPILE_ARGS := $(addprefix +incdir+,$(INCLUDE_DIRS))` — for Verilator
- `ifndef TRISTAN_ROOT` / `ifndef WFG_ROOT` guards abort make with a clear error if environment is not sourced

### Source file ordering

Packages must be listed before any module that imports them:

1. `cv32e40x_pkg.sv` (from `rtl/include/`)
2. `wfg_pkg.sv` (from `WFG_ROOT/design/pkg/`)
3. `soc_pkg.sv` (from `core/include/`)
4. `cv32e40x/rtl/*.sv` (all core modules, via wildcard)
5. `cv32e40x/bhv/cv32e40x_sim_clock_gate.sv` (behavioral clock gate — simulation only)
6. SoC files: `core_sram.sv`, `cv32e40x_soc.sv`, `simpleuart.v`
7. Custom extensions: `coproc_pkg.sv`, `coproc.sv`, `rshifter32.sv`, `obi_wb_bridge.sv`, `ram_arbiter.sv`, `wb_ram_interface.sv`
8. WFG peripherals: `wfg_timer_*.sv`
9. Testbench last

### Files intentionally excluded from simulation

| File/directory | Reason |
|---|---|
| `core/cv32e40x/sva/` | Formal verification assertions — not needed for simulation, can cause Verilator issues |
| `core/cv32e40x/bhv/cv32e40x_rvfi*.sv` | RVFI verification trace — verification-only, not part of DUT |
| `core/cv32e40x_yosys.v` | Legacy sv2v artifact — no longer generated or used |
| `core/cva6/` | Alternative core submodule — not part of this simulation flow |
| `core/riscv-dbg/` | Debug transport — not instantiated in testbench |

## Known Issues

### Verilator 5.046 `--timing` bug

**Never use `--timing`.** Use `--no-timing --Wno-fatal` instead.

Verilator 5.046 generates a `std::process` coroutine wrapper with member `m_process`, but the bundled `verilated_std.sv` comparison operators reference `__PVT__m_process`, causing a C++ compile error whenever `fork`/`join`, `disable`, or `#delay` constructs are present. This affects the CV32E40X RTL.

**Workaround:** `--no-timing` silently skips all `#delay` statements (zero delay). This is safe for the CV32E40X simulation flow.

See also: root `CLAUDE.md` § Known Issues for full background.

### Missing `cv32e40x_yosys.v`

This file was a legacy artifact generated by running `sv2v` on the CV32E40X RTL for Icarus Verilog compatibility. It is no longer needed: Verilator handles SystemVerilog natively. The file should not be generated or checked in.
