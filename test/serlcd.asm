.65832

.include "test/registers.inc"

.org 0x4000
start:
  ; Set 65C816 mode.
  clc
  xce

  ; Set 65C832 mode.
  clc
  clv
  xce

  ; Set A to 8-bit.
  sep #0x20

  ; Set X/Y to 32 bit.
  rep #0x10

main:
  lda.b #3
  sta SPI_DIV_1
  lda.b #'M'
  jsr spi_send_data

run:
  ;; LED on.
  lda.b #0x01
  sta 0x8008

  jsl delay

  ;; LED off.
  lda.b #0x00
  sta 0x8008

  jsl delay
  jmp run

;; spi_send_data()
spi_send_data:
  php
  SET_M8_X8
  sta SPI_TX_1
  lda.b #1
  trb SPI_IO_1
  lda.b #SPI_START
  tsb SPI_CTL_1
spi_send_data_wait:
  lda.b #SPI_BUSY
  bit SPI_CTL_1
  bne spi_send_data_wait
  lda.b #1
  tsb SPI_IO_1
  plp
  rts

delay:
  ldx.l #0x0002_0000
delay_loop:
  dex
  bne delay_loop
  rtl

