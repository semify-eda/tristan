# CLAUDE.md — Tristan (RISC-V Subsystem)

This file provides guidance to Claude Code when working in the `design/tristan/` repository.

> **Keep this file up to date.** Update it whenever the SoC structure, Makefile conventions, or simulation flow changes.

## Subsystem Overview

Tristan is a self-contained RISC-V SoC that supports two core variants selectable via `CORE=`:

| `CORE=` | Core | ISA | Source list |
|---|---|---|---|
| `cv32a60x` (default) | CVA6 cv32a60x | RV32IMA | `core/cv32a60x_soc.f` |
| `cv32e40x` | CV32E40X | RV32IA | `core/cv32e40x_soc.f` |

The SoC connects to Wishbone peripherals via an OBI → WB bridge. For the integration product (SmartWave) and the benchmark/coverage data, see `README.md` § "Larger verification & demo framework".

**Shared components (both cores):**

| Component | Path | Description |
|---|---|---|
| ISE package | `core/custom/ise/rtl/ise_pkg.sv` | Types and enums for the XIF / CVXIF Instruction Set Extension |
| Rotate-shift unit | `core/custom/ise/rtl/rshifter32.sv` | 32-bit right-shift / rotate-right primitive |
| OBI → WB bridge | `core/custom/obi_wb_bridge/rtl/` | Connects core data bus to Wishbone peripherals |
| WB RAM interface | `core/custom/wb_ram_interface/rtl/` | Wishbone slave for SRAM access |
| SoC package | `core/include/soc_pkg.sv` | Address map, type definitions |
| Testbench top | `core/testbench/top_tb.sv` | Connects SoC + WFG timer for sim |

**CV32E40X-specific:**

| Component | Path | Description |
|---|---|---|
| CV32E40X core | `core/cv32e40x/rtl/` | RISC-V CPU RTL (submodule) |
| SoC top | `core/cv32e40x_soc.sv` | Integrates core + SRAM + ISE + bridge |
| SRAM | `core/core_sram.sv` | Shared instruction/data memory |
| ISE | `core/custom/ise/rtl/coproc.sv` | XIF Instruction Set Extension (CV32E40X port) |
| RAM arbiter | `core/custom/ram_arbiter/rtl/` | Arbitrates CPU vs. Wishbone access to SRAM |

**CVA6-specific:**

| Component | Path | Description |
|---|---|---|
| CVA6 core | `core/cva6/` | CVA6 cv32a60x RISC-V CPU RTL (submodule) |
| SoC top | `core/cv32a60x_soc.sv` | Integrates CVA6 + SRAM + ISE + bridge |
| SRAM | `core/core_sram_patched.sv` | Per-byte-lane dual-port BRAM (Vivado-friendly) |
| Patched CSR file | `core/csr_regfile_patched.sv` | Local patch of CVA6's `csr_regfile.sv` (referenced directly from `cv32a60x_soc.f`; the upstream submodule file is commented out in that filelist) |
| ISE | `core/custom/ise/rtl/ise_cv32a60x.sv` | XIF Instruction Set Extension (CVA6 / CVXIF port) |
| Data bus arbiter | `core/custom/data_bus_arbiter/rtl/` | Arbitrates instruction vs. data OBI access |

## Environment Setup

```bash
export TRISTAN_ROOT=$(pwd)        # from the repo root
```

`WFG_ROOT` defaults to `$(TRISTAN_ROOT)/vendor/wfg` (the vendored mirror — see **Vendoring** below). If integrating with the upstream wfg-fpga project, `export WFG_ROOT=/path/to/wfg-fpga` before running `make` to override.

Python deps for the testbench: `pip install -r requirements.txt`.

## Simulation

### Root-level simulation (full SoC)

```bash
make                       # CVA6 core (default), Verilator
make CORE=cv32e40x         # CV32E40X core variant
make clean                 # remove sim_build/, traces, staged firmware.mem
```

The testbench is shared by both cores — `core/testbench/top_tb.{sv,py}` instantiates `tristan_soc` (the module name in both `cv32e40x_soc.sv` and `cv32a60x_soc.sv`). At sim start it `$readmemh`s `firmware/firmware.mem` into IRAM and `firmware/signals/dmem.mem` into DRAM.

A cocotb `WishboneSlave` provides default `ack`/`dat` for non-timer addresses, and a small coroutine (`_wb_write_monitor`) prints `[MMIO] W @ <adr>  data=<dat>` on each WB write — sampled directly from the bus signals at the cycle where `cyc & stb & we & ack` are all high.

### Module-level simulations

Three independent cocotb testbenches:

```bash
cd core/custom/ise/sim              && make
cd core/custom/obi_wb_bridge/sim    && make
cd core/custom/wb_ram_interface/sim && make
```

