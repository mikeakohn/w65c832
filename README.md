W65C832 In An FPGA
==================

This is a W65C832 (32 bit 6502) CPU implemented in an FPGA.

https://www.mikekohn.net/micro/w65c832_fpga.php

Test code is assembled with the naken_asm assembler.

Registers
=========

* A (8/16/32 bit accumulator)
* X (8/16/32 bit index x)
* Y (8/16/32 bit index y)

Note: If A is in 16 bit mode and X is 8 bit mode, using an
instruction such as TXA (transfer X to A) will only tranfer the lower 8
bits of X to A clearing the top bits of A. Most other instructions
will leave the upper bits of the registers alone.

There's also
* SP  (16 bit stack pointer)
* PC  (16 bit program counter)
* DR  (16 bit Direct Register to extend the zero page)
* DRB (8 bit Data Bank Register to extend data moves to 24 bit)
* PRB (8 bit Program Bank Register to extend PC to 24 bit)

Flags (Status Register)
=======================

P = { N, V, M, X, D, I, Z, C }

* N negative (set if bit 7 of the result is set)
* V overflow
* M
* X / break
* D decimal
* I interrupt disable
* Z zero     (set if ALU result is 0)
* C carry    (set if ALU result requires bit 8)

Outside of the status register there is an E8 flag (added for 65C816)
and a new E16 flag (added for 65C832).

Overflow is set if adding two positives comes out negative or adding
two negatives comes out positive.

Decimal mode is not currently supported.

Register / Memory Fetch Sizes
=============================

M flag sets the size of A and memory fetches.
X flag sets the size of X and Y.

E16 and E8 change the emulation mode. At startup, all 4 flags are 1.

    // E16  E8   M   X    A    X,Y    Mode
    //  0    0   0   0   16    32     W65C832 Native
    //  0    0   0   1   16     8     W65C832 Native
    //  0    0   1   0    8    32     W65C832 Native
    //  0    0   1   1    8     8     W65C832 Native
    //  0    1   0   0   32    32     W65C832 Native
    //  0    1   0   1   32     8     W65C832 Native
    //  0    1   1   0    8    32     W65C832 Native
    //  0    1   1   1    8     8     W65C832 Native
    //  1    0   0   0   16    16     W65C816 Emulation
    //  1    0   0   1   16     8     W65C816 Emulation
    //  1    0   1   0    8    16     W65C816 Emulation
    //  1    0   1   1    8     8     W65C816 Emulation
    //  1    1   1  BRK   8     8     W65C02  Emulation

To switch from W6502 emulation to W65C816 emulation:

    clc
    xce

While in W65C816 mode, the xce (Exchange C with E8) instruction becomes
the xfe (Exchange C with E8 and Exchange V with E16) instruction. So
to change to 65C832 mode while in W65C816 mode:

    clc
    clv
    xce

Addressing Modes
================

Zero Page / Direct Page
-----------------------

    Format: OPCODE, zp_address

    8 bit mode:     ea = zp_address
    32/16 bit mode: ea = zp_address + dr

Absolute
--------

    Format: OPCODE, address_low, address_high

    8 bit mode:     ea = { address_high, address_low }
    32/16 bit mode: ea = { pbr, address_high, address_low }

Absolute, X
-----------

    Format: OPCODE, address_low, address_high

    8 bit mode:     ea = { address_high, address_low } + X[7:0]
    32/16 bit mode: ea = { pbr, address_high, address_low } + X[7:0]
    32/16 bit mode: ea = { pbr, address_high, address_low } + X[15:0]
    32/16 bit mode: ea = { pbr, address_high, address_low } + X[31:0]

In 8 bit mode, X and Y will add only 8 bit to the absolute 16 bit address.
In 32/16 mode, X and Y is added to the absolute 24 bit address calculated
by the program bank register (pbr) along with the 2 bytes from the opcode.
The size of X and Y (8 bits, 16 bits, 32 bits) depends on the current mode
of the CPU based on flag_x and flag_e16.

Indirect
--------

    lda (zp + dr, X)
    lda (zp + dr), Y

    ea = [ zp + dr + X ]
    ea = [ zp + dr ] + Y

Instructions
============

From https://llx.com/Neil/a2/opcodes.html

Bit structure is:

    aaabbbcc

cc = 00
-------

|aaa|opcode|
|---|------|
|000|
|001|bit
|010|jmp
|011|jmp (abs)
|100|sty
|101|ldy
|110|cpy
|111|cpx

|bbb|addressing mode|
|---|---------------|
|000|immediate
|001|zero page
|010|
|011|absolute
|100|
|101|zero page, X
|110|
|111|absolute, X

