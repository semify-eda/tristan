# Minimum-working-example firmware for the Tristan SoC.
#
# `make base`  -> build/base/firmware.mem   (pure software)
# `make ise`   -> build/ise/firmware.mem    (uses custom-instruction extension)
# `make dmem`  -> signals/dmem.mem          (unpacks signals/encoded.txt)
# `make`       -> all of the above

RV     ?= riscv32-unknown-elf-
PYTHON ?= python3

CFLAGS  := -mabi=ilp32 -march=rv32iazicsr -O3 -ffreestanding -nostdlib -flto \
           -Wall -Wextra -Wshadow -Wundef -Wpointer-arith -Wcast-qual \
           -Wcast-align -Wwrite-strings -Wredundant-decls -I include
LDFLAGS := -Wl,--build-id=none,-Bstatic,-T,sections.lds,--strip-debug
SOURCES := main/main.c src/rle.c start.S

.PHONY: all base ise dmem clean
all:  base ise dmem
base: build/base/firmware.mem
ise:  build/ise/firmware.mem
dmem: signals/dmem.mem

# ── base build (pure software RLE) ─────────────────────────────────────────────
build/base/firmware.elf: $(SOURCES) sections.lds
	@mkdir -p build/base
	$(RV)gcc $(CFLAGS) $(LDFLAGS) -o build/base/firmware.elf $(SOURCES) -lgcc
	$(RV)objdump -d build/base/firmware.elf > build/base/firmware.lst

build/base/firmware.bin: build/base/firmware.elf
	$(RV)objcopy -O binary build/base/firmware.elf build/base/firmware.bin

build/base/firmware.mem: build/base/firmware.bin
	$(PYTHON) scripts/makehex.py build/base/firmware.bin 2048 > build/base/firmware.mem

# ── ise build (hardware-accelerated RLE via custom instructions) ──────────────
build/ise/firmware.elf: $(SOURCES) sections.lds
	@mkdir -p build/ise
	$(RV)gcc $(CFLAGS) -DCUSTOM_EXT $(LDFLAGS) -o build/ise/firmware.elf $(SOURCES) -lgcc
	$(RV)objdump -d build/ise/firmware.elf > build/ise/firmware.lst

build/ise/firmware.bin: build/ise/firmware.elf
	$(RV)objcopy -O binary build/ise/firmware.elf build/ise/firmware.bin

build/ise/firmware.mem: build/ise/firmware.bin
	$(PYTHON) scripts/makehex.py build/ise/firmware.bin 2048 > build/ise/firmware.mem

# ── dmem image — unpacks signals/encoded.txt into a .mem file ─────────────────
signals/dmem.mem: signals/encoded.txt scripts/generate_dmem.py
	$(PYTHON) scripts/generate_dmem.py signals/dmem.mem signals/encoded.txt

clean:
	rm -rf build/ signals/dmem.mem scripts/__pycache__/
