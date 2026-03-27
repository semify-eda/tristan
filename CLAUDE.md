# CLAUDE.md — Tristan (RISC-V Subsystem)

This file provides guidance to Claude Code when working in the `design/tristan/` subdirectory.

> **Keep this file up to date.** Update it whenever the SoC structure, Makefile conventions, or simulation flow changes.

## Subsystem Overview

Tristan is a RISC-V SoC that supports two core variants selectable via `CORE=`:

| `CORE=` | Core | ISA | Source list |
|---|---|---|---|
| `cv32e40x` (default) | CV32E40X | RV32IA | `core/cv32e40x_soc.f` |
| `cv32a60x` | CVA6 cv32a60x | RV32IMA | `core/cv32a60x_soc.f` |

It is integrated into SmartWave to run firmware that drives the WFG peripheral bus. The SoC connects to WFG peripherals (e.g. `wfg_timer`) via a Wishbone bus.

**Shared components (both cores):**

| Component | Path | Description |
|---|---|---|
| ISE package | `core/custom/ise/rtl/ise_pkg.sv` | Types and enums for XIF Instruction Set Extension |
| Rotate-shift unit | `core/custom/ise/rtl/rshifter32.sv` | 32-bit right-shift / rotate-right primitive |
| OBI→WB bridge | `core/custom/obi_wb_bridge/rtl/` | Connects core data bus to Wishbone peripherals |
| WB RAM interface | `core/custom/wb_ram_interface/rtl/` | Wishbone slave for SRAM access |
| SoC package | `core/include/soc_pkg.sv` | Address map, type definitions |
| Testbench top | `core/testbench/top_tb.sv` | Connects SoC + WFG timer for sim |

**CV32E40X-specific:**

| Component | Path | Description |
|---|---|---|
| CV32E40X core | `core/cv32e40x/rtl/` | 45-file RISC-V CPU RTL |
| SoC top | `core/cv32e40x_soc.sv` | Integrates core + SRAM + ISE + bridge |
| SRAM | `core/core_sram.sv` | Shared instruction/data memory |
| ISE | `core/custom/ise/rtl/coproc.sv` | XIF Instruction Set Extension (CV32E40X port) |
| RAM arbiter | `core/custom/ram_arbiter/rtl/` | Arbitrates CPU vs. Wishbone access to SRAM |
| Core package | `core/cv32e40x/rtl/include/cv32e40x_pkg.sv` | Core parameters, enums |

**CVA6-specific:**

