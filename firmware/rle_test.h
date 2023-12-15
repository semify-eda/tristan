#ifndef RLE_TEST_H
#define RLE_TEST_H

#include "rle/data.h"
#include "rle/rle.h"
#include "instr.h"
#include "util.h"

void rle_test(void);
void prepare_sample(int *samp_data);
void prepare_byte(uint8_t *data, int *sample_data);

#endif