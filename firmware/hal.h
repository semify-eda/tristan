#ifndef HAL_H
#define HAL_H
/*
    Hardware Abstraction Layer
*/
#include <stdint.h>

/********************** WISHBONE START *********************/

/// Read Data from external module
#define _MODR(mod)          *((volatile int*)(mod.addr))

// Write Data to external module
#define _MODW(mod, data)    *((volatile int*)(mod.addr)) = data

// External Module address granularity
typedef union module_t{
    uint32_t addr;
    struct {
        uint32_t reserved0  : 2;
        uint32_t reg        : 8;
        uint32_t id         : 5;
        uint32_t type       : 4;
        uint32_t block      : 3;
        uint32_t chip_sel   : 1;
        uint32_t reserved1  : 9;
    } __attribute__ ((packed));
} module_t;

///////////////////////////
//      Block
///////////////////////////
enum CHIP_SEL {
    CS_INTERNAL = 0,
    CS_EXTERNAL = 1
};

enum BLOCK {
    BLOCK_TIMER      = 0x7,
    // RESERVED      = 0x6,
    BLOCK_RECORDER   = 0x5,
    BLOCK_DRIVER     = 0x4,
    BLOCK_STIMULI    = 0x3,
    BLOCK_GEN_CONFIG = 0x2,
    BLOCK_MEMORY     = 0x1
    // RESERVED      = 0x0
};

///////////////////////////
//      Type
///////////////////////////
enum TYPE {
    TYPE_I2CT        = 0x4,
    TYPE_PIN_MUX     = 0x3,
    TYPE_SOC_TIMER   = 0x0
};

///////////////////////////
//      ID
///////////////////////////
enum ID {
    ID_I2CT          = 0x0,
    ID_PIN_MUX       = 0x0,
    ID_TIMER0        = 0x0
};

///////////////////////////
//      Registers
///////////////////////////
enum I2CT_REG {
    I2CT_CTRL        = 0x00,
    I2CT_CFG         = 0x04,
    I2CT_REGCFG      = 0x10,
    I2CT_REGADDR     = 0x14,
    I2CT_REGWDATA    = 0x18,
    I2CT_REGWMASK    = 0x1C,
    I2CT_REGRDATA    = 0x20,
    I2CT_REGRMASK    = 0x24
};

enum TIMER_REG {
    TIMER_CTRL      = 0x00,
    TIMER_CFG       = 0x04,
    TIMER_STATUS    = 0x08,
    TIMER_CLR       = 0x10,
    TIMER_ISR       = 0xA0,
    TIMER_IER       = 0xA4,
    TIMER_ICR       = 0xA8,
    TIMER_MOD_INFO  = 0xFC
};

enum PINMUX_REG {
    PINMUX_OUTPUT_SEL_0     = 0x00,
    PINMUX_OUTPUT_SEL_1     = 0x04,
    PINMUX_OUTPUT_SEL_2     = 0x08,
    PINMUX_OUTPUT_SEL_3     = 0x0C,
    PINMUX_PULLUP_SEL_0     = 0x10,
    PINMUX_PULLUP_SEL_1     = 0x14,
    PINMUX_PULLUP_SEL_2     = 0x18,
    PINMUX_PULLUP_SEL_3     = 0x1C,
    PINMUX_INPUT_SEL_0      = 0x20,
    PINMUX_INPUT_SEL_1      = 0x24,
    PINMUX_INPUT_SEL_2      = 0x28,
    PINMUX_INPUT_SEL_3      = 0x2C,
    PINMUX_MIRROR_OUTPUT    = 0x30,
    PINMUX_MIRROR_PULLUP    = 0x34,
    PINMUX_MIRROR_INPUT     = 0x38,
    PINMUX_PIN_IR_RISING    = 0x90,
    PINMUX_PIN_IR_FALLING   = 0x94,
    PINMUX_ISR              = 0xA0,
    PINMUX_IER              = 0xA4,
    PINMUX_ICR              = 0xA8,
    PINMUX_MODULE_INFO      = 0xFC
};

enum PINMUX_MOD_SEL {
    PINMUX_IN_MOD_I2CT_SDA      = 0x2,
    PINMUX_IN_MOD_I2CT_SCL      = 0x3,
    PINMUX_OUT_MOD_I2CT_SDA     = 0x5,
    PINMUX_OUT_MOD_I2CT_SCL     = 0x6,
    PINMUX_OUT_MOD_I2CT_WR_UPDATE = 0x4,
    PINMUX_OUT_MOD_I2CT_PDWN_SDA = 0x3
};

typedef struct acc_t {
    uint16_t x_acc;
    uint16_t y_acc;
    uint16_t z_acc;
    uint16_t x_gyro;
    uint16_t y_gyro;
    uint16_t z_gyro;
    uint8_t  x_dir;
    uint8_t  y_dir;
    uint8_t  z_dir;
} acc_t;

enum direction_t {
    UP,
    DOWN
};

/********************** WISHBONE END   *********************/

#define TIMER_FREQ          100000000
#define TIMER_IRQ_FREQ      10
#define TIMER_RELOAD_VAL    (TIMER_FREQ / TIMER_IRQ_FREQ)

// timer
void configure_timer(module_t timer, uint32_t cfg);
uint8_t timer_irq(module_t timer);
void ack_timer(module_t timer);

// i2ct
void initialize_i2ct(module_t i2ct);
void update_x_accel(module_t i2ct, uint16_t val);
void update_y_accel(module_t i2ct, uint16_t val);
void update_z_accel(module_t i2ct, uint16_t val);
void update_x_gyro(module_t i2ct, uint16_t val);
void update_y_gyro(module_t i2ct, uint16_t val);
void update_z_gyro(module_t i2ct, uint16_t val);

// pinmux
void configure_pinmux(module_t pinmux, uint8_t sda_pin, uint8_t scl_pin);

// debugging function
void set_led(module_t pinmux, uint8_t value);
#define LED_ON  0x2
#define LED_OFF 0x1

#endif