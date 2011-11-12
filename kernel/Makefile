# Makefile for kernel

GCC=/usr/local/cross/bin/i686-elf-gcc-4.6.1
LD=/usr/local/cross/bin/i686-elf-ld

COPTS=-c -Wall #-Werror

all: kernel

kernel: start_kernel.o kmain.o util.o io.o
	$(LD) -T kernel.lnk -o kernel.bin start_kernel.o kmain.o util.o io.o

start_kernel.o: start_kernel.S
	nasm -felf -o start_kernel.o start_kernel.S

kmain.o: kmain.c
	$(GCC) $(COPTS) kmain.c 

io.o: io.h io.c
	$(GCC) $(COPTS) io.c

util.o: util.h util.c
	$(GCC) $(COPTS) util.c

clean:
	rm -rf *.bin *.o *~
