# Master makefile

GCC=/usr/local/cross/bin/i686-elf-gcc-4.6.1
LD=/usr/local/cross/bin/i686-elf-ld
MAKE=exec make
CDIMG=cdimage
BOOTDIR=boot

all: cdimage flpimage

cdimage: bootloader kernel
	mkdir -p $(CDIMG)
	mkdir -p $(CDIMG)/$(BOOTDIR)
	cp ../boot/cdboot.bin $(CDIMG)/$(BOOTDIR)/stage1
	cp ../boot/stage2.bin $(CDIMG)/$(BOOTDIR)/stage2	
	cp ../kernel/kernel.bin $(CDIMG)/$(BOOTDIR)/kernel
	mkisofs -R -b $(BOOTDIR)/stage1 -no-emul-boot -boot-load-size 4 -o livecd.iso $(CDIMG)

flpimage: makefloppy bootloader kernel
	./makefloppy ../boot/boot.bin ../kernel/kernel.bin	

makefloppy: makefloppy.c
	gcc -o makefloppy makefloppy.c

bootloader: 
	cd ../boot && $(MAKE)

kernel:
	cd ../kernel && $(MAKE)

clean:
	rm -rf *~ makefloppy *.img *.iso
	rm -rf $(CDIMG)
	cd ../boot && $(MAKE) clean
	cd ../kernel && $(MAKE) clean
