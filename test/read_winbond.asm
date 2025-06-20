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
  ;lda.b #1
  ;pha
  ;plb
  lda 0xc000

.if 0
  lda.b #1
  sta 0x0000

  lda.b #0
  pha
  plb
  lda 0x0000
.endif

  brk