Branches have the format xxy 100 00

|xx|flag|
|--|---------------|
|00|negative
|01|overflow
|10|carry
|11|zero

    bpl 0x10 - 000 100 00 Branch on Result Plus
    bmi 0x30 - 001 100 00 Branch on Result Minus
    bvc 0x50 - 010 100 00 Branch on Overflow Clear
    bvs 0x70 - 011 100 00 Branch on Overflow Set
    bcc 0x90 - 100 100 00 Branch on Carry Clear
    bcs 0xb0 - 101 100 00 Branch on Carry Set
    bne 0xd0 - 110 100 00 Branch on Result not Zero
    beq 0xf0 - 111 100 00 Branch on Result Zero

Other Instructions

    brk 0x00 - 000 000 00  Break (Halt)
    jsr 0x20 - 001 000 00  Jump Subroutine
    rti 0x40 - 010 000 00  Return From Interrupt
    rts 0x60 - 011 000 00  Return From Subroutine
    bra 0x80 - 100 000 00  Branch Always [65C816]

    php 0x08 - 000 010 00  Push Status Register
    plp 0x28 - 001 010 00  Pull Status Register
    pha 0x48 - 010 010 00  Push A
    pla 0x68 - 011 010 00  Pull A
    dey 0x88 - 100 010 00  Decrement Y
    tay 0xa8 - 101 010 00  Transfer A To Y
    iny 0xc8 - 110 010 00  Increment Y
    inx 0xe8 - 111 010 00  Increment X

    jmp 0x6c - 011 011 00  Jump (abs)

    clc 0x18 - 000 110 00  Clear Carry
    sec 0x38 - 001 110 00  Set Carry
    cli 0x58 - 010 110 00  Clear Interrupt Disable
    sei 0x78 - 011 110 00  Set Interrupt Disable
    tya 0x98 - 100 110 00  Transfer Y to A
    clv 0xb8 - 101 110 00  Clear Overflow
    cld 0xd8 - 110 110 00  Clear Decimal
    sed 0xf8 - 111 110 00  Set Decimal

    jmp 0x7c - 011 111 00  Jump (abs, x)
    jsr 0xfc - 111 111 00  Jump Subroutine (abs, x)

65C816 Instructions

    mvp 0x44 - 010 001 00  Block Move Positive
    mvn 0x54 - 010 101 00  Block Move Negative
    pei 0xd4 - 110 101 00  Push Effective Indirect Address
    pea 0xf4 - 111 101 00  Push Effective Absolute Address
    jml 0x5c - 010 111 00  Jump Long Absolute (jmp.l)
    jml 0xdc - 110 111 00  Jump Long Indirect

    stz 0x64 - 011 001 00  Store Zero Direct Page
    stz 0x74 - 011 101 00  Store Zero Direct Page,X
    stz 0x9c - 100 111 00  Store Zero Absolute

    tsb 0x04 - 000 001 00  Test and Set Bit Direct Page
    tsb 0x0c - 000 011 00  Test and Set Bit Absolute
    trb 0x14 - 000 101 00  Test and Reset Bit Direct Page
    trb 0x1c - 000 111 00  Test and Reset Bit Absolute

cc = 01
-------

|aaa|opcode|
|---|------|
|000|ora
|001|and
|010|eor
|011|adc
|100|sta
|101|lda
|110|cmp
|111|sbc

|bbb|addressing mode|
|---|---------------|
|000|(zero page, X)
|001|zero page
|010|immediate
|011|absolute
|100|(zero page), Y
|101|zero page, X
|110|absolute, Y
|111|absolute, X

    bit 0x89 - 100 010 01  Bit test #imm (bit #imm).

cc = 10
-------

|aaa|opcode|
|---|------|
|000|asl
|001|rol
|010|lsr
|011|ror
|100|stx
|101|ldx
|110|dec
|111|inc

|bbb|addressing mode|
|---|---------------|
|000|immediate
|001|zero page
|010|accumulator
|011|absolute
|100|(dp)    (adc, and, cmp, eor, lda, ora, sbc, sta)
|101|zero page, X
|110|
|111|absolute, X

Other Instructions

    txa 0x8a - 100 010 10  Transfer X to A
    tax 0xaa - 101 010 10  Transfer A to X
    dex 0xca - 110 010 10  Decrement X
    nop 0xea - 111 010 10  No Operation

    inc 0x1a - 000 110 10  Increment A (65C816)
    dec 0x3a - 001 110 10  Decrement A (65C816)
    phy 0x5a - 010 110 10  Push Y (65C816)
    ply 0x7a - 011 110 10  Pull Y (65C816)
    txs 0x9a - 100 110 10  Transfer X to SP
    tsx 0xba - 101 110 10  Transfer SP to X
    phx 0xda - 110 110 10  Push X (65C816)
    plx 0xfa - 111 110 10  Pull X (65C816)

