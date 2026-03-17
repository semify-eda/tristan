// 0. Verilator waiver file (suppresses warnings from upstream CVA6 IP)
$(TRISTAN_ROOT)/core/cva6_upstream_waivers.vlt

// 1. Packages (must come before any module that imports them)
$(TRISTAN_ROOT)/core/include/soc_pkg.sv
$(TRISTAN_ROOT)/core/cva6/core/include/cv32a60x_config_pkg.sv
$(WFG_ROOT)/design/pkg/wfg_pkg.sv
$(TRISTAN_ROOT)/core/cva6/core/include/config_pkg.sv
$(TRISTAN_ROOT)/core/cva6/core/include/riscv_pkg.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/cf_math_pkg.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/obi/src/obi_pkg.sv
// $(TRISTAN_ROOT)/core/cva6/core/cvfpu/src/fpnew_pkg.sv
$(TRISTAN_ROOT)/core/cva6/core/include/ariane_pkg.sv
// $(TRISTAN_ROOT)/core/cva6/core/include/wt_cache_pkg.sv
// $(TRISTAN_ROOT)/core/cva6/core/include/std_cache_pkg.sv
// $(TRISTAN_ROOT)/core/cva6/core/include/instr_tracer_pkg.sv
$(TRISTAN_ROOT)/core/cva6/core/include/build_config_pkg.sv
// $(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/axi/src/axi_pkg.sv

// 2. Behavioral Clock Gate (primitive for simulation)
// $(TRISTAN_ROOT)/core/cv32e40x/bhv/cv32e40x_sim_clock_gate.sv

// 3. CVA6 core
// Copied from Flist.cva6

// Core Files
$(TRISTAN_ROOT)/core/cva6/core/cva6.sv
$(TRISTAN_ROOT)/core/cva6/core/cva6_pipeline.sv
$(TRISTAN_ROOT)/core/cva6/core/cva6_rvfi_probes.sv
$(TRISTAN_ROOT)/core/cva6/core/alu.sv
// Note: depends on fpnew_pkg, above
// $(TRISTAN_ROOT)/core/cva6/core/fpu_wrap.sv
$(TRISTAN_ROOT)/core/cva6/core/branch_unit.sv
$(TRISTAN_ROOT)/core/cva6/core/compressed_decoder.sv
$(TRISTAN_ROOT)/core/cva6/core/macro_decoder.sv
$(TRISTAN_ROOT)/core/cva6/core/controller.sv
// $(TRISTAN_ROOT)/core/cva6/core/zcmt_decoder.sv
$(TRISTAN_ROOT)/core/cva6/core/csr_buffer.sv
// $(TRISTAN_ROOT)/core/cva6/core/csr_regfile.sv
$(TRISTAN_ROOT)/core/cva6/core/csr_regfile_patched.sv
$(TRISTAN_ROOT)/core/cva6/core/decoder.sv
$(TRISTAN_ROOT)/core/cva6/core/ex_stage.sv
$(TRISTAN_ROOT)/core/cva6/core/instr_realign.sv
$(TRISTAN_ROOT)/core/cva6/core/id_stage.sv
$(TRISTAN_ROOT)/core/cva6/core/issue_read_operands.sv
$(TRISTAN_ROOT)/core/cva6/core/issue_stage.sv
$(TRISTAN_ROOT)/core/cva6/core/load_unit.sv
$(TRISTAN_ROOT)/core/cva6/core/load_store_unit.sv
$(TRISTAN_ROOT)/core/cva6/core/lsu_bypass.sv
$(TRISTAN_ROOT)/core/cva6/core/mult.sv
$(TRISTAN_ROOT)/core/cva6/core/multiplier.sv
$(TRISTAN_ROOT)/core/cva6/core/serdiv.sv
$(TRISTAN_ROOT)/core/cva6/core/perf_counters.sv
$(TRISTAN_ROOT)/core/cva6/core/ariane_regfile_ff.sv
$(TRISTAN_ROOT)/core/cva6/core/ariane_regfile_fpga.sv
// NOTE: scoreboard.sv modified for DSIM (unchanged for other simulators)
$(TRISTAN_ROOT)/core/cva6/core/scoreboard.sv
$(TRISTAN_ROOT)/core/cva6/core/store_buffer.sv
$(TRISTAN_ROOT)/core/cva6/core/amo_buffer.sv
$(TRISTAN_ROOT)/core/cva6/core/store_unit.sv
$(TRISTAN_ROOT)/core/cva6/core/commit_stage.sv
$(TRISTAN_ROOT)/core/cva6/core/axi_shim.sv
$(TRISTAN_ROOT)/core/cva6/core/cva6_accel_first_pass_decoder_stub.sv
$(TRISTAN_ROOT)/core/cva6/core/acc_dispatcher.sv
$(TRISTAN_ROOT)/core/cva6/core/cva6_fifo_v3.sv

