.65c832

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

  lda.b #0x23
  sta 0x12
  lda.b #0x02
  sta 0x13

  lda.b #0x67
  sta 0x0221
  lda.b #0x89
  sta 0x0222

  ;; Copy 2 bytes starting at 0x0221 to 0x0223.
  ldx.l #0x0221
  ldy.l #0x0223
  lda.b #1
  mvn 0x00, 0x00

  asl 0x0223

  ;per 0x1234
  ;pea 0x1234
  ;pei (0x12)

  lda.b #0x80

  ldx.l #1

  lda.b #0xf0
  trb 0x0223

  stz 0x0221, x

  ldx.l #2

  rep #0x20
  lda (0x10, x)
  sep #0x20

  brk

  ldx.b #0x81
  dex
  nop
  brk


  lda.b #0xa5
  ldy.b #0x81
  ;lda (0xe0, x)
  ;lda (0xffe0, x)
  ;stx 0x00
  ;lda 0x00
  ;tay
  phy
  pla
  brk

