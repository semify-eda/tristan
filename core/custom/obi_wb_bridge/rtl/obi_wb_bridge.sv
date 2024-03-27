`default_nettype none

module obi_wb_bridge
#(
    parameter ADDR_W      = 32,
    parameter DATA_W      = 32
)
(
    input  wire obi_clk_i,                          // I - clock driving the OBI state machine -- 25MHz or 50MHz
    input  wire wb_clk_i,                           // I - clock driving the Wishbone state machine -- 100MHz
    input  wire rst_ni,                             // I - global reset
    input  wire en,                                 // I - enable

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

    /* 
    * TODO: Add Wishbone slave interface to configure MMU 
    */
);

/*************** OBI Layer     ****************/
enum logic [1:0] {
    OBI_IDLE,   // no data being transfered to/from OBI master
    OBI_GNT,    // Wishbone layer acknowledged OBI master transfer request
    OBI_AWAIT,  // OBI master awaiting a response from the wishbone layer
    OBI_VALID   // Send valid signal to OBI Master
} obi_state, obi_next_state;

always_ff @(posedge obi_clk_i, negedge rst_ni) begin : obi_state_assignment
    if(~rst_ni) begin
        obi_state <= OBI_IDLE;
    end else begin
        obi_state <= obi_next_state;
    end
end : obi_state_assignment

// ensures that the wb response is recorded so that the slower OBI layer can accurately detect it
logic wb_resp;
logic wb_resp_ff;

assign wb_resp = wb_resp_ff | wb_ack_i;

always_ff @(posedge wb_clk_i, negedge rst_ni) begin : wb_resp_logic
    if(~rst_ni) begin
        wb_resp_ff <= '0;
    end else begin
        if(obi_req_i) begin
            // reset the wb valid flag when it is handed off to the OBI rvalid signal            
            if(obi_rvalid_o) begin
                wb_resp_ff <= '0;
            end else if(wb_ack_i) begin
                wb_resp_ff <= '1;
            end
        end
    end
end : wb_resp_logic

always_comb begin : obi_next_state_logic
    obi_next_state = OBI_IDLE;
    case(obi_state)
        OBI_IDLE: begin
            if((wb_cyc_o & wb_stb_o) | wb_resp) 
                obi_next_state = OBI_GNT;
            else
                obi_next_state = OBI_IDLE;
        end
        OBI_GNT: begin
            if(wb_resp)
                obi_next_state = OBI_VALID;
            else
                obi_next_state = OBI_AWAIT;
        end 
        OBI_AWAIT: begin
            if(wb_resp)
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
assign obi_gnt_o    = (OBI_GNT   == obi_state);
assign obi_rvalid_o = (OBI_VALID == obi_state);
/**********************************************/


/*************** Wishbone Layer ***************/
enum logic [1:0] {
    WB_IDLE,    // no data being transfered to/from WB master
    WB_AWAIT,   // WB layer is awaiting a response from the wishbone slave
    WB_ACK      // WB slave acknowledged request and sent a response
} wb_state;

always_ff @(posedge wb_clk_i, negedge rst_ni) begin : wb_state_assignment
    if(~rst_ni) begin
        wb_state <= WB_IDLE;
        wb_stb_o <= '0;
        wb_cyc_o <= '0;
    end else begin
        case(wb_state)
            WB_IDLE: begin
                if(obi_req_i & en & obi_state == OBI_IDLE) begin
                    wb_state     <= WB_AWAIT;
                    wb_stb_o     <= '1;
                    wb_cyc_o     <= '1;
                    wb_addr_o    <= {12'h0, obi_addr_i[19:0]};
                    wb_wdata_o   <= obi_wdata_i;
                    wb_wr_en_o   <= obi_wr_en_i;
                    wb_byte_en_o <= obi_byte_en_i;
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