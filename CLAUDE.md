# CLAUDE.md — Tristan (RISC-V Subsystem)

This file provides guidance to Claude Code when working in the `design/tristan/` subdirectory.

> **Keep this file up to date.** Update it whenever the SoC structure, Makefile conventions, or simulation flow changes.

## Subsystem Overview

Tristan is a RISC-V SoC that supports two core variants selectable via `CORE=`:

| `CORE=` | Core | ISA | Source list |
|---|---|---|---|
| `cv32e40x` (default) | CV32E40X | RV32IA | `core/cv32e40x_soc.f` |
| `cv32a60x` | CVA6 cv32a60x | RV32IMA | `core/cva6_soc.f` |

It is integrated into SmartWave to run firmware that drives the WFG peripheral bus. The SoC connects to WFG peripherals (e.g. `wfg_timer`) via a Wishbone bus.

**Shared components (both cores):**

| Component | Path | Description |
|---|---|---|
| Co-processor package | `core/custom/coproc/rtl/coproc_pkg.sv` | Types and enums for XIF co-processor |
| Rotate-shift unit | `core/custom/coproc/rtl/rshifter32.sv` | 32-bit right-shift / rotate-right primitive |
| OBI→WB bridge | `core/custom/obi_wb_bridge/rtl/` | Connects core data bus to Wishbone peripherals |
| WB RAM interface | `core/custom/wb_ram_interface/rtl/` | Wishbone slave for SRAM access |
| SoC package | `core/include/soc_pkg.sv` | Address map, type definitions |
| Testbench top | `core/testbench/top_tb.sv` | Connects SoC + WFG timer for sim |

**CV32E40X-specific:**

| Component | Path | Description |
|---|---|---|
| CV32E40X core | `core/cv32e40x/rtl/` | 45-file RISC-V CPU RTL |
| SoC top | `core/cv32e40x_soc.sv` | Integrates core + SRAM + co-processor + bridge |
| SRAM | `core/core_sram.sv` | Shared instruction/data memory |
| Co-processor | `core/custom/coproc/rtl/coproc.sv` | XIF co-processor (CV32E40X port) |
| RAM arbiter | `core/custom/ram_arbiter/rtl/` | Arbitrates CPU vs. Wishbone access to SRAM |
| Core package | `core/cv32e40x/rtl/include/cv32e40x_pkg.sv` | Core parameters, enums |

**CVA6-specific:**

| Component | Path | Description |
|---|---|---|
| CVA6 core | `core/cva6/` | CVA6 cv32a60x RISC-V CPU RTL (submodule) |
| SoC top | `core/cva6_soc.sv` | Integrates CVA6 + SRAM + co-processor + bridge |
| SRAM | `core/core_sram_patched.sv` | Per-byte-lane dual-port BRAM (Vivado-friendly) |
| Co-processor | `core/custom/coproc/rtl/coproc_cv32a60x.sv` | XIF co-processor (CVA6/CVXIF port) |
| Data bus arbiter | `core/custom/data_bus_arbiter/rtl/` | Arbitrates instruction vs. data OBI access |

## Environment Setup

```bash
source sourceme.bash    # sets $WFG_ROOT and $TRISTAN_ROOT
```

Both variables are required by all Makefiles. If they are unset, make will abort with an error message.

## Simulation

### Root-level simulation (full SoC)

```bash
cd design/tristan
make                      # CV32E40X core, Verilator (default)
make CORE=cv32a60x        # CVA6 core
make SIM=icarus           # Icarus Verilog (CV32E40X only)
make TESTCASE=<fn>        # single test
make clean
```

The Python testbench module is `top_tb` in `core/testbench/`.

The same `top_tb.sv` / `top_tb.py` testbench is shared by both cores. It instantiates `tristan_soc` (the SoC top module name in both `cv32e40x_soc.sv` and `cva6_soc.sv`).

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

Both cores connect to the co-processor via the **eXtension Interface (XIF)**:
- CV32E40X uses `coproc.sv` (XIF 0.9 subset)
- CVA6 uses `coproc_cv32a60x.sv` (CVXIF protocol)

