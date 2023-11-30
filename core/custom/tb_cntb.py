# SPDX-FileCopyrightText: © 2022 Leo Moser <leo.moser@pm.me>
# SPDX-License-Identifier: GPL-3.0-or-later

import os
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.types import LogicArray

# Reset coroutine
async def reset_dut(rst_ni, duration_ns):
    rst_ni.value = 0
    await Timer(duration_ns, units="ns")
    rst_ni.value = 1
    rst_ni._log.info("Reset complete")

# Cntb software model
def cntb_soft(word, index):
    count = 0
    bit_word = (word >> index) & 1
    
    while (index > 0):
        index -= 1
        next_bit = (word >> index) & 1
        if (next_bit != bit_word):
            break
        count += 1

    return count

@cocotb.test()
async def randomized_test(dut):
    """ Randomized test for ctnb """

    # Start the clock
    c = Clock(dut.clk_i, 10, 'ns')
    await cocotb.start(c.start())

    # Reset values
    dut.start_i.value = 0
    dut.word_i.value = 0
    dut.index_i.value = 0
    
    # Execution will block until reset_dut has completed
    await reset_dut(dut.rst_ni, 50)
    
    # Wait for 10 clock cycles
    for i in range(10):
        await FallingEdge(dut.clk_i)
    
    for i in range(1000):

        # Get new input
        word = random.randint(0, 2**32-1) # Value
        index = random.randint(0, 31) # Index
        result = cntb_soft(word, index)
        
        # Start counting
        dut.start_i.value = 1
        dut.word_i.value = word
        dut.index_i.value = index
        
        # Wait for completion
        await RisingEdge(dut.done_o)
        dut.start_i.value = 0
        
        dut._log.info(f"Word: {dut.word_i.value}, Index: {dut.index_i.value}")
        dut._log.info(f"Result: {dut.result_o.value.integer}")
        
        assert(dut.result_o.value == result)
        
        # Wait for 2 clock cycles
        for i in range(2):
            await FallingEdge(dut.clk_i)

def test_runner():

    sim = "verilator"
    proj_path = Path(__file__).resolve().parent

    verilog_sources = [
        proj_path / "cntb.sv"
    ]
    defines = [
        ("COCOTB", 1)
    ]
    hdl_toplevel = "cntb"
    build_args=["--trace-fst", "--trace-structs"]

    runner = get_runner(sim)

    runner.build(
        verilog_sources=verilog_sources,
        defines=defines,
        build_args=build_args,
        hdl_toplevel=hdl_toplevel,
        always=True,
    )

    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module="tb_cntb,"
    )

if __name__ == "__main__":
    test_runner()
