import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
from cocotb.utils import *
import random

@cocotb.test()
async def shifter_test(dut):


    dut.d.value = 0
    dut.shift_amount.value = 0
    dut.rotate_en.value = 0

    await Timer(1, units='ps')
    assert(dut.q.value == 0)

    for _ in range(1000):
        await Timer(1, units='ns')
        d = random.randrange(2**32)
        shift_amount = random.randrange(2**5)
        rotate_en    = random.randrange(2)

        dut.d.value = d
        dut.shift_amount.value = shift_amount
        dut.rotate_en.value = rotate_en

        await Timer(1, units='ps')
        if(rotate_en):
          assert(dut.q.value == ((d + (d << 32)) >> shift_amount) & (2**32-1))
        else:
          assert(dut.q.value == d >> shift_amount)


