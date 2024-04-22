#ifndef HAL_H
#define HAL_H
/*
    Hardware Abstraction Layer
*/
#include <stdint.h>

#define TIMER_FREQ          100000000
#define TIMER_IRQ_FREQ      10
#define TIMER_RELOAD_VAL    (TIMER_FREQ / TIMER_IRQ_FREQ)

// debugging function
#define LED_ON  0x2
#define LED_OFF 0x1

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
// template: soc_registers/headers.template
// marker_template_code

////////////////////////////////////////////
//********** module values ***************//
////////////////////////////////////////////

typedef enum pinmux_output_pins_t {

    WFG_PINMUX_OUT_WFG_DRIVE_SPI_TOP_0_SCLK = 32,
    WFG_PINMUX_OUT_WFG_DRIVE_SPI_TOP_0_CS = 31,
    WFG_PINMUX_OUT_WFG_DRIVE_SPI_TOP_0_DOUT = 30,
    WFG_PINMUX_OUT_WFG_DRIVE_SPI_TOP_1_SCLK = 29,
    WFG_PINMUX_OUT_WFG_DRIVE_SPI_TOP_1_CS = 28,
    WFG_PINMUX_OUT_WFG_DRIVE_SPI_TOP_1_DOUT = 27,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_0 = 26,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_1 = 25,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_2 = 24,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_3 = 23,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_4 = 22,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_5 = 21,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_6 = 20,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_7 = 19,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_8 = 18,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_9 = 17,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_10 = 16,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_11 = 15,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_12 = 14,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_13 = 13,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_14 = 12,
    WFG_PINMUX_OUT_WFG_DRIVE_PAT_TOP_0_OUTPUT_15 = 11,
    WFG_PINMUX_OUT_WFG_DRIVE_I2C_TOP_0_SCL = 10,
    WFG_PINMUX_OUT_WFG_DRIVE_I2C_TOP_0_SDA = 9,
    WFG_PINMUX_OUT_WFG_DRIVE_I2C_TOP_1_SCL = 8,
    WFG_PINMUX_OUT_WFG_DRIVE_I2C_TOP_1_SDA = 7,
    WFG_PINMUX_OUT_WFG_DRIVE_I2CT_TOP_0_SCL = 6,
    WFG_PINMUX_OUT_WFG_DRIVE_I2CT_TOP_0_SDA = 5,
    WFG_PINMUX_OUT_WFG_DRIVE_UART_TOP_0_TX = 4,
    WFG_PINMUX_OUT_WFG_DRIVE_UART_TOP_1_TX = 3
} pinmux_output_pins_t;

typedef enum pinmux_input_pins_t {

    WFG_PINMUX_IN_WFG_DRIVE_SPI_TOP_0_DIN = 9,
    WFG_PINMUX_IN_WFG_DRIVE_SPI_TOP_1_DIN = 8,
    WFG_PINMUX_IN_WFG_DRIVE_I2C_TOP_0_SCL = 7,
    WFG_PINMUX_IN_WFG_DRIVE_I2C_TOP_0_SDA = 6,
    WFG_PINMUX_IN_WFG_DRIVE_I2C_TOP_1_SCL = 5,
    WFG_PINMUX_IN_WFG_DRIVE_I2C_TOP_1_SDA = 4,
    WFG_PINMUX_IN_WFG_DRIVE_I2CT_TOP_0_SCL = 3,
    WFG_PINMUX_IN_WFG_DRIVE_I2CT_TOP_0_SDA = 2,
    WFG_PINMUX_IN_WFG_DRIVE_UART_TOP_0_RX = 1,
    WFG_PINMUX_IN_WFG_DRIVE_UART_TOP_1_RX = 0
} pinmux_input_pins_t;

typedef enum pinmux_pullup_values_t {
    WFG_PINMUX_PULLUP_ENABLE = 1,
    WFG_PINMUX_PULLUP_DISABLE = 0
} pinmux_pullup_values_t;

typedef enum interconnect_values_t {
    WFG_INTERCONNECT_SELECT_WFG_DRIVE_SPI_TOP_0 = 0x01U,
    WFG_INTERCONNECT_SELECT_WFG_DRIVE_SPI_TOP_1 = 0x02U,
    WFG_INTERCONNECT_SELECT_WFG_DRIVE_PAT_TOP_0 = 0x11U,
    WFG_INTERCONNECT_SELECT_WFG_DRIVE_I2C_TOP_0 = 0x21U,
    WFG_INTERCONNECT_SELECT_WFG_DRIVE_I2C_TOP_1 = 0x22U,
    WFG_INTERCONNECT_SELECT_WFG_DRIVE_I2CT_TOP_0 = 0x21U,
    WFG_INTERCONNECT_SELECT_WFG_DRIVE_UART_TOP_0 = 0x31U,
    WFG_INTERCONNECT_SELECT_WFG_DRIVE_UART_TOP_1 = 0x32U,
    WFG_INTERCONNECT_SELECT_WFG_STIM_MEM_TOP_0 = 0x01U,    
    WFG_INTERCONNECT_SELECT_WFG_STIM_MEM_TOP_1 = 0x02U,    
    WFG_INTERCONNECT_SELECT_WFG_STIM_MEM_TOP_2 = 0x03U,    
    WFG_INTERCONNECT_SELECT_WFG_STIM_MEM_TOP_3 = 0x04U    
} interconnect_values_t;

