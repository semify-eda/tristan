#ifndef HAL_H
#define HAL_H
/*
    Hardware Abstraction Layer
*/

#define BASE_WB 0x00300000

// Direct access to wfg register based on wfg address map
#define WFG_REGISTER(block, type, id) ((*((volatile int*)(BASE_WB + block + type + id))))


// I2CT
#define BLOCK_DRIVER 0x00080000
#define TYPE_I2CT 0x00008000
#define ID_I2CT 0x00000000

// Pins
#define BLOCK_GEN_CONFIG 0x00040000 
#define TYPE_DRIVER_PIN_MUX 0x00006000
#define ID_PIN_MUX 0x00000000



#endif