`default_nettype none
module wb_ram_interface #(
    parameter WB_ADDR_WIDTH  = 32,
    parameter RAM_ADDR_WIDTH = 32,
    parameter RAM_DATA_WIDTH = 32,
    parameter IRAM_ADDR_MASK = {3'h1, 4'h8},
    parameter DRAM_ADDR_MASK = {3'h1, 4'h9}
)(
    input  wire  wb_clk_i,                          // I - clock signal for wishbone state machine
    input  wire  ram_clk_i,                         // I - clock signal for ram state machine
    input  wire  rst_ni,                            // I - global reset

    /************ Wishbone Signals  *************/
    input  wire  [WB_ADDR_WIDTH-1:0]    wb_addr_i,  // I - address requested by wishbone master, must be translated
    output logic [31 : 0]               wb_rdata_o, // O - data to be sent to wishbone master from RAM
    input  wire  [31 : 0]               wb_wdata_i, // I - data to be written to RAM by the wishbone master
    input  wire                         wb_wr_en_i, // I - write enable: asserted indicated a write, deasserted indicated a read
    input  wire                         wb_stb_i,   // I - strobe: indicates wishbone master is initiating a transfer
    output logic                        wb_ack_o,   // O - acknowledge : asserted 1 wb_clk cycle after RAM responds
    input  wire                         wb_cyc_i,   // I - cycle: indicated wishbone master is initiating a transfer

    /*************** RAM Signals  ****************/
    output logic [RAM_ADDR_WIDTH-1 : 0] ram_addr_o, // O - address to be output to the RAM
    output logic [RAM_DATA_WIDTH-1 : 0] ram_data_o, // O - data to be written to RAM
    input  wire  [RAM_DATA_WIDTH-1 : 0] iram_data_i,// I - data read from IRAM
    input  wire  [RAM_DATA_WIDTH-1 : 0] dram_data_i,// I - data read from DRAM
    output logic                        iram_we_o,  // O - write Enable sent to IRAM
    output logic                        dram_we_o   // O - write enable sent to DRAM
);

    logic select_iram;
    logic select_dram;
    logic ram_comm;

    assign select_iram = (wb_addr_i[19:13] == IRAM_ADDR_MASK);
    assign select_dram = (wb_addr_i[19:13] == DRAM_ADDR_MASK);
    assign ram_comm    = select_dram | select_iram;

    /*************** Wishbone Signals *************/
    enum logic {
        WB_IDLE,   // no data being transfered
        WB_RESP    // return acknowledge signal and read data
    } wb_state, wb_next_state;

    always_ff @(posedge wb_clk_i, negedge rst_ni) begin : wb_state_assignment
        if (~rst_ni) begin
            wb_state  <= WB_IDLE;
            wb_ack_o  <= '0;
        end else begin : wb_state_actions
            wb_state  <= wb_next_state;
            case(wb_state)
                WB_IDLE: begin
                    if(ram_state == RAM_RESP & ram_comm) begin
                        wb_ack_o   <= '1;
                        wb_rdata_o <= select_iram ? iram_data_i : dram_data_i;
                    end
                end
                WB_RESP: begin
                    wb_ack_o <= '0;
                end
            endcase
        end : wb_state_actions
    end : wb_state_assignment

    always_comb begin : wb_next_state_logic
        wb_next_state = WB_IDLE;
        case(wb_state)
            WB_IDLE: begin
                if(ram_state == RAM_RESP) wb_next_state = WB_RESP;
                else                      wb_next_state = WB_IDLE;
            end
            WB_RESP: begin
                wb_next_state = WB_IDLE;
            end
        endcase
    end : wb_next_state_logic
    /**********************************************/

    /*************** RAM Signals ******************/
    enum logic [1:0] {
        RAM_IDLE,   // no data being transfered
        RAM_REQ,    // RAM receives a read/write request
        RAM_RESP    // RAM responds
    } ram_state, ram_next_state;

    always_ff @(posedge ram_clk_i, negedge rst_ni) begin : ram_state_assignment
        if (~rst_ni) begin
            ram_state <= RAM_IDLE;
        end else begin : ram_state_actions
            ram_state <= ram_next_state;
            case(ram_state)
                RAM_IDLE: begin
                    if(ram_comm & wb_stb_i & wb_cyc_i) begin
                        ram_addr_o <= wb_addr_i[RAM_ADDR_WIDTH-1 : 0];
                        ram_data_o <= wb_wdata_i;
                        iram_we_o  <= select_iram & wb_wr_en_i & (wb_state == WB_IDLE);
                        dram_we_o  <= select_dram & wb_wr_en_i & (wb_state == WB_IDLE); 
                    end
                end
                RAM_REQ: begin
                    iram_we_o <= '0;
                    dram_we_o <= '0;
                end
            endcase
        end : ram_state_actions
    end : ram_state_assignment

    always_comb begin : ram_next_state_logic
        ram_next_state = RAM_IDLE;
        case(ram_state)
            RAM_IDLE: begin
                if(wb_stb_i & wb_cyc_i & (wb_state == WB_IDLE)) 
                    ram_next_state = RAM_REQ;
                else
                    ram_next_state = RAM_IDLE;
            end
            RAM_REQ: begin
                ram_next_state = RAM_RESP;
            end
            RAM_RESP: begin
                ram_next_state = RAM_IDLE;
            end
        endcase
    end : ram_next_state_logic
    /**********************************************/

endmodule