////////////////////////////////////////////
//********** module base addresses *******//
////////////////////////////////////////////
#define MOD_WFG_MEMORY 0x120000U
#define MOD_WFG_INTERCONNECT_BASE 0x44000U
#define MOD_WFG_CORE_TOP_BASE 0x140000U
#define MOD_WFG_PIN_MUX_TOP_BASE 0x146000U
#define MOD_WFG_SYSCTRL_REG_BASE 0x148000U
#define MOD_WFG_STIM_MEM_TOP_0_BASE 0x160000U
#define MOD_WFG_STIM_MEM_TOP_1_BASE 0x160100U
#define MOD_WFG_STIM_MEM_TOP_2_BASE 0x160200U
#define MOD_WFG_STIM_MEM_TOP_3_BASE 0x160300U
#define MOD_WFG_DRIVE_SPI_TOP_0_BASE 0x180000U
#define MOD_WFG_DRIVE_SPI_TOP_1_BASE 0x180100U
#define MOD_WFG_DRIVE_PAT_TOP_0_BASE 0x182000U
#define MOD_WFG_DRIVE_I2C_TOP_0_BASE 0x184000U
#define MOD_WFG_DRIVE_I2C_TOP_1_BASE 0x184100U
#define MOD_WFG_DRIVE_I2CT_TOP_0_BASE 0x188000U
#define MOD_WFG_DRIVE_UART_TOP_0_BASE 0x186000U
#define MOD_WFG_DRIVE_UART_TOP_1_BASE 0x186100U
#define MOD_WFG_RECORD_MEM_TOP_0_BASE 0x1a0000U
#define MOD_WFG_RECORD_MEM_TOP_1_BASE 0x1a0100U
#define MOD_WFG_RECORD_MEM_TOP_2_BASE 0x1a0200U
#define MOD_WFG_RECORD_MEM_TOP_3_BASE 0x1a0300U
#define MOD_TIMER_BASE 0x1e0000U

////////////////////////////////////////////
//********** register bitfields **********//
////////////////////////////////////////////
typedef union bitfield_wfg_core_top_ctrl_t {
    uint32_t value;
    struct {
        uint32_t en : 1;
    } __attribute__ ((packed));
} bitfield_wfg_core_top_ctrl_t;

typedef union bitfield_wfg_core_top_cfg_t {
    uint32_t value;
    struct {
        uint32_t sync : 16;
        uint32_t subcycle : 16;
    } __attribute__ ((packed));
} bitfield_wfg_core_top_cfg_t;

typedef union bitfield_wfg_core_top_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_wfg_core_top_module_info_t;

