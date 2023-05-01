// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns / 1ps

// TODO rename spi_flash_controller
module spi_flash (
    input clk,
    input reset,

    input  [23:0]       addr_in,  // address of word
    output logic [31:0] data_out, // received word
    input               strobe,   // start transmission
    output logic        done,     // pulse, transmission done
    output logic        initialized, // initial cmds sent

    // SPI signals
    output sck,
    output sdo,
    input  sdi,
    output cs
);

    localparam bit [7:0] CMD_MODE_BIT_RESET = 8'hFF;
    localparam bit [7:0] CMD_WAKEUP         = 8'hAB;
    localparam bit [7:0] CMD_READ           = 8'h03;

    logic [23:0] current_address;

    typedef enum {
        ST_MODE_BIT_RESET,
        ST_MODE_BIT_RESET_2,
        ST_WAKEUP,
        ST_WAKEUP_2,
        ST_READ,
        ST_ADDR_0,
        ST_ADDR_1,
        ST_ADDR_2,
        ST_DATA_0,
        ST_DATA_1,
        ST_DATA_2,
        ST_DATA_3,
        ST_CONTINUE
    } spi_flash_states_t;
    
    spi_flash_states_t current_state;
    
    logic [7:0] spi_shifter_data_in;
    logic [7:0] spi_shifter_data_out;
    logic spi_shifter_strobe;
    logic spi_shifter_busy;
    logic spi_shifter_done;
    logic spi_shifter_deassert_cs;

    spi_shifter spi_shifter_inst (
        .clk,
        .reset,

        .data_in    (spi_shifter_data_in),
        .data_out   (spi_shifter_data_out),
        .strobe     (spi_shifter_strobe),
        .busy       (spi_shifter_busy),
        .done       (spi_shifter_done),
        .deassert_cs(spi_shifter_deassert_cs),

        .sck,
        .sdo,
        .sdi,
        .cs
    );
    
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            data_out    <= '0;
            done        <= 1'b0;
            initialized <= 1'b0;
            current_address         <= '0;
            current_state           <= ST_MODE_BIT_RESET;
            spi_shifter_data_in     <= '0;
            spi_shifter_strobe      <= 1'b0;
            spi_shifter_deassert_cs <= 1'b0;
        end else begin
            done                    <= 1'b0;
            spi_shifter_strobe      <= 1'b0;
            spi_shifter_deassert_cs <= 1'b0;

            case (current_state)
                ST_MODE_BIT_RESET: begin
                    spi_shifter_data_in <= CMD_MODE_BIT_RESET;
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        current_state <= ST_MODE_BIT_RESET_2;
                    end
                end
                ST_MODE_BIT_RESET_2: begin
                    spi_shifter_deassert_cs <= 1'b1;
                    current_state <= ST_WAKEUP;
                end
                ST_WAKEUP: begin
                    spi_shifter_data_in <= CMD_WAKEUP;
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        current_state <= ST_WAKEUP_2;
                    end
                end
                ST_WAKEUP_2: begin
                    spi_shifter_deassert_cs <= 1'b1;
                    initialized <= 1'b1;
                    if (strobe) begin
                        current_state <= ST_READ;
                        current_address <= {addr_in[23:2], 2'b00}; // align to word address
                    end
                end
                ST_READ: begin
                    spi_shifter_data_in <= CMD_READ;
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        current_state <= ST_ADDR_0;
                    end
                end
                ST_ADDR_0: begin
                    spi_shifter_data_in <= current_address[23:16];
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        current_state <= ST_ADDR_1;
                    end
                end
                ST_ADDR_1: begin
                    spi_shifter_data_in <= current_address[15:8];
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        current_state <= ST_ADDR_2;
                    end
                end
                ST_ADDR_2: begin
                    spi_shifter_data_in <= current_address[7:0];
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        current_state <= ST_DATA_0;
                    end
                end
                ST_DATA_0: begin
                    spi_shifter_data_in <= 8'b00; // dummy data
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        data_out[7:0] <= spi_shifter_data_out;
                        current_state <= ST_DATA_1;
                    end
                end
                ST_DATA_1: begin
                    spi_shifter_data_in <= 8'b00; // dummy data
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        data_out[15:8] <= spi_shifter_data_out;
                        current_state <= ST_DATA_2;
                    end
                end
                ST_DATA_2: begin
                    spi_shifter_data_in <= 8'b00; // dummy data
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        data_out[23:16] <= spi_shifter_data_out;
                        current_state <= ST_DATA_3;
                    end
                end
                ST_DATA_3: begin
                    spi_shifter_data_in <= 8'b00; // dummy data
                    if (!spi_shifter_busy) spi_shifter_strobe <= 1'b1;

                    if (spi_shifter_done) begin
                        data_out[31:24] <= spi_shifter_data_out;
                        current_state <= ST_CONTINUE;
                        done <= 1'b1;
                    end
                end
                ST_CONTINUE: begin
                    if (strobe && !done) begin
                        // If the next read is continuous, just read the data
                        if (addr_in == current_address + 4) begin
                            current_state <= ST_DATA_0;
                        // Else terminate current cmd and start anew
                        end else begin
                            spi_shifter_deassert_cs <= 1'b1;
                            current_state <= ST_READ;
                        end
                        // Set new address
                        current_address <= {addr_in[23:2], 2'b00}; // align to word address
                    end
                end
                default: begin
                    data_out <= 'x;
                    done     <= 'x;
                end
            endcase
        end
    end
endmodule

module spi_shifter (
    input clk,
    input reset,

    input  [7:0]        data_in,     // data to send
    output logic [7:0]  data_out,    // data received
    input               strobe,      // start transmission
    output logic        busy,        // transmission in progress
    output logic        done,        // pulse, transmission done
    input               deassert_cs, // deassert CS

    // SPI signals
    output logic    sck,
    output          sdo,
    input           sdi,
    output logic    cs
);

    localparam bit CS_ASSERT = 1'b0;
    localparam bit CS_DEASSERT = 1'b1;

    logic [3:0] remaining_bits;
    logic [7:0] data_shift;
    
    /*
    SCK: low when inactive
    SDO: MSB first, write on falling edge
    SDI: MSB first, read on falling edge
    CS: active low
    */

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            data_out        <= '0;
            busy            <= 1'b0;
            done            <= 1'b0;
            sck             <= 1'b0;
            cs              <= CS_DEASSERT;
            remaining_bits  <= '0;
            data_shift      <= '0;
        end else begin
            done <= 1'b0;
            busy <= 1'b0;
            sck  <= 1'b0;

            // New command -> deassert CS
            if (deassert_cs && remaining_bits == 0) begin
                cs <= CS_DEASSERT;
            end

            // Start transmission
            if (strobe && remaining_bits == 0) begin
                data_out        <= '0;
                busy            <= 1'b1;
                cs              <= CS_ASSERT;
                remaining_bits  <= 8;
                data_shift      <= data_in;
            end

            // Toggle sck, shift bits
            if (remaining_bits) begin
                sck <= !sck;
                busy <= 1'b1;

                if (sck) begin
                    data_shift      <= {data_shift[6:0], 1'b0};
                    data_out        <= {data_out[6:0], sdi};
                    remaining_bits  <= remaining_bits - 1'b1;
                    
                    // Pulse done
                    if (remaining_bits == 'd1) begin
                        done <= 1'b1;
                    end
                end
            end
        end
    end

    // Shift MSB first
    assign sdo = data_shift[7];

endmodule
