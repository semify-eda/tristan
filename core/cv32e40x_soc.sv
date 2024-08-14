`default_nettype none
`timescale 1ns/1ps
import soc_pkg::*;

module cv32e40x_soc import cv32e40x_pkg::*;
#(
  parameter SOC_ADDR_WIDTH    = 32,
  parameter SOC_DATA_WIDTH    = 32,
  parameter RAM_ADDR_WIDTH    = 12,
  parameter RAM_DATA_WIDTH    = 32,
  parameter BOOT_ADDR         = 32'h00020000,
  parameter DATA_START_ADDR   = 32'h00000000,
  parameter FIRMWARE_INITFILE = "firmware.mem",
  parameter DM_HALTADDRESS    = 32'h1A11_0800,
  parameter NUM_MHPMCOUNTERS  = 1,
  parameter HART_ID           = 32'h0000_0000
)
(
  // Clock and reset
  input  wire                         clk_i,
  input  wire                         wfg_clk_i,
  input  wire                         rst_ni,
  input  wire                         gbl_rst_ni,

  //core control signals
  input  wire                         soc_fetch_enable_i,
  output logic                        soc_core_sleep_o,

  // WB output interface for external modules
  output logic [SOC_ADDR_WIDTH-1:0]   wb_addr_o,
  input  wire  [31: 0]                wb_rdata_i,
  output logic [31: 0]                wb_wdata_o,
  output logic                        wb_wr_en_o,
  output logic [ 3: 0]                wb_byte_en_o,
  output logic                        wb_stb_o,
  input  wire                         wb_ack_i,
  output logic                        wb_cyc_o,

  // WB input interface to access SoC RAM
  input  wire  [SOC_ADDR_WIDTH-1:0]   wb_addr_i,
  output logic [31: 0]                wb_rdata_o,
  input  wire  [31: 0]                wb_wdata_i,
  input  wire                         wb_wr_en_i,
  input  wire  [ 3: 0]                wb_byte_en_i,
  input  wire                         wb_stb_i,
  output logic                        wb_ack_o,
  input  wire                         wb_cyc_i
);

  /* =====================================================================
  *                 cv32e40x instruction and data signals
  * ====================================================================== */
  logic                       cpu_instr_req;
  logic                       cpu_instr_gnt;
  logic                       cpu_instr_rvalid;
  logic [SOC_ADDR_WIDTH-1:0]  cpu_instr_addr;
  logic [31: 0]               cpu_instr_rdata;

  logic                       cpu_data_req;
  logic                       cpu_data_gnt;
  logic                       cpu_data_rvalid;
  logic [SOC_ADDR_WIDTH-1:0]  cpu_data_addr;
  logic [ 3: 0]               cpu_data_be;
  logic                       cpu_data_we;
  logic [31: 0]               cpu_data_wdata;
  logic [31: 0]               cpu_data_rdata;


  /* =====================================================================
  *                     cv32e40x unified signals
  * ====================================================================== */
  logic [SOC_ADDR_WIDTH-1:0]  addr;
  logic                       req;
  logic                       gnt;
  logic                       rvalid;
  logic [ 3: 0]               be;
  logic                       we;
  logic [31: 0]               wdata;
  logic [31: 0]               rdata;

  logic [31: 0]               instr_rdata;
  logic [31: 0]               ram_rdata;


  /* =====================================================================
  *                     cv32e40x peripheral signals
  * ====================================================================== */
  logic select_dram;
  logic select_iram;
  logic select_wb;

  e_chip_sel  chip_sel;
  e_block_sel block_sel;

  assign chip_sel  = e_chip_sel'(addr[20]);
  assign block_sel = e_block_sel'(addr[19:17]);

  // The alignment offset ensures that the RAM is addressed correctly regardless of its width.
  // This offset can change based on the width and depth of the RAM, and is calculated as:
  //          alignment offset = log2 (RAM Width / 8)
  // It is added to the beginning and end of the addr_width when addressing into the addr, in order to use
  // the correct bits of addr to index into the RAM, since larger width RAM means more bytes are packed together in a single row.
  localparam ALIGNMENT_OFFSET = $clog2( RAM_DATA_WIDTH / 8 );

  /* =====================================================================
  *                             OBI Signals
  * ====================================================================== */
  logic                       obi_req_o;
  logic                       obi_gnt_i;
  logic [SOC_ADDR_WIDTH-1:0]  obi_addr_o;
  logic                       obi_we_o;
  logic [3 : 0]               obi_be_o;
  logic [31 : 0]              obi_wdata_o;
  logic                       obi_rvalid_i;
  logic [31 : 0]              obi_rdata_i;

  assign obi_req_o    = req;
  assign obi_addr_o   = addr;
  assign obi_we_o     = we;
  assign obi_be_o     = be;
  assign obi_wdata_o  = wdata;


  /* =====================================================================
  *                cv32e40x - coprocessor eXtension interface
  * ====================================================================== */

  localparam int unsigned X_NUM_RS        =  2;  // Number of register file read ports that can be used by the eXtension interface
  localparam int unsigned X_ID_WIDTH      =  4;  // Width of ID field.
  localparam int unsigned X_MEM_WIDTH     =  32; // Memory access width for loads/stores via the eXtension interface
  localparam int unsigned X_RFR_WIDTH     =  32; // Register file read access width for the eXtension interface
  localparam int unsigned X_RFW_WIDTH     =  32; // Register file write access width for the eXtension interface
  localparam logic [31:0] X_MISA          =  '0; // MISA extensions implemented on the eXtension interface
  localparam logic [ 1:0] X_ECS_XS        =  '0; // Default value for mstatus.XS
  localparam int          XLEN            =  32;
  localparam int          FLEN            =  32;

  cv32e40x_if_xif #(
    .X_NUM_RS    (X_NUM_RS    ),
    .X_MEM_WIDTH (X_MEM_WIDTH ),
    .X_RFR_WIDTH (X_RFR_WIDTH ),
    .X_RFW_WIDTH (X_RFW_WIDTH ),
    .X_MISA      (X_MISA      )
  ) ext_if();

  /* =====================================================================
  *                           Bus Grant Logic
  * ====================================================================== */
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      gnt <= 1'b0;
    end else begin
      // If communicating with an external module, wait for the module to respond
      if(select_wb) begin
        gnt <= obi_gnt_i;
      end else begin
        // Grant if we have not already granted
        gnt <= req && !gnt && !rvalid;
      end
    end
  end


  /* ================================================================
  *                         Arbiter
  * ================================================================= */
  ram_arbiter i_ram_arbiter
  (
    .clk_i                  (clk_i              ),
    .rst_ni                 (rst_ni             ),

    // I RAM Signals
    .cpu_instr_addr_i       (cpu_instr_addr     ),
    .cpu_instr_req_i        (cpu_instr_req      ),
    .cpu_instr_gnt_o        (cpu_instr_gnt      ),
    .cpu_instr_rvalid_o     (cpu_instr_rvalid   ),
    .cpu_instr_rdata_o      (cpu_instr_rdata    ),

    // D RAM Signals
    .cpu_data_addr_i        (cpu_data_addr      ),
    .cpu_data_req_i         (cpu_data_req       ),
    .cpu_data_gnt_o         (cpu_data_gnt       ),
    .cpu_data_rvalid_o      (cpu_data_rvalid    ),
    .cpu_data_rdata_o       (cpu_data_rdata     ),
    .cpu_data_be_i          (cpu_data_be        ),
    .cpu_data_we_i          (cpu_data_we        ),
    .cpu_data_wdata_i       (cpu_data_wdata     ),

    // Unified Signals
    .soc_rvalid_i           (rvalid             ),
    .soc_gnt_i              (gnt                ),
    .soc_req_o              (req                ),
    .soc_addr_o             (addr               ),
    .soc_be_o               (be                 ),
    .soc_we_o               (we                 ),
    .soc_wdata_o            (wdata              ),
    .soc_rdata_i            (rdata              )
  );

  /* ===============================================================
  *                         CPU
  * ================================================================= */
  cv32e40x_core
  #(
    .NUM_MHPMCOUNTERS       (NUM_MHPMCOUNTERS       ), 
    .A_EXT                  (A                      ),
    .B_EXT                  (B_NONE                 ), //ZBA_ZBB_ZBC_ZBS
    .M_EXT                  (M_NONE                 ),
    .X_EXT                  (1'b1                   ), // enable xtension interface
    .X_NUM_RS               (X_NUM_RS               ),
    .DEBUG                  (1'b0                   )
  )
  cv32e40x_core_inst
  (
    .clk_i                  (clk_i                  ),
    .rst_ni                 (rst_ni                 ),
    .scan_cg_en_i           ('0                     ),

    // Static configuration
    .boot_addr_i            (BOOT_ADDR              ),
    .dm_exception_addr_i    ('0                     ),
    .dm_halt_addr_i         (DM_HALTADDRESS         ),
    .mhartid_i              (HART_ID                ),
    .mimpid_patch_i         ('0                     ),
    .mtvec_addr_i           ('0                     ),

    // Instruction memory interface
    .instr_req_o            (cpu_instr_req          ),

    .instr_gnt_i            (cpu_instr_gnt          ),
    .instr_rvalid_i         (cpu_instr_rvalid       ),
    .instr_addr_o           (cpu_instr_addr         ),

    .instr_memtype_o        (                       ),
    .instr_prot_o           (                       ),
    .instr_dbg_o            (                       ),
    .instr_rdata_i          (cpu_instr_rdata        ),
    .instr_err_i            ('0                     ),

    // Data memory interface
    .data_req_o             (cpu_data_req           ),
    .data_gnt_i             (cpu_data_gnt           ),
    .data_rvalid_i          (cpu_data_rvalid        ),
    .data_addr_o            (cpu_data_addr          ),
    .data_be_o              (cpu_data_be            ),
    .data_we_o              (cpu_data_we            ),
    .data_wdata_o           (cpu_data_wdata         ),
    .data_memtype_o         (                       ),
    .data_prot_o            (                       ),
    .data_dbg_o             (                       ),
    .data_atop_o            (                       ),
    .data_rdata_i           (cpu_data_rdata         ),
    .data_err_i             ('0                     ),
    .data_exokay_i          ('1                     ),

    // Cycle count
    .mcycle_o               (                       ),
    .time_i                 ('0                     ),

    // eXtension interface
    .xif_compressed_if      (ext_if.cpu_compressed  ),
    .xif_issue_if           (ext_if.cpu_issue       ),
    .xif_commit_if          (ext_if.cpu_commit      ),
    .xif_mem_if             (ext_if.cpu_mem         ),
    .xif_mem_result_if      (ext_if.cpu_mem_result  ),
    .xif_result_if          (ext_if.cpu_result      ),

    // Basic interrupt architecture
    .irq_i                  ( {32{1'b0}}            ),

    // Event wakeup signal
    .wu_wfe_i               ('0                     ),

    // Smclic interrupt architecture
    .clic_irq_i             ('0                     ),
    .clic_irq_id_i          ('0                     ),
    .clic_irq_level_i       ('0                     ),
    .clic_irq_priv_i        ('0                     ),
    .clic_irq_shv_i         ('0                     ),

    // Fencei flush handshake
    .fencei_flush_req_o     (                       ),
    .fencei_flush_ack_i     ('0                     ),

    .debug_req_i            ('0                     ),
    .debug_havereset_o      (                       ),
    .debug_running_o        (                       ),
    .debug_halted_o         (                       ),

    // CPU Control Signals
    .fetch_enable_i         (soc_fetch_enable_i     ),
    .core_sleep_o           (soc_core_sleep_o       )
  );

  /* ================================================================
  *                         Co-Processor
  * ================================================================= */
  coproc coproc_inst
  (
    .clk_i                  (clk_i                    ),
    .rst_ni                 (rst_ni                   ),

    // eXtension interface
    .xif_compressed_if      (ext_if.coproc_compressed ),
    .xif_issue_if           (ext_if.coproc_issue      ),
    .xif_commit_if          (ext_if.coproc_commit     ),
    .xif_mem_if             (ext_if.coproc_mem        ),
    .xif_mem_result_if      (ext_if.coproc_mem_result ),
    .xif_result_if          (ext_if.coproc_result     )
  );


  /* ================================================================
  *                     Peripheral Multiplexer
  * ================================================================= */
  // Data select signals
  assign select_wb           = chip_sel == EXTERNAL;
  assign select_dram         = chip_sel == INTERNAL & block_sel == DRAM;
  assign select_iram         = chip_sel == INTERNAL & block_sel == IRAM;

  always_comb begin
    rdata = '0;
    case(1'b1)
      select_dram:
        rdata = ram_rdata;
      select_iram:
        rdata = instr_rdata;
      select_wb:
        rdata = obi_rdata_i;
    endcase
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      rvalid <= 1'b0;
    end else begin
      if(select_wb) begin
        rvalid <= obi_rvalid_i;
      end else begin
        // Generally data is available one cycle after req
        rvalid <= gnt;
      end
    end
  end


  /* ================================================================
  *                     OBI - Wishbone bridge
  * ================================================================= */
  obi_wb_bridge i_obi_wb_bridge
  (
    .obi_clk_i      (clk_i                ),
    .wb_clk_i       (wfg_clk_i            ),
    .soc_rst_ni     (rst_ni               ),
    .gbl_rst_ni     (gbl_rst_ni           ),

    /* OBI Signals */
    .obi_req_i      (obi_req_o & select_wb),
    .obi_gnt_o      (obi_gnt_i            ),
    .obi_addr_i     (obi_addr_o           ),
    .obi_wr_en_i    (obi_we_o             ),
    .obi_byte_en_i  (obi_be_o             ),
    .obi_wdata_i    (obi_wdata_o          ),
    .obi_rvalid_o   (obi_rvalid_i         ),
    .obi_rdata_o    (obi_rdata_i          ),

    /* Wishbone Signals */
    .wb_addr_o      (wb_addr_o            ),
    .wb_rdata_i     (wb_rdata_i           ),
    .wb_wdata_o     (wb_wdata_o           ),
    .wb_wr_en_o     (wb_wr_en_o           ),
    .wb_byte_en_o   (wb_byte_en_o         ),
    .wb_stb_o       (wb_stb_o             ),
    .wb_ack_i       (wb_ack_i             ),
    .wb_cyc_o       (wb_cyc_o             )
  );

  logic [RAM_ADDR_WIDTH-1 : 0] wb2ram_addr;
  logic [RAM_DATA_WIDTH-1 : 0] wb2ram_data;
  logic [RAM_DATA_WIDTH-1 : 0] iram2wb_data;
  logic [RAM_DATA_WIDTH-1 : 0] dram2wb_data;
  logic                        wb2iram_we;
  logic                        wb2dram_we;


  /* ================================================================
  *                     Wishbone - RAM interface
  * ================================================================= */
  wb_ram_interface #(
    .RAM_ADDR_WIDTH (RAM_ADDR_WIDTH ),
    .RAM_DATA_WIDTH (RAM_DATA_WIDTH )
  ) i_wb_ram_interface (
    .ram_clk_i      (clk_i          ),
    .wb_clk_i       (wfg_clk_i      ),
    .rst_ni         (gbl_rst_ni     ),

    // Wishbone input signals
    .wb_addr_i      (wb_addr_i      ),
    .wb_rdata_o     (wb_rdata_o     ),
    .wb_wdata_i     (wb_wdata_i     ),
    .wb_wr_en_i     (wb_wr_en_i     ),
    .wb_stb_i       (wb_stb_i       ),
    .wb_ack_o       (wb_ack_o       ),
    .wb_cyc_i       (wb_cyc_i       ),

    // RAM output signals
    .ram_addr_o     (wb2ram_addr    ),
    .ram_data_o     (wb2ram_data    ),
    .iram_data_i    (iram2wb_data   ),
    .dram_data_i    (dram2wb_data   ),
    .iram_we_o      (wb2iram_we     ),
    .dram_we_o      (wb2dram_we     )
  );


  /* ================================================================
  *                     Dualport BRAM - Instr
  * ================================================================= */
  soc_sram_dualport #(
    .INITFILEEN     (1                  ),
    .INITFILE       (FIRMWARE_INITFILE  ),
    .DATAWIDTH      (RAM_DATA_WIDTH     ),
    .ADDRWIDTH      (RAM_ADDR_WIDTH     ),
    .BYTE_ENABLE    (1                  )
  ) instr_dualport_i (
    .clk      (clk_i                            ),

    // 16kb
    // RAM_ADDR_WIDTH is directly tied to the DATAWIDTH. Having an addr width of 12 does not mean that you address the
    // 12 LSB of the address, since if the data width is 32, then the 2 LSB are omitted, and you therefore must address
    // bits 13 to 2, due to alignment since the 2 LSB correspond to (32/8) = 4 bytes.
    .addr_a   (addr[RAM_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET]),
    .we_a     (gnt && select_iram && we         ),
    .be_a     (be                               ),
    .d_a      (wdata                            ),
    .q_a      (instr_rdata                      ),

    .addr_b   (wb2ram_addr                      ),
    .we_b     (wb2iram_we                       ),
    .d_b      (wb2ram_data                      ),
    .q_b      (iram2wb_data                     )
  );


  /* ================================================================
  *                     Dualport BRAM - Data
  * ================================================================= */
  soc_sram_dualport #(
    .DATAWIDTH      (RAM_DATA_WIDTH     ),
    .ADDRWIDTH      (RAM_ADDR_WIDTH     ),
    .BYTE_ENABLE    (1                  )
  ) data_dualport_i (
    .clk      (clk_i                      ),

    .addr_a   (addr[RAM_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET]),
    .we_a     (gnt && select_dram && we   ),
    .be_a     (be                         ),
    .d_a      (wdata                      ),
    .q_a      (ram_rdata                  ),

    .addr_b   (wb2ram_addr                ),
    .we_b     (wb2dram_we                 ),
    .d_b      (wb2ram_data                ),
    .q_b      (dram2wb_data               )
  );

endmodule
