# Makefile for bootloader`

all: cd flp 

cd: cdboot.bin

cdboot.bin: cdboot.S
	nasm -o cdboot.bin cdboot.S

flp: boot.bin

boot.bin: boot.S
	nasm -o boot.bin boot.S

clean:
	rm -rf *.bin *~
