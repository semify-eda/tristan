`timescale 1ns/1ps
module top_tb;

    localparam SOC_ADDR_WIDTH    = 32;
    localparam RAM_ADDR_WIDTH    = 14;
    localparam INSTR_RDATA_WIDTH = 32;
    localparam BOOT_ADDR         = 32'h02000000;
    parameter int CLK_FREQ       = 25_000_000;

    logic core_clk;
    logic core_rst_n;
    logic wfg_clk;

    // allow fst dump
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars();
    end

    // ----------------------------------
    //         Wishbone Signals
    // ----------------------------------
    logic [31 : 0]           addr_wb;
    logic [31 : 0]           data_i_wb;
    logic [31 : 0]           data_o_wb;
    logic                    wr_en_wb;
    logic [3 : 0]            byte_en_wb;
    logic                    stb_wb;
    logic                    ack_wb;
    logic                    cyc_wb;

    // ----------------------------------
    //           CV32E40X Core
    // ----------------------------------
    cv32e40x_soc
    #(
        .SOC_ADDR_WIDTH    (SOC_ADDR_WIDTH),
        .RAM_ADDR_WIDTH    (RAM_ADDR_WIDTH),
        .BOOT_ADDR         (BOOT_ADDR),
        .FIRMWARE_INITFILE ("firmware.mem")
    )
    cv32e40x_soc
    (
        .clk_i          ( core_clk     ),
        .wfg_clk_i      ( wfg_clk      ),
        .rst_ni         ( core_rst_n   ),
        .gbl_rst_ni     ( core_rst_n   ),
        .soc_fetch_enable_i ('1        ),

        // WB output interface
        .wb_addr_o      (addr_wb),
        .wb_rdata_i     (data_i_wb),
        .wb_wdata_o     (data_o_wb),
        .wb_wr_en_o     (wr_en_wb),
        .wb_byte_en_o   (byte_en_wb),
        .wb_stb_o       (stb_wb),
        .wb_ack_i       (ack_wb),
        .wb_cyc_o       (cyc_wb),

        // WB input interface to access RAM
        .wb_addr_i      ('0),
        .wb_wdata_i     ('0),
        .wb_wr_en_i     ('0),
        .wb_byte_en_i   ('0),
        .wb_stb_i       ('0),
        .wb_cyc_i       ('0)
    );

    logic timer_sel;
    assign timer_sel = addr_wb[19:8] == 12'b111000000000;


    logic default_ack;
    logic [31:0] default_dat;
    logic timer_ack;
    logic [31:0] timer_dat;

    wfg_timer_top timer
    (
        .clk         (wfg_clk),
        .rst_n       (core_rst_n),

        .wbs_stb_i   (stb_wb & timer_sel),
        .wbs_cyc_i   (cyc_wb & timer_sel),
        .wbs_we_i    (wr_en_wb),
        .wbs_dat_i   (data_o_wb),
        .wbs_adr_i   (addr_wb),
        .wbs_ack_o   (timer_ack),
        .wbs_dat_o   (timer_dat),

        .interrupt_o ()
    );

    assign ack_wb = timer_sel ? timer_ack : default_ack;
    assign data_i_wb = timer_sel ? timer_dat : default_dat;

endmodule
