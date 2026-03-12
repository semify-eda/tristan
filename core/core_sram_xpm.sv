// soc_sram_dualport — XPM (Xilinx Parameterized Macro) implementation
//
// PURPOSE
//   Drop-in replacement for core_sram.sv / core_sram_patched.sv, for use
//   in Vivado synthesis only.  XPM completely bypasses the RTL template
//   matcher.  Vivado resolves xpm_memory_tdpram internally to the correct
//   combination of RAMB36E1 (7-series) or RAMB36E2 (UltraScale+) primitives,
//   handling width and depth cascading automatically.
//
// SIMULATION
//   XPM simulation models require Xilinx libraries — not available to
//   Verilator.  Keep using core_sram.sv for Verilator/cocotb simulation.
//   In Vivado xsim, XPM is compiled automatically; no extra steps needed.
//
// FIRMWARE INITIALIZATION
//   In hardware, firmware is always loaded at runtime via port B (the
//   Wishbone interface).  The BRAM starts uninitialized; the
//   INITFILE / INITFILEEN parameters are accepted for interface
//   compatibility but are NOT used in this synthesis file.
//
// TARGET
//   Xilinx 7-series (Artix-7 xc7a100tftg256-3).
//   Also portable to UltraScale / UltraScale+ without modification.
//
// RESOURCE ESTIMATE (ADDRWIDTH=12, DATAWIDTH=32 → 4K × 32-bit = 16 KB)
//   Vivado maps this to 4 × RAMB36E1 per instance (port A: 18-bit TDP ×2
//   wide, ×2 deep).  Two instances (IRAM + DRAM) = 8 RAMB36E1 total.
//   Artix-7 100T has 135 RAMB36E1 available → fits very comfortably.

