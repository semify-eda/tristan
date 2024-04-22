#include "hal.h"
#include <stdint.h>

// marker_template_start
// multidata: globaldata:../../pkg/global_templating_data.json
// multidata: wfg_core_top:../../wfg/wfg_core/data/wfg_core_reg.json
// multidata: wfg_drive_i2c_top:../../wfg/wfg_drive_i2c/data/wfg_drive_i2c_reg.json
// multidata: wfg_drive_i2ct_top:../../wfg/wfg_drive_i2ct/data/wfg_drive_i2ct_reg.json
// multidata: wfg_drive_pat_top:../../wfg/wfg_drive_pat/data/wfg_drive_pat_reg.json
// multidata: wfg_drive_spi_top:../../wfg/wfg_drive_spi/data/wfg_drive_spi_reg.json
// multidata: wfg_drive_uart_top:../../wfg/wfg_drive_uart/data/wfg_drive_uart_reg.json
// multidata: wfg_stim_mem_top:../../wfg/wfg_stim_mem/data/wfg_stim_mem_reg.json
// multidata: wfg_record_mem_top:../../wfg/wfg_record_mem/data/wfg_record_mem_reg.json
// multidata: wfg_pin_mux_top:../../wfg/wfg_pin_mux/data/wfg_pin_mux_reg.json
// multidata: wfg_sysctrl_reg:../../wfg/wfg_top/data/wfg_sysctrl_reg.json
// multidata: wfg_timer_reg:../../wfg/wfg_timer/data/wfg_timer_reg.json
// template: soc_registers/inits.template
// marker_template_code
volatile wfg_interconnect_t* const wfg_interconnect = (wfg_interconnect_t*) MOD_WFG_INTERCONNECT_BASE;
volatile wfg_core_top_t* const wfg_core_top = (wfg_core_top_t* const) MOD_WFG_CORE_TOP_BASE;
volatile wfg_pin_mux_top_t* const wfg_pin_mux_top = (wfg_pin_mux_top_t* const) MOD_WFG_PIN_MUX_TOP_BASE;
volatile wfg_sysctrl_reg_t* const wfg_sysctrl_reg = (wfg_sysctrl_reg_t* const) MOD_WFG_SYSCTRL_REG_BASE;
volatile wfg_stim_mem_top_t* const wfg_stim_mem_top_0 = (wfg_stim_mem_top_t* const) MOD_WFG_STIM_MEM_TOP_0_BASE;
volatile wfg_stim_mem_top_t* const wfg_stim_mem_top_1 = (wfg_stim_mem_top_t* const) MOD_WFG_STIM_MEM_TOP_1_BASE;
volatile wfg_stim_mem_top_t* const wfg_stim_mem_top_2 = (wfg_stim_mem_top_t* const) MOD_WFG_STIM_MEM_TOP_2_BASE;
volatile wfg_stim_mem_top_t* const wfg_stim_mem_top_3 = (wfg_stim_mem_top_t* const) MOD_WFG_STIM_MEM_TOP_3_BASE;
volatile wfg_drive_spi_top_t* const wfg_drive_spi_top_0 = (wfg_drive_spi_top_t* const) MOD_WFG_DRIVE_SPI_TOP_0_BASE;
volatile wfg_drive_spi_top_t* const wfg_drive_spi_top_1 = (wfg_drive_spi_top_t* const) MOD_WFG_DRIVE_SPI_TOP_1_BASE;
volatile wfg_drive_pat_top_t* const wfg_drive_pat_top_0 = (wfg_drive_pat_top_t* const) MOD_WFG_DRIVE_PAT_TOP_0_BASE;
volatile wfg_drive_i2c_top_t* const wfg_drive_i2c_top_0 = (wfg_drive_i2c_top_t* const) MOD_WFG_DRIVE_I2C_TOP_0_BASE;
volatile wfg_drive_i2c_top_t* const wfg_drive_i2c_top_1 = (wfg_drive_i2c_top_t* const) MOD_WFG_DRIVE_I2C_TOP_1_BASE;
volatile wfg_drive_i2ct_top_t* const wfg_drive_i2ct_top_0 = (wfg_drive_i2ct_top_t* const) MOD_WFG_DRIVE_I2CT_TOP_0_BASE;
volatile wfg_drive_uart_top_t* const wfg_drive_uart_top_0 = (wfg_drive_uart_top_t* const) MOD_WFG_DRIVE_UART_TOP_0_BASE;
volatile wfg_drive_uart_top_t* const wfg_drive_uart_top_1 = (wfg_drive_uart_top_t* const) MOD_WFG_DRIVE_UART_TOP_1_BASE;
volatile wfg_record_mem_top_t* const wfg_record_mem_top_0 = (wfg_record_mem_top_t* const) MOD_WFG_RECORD_MEM_TOP_0_BASE;
volatile wfg_record_mem_top_t* const wfg_record_mem_top_1 = (wfg_record_mem_top_t* const) MOD_WFG_RECORD_MEM_TOP_1_BASE;
volatile wfg_record_mem_top_t* const wfg_record_mem_top_2 = (wfg_record_mem_top_t* const) MOD_WFG_RECORD_MEM_TOP_2_BASE;
volatile wfg_record_mem_top_t* const wfg_record_mem_top_3 = (wfg_record_mem_top_t* const) MOD_WFG_RECORD_MEM_TOP_3_BASE;
volatile wfg_timer_t* const wfg_timer = (wfg_timer_t* const) MOD_TIMER_BASE;

//marker_template_end