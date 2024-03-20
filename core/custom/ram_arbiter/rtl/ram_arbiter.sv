`default_nettype none
`timescale 1ns/1ps

module ram_arbiter
#(
    parameter SOC_ADDR_WIDTH = 32
)(
    input               clk_i,
    input               rst_ni,

    // I RAM signals
    input  logic [SOC_ADDR_WIDTH-1:0] cpu_instr_addr_i,
    input  logic                      cpu_instr_req_i,
    output logic                      cpu_instr_gnt_o,
    output logic                      cpu_instr_rvalid_o,
    output logic [31 : 0]             cpu_instr_rdata_o,

    // D RAM signals
    input  logic [SOC_ADDR_WIDTH-1:0] cpu_data_addr_i,
    input  logic                      cpu_data_req_i,
    output logic                      cpu_data_gnt_o,
    output logic                      cpu_data_rvalid_o,
    output logic [31 : 0]             cpu_data_rdata_o,
    input  logic [3 : 0]              cpu_data_be_i,
    input  logic                      cpu_data_we_i,
    input  logic [31 : 0]             cpu_data_wdata_i,

    // unified signals
    input  logic                      soc_rvalid_i,
    input  logic                      soc_gnt_i,
    output logic                      soc_req_o,
    output logic [SOC_ADDR_WIDTH-1:0] soc_addr_o,
    output logic [3 : 0]              soc_be_o,
    output logic                      soc_we_o,
    output logic [31 : 0]             soc_wdata_o,
    input  logic [31 : 0]             soc_rdata_i

);

typedef enum {
    GNT_NONE,
    GNT_DATA,
    GNT_INSTR
} arbiter_t;

arbiter_t cur_granted;

always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
        cur_granted <= GNT_NONE;
    end else begin
        // Bus is free
        if (cur_granted == GNT_NONE) begin
            // Data has precedence
            if (cpu_instr_req_i)  cur_granted <= GNT_INSTR;
            if (cpu_data_req_i)   cur_granted <= GNT_DATA;
        end else begin
            // Free the bus
            if (soc_rvalid_i) begin
                cur_granted <= GNT_NONE;
            end
        end
    end
end

always_comb begin
    // default values
    soc_req_o     = '0;
    soc_addr_o    = '0;
    soc_be_o      = '0;
    soc_we_o      = '0;
    soc_wdata_o   = '0;
    
    cpu_instr_gnt_o       = '0;
    cpu_instr_rvalid_o    = '0;
    cpu_instr_rdata_o     = '0;
    
    cpu_data_gnt_o        = '0;
    cpu_data_rvalid_o     = '0;
    cpu_data_rdata_o      = '0;

    if (cur_granted == GNT_INSTR) begin
        // don't request the next transaction before the arbiter has switched
        soc_req_o     = cpu_instr_req_i && !soc_rvalid_i;
        soc_addr_o    = cpu_instr_addr_i;
        
        cpu_instr_gnt_o       = soc_gnt_i;
        cpu_instr_rvalid_o    = soc_rvalid_i;
        cpu_instr_rdata_o     = soc_rdata_i;
    end
    if (cur_granted == GNT_DATA) begin
        // don't request the next transaction before the arbiter has switched
        soc_req_o     = cpu_data_req_i && !soc_rvalid_i;
        soc_addr_o    = cpu_data_addr_i;
        soc_be_o      = cpu_data_be_i;
        soc_we_o      = cpu_data_we_i;
        soc_wdata_o   = cpu_data_wdata_i;
        
        cpu_data_gnt_o        = soc_gnt_i;
        cpu_data_rvalid_o     = soc_rvalid_i;
        cpu_data_rdata_o      = soc_rdata_i;
    end
end

endmodule