typedef union bitfield_wfg_pin_mux_top_output_sel_0_t {
    uint32_t value;
    struct {
        uint32_t _0 : 8;
        uint32_t _1 : 8;
        uint32_t _2 : 8;
        uint32_t _3 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_output_sel_0_t;

typedef union bitfield_wfg_pin_mux_top_output_sel_1_t {
    uint32_t value;
    struct {
        uint32_t _4 : 8;
        uint32_t _5 : 8;
        uint32_t _6 : 8;
        uint32_t _7 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_output_sel_1_t;

typedef union bitfield_wfg_pin_mux_top_output_sel_2_t {
    uint32_t value;
    struct {
        uint32_t _8 : 8;
        uint32_t _9 : 8;
        uint32_t _10 : 8;
        uint32_t _11 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_output_sel_2_t;

typedef union bitfield_wfg_pin_mux_top_output_sel_3_t {
    uint32_t value;
    struct {
        uint32_t _12 : 8;
        uint32_t _13 : 8;
        uint32_t _14 : 8;
        uint32_t _15 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_output_sel_3_t;

typedef union bitfield_wfg_pin_mux_top_pullup_sel_0_t {
    uint32_t value;
    struct {
        uint32_t _0 : 8;
        uint32_t _1 : 8;
        uint32_t _2 : 8;
        uint32_t _3 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_pullup_sel_0_t;

typedef union bitfield_wfg_pin_mux_top_pullup_sel_1_t {
    uint32_t value;
    struct {
        uint32_t _4 : 8;
        uint32_t _5 : 8;
        uint32_t _6 : 8;
        uint32_t _7 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_pullup_sel_1_t;

typedef union bitfield_wfg_pin_mux_top_pullup_sel_2_t {
    uint32_t value;
    struct {
        uint32_t _8 : 8;
        uint32_t _9 : 8;
        uint32_t _10 : 8;
        uint32_t _11 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_pullup_sel_2_t;

typedef union bitfield_wfg_pin_mux_top_pullup_sel_3_t {
    uint32_t value;
    struct {
        uint32_t _12 : 8;
        uint32_t _13 : 8;
        uint32_t _14 : 8;
        uint32_t _15 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_pullup_sel_3_t;

typedef union bitfield_wfg_pin_mux_top_input_sel_0_t {
    uint32_t value;
    struct {
        uint32_t _0 : 8;
        uint32_t _1 : 8;
        uint32_t _2 : 8;
        uint32_t _3 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_input_sel_0_t;

typedef union bitfield_wfg_pin_mux_top_input_sel_1_t {
    uint32_t value;
    struct {
        uint32_t _4 : 8;
        uint32_t _5 : 8;
        uint32_t _6 : 8;
        uint32_t _7 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_input_sel_1_t;

typedef union bitfield_wfg_pin_mux_top_input_sel_2_t {
    uint32_t value;
    struct {
        uint32_t _8 : 8;
        uint32_t _9 : 8;
        uint32_t _10 : 8;
        uint32_t _11 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_input_sel_2_t;

typedef union bitfield_wfg_pin_mux_top_input_sel_3_t {
    uint32_t value;
    struct {
        uint32_t _12 : 8;
        uint32_t _13 : 8;
        uint32_t _14 : 8;
        uint32_t _15 : 8;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_input_sel_3_t;

typedef union bitfield_wfg_pin_mux_top_mirror_output_t {
    uint32_t value;
    struct {
        uint32_t val : 16;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_mirror_output_t;

typedef union bitfield_wfg_pin_mux_top_mirror_pullup_t {
    uint32_t value;
    struct {
        uint32_t val : 16;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_mirror_pullup_t;

typedef union bitfield_wfg_pin_mux_top_mirror_input_t {
    uint32_t value;
    struct {
        uint32_t val : 16;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_mirror_input_t;

typedef union bitfield_wfg_pin_mux_top_pin_ir_rising_t {
    uint32_t value;
    struct {
        uint32_t val : 16;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_pin_ir_rising_t;

typedef union bitfield_wfg_pin_mux_top_pin_ir_falling_t {
    uint32_t value;
    struct {
        uint32_t val : 16;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_pin_ir_falling_t;

typedef union bitfield_wfg_pin_mux_top_isr_t {
    uint32_t value;
    struct {
        uint32_t pin : 16;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_isr_t;

typedef union bitfield_wfg_pin_mux_top_ier_t {
    uint32_t value;
    struct {
        uint32_t pin : 16;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_ier_t;

typedef union bitfield_wfg_pin_mux_top_icr_t {
    uint32_t value;
    struct {
        uint32_t pin : 16;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_icr_t;

typedef union bitfield_wfg_pin_mux_top_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_wfg_pin_mux_top_module_info_t;

typedef union bitfield_wfg_sysctrl_reg_product_t {
    uint32_t value;
    struct {
        uint32_t id : 32;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_product_t;

typedef union bitfield_wfg_sysctrl_reg_fpga_version_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t dev : 8;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_fpga_version_t;

typedef union bitfield_wfg_sysctrl_reg_gendate_t {
    uint32_t value;
    struct {
        uint32_t year : 11;
        uint32_t month : 4;
        uint32_t day : 5;
        uint32_t hour : 4;
        uint32_t minute : 6;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_gendate_t;

typedef union bitfield_wfg_sysctrl_reg_clk_speed_t {
    uint32_t value;
    struct {
        uint32_t val : 8;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_clk_speed_t;

typedef union bitfield_wfg_sysctrl_reg_soc_ctrl_t {
    uint32_t value;
    struct {
        uint32_t fetch_enable : 1;
        uint32_t core_reset_n : 1;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_soc_ctrl_t;

typedef union bitfield_wfg_sysctrl_reg_soc_status_t {
    uint32_t value;
    struct {
        uint32_t core_sleep : 1;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_soc_status_t;

typedef union bitfield_wfg_sysctrl_reg_reset_flags_t {
    uint32_t value;
    struct {
        uint32_t wfg : 1;
        uint32_t soc : 1;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_reset_flags_t;

typedef union bitfield_wfg_sysctrl_reg_reset_clears_t {
    uint32_t value;
    struct {
        uint32_t wfg : 1;
        uint32_t soc : 1;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_reset_clears_t;

typedef union bitfield_wfg_sysctrl_reg_isr_t {
    uint32_t value;
    struct {
        uint32_t wishbone_invalid_address : 1;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_isr_t;

typedef union bitfield_wfg_sysctrl_reg_ier_t {
    uint32_t value;
    struct {
        uint32_t wishbone_invalid_address : 1;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_ier_t;

typedef union bitfield_wfg_sysctrl_reg_icr_t {
    uint32_t value;
    struct {
        uint32_t wishbone_invalid_address : 1;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_icr_t;

typedef union bitfield_wfg_sysctrl_reg_interrupt_mirror_t {
    uint32_t value;
    struct {
        uint32_t vector : 32;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_interrupt_mirror_t;

typedef union bitfield_wfg_sysctrl_reg_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_wfg_sysctrl_reg_module_info_t;


typedef union bitfield_wfg_stim_mem_top_ctrl_t {
    uint32_t value;
    struct {
        uint32_t en : 1;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_ctrl_t;

typedef union bitfield_wfg_stim_mem_top_cfg_t {
    uint32_t value;
    struct {
        uint32_t cnt : 8;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_cfg_t;

typedef union bitfield_wfg_stim_mem_top_start_t {
    uint32_t value;
    struct {
        uint32_t val : 1;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_start_t;

typedef union bitfield_wfg_stim_mem_top_stop_t {
    uint32_t value;
    struct {
        uint32_t val : 1;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_stop_t;

typedef union bitfield_wfg_stim_mem_top_step_t {
    uint32_t value;
    struct {
        uint32_t val : 1;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_step_t;

typedef union bitfield_wfg_stim_mem_top_addr_t {
    uint32_t value;
    struct {
        uint32_t val : 1;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_addr_t;

typedef union bitfield_wfg_stim_mem_top_gain_t {
    uint32_t value;
    struct {
        uint32_t val : 16;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_gain_t;

typedef union bitfield_wfg_stim_mem_top_offset_t {
    uint32_t value;
    struct {
        uint32_t val : 32;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_offset_t;

typedef union bitfield_wfg_stim_mem_top_isr_t {
    uint32_t value;
    struct {
        uint32_t done : 1;
        uint32_t end : 1;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_isr_t;

typedef union bitfield_wfg_stim_mem_top_ier_t {
    uint32_t value;
    struct {
        uint32_t done : 1;
        uint32_t end : 1;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_ier_t;

typedef union bitfield_wfg_stim_mem_top_icr_t {
    uint32_t value;
    struct {
        uint32_t done : 1;
        uint32_t end : 1;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_icr_t;

typedef union bitfield_wfg_stim_mem_top_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_wfg_stim_mem_top_module_info_t;

typedef union bitfield_wfg_drive_spi_top_ctrl_t {
    uint32_t value;
    struct {
        uint32_t en : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_spi_top_ctrl_t;

typedef union bitfield_wfg_drive_spi_top_cfg_t {
    uint32_t value;
    struct {
        uint32_t cpol : 1;
        uint32_t cpha : 1;
        uint32_t lsbfirst : 1;
        uint32_t sspol : 1;
        uint32_t core_sel : 1;
        uint32_t core_dependent : 1;
        uint32_t io_delay_compensation : 3;
    } __attribute__ ((packed));
} bitfield_wfg_drive_spi_top_cfg_t;

typedef union bitfield_wfg_drive_spi_top_clkcfg_t {
    uint32_t value;
    struct {
        uint32_t div : 32;
    } __attribute__ ((packed));
} bitfield_wfg_drive_spi_top_clkcfg_t;

typedef union bitfield_wfg_drive_spi_top_spi_len_t {
    uint32_t value;
    struct {
        uint32_t val : 6;
    } __attribute__ ((packed));
} bitfield_wfg_drive_spi_top_spi_len_t;

typedef union bitfield_wfg_drive_spi_top_cs_high_time_t {
    uint32_t value;
    struct {
        uint32_t val : 32;
    } __attribute__ ((packed));
} bitfield_wfg_drive_spi_top_cs_high_time_t;

typedef union bitfield_wfg_drive_spi_top_cs_active_delay_time_t {
    uint32_t value;
    struct {
        uint32_t val : 32;
    } __attribute__ ((packed));
} bitfield_wfg_drive_spi_top_cs_active_delay_time_t;

typedef union bitfield_wfg_drive_spi_top_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_wfg_drive_spi_top_module_info_t;

typedef union bitfield_wfg_drive_pat_top_ctrl_t {
    uint32_t value;
    struct {
        uint32_t en : 16;
    } __attribute__ ((packed));
} bitfield_wfg_drive_pat_top_ctrl_t;

typedef union bitfield_wfg_drive_pat_top_cfg_t {
    uint32_t value;
    struct {
        uint32_t begin : 8;
        uint32_t end : 8;
        uint32_t core_sel : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_pat_top_cfg_t;

typedef union bitfield_wfg_drive_pat_top_patsel0_t {
    uint32_t value;
    struct {
        uint32_t low : 16;
    } __attribute__ ((packed));
} bitfield_wfg_drive_pat_top_patsel0_t;

typedef union bitfield_wfg_drive_pat_top_patsel1_t {
    uint32_t value;
    struct {
        uint32_t high : 16;
    } __attribute__ ((packed));
} bitfield_wfg_drive_pat_top_patsel1_t;

typedef union bitfield_wfg_drive_pat_top_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_wfg_drive_pat_top_module_info_t;

typedef union bitfield_wfg_drive_i2c_top_ctrl_t {
    uint32_t value;
    struct {
        uint32_t en : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2c_top_ctrl_t;

typedef union bitfield_wfg_drive_i2c_top_cfg_t {
    uint32_t value;
    struct {
        uint32_t dev_id : 7;
        uint32_t wait_state_enabled : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2c_top_cfg_t;

typedef union bitfield_wfg_drive_i2c_top_clkcfg_t {
    uint32_t value;
    struct {
        uint32_t div : 32;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2c_top_clkcfg_t;

typedef union bitfield_wfg_drive_i2c_top_isr_t {
    uint32_t value;
    struct {
        uint32_t command_frame_error : 1;
        uint32_t data_frame_error : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2c_top_isr_t;

typedef union bitfield_wfg_drive_i2c_top_ier_t {
    uint32_t value;
    struct {
        uint32_t command_frame_error : 1;
        uint32_t data_frame_error : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2c_top_ier_t;

typedef union bitfield_wfg_drive_i2c_top_icr_t {
    uint32_t value;
    struct {
        uint32_t command_frame_error : 1;
        uint32_t data_frame_error : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2c_top_icr_t;

typedef union bitfield_wfg_drive_i2c_top_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2c_top_module_info_t;

typedef union bitfield_wfg_drive_i2ct_top_ctrl_t {
    uint32_t value;
    struct {
        uint32_t en : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2ct_top_ctrl_t;

typedef union bitfield_wfg_drive_i2ct_top_cfg_t {
    uint32_t value;
    struct {
        uint32_t devid : 7;
        uint32_t addrsize : 1;
        uint32_t datasize : 2;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2ct_top_cfg_t;

typedef union bitfield_wfg_drive_i2ct_top_regcfg_t {
    uint32_t value;
    struct {
        uint32_t autoinc : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2ct_top_regcfg_t;

typedef union bitfield_wfg_drive_i2ct_top_regaddr_t {
    uint32_t value;
    struct {
        uint32_t addr : 16;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2ct_top_regaddr_t;

typedef union bitfield_wfg_drive_i2ct_top_regwdata_t {
    uint32_t value;
    struct {
        uint32_t data : 32;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2ct_top_regwdata_t;

typedef union bitfield_wfg_drive_i2ct_top_regwmask_t {
    uint32_t value;
    struct {
        uint32_t mask : 32;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2ct_top_regwmask_t;

typedef union bitfield_wfg_drive_i2ct_top_regrdata_t {
    uint32_t value;
    struct {
        uint32_t data : 32;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2ct_top_regrdata_t;

typedef union bitfield_wfg_drive_i2ct_top_regrmask_t {
    uint32_t value;
    struct {
        uint32_t mask : 32;
    } __attribute__ ((packed));
} bitfield_wfg_drive_i2ct_top_regrmask_t;

typedef union bitfield_wfg_drive_uart_top_ctrl_t {
    uint32_t value;
    struct {
        uint32_t en : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_uart_top_ctrl_t;

typedef union bitfield_wfg_drive_uart_top_cfg_t {
    uint32_t value;
    struct {
        uint32_t core_sel : 1;
        uint32_t txsize : 7;
        uint32_t cdiv : 24;
    } __attribute__ ((packed));
} bitfield_wfg_drive_uart_top_cfg_t;

typedef union bitfield_wfg_drive_uart_top_cfg2_t {
    uint32_t value;
    struct {
        uint32_t parity_sel : 2;
        uint32_t stop_sel : 2;
        uint32_t tx_delay : 16;
        uint32_t shift_dir : 1;
    } __attribute__ ((packed));
} bitfield_wfg_drive_uart_top_cfg2_t;

typedef union bitfield_wfg_drive_uart_top_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_wfg_drive_uart_top_module_info_t;

typedef union bitfield_wfg_record_mem_top_ctrl_t {
    uint32_t value;
    struct {
        uint32_t en : 1;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_ctrl_t;

typedef union bitfield_wfg_record_mem_top_cfg_t {
    uint32_t value;
    struct {
        uint32_t cnt : 8;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_cfg_t;

typedef union bitfield_wfg_record_mem_top_start_t {
    uint32_t value;
    struct {
        uint32_t val : 1;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_start_t;

typedef union bitfield_wfg_record_mem_top_stop_t {
    uint32_t value;
    struct {
        uint32_t val : 1;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_stop_t;

typedef union bitfield_wfg_record_mem_top_step_t {
    uint32_t value;
    struct {
        uint32_t val : 1;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_step_t;

typedef union bitfield_wfg_record_mem_top_addr_t {
    uint32_t value;
    struct {
        uint32_t val : 1;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_addr_t;

typedef union bitfield_wfg_record_mem_top_isr_t {
    uint32_t value;
    struct {
        uint32_t done : 1;
        uint32_t end : 1;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_isr_t;

typedef union bitfield_wfg_record_mem_top_ier_t {
    uint32_t value;
    struct {
        uint32_t done : 1;
        uint32_t end : 1;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_ier_t;

typedef union bitfield_wfg_record_mem_top_icr_t {
    uint32_t value;
    struct {
        uint32_t done : 1;
        uint32_t end : 1;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_icr_t;

typedef union bitfield_wfg_record_mem_top_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_wfg_record_mem_top_module_info_t;

typedef union bitfield_timer_ctrl_t {
    uint32_t value;
    struct {
        uint32_t en : 1;
    } __attribute__ ((packed));
} bitfield_timer_ctrl_t;

typedef union bitfield_timer_cfg_t {
    uint32_t value;
    struct {
        uint32_t auto_reload : 1;
        uint32_t reload_value : 24;
    } __attribute__ ((packed));
} bitfield_timer_cfg_t;

typedef union bitfield_timer_status_t {
    uint32_t value;
    struct {
        uint32_t count_value : 24;
    } __attribute__ ((packed));
} bitfield_timer_status_t;

typedef union bitfield_timer_clr_t {
    uint32_t value;
    struct {
        uint32_t clear : 1;
    } __attribute__ ((packed));
} bitfield_timer_clr_t;

typedef union bitfield_timer_isr_t {
    uint32_t value;
    struct {
        uint32_t timer_down : 1;
    } __attribute__ ((packed));
} bitfield_timer_isr_t;

typedef union bitfield_timer_ier_t {
    uint32_t value;
    struct {
        uint32_t timer_down : 1;
    } __attribute__ ((packed));
} bitfield_timer_ier_t;

typedef union bitfield_timer_icr_t {
    uint32_t value;
    struct {
        uint32_t timer_down : 1;
    } __attribute__ ((packed));
} bitfield_timer_icr_t;

typedef union bitfield_timer_module_info_t {
    uint32_t value;
    struct {
        uint32_t patch : 8;
        uint32_t minor : 8;
        uint32_t major : 8;
        uint32_t type : 1;
        uint32_t block : 4;
    } __attribute__ ((packed));
} bitfield_timer_module_info_t;


////////////////////////////////////////////
//********** module structs **************//
////////////////////////////////////////////

//! templated interconnect register offsets reflect the remapping done in the bridge
typedef struct wfg_interconnect_t {
    //drivers
    uint32_t wfg_drive_spi_top_0_select_0;
    uint32_t wfg_drive_spi_top_1_select_0;
    uint32_t reserved0[2];
    uint32_t wfg_drive_pat_top_0_select_0;
    uint32_t reserved1[3];
    uint32_t wfg_drive_i2c_top_0_select_0;
    uint32_t wfg_drive_i2c_top_1_select_0;
    uint32_t reserved2[2];
    uint32_t wfg_drive_uart_top_0_select_0;
    uint32_t wfg_drive_uart_top_1_select_0;
    //recorders
    uint32_t reserved3[46];
    uint32_t wfg_record_mem_top_0_select_0;
    uint32_t wfg_record_mem_top_1_select_0;
    uint32_t wfg_record_mem_top_2_select_0;
    uint32_t wfg_record_mem_top_3_select_0;
} wfg_interconnect_t;

// wfg_core_top
typedef struct wfg_core_top_t {
    bitfield_wfg_core_top_ctrl_t ctrl;
    bitfield_wfg_core_top_cfg_t cfg;
    uint32_t reserved0[61];
    bitfield_wfg_core_top_module_info_t module_info;
} wfg_core_top_t;

// wfg_pin_mux_top
typedef struct wfg_pin_mux_top_t {
    bitfield_wfg_pin_mux_top_output_sel_0_t output_sel_0;
    bitfield_wfg_pin_mux_top_output_sel_1_t output_sel_1;
    bitfield_wfg_pin_mux_top_output_sel_2_t output_sel_2;
    bitfield_wfg_pin_mux_top_output_sel_3_t output_sel_3;
    bitfield_wfg_pin_mux_top_pullup_sel_0_t pullup_sel_0;
    bitfield_wfg_pin_mux_top_pullup_sel_1_t pullup_sel_1;
    bitfield_wfg_pin_mux_top_pullup_sel_2_t pullup_sel_2;
    bitfield_wfg_pin_mux_top_pullup_sel_3_t pullup_sel_3;
    bitfield_wfg_pin_mux_top_input_sel_0_t input_sel_0;
    bitfield_wfg_pin_mux_top_input_sel_1_t input_sel_1;
    bitfield_wfg_pin_mux_top_input_sel_2_t input_sel_2;
    bitfield_wfg_pin_mux_top_input_sel_3_t input_sel_3;
    bitfield_wfg_pin_mux_top_mirror_output_t mirror_output;
    bitfield_wfg_pin_mux_top_mirror_pullup_t mirror_pullup;
    bitfield_wfg_pin_mux_top_mirror_input_t mirror_input;
    uint32_t reserved0[21];
    bitfield_wfg_pin_mux_top_pin_ir_rising_t pin_ir_rising;
    bitfield_wfg_pin_mux_top_pin_ir_falling_t pin_ir_falling;
    uint32_t reserved1[2];
    bitfield_wfg_pin_mux_top_isr_t isr;
    bitfield_wfg_pin_mux_top_ier_t ier;
    bitfield_wfg_pin_mux_top_icr_t icr;
    uint32_t reserved2[20];
    bitfield_wfg_pin_mux_top_module_info_t module_info;
} wfg_pin_mux_top_t;

// wfg_sysctrl_reg
typedef struct wfg_sysctrl_reg_t {
    bitfield_wfg_sysctrl_reg_product_t product;
    bitfield_wfg_sysctrl_reg_fpga_version_t fpga_version;
    bitfield_wfg_sysctrl_reg_gendate_t gendate;
    bitfield_wfg_sysctrl_reg_clk_speed_t clk_speed;
    bitfield_wfg_sysctrl_reg_soc_ctrl_t soc_ctrl;
    bitfield_wfg_sysctrl_reg_soc_status_t soc_status;
    uint32_t reserved0[2];
    bitfield_wfg_sysctrl_reg_reset_flags_t reset_flags;
    bitfield_wfg_sysctrl_reg_reset_clears_t reset_clears;
    uint32_t reserved1[30];
    bitfield_wfg_sysctrl_reg_isr_t isr;
    bitfield_wfg_sysctrl_reg_ier_t ier;
    bitfield_wfg_sysctrl_reg_icr_t icr;
    uint32_t reserved2[1];
    bitfield_wfg_sysctrl_reg_interrupt_mirror_t interrupt_mirror;
    uint32_t reserved3[18];
    bitfield_wfg_sysctrl_reg_module_info_t module_info;
} wfg_sysctrl_reg_t;


// wfg_stim_mem_top
typedef struct wfg_stim_mem_top_t {
    bitfield_wfg_stim_mem_top_ctrl_t ctrl;
    bitfield_wfg_stim_mem_top_cfg_t cfg;
    bitfield_wfg_stim_mem_top_start_t start;
    bitfield_wfg_stim_mem_top_stop_t stop;
    bitfield_wfg_stim_mem_top_step_t step;
    bitfield_wfg_stim_mem_top_addr_t addr;
    bitfield_wfg_stim_mem_top_gain_t gain;
    bitfield_wfg_stim_mem_top_offset_t offset;
    uint32_t reserved0[32];
    bitfield_wfg_stim_mem_top_isr_t isr;
    bitfield_wfg_stim_mem_top_ier_t ier;
    bitfield_wfg_stim_mem_top_icr_t icr;
    uint32_t reserved1[20];
    bitfield_wfg_stim_mem_top_module_info_t module_info;
} wfg_stim_mem_top_t;

// wfg_drive_spi_top
typedef struct wfg_drive_spi_top_t {
    bitfield_wfg_drive_spi_top_ctrl_t ctrl;
    bitfield_wfg_drive_spi_top_cfg_t cfg;
    bitfield_wfg_drive_spi_top_clkcfg_t clkcfg;
    bitfield_wfg_drive_spi_top_spi_len_t spi_len;
    bitfield_wfg_drive_spi_top_cs_high_time_t cs_high_time;
    bitfield_wfg_drive_spi_top_cs_active_delay_time_t cs_active_delay_time;
    uint32_t reserved0[57];
    bitfield_wfg_drive_spi_top_module_info_t module_info;
} wfg_drive_spi_top_t;

// wfg_drive_pat_top
typedef struct wfg_drive_pat_top_t {
    bitfield_wfg_drive_pat_top_ctrl_t ctrl;
    bitfield_wfg_drive_pat_top_cfg_t cfg;
    bitfield_wfg_drive_pat_top_patsel0_t patsel0;
    bitfield_wfg_drive_pat_top_patsel1_t patsel1;
    uint32_t reserved0[59];
    bitfield_wfg_drive_pat_top_module_info_t module_info;
} wfg_drive_pat_top_t;

// wfg_drive_i2c_top
typedef struct wfg_drive_i2c_top_t {
    bitfield_wfg_drive_i2c_top_ctrl_t ctrl;
    bitfield_wfg_drive_i2c_top_cfg_t cfg;
    bitfield_wfg_drive_i2c_top_clkcfg_t clkcfg;
    uint32_t reserved0[37];
    bitfield_wfg_drive_i2c_top_isr_t isr;
    bitfield_wfg_drive_i2c_top_ier_t ier;
    bitfield_wfg_drive_i2c_top_icr_t icr;
    uint32_t reserved1[20];
    bitfield_wfg_drive_i2c_top_module_info_t module_info;
} wfg_drive_i2c_top_t;

// wfg_drive_i2ct_top
typedef struct wfg_drive_i2ct_top_t {
    bitfield_wfg_drive_i2ct_top_ctrl_t ctrl;
    bitfield_wfg_drive_i2ct_top_cfg_t cfg;
    uint32_t reserved0[2];
    bitfield_wfg_drive_i2ct_top_regcfg_t regcfg;
    bitfield_wfg_drive_i2ct_top_regaddr_t regaddr;
    bitfield_wfg_drive_i2ct_top_regwdata_t regwdata;
    bitfield_wfg_drive_i2ct_top_regwmask_t regwmask;
    bitfield_wfg_drive_i2ct_top_regrdata_t regrdata;
    bitfield_wfg_drive_i2ct_top_regrmask_t regrmask;
} wfg_drive_i2ct_top_t;

// wfg_drive_uart_top
typedef struct wfg_drive_uart_top_t {
    bitfield_wfg_drive_uart_top_ctrl_t ctrl;
    bitfield_wfg_drive_uart_top_cfg_t cfg;
    bitfield_wfg_drive_uart_top_cfg2_t cfg2;
    uint32_t reserved0[60];
    bitfield_wfg_drive_uart_top_module_info_t module_info;
} wfg_drive_uart_top_t;

// wfg_record_mem_top
typedef struct wfg_record_mem_top_t {
    bitfield_wfg_record_mem_top_ctrl_t ctrl;
    bitfield_wfg_record_mem_top_cfg_t cfg;
    bitfield_wfg_record_mem_top_start_t start;
    bitfield_wfg_record_mem_top_stop_t stop;
    bitfield_wfg_record_mem_top_step_t step;
    bitfield_wfg_record_mem_top_addr_t addr;
    uint32_t reserved0[34];
    bitfield_wfg_record_mem_top_isr_t isr;
    bitfield_wfg_record_mem_top_ier_t ier;
    bitfield_wfg_record_mem_top_icr_t icr;
    uint32_t reserved1[20];
    bitfield_wfg_record_mem_top_module_info_t module_info;
} wfg_record_mem_top_t;

// timer
typedef struct wfg_timer_t {
    bitfield_timer_ctrl_t ctrl;
    bitfield_timer_cfg_t cfg;
    bitfield_timer_status_t status;
    uint32_t reserved0[1];
    bitfield_timer_clr_t clr;
    uint32_t reserved1[35];
    bitfield_timer_isr_t isr;
    bitfield_timer_ier_t ier;
    bitfield_timer_icr_t icr;
    uint32_t reserved2[20];
    bitfield_timer_module_info_t module_info;
} wfg_timer_t;

////////////////////////////////////////////
//********** module pointers *************//
////////////////////////////////////////////
extern volatile wfg_core_top_t* const wfg_core_top;
extern volatile wfg_pin_mux_top_t* const wfg_pin_mux_top;
extern volatile wfg_sysctrl_reg_t* const wfg_sysctrl_reg;
extern volatile wfg_stim_mem_top_t* const wfg_stim_mem_top_0;
extern volatile wfg_stim_mem_top_t* const wfg_stim_mem_top_1;
extern volatile wfg_stim_mem_top_t* const wfg_stim_mem_top_2;
extern volatile wfg_stim_mem_top_t* const wfg_stim_mem_top_3;
extern volatile wfg_drive_spi_top_t* const wfg_drive_spi_top_0;
extern volatile wfg_drive_spi_top_t* const wfg_drive_spi_top_1;
extern volatile wfg_drive_pat_top_t* const wfg_drive_pat_top_0;
extern volatile wfg_drive_i2c_top_t* const wfg_drive_i2c_top_0;
extern volatile wfg_drive_i2c_top_t* const wfg_drive_i2c_top_1;
extern volatile wfg_drive_i2ct_top_t* const wfg_drive_i2ct_top_0;
extern volatile wfg_drive_uart_top_t* const wfg_drive_uart_top_0;
extern volatile wfg_drive_uart_top_t* const wfg_drive_uart_top_1;
extern volatile wfg_record_mem_top_t* const wfg_record_mem_top_0;
extern volatile wfg_record_mem_top_t* const wfg_record_mem_top_1;
extern volatile wfg_record_mem_top_t* const wfg_record_mem_top_2;
extern volatile wfg_record_mem_top_t* const wfg_record_mem_top_3;
extern volatile wfg_timer_t* const wfg_timer;
//marker_template_end

#endif