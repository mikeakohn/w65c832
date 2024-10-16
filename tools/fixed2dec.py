#!/usr/bin/env python3

import sys

a = int(sys.argv[1], 0)
s = ""

if (a & 0x8000) != 0:
  s = "-"
  a = a ^ 0xffff
  a = a + 1
  a = a & 0xffff

b = a & 0x3ff
a = a >> 10
a += b / 1024

print(s + str(a))

