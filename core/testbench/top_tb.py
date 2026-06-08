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

async def _wb_write_monitor(dut):
    """Print each WB write transaction at the cycle where cyc+stb+we+ack
    are all high.  Captures address/data at the handshake edge, which is
    when the master is still presenting them on the bus."""
    while True:
        await RisingEdge(dut.wfg_clk)
        try:
            if (int(dut.cyc_wb.value)  == 1 and
                int(dut.stb_wb.value)  == 1 and
                int(dut.wr_en_wb.value) == 1 and
                int(dut.ack_wb.value)  == 1):
                adr = int(dut.addr_wb.value)
                dat = int(dut.data_o_wb.value)
                dut._log.info(f"[MMIO] W @ 0x{adr:08x}  data=0x{dat:08x}")
        except ValueError:
            # Signals are X during reset; ignore.
            pass


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
                            "datrd": "default_dat",
                            "ack": "default_ack"
                        })

    # Print WB writes as they happen (cocotbext-wishbone's _recvQ samples at
    # the wrong cycle for our timing, so we use a direct signal monitor).
    cocotb.start_soon(_wb_write_monitor(dut))

    await Timer(400, units='us')

    wbs.log.info("WishboneSlave captured %d transactions" % len(wbs._recvQ))