| Component | Path | Description |
|---|---|---|
| CVA6 core | `core/cva6/` | CVA6 cv32a60x RISC-V CPU RTL (submodule) |
| SoC top | `core/cv32a60x_soc.sv` | Integrates CVA6 + SRAM + ISE + bridge |
| SRAM | `core/core_sram_patched.sv` | Per-byte-lane dual-port BRAM (Vivado-friendly) |
| ISE | `core/custom/ise/rtl/ise_cv32a60x.sv` | XIF Instruction Set Extension (CVA6/CVXIF port) |
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
make                        # CVA6 core, Verilator (default)
make CORE=cv32e40x          # CV32E40X core
make SIM=icarus             # Icarus Verilog (CV32E40X only)
make TESTCASE=<fn>          # single test
make FIRMWARE=ise_test      # override firmware variant (default: custom_ext)
make clean
```

The Python testbench module is `top_tb` in `core/testbench/`.

The same `top_tb.sv` / `top_tb.py` testbench is shared by both cores. It instantiates `tristan_soc` (the SoC top module name in both `cv32e40x_soc.sv` and `cv32a60x_soc.sv`).

### Module-level simulations

```bash
# ISE shifter
cd design/tristan/core/custom/ise/sim
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
make firmware                       # build custom_ext (default) → firmware.mem
make firmware FIRMWARE=ise_test     # build ise_test variant instead
```

Runs `make $(FIRMWARE)` in `$(WFG_ROOT)/firmware/` and copies the result to `$(TRISTAN_ROOT)/firmware.mem`. The RISC-V GNU toolchain must be on `PATH` (see README.md).

## Architecture

### Memory Map (from `core/include/soc_pkg.sv`)

The SoC boot address is `0x0200_0000`. Wishbone peripherals (including WFG) are mapped above the SRAM range.

### Clock domains

- `core_clk` — CV32E40X and SRAM (25 MHz in testbench)
- `wfg_clk` — WFG Wishbone peripherals (same clock in testbench)

### XIF Instruction Set Extension Interface

Both cores connect to the ISE via the **eXtension Interface (XIF)**:
- CV32E40X uses `coproc.sv` (XIF 0.9 subset)
- CVA6 uses `ise_cv32a60x.sv` (CVXIF protocol)

The ISE implements a right-shift / rotate-right accelerator (`rshifter32.sv`) used for RLE compression in firmware. Custom instructions reduce code size by ~33% and improve throughput by ~50%.

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

Files in this project that use this pattern: `ise_cv32a60x.sv`, `cv32a60x_soc.sv`, `obi_wb_bridge.sv`, `obi_data_bus_arbiter.sv`.

### Testbench: cocotb WishboneSlave is an active driver

`cocotbext-wishbone`'s `WishboneSlave` **drives** the signals listed in its `signals_dict` — it is not a passive monitor. In `top_tb.sv`, `default_ack` and `default_dat` are driven exclusively by the cocotb slave. **Do not assign these signals from RTL** (`assign default_ack = ...`). A multi-driver conflict causes Verilator's RTL assignment to win every evaluation cycle, preventing cocotb from ever deasserting `ack`, which stalls the slave's state machine and records 0 transactions.

## Makefile Conventions

All Makefiles follow the same pattern as `design/wfg/*/sim/Makefile`:

- `SIM ?= verilator` — Verilator is the default
- `EXTRA_ARGS += --no-timing --trace --Wno-fatal` — required; see Known Issues below
- `COMPILE_ARGS := $(addprefix +incdir+,$(INCLUDE_DIRS))` — for Verilator
- `ifndef TRISTAN_ROOT` / `ifndef WFG_ROOT` guards abort make with a clear error if environment is not sourced

### Source file ordering

Packages must be listed before any module that imports them. The `.f` filelists (`cv32e40x_soc.f`, `cv32a60x_soc.f`) define the canonical order. For CV32E40X:

1. Packages: `soc_pkg.sv`, `cv32e40x_pkg.sv`, `wfg_pkg.sv`
2. `cv32e40x/bhv/cv32e40x_sim_clock_gate.sv` (behavioral clock gate — simulation only)
3. `cv32e40x/rtl/*.sv` (all core modules, explicitly listed)
4. ISE: `ise_pkg.sv`, `coproc.sv`, `rshifter32.sv`
5. WFG peripherals: `wfg_timer_wishbone_reg.sv`, `wfg_timer.sv`, `wfg_timer_top.sv`
6. SoC modules: `obi_wb_bridge.sv`, `ram_arbiter.sv`, `wb_ram_interface.sv`, `core_sram.sv`, `cv32e40x_soc.sv`
7. `+incdir+` entries last
8. Testbench last (not in `.f` — added by Makefile)

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

### CVA6 `obi_data_bus_arbiter`: Flat bus corruption — **FIXED**

**File:** `core/custom/data_bus_arbiter/rtl/obi_data_bus_arbiter.sv`

**Symptom (resolved):** When running with `CORE=cv32a60x`, the ISE's RMST instruction wrote 0 to DRAM instead of the computed value. This caused the wfg stimuli SRAM to receive wrong sample data, producing incorrect DAC output (`d_a=5` instead of `d_a=4`). CV32E40X was unaffected.

#### Root cause

CVA6 exposes separate OBI store and load buses. The arbiter's `flat_wdata` mux is combinatorial and priority-driven: `store > load > ISE`. When the ISE entered state MEM_WR1 and asserted `obi_ise_req_i=1`, it presented `obi_ise_wdata_i=0` on the first cycle — this is **OBI-compliant**: the protocol only requires wdata to be stable at the grant cycle, not at the request cycle.

The arbiter latched the entire flat bus (including wdata) at the **request-acceptance cycle** (cycle N), capturing `wdata=0`. One cycle later (cycle N+1, when `flat_gnt=1`), the ISE had updated `obi_ise_wdata_i` to the correct value (`0x0ebe0000`), but the SRAM write used the already-frozen latch value of 0.

On CV32E40X there is no latch — its `ram_arbiter` drives SRAM signals combinatorially — so the SRAM always sees the live wdata at the write edge, which happens to be the cycle when the ISE's data is ready.

#### Simulation evidence

Both cores write `0x000000000ebe0000` to `wbuf` at an earlier RMLD. Wbuf resets to 0 one to two clocks before the critical MEM_WR1. At MEM_WR1: CV32E40X's `d_a` (SRAM write data) = `0x0ebe0000`; CVA6's `d_a` = 0 — confirming the write used the stale latch value. The subsequent MEM_RD1 of the same address then reads back 0, and `rbuf`/`wbuf` stay 0 for all later iterations, producing wrong sample data.

#### Fix applied

`flat_wdata_active` now reads the **live signal from the owning master** while `arb_busy=1`, identified by `arb_sel_*_q`, instead of the latched value. This is safe because `flat_req` is suppressed while busy (no competing master can change the mux), and the owning master is guaranteed to hold wdata stable from req until gnt per OBI protocol.

`addr`, `be`, `we`, and `select` signals continue to use the latch — they are correct from the request cycle and must be frozen to prevent address/control corruption if a higher-priority request arrives while busy.

```sv
// addr/be/we/select: latched at accept cycle — frozen against concurrent requests
assign flat_addr_active        = arb_busy ? flat_addr_latch        : flat_addr;
assign flat_be_active          = arb_busy ? flat_be_latch          : flat_be;
assign flat_we_active          = arb_busy ? flat_we_latch          : flat_we;
assign flat_select_dmem_active = arb_busy ? flat_select_dmem_latch : flat_select_dmem;
assign flat_select_wb_active   = arb_busy ? flat_select_wb_latch   : flat_select_wb;

// wdata: live signal from owning master — valid at gnt cycle (one cycle after req)
assign flat_wdata_active = arb_busy ?
    (arb_sel_store_q  ? obi_cpudata_store_req_i.a.wdata :
     arb_sel_ise_q    ? obi_ise_wdata_i                  :
                        obi_cpudata_load_req_i.a.wdata)  :
    flat_wdata;
```

**Priority order:** Store (highest) > Load > ISE (lowest).

**Note:** This only affects CVA6. CV32E40X uses `ram_arbiter` (single data bus) and `core_sram.sv`, so this race cannot occur.

### Verilator 5.046 `--timing` bug

**Never use `--timing`.** Use `--no-timing --Wno-fatal` instead.

Verilator 5.046 generates a `std::process` coroutine wrapper with member `m_process`, but the bundled `verilated_std.sv` comparison operators reference `__PVT__m_process`, causing a C++ compile error whenever `fork`/`join`, `disable`, or `#delay` constructs are present. This affects the CV32E40X RTL.

**Workaround:** `--no-timing` silently skips all `#delay` statements (zero delay). This is safe for the CV32E40X simulation flow.

See also: root `CLAUDE.md` § Known Issues for full background.

### Missing `cv32e40x_yosys.v`

This file was a legacy artifact generated by running `sv2v` on the CV32E40X RTL for Icarus Verilog compatibility. It is no longer needed: Verilator handles SystemVerilog natively. The file should not be generated or checked in.

### BRAM preload not supported in synthesis (`core_sram_patched.sv`)

The CVA6 SRAM (`core_sram_patched.sv`) splits memory into per-byte-lane 8-bit BRAMs via a `generate` loop. The `$readmemh` call is wrapped in `// synthesis translate_off / // synthesis translate_on` and is **simulation-only**. Vivado cannot follow the intermediate temp-array + for-loop pattern to initialize the inferred BRAMs, so the SRAM always powers up as zero in hardware. The firmware must be loaded via another mechanism (e.g. JTAG, UART bootloader, or a BRAM IP with a `.coe` file).
