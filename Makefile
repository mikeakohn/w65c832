
PROGRAM=w65c832
SOURCE= \
  src/$(PROGRAM).v \
  src/flash_rom.v \
  src/memory_bus.v \
  src/peripherals.v \
  src/addressing_mode.v \
  src/ram.v \
  src/reg_mode.v \
  src/rom.v \
  src/spi.v \
  src/uart.v

default:
	yosys -q -p "synth_ice40 -top $(PROGRAM) -json $(PROGRAM).json" $(SOURCE)
	nextpnr-ice40 -r --hx8k --json $(PROGRAM).json --package cb132 --asc $(PROGRAM).asc --opt-timing --pcf icefun.pcf
	icepack $(PROGRAM).asc $(PROGRAM).bin

program:
	iceFUNprog $(PROGRAM).bin

blink:
	naken_asm -l -type bin -o rom.bin test/blink.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

lcd:
	naken_asm -l -type bin -o rom.bin test/lcd.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

jml_blink:
	naken_asm -l -type bin -o rom.bin test/jml_blink.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

jsr_abs_blink:
	naken_asm -l -type bin -o rom.bin test/jsr_abs_blink.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

simple:
	naken_asm -l -type bin -o rom.bin test/simple.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

read_winbond:
	naken_asm -l -type bin -o rom.bin test/read_winbond.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

uart:
	naken_asm -l -type bin -o rom.bin test/uart.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

clean:
	@rm -f $(PROGRAM).bin $(PROGRAM).json $(PROGRAM).asc *.lst
	@rm -f blink.bin test_alu.bin test_shift.bin test_subroutine.bin
	@rm -f button.bin
	@echo "Clean!"

