
;; Registers.
BUTTON     equ 0x8000
SPI_TX_0   equ 0x8001
SPI_CTL_0  equ 0x8003
SPI_RX_0   equ 0x8004
SPI_DIV_0  equ 0x8005
PORT0      equ 0x8008
SOUND      equ 0x8009
SPI_IO     equ 0x800a
PORT1      equ 0x800a
UART_TX    equ 0x800b
UART_RX    equ 0x800c
UART_CTL   equ 0x800d
SPI_TX_1   equ 0x800e
SPI_RX_1   equ 0x800f
SPI_CTL_1  equ 0x8010
SPI_IO_1   equ 0x8011
SPI_DIV_1  equ 0x8012

;; Bits in SPI_CTL.
SPI_BUSY   equ 1
SPI_START  equ 2
SPI_16     equ 4

;; Bits in UART_CTL.
UART_TX_BUSY  equ 1
UART_RX_READY equ 2

;; Bits in SPI_IO.
LCD_RES    equ 1
LCD_DC     equ 2
LCD_CS     equ 4

;; Bits in PORT0
LED0       equ 1

.macro SET_M8_X8
  sep #0x30
.endm

.macro SET_M8_X32
  sep #0x20
  rep #0x10
.endm

.macro SET_M32_X32
  rep #0x30
.endm

.macro SET_M32_X32_FULL
  sec
  clv
  xce
  rep #0x30
.endm

.macro SET_M16_X32
  rep #0x30
.endm

.macro SET_M16_X32_FULL
  clc
  clv
  xce
  rep #0x30
.endm

