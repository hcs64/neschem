#!/usr/bin/python

import png
from sys import argv
from io import open
from array import array

inpng_names = []
outbin_names = []

while len(argv) > 1:
    nextarg = argv.pop(1)
    if nextarg == '-o':
        break
    inpng_names.append(nextarg)

while len(argv) > 1:
    nextarg = argv.pop(1)
    outbin_names.append(nextarg)

if len(inpng_names) != len(outbin_names):
    print "%d inputs and %d outputs, should be equal" % (len(inpng_names), len(outbin_names))


for (inpng_name, outbin_name) in zip(inpng_names, outbin_names):

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
    outbin = open(outbin_name, "wb")
    outbin.write(outarr)
    outbin.close()
