IMAGES=arrowdown.imgbin arrowup.imgbin element_He.imgbin

test.nes: test.as tiles.as $(IMAGES)
	neshla test.as

%.imgbin: ../images/%.png
	../img2bin/img2bin.py $< $@

clean:
	rm -f test.nes $(IMAGES) log.txt
