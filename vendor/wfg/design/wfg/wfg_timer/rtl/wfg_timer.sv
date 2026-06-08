`default_nettype none

import wfg_pkg::*;

module wfg_timer #(
  parameter int DATA_WIDTH = 24
) (
  input wire              clk,
  input wire              reset_n,
  input wire    [ 0: 0]   ctrl_en_i,
  input wire              ctrl_en_enpulse_i,
  output logic            ctrl_en_disable_o,
  input wire    [ 0: 0]   cfg_auto_reload_i,
  input wire    [31: 8]   cfg_reload_value_i,
  output logic            status_count_value_den_o,
  output logic  [31: 8]   status_count_value_d_o,
  input wire              clr_clear_wpulse_i,
  input wire    [ 0: 0]   clr_clear_q_i,
  output logic  [ 0: 0]   isr_timer_down_set_o
);

  // -------------------------------------------------------------------------------------------------
  // Definitions
  // -------------------------------------------------------------------------------------------------
  logic [DATA_WIDTH - 1 : 0] r_count_val;                   // Register for counter value
  logic [DATA_WIDTH - 1 : 0] counter_ff;
  // -------------------------------------------------------------------------------------------------
  // Implementation
  // -------------------------------------------------------------------------------------------------
  assign r_count_val = counter_ff - {{(DATA_WIDTH-1){1'b0}}, 1'b1};    // Generate count down value
  assign status_count_value_den_o = 1'b1;
  assign status_count_value_d_o = counter_ff;

  always_ff @(posedge clk) begin
    isr_timer_down_set_o <= 1'b0;
    ctrl_en_disable_o <= 1'b0;
    if (clr_clear_wpulse_i & clr_clear_q_i) begin
      counter_ff <= {(DATA_WIDTH){1'b0}};
    end else if (ctrl_en_enpulse_i) begin
          counter_ff <= cfg_reload_value_i;
    end else if (ctrl_en_i & ~ctrl_en_disable_o) begin
      if (counter_ff == {(DATA_WIDTH){1'b0}}) begin
        isr_timer_down_set_o <= 1'b1;
        if (cfg_auto_reload_i) begin
          counter_ff <= cfg_reload_value_i;
        end else begin
          ctrl_en_disable_o <= 1'b1;
        end
      end else begin
        counter_ff <= r_count_val;
      end
    end
  end

endmodule // wfg_timer
`default_nettype wire
