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

  lda.b #0x01
  cmp.b #0x01
  beq pass_1
  jsr error
pass_1: 

  bit.b #0xc0
  php
  pla
  bit.b #0x80
  bne pass_2
  jsr error
pass_2: 
  bit.b #0x40
  bne pass_3
  jsr error
pass_3: 

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

