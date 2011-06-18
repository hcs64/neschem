#!/usr/bin/python

import png
from sys import argv
from io import open
from array import array

inpng_name = argv[1]
outbin_name = argv[2]

inpng = png.Reader(inpng_name)

(width, height, pixels, metadata) = inpng.read()

if metadata['bitdepth'] != 1 or width != 8 or height != 8:
    print "unsupported (%d,%d)" % (width, height)
    print metadata
    exit(1)

outarr = array('B')
for row in pixels:
    val = 0
    for pixel in row:
        val = (val << 1) | pixel
    outarr.append(val)

outarr.reverse()
outbin = open(argv[2], "wb")
outbin.write(outarr)
