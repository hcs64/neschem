IMAGES= arrowdown.imgbin \
arrowleft.imgbin \
arrowright.imgbin \
arrowup.imgbin \
cmd_alpha.imgbin \
cmd_beta.imgbin \
cmd_bondadd.imgbin \
cmd_bondsub.imgbin \
cmd_d.imgbin \
cmd_ff.imgbin \
cmd_gd.imgbin \
cmd_g.imgbin \
cmd_omega.imgbin \
cmd_psi.imgbin \
cmd_start.imgbin \
element_Be.imgbin \
element_B.imgbin \
element_C.imgbin \
element_F.imgbin \
element_He.imgbin \
element_H.imgbin \
element_Li.imgbin \
element_Ne.imgbin \
element_O.imgbin \
fringebot.imgbin \
fringeleft.imgbin \
fringeright.imgbin \
fringetop.imgbin \
linebotleft.imgbin \
linebotright.imgbin \
lineh.imgbin \
linetopleft.imgbin \
linetopright.imgbin \
linev.imgbin


test.nes: test.as tiles.as $(IMAGES)
	neshla test.as

%.imgbin: ../images/%.png
	../img2bin/img2bin.py $< $@

clean:
	rm -f test.nes $(IMAGES) log.txt
