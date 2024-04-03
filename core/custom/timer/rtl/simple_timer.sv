// ---------------------------------------------------------------------------
//                    Copyright Message
// ---------------------------------------------------------------------------
//
// CONFIDENTIAL and PROPRIETARY
// COPYRIGHT (c) 2024 semify GmbH
//
// All rights are reserved. Reproduction in whole or in part is
// prohibited without the written consent of the copyright owner.
//
// ---------------------------------------------------------------------------
//                    Design Information
// ---------------------------------------------------------------------------
//
// Author     : Adam Horvath
// Description: Generic timer with enable functionality
//
// Parameters :
//   - WIDTH  : Count register bit width
//
// ---------------------------------------------------------------------------
//                    Revision History (written manually)
// ---------------------------------------------------------------------------
//
// Date        Author       Change Description
// ==========  ==========   ====================================================
// 2024-03-27  adam-hrvth   Initial release

`default_nettype none

`timescale 1ns/1ps

module simple_timer #(
    parameter WIDTH = 8
)(
    // -------------------------------------------------------------------------------------------------
    // Inputs
    // -------------------------------------------------------------------------------------------------
    input wire                   clk_i,     // I - Clock input
    input wire                   rst_n_i,   // I - Asynchronous reset
	input wire					 load_i,	// I - Control signal to load start value 
	input wire [WIDTH - 1 : 0]	 d_i,		// I - Timer start value
    input wire                   en_i,      // I - Timer enable
    // -------------------------------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------------------------------
    output logic [WIDTH - 1 : 0] q_o,       // O - Timer current value
    output logic                 tick_o     // O - Tick event raised when counter reaches zero
);

    // -------------------------------------------------------------------------------------------------
    // Definitions
    // -------------------------------------------------------------------------------------------------
    logic [WIDTH - 1 : 0] r_count_val;        // Register for counter value
    logic [WIDTH - 1 : 0] r_next_count;       // Register for next counter value
    
    // -------------------------------------------------------------------------------------------------
    // Implementation
    // -------------------------------------------------------------------------------------------------
    assign r_next_count = q_o + {{(WIDTH-1){1'b0}}, 1'b1};
	assign r_count_val = (r_next_count == WIDTH) ? {(WIDTH){1'b0}} : r_next_count;    // Reset if max count is reached, else, take next counter value	
	assign tick_o = (q_o == WIDTH-1) ? 1'b1 : 1'b0;     // If max count is reached, raise tick signal

    always_ff @(posedge clk_i, negedge rst_n_i) begin
        if(~rst_n_i)begin
            q_o <= {(WIDTH){1'b0}};
        end
        else begin
            if(en_i) begin
				if(load_i) begin
					q_o <= d_i;
				end else begin
					q_o <= r_count_val;
				end
            end
        end
    end
                                   

endmodule
`default_nettype wire