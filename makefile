
pstwo.bin: pstwo.asm include/bios.inc include/kernel.inc
	asm02 -b -L pstwo.asm

clean:
	-rm -f *.bin *.lst

