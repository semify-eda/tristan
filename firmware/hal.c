#include "hal.h"
#include <stdint.h>

void configure_timer(module_t timer, uint32_t cfg)
{
    _MODW(timer, cfg);
}

uint8_t timer_irq(module_t timer)
{
    static volatile module_t t;

    t = timer;
    t.reg = TIMER_ISR;
    return _MODR(t); // return Interrupt Service flag
}

void ack_timer(module_t timer)
{
    static volatile module_t t;

    t = timer;
    t.reg = TIMER_ICR;
    _MODW(t,0x1);   // clear the interrupt flag
}

void initialize_i2ct(module_t i2ct)
{ 

    
    // configure the i2ct as an IMU
    static volatile module_t i_cfg;
    static volatile module_t i_addr;
    static volatile module_t i_wdata;
    static volatile module_t i_ctrl;
    static volatile module_t i_wmask;

    i_ctrl = i2ct;
    i_cfg = i2ct;
    i_addr = i2ct;
    i_wdata = i2ct;
    i_wmask = i2ct;

    i_ctrl.reg = I2CT_CTRL;
    i_cfg.reg = I2CT_CFG;
    i_addr.reg = I2CT_REGADDR;
    i_wdata.reg = I2CT_REGWDATA;
    i_wmask.reg = I2CT_REGWMASK;


    // enable i2ct
    _MODW(i_ctrl, 0x1);

    // 1 data byte, 1 address byte, 0x6a device id
    uint32_t cfg = 0x6a << 1;
    // write to configuration register
    _MODW(i_cfg, cfg);

    // set all the acceleration values to 0 initially
    update_x_accel(i2ct, 0x0000);
    update_y_accel(i2ct, 0x0000);
    update_z_accel(i2ct, 0x0000);
    update_x_gyro(i2ct, 0x0000);
    update_y_gyro(i2ct, 0x0000);
    update_z_gyro(i2ct, 0x0000);


    // do a write to the WHO_AM_I register
    _MODW(i_addr, 0x0f);
    _MODW(i_wdata, 0x6b);

    //write to the i2ct mem mask
    i_addr.reg = 
    _MODW(i_wmask, 0xff);


}

void update_x_accel(module_t i2ct, uint16_t val)
{
    static volatile module_t addr;
    static volatile module_t wdata;

    addr = i2ct;
    addr.reg = I2CT_REGADDR;

    wdata = i2ct;
    wdata.reg = I2CT_REGWDATA;

    //write 8 LSB
    _MODW(addr, 0x28);
    _MODW(wdata, (val & 0x00FF));

    //write 8 MSB
    _MODW(addr, 0x29);
    _MODW(wdata, (val >> 8));

}

void update_y_accel(module_t i2ct, uint16_t val)
{
    static volatile module_t addr;
    static volatile module_t wdata;

    addr = i2ct;
    addr.reg = I2CT_REGADDR;

    wdata = i2ct;
    wdata.reg = I2CT_REGWDATA;

    //write 8 LSB
    _MODW(addr, 0x2A);
    _MODW(wdata, (val & 0x00FF));

    //write 8 MSB
    _MODW(addr, 0x2B);
    _MODW(wdata, (val >> 8));
}

void update_z_accel(module_t i2ct, uint16_t val)
{
    static volatile module_t addr;
    static volatile module_t wdata;

    addr = i2ct;
    addr.reg = I2CT_REGADDR;

    wdata = i2ct;
    wdata.reg = I2CT_REGWDATA;

    //write 8 LSB
    _MODW(addr, 0x2C);
    _MODW(wdata, (val & 0x00FF));

    //write 8 MSB
    _MODW(addr, 0x2D);
    _MODW(wdata, (val >> 8));
}

void update_x_gyro(module_t i2ct, uint16_t val)
{
    static volatile module_t addr;
    static volatile module_t wdata;

    addr = i2ct;
    addr.reg = I2CT_REGADDR;

    wdata = i2ct;
    wdata.reg = I2CT_REGWDATA;

    //write 8 LSB
    _MODW(addr, 0x22);
    _MODW(wdata, (val & 0x00FF));

    //write 8 MSB
    _MODW(addr, 0x23);
    _MODW(wdata, (val >> 8));
}

void update_y_gyro(module_t i2ct, uint16_t val)
{
    static volatile module_t addr;
    static volatile module_t wdata;

    addr = i2ct;
    addr.reg = I2CT_REGADDR;

    wdata = i2ct;
    wdata.reg = I2CT_REGWDATA;

    //write 8 LSB
    _MODW(addr, 0x24);
    _MODW(wdata, (val & 0x00FF));

    //write 8 MSB
    _MODW(addr, 0x25);
    _MODW(wdata, (val >> 8));
}

void update_z_gyro(module_t i2ct, uint16_t val)
{
    static volatile module_t addr;
    static volatile module_t wdata;

    addr = i2ct;
    addr.reg = I2CT_REGADDR;

    wdata = i2ct;
    wdata.reg = I2CT_REGWDATA;

    //write 8 LSB
    _MODW(addr, 0x26);
    _MODW(wdata, (val & 0x00FF));

    //write 8 MSB
    _MODW(addr, 0x27);
    _MODW(wdata, (val >> 8));
}

