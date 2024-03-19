`timescale 1ns/1ps

module memory_test;

// allow fst dump
initial begin
    $dumpfile("memory_test.vcd");
    $dumpvars();
end

logic clk;
logic [31:0] ram_addr, ram_data;

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

  .addr_a   (ram_addr[INSTR_ADDR_WIDTH+1:2]), // TODO word aligned
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