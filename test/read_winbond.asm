.65832

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
  ;lda 0xc000
  lda 0xc005
  lda.b #1
  pha
  ;pld
  plb
  ;lda 0xc001
  lda 0x0000

  brk

