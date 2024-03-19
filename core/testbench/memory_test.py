import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
from cocotb.utils import *

"""
The purpose of this testbench is to ensure the integrity of the firmware loaded in RAM,
to check that it all fits, and to ensure proper addressability of all available RAM. 
"""

CLK_PER_SYNC = 300
SYSCLK = 100e6

@cocotb.test()
async def memory_test(dut):
    cocotb.start_soon(Clock(dut.clk, (1/SYSCLK)*1e9, units="ns").start())

    dut._log.info("Initialize and reset model")

    # open the firmware file
    firmware = open('../../firmware/firmware.hex', 'r')

    await ClockCycles(dut.clk, 10)

    for i in range(0x0, 0x4000, 0x4):

        expectedData = firmware.readline().strip()

        # set the address of the ram
        address = 0x02000000 + i
        dut.ram_addr.value = address

        # wait for the rising edge
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        recievedData = hex(dut.ram_data.value)[2:]

        assert recievedData.lstrip("0") == expectedData.lstrip("0"), f"Error at address: {hex(address)}. Expected: {expectedData}, Received: {recievedData}"
        
        await RisingEdge(dut.clk)

