.65832

.include "test/registers.inc"

;; The sd_card code can be tested with the Windbond tests, but this
;; is an extra test (could be used to test Windbond too, if it gets
;; the page_load register).
;;
;; Basically this will read a page from SD card memory so it page
;; loads 512 bytes, dump some data to the serlcd display to prove
;; it works. Read from another page. And dump the page_load register
;; so it can prove the SD card isn't page loading on every hit.

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
  ; Set X/Y to 32 bit.
  SET_M8_X32

  ; Clear 32 bit location 0.
  lda.b #0
  sta 0
  sta 1
  sta 2
  sta 3

main:
  lda.b #7
  sta SPI_DIV_1

  jsr clear_screen

  lda 0xc1ff
  jsr spi_send_data
  ;lda 0xc001
  ;jsr spi_send_data
  ;lda 0xc002
  ;jsr spi_send_data
  ;lda 0xc200
  ;jsr spi_send_data
  ;lda 0x10000
  ;jsr spi_send_data
  ;lda 0xc000
  ;jsr spi_send_data
  lda 0x10000
  jsr spi_send_data
  lda 0x10205
  jsr spi_send_data
  lda 0x10206
  jsr spi_send_data
  lda 0x10207
  jsr spi_send_data

  lda.b #' '
  jsr spi_send_data

  lda LOAD_COUNT
  sta 0

  jsr print_accum

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

clear_screen:
  lda.b #'|'
  jsr spi_send_data
  lda.b #0x2d
  jsr spi_send_data
  rts

print_accum:
  phx
  php
  ;SET_M32_X32_FULL
  ;lda.l #0x1234abcd
  ;sta 0
  SET_M8_X8
  ldx.b #3
print_accum_loop:
  lda 0, x
  lsr
  lsr
  lsr
  lsr
  jsr print_nibble
  lda 0, x
  and.b #0x0f
  jsr print_nibble
  dex
  bpl print_accum_loop
  plp
  plx
  rts

print_nibble:
  cmp.b #10
  bpl print_nibble_af
  clc
  adc.b #'0'
  jsr spi_send_data
  rts
print_nibble_af:
  clc
  adc.b #'A' - 10
  jsr spi_send_data
  rts

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

