`default_nettype none
// import wfg_pkg::*;

module obi_wb_bridge
#(
    parameter ADDR_W      = 32,
    parameter DATA_W      = 32,
    parameter I2C_MASK    = 4'hE,
    parameter PINMUX_MASK = 4'hF
)
(
    input logic clk_i,
    input logic rst_ni,

    /********* OBI Signals **********************/
    input  logic                    obi_req_i,      // I - Master requests data transfer, certifies that address & data out is accurate
    output logic                    obi_gnt_o,      // O - Slave acknewledged request and is working on it
    input  logic [ADDR_W-1 : 0]     obi_addr_i,     // I - Address for data transfer from OBI perspective
    input  logic                    obi_wr_en_i,    // I - Write enable: 0 -> data read, 1 -> data write
    input  logic [(DATA_W/8)-1 : 0] obi_byte_en_i,  // I - Byte enable: each bit acts as a write enable for the corresponding byte on data line
    input  logic [DATA_W-1 : 0]     obi_wdata_i,    // I - Data to be written to slave
    output logic                    obi_rvalid_o,   // O - Response from slave is valid and transaciton is complete
    output logic [DATA_W-1 : 0]     obi_rdata_o,    // O - Data read from slave


    /********* Wishbone Master Signals  *********/
    output logic [ADDR_W-1 : 0]     wb_addr_o,      // O - Address for data transfer from Wishbone perspective
    input  logic [DATA_W-1 : 0]     wb_rdata_i,     // I - Data read from slave
    output logic [DATA_W-1 : 0]     wb_wdata_o,     // O - Data to be written to slave
    output logic                    wb_wr_en_o,     // O - Write enable: 0 -> data read, 1 -> data write
    output logic [(DATA_W/8)-1 : 0] wb_byte_en_o,   // O - Byte enable: each bit acts as a write enable for the corresponding byte on data line
    output logic                    wb_stb_o,       // O - Strobe: held high for the duration of an entire data transfer
    input  logic                    wb_ack_i,       // I - Acknowledge: response from the slave is valid and the transfer is complete
    output logic                    wb_cyc_o        // O - Cycle: held high for the duration of an entire data transaction (multiple transfers)

    /* 
    * TODO: Add Wishbone slave interface to configure MMU 
    */
);

logic       bridge_en;
logic [7:0] block_sel;

/* 
* TODO: Add MMU functionality to enable/disable accessing certain blocks/addresses 
*/

enum logic [1:0] {
    IDLE,  // no data being transfered
    REQ,   // request from OBI toggled and address asserted 
    AWAIT, // wait for the data to be received from WB
    RESP   // response sent to OBI
} state, next_state;

always_ff @(posedge clk_i, negedge rst_ni) begin : state_assignment
    if (~rst_ni) begin
        state   <= IDLE;
    end else begin
        state   <= next_state;
    end
end : state_assignment

assign block_sel = obi_addr_i[31:24];
assign bridge_en = (block_sel == I2C_MASK | block_sel == PINMUX_MASK);

always_comb begin : next_state_logic
    next_state = IDLE;
    case(state)
        IDLE: begin
            if(obi_req_i & bridge_en)   
                next_state = REQ;
            else        
                next_state = IDLE;
        end
        REQ: begin
            next_state = AWAIT;
        end
        AWAIT: begin
            if(wb_ack_i) next_state = RESP;
            else         next_state = AWAIT;
        end
        RESP: begin
            next_state = IDLE;
        end
    endcase
end : next_state_logic

always_comb begin : state_actions_comb
    obi_gnt_o    = 1'b0;
    obi_rvalid_o = 1'b0;
    wb_cyc_o     = 1'b0;
    wb_stb_o     = 1'b0;
    case(state)
        REQ: begin
            // latch onto OBI addr and data in this state
            obi_gnt_o = 1'b1;
            wb_cyc_o  = 1'b1;
            wb_stb_o  = 1'b1;
        end
        AWAIT: begin
            wb_cyc_o = 1'b1;
            wb_stb_o = 1'b1;
        end
        RESP: begin
            obi_rvalid_o = 1'b1;
        end
    endcase
end : state_actions_comb

always_ff @(posedge clk_i) begin : state_actions_ff
    wb_wr_en_o   <= obi_wr_en_i;
    wb_byte_en_o <= obi_byte_en_i;
    case(state)
        IDLE: begin
            // SoC to Smartwave peripheral address translation
            /* TODO: expand address translation when MMU is added */
            if(block_sel == PINMUX_MASK) begin
                wb_addr_o <= {12'h0, 3'h2, 4'h3, 5'h0, 8'h0};
                // wb_addr_o <= {12'h0, D_P_MATRIX_ADDR, 8'h0};  // from pkg
            end
            else if(block_sel == I2C_MASK) begin
                wb_addr_o <= {12'h0, 3'h4, 4'h3, 5'h0, 8'h0};
                // wb_addr_o <= {12'h0, DRIVE_I2CT_MODULE_ADDR, 5'h0, 8'h0}; // from pkg
            end
            wb_wdata_o  <= obi_wdata_i;
        end
        AWAIT: begin
            obi_rdata_o <= wb_rdata_i;
        end
    endcase
end : state_actions_ff

endmodule