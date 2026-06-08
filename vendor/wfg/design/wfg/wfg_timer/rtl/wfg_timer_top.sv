`default_nettype none
import wfg_pkg::*;

module wfg_timer_top #(
  parameter int DATA_WIDTH = 24
) (
  input  wire                 clk,
  input  wire                 rst_n,

  input  wire                 wbs_stb_i,
  input  wire                 wbs_cyc_i,
  input  wire                 wbs_we_i,
  input  wire  [  (BUSW-1):0] wbs_dat_i,
  input  wire  [ (ADDRW-1):0] wbs_adr_i,
  output logic                wbs_ack_o,
  output logic [  (BUSW-1):0] wbs_dat_o,

  output logic interrupt_o
);

  // Registers for timer configuration over wishbonebus
  //marker_template_start
  //data: ../data/wfg_timer_reg.json
  //template: wishbone/instantiate_top.template
  //marker_template_code
  logic [ 0: 0] ctrl_en_q;
  logic         ctrl_en_enpulse;
  logic         ctrl_en_disable;
  logic [ 0: 0] cfg_auto_reload_q;
  logic [31: 8] cfg_reload_value_q;
  logic         status_count_value_den;
  logic [31: 8] status_count_value_d;
  logic         clr_clear_wpulse;
  logic [ 0: 0] clr_clear_q;
  logic [ 0: 0] isr_timer_down_set;

  //marker_template_end


  // register for timer configuration
  wfg_timer_wishbone_reg wfg_timer_wishbone_reg (
    //marker_template_start
    //data: ../data/wfg_timer_reg.json
    //template: wishbone/assign_to_module.template
    //marker_template_code
    .ctrl_en_q_o             (ctrl_en_q               ),
    .ctrl_en_enpulse_o       (ctrl_en_enpulse         ),
    .ctrl_en_disable_i       (ctrl_en_disable         ),
    .cfg_auto_reload_q_o     (cfg_auto_reload_q       ),
    .cfg_reload_value_q_o    (cfg_reload_value_q      ),
    .status_count_value_den_i(status_count_value_den  ),
    .status_count_value_d_i  (status_count_value_d    ),
    .clr_clear_wpulse_o      (clr_clear_wpulse        ),
    .clr_clear_q_o           (clr_clear_q             ),
    .isr_timer_down_set_i    (isr_timer_down_set      ),
    .interrupt_o             (interrupt_o             ),

    //marker_template_end
    .clk (clk),
    .rst_n (rst_n),
    .wbs_stb_i(wbs_stb_i),
    .wbs_cyc_i(wbs_cyc_i),
    .wbs_we_i (wbs_we_i),
    .wbs_dat_i(wbs_dat_i),
    .wbs_adr_i(wbs_adr_i),
    .wbs_ack_o(wbs_ack_o),
    .wbs_dat_o(wbs_dat_o)
  );

  wfg_timer #(
    .DATA_WIDTH               (DATA_WIDTH)
  )
  wfg_timer
  (
    .clk                        (clk),
    .reset_n                    (rst_n),
    .ctrl_en_i                  (ctrl_en_q),
    .ctrl_en_enpulse_i          (ctrl_en_enpulse),
    .ctrl_en_disable_o          (ctrl_en_disable),
    .cfg_auto_reload_i          (cfg_auto_reload_q),
    .cfg_reload_value_i         (cfg_reload_value_q),
    .status_count_value_den_o   (status_count_value_den),
    .status_count_value_d_o     (status_count_value_d),
    .clr_clear_wpulse_i         (clr_clear_wpulse),
    .clr_clear_q_i              (clr_clear_q),
    .isr_timer_down_set_o       (isr_timer_down_set)
  );

endmodule
`default_nettype wire
