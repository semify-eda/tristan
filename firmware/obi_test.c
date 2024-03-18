#include "util.h"
#include "obi_test.h"

// this test is intended to be viewed/verified through a testbench or waveform viewer
void write_i2c(unsigned int i2c_data)
{
    BASE_I2C = i2c_data;
}

volatile unsigned int read_i2c()
{
    return BASE_I2C;
}

// this test is intended to be viewed/verified through a testbench or waveform viewr
void write_pinmux(volatile unsigned int pinmux_data)
{
    BASE_PINMUX = pinmux_data;
}

volatile unsigned int read_pinmux()
{
    return BASE_PINMUX;
}

void obi_test()
{
    volatile unsigned int i2c_data = 0xFEEDBEEF;
    volatile unsigned int pinmux_data = 0xDAD5FADE;

    //test I2C interface over WB
    write_i2c(i2c_data);
    volatile unsigned int i2c_read = read_i2c();

    if(i2c_read != 0xCAFEBABE) 
        //test failed case
        pinmux_data = 0xdeadbeef;

    //test pinmux interface over wb
    write_pinmux(pinmux_data);
    volatile unsigned int pinmux_read = read_pinmux();

    if(pinmux_read != 0xFEEDDEED)
        //test failed case
        pinmux_data = 0xdeadbeef;
    else
        //test passed
        pinmux_data = 0x00000000;
    write_pinmux(pinmux_data);

    write_i2c(0xabcd0123);
    write_i2c(0x1234abcd);
    if(read_i2c() != 0x11111111)
    {
        write_i2c(0xdeadbeef);
    }

    read_pinmux();
    read_pinmux();
}