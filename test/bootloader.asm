; XMODEM Bootloader for Michael Kohn's W65C832 FPGA Core
; Written by Joe Davisson

; Tested with:
; - iceFUN iCE40 HX8K FPGA
; - Adafruit USB to TTL serial cable
; - Minicom 2.9 (9600 baud, 8N2, no handshaking)

; cable connnections:
;  - RED   - 5V (not connected)
;  - BLACK - GND
;  - WHITE - RX (goes to H3)
;  - GREEN - TX (goes to G3)

; packet format:
;  - start of header (1 byte)
;  - packet number (1 byte)
;  - inverse packet_number (1 byte)
;  - data (128 bytes)
;  - checksum (1 byte)

.65832

.include "test/registers.inc"

SOH equ 0x01  ; start of header
EOT equ 0x04  ; end of transmission
ACK equ 0x06  ; acknowledged
NAK equ 0x15  ; not acknowledged

address equ 0x10
packet_count equ 0x14
packet_data equ 0x18

; program is loaded into RAM here
ram_start equ 0x200

; program loader
.org 0x4000

start:
  ; take out of emulation mode
  clc
  xce

  ; set flags so registers can be 8 or 32 bits with sep #0x30 or rep #0x30
  sec
  clv
  xce

  ; 8-bit mode
  SET_M8_X8

message:
  ldx.b #0
message_loop:
  lda message_text,x
  cmp.b #'\0'
  beq button_press
  jsr write_uart
  inx
  jmp message_loop

button_press:
  lda.b #1
  bit BUTTON
  beq button_press

button_release:
  lda.b #1
  bit BUTTON
  bne button_release

begin_transfer:
  lda.b #ram_start & 255
  sta address + 0
  lda.b #ram_start >> 8
  sta address + 1

  lda.b #1
  sta packet_count

  lda.b #NAK
  jsr write_uart

get_next_packet:
  jsr read_uart
  cmp.b #SOH
  beq get_packet_data
  cmp.b #EOT
  bne get_next_packet_error
  jmp done
get_next_packet_error:
  jmp error

get_packet_data:
  ldx.b #0
get_packet_data_loop:
  jsr read_uart
  sta packet_data,x
  inx
  cpx.b #131
  bne get_packet_data_loop

check_packet_number:
  lda packet_data + 0
  cmp packet_count
  beq check_packet_number_inverse
  jmp error

check_packet_number_inverse:
  clc
  lda packet_data + 0
  adc packet_data + 1
  cmp.b #0xff
  beq test_checksum
  jmp error

test_checksum:
  lda.b #0
  pha
  pha
  ldx.b #127
  clc
test_checksum_loop:
  pla
  adc.b packet_data + 2,x
  tay
  pla
  adc.b #0
  pha
  phy
  dex
  bpl test_checksum_loop
  pla
  ply
  cmp packet_data + 130
  beq store_packet
  jmp error

store_packet:
  ldx.b #127
  txy
store_packet_loop:
  lda packet_data + 2,x
  sta (address),y
  dex
  dey
  bpl store_packet_loop

update_address:
  clc
  lda address + 0
  adc.b #128
  sta address + 0
  lda address + 1
  adc.b #0
  sta address + 1

  inc packet_count

  lda.b #ACK
  jsr write_uart

  jmp get_next_packet

done:
  lda.b #ACK
  jsr write_uart

  ; run user program
  jml ram_start

error:
  lda.b #NAK
  jsr write_uart
  jmp get_next_packet

read_uart:
  php
read_uart_wait:
  lda 0x800d
  and.b #UART_RX_READY
  beq read_uart_wait
  lda 0x800c
  plp
  rts

write_uart:
  php
  sta 0x800b
write_uart_wait:
  lda 0x800d
  and.b #UART_TX_BUSY
  bne write_uart_wait
  plp
  rts

message_text:
  db "Ready.\r\n\0"

