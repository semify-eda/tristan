`timescale 1ns/1ps
module top_tb;

    localparam SOC_ADDR_WIDTH    = 32;
    localparam DRAM_ADDR_WIDTH   = 12;  // 4K words (16 KB) data memory
    localparam IRAM_ADDR_WIDTH   = 13;  // 8K words (32 KB) — 4 × 2K firmware slots
    localparam INSTR_RDATA_WIDTH = 32;
    localparam BOOT_ADDR         = 32'h00020000;
    parameter int CLK_FREQ       = 25_000_000;

    logic core_clk;
    logic core_rst_n;
    logic wfg_clk;

    // VCD waveform dump (open with gtkwave top_tb.vcd)
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
    //  IRAM firmware loading
    // ----------------------------------
    // Firmware is loaded here at simulation time, not inside the SRAM module.
    // For multi-slot loading (FW0–FW3) see software/simulation/sim_basic_showcase.sv.
    //
    // CV32A60X: core_sram_patched.sv stores memory as per-byte-lane 8-bit arrays;
    //   $readmemh of a 32-bit hex file into an 8-bit array truncates each word to the
    //   lowest byte. Load via a 32-bit temp array, then distribute into byte lanes.
    // CV32E40X: core_sram.sv has a flat 32-bit ram[] array; direct $readmemh works.
`ifdef CV32A60X
    initial begin
        logic [31:0] _iram_tmp [0:(1<<IRAM_ADDR_WIDTH)-1];
        $readmemh("firmware.mem", _iram_tmp);
        for (int _k = 0; _k < (1<<IRAM_ADDR_WIDTH); _k++) begin
            i_tristan_soc.i_instr_sram.byte_lane[0].ram[_k] = _iram_tmp[_k][ 7: 0];
            i_tristan_soc.i_instr_sram.byte_lane[1].ram[_k] = _iram_tmp[_k][15: 8];
            i_tristan_soc.i_instr_sram.byte_lane[2].ram[_k] = _iram_tmp[_k][23:16];
            i_tristan_soc.i_instr_sram.byte_lane[3].ram[_k] = _iram_tmp[_k][31:24];
        end
    end
`else
    initial begin
        $readmemh("firmware.mem", i_tristan_soc.instr_dualport_i.ram);
    end
`endif

    // ----------------------------------
    //           Tristan Core
    // ----------------------------------
    tristan_soc
    #(
        .SOC_ADDR_WIDTH    (SOC_ADDR_WIDTH  ),
        .DRAM_ADDR_WIDTH   (DRAM_ADDR_WIDTH ),
        .IRAM_ADDR_WIDTH   (IRAM_ADDR_WIDTH ),
        .BOOT_ADDR         (BOOT_ADDR       )
    )
    i_tristan_soc
    (
        .clk_i          ( core_clk     ),
        .wfg_clk_i      ( wfg_clk      ),
        .rst_ni         ( core_rst_n   ),
        .gbl_rst_ni     ( core_rst_n   ),
        .soc_fetch_enable_i ('1        ),
        .soc_core_sleep_o (        ),

        // WB output interface
        .wb_addr_o      (addr_wb),
        .wb_rdata_i     (data_i_wb),
        .wb_wdata_o     (data_o_wb),
        .wb_wr_en_o     (wr_en_wb),
        .wb_byte_en_o   (byte_en_wb),
        .wb_stb_o       (stb_wb),
        .wb_ack_i       (ack_wb),
        .wb_cyc_o       (cyc_wb),

        // WB input interface: allows external Wishbone master to access SRAM directly.
        // Tied to '0 in this testbench — not exercised by the obi_wb_bridge_test.
        .wb_addr_i      ('0),
        .wb_wdata_i     ('0),
        .wb_wr_en_i     ('0),
        .wb_byte_en_i   ('0),
        .wb_stb_i       ('0),
        .wb_cyc_i       ('0),
        .wb_rdata_o     (   ),  // WB-to-RAM port unused in this testbench
        .wb_ack_o       (   )   // WB-to-RAM port unused in this testbench
    );

    // WFG timer wishbone base: bits [19:8] == 0xE00 (from wfg_pkg address map)
    localparam logic [11:0] WFG_TIMER_ADDR_MSB = 12'b111000000000;

    logic timer_sel;
    assign timer_sel = addr_wb[19:8] == WFG_TIMER_ADDR_MSB;

    // Default wishbone responder for non-timer addresses.
    // Driven by the cocotb WishboneSlave in top_tb.py (immediate ACK, zero read-data).
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
        .wbs_adr_i   (addr_wb[19:0]),
        .wbs_ack_o   (timer_ack),
        .wbs_dat_o   (timer_dat),

        .interrupt_o ()
    );

    assign ack_wb = timer_sel ? timer_ack : default_ack;
    assign data_i_wb = timer_sel ? timer_dat : default_dat;

endmodule
