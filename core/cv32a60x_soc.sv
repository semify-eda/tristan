// Copyright 2024 semify-eda
// SPDX-License-Identifier: Apache-2.0
//
// SoC wrapper for cv32a60x (CVA6 pipeline-only, OBI bus).
// Drop-in replacement for cv32e40x_soc.sv — identical external ports.

`default_nettype none
`timescale 1ns/1ps

`include "obi/typedef.svh"
`include "obi/assign.svh"
`include "rvfi_types.svh"
`include "cvxif_types.svh"

import soc_pkg::*;

module tristan_soc
  import ariane_pkg::*;
#(
  parameter SOC_ADDR_WIDTH    = 32,
  parameter RAM_ADDR_WIDTH    = 12,
  parameter RAM_DATA_WIDTH    = 32,
  parameter BOOT_ADDR         = 32'h00020000,
  parameter FIRMWARE_INITFILE = "../firmware.mem",
  parameter HART_ID           = 32'h0000_0000
  // Removed CV32E40X-era parameters not used in CVA6 SoC:
  //   SOC_DATA_WIDTH    — no data-width parameterisation needed (fixed 32-bit)
  //   DATA_START_ADDR   — data SRAM start is fixed in soc_pkg address map
  //   DM_HALTADDRESS    — debug transport module not instantiated
  //   NUM_MHPMCOUNTERS  — hardware performance counters not instantiated
)
(
  // Clock and reset
  input  wire                         clk_i,
  input  wire                         wfg_clk_i,
  input  wire                         rst_ni,
  input  wire                         gbl_rst_ni,

  // Core control signals
  input  wire                         soc_fetch_enable_i,
  output logic                        soc_core_sleep_o,

  // WB output interface for external modules
  output logic [SOC_ADDR_WIDTH-1:0]   wb_addr_o,
  input  wire  [31: 0]                wb_rdata_i,
  output logic [31: 0]                wb_wdata_o,
  output logic                        wb_wr_en_o,
  output logic [ 3: 0]                wb_byte_en_o,
  output logic                        wb_stb_o,
  input  wire                         wb_ack_i,
  output logic                        wb_cyc_o,

  // WB input interface to access SoC RAM (firmware and data pre-loading only)
  // All writes are full 32-bit words; wb_byte_en_i is declared for port
  // compatibility but intentionally not connected — wb_ram_interface and
  // soc_sram_dualport port B do not support sub-word byte enables.
  input  wire  [SOC_ADDR_WIDTH-1:0]   wb_addr_i,
  output logic [31: 0]                wb_rdata_o,
  input  wire  [31: 0]                wb_wdata_i,
  input  wire                         wb_wr_en_i,
  input  wire  [ 3: 0]                wb_byte_en_i, /* unused — see comment above */
  input  wire                         wb_stb_i,
  output logic                        wb_ack_o,
  input  wire                         wb_cyc_i
);

  /* =====================================================================
  *                  cv32a60x Configuration
  * ====================================================================== */

