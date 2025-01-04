.65832

.include "test/registers.inc"
.include "lcd/ssd1331.inc"

.org 0x4000

;; Variables memory addresses.
temp1  equ 12
temp   equ 16

;; Variables for mandelbrot().
curr_x equ 20
curr_y equ 22
curr_r equ 24
curr_i equ 26
color  equ 28
zr     equ 30
zi     equ 32
tr     equ 34
ti     equ 36

;curr_x equ 20
;curr_y equ 24
;curr_r equ 28
;curr_i equ 32
;color  equ 36
;zr     equ 40
;zi     equ 44
;tr     equ 48
;ti     equ 52
zr2    equ 56
zi2    equ 60

;; Variables for multiply.
mul_in_0  equ 80
mul_in_1  equ 84
mul_out   equ 88

mul_sign  equ 92
;four      equ 96
;one       equ 100
;zero      equ 104
;mask_ffff equ 108
;mask_8000 equ 112

.macro send_command(value)
  lda.b #value
  jsr lcd_send_cmd
.endm

.macro lsr_10
  lsr
  lsr
  lsr
  lsr
  lsr

  lsr
  lsr
  lsr
  lsr
  lsr
.endm

.macro square_fixed(var)
.scope
  lda var
  bit.w #0x8000
  beq not_signed
  eor.w #0xffff
  inc
not_signed:
  sta mul_in_0
  sta mul_in_1
  jsr multiply
.ends
.endm

.macro multiply_fixed(var1, var2)
  lda var1
  sta mul_in_0
  lda var2
  sta mul_in_1
  jsr multiply_signed
.endm

start:
  ;; Take out of emulation mode.
  clc
  xce

  ;; Use e16=0, e8=1 so registers are either 8bit/8bit or 32bit/32bit.
  sec
  clv
  xce

  SET_M8_X8

  ;; Clear LED.
  lda.b #0
  sta PORT0

main:
  jsr lcd_init
  jsr lcd_clear
while_1:
  lda.b #1
  bit BUTTON
  bne run
  jsr delay
  jsr toggle_led
  jmp while_1
run:
  jsr lcd_clear_2
  jsr mandelbrot
  jmp while_1

lcd_init:
  php
  SET_M8_X8

  lda.b #LCD_CS
  sta PORT1
  jsr delay
  lda.b #LCD_RES
  tsb PORT1

  send_command(SSD1331_DISPLAY_OFF)
  send_command(SSD1331_SET_REMAP)
  send_command(0x72)
  send_command(SSD1331_START_LINE)
  send_command(0x00)
  send_command(SSD1331_DISPLAY_OFFSET)
  send_command(0x00)
  send_command(SSD1331_DISPLAY_NORMAL)
  send_command(SSD1331_SET_MULTIPLEX)
  send_command(0x3f)
  send_command(SSD1331_SET_MASTER)
  send_command(0x8e)
  send_command(SSD1331_POWER_MODE)
  send_command(SSD1331_PRECHARGE)
  send_command(0x31)
  send_command(SSD1331_CLOCKDIV)
  send_command(0xf0)
  send_command(SSD1331_PRECHARGE_A)
  send_command(0x64)
  send_command(SSD1331_PRECHARGE_B)
  send_command(0x78)
  send_command(SSD1331_PRECHARGE_C)
  send_command(0x64)
  send_command(SSD1331_PRECHARGE_LEVEL)
  send_command(0x3a)
  send_command(SSD1331_VCOMH)
  send_command(0x3e)
  send_command(SSD1331_MASTER_CURRENT)
  send_command(0x06)
  send_command(SSD1331_CONTRAST_A)
  send_command(0x91)
  send_command(SSD1331_CONTRAST_B)
  send_command(0x50)
  send_command(SSD1331_CONTRAST_C)
  send_command(0x7d)
  send_command(SSD1331_DISPLAY_ON)
  plp
  rts

lcd_clear:
  php
  SET_M8_X32
  ;lda.b #SPI_16
  ;tsb SPI_CTL_0
  ldx.l #96 * 64 * 2
