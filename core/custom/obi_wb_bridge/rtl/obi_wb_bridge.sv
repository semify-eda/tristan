`default_nettype none

// ============================================================================
// CDC capture redesign (2026-06-12) — root-cause fix for the stim_mem ±2 slip
// ============================================================================
// The original bridge sampled the RAW OBI bus directly in the wb_clk domain,
// gated by a `capture` pulse derived from a toggling obi_clk_ff:
//
//     bufr[0] <= obi_clk_ff;
//     bufr[1] <= bufr[0] ^ obi_clk_ff;   // raw obi_clk_ff used AGAIN here
//     capture <= bufr[1];
//     ...
//     if (obi_req_i & obi_state == OBI_IDLE & capture)
//         wb_addr_o <= {12'h0, obi_addr_i[19:0]};   // raw CPU bus sampled
//
// That scheme had three structural CDC hazards, confirmed on hardware as rare
// spurious WB writes with a corrupted low address byte (firmware write to stim
// SWAP_GRANT 0x6002C, data 0x1, executed as stim CTRL 0x60000, data 0x1 —
// ~1 per 25 s, host-independent; see CLAUDE.md "stim_mem ±2 half-buffer slip"):
//
//  1. The capture-pulse synchroniser mixed raw and synchronised signals:
//     obi_clk_ff entered the wb domain at TWO flops over two different routes
//     (bufr[0] and the XOR into bufr[1]). A marginal capture / metastable
//     resolution shifts or doubles the capture pulse. This is an *alignment*
//     property, invisible to STA — and the deliberate set_max_delay
//     -datapath_only on the 25<->100 MHz crossing drops the hold check on
//     exactly these paths, so the tool was structurally blind to it.
//
//  2. obi_addr_i / obi_wdata_i are NOT flop outputs at this boundary — they
//     arrive through the CPU LSU / bus-arbiter mux logic and can GLITCH while
//     settling (a 0xA8 -> 0x2C low-byte transition can transiently read 0x00).
//     A capture pulse landing early (hazard 1) latches such a glitch. STA only
//     checks final settling, never glitching, so no constraint can fix this.
//
//  3. The 2-bit obi_state was decoded raw in the wb domain; its GNT(01) ->
//     AWAIT(10) transition passes through 11 (VALID) / 00 (IDLE) if the two
//     bits skew. obi_req_i was likewise sampled raw.
//
// New scheme — every remaining crossing is either a 2-FF-synchronised single
// bit or a bus that is provably stable when sampled:
//
//     obi_clk domain                          wb_clk domain
//     --------------                          -------------
//     obi_*_q <= raw OBI bus (same-clock      req_sync[1:0] (2-FF sync of
//       sample, fully STA-covered)              req_toggle, ASYNC_REG)
//     req_toggle flips on the SAME edge  -->  wb_pending = sync != seen
//       the obi_*_q regs are captured           (one transaction per toggle)
//                                             WB FSM samples obi_*_q only
//                                               when wb_pending — by then the
//                                               bus has been stable >= 1 full
//                                               wb cycle (>= 10 ns even in a
//                                               worst-case hold race, because
//                                               the toggle passes two extra wb
//                                               flops while the data passes
//                                               none)
//
// Cost: +1 obi_clk cycle of latency per transaction. No port changes.
// ============================================================================

module obi_wb_bridge
#(
    parameter ADDR_W      = 32,
    parameter DATA_W      = 32
)
(
    input  wire obi_clk_i,                          // I - clock driving the OBI state machine -- 25MHz or 50MHz
    input  wire wb_clk_i,                           // I - clock driving the Wishbone state machine -- 100MHz
    input  wire soc_rst_ni,                         // I - SoC reset
    input  wire gbl_rst_ni,                         // I - Global reset

    /********* OBI Signals **********************/
    input  wire                     obi_req_i,      // I - Master requests data transfer, certifies that address & data out is accurate
    output logic                    obi_gnt_o,      // O - Slave acknewledged request and is working on it
    input  wire  [ADDR_W-1 : 0]     obi_addr_i,     // I - Address for data transfer from OBI perspective
    input  wire                     obi_wr_en_i,    // I - Write enable: 0 -> data read, 1 -> data write
    input  wire  [(DATA_W/8)-1 : 0] obi_byte_en_i,  // I - Byte enable: each bit acts as a write enable for the corresponding byte on data line
    input  wire  [DATA_W-1 : 0]     obi_wdata_i,    // I - Data to be written to slave
    output logic                    obi_rvalid_o,   // O - Response from slave is valid and transaciton is complete
    output logic [DATA_W-1 : 0]     obi_rdata_o,    // O - Data read from slave


    /********* Wishbone Master Signals  *********/
    output logic [ADDR_W-1 : 0]     wb_addr_o,      // O - Address for data transfer from Wishbone perspective
    input  wire  [DATA_W-1 : 0]     wb_rdata_i,     // I - Data read from slave
    output logic [DATA_W-1 : 0]     wb_wdata_o,     // O - Data to be written to slave
    output logic                    wb_wr_en_o,     // O - Write enable: 0 -> data read, 1 -> data write
    output logic [(DATA_W/8)-1 : 0] wb_byte_en_o,   // O - Byte enable: each bit acts as a write enable for the corresponding byte on data line
    output logic                    wb_stb_o,       // O - Strobe: held high for the duration of an entire data transfer
    input  wire                     wb_ack_i,       // I - Acknowledge: response from the slave is valid and the transfer is complete
    output logic                    wb_cyc_o        // O - Cycle: held high for the duration of an entire data transaction (multiple transfers)
);

// OBI-domain copy of the request — the ONLY place the raw CPU bus is sampled
// (same-clock, so the sampling is a normal STA-covered 25 MHz path).
// Only addr[19:0] is captured: that is all the WB side ever forwarded.
logic [19 : 0]           obi_addr_q;
logic [DATA_W-1 : 0]     obi_wdata_q;
logic                    obi_wr_en_q;
logic [(DATA_W/8)-1 : 0] obi_byte_en_q;
logic                    obi_pend;        // a captured request is in flight (capture .. rvalid)
logic                    req_toggle;      // flips once per captured request

// wb-domain receive side of the toggle handshake
(* ASYNC_REG = "TRUE" *) logic [1:0] req_sync;  // 2-FF synchroniser for req_toggle
logic                    req_toggle_seen; // last toggle value consumed by the WB FSM
logic                    wb_pending;      // new request waiting (level, held until consumed)

logic                    resp_gate;
logic                    wb_resp_ff;      // WB ack recorded for the slower OBI layer

enum logic [1:0] {
    WB_IDLE,    // no data being transfered to/from WB master
    WB_AWAIT,   // WB layer is awaiting a response from the wishbone slave
    WB_ACK      // WB slave acknowledged request and sent a response
} wb_state;

enum logic [1:0] {
    OBI_IDLE,   // no data being transfered to/from OBI master
    OBI_GNT,    // Wishbone layer acknowledged OBI master transfer request
    OBI_AWAIT,  // OBI master awaiting a response from the wishbone layer
    OBI_VALID   // Send valid signal to OBI Master
} obi_state, obi_next_state;

/********** Reset Handler          ***********/
// gate the responses to the OBI master based on whether a reset invalidated data
// (wb_stb_o / wb_cyc_o are held levels; a marginal 25 MHz sample only moves the
// gate release by one obi cycle, which is harmless)
always_ff @(posedge obi_clk_i, negedge soc_rst_ni) begin
    if (~soc_rst_ni) begin
        resp_gate <= '1;
    end else begin
        /* if a reset happens when there is no transaction taking place */
        if(~wb_stb_o & ~wb_cyc_o) begin
            resp_gate <= '0;
        end else if (wb_resp_ff) begin
            resp_gate <= '0;
        end
    end
end

/********** OBI-domain request capture ********/
// Replaces the old "Multicycle Path Timing" obi_clk_ff/bufr/capture scheme
// (hazards 1+2 above): the raw, potentially-glitching CPU bus is sampled by
// obi_clk flops here, and only these clean flop outputs — which change at
// most once per transaction — are ever seen by the wb domain.
always_ff @(posedge obi_clk_i, negedge soc_rst_ni) begin : obi_request_capture
    if (~soc_rst_ni) begin
        obi_addr_q    <= '0;
        obi_wdata_q   <= '0;
        obi_wr_en_q   <= '0;
        obi_byte_en_q <= '0;
        obi_pend      <= '0;
        req_toggle    <= '0;
    end else begin
        // ~obi_pend implies obi_state == OBI_IDLE (pend spans capture..VALID),
        // so this fires exactly once per OBI transaction
        if (obi_req_i & ~obi_pend) begin
            obi_addr_q    <= obi_addr_i[19:0];
            obi_wdata_q   <= obi_wdata_i;
            obi_wr_en_q   <= obi_wr_en_i;
            obi_byte_en_q <= obi_byte_en_i;
            obi_pend      <= '1;
            req_toggle    <= ~req_toggle;   // same edge as the data capture
        end else if (obi_state == OBI_VALID) begin
            obi_pend      <= '0;            // response handed to the master
        end
    end
end : obi_request_capture

/********** wb-domain toggle synchroniser *****/
// req_toggle is the only obi->wb control crossing left. Unlike the old bufr
// chain, the edge detect compares two REGISTERED values (req_sync[1] vs
// req_toggle_seen) — never the raw input — so a marginal/metastable capture
// can only delay the request by one wb cycle, never split/double the pulse
// or fire it before the obi_*_q data has settled.
// Reset by soc_rst_ni (same reset as req_toggle) so a CPU-only reset cannot
// leave a phantom toggle inequality (= phantom transaction) behind.
always_ff @(posedge wb_clk_i, negedge soc_rst_ni) begin : req_toggle_cdc
    if (~soc_rst_ni) begin
        req_sync        <= '0;
        req_toggle_seen <= '0;
    end else begin
        req_sync <= {req_sync[0], req_toggle};
        if (wb_pending & (wb_state == WB_IDLE)) begin
            req_toggle_seen <= req_sync[1];  // consumed on the same edge the FSM starts
        end
    end
end : req_toggle_cdc

// Level, not a pulse: stays asserted until the WB FSM consumes it, so a busy
// FSM (e.g. still draining a pre-reset transaction) defers the request
// instead of losing it.
assign wb_pending = req_sync[1] ^ req_toggle_seen;

/*************** OBI Layer     ****************/
always_ff @(posedge obi_clk_i, negedge soc_rst_ni) begin : obi_state_assignment
    if(~soc_rst_ni) begin
        obi_state <= OBI_IDLE;
    end else begin
        obi_state <= obi_next_state;
    end
end : obi_state_assignment

always_ff @(posedge wb_clk_i, negedge soc_rst_ni) begin : wb_resp_logic
    if(~soc_rst_ni) begin
        wb_resp_ff <= '0;
    end else begin
        // Was: cleared by decoding obi_state == OBI_VALID across the CDC
        // (hazard 3) and gated by a raw obi_req_i (via obi_trans). Now it is
        // cleared when the NEXT request is accepted — a pure wb-domain
        // condition. It therefore stays high between transactions; that is
        // safe because the OBI FSM only samples it in GNT/AWAIT, which it
        // reaches >= 2 obi cycles (80 ns) after the toggle, while the
        // accept-clear lands <= ~4 wb cycles (40 ns) after the same toggle.
        if (wb_pending & (wb_state == WB_IDLE)) begin
            wb_resp_ff <= '0;
        end else if (wb_ack_i & wb_cyc_o) begin
            // qualified with our own wb_cyc_o so an ack meant for another
            // master on a shared bus segment can never set it
            wb_resp_ff <= '1;
        end
    end
end : wb_resp_logic

always_comb begin : obi_next_state_logic
    obi_next_state = OBI_IDLE;
    case(obi_state)
        OBI_IDLE: begin
            // Was: (wb_cyc_o & wb_stb_o) | wb_resp — an AND of two raw
            // wb-domain flops, whose skewed arrivals could be sampled
            // inconsistently. obi_pend is an obi-domain flop instead. The
            // grant may now precede the WB bus phase, which is fine: the
            // obi_*_q copy keeps the request valid after the master drops it.
            if(obi_pend)
                obi_next_state = OBI_GNT;
            else
                obi_next_state = OBI_IDLE;
        end
        OBI_GNT: begin
            // Was: wb_resp = wb_resp_ff | wb_ack_i — the raw wb_ack_i term
            // came combinationally from the slave and could glitch into this
            // slow-domain sample. wb_resp_ff is a held level (stable until
            // the next accepted request); worst case is +1 obi cycle latency.
            if(wb_resp_ff)
                obi_next_state = OBI_VALID;
            else
                obi_next_state = OBI_AWAIT;
        end
        OBI_AWAIT: begin
            if(wb_resp_ff)
                obi_next_state = OBI_VALID;
            else
                obi_next_state = OBI_AWAIT;
        end
        OBI_VALID: begin
            obi_next_state = OBI_IDLE;
        end
    endcase
end : obi_next_state_logic

/* State Actions */
assign obi_gnt_o    = (OBI_GNT   == obi_state) & ~resp_gate;
assign obi_rvalid_o = (OBI_VALID == obi_state) & ~resp_gate;
/**********************************************/


/*************** Wishbone Layer ***************/
always_ff @(posedge wb_clk_i, negedge gbl_rst_ni) begin : wb_state_assignment
    if(~gbl_rst_ni) begin
        wb_state <= WB_IDLE;
        wb_stb_o <= '0;
        wb_cyc_o <= '0;
        obi_rdata_o  <= '0;
        wb_wr_en_o   <= '0;
        wb_byte_en_o <= '0;
        wb_wdata_o   <= '0;
        wb_addr_o    <= '0;
    end else begin
        case(wb_state)
            WB_IDLE: begin
                // Was: if(obi_req_i & obi_state == OBI_IDLE & capture) with the
                // raw obi_addr_i/obi_wdata_i sampled here (hazards 1-3). With
                // wb_pending the obi_*_q copies are stable by construction:
                // they were captured on the same obi edge that flipped
                // req_toggle, and the toggle needs two extra wb flops to get
                // here while the data path needs none.
                if(wb_pending) begin
                    wb_state     <= WB_AWAIT;
                    wb_stb_o     <= '1;
                    wb_cyc_o     <= '1;
                    wb_wdata_o   <= obi_wdata_q;
                    wb_wr_en_o   <= obi_wr_en_q;
                    wb_byte_en_o <= obi_byte_en_q;
                    wb_addr_o    <= {12'h0, obi_addr_q};
                end
            end
            WB_AWAIT: begin
                if(wb_ack_i) begin
                    wb_state     <= WB_ACK;
                    wb_stb_o     <= '0;
                    wb_cyc_o     <= '0;
                    obi_rdata_o  <= wb_rdata_i;
                    wb_wr_en_o   <= '0;
                    wb_byte_en_o <= '0;
                end
            end
            WB_ACK: begin
                wb_state <= WB_IDLE;
            end
        endcase
    end
end : wb_state_assignment

endmodule
`default_nettype wire
