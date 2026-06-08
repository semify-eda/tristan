// Dual-port RAM with byte enables, implemented as per-byte-lane TDP BRAMs.
//
// This splits the memory into NB_COL separate 8-bit
// wide TDP RAMs via a generate loop. Each lane uses the simplest possible
// TDP template which Vivado reliably infers as block RAM.
//
// Changes from core_sram.sv:
//   - Memory split into per-byte-lane sub-RAMs (generate for with genvar)
//   - Firmware is loaded from the testbench via the byte-lane arrays (not via $readmemh here)
//   - Both ports have a byte enable now, that cannot be turned off.
//     (the BYTE_ENABLE parameter is kept, for compatibility with core_sram.sv)

module soc_sram_dualport #(
  parameter                   DATAWIDTH    = 32,
  parameter                   ADDRWIDTH    = 14,
  parameter                   BYTE_ENABLE  = 0,
  parameter                   BYTE_ENABLES = DATAWIDTH / 8
) (
  input  wire clk,

  input  wire  [ADDRWIDTH-1:0]    addr_a,
  input  wire                     we_a,
  input  wire  [BYTE_ENABLES-1:0] be_a,
  input  wire  [DATAWIDTH-1:0]    d_a,
  output wire  [DATAWIDTH-1:0]    q_a,

  input  wire  [ADDRWIDTH-1:0]    addr_b,
  input  wire                     we_b,
  input  wire  [DATAWIDTH-1:0]    d_b,
  output wire  [DATAWIDTH-1:0]    q_b
);

  // initial begin $display("Read firmware file: %s", INITFILE); end

  localparam NB_COL    = DATAWIDTH / 8;
  localparam COL_WIDTH = 8;
  localparam MEMSIZE   = 1 << ADDRWIDTH;

  genvar gi;
  generate
    for (gi = 0; gi < NB_COL; gi = gi + 1) begin : byte_lane
      // RAM preloading (firmware/data) is done hierarchically from the testbench top
      // at time 0, e.g.: i_tristan_soc.i_instr_sram.byte_lane[N].ram[k] = ...
      // See the IRAM/DRAM loading initial blocks in ise_test_tb.sv or sim_basic_showcase.sv.
      (* ram_style = "block" *)
      reg [COL_WIDTH-1:0] ram [MEMSIZE-1:0];
      reg [COL_WIDTH-1:0] dout_a;
      reg [COL_WIDTH-1:0] dout_b;

      // Port A: CPU access — write enabled per byte lane
      always @(posedge clk) begin
        if (we_a & be_a[gi])
          ram[addr_a] <= d_a[gi*COL_WIDTH +: COL_WIDTH];
        dout_a <= ram[addr_a];
      end

      // Port B: WB access — all lanes written together
      always @(posedge clk) begin
        if (we_b)
          ram[addr_b] <= d_b[gi*COL_WIDTH +: COL_WIDTH];
        dout_b <= ram[addr_b];
      end

      assign q_a[gi*COL_WIDTH +: COL_WIDTH] = dout_a;
      assign q_b[gi*COL_WIDTH +: COL_WIDTH] = dout_b;
    end
  endgenerate

endmodule