lcd_clear_loop:
  lda.b #0x0f
  sta SPI_TX_0
  ;sta SPI_TX_0+1
  jsr lcd_send_data
  dex
  bne lcd_clear_loop
  ;lda.b #SPI_16
  ;trb SPI_CTL_0
  plp
  rts

lcd_clear_2:
  php
  SET_M8_X32
  ;lda.b #SPI_16
  ;tsb SPI_CTL_0
  ldx.l #96 * 64
lcd_clear_loop_2:
  lda.b #0x0f
  sta SPI_TX_0
  jsr lcd_send_data
  lda.b #0xf0
  sta SPI_TX_0
  jsr lcd_send_data
  dex
  bne lcd_clear_loop_2
  ;lda.b #SPI_16
  ;trb SPI_CTL_0
  plp
  rts

;; uint32_t multiply(mul_in_0, mul_in_1) : A;
multiply:
  ;lda.w #0
  ;sta mul_in_0+2
  ;sta mul_in_1+2
  stz mul_in_0+2
  stz mul_in_1+2

  SET_M32_X32_FULL
  ; Set output to 0, count 16 bits.
  lda.l #0
  ldx.l #16
multiply_repeat:
  lsr mul_in_1
  bcc multiply_ignore_bit
  clc
  adc mul_in_0
multiply_ignore_bit:
  asl mul_in_0
  dex
  bne multiply_repeat
  lsr_10
  SET_M16_X32_FULL
  rts

;; This is only 16x16=16.
multiply_signed:
  ;; Keep track of sign bits
  ;lda.w #0
  ;sta mul_sign
  stz mul_sign
  lda.w #0x8000
  bit mul_in_0
  beq multiply_signed_var0_positive
  inc mul_sign
  lda mul_in_0
  eor.w #0xffff
  inc
  sta mul_in_0
multiply_signed_var0_positive:
  lda.w #0x8000
  bit mul_in_1
  beq multiply_signed_var1_positive
  inc mul_sign
  lda mul_in_1
  eor.w #0xffff
  inc
  sta mul_in_1
multiply_signed_var1_positive:
  jsr multiply
  lsr mul_sign
  bcc multiply_signed_not_neg
  eor.w #0xffff
  inc
multiply_signed_not_neg:
  rts

;shift_right_10:
;  ldx.l #10
;shift_right_10_loop:
;  ;clc
;  lsr mul_out
;  dex
;  bne shift_right_10_loop
;  rts

mandelbrot:
  ;; final int DEC_PLACE = 10;
  ;; final int r0 = (-2 << DEC_PLACE);
  ;; final int i0 = (-1 << DEC_PLACE);
  ;; final int r1 = (1 << DEC_PLACE);
  ;; final int i1 = (1 << DEC_PLACE);
  ;; final int dx = (r1 - r0) / 96; (0x0020)
  ;; final int dy = (i1 - i0) / 64; (0x0020)

  php

  ;; Set SPI to 16 bit.
  ;SET_M8_X8
  ;lda.b #SPI_16
  ;tsb SPI_CTL_0

  ;SET_M32_X32
  ;stz zr
  ;stz zi

  SET_M16_X32_FULL

  ;; for (y = 0; y < 64; y++)
  lda.w #64
  sta curr_y
  ;; int i = -1 << 10;
  lda.w #0xfc00
  sta curr_i
mandelbrot_for_y:
  ;; for (x = 0; x < 96; x++)
  lda.w #96
  sta curr_x
  ;; int r = -2 << 10;
  lda.w #0xf800
  sta curr_r
mandelbrot_for_x:
  ;; zr = r;
  ;; zi = i;
  lda curr_r
  sta zr
  lda curr_i
  sta zi

  ;; for (int count = 0; count < 15; count++)
  lda.w #15
  sta color
