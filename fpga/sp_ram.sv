`default_nettype none

module sp_ram
#(
    parameter ADDR_WIDTH = 8
)
(
    input logic                  clk_i,

    input logic                  en_i,
    input logic [ADDR_WIDTH-1:0] addr_i,
    input logic [31:0]           wdata_i,
    output logic [31:0]          rdata_o,
    input logic                  we_i,
    input logic [3:0]            be_i
 );

    localparam bytes = 2**ADDR_WIDTH;

    logic [31:0]                     mem[bytes/4];
    logic [ADDR_WIDTH-1:0]           addr_int;

    always_comb addr_int = addr_i[ADDR_WIDTH-1:2];

    always_ff @(posedge clk_i) begin

        // addr_i is the actual memory address referenced
        if (en_i) begin
            // handle writes
            if (we_i) begin
                if (be_i[0]) mem[addr_int][ 7: 0] <= wdata_i[ 0+:8];
                if (be_i[1]) mem[addr_int][15: 8] <= wdata_i[ 8+:8];
                if (be_i[2]) mem[addr_int][23:16] <= wdata_i[16+:8];
                if (be_i[3]) mem[addr_int][31:24] <= wdata_i[24+:8];
            end
            // handle reads
            else begin
                rdata_o <= mem[addr_int];
            end
        end
    end

endmodule
