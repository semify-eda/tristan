#include "util.h"
#include "obi_test.h"
#include "hal.h"


void obi_test()
{

    module_t i2ct = {
        .chip_sel  = CS_EXTERNAL,
        .block     = BLOCK_DRIVER,
        .type      = TYPE_I2CT,
        .id        = ID_I2CT,
        .reg       = I2CT_REGWDATA,
        .reserved0 = 0,
        .reserved1 = 0
    };

    module_t pinmux = {
        .chip_sel  = CS_EXTERNAL,
        .block     = BLOCK_GEN_CONFIG,
        .type      = TYPE_PIN_MUX,
        .id        = ID_PIN_MUX,
        .reg       = 0,
        .reserved0 = 0,
        .reserved1 = 0
    };

    volatile uint32_t i2c_data = 0xFEEDBEEF;
    volatile uint32_t pinmux_data = 0xDAD5FADE;

    //test I2C interface over WB
    _MODW(i2ct, i2c_data);
    volatile uint32_t i2c_read = _MODR(i2ct);

    if(i2c_read != 0xCAFEBABE) 
        //test failed case
        pinmux_data = 0xdeadbeef;

    //test pinmux interface over wb
    _MODW(pinmux, pinmux_data);
    volatile uint32_t pinmux_read = _MODR(pinmux);

    if(pinmux_read != 0xFEEDDEED)
        //test failed case
        pinmux_data = 0xdeadbeef;
    else
        //test passed
        pinmux_data = 0x00000000;
    _MODW(pinmux, pinmux_data);

    _MODW(i2ct, 0xabcd0123);
    _MODW(i2ct, 0x1234abcd);

    if(_MODR(i2ct) != 0x11111111)
    {
        _MODW(i2ct, 0xdeadbeef);
    }

    _MODR(pinmux);
    _MODR(pinmux);
}