void configure_pinmux(module_t pinmux, uint8_t sda_pin, uint8_t scl_pin)
{
    // for now, ignore sda pin and scl pin parameters, since they would
    // change which registers we need to write into
    module_t p = pinmux;
    uint32_t val;
    uint32_t write;

    /********** MAP OUTPUTS **********/
    p.reg = PINMUX_OUTPUT_SEL_2;

    // read the value from the pinmux register
    val = _MODR(p);

    // clear the entries for pins 8 and 9
    val = 0x0;

    // write wr_update to pin 11
    write = PINMUX_OUT_MOD_I2CT_WR_UPDATE << 24;
    val = val + write;

    // write sda pdwn to pin 10
    write = PINMUX_OUT_MOD_I2CT_PDWN_SDA << 16;
    val = val + write;

    // write scl into pin 9
    write = PINMUX_OUT_MOD_I2CT_SCL << 8;

    // write sda into pin 8
    write = write + PINMUX_OUT_MOD_I2CT_SDA;

    // update the pinmux register values
    val = val + write;
    _MODW(p, val);


    /********** MAP INPUTS **********/
    p.reg = PINMUX_INPUT_SEL_2;

    // read the value from the pimux register
    val = _MODR(p);

    // clear the entries for pins 8 and 9
    val = val & 0xFFFF0000;

    // write scl into pin 9
    write = PINMUX_IN_MOD_I2CT_SCL << 8;

    // write sda into pin 8
    write = write + PINMUX_IN_MOD_I2CT_SDA;

    // update the pinmux register values
    val = val + write;
    _MODW(p, val);

    

    /********** MAP PULLUPS **********/
    p.reg = PINMUX_PULLUP_SEL_2;

    // real the value from the pinmux pullup register
    val = _MODR(p);

    // clear the entires for pins 8 and 9
    val = val & 0xFFFF0000;

    // enable both the pullups
    val = val + 0x00000101;

    // write back the changes
    _MODW(p, val);
    
}

void set_led(module_t pinmux, uint8_t value)
{
    static module_t p;
    p = pinmux;
    p.reg = PINMUX_OUTPUT_SEL_2;

    uint32_t rval = _MODR(p);
    uint32_t w;

    w = value << 16;
    rval = rval & 0xFF00FFFF;
    rval = rval + w;

    _MODW(p, rval);

}

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
const wfg_interconnect_t* wfg_interconnect = (wfg_interconnect_t*) MOD_WFG_INTERCONNECT_BASE;
const wfg_core_top_t* wfg_core_top = (wfg_core_top_t*) MOD_WFG_CORE_TOP_BASE;
const wfg_pin_mux_top_t* wfg_pin_mux_top = (wfg_pin_mux_top_t*) MOD_WFG_PIN_MUX_TOP_BASE;
const wfg_sysctrl_reg_t* wfg_sysctrl_reg = (wfg_sysctrl_reg_t*) MOD_WFG_SYSCTRL_REG_BASE;
const wfg_stim_mem_top_t* wfg_stim_mem_top_0 = (wfg_stim_mem_top_t*) MOD_WFG_STIM_MEM_TOP_0_BASE;
const wfg_stim_mem_top_t* wfg_stim_mem_top_1 = (wfg_stim_mem_top_t*) MOD_WFG_STIM_MEM_TOP_1_BASE;
const wfg_stim_mem_top_t* wfg_stim_mem_top_2 = (wfg_stim_mem_top_t*) MOD_WFG_STIM_MEM_TOP_2_BASE;
const wfg_stim_mem_top_t* wfg_stim_mem_top_3 = (wfg_stim_mem_top_t*) MOD_WFG_STIM_MEM_TOP_3_BASE;
const wfg_drive_spi_top_t* wfg_drive_spi_top_0 = (wfg_drive_spi_top_t*) MOD_WFG_DRIVE_SPI_TOP_0_BASE;
const wfg_drive_spi_top_t* wfg_drive_spi_top_1 = (wfg_drive_spi_top_t*) MOD_WFG_DRIVE_SPI_TOP_1_BASE;
const wfg_drive_pat_top_t* wfg_drive_pat_top_0 = (wfg_drive_pat_top_t*) MOD_WFG_DRIVE_PAT_TOP_0_BASE;
const wfg_drive_i2c_top_t* wfg_drive_i2c_top_0 = (wfg_drive_i2c_top_t*) MOD_WFG_DRIVE_I2C_TOP_0_BASE;
const wfg_drive_i2c_top_t* wfg_drive_i2c_top_1 = (wfg_drive_i2c_top_t*) MOD_WFG_DRIVE_I2C_TOP_1_BASE;
const wfg_drive_i2ct_top_t* wfg_drive_i2ct_top_0 = (wfg_drive_i2ct_top_t*) MOD_WFG_DRIVE_I2CT_TOP_0_BASE;
const wfg_drive_uart_top_t* wfg_drive_uart_top_0 = (wfg_drive_uart_top_t*) MOD_WFG_DRIVE_UART_TOP_0_BASE;
const wfg_drive_uart_top_t* wfg_drive_uart_top_1 = (wfg_drive_uart_top_t*) MOD_WFG_DRIVE_UART_TOP_1_BASE;
const wfg_record_mem_top_t* wfg_record_mem_top_0 = (wfg_record_mem_top_t*) MOD_WFG_RECORD_MEM_TOP_0_BASE;
const wfg_record_mem_top_t* wfg_record_mem_top_1 = (wfg_record_mem_top_t*) MOD_WFG_RECORD_MEM_TOP_1_BASE;
const wfg_record_mem_top_t* wfg_record_mem_top_2 = (wfg_record_mem_top_t*) MOD_WFG_RECORD_MEM_TOP_2_BASE;
const wfg_record_mem_top_t* wfg_record_mem_top_3 = (wfg_record_mem_top_t*) MOD_WFG_RECORD_MEM_TOP_3_BASE;
const timer_t* timer = (timer_t*) MOD_TIMER_BASE;

//marker_template_end