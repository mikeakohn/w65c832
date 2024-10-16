#!/usr/bin/env python3

import sys

a = int(sys.argv[1], 16)
b = int(sys.argv[2], 16)

s = 0

if (a & 0x8000) != 0:
  a = a ^ 0xffff
  a += 1
  s += 1

if (b & 0x8000) != 0:
  b = b ^ 0xffff
  b += 1
  s += 1

c = 0

for i in range(0, 16):
  if (a & 1) == 1: c += b

  a = a >> 1
  b = b << 1

c = c >> 10
c = c & 0xffff

print("before sign fix: 0x%04x\n" % (c))

if s == 1:
  c = c ^ 0xffff
  c += 1
  c = c & 0xffff

print("0x%04x\n" % (c))

