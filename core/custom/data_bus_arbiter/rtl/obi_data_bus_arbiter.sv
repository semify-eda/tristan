// OBI Data Bus Arbiter
//
// Arbitrates 3 OBI masters (CPU store, CPU load, co-processor) onto 2 OBI
// slaves (DRAM port A, OBI-WB bridge).
//
// Priority: store (highest) > load > co-processor (lowest)
//
// Address decode on addr[20]:
//   INTERNAL (addr[20]=0, block_sel=DRAM) -> DRAM port A (1-cycle BRAM)
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
  input  logic        obi_coproc_req_i,
  output logic        obi_coproc_gnt_o,
  input  logic        obi_coproc_we_i,
  input  logic [31:0] obi_coproc_addr_i,
  input  logic [31:0] obi_coproc_wdata_i,
  output logic        obi_coproc_rvalid_o,
  output logic [31:0] obi_coproc_rdata_o,

  // -- OBI Slave: DRAM port A (raw RAM signals) --
  output logic [RAM_ADDR_WIDTH-1:0]     obi_dram_addr_o,
  output logic                          obi_dram_we_o,
  output logic [RAM_DATA_WIDTH/8-1:0]   obi_dram_be_o,
  output logic [RAM_DATA_WIDTH-1:0]     obi_dram_wdata_o,
  input  logic [RAM_DATA_WIDTH-1:0]     obi_dram_rdata_i,

  // -- OBI Slave: OBI-WB bridge (OBI side -- bridge instantiated in SoC) --
  output logic        obi_wb_req_o,
  input  logic        obi_wb_gnt_i,
  output logic [31:0] obi_wb_addr_o,
  output logic        obi_wb_we_o,
  output logic [3:0]  obi_wb_be_o,
  output logic [31:0] obi_wb_wdata_o,
  input  logic        obi_wb_rvalid_i,
  input  logic [31:0] obi_wb_rdata_i
);

  /* =====================================================================
  *                  Flat Data Bus (one in-flight transaction at a time)
  * ====================================================================== */
  logic [31:0]  data_addr;
  logic         data_req;
  logic         data_gnt;
  logic         data_rvalid;
  logic [3:0]   data_be;
  logic         data_we;
  logic [31:0]  data_wdata;
  logic [31:0]  data_rdata;

  /* =====================================================================
  *                  Address Decode
  * ====================================================================== */
  e_chip_sel    data_chip_sel;
  e_block_sel   data_block_sel;
  logic         data_select_dram;
  logic         data_select_wb;

  assign data_chip_sel    = e_chip_sel'(data_addr[20]);
  assign data_block_sel   = e_block_sel'(data_addr[19:17]);
  assign data_select_dram = (data_chip_sel == INTERNAL) && (data_block_sel == DRAM);
  assign data_select_wb   = (data_chip_sel == EXTERNAL);

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
  logic sel_coproc;         // combinatorial: co-proc lowest priority (only when no CPU req)

  assign sel_store  = obi_cpudata_store_req_i.req;
  assign sel_coproc = obi_coproc_req_i & ~obi_cpudata_store_req_i.req & ~obi_cpudata_load_req_i.req;

  // Mux selected OBI master onto flat bus; suppress while busy
  assign data_req   = (obi_cpudata_store_req_i.req | obi_cpudata_load_req_i.req | obi_coproc_req_i) & ~arb_busy;
  assign data_we    = sel_store  ? obi_cpudata_store_req_i.a.we         :
                      sel_coproc ? obi_coproc_we_i                      :
                                   obi_cpudata_load_req_i.a.we;
  assign data_addr  = sel_store  ? obi_cpudata_store_req_i.a.addr[31:0] :
                      sel_coproc ? obi_coproc_addr_i                     :
                                   obi_cpudata_load_req_i.a.addr[31:0];
  assign data_be    = sel_store  ? obi_cpudata_store_req_i.a.be         :
                      sel_coproc ? 4'hF                                  :  // co-proc: always full-word
                                   obi_cpudata_load_req_i.a.be;
  assign data_wdata = sel_store  ? obi_cpudata_store_req_i.a.wdata      :
                      sel_coproc ? obi_coproc_wdata_i                    :
                                   obi_cpudata_load_req_i.a.wdata;

  /* =====================================================================
  *                  DRAM Port A (raw RAM signals)
  * ====================================================================== */
  assign obi_dram_addr_o  = data_addr[RAM_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET];
  assign obi_dram_we_o    = data_gnt & data_select_dram & data_we;
  assign obi_dram_be_o    = data_be;
  assign obi_dram_wdata_o = data_wdata;

  /* =====================================================================
  *                  OBI-WB Bridge Output (OBI side)
  * ====================================================================== */
  assign obi_wb_req_o   = data_req & data_select_wb;
  assign obi_wb_addr_o  = data_addr;
  assign obi_wb_we_o    = data_we;
  assign obi_wb_be_o    = data_be;
  assign obi_wb_wdata_o = data_wdata;

  /* =====================================================================
  *                  Grant + Arbitration FSM
  *
  *  BRAM path: single-cycle grant (data_gnt = 1 immediately)
  *  WB path:   multi-cycle grant (data_gnt follows obi_wb_gnt_i)
  * ====================================================================== */
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      data_gnt         <= 1'b0;
      arb_busy         <= 1'b0;
      arb_sel_store_q  <= 1'b0;
      arb_sel_coproc_q <= 1'b0;
      arb_wb_q         <= 1'b0;
    end else begin
      data_gnt <= 1'b0;  // pulse for one cycle only (default: deassert)
      if (!arb_busy) begin
        if (data_req & data_select_wb) begin
          // External path: gnt comes from WB bridge (multi-cycle)
          data_gnt <= obi_wb_gnt_i;
          if (obi_wb_gnt_i) begin
            arb_busy         <= 1'b1;
            arb_sel_store_q  <= sel_store;
            arb_sel_coproc_q <= sel_coproc;
            arb_wb_q         <= 1'b1;
          end
        end else if (data_req) begin
          // Internal BRAM path: single-cycle grant
          data_gnt         <= 1'b1;
          arb_busy         <= 1'b1;
          arb_sel_store_q  <= sel_store;
          arb_sel_coproc_q <= sel_coproc;
          arb_wb_q         <= 1'b0;
        end
      end
      if (data_rvalid) begin
        arb_busy         <= 1'b0;
        arb_sel_coproc_q <= 1'b0;
        arb_wb_q         <= 1'b0;
      end
    end
  end

  /* =====================================================================
  *                  Response: rvalid + rdata
  * ====================================================================== */

  // rvalid: one cycle after gnt for BRAM; forwarded from bridge for WB
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) data_rvalid <= 1'b0;
    else         data_rvalid <= arb_wb_q ? obi_wb_rvalid_i : data_gnt;
  end

  // rdata mux: WB bridge or DRAM port A
  always_comb begin
    data_rdata = '0;
    if (arb_wb_q) data_rdata = obi_wb_rdata_i;
    else          data_rdata = obi_dram_rdata_i;
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
      obi_cpudata_store_rsp_o.gnt     = data_gnt;
      obi_cpudata_store_rsp_o.rvalid  = data_rvalid;
      obi_cpudata_store_rsp_o.r.rdata = data_rdata;
    end else if (arb_sel_coproc_q) begin
      obi_coproc_gnt_o    = data_gnt;
      obi_coproc_rvalid_o = data_rvalid;
      obi_coproc_rdata_o  = data_rdata;
    end else begin
      obi_cpudata_load_rsp_o.gnt      = data_gnt;
      obi_cpudata_load_rsp_o.rvalid   = data_rvalid;
      obi_cpudata_load_rsp_o.r.rdata  = data_rdata;
    end
    // On gnt cycle: arb_sel_*_q stale -> override with current selection
    if (!arb_busy) begin
      obi_cpudata_store_rsp_o.gnt = 1'b0;
      obi_cpudata_load_rsp_o.gnt  = 1'b0;
      obi_coproc_gnt_o            = 1'b0;
      if (sel_store) begin
        obi_cpudata_store_rsp_o.gnt = data_gnt;
      end else if (sel_coproc) begin
        obi_coproc_gnt_o = data_gnt;
      end else begin
        obi_cpudata_load_rsp_o.gnt = data_gnt;
      end
    end
  end

endmodule
`default_nettype wire
