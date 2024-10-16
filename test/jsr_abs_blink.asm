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

  ;jmp.l run
  ldx.l #2
  jmp (run_table, x)

  nop
  nop
  nop
  nop
  nop
  brk

run:
  ;; LED on.
  ;lda.b #0x01
  ;sta 0x8008
  ldx.l #0
  jsr (led_table, x)

  jsl delay

  ;; LED off.
  ;lda.b #0x00
  ;sta 0x8008
  ldx.l #2
  jsr (led_table, x)

  jsl delay

  jmp run

delay:
  ldx.l #0x0002_0000
delay_loop:
  dex
  bne delay_loop
  rtl

run_table:
  .dc16 0
  .dc16 run

led_table:
  .dc16 led_on
  .dc16 led_off

led_on:
  lda.b #0x01
  sta 0x8008
  rts

led_off:
  lda.b #0x00
  sta 0x8008
  rts

