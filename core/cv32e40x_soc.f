// 1. Packages (must come before any module that imports them)
$(TRISTAN_ROOT)/core/include/soc_pkg.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/include/cv32e40x_pkg.sv
$(WFG_ROOT)/design/pkg/wfg_pkg.sv

// 2. Behavioral Clock Gate (primitive for simulation)
$(TRISTAN_ROOT)/core/cv32e40x/bhv/cv32e40x_sim_clock_gate.sv

// 3. CV32E40X core
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_alignment_buffer.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_align_check.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_alu.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_alu_b_cpop.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_a_decoder.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_b_decoder.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_clic_int_controller.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_compressed_decoder.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_controller.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_controller_bypass.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_controller_fsm.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_core.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_csr.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_cs_registers.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_data_obi_interface.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_debug_triggers.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_decoder.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_div.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_ex_stage.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_ff_one.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_id_stage.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_if_c_obi.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_if_stage.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_if_xif.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_instr_obi_interface.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_int_controller.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_i_decoder.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_load_store_unit.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_lsu_response_filter.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_mpu.sv
// $(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_mpu2.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_mult.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_m_decoder.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_pc_target.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_pma.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_popcnt.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_prefetcher.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_prefetch_unit.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_register_file.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_register_file_wrapper.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_sequencer.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_sleep_unit.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_wb_stage.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_wpt.sv
$(TRISTAN_ROOT)/core/cv32e40x/rtl/cv32e40x_write_buffer.sv

// 4. Co-processor
$(TRISTAN_ROOT)/core/custom/coproc/rtl/coproc_pkg.sv
$(TRISTAN_ROOT)/core/custom/coproc/rtl/coproc.sv
$(TRISTAN_ROOT)/core/custom/coproc/rtl/rshifter32.sv

// 5. WFG Peripherals (connected via Wishbone)
$(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer_wishbone_reg.sv
$(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer.sv
$(WFG_ROOT)/design/wfg/wfg_timer/rtl/wfg_timer_top.sv

// 6. SoC Modules
$(TRISTAN_ROOT)/core/custom/obi_wb_bridge/rtl/obi_wb_bridge.sv
$(TRISTAN_ROOT)/core/custom/ram_arbiter/rtl/ram_arbiter.sv
$(TRISTAN_ROOT)/core/custom/wb_ram_interface/rtl/wb_ram_interface.sv
$(TRISTAN_ROOT)/core/core_sram.sv
$(TRISTAN_ROOT)/core/cv32e40x_soc.sv

// 7. Include directories
// +incdir+$(TRISTAN_ROOT)/core/cv32e40x/rtl/include/
// +incdir+$(TRISTAN_ROOT)/core/include/
// +incdir+$(WFG_ROOT)/design/pkg/