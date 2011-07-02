OBJECTS = \
header.o \
init.o \
test2.o \
images.o \
common.o \
tiles.o \
ppu.o \
nmi.o \
joy.o

IMAGE_PATH = ../images/
IMG2BIN_PATH = ../img2bin/img2bin.py
include images.mk

EXE = test2.nes
LD65_CFG = link.cfg

$(EXE): $(LD65_CFG) $(OBJECTS)
	ld65 -C $(LD65_CFG) $(filter %.o,$^) -o $@

images.o: $(IMAGES)
tiles.o: common.inc ppu.inc tiles.inc
common.o: common.inc
ppu.o: ppu.inc
nmi.o: nmi.inc ppu.inc tiles.inc joy.inc
joy.o: joy.inc
test2.o: ppu.inc nmi.inc common.inc tiles.inc joy.inc images.inc

%.o: %.asm
	ca65 $< -o $@

# build all images, it's just faster than running img2bin more than once
$(IMAGES): $(patsubst %.imgbin,$(IMAGE_PATH)%.png,$(IMAGES))
	$(IMG2BIN_PATH) $^ -o $(patsubst $(IMAGE_PATH)%.png,%.imgbin,$^)

clean:
	rm -f $(EXE) $(OBJECTS) $(IMAGES) 