## Firmware

A minimum-working-example firmware lives under `firmware/`. Single source `main/main.c`, built twice — once without and once with `-DCUSTOM_EXT` — producing `base` and `ise` variants. Both decode three BRLE-encoded 16-bit words from DMEM and write them to a Wishbone-mapped sink at `0x00100000`.

```bash
make firmware                       # build all + stage base/firmware.mem as firmware/firmware.mem
make firmware FW_VARIANT=ise        # stage ise variant instead
make firmware FW_GOAL=base          # only build base
make firmware FW_GOAL=dmem          # only build dmem image from signals/encoded.txt
make firmware FW_GOAL=clean         # clean firmware/
```

The top-level `firmware` target wraps `$(MAKE) -C firmware $(FW_GOAL)` and (for non-clean goals) `cp`s `firmware/build/$(FW_VARIANT)/firmware.mem` to `firmware/firmware.mem` for the testbench to pick up.

Build chain inside `firmware/`: `main.c + rle.c + start.S → firmware.elf → firmware.bin → firmware.mem (via scripts/makehex.py)`. The `dmem` target runs `scripts/generate_dmem.py` over `signals/encoded.txt` to produce `signals/dmem.mem` (header at byte 0x3E00, payload right after).

The base/ise distinction is purely a compile-time flag — `firmware/src/rle.c` has `#ifdef CUSTOM_EXT` branches in `extend_value()` and `copy_segment()` that emit ISE inline asm (RMLD / RMCS / RMXR / RMXS, defined in `firmware/include/instr.h`) instead of the software bit-manipulation path.

## Architecture

### Memory map

From `core/cv32a60x_soc.sv` (CV32E40X uses the same scheme):

- `addr[20] = 0` → INTERNAL: DRAM (block_sel 0, `0x000000–0x01FFFF`) / IRAM (block_sel 1, `0x020000–0x03FFFF`)
- `addr[20] = 1` → EXTERNAL: routes through OBI → WB bridge to peripherals at `0x100000+`

The bridge strips bit 20 on the way out, so a CPU write to `0x00100000` appears on the WB bus as `wb_addr_o = 0x00000000`.

### Clock domains

- `core_clk` — CPU + SRAM (25 MHz in testbench)
- `wfg_clk` — Wishbone peripherals (100 MHz in testbench)

### ISE interface

Both cores connect to the ISE via the **eXtension Interface (XIF / CVXIF)**:
- CV32E40X uses `coproc.sv` (XIF 0.9 subset)
- CVA6 uses `ise_cv32a60x.sv` (CVXIF protocol)

The ISE implements a right-shift / rotate-right accelerator (`rshifter32.sv`) used by the BRLE decoder. Hardware-measured speed-up on the larger framework's RLE-decompression workload: ~2× throughput, ~36 % smaller decode firmware (see `README.md` § Benchmark for full numbers).

## Coding Conventions

### `` `default_nettype `` guard

Every RTL file that opens with `` `default_nettype none `` **must** close with `` `default_nettype wire `` after `endmodule`. Without the footer, the `none` directive bleeds into every subsequently compiled file (both in Verilator and Vivado), causing spurious "net type must be explicitly specified" errors in unrelated files.

```sv
`default_nettype none     // ← top of file
module my_module ( ... );
  ...
endmodule
`default_nettype wire     // ← mandatory footer, always present
```

### Testbench: cocotb WishboneSlave is an active driver

`cocotbext-wishbone`'s `WishboneSlave` **drives** the signals listed in its `signals_dict` — it is not a passive monitor. In `top_tb.sv`, `default_ack` and `default_dat` are driven exclusively by the cocotb slave. **Do not assign these signals from RTL** (`assign default_ack = ...`). A multi-driver conflict causes Verilator's RTL assignment to win every evaluation cycle, preventing cocotb from ever deasserting `ack`, which stalls the slave's state machine and records 0 transactions.

## Makefile Conventions

- `SIM ?= verilator` — Verilator is the only supported simulator. Other backends are not tested.
- `EXTRA_ARGS += --no-timing --trace --Wno-fatal` — required; see *Known Issues* below.
- `COMPILE_ARGS := $(addprefix +incdir+,$(INCLUDE_DIRS))` — Verilator include-path style.
- `ifndef TRISTAN_ROOT` guards abort make with a clear error if the env var isn't exported.
- `WFG_ROOT` is defaulted via `?= $(TRISTAN_ROOT)/vendor/wfg` and `export`ed so the `.f` filelists' `$(WFG_ROOT)/...` paths expand from the environment.

### Source file ordering in the `.f` filelists

Packages must be listed before any module that imports them. For CV32E40X (`cv32e40x_soc.f`):

