#!/usr/bin/env python3

import sys

fp = open(sys.argv[1], "rb")

while True:
  b = fp.read(1)
  if not b: break
  #print("%02x%02x%02x%02x" % (b[0], b[1], b[2], b[3]))
  print("%02x" % (b[0]))

fp.close()

