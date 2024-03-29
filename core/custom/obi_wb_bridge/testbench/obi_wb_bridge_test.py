import cocotb
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
from cocotbext.wishbone.driver import WishboneMaster, WBOp
from cocotbext.wishbone.monitor import WishboneSlave
from cocotb.utils import *

CLK_PER_SYNC = 300
SYSCLK = 25e6
WBCLK  = 100e6

@cocotb.test()
async def obi_wb_bridge_test(dut):
    cocotb.start_soon(Clock(dut.core_clk, (1/SYSCLK)*1e9, units="ns").start())
    cocotb.start_soon(Clock(dut.wfg_clk, (1/WBCLK)*1e9, units="ns").start())

    dut._log.info("Initialize and reset model")

    dut.core_rst_n.value = 0
    await Timer(30, units='ns')
    await RisingEdge(dut.core_clk)
    dut.core_rst_n.value = 1

    # wishbone slave 
    wbs = WishboneSlave(dut,
                        "",
                        dut.wfg_clk,
                        width=32, # size of data bus
                        signals_dict={
                            "cyc": "cyc_wb",
                            "stb": "stb_wb",
                            "we": "wr_en_wb",
                            "adr": "addr_wb",
                            "datwr": "data_o_wb",
                            "datrd": "data_i_wb",
                            "ack": "ack_wb"
                        },
                        datgen = iter([0xcafebabe, 0xfeeddeed, 0x11111111, 0x22222222, 0x33333333])
                        )
    
    await Timer(190, units='us')

    wbs.log.info("received %d transactions" % len(wbs._recvQ))
    for transaction in wbs._recvQ:
        wbs.log.info(f"{[f'@{hex(v.adr)}r{hex(v.datrd)}w{hex(0 if v.datwr is None else v.datwr)}' for v in transaction]}")