1. Packages: `soc_pkg.sv`, `cv32e40x_pkg.sv`, `wfg_pkg.sv`
2. `cv32e40x/bhv/cv32e40x_sim_clock_gate.sv` (simulation only)
3. `cv32e40x/rtl/*.sv` (all core modules, explicitly listed)
4. ISE: `ise_pkg.sv`, `coproc.sv`, `rshifter32.sv`
5. WFG peripherals: `wfg_timer_wishbone_reg.sv`, `wfg_timer.sv`, `wfg_timer_top.sv`
6. SoC modules: `obi_wb_bridge.sv`, `ram_arbiter.sv`, `wb_ram_interface.sv`, `core_sram.sv`, `cv32e40x_soc.sv`
7. `+incdir+` entries last
8. Testbench last (not in `.f` — added by the Makefile)

### Files intentionally excluded from simulation

| File / directory | Reason |
|---|---|
| `core/cv32e40x/sva/` | Formal verification assertions — not needed for simulation, can cause Verilator issues |
| `core/cv32e40x/bhv/cv32e40x_rvfi*.sv` | RVFI verification trace — verification-only, not part of DUT |
| `core/cva6/corev_apu/`, `core/cva6/verif/` | CVA6 subsystem-level testbenches — not part of this SoC sim flow |

## Vendoring

A few SystemVerilog files are vendored from the upstream wfg-fpga project into `vendor/wfg/`, mirroring the upstream directory layout so the build's `$(WFG_ROOT)/...` paths resolve locally without source edits:

| Vendored file | Purpose |
|---|---|
| `design/pkg/wfg_pkg.sv` | Slimmed Wishbone-bus parameter package (`BUSW`, `ADDRW`, `BLOCK_SEL_ADDRW`, …) |
| `design/wfg/wfg_timer/rtl/*.sv` | Wishbone-attached timer peripheral instantiated by the testbench |
| `design/semify_common/wishbone/arbiter/rtl/wb_arbiter_2.sv` | Wishbone master arbiter used by the OBI ↔ WB bridge unit sim |

The `.f` filelists and module-sim Makefiles use `$(WFG_ROOT)/...` paths verbatim. With `WFG_ROOT` defaulted to `$(TRISTAN_ROOT)/vendor/wfg` and `export`ed, these resolve to the vendored copies in standalone use.

## Known Issues

### Verilator 5.046 `--timing` bug

**Never use `--timing`.** Use `--no-timing --Wno-fatal` instead.

Verilator 5.046 generates a `std::process` coroutine wrapper with member `m_process`, but the bundled `verilated_std.sv` comparison operators reference `__PVT__m_process`, causing a C++ compile error whenever `fork`/`join`, `disable`, or `#delay` constructs are present. The CV32E40X RTL contains these constructs.

**Workaround:** `--no-timing` silently skips all `#delay` statements (zero delay). Safe for this SoC simulation flow.

### CVA6 CVXIF `rd` writeback unreliable (OPEN)

The CVA6 / CVXIF path of `RMLD` correctly loads the shadow register (verified via `RMCS` readback), but the value written back to the integer register file via the CVXIF result channel is occasionally wrong (often 0). The firmware works around this by reading the result via `RMCS` from the shadow register instead of via the `rd` field. Comments in `firmware/src/rle.c` reference this limitation. Spec: <https://docs.openhwgroup.org/projects/cva6-user-manual/01_cva6_user/CVX_Interface_Coprocessor.html>.
This will be tested in the upstream smartwave repo.

### BRAM preload not supported in synthesis (`core_sram_patched.sv`)

The CVA6 SRAM splits memory into per-byte-lane 8-bit BRAMs via a `generate` loop, with `$readmemh` wrapped in `// synthesis translate_off / translate_on` (**simulation-only**). Vivado cannot follow the intermediate temp-array + for-loop pattern to initialize the inferred BRAMs, so the SRAM always powers up as zero in hardware. Synthesis flows must load firmware via another mechanism (JTAG, UART bootloader, BRAM IP with a `.coe` file, …).

## Known TODOs

### Refactor `extend_value` CUSTOM_EXT branch to use `xset_stream_bits()`

**File:** `firmware/src/rle.c` — the `#ifdef CUSTOM_EXT` branch inside `extend_value()` currently inlines the size/`s_bits` bookkeeping and then calls `RMXS` / `RMXR` directly. The intent (documented in a `TODO` comment in the source) is to extract this into a helper analogous to `xset_stream_bits()` — ideally split into two helpers, one for shadow-register copies (today's `xset_stream_bits` wrapping `RMCS`) and a new one for value-extend stamps (wrapping `RMXS` / `RMXR`).

Cosmetic refactor: no functional change. After it lands, the `extend_value()` body shrinks and the CUSTOM_EXT branch reads more like the equivalent helper-using line in `copy_segment()`.
