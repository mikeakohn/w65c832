.65832

.low_address 0
.high_address (1 << 24) - 1

.org 0xc000
data_0:
  .asciiz "I'm a little teapot"

.org 0x10000
data_1:
  .asciiz "Short and stout"

.org 0x1c000
data_2:
  .asciiz "HELLO!"

