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

  ;; Test 1: 16 bit mvn.
  ;; Move 2 bytes from SD card (upper memory) to lower.
  SET_M16_X16_FULL
  lda.w #1
  ldx.w #0x1000
  ldy.w #0x0000
  mvn 0x01, 0x00
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

  ;; Test 2: 16 bit mvp.
  ;; Move 2 bytes from SD card (upper memory) to lower.
  SET_M16_X16_FULL
  lda.w #1
  ldx.w #0x100b
  ldy.w #0x0006
  mvp 0x01, 0x00
  SET_M8_X32_FULL

  cmp.b #0xff
  CHECK_EQUAL
  cpx.l #0x1009
  CHECK_EQUAL
  cpy.l #0x0004
  CHECK_EQUAL

  phb
  pla
  cmp.b #0x00
  CHECK_EQUAL

  lda 0x6
  cmp.b #0x31
  CHECK_EQUAL

  lda 0x5
  cmp.b #0x30
  CHECK_EQUAL

  lda 0x4
  cmp.b #0x00
  CHECK_EQUAL

  ;; Test 3: 32 bit mvn.
  ;; Set dbr to 01 to prove it's not used in 32 bit mode.
  lda.b #0x02
  pha
  plb

  SET_M32_X32_FULL
  lda.l #1
  ldx.l #0x11900
  ldy.l #0x00010
  ;; Assembler doesn't support mvp/mvn with no operands yet.
  ;mvn
  .db 0x54

  cmp.l #0xffff_ffff
  CHECK_EQUAL
  cpx.l #0x11902
  CHECK_EQUAL
  cpy.l #0x00012
  CHECK_EQUAL

  SET_M8_X32_FULL

  ;; Check dbr didn't change from mvn.
  phb
  pla
  cmp.b #0x02
  CHECK_EQUAL

  ;; Set dbr back to 0.
  lda.b #0x00
  pha
  plb

  lda 0x10
  cmp.b #0x36
  CHECK_EQUAL

  lda 0x11
  cmp.b #0x37
  CHECK_EQUAL

  lda 0x12
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
  SET_M16_X16_FULL
  pla
  brk