// Note PS: cva6_config_pkg is declared in cv32a60x_config_pkg.sv -> So cv32a60x_config_pkg.sv must be compiled before. (and NO other config_pkg.sv)

  localparam config_pkg::cva6_cfg_t Cv32a60xCfg = build_config_pkg::build_config(
      cva6_config_pkg::cva6_cfg
  );

  // 16kb
  // RAM_ADDR_WIDTH is directly tied to the DATAWIDTH. Having an addr width of 12 does not mean that you address the
  // 12 LSB of the address, since if the data width is 32, then the 2 LSB are omitted, and you therefore must address
  // bits 13 to 2, due to alignment since the 2 LSB correspond to (32/8) = 4 bytes.
  localparam ALIGNMENT_OFFSET = $clog2(RAM_DATA_WIDTH / 8);

  /* =====================================================================
  *                  Fetch / Old-style Bus Types
  *  (Identical to cva6.sv — required for cva6_pipeline port compatibility)
  * ====================================================================== */
  localparam type fetch_req_t = struct packed {
    logic                    req;
    logic                    kill_req;
    logic [Cv32a60xCfg.VLEN-1:0] vaddr;
  };
  localparam type fetch_rsp_t = struct packed {
    logic ready;
    logic invalid_data;
  };

  // FIXME: temp type used by obi_mmu_ptw and obi_zcmt ports in cva6_pipeline 
  // (CVA6 imperfection: Still use old style dbus_req_t struct, not the new OBI Bus types below)
  localparam type dbus_req_t = struct packed {
    logic [Cv32a60xCfg.DCACHE_INDEX_WIDTH-1:0] address_index;
    logic [Cv32a60xCfg.DCACHE_TAG_WIDTH-1:0]   address_tag;
    logic [Cv32a60xCfg.XLEN-1:0]               data_wdata;
    logic [Cv32a60xCfg.DCACHE_USER_WIDTH-1:0]  data_wuser;
    logic                                  data_req;
    logic                                  data_we;
    logic [(Cv32a60xCfg.XLEN/8)-1:0]           data_be;
    logic [1:0]                            data_size;
    logic [Cv32a60xCfg.DcacheIdWidth-1:0]      data_id;
    logic                                  kill_req;
    logic                                  tag_valid;
  };
  localparam type dbus_rsp_t = struct packed {
    logic                                 data_gnt;
    logic                                 data_rvalid;
    logic [Cv32a60xCfg.DcacheIdWidth-1:0]     data_rid;
    logic [Cv32a60xCfg.XLEN-1:0]             data_rdata;
    logic [Cv32a60xCfg.DCACHE_USER_WIDTH-1:0] data_ruser;
  };

  // Old-style load bus (not used in PipelineOnly path)
  localparam type load_req_t = struct packed {
    logic [Cv32a60xCfg.DCACHE_INDEX_WIDTH-1:0] address_index;
    logic                                  req;
    logic [(Cv32a60xCfg.XLEN/8)-1:0]           be;
    logic [Cv32a60xCfg.IdWidth-1:0]            aid;
    logic                                  kill_req;
  };
  localparam type load_rsp_t = struct packed { logic gnt; };

  /* =====================================================================
  *                  OBI Bus Types
  *
  *  CVA6 cv32a60x exposes four separate OBI buses (fetch, store, load, amo)
  *  each with their own parameterised type generated from the core config.
  *  The macro OBI_LOCALPARAM_TYPE_ALL produces _req_t / _rsp_t pairs.
  * ====================================================================== */
  `OBI_LOCALPARAM_TYPE_ALL(obi_fetch, Cv32a60xCfg.ObiFetchbusCfg);
  `OBI_LOCALPARAM_TYPE_ALL(obi_store, Cv32a60xCfg.ObiStorebusCfg);
  `OBI_LOCALPARAM_TYPE_ALL(obi_amo,   Cv32a60xCfg.ObiAmobusCfg);
  `OBI_LOCALPARAM_TYPE_ALL(obi_load,  Cv32a60xCfg.ObiLoadbusCfg);

  // Inactive buses keep the dbus_req_t alias (FIXME: temp in CVA6 upstream)
  localparam type obi_mmu_ptw_req_t = dbus_req_t;
  localparam type obi_mmu_ptw_rsp_t = dbus_rsp_t;
  localparam type obi_zcmt_req_t    = dbus_req_t;
  localparam type obi_zcmt_rsp_t    = dbus_rsp_t;

  /* =====================================================================
  *                  CVXIF Types
  * ====================================================================== */
  localparam type readregflags_t      = `READREGFLAGS_T(Cv32a60xCfg);
  localparam type writeregflags_t     = `WRITEREGFLAGS_T(Cv32a60xCfg);
  localparam type id_t                = `ID_T(Cv32a60xCfg);
  localparam type hartid_t            = `HARTID_T(Cv32a60xCfg);
  localparam type x_compressed_req_t  = `X_COMPRESSED_REQ_T(Cv32a60xCfg, hartid_t);
  localparam type x_compressed_resp_t = `X_COMPRESSED_RESP_T(Cv32a60xCfg);
  localparam type x_issue_req_t       = `X_ISSUE_REQ_T(Cv32a60xCfg, hartid_t, id_t);
  localparam type x_issue_resp_t      = `X_ISSUE_RESP_T(Cv32a60xCfg, writeregflags_t, readregflags_t);
  localparam type x_register_t        = `X_REGISTER_T(Cv32a60xCfg, hartid_t, id_t, readregflags_t);
  localparam type x_commit_t          = `X_COMMIT_T(Cv32a60xCfg, hartid_t, id_t);
  localparam type x_result_t          = `X_RESULT_T(Cv32a60xCfg, hartid_t, id_t, writeregflags_t);
  localparam type cvxif_req_t         =
      `CVXIF_REQ_T(Cv32a60xCfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t);
  localparam type cvxif_resp_t        =
      `CVXIF_RESP_T(Cv32a60xCfg, x_compressed_resp_t, x_issue_resp_t, x_result_t);

  /* =====================================================================
  *                  RVFI Types
  * ====================================================================== */
  localparam type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(Cv32a60xCfg);
  localparam type rvfi_probes_csr_t   = `RVFI_PROBES_CSR_T(Cv32a60xCfg);
  localparam type rvfi_probes_t       = struct packed {
    rvfi_probes_csr_t   csr;
    rvfi_probes_instr_t instr;
  };

  /* =====================================================================
  *                  OBI Signal Declarations
  * ====================================================================== */
  fetch_req_t       fetch_req;
  fetch_rsp_t       fetch_rsp;

  obi_fetch_req_t   obi_fetch_req;
  obi_fetch_rsp_t   obi_fetch_rsp;

  obi_store_req_t   obi_store_req;
  obi_store_rsp_t   obi_store_rsp;

  obi_amo_req_t     obi_amo_req;
  obi_amo_rsp_t     obi_amo_rsp;

  load_req_t        load_req;
  load_rsp_t        load_rsp;

  obi_load_req_t    obi_load_req;
  obi_load_rsp_t    obi_load_rsp;

  obi_mmu_ptw_req_t obi_mmu_ptw_req;
  obi_mmu_ptw_rsp_t obi_mmu_ptw_rsp;

  obi_zcmt_req_t    obi_zcmt_req;
  obi_zcmt_rsp_t    obi_zcmt_rsp;

  cvxif_req_t       cvxif_req;
  cvxif_resp_t      cvxif_resp;

  /* =====================================================================
  *                  Tie-offs for Inactive / Cache Ports
  *
  *  cv32a60x is configured with PipelineOnly=1 (no cache subsystem),
  *  MmuPresent=0, RVZCMT=0, and RVA=0.  The ports for these features
  *  still exist on cva6_pipeline but are permanently tied off here.
  * ====================================================================== */

  // cv32a60x has no core_sleep output; keep the port for drop-in compatibility
  assign soc_core_sleep_o = 1'b0;

  // Old-style fetch channel: always ready (no cache subsystem, PipelineOnly=1)
  assign fetch_rsp.ready        = 1'b1;
  assign fetch_rsp.invalid_data = 1'b0;

  // Old-style load channel: never grant (PipelineOnly path uses obi_load)
  assign load_rsp.gnt = 1'b0;

  // Inactive OBI buses: MMU PTW (MmuPresent=0), ZCMT (RVZCMT=0), AMO (RVA=0)
  assign obi_mmu_ptw_rsp = '0;
  assign obi_zcmt_rsp    = '0;
  assign obi_amo_rsp     = '0;

  // CVXIF: Instruction Set Extension
  ise_cv32a60x #(
    .cvxif_req_t  (cvxif_req_t ),
    .cvxif_resp_t (cvxif_resp_t)
  ) i_ise (
    .clk_i        (clk_i      ),
    .rst_ni       (rst_ni     ),
    .cvxif_req_i  (cvxif_req  ),
    .cvxif_resp_o (cvxif_resp ),
    .obi_ise_req       (obi_ise_req     ),
    .obi_ise_gnt       (obi_ise_gnt     ),
    .obi_ise_we        (obi_ise_we      ),
    .obi_ise_addr      (obi_ise_addr    ),
    .obi_ise_wdata     (obi_ise_wdata   ),
    .obi_ise_rvalid    (obi_ise_rvalid  ),
    .obi_ise_rdata     (obi_ise_rdata   )
  );

  /* =====================================================================
  *                  cva6_pipeline Instantiation
  * ====================================================================== */
  cva6_pipeline #(
      .CVA6Cfg          (Cv32a60xCfg      ),
      .rvfi_probes_t(rvfi_probes_t)
  ) i_cv32a60x_pipeline (
      .clk_i                   (clk_i          ),
      .rst_ni                  (rst_ni         ),
      .boot_addr_i             (BOOT_ADDR      ),  // VLEN=32 = BOOT_ADDR width
      .hart_id_i               (HART_ID        ),

      .irq_i                   (2'b00          ),
      .ipi_i                   (1'b0           ),
      .time_irq_i              (1'b0           ),
      .debug_req_i             (1'b0           ),

      .rvfi_probes_o           (               ),

      .cvxif_req_o             (cvxif_req      ),
      .cvxif_resp_i            (cvxif_resp     ),

      // Cache control — PipelineOnly=1, no cache subsystem present
      .icache_enable_o         (               ),
      .icache_flush_o          (               ),
      .icache_miss_i           (1'b0           ),

      .dcache_enable_o         (               ),
      .dcache_flush_o          (               ),
      .dcache_flush_ack_i      (1'b1           ),  // always acknowledge flush
      .dcache_miss_i           (1'b0           ),
      .dcache_wbuffer_empty_i  (1'b1           ),  // write buffer always empty
      .dcache_wbuffer_not_ni_i (1'b1           ),

      // Old-style fetch channel (cache subsystem interface — tied off)
      .fetch_req_o             (fetch_req      ),
      .fetch_rsp_i             (fetch_rsp      ),

      // OBI Fetch — instruction bus → IRAM (connected below)
      .obi_fetch_req_o         (obi_fetch_req  ),
      .obi_fetch_rsp_i         (obi_fetch_rsp  ),

      // OBI Store — data write bus → data arbiter (connected below)
      .obi_store_req_o         (obi_store_req  ),
      .obi_store_rsp_i         (obi_store_rsp  ),

      // OBI AMO — inactive (RVA=0)
      .obi_amo_req_o           (obi_amo_req    ),
      .obi_amo_rsp_i           (obi_amo_rsp    ),

      // Old-style load channel (tied off — PipelineOnly uses obi_load)
      .load_req_o              (load_req       ),
      .load_rsp_i              (load_rsp       ),

      // OBI Load — data read bus → data arbiter (connected below)
      .obi_load_req_o          (obi_load_req   ),
      .obi_load_rsp_i          (obi_load_rsp   ),

      // OBI MMU PTW — inactive (MmuPresent=0)
      .obi_mmu_ptw_req_o       (obi_mmu_ptw_req),
      .obi_mmu_ptw_rsp_i       (obi_mmu_ptw_rsp),

      // OBI ZCMT — inactive (RVZCMT=0)
      .obi_zcmt_req_o          (obi_zcmt_req   ),
      .obi_zcmt_rsp_i          (obi_zcmt_rsp   )
  );

  /* =====================================================================
  *                  (OBI) Fetch Bus → IRAM
  *
  *  Drives soc_sram_dualport (instr) port A from obi_fetch_req.
  *  The CPU only fetches while soc_fetch_enable_i is asserted.
  *
  *  BRAM has 1-cycle registered read latency:
  *    addr_a presented this cycle → q_a valid next cycle
  *  Therefore:
  *    fetch_gnt   : registered pulse when req accepted (gated with fetch_enable)
  *    fetch_rvalid: one cycle after fetch_gnt
  *    r.rdata     : iram_rdata_a (registered BRAM output, valid with rvalid)
  *
  *  Integrity=0 → gntpar / rvalidpar tied to 0 (covered by '0 default).
  * ====================================================================== */

  logic fetch_gnt;
  logic fetch_rvalid;
  // Declared here (used in always_comb below before IRAM signals block — Vivado requires declaration before first use)
  logic [RAM_DATA_WIDTH-1:0] iram_rdata_a;

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      fetch_gnt    <= 1'b0;
      fetch_rvalid <= 1'b0;
    end else begin
      // Accept request only when enabled and no transaction already in-flight
      fetch_gnt    <= obi_fetch_req.req & soc_fetch_enable_i
                      & ~fetch_gnt & ~fetch_rvalid;
      // rvalid follows one cycle after gnt (BRAM latency)
      fetch_rvalid <= fetch_gnt;
    end
  end

  always_comb begin
    obi_fetch_rsp          = '0;     // default all fields to 0 (incl. integrity parity)
    obi_fetch_rsp.gnt      = fetch_gnt;
    obi_fetch_rsp.rvalid   = fetch_rvalid;
    obi_fetch_rsp.r.rdata  = iram_rdata_a;
  end

  /* =====================================================================
  *                  (OBI) Data Bus Arbiter
  *
  *  Arbitrates 3 OBI masters (CPU store, CPU load, Instruction Set Extension) onto
  *  2 OBI slaves (DRAM port A, OBI-WB bridge).
  *  Address decode on addr[20]:
  *    INTERNAL (addr[20]=0, block_sel=DRAM) -> DRAM port A (1-cycle BRAM)
  *    EXTERNAL (addr[20]=1)                 -> obi_wb_bridge
  * ====================================================================== */

  // ISE sideband OBI port signals
  logic        obi_ise_req;
  logic        obi_ise_gnt;
  logic        obi_ise_we;
  logic [31:0] obi_ise_addr;
  logic [31:0] obi_ise_wdata;
  logic        obi_ise_rvalid;
  logic [31:0] obi_ise_rdata;

  // Arbiter <-> OBI-WB bridge interconnect (OBI side)
  logic        arb2wb_obi_req;
  logic        arb2wb_obi_gnt;
  logic [31:0] arb2wb_obi_addr;
  logic        arb2wb_obi_we;
  logic [3:0]  arb2wb_obi_be;
  logic [31:0] arb2wb_obi_wdata;
  logic        arb2wb_obi_rvalid;
  logic [31:0] arb2wb_obi_rdata;

  obi_data_bus_arbiter #(
    .obi_store_req_t (obi_store_req_t),
    .obi_store_rsp_t (obi_store_rsp_t),
    .obi_load_req_t  (obi_load_req_t ),
    .obi_load_rsp_t  (obi_load_rsp_t ),
    .RAM_ADDR_WIDTH  (RAM_ADDR_WIDTH ),
    .RAM_DATA_WIDTH  (RAM_DATA_WIDTH ),
    .ALIGNMENT_OFFSET(ALIGNMENT_OFFSET)
  ) i_data_bus_arbiter (
    .clk_i                    (clk_i            ),
    .rst_ni                   (rst_ni           ),

    // CPU store/load OBI channels
    .obi_cpudata_store_req_i  (obi_store_req    ),
    .obi_cpudata_store_rsp_o  (obi_store_rsp    ),
    .obi_cpudata_load_req_i   (obi_load_req     ),
    .obi_cpudata_load_rsp_o   (obi_load_rsp     ),

    // Co-processor sideband
    .obi_ise_req_i         (obi_ise_req   ),
    .obi_ise_gnt_o         (obi_ise_gnt   ),
    .obi_ise_we_i          (obi_ise_we    ),
    .obi_ise_addr_i        (obi_ise_addr  ),
    .obi_ise_wdata_i       (obi_ise_wdata ),
    .obi_ise_rvalid_o      (obi_ise_rvalid),
    .obi_ise_rdata_o       (obi_ise_rdata ),

    // DRAM port A
    .obi_dmem_addr_o          (dram_addr_a      ),
    .obi_dmem_we_o            (dram_we_a        ),
    .obi_dmem_be_o            (dram_be_a        ),
    .obi_dmem_wdata_o         (dram_wdata_a     ),
    .obi_dmem_rdata_i         (dram_rdata_a     ),

    // OBI-WB bridge (OBI side)
    .obi_wb_req_o             (arb2wb_obi_req   ),
    .obi_wb_gnt_i             (arb2wb_obi_gnt   ),
    .obi_wb_addr_o            (arb2wb_obi_addr  ),
    .obi_wb_we_o              (arb2wb_obi_we    ),
    .obi_wb_be_o              (arb2wb_obi_be    ),
    .obi_wb_wdata_o           (arb2wb_obi_wdata ),
    .obi_wb_rvalid_i          (arb2wb_obi_rvalid),
    .obi_wb_rdata_i           (arb2wb_obi_rdata )
  );

  /* ================================================================
  *                   OBI-Wishbone Bridge
  *   External data path: addr[20]=1 -> WB master interface
  * ================================================================= */
  obi_wb_bridge i_obi_wb_bridge (
    .obi_clk_i     (clk_i              ),
    .wb_clk_i      (wfg_clk_i          ),
    .soc_rst_ni    (rst_ni             ),
    .gbl_rst_ni    (gbl_rst_ni         ),

    .obi_req_i     (arb2wb_obi_req     ),
    .obi_gnt_o     (arb2wb_obi_gnt     ),
    .obi_addr_i    (arb2wb_obi_addr    ),
    .obi_wr_en_i   (arb2wb_obi_we      ),
    .obi_byte_en_i (arb2wb_obi_be      ),
    .obi_wdata_i   (arb2wb_obi_wdata   ),
    .obi_rvalid_o  (arb2wb_obi_rvalid  ),
    .obi_rdata_o   (arb2wb_obi_rdata   ),

    .wb_addr_o     (wb_addr_o          ),
    .wb_rdata_i    (wb_rdata_i         ),
    .wb_wdata_o    (wb_wdata_o         ),
    .wb_wr_en_o    (wb_wr_en_o         ),
    .wb_byte_en_o  (wb_byte_en_o       ),
    .wb_stb_o      (wb_stb_o           ),
    .wb_ack_i      (wb_ack_i           ),
    .wb_cyc_o      (wb_cyc_o           )
  );


  /* =====================================================================
  *                  Dual-Port BRAM + WB-RAM Interface
  * ====================================================================== */

  // Interconnect between wb_ram_interface and BRAM port B
  logic [RAM_ADDR_WIDTH-1:0]   wb2ram_addr;
  logic [RAM_DATA_WIDTH-1:0]   wb2ram_data;
  logic [RAM_DATA_WIDTH-1:0]   iram2wb_data;
  logic [RAM_DATA_WIDTH-1:0]   dram2wb_data;
  logic                        wb2iram_we;
  logic                        wb2dram_we;

  // IRAM port A signals — driven by Fetch Bus
  logic [RAM_ADDR_WIDTH-1:0]   iram_addr_a;
  logic                        iram_we_a;
  logic [RAM_DATA_WIDTH/8-1:0] iram_be_a;
  logic [RAM_DATA_WIDTH-1:0]   iram_wdata_a;
  // iram_rdata_a declared earlier (before first use in always_comb fetch block)

  // DRAM port A signals — driven by Data Bus Arbiter
  logic [RAM_ADDR_WIDTH-1:0]   dram_addr_a;
  logic                        dram_we_a;
  logic [RAM_DATA_WIDTH/8-1:0] dram_be_a;
  logic [RAM_DATA_WIDTH-1:0]   dram_wdata_a;
  logic [RAM_DATA_WIDTH-1:0]   dram_rdata_a;

  // IRAM port A — driven by fetch bus
  assign iram_addr_a  = obi_fetch_req.a.addr[RAM_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET];
  assign iram_we_a    = 1'b0;   // instruction fetch is always read
  assign iram_be_a    = '0;     // don't care (read-only port)
  assign iram_wdata_a = '0;     // don't care (read-only port)
  // DRAM port A — driven by obi_data_bus_arbiter (instantiated above)

  /* ================================================================
  *                   Wishbone — RAM Interface
  *   WB slave: receives firmware writes from external SPI master
  *   Drives BRAM port B on both IRAM and DRAM
  * ================================================================= */
  wb_ram_interface #(
    .RAM_ADDR_WIDTH (RAM_ADDR_WIDTH),
    .RAM_DATA_WIDTH (RAM_DATA_WIDTH)
  ) i_wb_ram_interface (
    .ram_clk_i   (clk_i       ),
    .wb_clk_i    (wfg_clk_i   ),
    .rst_ni      (gbl_rst_ni  ),

    .wb_addr_i   (wb_addr_i   ),
    .wb_rdata_o  (wb_rdata_o  ),
    .wb_wdata_i  (wb_wdata_i  ),
    .wb_wr_en_i  (wb_wr_en_i  ),
    .wb_stb_i    (wb_stb_i    ),
    .wb_ack_o    (wb_ack_o    ),
    .wb_cyc_i    (wb_cyc_i    ),

    .ram_addr_o  (wb2ram_addr ),
    .ram_data_o  (wb2ram_data ),
    .iram_data_i (iram2wb_data),
    .dram_data_i (dram2wb_data),
    .iram_we_o   (wb2iram_we  ),
    .dram_we_o   (wb2dram_we  )
  );

  /* ================================================================
  *                   Dualport BRAM — Instruction (IRAM)
  *   Port A: CPU fetch bus (read-only)
  *   Port B: WB RAM interface (firmware loading)
  * ================================================================= */
  soc_sram_dualport #(
    .INITFILEEN  (1                ),
    .INITFILE    (FIRMWARE_INITFILE),
    .DATAWIDTH   (RAM_DATA_WIDTH   ),
    .ADDRWIDTH   (RAM_ADDR_WIDTH   ),
    .BYTE_ENABLE (1                )
  ) i_instr_sram (
    .clk    (clk_i       ),

    .addr_a (iram_addr_a ),
    .we_a   (iram_we_a   ),
    .be_a   (iram_be_a   ),
    .d_a    (iram_wdata_a),
    .q_a    (iram_rdata_a),

    .addr_b (wb2ram_addr ),
    .we_b   (wb2iram_we  ),
    .d_b    (wb2ram_data ),
    .q_b    (iram2wb_data)
  );

  /* ================================================================
  *                   Dualport BRAM — Data (DRAM)
  *   Port A: CPU data bus (read/write)
  *   Port B: WB RAM interface (firmware loading)
  * ================================================================= */
  soc_sram_dualport #(
    .DATAWIDTH   (RAM_DATA_WIDTH),
    .ADDRWIDTH   (RAM_ADDR_WIDTH),
    .BYTE_ENABLE (1             )
  ) i_data_sram (
    .clk    (clk_i       ),

    .addr_a (dram_addr_a ),
    .we_a   (dram_we_a   ),
    .be_a   (dram_be_a   ),
    .d_a    (dram_wdata_a),
    .q_a    (dram_rdata_a),

    .addr_b (wb2ram_addr ),
    .we_b   (wb2dram_we  ),
    .d_b    (wb2ram_data ),
    .q_b    (dram2wb_data)
  );

endmodule
`default_nettype wire
