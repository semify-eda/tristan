
`timescale 1ns/1ps
module obi_wb_bridge_tb;

    localparam BAUDRATE          = 115200;
    localparam SOC_ADDR_WIDTH    = 32;
    localparam DRAM_ADDR_WIDTH   = 12;  // 4K words (16 KB) data memory
    localparam IRAM_ADDR_WIDTH   = 13;  // 8K words (32 KB) — 4 × 2K firmware slots
    localparam INSTR_RDATA_WIDTH = 32;
    // IRAM base (block_sel = addr[19:17] == 1), matches wfg_top.sv
    localparam BOOT_ADDR         = 32'h00020000;
    parameter int CLK_FREQ       = 25_000_000;
    parameter int  SER_BIT_PERIOD_NS = 1_000_000_000 / BAUDRATE;

    logic core_clk;
    logic core_rst_n;
    logic wfg_clk;

    // allow fst dump
    initial begin
        $dumpfile("wb_obi_test.vcd");
        $dumpvars();
    end


    localparam DATAW = 32;
    localparam ADDRW = 20;


    wire [ADDRW-1:0]   wbm0_adr_i;
    wire [DATAW-1:0]   wbm0_dat_i;
    wire [DATAW-1:0]   wbm0_dat_o;
    wire               wbm0_we_i;
    wire               wbm0_stb_i;
    wire               wbm0_ack_o;
    wire               wbm0_cyc_i;

    wire [ADDRW-1:0]   wbm1_adr_i;
    wire [DATAW-1:0]   wbm1_dat_i;
    wire [DATAW-1:0]   wbm1_dat_o;
    wire               wbm1_we_i;
    wire               wbm1_stb_i;
    wire               wbm1_ack_o;
    wire               wbm1_cyc_i;


    wb_arbiter_2 #
    (
        .DATAW(DATAW),
        .ADDRW(ADDRW)
    ) i_wb_arbiter
    (
        .clk(wfg_clk),
        .rst_n(core_rst_n),

        .wbm0_adr_i(wbm0_adr_i),
        .wbm0_dat_i(wbm0_dat_i),
        .wbm0_dat_o(wbm0_dat_o),
        .wbm0_we_i (wbm0_we_i),
        .wbm0_stb_i(wbm0_stb_i),
        .wbm0_ack_o(wbm0_ack_o),
        .wbm0_cyc_i(wbm0_cyc_i),

        .wbm1_adr_i(wbm1_adr_i),
        .wbm1_dat_i(wbm1_dat_i),
        .wbm1_dat_o(wbm1_dat_o),
        .wbm1_we_i (wbm1_we_i),
        .wbm1_stb_i(wbm1_stb_i),
        .wbm1_ack_o(wbm1_ack_o),
        .wbm1_cyc_i(wbm1_cyc_i),

        .wbs_adr_o(addr_wb),
        .wbs_dat_i(data_i_wb),
        .wbs_dat_o(data_o_wb),
        .wbs_we_o (wr_en_wb),
        .wbs_stb_o(stb_wb),
        .wbs_ack_i(ack_wb),
        .wbs_cyc_o(cyc_wb)
    );


    
    // ----------------------------------
    //         Wishbone Signals
    // ----------------------------------
    logic [19 : 0]           addr_wb;
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
    tristan_soc
    #(
        .SOC_ADDR_WIDTH    (SOC_ADDR_WIDTH  ),
        .DRAM_ADDR_WIDTH   (DRAM_ADDR_WIDTH ),
        .IRAM_ADDR_WIDTH   (IRAM_ADDR_WIDTH ),
        .BOOT_ADDR         (BOOT_ADDR       ),
        // $readmemh resolves this at runtime relative to sim/ — 4 levels up is the
        // tristan root in both the standalone and the wfg-fpga (design/tristan) layout
        .FIRMWARE_INITFILE ("../../../../firmware/build/base/firmware.mem")
    )
    cv32e40x_soc
    (
        .clk_i          ( core_clk     ),
        .wfg_clk_i      ( wfg_clk      ),
        .rst_ni         ( core_rst_n   ),
        .gbl_rst_ni     ( core_rst_n   ),
        .soc_fetch_enable_i ('1),
        .boot_offset_i  ('0),           // slot 0
        // .ser_tx,
        // .ser_rx,

        // WB output interface
        .wb_addr_o      (wbm1_adr_i),
        .wb_rdata_i     (wbm1_dat_o),
        .wb_wdata_o     (wbm1_dat_i),
        .wb_wr_en_o     (wbm1_we_i),
        .wb_byte_en_o   (byte_en_wb),
        .wb_stb_o       (wbm1_stb_i),
        .wb_ack_i       (wbm1_ack_o),
        .wb_cyc_o       (wbm1_cyc_i),

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

    logic default_slave_stb;
    assign default_slave_stb = stb_wb & ~timer_sel;

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
