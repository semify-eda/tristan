#© 2024 semify <office@semify-eda.com>

import cocotb 
from cocotb.utils import get_sim_time
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

SYSCLK = 100e6

@cocotb.test()
async def test_simple_timer(dut):
    cocotb.start_soon(Clock(dut.clk_i, (1/SYSCLK)*1e9, units="ns").start())

    dut._log.info("Initialize and reset model")

    # Reset
    dut.rst_n_i.value = 0
    await Timer(10, units="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_n_i = 1    

    # Set enable high
    dut.en_i.value = 1
    dut.load_i = 0

    # Run for ten clock cycles
    for _ in range(10):
        await RisingEdge(dut.clk_i)

    # Set enable low
    dut.en_i.value = 0

    # Run for three clock cycles
    for _ in range(3):
        await RisingEdge(dut.clk_i) 


    # Reset
    dut.rst_n_i.value = 0
    await Timer(10, units="ns")
    await RisingEdge(dut.clk_i)
    dut.rst_n_i = 1      

    # Set enable high
    dut.en_i.value = 1
    
    # Set load data value
    dut.load_i = 1
    dut.d_i = 3
    await RisingEdge(dut.clk_i)
    dut.load_i = 0

    # Run for five clock cycles
    for _ in range(10):
        await RisingEdge(dut.clk_i)

