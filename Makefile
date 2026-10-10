# usage: make PHASE=p1_blink [prog|flash]   (flash = persist to SPI flash)
PHASE ?= p1_blink
B     := build/$(PHASE)
SRC   := $(filter-out %/tb.v,$(wildcard rtl/*.v phases/$(PHASE)/*.v))
FW    := phases/$(PHASE)/fw
HEX   := $(if $(wildcard $(FW)),build/fw.hex)
DEV   := GW1NR-LV9QN88PC6/I5
FAM   := GW1N-9C

all: $(B).fs

$(B).json: $(SRC) $(HEX) | build
	yosys -q -p "read_verilog $(SRC); synth_gowin -top top -json $@"

$(B)_pnr.json: $(B).json tangnano9k.cst
	nextpnr-himbaechel --json $< --write $@ --device $(DEV) --vopt family=$(FAM) --vopt cst=tangnano9k.cst

$(B).fs: $(B)_pnr.json
	gowin_pack -d $(FAM) -o $@ $<

# firmware: ELF -> raw binary -> one 32-bit hex word per line
build/fw.elf: $(wildcard $(FW)/*) | build
	riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostdlib -T $(FW)/link.ld -o $@ $(FW)/start.S $(FW)/main.c

build/fw.hex: build/fw.elf
	riscv64-unknown-elf-objcopy -O binary $< build/fw.bin
	od -An -v -tx4 -w4 build/fw.bin | tr -d ' ' > $@

build:
	mkdir -p build

prog: $(B).fs
	openFPGALoader -b tangnano9k $<

flash: $(B).fs
	openFPGALoader -b tangnano9k -f $<

sim: $(HEX) | build
	iverilog -o build/tb.vvp rtl/*.v phases/$(PHASE)/*.v && vvp build/tb.vvp

clean:
	rm -rf build

.PHONY: all prog flash sim clean
