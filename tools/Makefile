# Master makefile

GCC=/usr/local/cross/bin/i686-elf-gcc-4.6.1
LD=/usr/local/cross/bin/i686-elf-ld
MAKE=exec make


image: makefloppy bootloader kernel
	./makefloppy ../boot/bootloader.bin ../kernel/kernel.bin	

makefloppy: makefloppy.c
	gcc -o makefloppy makefloppy.c

bootloader: 
	cd ../boot && $(MAKE)

kernel:
	cd ../kernel && $(MAKE)

clean:
	rm -rf *~ makefloppy *.img
	cd ../boot && $(MAKE) clean
	cd ../kernel && $(MAKE) clean