`default_nettype none

module soc_sram_dualport #(
  parameter                   INITFILEEN   = 0,      // accepted but unused in synthesis
  parameter                   INITFILE     = "init.mem", // accepted but unused in synthesis
  parameter                   DATAWIDTH    = 32,
  parameter                   ADDRWIDTH    = 12,
  parameter                   BYTE_ENABLE  = 0,      // accepted but unused (always byte-enabled)
  parameter                   BYTE_ENABLES = DATAWIDTH / 8
) (
  input  wire clk,

  // Port A: CPU access — byte-granularity read/write
  input  wire [ADDRWIDTH-1:0]    addr_a,
  input  wire                    we_a,
  input  wire [BYTE_ENABLES-1:0] be_a,
  input  wire [DATAWIDTH-1:0]    d_a,
  output wire [DATAWIDTH-1:0]    q_a,

  // Port B: Wishbone access — full-word read/write, no byte enables
  input  wire [ADDRWIDTH-1:0]    addr_b,
  input  wire                    we_b,
  input  wire [DATAWIDTH-1:0]    d_b,
  output wire [DATAWIDTH-1:0]    q_b
);

  localparam MEMORY_SIZE = DATAWIDTH * (1 << ADDRWIDTH); // total bits

  // Port A write enable: WEA[i]=1 enables byte lane i.
  // Deassert all bytes on reads (we_a=0).
  wire [BYTE_ENABLES-1:0] wea_int = we_a ? be_a : {BYTE_ENABLES{1'b0}};

  // Port B write enable: 1-bit because BYTE_WRITE_WIDTH_B = DATAWIDTH
  // (full word only, no sub-word byte enables).
  wire we_b_int = we_b;

  xpm_memory_tdpram #(
    // ---------------------------------------------------------------
    // Memory geometry
    // ---------------------------------------------------------------
    .MEMORY_SIZE             (MEMORY_SIZE),   // total bits: DATAWIDTH × 2^ADDRWIDTH
    .MEMORY_PRIMITIVE        ("block"),        // always map to BRAM, never LUT RAM

    // ---------------------------------------------------------------
    // Clocking
    // ---------------------------------------------------------------
    // Both ports share one clock → "common_clock" mode.
    // Allows READ_LATENCY = 1 (single registered output stage).
    .CLOCKING_MODE           ("common_clock"),

    // ---------------------------------------------------------------
    // Port A — CPU (byte-granularity write enable)
    // ---------------------------------------------------------------
    .ADDR_WIDTH_A            (ADDRWIDTH),
    .WRITE_DATA_WIDTH_A      (DATAWIDTH),
    .READ_DATA_WIDTH_A       (DATAWIDTH),
    // BYTE_WRITE_WIDTH_A = 8 → WEA width = DATAWIDTH/8 bits (one per byte)
    .BYTE_WRITE_WIDTH_A      (8),
    // 1-cycle latency: address/data registered on posedge clk, output valid next cycle.
    // Matches the behavior cva6_soc.sv already accounts for (iram_rvalid delayed 1 cycle).
    .READ_LATENCY_A          (1),

    // ---------------------------------------------------------------
    // Port B — Wishbone (full-word only, no byte enables)
    // ---------------------------------------------------------------
    .ADDR_WIDTH_B            (ADDRWIDTH),
    .WRITE_DATA_WIDTH_B      (DATAWIDTH),
    .READ_DATA_WIDTH_B       (DATAWIDTH),
    // BYTE_WRITE_WIDTH_B = DATAWIDTH → WEB is 1 bit (full word at once)
    .BYTE_WRITE_WIDTH_B      (DATAWIDTH),
    .READ_LATENCY_B          (1),

    // ---------------------------------------------------------------
    // Read-during-write collision behavior
    // ---------------------------------------------------------------
    // "read_first": when the same address is written and read in the
    // same cycle, the OLD (pre-write) value appears on the output.
    // Equivalent to "read-before-write" in ASIC SRAM terminology.
    // Matches the behavior of the original core_sram.sv always_ff blocks.
    .WRITE_MODE_A            ("read_first"),
    .WRITE_MODE_B            ("read_first"),

    // ---------------------------------------------------------------
    // Initialization
    // ---------------------------------------------------------------
    // Firmware is loaded at runtime via Port B (Wishbone/UART).
    // No BRAM init needed for synthesis.
    .USE_MEM_INIT            (0),
    .MEMORY_INIT_FILE        ("none"),
    .MEMORY_INIT_PARAM       (""),
    .USE_MEM_INIT_MMI        (0),

    // ---------------------------------------------------------------
    // Unused features
    // ---------------------------------------------------------------
    .ECC_MODE                ("no_ecc"),
    .AUTO_SLEEP_TIME         (0),
    .CASCADE_HEIGHT          (0),        // 0 = Vivado auto-selects cascade depth
    .RST_MODE_A              ("SYNC"),
    .RST_MODE_B              ("SYNC"),
    .SIM_ASSERT_CHK          (0),
    .MESSAGE_CONTROL         (0),
    .MEMORY_OPTIMIZATION     ("true"),
    .USE_EMBEDDED_CONSTRAINT (0)

  ) i_xpm_tdpram (

    // ------ Port A: CPU ------
    .clka    (clk),
    .addra   (addr_a),
    .dina    (d_a),
    .wea     (wea_int),     // BYTE_ENABLES bits wide
    .douta   (q_a),
    .ena     (1'b1),        // always enabled
    .rsta    (1'b0),        // no output reset
    .regcea  (1'b1),        // output register always active

    // ------ Port B: Wishbone ------
    .clkb    (clk),
    .addrb   (addr_b),
    .dinb    (d_b),
    .web     (we_b_int),    // 1 bit (BYTE_WRITE_WIDTH_B = DATAWIDTH)
    .doutb   (q_b),
    .enb     (1'b1),
    .rstb    (1'b0),
    .regceb  (1'b1),

    // ------ ECC injection / status (unused) ------
    .injectdbiterra (1'b0),
    .injectsbiterra (1'b0),
    .injectdbiterrb (1'b0),
    .injectsbiterrb (1'b0),
    .dbiterra (),
    .sbiterra (),
    .dbiterrb (),
    .sbiterrb ()
  );

endmodule

`default_nettype wire
