;; NOTE: This test requires an SD card connected and loaded with the
;; sd_card.bin binary.

.65832

.include "test_macros.inc"
.include "registers.inc"

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

  lda.b #0x01
  pha
  plb
  ; Full address with dbr is 01_0000. Should be on SD card.
  lda 0x0000
  cmp.b #0x50
  CHECK_EQUAL

  ;; Move 2 bytes from SD card (upper memory) to lower.
  SET_M16_X16_FULL
  lda.w #1
  ldx.w #0x1000
  ldy.w #0x0000
  mvp 0x01, 0x00
  SET_M8_X32_FULL

  cmp.b #0xff
  CHECK_EQUAL
  cpx.l #0x1002
  CHECK_EQUAL
  cpy.l #0x0002
  CHECK_EQUAL

  phb
  pla
  cmp.b #0x00
  CHECK_EQUAL

  lda 0
  cmp.b #0x50
  CHECK_EQUAL

  lda 1
  cmp.b #0x41
  CHECK_EQUAL

  lda 2
  cmp.b #0x00
  CHECK_EQUAL

loop:
  ;; LED on.
  lda.b #0x01
  sta 0x8008
  jsr delay
  ;; LED off.
  lda.b #0x00
  sta 0x8008
  jsr delay
  jmp loop

delay:
  ldx.l #0x0002_0000
delay_loop:
  dex
  bne delay_loop
  rts

error:
  lda.b #0x01
  sta 0x8008
  pla
  brk

