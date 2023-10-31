
// This module counts consecutive
// ones in data starting from the MSB
//
// Example: 11001 -> count = 1
// Example: 11101 -> count = 2
// Example: 11111 -> count = 4
//
// It is expected that the MSB is 1, therefore
// count = 0 means the next lowest bit is 0
//
// Example: 10000 -> count = 0
module bit_counter
#(
    parameter int SIZE = 1
)
(
    input logic [SIZE-1:0] data,
    output logic [4:0] count
);
    logic [SIZE-1:0] tmp;

    genvar i;

    // Get the longest streak of ones
    generate
        for (i=0; i<SIZE; i++) begin
            assign tmp[i] = &data[SIZE-1:SIZE-1-i];
        end
    endgenerate

    // Count the bits of tmp
    always_comb begin
        count = 0;
        for (int j=0; j<SIZE; j++) begin
            if (tmp[j]) begin
                /* verilator lint_off WIDTHTRUNC */
                count = j; // Last assignment wins
                /* verilator lint_on WIDTHTRUNC */
            end
        end
    end

endmodule


// This module counts consecutive
// bits in rs0_i starting from any index (31 to 0)
// Example: index = 3, rs0_i = 0001110, rd_o = 2
// This means after index 3 there are two more bits that are 1
// Example: index = 7, rs0_i = 0011110001110, rd_o = 0
// Directly after the bit at index 7 (1) there is a 0, therefore the result is 0
// This means after index 3 there are two more bits that are 1
// Example: index = 5, rs0_i = 0011110000010, rd_o = 3
// There are 4 zero bits in a row starting from index 5
module cntb2
(
    input  logic        clk_i,      // clock
    input  logic        rst_ni,     // reset
    input  logic        start_i,    // start counting
    input  logic [31:0] rs0_i,      // word to count bits for
    input  logic [31:0] rs1_i,      // index to start counting
    output logic [31:0] rd_o,       // output result
    output logic        done_o      // execution done, output valid
); 

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            done_o <= 1'b0;
        end else begin
            done_o <= start_i;
        end
    end

    // Index can be from 0 to 31
    logic [4:0] index;
    assign index = rs1_i[4:0];

    // Get bit value at index (0 or 1)
    logic bit_value;
    assign bit_value = rs0_i[index];
    
    logic [31:0] data;
    
    // Invert because we only count ones
    assign data = bit_value ? rs0_i : ~rs0_i;
    
    genvar i;
    // Stores the results for all indexes
    logic [4:0] results [32];

    // Count the ones for all indexes
    generate
            for (i=1; i<=32; i++) begin
                bit_counter
                #(
                    .SIZE   (i)
                )
                bit_counter_i
                (
                    .data   (data[i-1:0]),
                    .count  (results[i-1])
                );
            end
    endgenerate

    // Now choose the result for our index
    assign rd_o = {27'b0, results[index]};

endmodule