//OBI
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/obi/src/obi_atop_resolver.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/obi/src/obi_demux.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/obi/src/obi_err_sbr.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/obi/src/obi_intf.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/obi/src/obi_mux.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/obi/src/obi_sram_shim.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/obi/src/obi_xbar.sv

//FPGA memories
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/fpga-support/rtl/SyncDpRam.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/fpga-support/rtl/AsyncDpRam.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/fpga-support/rtl/AsyncThreePortRam.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/fpga-support/rtl/SyncThreePortRam.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/fpga-support/rtl/SyncDpRam_ind_r_w.sv

//CVXIF
$(TRISTAN_ROOT)/core/cva6/core/cvxif_compressed_if_driver.sv
$(TRISTAN_ROOT)/core/cva6/core/cvxif_issue_register_commit_if_driver.sv
$(TRISTAN_ROOT)/core/cva6/core/cvxif_fu.sv

// What is "frontend"?
$(TRISTAN_ROOT)/core/cva6/core/frontend/btb.sv
$(TRISTAN_ROOT)/core/cva6/core/frontend/bht.sv
$(TRISTAN_ROOT)/core/cva6/core/frontend/ras.sv
$(TRISTAN_ROOT)/core/cva6/core/frontend/instr_scan.sv
$(TRISTAN_ROOT)/core/cva6/core/frontend/instr_queue.sv
$(TRISTAN_ROOT)/core/cva6/core/frontend/frontend.sv

// Example coprocessor
// $(TRISTAN_ROOT)/core/cva6/core/cvxif_example/include/cvxif_instr_pkg.sv
// $(TRISTAN_ROOT)/core/cva6/core/cvxif_example/cvxif_example_coprocessor.sv
// $(TRISTAN_ROOT)/core/cva6/core/cvxif_example/instr_decoder.sv
// $(TRISTAN_ROOT)/core/cva6/core/cvxif_example/compressed_instr_decoder.sv
// $(TRISTAN_ROOT)/core/cva6/core/cvxif_example/copro_alu.sv
// Common Cells for example coprocessor
// $(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/counter.sv
// $(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/delta_counter.sv

// PULP Common Cells
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/fifo_v3.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/lfsr.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/lfsr_8bit.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/stream_arbiter.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/stream_arbiter_flushable.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/stream_mux.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/stream_demux.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/lzc.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/rr_arb_tree.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/shift_reg.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/popcount.sv
$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/exp_backoff.sv

