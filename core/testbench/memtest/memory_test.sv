`timescale 1ns/1ps

module memory_test;

// allow fst dump
initial begin
    $dumpfile("memory_test.vcd");
    $dumpvars();
end

logic clk;
logic [31:0] ram_addr, ram_data;


// The alignment offset ensures that the RAM is addressed correctly regardless of its width.
// This offset can change based on the width and depth of the RAM, and is calculated as:
//          alignment offset = log2 (RAM Width / 8)
// It is added to the beginning and end of the addr_width when addressing into the soc_addr, in order to use
// the correct bits of soc_addr to index into the RAM, since larger width RAM means more bytes are packed together in a single row.
localparam ALIGNMENT_OFFSET = $clog2( SOC_ADDR_WIDTH / 8 );


localparam SOC_ADDR_WIDTH    = 32;
localparam INSTR_ADDR_WIDTH  = 12;

sram_dualport #(
    .INITFILEEN     (1),
    .INITFILE       ("../../firmware/firmware.hex"),
    .DATAWIDTH      (SOC_ADDR_WIDTH),
    .ADDRWIDTH      (INSTR_ADDR_WIDTH),
    .BYTE_ENABLE    (1)
) instr_dualport_i (
  .clk      (clk),

  .addr_a   (ram_addr[INSTR_ADDR_WIDTH + ALIGNMENT_OFFSET - 1 : ALIGNMENT_OFFSET]), // TODO word aligned
  .we_a     ('0),
  .be_a     ('1),
  .d_a      ('0),
  .q_a      (ram_data),

  .addr_b   ('0),
  .we_b     ('0),
  .d_b      ('0),
  .q_b      ()
);

endmodule