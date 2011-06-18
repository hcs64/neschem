#!/usr/bin/python

import png
from sys import argv
from io import open

inpng_name = argv[1]
outbin_name = argv[2]

inpng = png.Reader(inpng_name)

(width, height, pixels, metadata) = inpng.read()

if metadata['bitdepth'] != 1 or width != 8 or height != 8:
    print "unsupported (%d,%d)" % (width, height)
    print metadata
    exit(1)

outbin = open(argv[2], "wb")
for row in pixels:
    val = 0
    for pixel in row:
        val = (val << 1) | pixel

    outbin.write((val,))
