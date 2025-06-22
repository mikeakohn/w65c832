#!/usr/bin/env python3

def write_block(text):
  for s in text:
    fp.write(s)

  for i in range(0, 512 - len(text)):
    c = str(i)
    fp.write(c[-1])

# ---------------------- fold here -----------------------

fp = open("sd_card.bin", "w")

address = 0

for i in range(0,500):
  text = "PAGE " + str(i) + "--"

  if address == 0xc000:
    write_block("MY NAME IS LUKA AND I LIVE ON THE SECOND FLOOR.")
  else:
    write_block(text)

  address += 512

fp.close()

