from SmartWaveAPI import SmartWave
from sys import argv, exit

try:
    path = argv[1]
except:
    # exit("Must enter a path to the firmware...")
    path = "firmware_blink.mem"

try:
    firmware = open(path, "r")
except:
    exit("Firmware not found...")

SOC_CTRL_REG = 0x48010      # TODO: import these values from a header file
IRAM_BASE_ADDR = 0xC2000
DRAM_BASE_ADDR = 0xC0000

with SmartWave().connect() as sw:
    # assert reset SoC and block instruction fetch

    sw.writeFPGARegister(SOC_CTRL_REG, 0b00)
    r = sw.readFPGARegister(SOC_CTRL_REG)

    addr = 0xC2000

    # write the firmware into IRAM
    for line in firmware:
        # write a line from the firmware to the RAM
        l = line.strip()
        h = int(l, 16)
        sw.writeFPGARegister(addr, h)
        t = sw.readFPGARegister(addr)
        assert t == h, f"Error loading SoC firmware..."
        addr = addr + 0x1;
    

    # reset SoC and enable instruction fetch
    sw.writeFPGARegister(SOC_CTRL_REG, 0b11)
    r = sw.readFPGARegister(SOC_CTRL_REG)

    print("SoC firmware loaded successfully...")
