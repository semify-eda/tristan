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
    uint32_t cfg = 0x6a;
    // write to configuration register
    _MODW(i_cfg, cfg);

    // set all the acceleration values to 0 initially
    update_x_accel(i2ct, 0x0000);
    update_y_accel(i2ct, 0x0000);
    update_z_accel(i2ct, 0x0000);

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