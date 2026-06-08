`default_nettype none

module wb_arbiter_2 #
(
  parameter DATAW = 32,
  parameter ADDRW = 32
)
(
  input wire clk,                                           //  I  System Clock
  input wire rst_n,                                         //  I  Reset Active Low

  input  wire [ADDRW-1:0]   wbm0_adr_i,                     //  I  Wishbone Master 0 ADR
  input  wire [DATAW-1:0]   wbm0_dat_i,                     //  I  Wishbone Master 0 DAT
  output wire [DATAW-1:0]   wbm0_dat_o,                     //  O  Wishbone Master 0 DAT
  input  wire               wbm0_we_i,                      //  I  Wishbone Master 0 WE
  input  wire               wbm0_stb_i,                     //  I  Wishbone Master 0 STB
  output wire               wbm0_ack_o,                     //  O  Wishbone Master 0 ACK
  input  wire               wbm0_cyc_i,                     //  I  Wishbone Master 0 CYC

  input  wire [ADDRW-1:0]   wbm1_adr_i,                     //  I  Wishbone Master 1 ADR
  input  wire [DATAW-1:0]   wbm1_dat_i,                     //  I  Wishbone Master 1 DAT
  output wire [DATAW-1:0]   wbm1_dat_o,                     //  O  Wishbone Master 1 DAT
  input  wire               wbm1_we_i,                      //  I  Wishbone Master 1 WE
  input  wire               wbm1_stb_i,                     //  I  Wishbone Master 1 STB
  output wire               wbm1_ack_o,                     //  O  Wishbone Master 1 ACK
  input  wire               wbm1_cyc_i,                     //  I  Wishbone Master 1 CYC

  output wire [ADDRW-1:0]   wbs_adr_o,                      //  O  Wishbone Slave ADR
  input  wire [DATAW-1:0]   wbs_dat_i,                      //  I  Wishbone Slave DAT
  output wire [DATAW-1:0]   wbs_dat_o,                      //  O  Wishbone Slave DAT
  output wire               wbs_we_o,                       //  O  Wishbone Slave WE
  output wire               wbs_stb_o,                      //  O  Wishbone Slave STB
  input  wire               wbs_ack_i,                      //  I  Wishbone Slave ACK
  output wire               wbs_cyc_o                       //  O  Wishbone Slave CYC
);


logic grant_0_P, grant_0_N, grant_1_P, grant_1_N;

logic [ADDRW-1:0]   wbs_adr_N, wbs_adr_P;
logic [DATAW-1:0]   wbs_wr_data_N, wbs_wr_data_P;
logic [DATAW-1:0]   wbs_rd_data_N, wbs_rd_data_P;
logic               wbs_we_N,  wbs_we_P;
logic               wbs_stb_N, wbs_stb_P;
logic               wbs_ack_N, wbs_ack_P;
logic               wbs_cyc_N, wbs_cyc_P;


assign wbm0_dat_o = wbs_rd_data_P;
assign wbm0_ack_o = wbs_ack_P & grant_0_P;

assign wbm1_dat_o = wbs_rd_data_P;
assign wbm1_ack_o = wbs_ack_P & grant_1_P;

assign wbs_adr_o = wbs_adr_P;
assign wbs_dat_o = wbs_wr_data_P;
assign wbs_we_o = wbs_we_P;
assign wbs_stb_o = wbs_stb_P & ~wbs_ack_P;
assign wbs_cyc_o = wbs_cyc_P & ~wbs_ack_P;


always_comb begin
  grant_0_N = 1'b0;
  grant_1_N = 1'b0;

  wbs_rd_data_N = wbs_dat_i;
  wbs_ack_N = wbs_ack_i;

  wbs_adr_N = '0;
  wbs_wr_data_N = '0;
  wbs_we_N = '0;
  wbs_stb_N = '0;
  wbs_cyc_N = '0;

  if(wbm0_cyc_i & (grant_0_P | ~grant_1_P)) begin
    grant_0_N = ~wbs_ack_P;
    wbs_adr_N = wbm0_adr_i;
    wbs_wr_data_N = wbm0_dat_i;
    wbs_we_N = wbm0_we_i;
    wbs_stb_N = wbm0_stb_i & ~wbs_ack_P;
    wbs_cyc_N = wbm0_cyc_i & ~wbs_ack_P;
  end else if (wbm1_cyc_i & (grant_1_P | ~grant_0_P)) begin
    grant_1_N = ~wbs_ack_P;
    wbs_adr_N = wbm1_adr_i;
    wbs_wr_data_N = wbm1_dat_i;
    wbs_we_N = wbm1_we_i;
    wbs_stb_N = wbm1_stb_i & ~wbs_ack_P;
    wbs_cyc_N = wbm1_cyc_i & ~wbs_ack_P;
  end
end //always_comb


always_ff @(posedge clk or negedge rst_n) begin : proc_
  if(~rst_n) begin
    grant_0_P <= '0;
    grant_1_P <= '0;

    wbs_adr_P <= '0;
    wbs_wr_data_P <= '0;
    wbs_rd_data_P <= '0;
    wbs_we_P <= '0;
    wbs_stb_P <= '0;
    wbs_ack_P <= '0;
    wbs_cyc_P <= '0;
  end else begin
    grant_0_P <= grant_0_N;
    grant_1_P <= grant_1_N;

    wbs_adr_P <= wbs_adr_N;
    wbs_wr_data_P <= wbs_wr_data_N;
    wbs_rd_data_P <= wbs_rd_data_N;
    wbs_we_P <= wbs_we_N;
    wbs_stb_P <= wbs_stb_N;
    wbs_ack_P <= wbs_ack_N;
    wbs_cyc_P <= wbs_cyc_N;
  end
end


endmodule
`default_nettype wire
