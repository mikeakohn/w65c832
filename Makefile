
NAKEN_INCLUDE=../naken_asm/include
PROGRAM=w65c832
SOURCE= \
  src/$(PROGRAM).v \
  src/memory_bus.v \
  src/peripherals.v \
  src/addressing_mode.v \
  src/ram.v \
  src/reg_mode.v \
  src/rom.v \
  src/sd_card.v \
  src/spi.v \
  src/uart.v

# flash_rom was tested and working, but now replaced with an SD card.
NOT_USED= \
  src/flash_rom.v

default:
	yosys -q \
	  -p "synth_ice40 -top $(PROGRAM) -json $(PROGRAM).json" $(SOURCE)
	nextpnr-ice40 -r \
	  --hx8k \
	  --json $(PROGRAM).json \
	  --package cb132 \
	  --asc $(PROGRAM).asc \
	  --opt-timing \
	  --pcf icefun.pcf
	icepack $(PROGRAM).asc $(PROGRAM).bin

tang_nano:
	yosys -q \
	  -D TANG_NANO \
	  -p "read_verilog $(SOURCE); synth_gowin -json $(PROGRAM).json -family gw2a"
	nextpnr-himbaechel -r \
	  --json $(PROGRAM).json \
	  --write $(PROGRAM)_pnr.json \
	  --freq 27 \
	  --vopt family=GW2A-18C \
	  --vopt cst=tangnano20k.cst \
	  --device GW2AR-LV18QN88C8/I7
	gowin_pack -d GW2A-18C -o $(PROGRAM).fs $(PROGRAM)_pnr.json

old:
	yosys -q \
	  -p "synth_gowin -top $(PROGRAM) -json $(PROGRAM).json -family gw2a" \
	  $(SOURCE)

program:
	iceFUNprog $(PROGRAM).bin

bootloader:
	naken_asm -l -type bin -o rom.bin test/bootloader.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

blink:
	naken_asm -l -type bin -o rom.bin test/blink.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

lcd:
	naken_asm -l -type bin -o rom.bin -I$(NAKEN_INCLUDE) test/lcd.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

winbond_lcd:
	naken_asm -l -type bin -o rom.bin -I$(NAKEN_INCLUDE) test/winbond_lcd.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

winbond_data:
	naken_asm -l -type bin -o data_c000.bin -I$(NAKEN_INCLUDE) test/winbond_data.asm

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

serlcd:
	naken_asm -l -type bin -o rom.bin test/serlcd.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

serlcd_tang_nano:
	naken_asm -l -type bin -o rom.bin test/serlcd_tang_nano.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

sd_test:
	naken_asm -l -type bin -o rom.bin test/sd_test.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

extra_modes:
	naken_asm -l -type bin -o rom.bin test/extra_modes.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

multiple_move:
	naken_asm -l -type bin -o rom.bin test/multiple_move.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

qa_1:
	naken_asm -l -type bin -o rom.bin -I test -I qa qa/test_1.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

qa_move:
	naken_asm -l -type bin -o rom.bin -I test -Iqa qa/test_move.asm
	python3 tools/bin2txt.py rom.bin > rom.txt

clean:
	@rm -f $(PROGRAM).bin $(PROGRAM).json $(PROGRAM).asc *.lst
	@rm -f $(PROGRAM)_pnr.json
	@rm -f blink.bin test_alu.bin test_shift.bin test_subroutine.bin
	@rm -f button.bin
	@echo "Clean!"

