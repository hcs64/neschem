test.nes: test.as element_He.bin
	neshla test.as

element_He.bin: element_He.png
	../img2bin/img2bin.py element_He.png element_He.bin

clean:
	rm -f test.nes element_He.bin
