// OBI Data Bus Arbiter
//
// Arbitrates 3 OBI masters (CPU store, CPU load, co-processor) onto 2 OBI
// slaves (D-MEM port A, OBI-WB bridge).
//
// Priority: store (highest) > co-processor > load (lowest)
//
// Address decode on addr[20]:
//   INTERNAL (addr[20]=0, block_sel=D-MEM) -> SRAM port A (1-cycle SRAM)
//   EXTERNAL (addr[20]=1)                 -> OBI-WB bridge (multi-cycle)

`default_nettype none
import soc_pkg::*;

module obi_data_bus_arbiter
#(
  parameter type obi_store_req_t = logic,
  parameter type obi_store_rsp_t = logic,
  parameter type obi_load_req_t  = logic,
  parameter type obi_load_rsp_t  = logic,
  parameter int  RAM_ADDR_WIDTH  = 12,
  parameter int  RAM_DATA_WIDTH  = 32,
  parameter int  ALIGNMENT_OFFSET = 2
)
(
  input  wire  clk_i,
  input  wire  rst_ni,

  // -- OBI Master: CPU Data (store + load) --
  input  obi_store_req_t  obi_cpudata_store_req_i,
  output obi_store_rsp_t  obi_cpudata_store_rsp_o,
  input  obi_load_req_t   obi_cpudata_load_req_i,
  output obi_load_rsp_t   obi_cpudata_load_rsp_o,

  // -- OBI Master: Co-processor sideband --
  input  wire         obi_coproc_req_i,
  output logic        obi_coproc_gnt_o,
  input  wire         obi_coproc_we_i,
  input  wire  [31:0] obi_coproc_addr_i,
  input  wire  [31:0] obi_coproc_wdata_i,
  output logic        obi_coproc_rvalid_o,
  output logic [31:0] obi_coproc_rdata_o,

  // -- OBI Slave: D-MEM port A (raw RAM signals) --
  output logic [RAM_ADDR_WIDTH-1:0]     obi_dmem_addr_o,
  output logic                          obi_dmem_we_o,
  output logic [RAM_DATA_WIDTH/8-1:0]   obi_dmem_be_o,
  output logic [RAM_DATA_WIDTH-1:0]     obi_dmem_wdata_o,
  input  wire  [RAM_DATA_WIDTH-1:0]     obi_dmem_rdata_i,

  // -- OBI Slave: OBI-WB bridge (OBI side -- bridge instantiated in SoC) --
  output logic        obi_wb_req_o,
  input  wire         obi_wb_gnt_i,
  output logic [31:0] obi_wb_addr_o,
  output logic        obi_wb_we_o,
  output logic [3:0]  obi_wb_be_o,
  output logic [31:0] obi_wb_wdata_o,
  input  wire         obi_wb_rvalid_i,
  input  wire  [31:0] obi_wb_rdata_i
);

  /* =====================================================================
  *                  Flat Bus (one in-flight transaction at a time)
  *
  *  Muxes 3 OBI masters (store, load, co-processor) onto a single flat bus
  *  that routes to either D-MEM (SRAM port A, 1-cycle latency) or OBI-WB
  *  bridge (multi-cycle).
  * ====================================================================== */
  logic [31:0]  flat_addr;
  logic         flat_req;
  logic         flat_gnt;
  logic         flat_rvalid;
  logic [3:0]   flat_be;
  logic         flat_we;
  logic [31:0]  flat_wdata;
  logic [31:0]  flat_rdata;

  /* =====================================================================
  *                  Address Decode (from flat bus)
  * ====================================================================== */
  e_chip_sel    flat_chip_sel;
  e_block_sel   flat_block_sel;
  logic         flat_select_dmem;
  logic         flat_select_wb;

  assign flat_chip_sel    = e_chip_sel'(flat_addr[20]);
  assign flat_block_sel   = e_block_sel'(flat_addr[19:17]);
  assign flat_select_dmem = (flat_chip_sel == INTERNAL) && (flat_block_sel == DRAM);
  assign flat_select_wb   = (flat_chip_sel == EXTERNAL);

  /* =====================================================================
  *                  Priority Mux (3 masters -> flat bus)
  *
  *  Priority: store (highest) > load > co-processor (lowest)
  * ====================================================================== */
  logic arb_busy;           // a transaction is in-flight; blocks new requests
  logic arb_sel_store_q;    // 1 = store owns the in-flight transaction
  logic arb_sel_coproc_q;   // 1 = co-processor owns the in-flight transaction (else: load)
  logic arb_wb_q;           // 1 = in-flight transaction targets WB bridge
  logic sel_store;          // combinatorial: store highest priority
  logic sel_load;           // combinatorial: load mid priority
  logic sel_coproc;         // combinatorial: co-processor lowest priority

  assign sel_store  = obi_cpudata_store_req_i.req;
  assign sel_load   = obi_cpudata_load_req_i.req & ~sel_store;
  assign sel_coproc = obi_coproc_req_i & ~sel_store & ~sel_load;

  // Mux selected OBI master onto flat bus; suppress while busy
  assign flat_req   = (obi_cpudata_store_req_i.req | obi_cpudata_load_req_i.req | obi_coproc_req_i) & ~arb_busy;
  assign flat_we    = sel_store  ? obi_cpudata_store_req_i.a.we         :
                      sel_load   ? obi_cpudata_load_req_i.a.we          :
                      sel_coproc ? obi_coproc_we_i                      :
                                   1'b0;
  assign flat_addr  = sel_store  ? obi_cpudata_store_req_i.a.addr[31:0] :
                      sel_load   ? obi_cpudata_load_req_i.a.addr[31:0]  :
                      sel_coproc ? obi_coproc_addr_i                    :
                                   32'b0;
  assign flat_be    = sel_store  ? obi_cpudata_store_req_i.a.be         :
                      sel_load   ? obi_cpudata_load_req_i.a.be          :
                      sel_coproc ? 4'hF                                  :  // co-proc: always full-word
                                   4'b0;
  assign flat_wdata = sel_store  ? obi_cpudata_store_req_i.a.wdata      :
                      sel_load   ? obi_cpudata_load_req_i.a.wdata       :
                      sel_coproc ? obi_coproc_wdata_i                   :
                                   32'b0;

  /* =====================================================================
  *                  Flat Bus Latch
  *
  *  The flat bus signals are latched when a transaction
  *  is accepted to prevent mid-transaction corruption if a higher-priority
  *  request arrives while one is already in flight (arb_busy=1).
  * ====================================================================== */
  logic [31:0]  flat_addr_latch;
  logic [3:0]   flat_be_latch;
  logic         flat_we_latch;
  logic [31:0]  flat_wdata_latch;
  logic         flat_select_dmem_latch;
  logic         flat_select_wb_latch;

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      flat_addr_latch         <= '0;
      flat_be_latch           <= '0;
      flat_we_latch           <= '0;
      flat_wdata_latch        <= '0;
      flat_select_dmem_latch  <= '0;
      flat_select_wb_latch    <= '0;
    end else if (!arb_busy && flat_req && (!flat_select_wb || obi_wb_gnt_i)) begin
      // Capture entire transaction atomically when it's accepted (granted).
      // D-MEM: grant fires immediately when !arb_busy && flat_req && !flat_select_wb
      // WB:   grant fires only when obi_wb_gnt_i=1 && !arb_busy && flat_req && flat_select_wb
      flat_addr_latch         <= flat_addr;
      flat_be_latch           <= flat_be;
      flat_we_latch           <= flat_we;
      flat_wdata_latch        <= flat_wdata;
      flat_select_dmem_latch  <= flat_select_dmem;
      flat_select_wb_latch    <= flat_select_wb;
    end
  end

  // Use latch while busy; mux while idle
  logic [31:0]  flat_addr_active;
  logic [3:0]   flat_be_active;
  logic         flat_we_active;
  logic [31:0]  flat_wdata_active;
  logic         flat_select_dmem_active;
  logic         flat_select_wb_active;

  assign flat_addr_active         = arb_busy ? flat_addr_latch         : flat_addr;
  assign flat_be_active           = arb_busy ? flat_be_latch           : flat_be;
  assign flat_we_active           = arb_busy ? flat_we_latch           : flat_we;
  assign flat_wdata_active        = arb_busy ? flat_wdata_latch        : flat_wdata;
  assign flat_select_dmem_active  = arb_busy ? flat_select_dmem_latch  : flat_select_dmem;
  assign flat_select_wb_active    = arb_busy ? flat_select_wb_latch    : flat_select_wb;

  /* =====================================================================
  *                  D-MEM Port A
  * ====================================================================== */
  assign obi_dmem_addr_o  = flat_addr_active[RAM_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET];
  assign obi_dmem_we_o    = flat_gnt & flat_select_dmem_active & flat_we_active;
  assign obi_dmem_be_o    = flat_be_active;
  assign obi_dmem_wdata_o = flat_wdata_active;

  /* =====================================================================
  *                  OBI-WB Bridge Output (OBI side)
  * ====================================================================== */
  assign obi_wb_req_o   = flat_req & flat_select_wb_active;
  assign obi_wb_addr_o  = flat_addr_active;
  assign obi_wb_we_o    = flat_we_active;
  assign obi_wb_be_o    = flat_be_active;
  assign obi_wb_wdata_o = flat_wdata_active;

  /* =====================================================================
  *                  Grant + Arbitration FSM
  *
  *  D-MEM path: single-cycle grant (flat_gnt = 1 immediately)
  *  WB path:   multi-cycle grant (flat_gnt follows obi_wb_gnt_i)
  * ====================================================================== */
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      flat_gnt         <= 1'b0;
      arb_busy         <= 1'b0;
      arb_sel_store_q  <= 1'b0;
      arb_sel_coproc_q <= 1'b0;
      arb_wb_q         <= 1'b0;
    end else begin
      flat_gnt <= 1'b0;  // pulse for one cycle only (default: deassert)
      if (!arb_busy) begin
        if (flat_req & flat_select_wb) begin
          // External path: gnt comes from WB bridge (multi-cycle)
          flat_gnt <= obi_wb_gnt_i;
          if (obi_wb_gnt_i) begin
            arb_busy         <= 1'b1;
            arb_sel_store_q  <= sel_store;
            arb_sel_coproc_q <= sel_coproc;
            arb_wb_q         <= 1'b1;
          end
        end else if (flat_req) begin
          // Internal D-MEM path: single-cycle grant
          flat_gnt         <= 1'b1;
          arb_busy         <= 1'b1;
          arb_sel_store_q  <= sel_store;
          arb_sel_coproc_q <= sel_coproc;
          arb_wb_q         <= 1'b0;
        end
      end
      if (flat_rvalid) begin
        arb_busy         <= 1'b0;
        arb_sel_coproc_q <= 1'b0;
        arb_wb_q         <= 1'b0;
      end
    end
  end

  /* =====================================================================
  *                  Response: rvalid + rdata
  * ====================================================================== */

  // rvalid: one cycle after gnt for D-MEM; forwarded from bridge for WB
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) flat_rvalid <= 1'b0;
    else         flat_rvalid <= arb_wb_q ? obi_wb_rvalid_i : flat_gnt;
  end

  // rdata mux: WB bridge or D-MEM port A
  always_comb begin
    flat_rdata = '0;
    if (arb_wb_q) flat_rdata = obi_wb_rdata_i;
    else          flat_rdata = obi_dmem_rdata_i;
  end

  /* =====================================================================
  *                  Response Routing (flat bus -> correct OBI master)
  *
  *  arb_sel_*_q are stable once busy=1; on the gnt cycle (busy still 0,
  *  sel_*_q not yet updated) use sel_store/sel_coproc to override routing.
  * ====================================================================== */
  always_comb begin
    obi_cpudata_store_rsp_o = '0;
    obi_cpudata_load_rsp_o  = '0;
    obi_coproc_gnt_o    = 1'b0;
    obi_coproc_rvalid_o = 1'b0;
    obi_coproc_rdata_o  = '0;
    if (arb_sel_store_q) begin
      obi_cpudata_store_rsp_o.gnt     = flat_gnt;
      obi_cpudata_store_rsp_o.rvalid  = flat_rvalid;
      obi_cpudata_store_rsp_o.r.rdata = flat_rdata;
    end else if (arb_sel_coproc_q) begin
      obi_coproc_gnt_o    = flat_gnt;
      obi_coproc_rvalid_o = flat_rvalid;
      obi_coproc_rdata_o  = flat_rdata;
    end else begin
      obi_cpudata_load_rsp_o.gnt      = flat_gnt;
      obi_cpudata_load_rsp_o.rvalid   = flat_rvalid;
      obi_cpudata_load_rsp_o.r.rdata  = flat_rdata;
    end
    // On gnt cycle: arb_sel_*_q stale -> override with current selection
    if (!arb_busy) begin
      obi_cpudata_store_rsp_o.gnt = 1'b0;
      obi_cpudata_load_rsp_o.gnt  = 1'b0;
      obi_coproc_gnt_o            = 1'b0;
      if (sel_store) begin
        obi_cpudata_store_rsp_o.gnt = flat_gnt;
      end else if (sel_coproc) begin
        obi_coproc_gnt_o = flat_gnt;
      end else begin
        obi_cpudata_load_rsp_o.gnt = flat_gnt;
      end
    end
  end

endmodule
`default_nettype wire
