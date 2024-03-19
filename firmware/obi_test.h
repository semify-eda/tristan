#ifndef OBI_TEST_H
#define OBI_TEST_H

void                  write_pinmux(volatile unsigned int pinmux_data);
void                  write_i2c(volatile unsigned int i2c_data);
volatile unsigned int read_pinmux();
volatile unsigned int read_i2c();

void                  obi_test();

#endif