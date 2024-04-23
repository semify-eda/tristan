#include "util.h"
#include "csr.h"
#include "instr.h"
#include "cntb_test.h"
#include "rle_test.h"
#include "hal.h"
#include "obi_test.h"

void main(void);


void main(void)
{
    // configure the pinmux so that the I2CT SDA is mapped to pin 8 and SCL to pin 9, and enable the pullups

    wfg_pin_mux_top->output_sel_2.value = (LED_ON << 16) + (WFG_PINMUX_OUT_WFG_DRIVE_I2CT_TOP_0_SCL << 8) + WFG_PINMUX_OUT_WFG_DRIVE_I2CT_TOP_0_SDA;
    wfg_pin_mux_top->input_sel_2.value = (WFG_PINMUX_IN_WFG_DRIVE_I2CT_TOP_0_SCL << 8) + WFG_PINMUX_IN_WFG_DRIVE_I2CT_TOP_0_SDA;
    wfg_pin_mux_top->pullup_sel_2.value = (1 << 8) + 1;

    // configure the timer
    wfg_timer->cfg.value = (TIMER_RELOAD_VAL << 8) + 1;
    wfg_timer->ctrl.en = 0x1;

    // configure i2ct
    wfg_drive_i2ct_top_0->ctrl.en = 0x1;
    wfg_drive_i2ct_top_0->cfg.value = 0x6a << 1;

    // initialize all acceleration values
    wfg_drive_i2ct_top_0->regaddr.addr = 0x28;
    wfg_drive_i2ct_top_0->regwdata.data = 0x01;

    wfg_drive_i2ct_top_0->regaddr.addr = 0x29;
    wfg_drive_i2ct_top_0->regwdata.data = 0x02;

    wfg_drive_i2ct_top_0->regaddr.addr = 0x2a;
    wfg_drive_i2ct_top_0->regwdata.data = 0x03;

    wfg_drive_i2ct_top_0->regaddr.addr = 0x2b;
    wfg_drive_i2ct_top_0->regwdata.data = 0x04;

    wfg_drive_i2ct_top_0->regaddr.addr = 0x2c;
    wfg_drive_i2ct_top_0->regwdata.data = 0x05;

    wfg_drive_i2ct_top_0->regaddr.addr = 0x2d;
    wfg_drive_i2ct_top_0->regwdata.data = 0x06;

    // do a write to the WHO_AM_I register
    wfg_drive_i2ct_top_0->regaddr.addr = 0x0f;
    wfg_drive_i2ct_top_0->regwdata.data = 0x6b;

    // write to the i2ct mem mask
    wfg_drive_i2ct_top_0->regwmask.mask = 0xff;


    uint8_t s = 0;
    uint32_t mask = 0;

    while (1) 
    {
        // s++;
        // every 100 ms, update the I2CT registers
        if(wfg_timer->isr.timer_down == 1)
        {
            wfg_timer->icr.timer_down = 1;
            
            s++;
            if(s % 2 == 0)
            {
                // toggle led on
                mask = wfg_pin_mux_top->output_sel_2.value & 0x0000ffff;
                wfg_pin_mux_top->output_sel_2.value = mask + (LED_ON << 16);
            } 
            else 
            {
                // toggle led off
                mask = wfg_pin_mux_top->output_sel_2.value & 0x0000ffff;
                wfg_pin_mux_top->output_sel_2.value = mask + (LED_OFF << 16);
            }
        }
    }
}