// Cache subsystem
// $(TRISTAN_ROOT)/core/cva6/core/cache_subsystem/cva6_icache.sv
// $(TRISTAN_ROOT)/core/cva6/core/cache_subsystem/axi_adapter.sv
// -F ${HPDCACHE_DIR}/rtl/hpdcache.Flist
// ${HPDCACHE_DIR}/rtl/src/utils/hpdcache_mem_resp_demux.sv
// ${HPDCACHE_DIR}/rtl/src/utils/hpdcache_mem_to_axi_read.sv
// ${HPDCACHE_DIR}/rtl/src/utils/hpdcache_mem_to_axi_write.sv
// $(TRISTAN_ROOT)/core/cva6/core/cache_subsystem/cva6_hpdcache_subsystem.sv
// $(TRISTAN_ROOT)/core/cva6/core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv
// $(TRISTAN_ROOT)/core/cva6/core/cache_subsystem/cva6_hpdcache_if_adapter.sv
// $(TRISTAN_ROOT)/core/cva6/core/cache_subsystem/cva6_hpdcache_wrapper.sv
// ${HPDCACHE_DIR}/rtl/src/common/macros/behav/hpdcache_sram_1rw.sv
// ${HPDCACHE_DIR}/rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv
// ${HPDCACHE_DIR}/rtl/src/common/macros/behav/hpdcache_sram_wmask_1rw.sv

// Physical Memory Protection
// NOTE: pmp.sv modified for DSIM (unchanged for other simulators)
$(TRISTAN_ROOT)/core/cva6/core/pmp/src/pmp.sv
$(TRISTAN_ROOT)/core/cva6/core/pmp/src/pmp_entry.sv
$(TRISTAN_ROOT)/core/cva6/core/pmp/src/pmp_data_if.sv

// Tracer (behavioral code, not RTL)
// $(TRISTAN_ROOT)/core/cva6/common/local/util/instr_tracer.sv
// $(TRISTAN_ROOT)/core/cva6/common/local/util/tc_sram_wrapper.sv
// $(TRISTAN_ROOT)/core/cva6/common/local/util/tc_sram_wrapper_cache_techno.sv
// $(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/tech_cells_generic/src/rtl/tc_sram.sv
// $(TRISTAN_ROOT)/core/cva6/common/local/util/sram.sv
// $(TRISTAN_ROOT)/core/cva6/common/local/util/sram_cache.sv

// MMU 
// $(TRISTAN_ROOT)/core/cva6/core/cva6_mmu/cva6_mmu.sv
// $(TRISTAN_ROOT)/core/cva6/core/cva6_mmu/cva6_ptw.sv
// $(TRISTAN_ROOT)/core/cva6/core/cva6_mmu/cva6_tlb.sv
// $(TRISTAN_ROOT)/core/cva6/core/cva6_mmu/cva6_shared_tlb.sv


// 4. Co-processor
$(TRISTAN_ROOT)/core/custom/coproc/rtl/coproc_pkg.sv
$(TRISTAN_ROOT)/core/custom/coproc/rtl/coproc_cv32a60x.sv
$(TRISTAN_ROOT)/core/custom/coproc/rtl/rshifter32.sv

// 5. WFG Peripherals (connected via Wishbone)
$(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer_wishbone_reg.sv
$(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer.sv
$(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer_top.sv

// 6. SoC Modules
$(TRISTAN_ROOT)/core/custom/data_bus_arbiter/rtl/obi_data_bus_arbiter.sv
$(TRISTAN_ROOT)/core/custom/obi_wb_bridge/rtl/obi_wb_bridge.sv
// $(TRISTAN_ROOT)/core/custom/ram_arbiter/rtl/ram_arbiter.sv
$(TRISTAN_ROOT)/core/custom/wb_ram_interface/rtl/wb_ram_interface.sv
// $(TRISTAN_ROOT)/core/core_sram.sv
$(TRISTAN_ROOT)/core/core_sram_patched.sv
// $(TRISTAN_ROOT)/core/core_sram_xpm.sv
$(TRISTAN_ROOT)/core/cva6_soc.sv

// 7. Include directories
// +incdir+$(TRISTAN_ROOT)/core/include/
// +incdir+$(WFG_ROOT)/design/pkg/
+incdir+$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/obi/include
+incdir+$(TRISTAN_ROOT)/core/cva6/core/include
+incdir+$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/include/
// +incdir+$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/common_cells/src/
// +incdir+$(TRISTAN_ROOT)/core/cva6/vendor/pulp-platform/axi/include/
// +incdir+$(TRISTAN_ROOT)/core/cva6/common/local/util/