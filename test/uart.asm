.65832

UART_TX_BUSY  equ 1
UART_RX_READY equ 2

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

  clv

  ;; Write out 4 bytes in a row to test transmit.
  lda.b #'M'
  jsr write_uart
  lda.b #'I'
  jsr write_uart
  lda.b #'K'
  jsr write_uart
  lda.b #'E'
  jsr write_uart

  ;; Read from UART if there is data and echo it back.
  ;; Reading from UART RX (0x800c) clears rx_ready.
wait_for_uart:
  lda 0x800d
  and.b #UART_RX_READY
  beq wait_for_uart
  lda 0x800c
  jsr write_uart
  jmp wait_for_uart

  nop
  nop
  nop

write_uart:
  sta 0x800b
write_uart_wait:
  lda 0x800d
  and.b #UART_TX_BUSY
  bne write_uart_wait
  rts

