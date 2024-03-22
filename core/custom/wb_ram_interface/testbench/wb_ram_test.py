import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles
from cocotbext.wishbone.driver import WishboneMaster, WBOp
from cocotb.utils import *

CLK_PER_SYNC = 300
SYSCLK = 100e6
RAMCLK = 50e6

@cocotb.test()
async def wb_ram_test(dut):
    cocotb.start_soon(Clock(dut.clk_i, (1/SYSCLK)*1e9, units="ns").start())
    cocotb.start_soon(Clock(dut.ram_clk_i, (1/RAMCLK)*1e9, units="ns").start())

    dut._log.info("Initialize and reset model")

    dut.rst_ni.value = 0
    await Timer(30, units='ns')
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1

    dram_data = open('dram.hex', 'r')
    iram_data = open('iram.hex', 'r')

    # write tests

    #wishbone master
    wbm = WishboneMaster(
        dut,
        "",
        dut.clk_i,
        timeout=10,
        width=32,
        signals_dict={
            "cyc":   "wb_cyc_i",
            "stb":   "wb_stb_i",
            "we":    "wb_wr_en_i",
            "adr":   "wb_addr_i",
            "datwr": "wb_wdata_i",
            "datrd": "wb_rdata_o",
            "ack":   "wb_ack_o"
        }
    )

    RAM_DEPTH = 0x1000
    IRAM_ADDR = 0x00030000
    DRAM_ADDR = 0x00032000

    idata = ''
    ddata = ''

    iram_addr = 0x0
    dram_addr = 0x0


    # write in all of memory

    for _ in range (0, int(RAM_DEPTH/4)):
        
        # perform an iram write
        idata = iram_data.readline().strip()
        await wbm.send_cycle([WBOp(IRAM_ADDR + iram_addr, int(idata,16))])
        assert dut.instr_dualport.ram[iram_addr].value == int(idata,16), f"IRAM WRITE ERROR -- Expected:{idata}\nWrote:{hex(dut.instr_dualport.ram[iram_addr].value)}"
        iram_addr = iram_addr + 0x1

        # perform a dram write
        ddata = dram_data.readline().strip()
        await wbm.send_cycle([WBOp(DRAM_ADDR + dram_addr, int(ddata,16))])
        assert dut.data_dualport.ram[dram_addr].value == int(ddata,16), f"DRAM WRITE ERROR -- Expected:{ddata}\nWrote:{hex(dut.instr_dualport.ram[dram_addr].value)}"
        dram_addr = dram_addr + 0x1


        # perform 2 iram writes
        idata = iram_data.readline().strip()
        await wbm.send_cycle([WBOp(IRAM_ADDR + iram_addr, int(idata,16))])
        assert dut.instr_dualport.ram[iram_addr].value == int(idata,16), f"IRAM WRITE ERROR -- Expected:{idata}\nWrote:{hex(dut.instr_dualport.ram[iram_addr].value)}"
        iram_addr = iram_addr + 0x1

        idata = iram_data.readline().strip()
        await wbm.send_cycle([WBOp(IRAM_ADDR + iram_addr, int(idata,16))])
        assert dut.instr_dualport.ram[iram_addr].value == int(idata,16), f"IRAM WRITE ERROR -- Expected:{idata}\nWrote:{hex(dut.instr_dualport.ram[iram_addr].value)}"
        iram_addr = iram_addr + 0x1


        # perform 2 dram writes
        ddata = dram_data.readline().strip()
        await wbm.send_cycle([WBOp(DRAM_ADDR + dram_addr, int(ddata,16))])
        assert dut.data_dualport.ram[dram_addr].value == int(ddata,16), f"DRAM WRITE ERROR -- Expected:{ddata}\nWrote:{hex(dut.instr_dualport.ram[dram_addr].value)}"
        dram_addr = dram_addr + 0x1

        ddata = dram_data.readline().strip()
        await wbm.send_cycle([WBOp(DRAM_ADDR + dram_addr, int(ddata,16))])
        assert dut.data_dualport.ram[dram_addr].value == int(ddata,16), f"DRAM WRITE ERROR -- Expected:{ddata}\nWrote:{hex(dut.instr_dualport.ram[dram_addr].value)}"
        dram_addr = dram_addr + 0x1

        # perform an iram write
        idata = iram_data.readline().strip()
        await wbm.send_cycle([WBOp(IRAM_ADDR + iram_addr, int(idata,16))])
        assert dut.instr_dualport.ram[iram_addr].value == int(idata,16), f"IRAM WRITE ERROR -- Expected:{idata}\nWrote:{hex(dut.instr_dualport.ram[iram_addr].value)}"
        iram_addr = iram_addr + 0x1

        # perform a dram write
        ddata = dram_data.readline().strip()
        await wbm.send_cycle([WBOp(DRAM_ADDR + dram_addr, int(ddata,16))])
        assert dut.data_dualport.ram[dram_addr].value == int(ddata,16), f"DRAM WRITE ERROR -- Expected:{ddata}\nWrote:{hex(dut.instr_dualport.ram[dram_addr].value)}"
        dram_addr = dram_addr + 0x1

    # reset file pointers
    dram_data.close()
    iram_data.close()
    dram_data = open('dram.hex', 'r')
    iram_data = open('iram.hex', 'r')


    RAM_DEPTH = 0x1000
    IRAM_ADDR = 0x00030000
    DRAM_ADDR = 0x00032000

    idata = ''
    ddata = ''

    iram_addr = 0x0
    dram_addr = 0x0

    for _ in range (0, int(RAM_DEPTH/4)):
        
        # perform an iram read
        idata = iram_data.readline().strip()
        await wbm.send_cycle([WBOp(IRAM_ADDR + iram_addr)])
        iram_addr = iram_addr + 0x1
        assert int(idata,16) == int(hex(dut.wb_rdata_o.value),0), f"IRAM READ ERROR -- Expected: {idata}\nReceived: {hex(dut.wb_rdata_o.value)}"

        # perform a dram read
        ddata = dram_data.readline().strip()
        await wbm.send_cycle([WBOp(DRAM_ADDR + dram_addr)])
        dram_addr = dram_addr + 0x1
        assert int(ddata,16) == int(hex(dut.wb_rdata_o.value),0), f"DRAM READ ERROR -- Expected: {ddata}\nReceived: {hex(dut.wb_rdata_o.value)}"

        # perform 2 iram reads
        idata = iram_data.readline().strip()
        await wbm.send_cycle([WBOp(IRAM_ADDR + iram_addr)])
        iram_addr = iram_addr + 0x1
        assert int(idata,16) == int(hex(dut.wb_rdata_o.value),0), f"IRAM READ ERROR -- Expected: {idata}\nReceived: {hex(dut.wb_rdata_o.value)}"

        idata = iram_data.readline().strip()
        await wbm.send_cycle([WBOp(IRAM_ADDR + iram_addr)])
        iram_addr = iram_addr + 0x1
        assert int(idata,16) == int(hex(dut.wb_rdata_o.value),0), f"IRAM READ ERROR -- Expected: {idata}\nReceived: {hex(dut.wb_rdata_o.value)}"


        # perform 2 dram reads
        ddata = dram_data.readline().strip()
        await wbm.send_cycle([WBOp(DRAM_ADDR + dram_addr)])
        dram_addr = dram_addr + 0x1
        assert int(ddata,16) == int(hex(dut.wb_rdata_o.value),0), f"DRAM READ ERROR -- Expected: {ddata}\nReceived: {hex(dut.wb_rdata_o.value)}"

        ddata = dram_data.readline().strip()
        await wbm.send_cycle([WBOp(DRAM_ADDR + dram_addr)])
        dram_addr = dram_addr + 0x1
        assert int(ddata,16) == int(hex(dut.wb_rdata_o.value),0), f"DRAM READ ERROR -- Expected: {ddata}\nReceived: {hex(dut.wb_rdata_o.value)}"

        # perform an iram read
        idata = iram_data.readline().strip()
        await wbm.send_cycle([WBOp(IRAM_ADDR + iram_addr)])
        iram_addr = iram_addr + 0x1
        assert int(idata,16) == int(hex(dut.wb_rdata_o.value),0), f"IRAM READ ERROR -- Expected: {idata}\nReceived: {hex(dut.wb_rdata_o.value)}"

        # perform a dram read
        ddata = dram_data.readline().strip()
        await wbm.send_cycle([WBOp(DRAM_ADDR + dram_addr)])
        dram_addr = dram_addr + 0x1
        assert int(ddata,16) == int(hex(dut.wb_rdata_o.value),0), f"DRAM READ ERROR -- Expected: {ddata}\nReceived: {hex(dut.wb_rdata_o.value)}"
