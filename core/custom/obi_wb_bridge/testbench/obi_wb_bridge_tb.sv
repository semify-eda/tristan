// Copyright 2017 Embecosm Limited <www.embecosm.com>
// Copyright 2018 Robert Balas <balasr@student.ethz.ch>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Top level wrapper for a RI5CY testbench
// Contributor: Robert Balas <balasr@student.ethz.ch>
//              Jeremy Bennett <jeremy.bennett@embecosm.com>

`timescale 1ns/1ps
module obi_wb_bridge_tb;

    localparam BAUDRATE          = 115200;
    localparam SOC_ADDR_WIDTH    = 32;
    localparam RAM_ADDR_WIDTH    = 14;
    localparam INSTR_RDATA_WIDTH = 32;
    localparam BOOT_ADDR         = 32'h02000000 + 24'h200000; // TODO set inside cv32e40x_top
    parameter int CLK_FREQ       = 25_000_000;
    parameter int  SER_BIT_PERIOD_NS = 1_000_000_000 / BAUDRATE;

    logic core_clk;
    logic core_rst_n;

    // allow fst dump
    initial begin
        $dumpfile("wb_obi_test.vcd");
        $dumpvars();
    end


    // ----------------------------------
    //           CV32E40X Core
    // ----------------------------------
    cv32e40x_soc
    #(
        .SOC_ADDR_WIDTH    (SOC_ADDR_WIDTH),
        .RAM_ADDR_WIDTH    (RAM_ADDR_WIDTH),
        .INSTR_RDATA_WIDTH (INSTR_RDATA_WIDTH),
        .CLK_FREQ          (CLK_FREQ),
        .BAUDRATE          (BAUDRATE),
        .BOOT_ADDR         (BOOT_ADDR)
    )
    cv32e40x_soc
    (
        .clk_i          ( core_clk     ),
        .rst_ni         ( core_rst_n   ),
        .ser_tx,
        .ser_rx,

        // OBI interface
        .obi_req_o      (req_obi),
        .obi_gnt_i      (gnt_obi),
        .obi_addr_o     (addr_obi),
        .obi_we_o       (wr_en_obi),
        .obi_be_o       (byte_en_obi),
        .obi_wdata_o    (wdata_obi),
        .obi_rvalid     (rvalid_obi),
        .obi_rdata      (rdata_obi)

    );

    // ----------------------------------
    //           OBI Wishbone Bridge
    // ----------------------------------
    logic                    req_obi;
    logic                    gnt_obi;
    logic [31 : 0]           addr_obi;
    logic                    wr_en_obi;
    logic [3 : 0]            byte_en_obi;
    logic [31 : 0]           wdata_obi;
    logic                    rvalid_obi;
    logic [31 : 0]           rdata_obi;

    logic [31 : 0]           addr_wb;
    logic [31 : 0]           data_i_wb;
    logic [31 : 0]           data_o_wb;
    logic                    wr_en_wb;
    logic [3 : 0]            byte_en_wb;
    logic                    stb_wb;
    logic                    ack_wb;
    logic                    cyc_wb;

    obi_wb_bridge i_obi_wb_bridge
    (
        .clk_i      (core_clk),
        .rst_ni     (core_rst_n),

        /********* OBI Signals **********************/
        .req_i      (req_obi),
        .gnt_o      (gnt_obi),
        .addr_i     (addr_obi),
        .wr_en_i    (wr_en_obi),
        .byte_en_i  (byte_en_obi),
        .wdata_i    (wdata_obi),
        .rvalid_o   (rvalid_obi),
        .rdata_o    (rdata_obi),

        /********* Wishbone Master Signals  *********/
        .addr_o     (addr_wb),
        .data_i     (data_i_wb),
        .data_o     (data_o_wb),
        .wr_en_o    (wr_en_wb),
        .byte_en_o  (byte_en_wb),
        .stb_o      (stb_wb),
        .ack_i      (ack_wb),
        .cyc_o      (cyc_wb)
    );

    logic ser_tx;
    logic ser_rx = 1'b1;
    
    logic [7:0] recv_byte = 0;

    always @(negedge ser_tx) begin
        read_byte_ser;
    end

    task automatic read_byte_ser;
        #(SER_BIT_PERIOD_NS / 2);  // Wait half baud
        if ((ser_tx == 0)) begin

            #SER_BIT_PERIOD_NS;

            // Read data LSB first
            for (int j = 0; j < 8; j++) begin
                recv_byte[j] = ser_tx;
                #SER_BIT_PERIOD_NS;
            end

            if ((ser_tx == 1)) begin
                $display("cpu --> uart: 0x%h '%c'", recv_byte, recv_byte);
            end
        end
    endtask

    task automatic send_byte_ser(input bit [7:0] data);
        $display("uart --> cpu: 0x%h '%c'", data, data);

        // Start bit
        ser_rx = 0;
        #SER_BIT_PERIOD_NS;

        // Send data LSB first
        for (int i = 0; i < 8; i++) begin
            ser_rx = data[i];
            #SER_BIT_PERIOD_NS;
        end

        // Stop bit
        ser_rx = 1;
        #SER_BIT_PERIOD_NS;
    endtask

endmodule