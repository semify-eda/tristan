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

def cntb_soft(value, index):
    count = 0
    bit_value = (value >> index) & 1
    
    while (index > 0):
        index -= 1
        next_bit = (value >> index) & 1
        if (next_bit != bit_value):
            break
        count += 1

    return count

@cocotb.test()
async def simple_test(dut):
    """ Simple test for modular_multiplier """

    # Start the clock
    c = Clock(dut.clk_i, 10, 'ns')
    await cocotb.start(c.start())

    # Reset values
    dut.start_i.value = 0
    dut.rs0_i.value = 0
    dut.rs1_i.value = 0
    
    # Execution will block until reset_dut has completed
    await reset_dut(dut.rst_ni, 50)
    
    # Wait for 10 clock cycles
    for i in range(10):
        await FallingEdge(dut.clk_i)
    
    for i in range(1000):

        # Get new input
        value = random.randint(0, 2**32-1) # Value
        index = random.randint(0, 31) # Index
        result = cntb_soft(value, index)
        
        # Start counting
        dut.start_i.value = 1
        dut.rs0_i.value = value
        dut.rs1_i.value = index
        
        # Wait for completion
        await RisingEdge(dut.done_o)
        dut.start_i.value = 0
        
        dut._log.info(f"Value: {dut.rs0_i.value}, Index: {index}")
        dut._log.info(f"Result: {dut.rd_o.value.integer}")
        
        assert(dut.rd_o.value == result)
        
        # Wait for 2 clock cycles
        for i in range(2):
            await FallingEdge(dut.clk_i)

def test_runner():

    sim = "verilator"
    proj_path = Path(__file__).resolve().parent

    verilog_sources = [
        proj_path / "include/custom_instr_pkg.sv",
        proj_path / "cntb2.sv"
    ]
    defines = [
        ("COCOTB", 1)
    ]
    hdl_toplevel = "cntb2"
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
        test_module="tb_cntb2,"
    )

if __name__ == "__main__":
    test_runner()
