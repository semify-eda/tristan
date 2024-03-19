module sram_dualport #(
  parameter                   INITFILEEN = 0,
  parameter string            INITFILE   = "init.mem",
  parameter                   DATAWIDTH  = 32,
  parameter                   ADDRWIDTH  = 14
) (
  input  wire clk,

  input  wire  [ADDRWIDTH-1:0] addr_a,
  input  wire                  we_a,
  input  wire  [DATAWIDTH-1:0] d_a,
  output logic [DATAWIDTH-1:0] q_a,

  input  wire  [ADDRWIDTH-1:0] addr_b,
  input  wire                  we_b,
  input  wire  [DATAWIDTH-1:0] d_b,
  output logic [DATAWIDTH-1:0] q_b
);

  localparam MEMSIZE = 1 << ADDRWIDTH;

  //Wire/Reg declarations
  // (* ram_style = "block" *)

  logic [DATAWIDTH-1:0]  ram [MEMSIZE-1:0];

  generate
    if (INITFILEEN) begin
      initial begin
        $readmemh(INITFILE, ram);
        // $readmemb(INITFILE, ram);
      end//init
    end else begin
      initial begin
        foreach(ram[i]) begin
          ram[i] = '0;
        end//for
      end//init
    end//elif
  endgenerate


  always_ff @(posedge clk) begin
    q_a <= ram[addr_a];
    if (we_a) begin
      ram[addr_a] <= d_a;
    end//if
  end//always_ff

  always_ff @(posedge clk) begin
    q_b <= ram[addr_b];
    if (we_b) begin
      ram[addr_b] <= d_b;
    end//if
  end//always_ff

endmodule