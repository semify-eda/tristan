
`default_nettype none
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
    input wire [SIZE-1:0] data,
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
// bits in word starting from any index (31 to 0)
// Example: index = 3, word = 0001110, rd_o = 2
// This means after index 3 there are two more bits that are 1
// Example: index = 7, word = 0011110001110, rd_o = 0
// Directly after the bit at index 7 (1) there is a 0, therefore the result is 0
// This means after index 3 there are two more bits that are 1
// Example: index = 5, word = 0011110000010, rd_o = 3
// There are 4 zero bits in a row starting from index 5
module cntb
(
    input  wire        clk_i,      // clock
    input  wire        rst_ni,     // reset
    input  wire        start_i,    // start counting
    input  wire [31:0] word_i,     // word to count bits for
    input  wire [ 4:0] index_i,    // index to start counting
    output wire [ 4:0] result_o,   // output result
    output logic        done_o      // execution done, output valid
); 

    // Control logic
    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            done_o <= 1'b0;
        end else begin
            done_o <= start_i;
        end
    end

    // Get bit value at index (0 or 1)
    logic bit_value;
    assign bit_value = word_i[index_i];
    
    logic [31:0] data;
    
    // Invert because we only count ones
    assign data = bit_value ? word_i : ~word_i;
    
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
    assign result_o = results[index_i];

endmodule
`default_nettype wire