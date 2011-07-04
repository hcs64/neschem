SOURCES = \
images.as \
mem.as \
test.as \
tile_fixed.as \
tile_stage.as \
tile_update.as

EXE = test.nes

IMAGE_PATH = ../images/
IMG2BIN_PATH = ../img2bin/img2bin.py
include images.mk

$(EXE): $(SOURCES) $(IMAGES)
	neshla test.as

tell: $(SOURCES) $(IMAGES)
	neshla test.as -tell

# build all images, it's just faster than running img2bin more than once
$(IMAGES): $(patsubst %.imgbin,$(IMAGE_PATH)%.png,$(IMAGES))
	$(IMG2BIN_PATH) $^ -o $(patsubst $(IMAGE_PATH)%.png,%.imgbin,$^)

clean:
	rm -f test.nes $(IMAGES) log.txt
