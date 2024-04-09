#include "util.h"
#include "csr.h"
#include "instr.h"
#include "cntb_test.h"
#include "rle_test.h"
#include "hal.h"
#include "obi_test.h"

void main(void);

static module_t i2ct = {
    .chip_sel   = CS_EXTERNAL,
    .block      = BLOCK_DRIVER,
    .type       = TYPE_I2CT,
    .id         = ID_I2CT,
    .reg        = 0,
    .reserved0  = 0,
    .reserved1  = 0
};

static module_t pinmux = {
    .chip_sel   = CS_EXTERNAL,
    .block      = BLOCK_GEN_CONFIG,
    .type       = TYPE_PIN_MUX,
    .id         = ID_PIN_MUX,
    .reg        = 0,
    .reserved0  = 0,
    .reserved1  = 0
};

static module_t timer = {
    .chip_sel   = CS_EXTERNAL,
    .block      = BLOCK_TIMER,
    .type       = 0,
    .id         = 0,
    .reg        = 0,
    .reserved0  = 0,
    .reserved1  = 0
};

void main(void)
{
    // configure the pinmux so that the I2CT SDA is mapped to pin 8 and SCL to pin 9
    configure_pinmux(pinmux, 0x8, 0x9);
    
    // Set the timer reload value and turn on auto reload
    timer.reg = TIMER_CFG;
    _MODW(timer, (TIMER_RELOAD_VAL << 8) + 0x1);

    // Enable the timer
    timer.reg = TIMER_CTRL;
    _MODW(timer, 0x1);

    // initialize i2ct
    initialize_i2ct(i2ct);

    acc_t acc = {
        .x_acc = 0xFFFF,
        .y_acc = 0x0000,
        .z_acc = 0x0000,
        .x_dir = UP,
        .y_dir = DOWN,
        .z_dir = DOWN
    };

    set_led(pinmux, LED_ON);

    uint8_t s = 0;
    while (1) 
    {
        // every 100 ms, update the I2CT registers
        if(timer_irq(timer))
        {
            ack_timer(timer);
            if(acc.x_dir == UP)
            {
                if(acc.x_acc == 0xFFFF)  acc.x_dir = DOWN;
                else                    acc.x_acc += 0x1111;
            } 
            else if (acc.x_dir == DOWN) 
            {
                if(acc.x_acc == 0x0000) acc.x_dir = UP;
                else                    acc.x_acc -= 0x1111;
            }

            if(acc.y_dir == UP)
            {
                if(acc.y_acc == 0xFFFF)  acc.y_dir = DOWN;
                else                    acc.y_acc += 0x1111;
            } 
            else if (acc.y_dir == DOWN) 
            {
                if(acc.y_acc == 0x0000) acc.y_dir = UP;
                else                    acc.y_acc -= 0x1111;
            }

            if(acc.z_dir == UP)
            {
                if(acc.z_acc == 0xFFFF)  acc.z_dir = DOWN;
                else                    acc.z_acc += 0x1111;
            } 
            else if (acc.z_dir == DOWN) 
            {
                if(acc.z_acc == 0x0000) acc.z_dir = UP;
                else                    acc.z_acc -= 0x1111;
            }

            // update the register values
            update_x_accel(i2ct, acc.x_acc);
            update_y_accel(i2ct, acc.y_acc);
            update_z_accel(i2ct, acc.z_acc);

            s++;
            if(s % 2 == 0) set_led(pinmux, LED_ON);
            else           set_led(pinmux, LED_OFF);
        }
    }
}

