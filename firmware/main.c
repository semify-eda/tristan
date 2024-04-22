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
    //// configure the pinmux so that the I2CT SDA is mapped to pin 8 and SCL to pin 9
    // configure_pinmux(pinmux, 0x8, 0x9);
    // configure pinmux

    // write sda into pinmux output pin 8
    wfg_pin_mux_top->output_sel_2._8 = WFG_PINMUX_OUT_WFG_DRIVE_I2CT_TOP_0_SDA;
    
    // // write scl into pinmux output pin 9
    wfg_pin_mux_top->output_sel_2._9 = WFG_PINMUX_OUT_WFG_DRIVE_I2C_TOP_0_SCL;

    // // write scl into pinmux input pin 8
    wfg_pin_mux_top->input_sel_2._8 = WFG_PINMUX_IN_WFG_DRIVE_I2CT_TOP_0_SCL;

    // // write sda into pinmux input pin 9
    wfg_pin_mux_top->input_sel_2._9 = WFG_PINMUX_IN_WFG_DRIVE_I2CT_TOP_0_SDA;


    // // Set the timer reload value and turn on auto reload
    // timer.reg = TIMER_CFG;
    // _MODW(timer, (TIMER_RELOAD_VAL << 8) + 0x1);

    // // Enable the timer
    // timer.reg = TIMER_CTRL;
    // _MODW(timer, 0x1);

    // configure the timer
    wfg_timer->cfg.reload_value = TIMER_RELOAD_VAL;
    wfg_timer->cfg.auto_reload = 0x1;

    wfg_timer->ctrl.en = 0x1;

    // // initialize i2ct
    // initialize_i2ct(i2ct);

    // configure i2ct
    wfg_drive_i2ct_top_0->ctrl.en = 0x1;
    wfg_drive_i2ct_top_0->cfg.devid = 0x6a;

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


    // acc_t acc = {
    //     .x_acc  = 0x7FFF,
    //     .y_acc  = 0x0000,
    //     .z_acc  = 0x0000,
    //     .x_gyro = 0x7FFF,
    //     .y_gyro = 0x0000,
    //     .z_gyro = 0x0000,
    //     .x_dir  = UP,
    //     .y_dir  = DOWN,
    //     .z_dir  = DOWN
    // };

    uint8_t s = 0;
    while (1) 
    {
        // every 100 ms, update the I2CT registers
        if(wfg_timer->isr.timer_down == 1)
        {
            wfg_timer->icr.timer_down = 1;
            // if(acc.x_dir == UP)
            // {
            //     if(acc.x_acc == 0xFFFF)  
            //     {
            //         acc.x_dir = DOWN;
            //     }
            //     else
            //     {
            //         acc.x_acc += 0x0111;
            //         acc.x_gyro += 0x0111;
            //     }
            // } 
            // else if (acc.x_dir == DOWN) 
            // {
            //     if(acc.x_acc == 0x0000) 
            //     {
            //         acc.x_dir = UP;
            //     }
            //     else
            //     {
            //         acc.x_acc -= 0x0111;
            //         acc.x_gyro -= 0x0111;
            //     }
            // }

            // if(acc.y_dir == UP)
            // {
            //     if(acc.y_acc == 0xFFFF)
            //     {
            //         acc.y_dir = DOWN;
            //     }
            //     else
            //     {
            //         acc.y_acc += 0x0111;
            //         acc.y_gyro += 0x0111;
            //     }
            // } 
            // else if (acc.y_dir == DOWN) 
            // {
            //     if(acc.y_acc == 0x0000) 
            //     {
            //         acc.y_dir = UP;
            //     }
            //     else 
            //     {
            //         acc.y_acc -= 0x0111;
            //         acc.y_gyro -= 0x0111;
            //     }
            // }

            // if(acc.z_dir == UP)
            // {
            //     if(acc.z_acc == 0xFFFF)
            //     {
            //         acc.z_dir = DOWN;
            //     }
            //     else
            //     {
            //         acc.z_acc += 0x0111;
            //         acc.z_gyro += 0x0111;
            //     } 
            // } 
            // else if (acc.z_dir == DOWN) 
            // {
            //     if(acc.z_acc == 0x0000) 
            //     {
            //         acc.z_dir = UP;
            //     }
            //     else
            //     {
            //         acc.z_acc -= 0x0111;
            //         acc.z_gyro -= 0x0111;
            //     }
            // }

            // // update the register values
            // update_x_accel(i2ct, acc.x_acc);
            // update_y_accel(i2ct, acc.y_acc);
            // update_z_accel(i2ct, acc.z_acc);

            s++;
            if(s % 2 == 0)
            {
                // toggle led on
                wfg_pin_mux_top->output_sel_2._10 = LED_ON;
            } 
            else 
            {
                // toggle led off
                wfg_pin_mux_top->output_sel_2._10 = LED_OFF;
            }
        }
        // s++;
    }
}

