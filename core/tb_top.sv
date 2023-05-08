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
`define TB_CORE

module tb_top;

    localparam BAUDRATE       = 115200;

    parameter time CLK_PHASE_HI       = 20;
    parameter time CLK_PHASE_LO       = 20;
    parameter time CLK_PERIOD         = CLK_PHASE_HI + CLK_PHASE_LO;
    parameter int  CLK_FREQ           = 1_000_000_000 / CLK_PERIOD;
    parameter time STIM_APPLICATION_DEL = CLK_PERIOD * 0.1;
    parameter time RESP_ACQUISITION_DEL = CLK_PERIOD * 0.9;
    parameter time RESET_DEL = STIM_APPLICATION_DEL;
    parameter int  RESET_WAIT_CYCLES  = 4;
    parameter int  SER_BIT_PERIOD_NS = 1_000_000_000 / BAUDRATE;

    // clock and reset for tb
    logic                   core_clk;
    logic                   core_rst_n;

    // cycle counter
    int unsigned            cycle_cnt_q;

    // allow fst dump
    initial begin
        if ($test$plusargs("fst")) begin
            $dumpfile("tb_top.fst");
            $dumpvars(0, tb_top);
        end
    end

    // we either load the provided firmware or execute a small test program that
    // doesn't do more than an infinite loop with some I/O
    // TODO execute directly from SPI Flash
    /*initial begin: load_prog
        if($test$plusargs("verbose"))
            $display("[TESTBENCH] @ t=%0t: loading firmware %0s",
                     $time, "core/firmware/firmware.hex");
        $readmemh("core/firmware/firmware.hex", cv32e40x_soc.dp_ram_i.mem);
    end*/

    initial begin: clock_gen
        forever begin
            #CLK_PHASE_HI core_clk = 1'b0;
            #CLK_PHASE_LO core_clk = 1'b1;
        end
    end: clock_gen


    // timing format, reset generation and parameter check
    initial begin
        $timeformat(-9, 0, "ns", 9);
        core_rst_n = 1'b0;

        // wait a few cycles
        repeat (RESET_WAIT_CYCLES) begin
            @(posedge core_clk); //TODO: was posedge, see below
        end

        // start running
        #RESET_DEL core_rst_n = 1'b1;

        repeat (3) @(negedge core_clk);
        core_rst_n = 1'b1;

        if($test$plusargs("verbose")) begin
            $display("reset deasserted", $time);
        end
        
        send_byte_ser("h");
        #(SER_BIT_PERIOD_NS * 10 * 8 * 10);
        $finish;
        
    end

    // abort after n cycles, if we want to
    always_ff @(posedge core_clk, negedge core_rst_n) begin
        int maxcycles;
        if($value$plusargs("maxcycles=%d", maxcycles)) begin
            if (~core_rst_n) begin
                cycle_cnt_q <= 0;
            end else begin
                cycle_cnt_q     <= cycle_cnt_q + 1;
                if (cycle_cnt_q >= maxcycles) begin
                    $fatal(2, "Simulation aborted due to maximum cycle limit");
                end
            end
        end
    end

    logic led;
    logic ser_tx;
    logic ser_rx = 1'b1;
    logic sck, sdi, cs;
    wire  sdo;

    // wrapper for CV32E40X, the memory system and stdout peripheral
    cv32e40x_soc
    #(
    )
    cv32e40x_soc
    (
        .clk_i          ( core_clk     ),
        .rst_ni         ( core_rst_n   ),
        .led,
        .ser_tx,
        .ser_rx,
        
        .sck,
        .sdo,
        .sdi,
        .cs
    );
    
    spiflash #(
        .INIT_F("core/firmware/firmware.hex"), // TODO
        .OFFSET(24'h200000)
    ) spiflash_inst (
        .csb    (cs),
        .clk    (sck),
        .io0    (sdo), // MOSI
        .io1    (sdi), // MISO
        .io2    (),
        .io3    ()
    );
    
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

endmodule // tb_top
