#!/usr/bin/env python3

import sys

a = float(sys.argv[1])
m = False

if (a < 0):
  m = True 
  a = -a

print(a)

i = int(a)
a = a - i
a = int(1024 * a)
i = i << 10
a = i + a

if m == True:
  a = a ^ 0xffff
  a = a + 1
  a = a & 0xffff

print("0x%04x" % (a))

