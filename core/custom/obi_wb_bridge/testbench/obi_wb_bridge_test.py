import cocotb
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
from cocotbext.wishbone.driver import WishboneMaster, WBOp
from cocotbext.wishbone.monitor import WishboneSlave
from cocotb.utils import *
import random

CLK_PER_SYNC = 300
SYSCLK = 25e6
WBCLK  = 100e6

async def run_wbm(wbm, address=0, count=1000, max_ns_between_transactions=10):
  for i in range(count):
    if random.randint(0,2):
      await wbm.send_cycle([WBOp(address, i)])
    else:
      await wbm.send_cycle([WBOp(address)])

    await Timer(random.randint(0, max_ns_between_transactions), units='ns')


@cocotb.test()
async def obi_wb_bridge_test(dut):
    cocotb.start_soon(Clock(dut.core_clk, (1/SYSCLK)*1e9, units="ns").start())
    cocotb.start_soon(Clock(dut.wfg_clk, (1/WBCLK)*1e9, units="ns").start())

    dut._log.info("Initialize and reset model")


    dut.core_rst_n.value = 0
    await Timer(30, units='ns')
    await RisingEdge(dut.core_clk)
    dut.core_rst_n.value = 1

    # Wishbone Master 0
    wbm0 = WishboneMaster(dut,
                          "wbm0",
                          dut.wfg_clk,
                          width=32,   # size of data bus
                          timeout=1000, # in clock cycle number
                          signals_dict={"cyc":  "cyc_i",
                                        "stb":  "stb_i",
                                        "we":   "we_i",
                                        "adr":  "adr_i",
                                        "datwr":"dat_i",
                                        "datrd":"dat_o",
                                        "ack":  "ack_o" })

    # wishbone slave 
    wbs = WishboneSlave(dut,
                        "",
                        dut.wfg_clk,
                        width=32, # size of data bus
                        signals_dict={
                            "cyc": "cyc_wb",
                            "stb": "default_slave_stb",
                            "we": "wr_en_wb",
                            "adr": "addr_wb",
                            "datwr": "data_o_wb",
                            "datrd": "default_dat",
                            "ack": "default_ack"
                        },
                        datgen = None)


    await RisingEdge(dut.wbm1_cyc_i)

    m0 = cocotb.start_soon(run_wbm(wbm=wbm0, address=0, count=50, max_ns_between_transactions=200))

    for _ in range(2):
        await Timer(50, units='us')
        dut._log.info("50us")

   
    wbs.log.info("received %d transactions" % len(wbs._recvQ))
    for transaction in wbs._recvQ:
        wbs.log.info(f"{[f'@{hex(v.adr)}r{hex(v.datrd)}w{hex(0 if v.datwr is None else v.datwr)}' for v in transaction]}")
    



    await m0