Other 65C816 Instructions

    cop 0x02 - 000 000 10  Coprocessor Instruction (goes into error state)
    jsl 0x22 - 001 000 10  Jump Subroutine Long
    wdm 0x42 - 010 000 10  Reserved
    per 0x62 - 011 000 10  Push Effective Program Counter Relative Address
    brl 0x82 - 100 000 10  Branch Always Long
               101
    rep 0xc2 - 110 000 10  Reset Status Bits
    sep 0xe2 - 111 000 10  Set Processor Status Bits

    stz 0x9e - 100 111 10  Store Zero Absolute,X

cc = 11
-------

65C816 Instructions

|aaa|opcode|
|---|------|
|000|ora
|001|and
|010|eor
|011|adc
|100|sta
|101|lda
|110|cmp
|111|sbc

|bbb|addressing mode|
|---|---------------|
|000|sr, s (2 bytes, stack relative)
|001|[dp] (2 bytes, direct page indirect long)
|010|
|011|absolute24 (4 bytes)
|100|(sr, s), y (2 bytes, stack relative indirect)
|101|[dp], Y (2 bytes, direct page indirect long indexed)
|110|
|111|absolute24, x (4 bytes, absolute long indexed)

Other 65C816 Instructions

    phd 0x0b - 000 010 11  Push Direct Register
    pld 0x2b - 001 010 11  Pull Direct Register
    phk 0x4b - 010 010 11  Push Program Bank Register
    rtl 0x6b - 011 010 11  Return from Subroutine Long
    phb 0x8b - 100 010 11  Push Data Bank Register
    plb 0xab - 101 010 11  Pull Data Bank Register
    wai 0xcb - 110 010 11  Wait for Interrupt
    xba 0xeb - 111 010 11  Exchange AH and AL

    tcs 0x1b - 000 110 11  Transfer A to SP
    tsc 0x3b - 001 110 11  Transfer SP to A
    tcd 0x5b - 010 110 11  Transfer A to Direct Register
    tdc 0x7b - 011 110 11  Transfer Direct Regsiter To A
    txy 0x9b - 100 110 11  Transfer X to Y
    tyx 0xbb - 101 110 11  Transfer Y to X
    stp 0xdb - 110 110 11  Stop the Clock
    xce 0xfb - 111 110 11  Exchange Carry and Emulation Bits
    xfe 0xfb - 111 110 11  Exchange Carry and Emulation Bits

65C832 Notes
------------

The mvn/mvp instructions originally had the syntax:

    mvn {src bits [23:16]}, {dst bits [23:16]}

When the instruction finishes, {dst bits [23:16]} moves into dbr.

In 32 bit mode the mvn and mvp instructions don't have operands and
Index X (src) and Index Y (dst) are simply used to point to addresses with out
modification of a dbr register. The dbr register is not updated.

Memory Map
----------

This implementation of the W65C832 has 4 banks of memory. If there is
a Winbond W25Q128JV, Bank 3 and all memory above up to 16MB will be
paged in (and out) of RAM 4k at a time.

* Bank 0: RAM (4096 bytes)
* Bank 1: ROM (4096 bytes from rom.txt)
* Bank 2: Peripherals
* Bank 3: Wondbond W25Q128JV Flash (filling up to 16MB).

On start up the chip will execute code from Bank 1. If the program
select button is pushed on reset code will start from location 0xc000
in Bank 3.

The peripherals area contain the following:

* 0x8000: input from push button
* 0x8001: SPI_TX0
* 0x8003: SPI_CTRL0: bit 1: SPI start, bit 0: busy
* 0x8004: SPI_RX0
* 0x8005: SPI_DIVSOR0: 0 to 8
* 0x8008: ioport0 output (in my test case only 1 pin is connected)
* 0x8009: MIDI note value (60-96) to play a tone on the speaker or 0 to stop
* 0x800a: iport1
* 0x800b: UART TX buffer
* 0x800c: UART RX buffer
* 0x800d: UART CTRL - bit 1: rx_ready, bit 0: tx_busy
* 0x800e: SPI_TX1
* 0x800f: SPI_RX1
* 0x8010: SPI_CTRL1: bit 1: SPI start, bit 0: busy
* 0x8011: SPI_IO1: bit 0: cs
* 0x8012: SPI_DIVSOR1: 0 to 8
* 0x8013: SD card load count (number of times a page was loaded)

The UART runs only at 9600 baud. Reading from UART RX clears rx_ready.

