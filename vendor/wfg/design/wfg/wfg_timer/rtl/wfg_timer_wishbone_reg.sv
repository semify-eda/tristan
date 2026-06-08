// Note: marker_template_* comments inside are upstream-only code-generation hooks; no effect in this vendored copy.
`default_nettype none

import wfg_pkg::*;

module wfg_timer_wishbone_reg (
  //marker_template_start
  //data: ../data/wfg_timer_reg.json
  //template: wishbone/register_interface.template
  //marker_template_code
  output logic [ 0: 0] ctrl_en_q_o,
  output logic         ctrl_en_enpulse_o,
  input  wire          ctrl_en_disable_i,
  output logic [ 0: 0] cfg_auto_reload_q_o,
  output logic [31: 8] cfg_reload_value_q_o,
  input  wire          status_count_value_den_i,
  input  wire  [31: 8] status_count_value_d_i,
  output logic         clr_clear_wpulse_o,
  output logic [ 0: 0] clr_clear_q_o,
  input  wire  [ 0: 0] isr_timer_down_set_i,
  output logic         interrupt_o,

  //marker_template_end

  input  wire                 clk,
  input  wire                 rst_n,
  input  wire                 wbs_stb_i,
  input  wire                 wbs_cyc_i,
  input  wire                 wbs_we_i,
  input  wire  [  (BUSW-1):0] wbs_dat_i,
  input  wire  [ (ADDRW-1):0] wbs_adr_i,
  output logic                wbs_ack_o,
  output logic [  (BUSW-1):0] wbs_dat_o

);

  //marker_template_start
  //data: ../data/wfg_timer_reg.json
  //template: wishbone/instantiate_registers.template
  //marker_template_code
  logic [ 0: 0] ctrl_en_ff;
  logic [ 0: 0] cfg_auto_reload_ff;
  logic [31: 8] cfg_reload_value_ff;
  logic [31: 8] status_count_value_ff;
  logic [ 0: 0] clr_clear_ff;
  logic [ 0: 0] isr_timer_down_ff;
  logic [ 0: 0] ier_timer_down_ff;

  //marker_template_end

  // Wishbone write to slave
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      //marker_template_start
      //data: ../data/wfg_timer_reg.json
      //template: wishbone/reset_registers.template
      //marker_template_code
      ctrl_en_ff               <= 1'b0;
      cfg_auto_reload_ff       <= 1'b1;
      cfg_reload_value_ff      <= 24'h0;
      status_count_value_ff    <= 24'h0;
      clr_clear_ff             <= 1'b0;
      isr_timer_down_ff        <= 1'b0;
      ier_timer_down_ff        <= 1'b1;

      //marker_template_end
    end else begin
      if (wbs_stb_i && wbs_we_i && wbs_cyc_i) begin
        case (wbs_adr_i[REGISTER_SEL_ADDRW-1:0])
          //marker_template_start
          //data: ../data/wfg_timer_reg.json
          //template: wishbone/assign_to_registers.template
          //marker_template_code
          8'h00: begin
            ctrl_en_ff               <= wbs_dat_i[ 0: 0];
          end
          8'h04: begin
            cfg_auto_reload_ff       <= wbs_dat_i[ 0: 0];
            cfg_reload_value_ff      <= wbs_dat_i[31: 8];
            ctrl_en_ff               <= 1'b0;
          end
          8'h10: begin
            clr_clear_ff             <= wbs_dat_i[ 0: 0];
            ctrl_en_ff               <= 1'b0;
          end
          8'hA4: begin
            ier_timer_down_ff        <= wbs_dat_i[ 0: 0];
          end
          8'hA8: begin
            isr_timer_down_ff        <= isr_timer_down_ff & ~wbs_dat_i[ 0: 0];
          end

          //marker_template_end
	  default: begin end
        endcase
      end

      //register hw updates
      //marker_template_start
      //data: ../data/wfg_timer_reg.json
      //template: wishbone/hw_update_registers.template
      //marker_template_code
      if(ctrl_en_disable_i) begin
        ctrl_en_ff <= 1'b0;
      end
      if(status_count_value_den_i) begin
        status_count_value_ff <= status_count_value_d_i;
      end
      if(|isr_timer_down_set_i) begin
        isr_timer_down_ff <= isr_timer_down_set_i;
      end

      //marker_template_end
    end
  end//always_ff

  // Wishbone read from slave
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      wbs_dat_o <= '0;
    end else begin
      if (wbs_stb_i && !wbs_we_i && wbs_cyc_i) begin
        wbs_dat_o <= '0;
        case (wbs_adr_i[REGISTER_SEL_ADDRW-1:0])
          //marker_template_start
          //data: ../data/wfg_timer_reg.json
          //template: wishbone/assign_from_registers.template
          //marker_template_code
          8'h00: begin
                  wbs_dat_o[ 0: 0] <= ctrl_en_ff;
          end
          8'h04: begin
                  wbs_dat_o[ 0: 0] <= cfg_auto_reload_ff;
                  wbs_dat_o[31: 8] <= cfg_reload_value_ff;
          end
          8'h08: begin
                  wbs_dat_o[31: 8] <= status_count_value_ff;
          end
          8'hA0: begin
                  wbs_dat_o[ 0: 0] <= isr_timer_down_ff;
          end
          8'hA4: begin
                  wbs_dat_o[ 0: 0] <= ier_timer_down_ff;
          end
          8'hFC: begin
                  wbs_dat_o[ 7: 0] <= 8'd0;
                  wbs_dat_o[15: 8] <= 8'd0;
                  wbs_dat_o[23:16] <= 8'd1;
                  wbs_dat_o[27:27] <= 4'h0;
                  wbs_dat_o[31:28] <= 4'h0;
          end

          //marker_template_end
	  default: begin end
        endcase
      end
    end
  end//always_ff



  //marker_template_start
  //data: ../data/wfg_timer_reg.json
  //template: wishbone/interrupts.template
  //marker_template_code

  logic isr_timer_down_masked;
  assign isr_timer_down_masked = |(isr_timer_down_ff & ier_timer_down_ff);

  assign interrupt_o = isr_timer_down_masked;

  //marker_template_end


  // WB Acknowledgement
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      wbs_ack_o <= 1'b0;
    end else begin
      wbs_ack_o <= wbs_stb_i && wbs_cyc_i & !wbs_ack_o;
    end
  end

  //marker_template_start
  //data: ../data/wfg_timer_reg.json
  //template: wishbone/assign_outputs.template
  //marker_template_code
  assign ctrl_en_q_o              = ctrl_en_ff;
  assign ctrl_en_enpulse_o        = ((wbs_adr_i[REGISTER_SEL_ADDRW-1:0] == 8'h00) & wbs_we_i & wbs_ack_o
                                     & (ctrl_en_ff[ 0: 0] != 1'b0));
  assign cfg_auto_reload_q_o      = cfg_auto_reload_ff;
  assign cfg_reload_value_q_o     = cfg_reload_value_ff;
  assign clr_clear_q_o            = clr_clear_ff;
  assign clr_clear_wpulse_o       = ((wbs_adr_i[REGISTER_SEL_ADDRW-1:0] == 8'h10) & wbs_we_i & wbs_ack_o);

  //marker_template_end
endmodule
`default_nettype wire