The co-processor implements a right-shift / rotate-right accelerator (`rshifter32.sv`) used for RLE compression in firmware. Custom instructions reduce code size by ~33% and improve throughput by ~50%.

## Coding Conventions

### `` `default_nettype `` guard

Every RTL file that opens with `` `default_nettype none `` **must** close with `` `default_nettype wire `` after `endmodule`. Without the footer, the `none` directive bleeds into every subsequently compiled file (both in Verilator and Vivado), causing spurious "net type must be explicitly specified" errors in files that are otherwise correctly written.

```sv
`default_nettype none     // ← top of file
module my_module ( ... );
  ...
endmodule
`default_nettype wire     // ← mandatory footer, always present
```

Files in this project that use this pattern: `coproc_cv32a60x.sv`, `cva6_soc.sv`, `obi_wb_bridge.sv`, `obi_data_bus_arbiter.sv`.

### Testbench: cocotb WishboneSlave is an active driver

`cocotbext-wishbone`'s `WishboneSlave` **drives** the signals listed in its `signals_dict` — it is not a passive monitor. In `top_tb.sv`, `default_ack` and `default_dat` are driven exclusively by the cocotb slave. **Do not assign these signals from RTL** (`assign default_ack = ...`). A multi-driver conflict causes Verilator's RTL assignment to win every evaluation cycle, preventing cocotb from ever deasserting `ack`, which stalls the slave's state machine and records 0 transactions.

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
| `core/cva6/corev_apu/`, `core/cva6/verif/` | CVA6 subsystem-level testbenches — not part of this SoC sim flow |
| `core/riscv-dbg/` | Debug transport — not instantiated in testbench |

## Vivado Synthesis (CVA6 variant)

The CVA6+XIF Vivado project lives under `vivado/wfg_cv32a60x/cva6_with_xif/` (relative to the repo root). Steps:

1. **Build firmware** — `cd design/tristan && make firmware` (copies `firmware.mem` here; see BRAM preload limitation below)
2. **Open Vivado 2023.2** and create or open the project
3. **Add sources** — in the Tcl console: `source vivado/wfg_cv32a60x/cva6_with_xif/vivado_add_sources.tcl`
   - Edit `TRISTAN_ROOT` and `WFG_ROOT` at the top of the script to match your machine before sourcing
   - This adds all RTL sources in the correct order and sets `tristan_soc` as the synthesis top
4. **Run implementation** — Flow Navigator → Generate Bitstream (or use the make-release-bitstream.tcl script)
5. **Package release** — `python make-release.py` from the repo root

## Known Issues

### Verilator 5.046 `--timing` bug

**Never use `--timing`.** Use `--no-timing --Wno-fatal` instead.

Verilator 5.046 generates a `std::process` coroutine wrapper with member `m_process`, but the bundled `verilated_std.sv` comparison operators reference `__PVT__m_process`, causing a C++ compile error whenever `fork`/`join`, `disable`, or `#delay` constructs are present. This affects the CV32E40X RTL.

**Workaround:** `--no-timing` silently skips all `#delay` statements (zero delay). This is safe for the CV32E40X simulation flow.

See also: root `CLAUDE.md` § Known Issues for full background.

### Missing `cv32e40x_yosys.v`

This file was a legacy artifact generated by running `sv2v` on the CV32E40X RTL for Icarus Verilog compatibility. It is no longer needed: Verilator handles SystemVerilog natively. The file should not be generated or checked in.

### BRAM preload not supported in synthesis (`core_sram_patched.sv`)

The CVA6 SRAM (`core_sram_patched.sv`) splits memory into per-byte-lane 8-bit BRAMs via a `generate` loop. The `$readmemh` call is wrapped in `// synthesis translate_off / // synthesis translate_on` and is **simulation-only**. Vivado cannot follow the intermediate temp-array + for-loop pattern to initialize the inferred BRAMs, so the SRAM always powers up as zero in hardware. The firmware must be loaded via another mechanism (e.g. JTAG, UART bootloader, or a BRAM IP with a `.coe` file).