mandelbrot_for_count:
  ;; zr2 = (zr * zr) >> DEC_PLACE;
  square_fixed(zr)
  sta zr2

  ;; zi2 = (zi * zi) >> DEC_PLACE;
  square_fixed(zi)
  sta zi2

  ;; if (zr2 + zi2 > (4 << DEC_PLACE)) { break; }
  ;; cmp does: 4 - (zr2 + zi2).. if it's positive it's bigger than 4.
  lda zi2
  clc
  adc zr2

  cmp.w #(4 << 10)

  ;; push flags (1 byte) change M mode to 8 bits, pull A, change M back
  ;; to 16 bit mode. This is a signed greater than / equal comparison.
  ;php
  ;sep #0x20
  ;pla
  ;rep #0x20
  ;and.w #0xc0
  ;beq mandelbrot_stop
  ;cmp.w #0xc0
  ;beq mandelbrot_stop

  ;; Branch positive is an unsigned comparison. Since both numbers are
  ;; positive anyway, unsigned should be fine.
  bpl mandelbrot_stop
;php
;sep #0x20
;pla
;rep #0x20
;lda zi
;brk

  ;; tr = zr2 - zi2;
  lda zr2
  sec
  sbc zi2
  sta tr

  ;; ti = ((zr * zi) >> DEC_PLACE) << 1;
  multiply_fixed(zr, zi)
  asl
  sta ti

  ;; zr = tr + curr_r;
  lda tr
  clc
  adc curr_r
  sta zr

;lda zi
;brk

  ;; zi = ti + curr_i;
  lda ti
  clc
  adc curr_i
  sta zi

  dec color
  beq mandelbrot_stop
  jmp mandelbrot_for_count
mandelbrot_stop:

  asl color
  asl color

  SET_M8_X8
  ldx color

  lda colors+1,x
  sta SPI_TX_0
  jsr lcd_send_data
  lda colors+0,x
  sta SPI_TX_0
  jsr lcd_send_data

  SET_M16_X32

  ;; r += dx;
  lda curr_r
  clc
  adc.w #0x0020
  sta curr_r
  dec curr_x
  beq mandelbrot_for_x_exit
  jmp mandelbrot_for_x
mandelbrot_for_x_exit:

;lda curr_r
;brk

  ;; i += dy;
  lda curr_i
  clc
  adc.w #0x0020
  sta curr_i
  dec curr_y
  beq mandelbrot_for_y_exit
  jmp mandelbrot_for_y
mandelbrot_for_y_exit:

;lda curr_i
;brk

  SET_M8_X8
  ;lda.b #SPI_16
  ;trb SPI_CTL_0

  plp
  rts

;; lcd_send_cmd(A)
lcd_send_cmd:
  php
  pha
  SET_M8_X8
  lda.b #LCD_DC|LCD_CS
  trb PORT1

  pla
  sta SPI_TX_0

  lda.b #SPI_START
  tsb SPI_CTL_0
lcd_send_cmd_wait:
  lda.b #SPI_BUSY
  bit SPI_CTL_0
  bne lcd_send_cmd_wait

  lda.b #LCD_CS
  tsb PORT1
  plp
  rts

;; lcd_send_data()
lcd_send_data:
  php
  SET_M8_X8
  lda.b #LCD_DC
  tsb PORT1
  lda.b #LCD_CS
  trb PORT1
  lda.b #SPI_START
  tsb SPI_CTL_0
lcd_send_data_wait:
  lda.b #SPI_BUSY
  bit SPI_CTL_0
  bne lcd_send_data_wait
  lda.b #LCD_CS
  tsb PORT1
  plp
  rts

delay:
  php
  SET_M32_X32
  ldx.l #0x0002_0000
delay_loop:
  dex
  bne delay_loop
  plp
  rts

toggle_led:
  php
  SET_M8_X8
  lda PORT0
  eor.b #1
  sta PORT0
  plp
  rts

colors:
  .dc32 0x0000
  .dc32 0x000c
  .dc32 0x0013
  .dc32 0x0015
  .dc32 0x0195
  .dc32 0x0335
  .dc32 0x04d5
  .dc32 0x34c0
  .dc32 0x64c0
  .dc32 0x9cc0
  .dc32 0x6320
  .dc32 0xa980
  .dc32 0xaaa0
  .dc32 0xcaa0
  .dc32 0xe980
  .dc32 0xf800

